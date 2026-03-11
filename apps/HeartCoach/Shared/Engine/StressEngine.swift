// StressEngine.swift
// ThumpCore
//
// Computes an HRV-based stress score (0-100) using a personal baseline
// approach. Lower HRV relative to the user's own rolling average
// indicates higher stress. Supports day, week, and month aggregation
// for trend visualization.
//
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Stress Engine

/// Stateless engine that derives stress scores from HRV data.
///
/// The algorithm compares current HRV against a 14-day rolling baseline.
/// When HRV drops below baseline the stress score rises, and when HRV
/// is above baseline the score falls. The mapping uses a sigmoid-style
/// curve to keep scores within 0-100.
///
/// All methods are pure functions with no side effects.
public struct StressEngine: Sendable {

    // MARK: - Configuration

    /// Number of days used for the personal HRV baseline.
    public let baselineWindow: Int

    /// The maximum reasonable HRV deviation (in ms) used for score scaling.
    /// Deviations beyond this are clamped.
    private let maxDeviation: Double = 40.0

    public init(baselineWindow: Int = 14) {
        self.baselineWindow = max(baselineWindow, 3)
    }

    // MARK: - Core Computation

    /// Compute a stress score from current HRV compared to a personal baseline.
    ///
    /// The score is derived by measuring how far the current HRV deviates
    /// below (or above) the baseline. A large negative deviation produces
    /// a high stress score; at-or-above baseline produces a low score.
    ///
    /// - Parameters:
    ///   - currentHRV: Today's HRV (SDNN) in milliseconds.
    ///   - baselineHRV: The user's rolling average HRV in milliseconds.
    /// - Returns: A ``StressResult`` with score, level, and description.
    public func computeStress(
        currentHRV: Double,
        baselineHRV: Double
    ) -> StressResult {
        guard baselineHRV > 0 else {
            return StressResult(
                score: 50,
                level: .balanced,
                description: "Not enough data to determine your baseline yet."
            )
        }

        // How far below baseline the current reading is (positive = below)
        let deviation = baselineHRV - currentHRV

        // Normalize deviation to a 0-100 scale.
        // deviation > 0 means HRV is below baseline (more stressed)
        // deviation <= 0 means HRV is at/above baseline (less stressed)
        let normalized = deviation / maxDeviation
        let rawScore = 50.0 + (normalized * 50.0)
        let score = max(0, min(100, rawScore))

        let level = StressLevel.from(score: score)
        let description = friendlyDescription(
            score: score,
            level: level,
            currentHRV: currentHRV,
            baselineHRV: baselineHRV
        )

        return StressResult(
            score: score,
            level: level,
            description: description
        )
    }

    // MARK: - Daily Stress Score

    /// Compute a single stress score for the most recent day using
    /// the preceding snapshots as baseline.
    ///
    /// - Parameter snapshots: Historical snapshots, ordered oldest-first.
    ///   The last element is treated as "today."
    /// - Returns: A stress score (0-100), or `nil` if insufficient data.
    public func dailyStressScore(
        snapshots: [HeartSnapshot]
    ) -> Double? {
        guard snapshots.count >= 2 else { return nil }

        let current = snapshots[snapshots.count - 1]
        guard let currentHRV = current.hrvSDNN else { return nil }

        let baseline = computeBaseline(
            snapshots: Array(snapshots.dropLast())
        )
        guard let baselineHRV = baseline else { return nil }

        let result = computeStress(
            currentHRV: currentHRV,
            baselineHRV: baselineHRV
        )
        return result.score
    }

    // MARK: - Stress Trend

    /// Produce a time series of stress data points over a given range.
    ///
    /// For each day in the range, a stress score is computed against
    /// the rolling baseline from the preceding days.
    ///
    /// - Parameters:
    ///   - snapshots: Full history of snapshots, ordered oldest-first.
    ///   - range: The time range to generate trend data for.
    /// - Returns: Array of ``StressDataPoint`` values, one per day
    ///   that has valid HRV data.
    public func stressTrend(
        snapshots: [HeartSnapshot],
        range: TimeRange
    ) -> [StressDataPoint] {
        guard snapshots.count >= 2 else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -range.days,
            to: today
        ) else { return [] }

        var points: [StressDataPoint] = []

        for index in 0..<snapshots.count {
            let snapshot = snapshots[index]

            // Only include snapshots within the requested range
            guard snapshot.date >= cutoff else { continue }
            guard let currentHRV = snapshot.hrvSDNN else { continue }

            // Build baseline from all preceding snapshots (up to window)
            let precedingEnd = index
            let precedingStart = max(0, precedingEnd - baselineWindow)
            let precedingSlice = Array(
                snapshots[precedingStart..<precedingEnd]
            )
            guard let baselineHRV = computeBaseline(
                snapshots: precedingSlice
            ) else { continue }

            let result = computeStress(
                currentHRV: currentHRV,
                baselineHRV: baselineHRV
            )
            points.append(StressDataPoint(
                date: snapshot.date,
                score: result.score,
                level: result.level
            ))
        }

        return points
    }

    // MARK: - Baseline Computation

    /// Compute the rolling HRV baseline from a set of snapshots.
    ///
    /// Uses the mean of available HRV values within the baseline window.
    ///
    /// - Parameter snapshots: Snapshots to derive the baseline from.
    /// - Returns: The average HRV in milliseconds, or `nil` if no data.
    public func computeBaseline(
        snapshots: [HeartSnapshot]
    ) -> Double? {
        let recent = Array(snapshots.suffix(baselineWindow))
        let hrvValues = recent.compactMap(\.hrvSDNN)
        guard !hrvValues.isEmpty else { return nil }
        return hrvValues.reduce(0, +) / Double(hrvValues.count)
    }

    // MARK: - Hourly Stress Estimation

    /// Estimate hourly stress scores for a single day using circadian
    /// variation patterns applied to the daily HRV reading.
    ///
    /// Since HealthKit typically provides one HRV reading per day,
    /// this applies known circadian HRV patterns to estimate hourly
    /// variation: HRV is naturally lower during waking/active hours
    /// and higher during sleep.
    ///
    /// - Parameters:
    ///   - dailyHRV: The day's HRV (SDNN) in milliseconds.
    ///   - baselineHRV: The user's rolling baseline HRV.
    ///   - date: The calendar date for hour generation.
    /// - Returns: Array of 24 ``HourlyStressPoint`` values (one per hour).
    public func hourlyStressEstimates(
        dailyHRV: Double,
        baselineHRV: Double,
        date: Date
    ) -> [HourlyStressPoint] {
        let calendar = Calendar.current

        // Circadian HRV multipliers: night hours have higher HRV,
        // afternoon/work hours have lower HRV
        let circadianFactors: [Double] = [
            1.15, 1.18, 1.20, 1.18, 1.12, 1.05, // 0-5 AM (sleep)
            0.98, 0.95, 0.90, 0.88, 0.85, 0.87, // 6-11 AM (morning)
            0.90, 0.85, 0.82, 0.84, 0.88, 0.92, // 12-5 PM (afternoon)
            0.95, 0.98, 1.02, 1.05, 1.10, 1.12  // 6-11 PM (evening)
        ]

        return (0..<24).map { hour in
            let adjustedHRV = dailyHRV * circadianFactors[hour]
            let result = computeStress(
                currentHRV: adjustedHRV,
                baselineHRV: baselineHRV
            )
            let hourDate = calendar.date(
                bySettingHour: hour, minute: 0, second: 0, of: date
            ) ?? date

            return HourlyStressPoint(
                date: hourDate,
                hour: hour,
                score: result.score,
                level: result.level
            )
        }
    }

    /// Generate hourly stress data for a full day from snapshot history.
    ///
    /// - Parameters:
    ///   - snapshots: Full history of snapshots, ordered oldest-first.
    ///   - date: The target date to generate hourly data for.
    /// - Returns: Array of 24 hourly stress points, or empty if no data.
    public func hourlyStressForDay(
        snapshots: [HeartSnapshot],
        date: Date
    ) -> [HourlyStressPoint] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)

        // Find the snapshot for this date
        guard let snapshot = snapshots.first(where: {
            calendar.isDate($0.date, inSameDayAs: targetDay)
        }), let dailyHRV = snapshot.hrvSDNN else {
            return []
        }

        // Compute baseline from preceding days
        let preceding = snapshots.filter { $0.date < targetDay }
        guard let baseline = computeBaseline(snapshots: preceding) else {
            return []
        }

        return hourlyStressEstimates(
            dailyHRV: dailyHRV,
            baselineHRV: baseline,
            date: targetDay
        )
    }

    // MARK: - Trend Direction

    /// Determine whether stress is rising, falling, or steady over
    /// a set of data points.
    ///
    /// Uses simple linear regression on the scores to determine slope.
    /// A slope > 2 points/day is rising, < -2 is falling, else steady.
    ///
    /// - Parameter points: Stress data points, ordered chronologically.
    /// - Returns: The trend direction, or `.steady` if insufficient data.
    public func trendDirection(
        points: [StressDataPoint]
    ) -> StressTrendDirection {
        guard points.count >= 3 else { return .steady }

        let count = Double(points.count)
        let xValues = (0..<points.count).map { Double($0) }
        let yValues = points.map(\.score)

        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).map(*).reduce(0, +)
        let sumX2 = xValues.map { $0 * $0 }.reduce(0, +)

        let denominator = count * sumX2 - sumX * sumX
        guard denominator != 0 else { return .steady }

        let slope = (count * sumXY - sumX * sumY) / denominator

        // Slope threshold: ~0.5 points per day over the range
        // is enough to indicate a meaningful trend shift
        if slope > 0.5 {
            return .rising
        } else if slope < -0.5 {
            return .falling
        } else {
            return .steady
        }
    }

    // MARK: - Friendly Descriptions

    /// Generate a friendly, non-clinical description of the stress result.
    private func friendlyDescription(
        score: Double,
        level: StressLevel,
        currentHRV: Double,
        baselineHRV: Double
    ) -> String {
        let percentDiff = abs(currentHRV - baselineHRV) / baselineHRV * 100

        switch level {
        case .relaxed:
            if percentDiff < 5 {
                return "Your body seems to be in a good rhythm today. "
                    + "Keep doing what you're doing!"
            }
            return "Your heart rate variability is looking great "
                + "compared to your usual. Nice work!"

        case .balanced:
            if currentHRV < baselineHRV {
                return "Things are looking pretty normal today. "
                    + "Your body is handling its day-to-day load well."
            }
            return "You're right around your usual range. "
                + "A pretty typical day for your body."

        case .elevated:
            if percentDiff > 30 {
                return "Your body might be working a bit harder than "
                    + "usual today. Consider taking it easy — a walk, "
                    + "some deep breaths, or extra sleep could help."
            }
            return "You seem to be running a bit hot today. "
                + "Think about giving yourself some recovery "
                + "time — your body will thank you."
        }
    }
}

// MARK: - Time Range

/// Predefined time ranges for stress trend aggregation.
public enum TimeRange: Int, CaseIterable, Sendable {
    case day = 1
    case week = 7
    case month = 30

    /// The number of calendar days this range represents.
    public var days: Int { rawValue }

    /// Human-readable label for display.
    public var label: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

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

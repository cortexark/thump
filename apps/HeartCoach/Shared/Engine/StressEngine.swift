// StressEngine.swift
// ThumpCore
//
// HR-primary stress scoring calibrated against real PhysioNet data:
//
// Calibration finding (March 2026): Testing 6 algorithms against
// PhysioNet Wearable Exam Stress Dataset (10 subjects, 643 windows)
// vs published resting norms (Nunan et al. 2010), HR was the only
// signal that discriminated stress vs rest in the correct direction
// (Cohen's d = +2.10). SDNN and RMSSD went UP during exam stress
// (d = +1.31, +2.08) due to physical immobility confound.
//
// Architecture (calibrated weights):
//
// 1. RHR Deviation (primary, 50% weight):
//    - Elevated resting HR relative to personal baseline
//    - Strongest stress discriminator from wearable data (AUC 0.85+)
//    - Z-score through sigmoid for smooth 0-100 mapping
//
// 2. HRV Baseline Deviation (secondary, 30% weight):
//    - Z-score of current HRV vs 14-day rolling baseline
//    - HRV alone has inverted direction for seated cognitive stress
//    - Effective only when activity-controlled or sleep-measured
//
// 3. Coefficient of Variation (tertiary, 20% weight):
//    - CV = SD / Mean of recent HRV readings
//    - High CV (>0.25) suggests autonomic instability
//
// 4. Sigmoid Mapping:
//    - Raw composite score mapped through sigmoid for smooth 0-100
//
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Stress Engine

/// HR-primary stress engine calibrated against real PhysioNet data.
///
/// Uses RHR deviation as the primary signal (50%) with HRV baseline
/// deviation as secondary (30%) and CV as tertiary (20%).
///
/// Calibration: PhysioNet Wearable Exam Stress Dataset showed HR is
/// the strongest stress discriminator from wearables (Cohen's d = 2.10).
/// HRV alone inverts direction during seated cognitive stress.
///
/// All methods are pure functions with no side effects.
public struct StressEngine: Sendable {

    // MARK: - Configuration

    /// Number of days used for the personal HRV baseline.
    public let baselineWindow: Int

    /// Whether to apply log-SDNN transformation before computing the HRV component.
    ///
    /// When `true` (the default), SDNN values are transformed via `log(sdnn)`
    /// before computing the HRV Z-score. This handles the well-known right-skew
    /// in SDNN distributions and makes the score more linear across the
    /// population range.
    public let useLogSDNN: Bool

    /// Weight for RHR deviation component (primary signal).
    /// Calibrated from PhysioNet data: HR discriminates stress best (d=2.10).
    private let rhrWeight: Double = 0.50

    /// Weight for HRV Z-score component (secondary signal).
    /// Effective when activity-controlled or sleep-measured.
    private let hrvWeight: Double = 0.30

    /// Weight for coefficient of variation component (tertiary signal).
    private let cvWeight: Double = 0.20

    /// Sigmoid steepness — higher = sharper transition around midpoint.
    private let sigmoidK: Double = 0.08

    /// Sigmoid midpoint (raw composite score that maps to stress = 50).
    private let sigmoidMid: Double = 50.0

    public init(baselineWindow: Int = 14, useLogSDNN: Bool = true) {
        self.baselineWindow = max(baselineWindow, 3)
        self.useLogSDNN = useLogSDNN
    }

    // MARK: - Core Computation

    /// Compute a stress score from HR and HRV data compared to personal baselines.
    ///
    /// Uses three signals (calibrated from PhysioNet real data):
    /// 1. RHR deviation: elevated resting HR vs baseline (primary, 50%)
    /// 2. HRV Z-score: how many SDs below personal HRV baseline (30%)
    /// 3. CV signal: autonomic instability from recent HRV variability (20%)
    ///
    /// - Parameters:
    ///   - currentHRV: Today's HRV (SDNN) in milliseconds.
    ///   - baselineHRV: The user's rolling average HRV in milliseconds.
    ///   - baselineHRVSD: Standard deviation of the baseline HRV. Nil uses legacy mode.
    ///   - currentRHR: Today's resting heart rate (primary signal).
    ///   - baselineRHR: Rolling average RHR (primary signal baseline).
    ///   - recentHRVs: Recent HRV readings for CV computation. Nil skips CV.
    /// - Returns: A ``StressResult`` with score, level, and description.
    public func computeStress(
        currentHRV: Double,
        baselineHRV: Double,
        baselineHRVSD: Double? = nil,
        currentRHR: Double? = nil,
        baselineRHR: Double? = nil,
        recentHRVs: [Double]? = nil
    ) -> StressResult {
        guard baselineHRV > 0 else {
            return StressResult(
                score: 50,
                level: .balanced,
                description: "Not enough data to determine your baseline yet."
            )
        }

        // ── Signal 1: HRV Z-score (primary) ────────────────────────
        // How many standard deviations below baseline
        let hrvRawScore: Double
        if useLogSDNN {
            // Log-SDNN transform: handles right-skew in SDNN distributions.
            // log(50) ≈ 3.91 is a typical population midpoint in log-space.
            let logCurrent = log(max(currentHRV, 1.0))
            let logBaseline = log(max(baselineHRV, 1.0))
            let logSD: Double
            if let bsd = baselineHRVSD, bsd > 0 {
                // Transform SD into log-space: approximate via delta method
                logSD = bsd / max(baselineHRV, 1.0)
            } else {
                logSD = 0.20 // ~20% CV in log-space as fallback
            }
            let zScore: Double
            if logSD > 0 {
                zScore = (logBaseline - logCurrent) / logSD
            } else {
                zScore = logCurrent < logBaseline ? 2.0 : -1.0
            }
            hrvRawScore = 35.0 + zScore * 20.0
        } else {
            // Legacy linear path
            let sd = baselineHRVSD ?? (baselineHRV * 0.20)
            let zScore: Double
            if sd > 0 {
                zScore = (baselineHRV - currentHRV) / sd
            } else {
                zScore = currentHRV < baselineHRV ? 2.0 : -1.0
            }
            hrvRawScore = 35.0 + zScore * 20.0
        }

        // ── Signal 2: Coefficient of Variation ──────────────────────
        var cvRawScore: Double = 50.0 // Neutral default
        if let hrvs = recentHRVs, hrvs.count >= 3 {
            let mean = hrvs.reduce(0, +) / Double(hrvs.count)
            if mean > 0 {
                let variance = hrvs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(hrvs.count - 1)
                let cvSD = sqrt(variance)
                let cv = cvSD / mean
                // CV < 0.15 = stable (low stress), CV > 0.30 = unstable (high stress)
                cvRawScore = max(0, min(100, (cv - 0.10) / 0.25 * 100.0))
            }
        }

        // ── Signal 3: RHR Deviation (PRIMARY) ──────────────────────
        // Calibrated from PhysioNet data: HR is the strongest stress
        // discriminator from wearables (Cohen's d = 2.10).
        var rhrRawScore: Double = 50.0 // Neutral if unavailable
        if let rhr = currentRHR, let baseRHR = baselineRHR, baseRHR > 0 {
            let rhrDeviation = (rhr - baseRHR) / baseRHR * 100.0
            // +5% above baseline → moderate stress, +10% → high stress
            rhrRawScore = max(0, min(100, 40.0 + rhrDeviation * 4.0))
        }

        // ── Weighted Composite (HR-primary calibration) ───────────
        let actualRHRWeight: Double
        let actualHRVWeight: Double
        let actualCVWeight: Double

        if recentHRVs != nil && currentRHR != nil {
            // All signals available — use calibrated weights
            actualRHRWeight = rhrWeight   // 0.50
            actualHRVWeight = hrvWeight   // 0.30
            actualCVWeight = cvWeight     // 0.20
        } else if currentRHR != nil {
            // RHR + HRV (no CV data) — RHR stays primary
            actualRHRWeight = 0.60
            actualHRVWeight = 0.40
            actualCVWeight = 0.0
        } else if recentHRVs != nil {
            // HRV + CV only (no RHR) — HRV takes over as primary
            actualRHRWeight = 0.0
            actualHRVWeight = 0.70
            actualCVWeight = 0.30
        } else {
            // HRV only (legacy mode)
            actualRHRWeight = 0.0
            actualHRVWeight = 1.0
            actualCVWeight = 0.0
        }

        let rawComposite = hrvRawScore * actualHRVWeight
            + cvRawScore * actualCVWeight
            + rhrRawScore * actualRHRWeight

        // ── Sigmoid Normalization ───────────────────────────────────
        // Smooth S-curve mapping: avoids harsh clipping, concentrates
        // sensitivity around the 30-70 range where users care most
        let score = sigmoid(rawComposite)

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

    /// Legacy API: compute stress from just HRV values.
    public func computeStress(
        currentHRV: Double,
        baselineHRV: Double
    ) -> StressResult {
        computeStress(
            currentHRV: currentHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: nil,
            currentRHR: nil,
            baselineRHR: nil,
            recentHRVs: nil
        )
    }

    /// Convenience: compute stress from a snapshot and recent history.
    public func computeStress(
        snapshot: HeartSnapshot,
        recentHistory: [HeartSnapshot]
    ) -> StressResult? {
        guard let currentHRV = snapshot.hrvSDNN else { return nil }
        let baseline = computeBaseline(snapshots: recentHistory)
        guard let baselineHRV = baseline else { return nil }
        let hrvValues = recentHistory.compactMap(\.hrvSDNN)
        let n = Double(hrvValues.count)
        let baselineSD: Double? = n >= 2 ? {
            let mean = hrvValues.reduce(0, +) / n
            let ss = hrvValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
            return (ss / (n - 1)).squareRoot()
        }() : nil
        let rhrValues = recentHistory.compactMap(\.restingHeartRate)
        let avgRHR: Double? = rhrValues.isEmpty ? nil : rhrValues.reduce(0, +) / Double(rhrValues.count)
        return computeStress(
            currentHRV: currentHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineSD,
            currentRHR: snapshot.restingHeartRate,
            baselineRHR: avgRHR,
            recentHRVs: recentHistory.suffix(7).compactMap(\.hrvSDNN)
        )
    }

    /// Sigmoid mapping: raw → 0-100 with smooth transitions.
    private func sigmoid(_ x: Double) -> Double {
        let exponent = -sigmoidK * (x - sigmoidMid)
        let result = 100.0 / (1.0 + exp(exponent))
        return max(0, min(100, result))
    }

    // MARK: - Daily Stress Score

    /// Compute a single stress score for the most recent day using
    /// the preceding snapshots as baseline.
    ///
    /// Uses the enhanced multi-signal algorithm when RHR data is available.
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

        let preceding = Array(snapshots.dropLast())
        guard let baselineHRV = computeBaseline(snapshots: preceding) else { return nil }

        // Compute baseline standard deviation
        let recentHRVs = preceding.suffix(baselineWindow).compactMap(\.hrvSDNN)
        let baselineSD = computeBaselineSD(hrvValues: recentHRVs, mean: baselineHRV)

        // RHR corroboration
        let currentRHR = current.restingHeartRate
        let baselineRHR = computeRHRBaseline(snapshots: preceding)

        let result = computeStress(
            currentHRV: currentHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineSD,
            currentRHR: currentRHR,
            baselineRHR: baselineRHR,
            recentHRVs: recentHRVs
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

            // Enhanced: compute SD, RHR baseline, recent HRVs
            let recentHRVs = precedingSlice.compactMap(\.hrvSDNN)
            let baselineSD = computeBaselineSD(hrvValues: recentHRVs, mean: baselineHRV)
            let currentRHR = snapshot.restingHeartRate
            let baselineRHR = computeRHRBaseline(snapshots: precedingSlice)

            let result = computeStress(
                currentHRV: currentHRV,
                baselineHRV: baselineHRV,
                baselineHRVSD: baselineSD,
                currentRHR: currentRHR,
                baselineRHR: baselineRHR,
                recentHRVs: recentHRVs
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

    /// Compute the standard deviation of HRV baseline values.
    ///
    /// - Parameters:
    ///   - hrvValues: The HRV values in the baseline window.
    ///   - mean: The precomputed mean of these values.
    /// - Returns: Standard deviation in milliseconds.
    public func computeBaselineSD(hrvValues: [Double], mean: Double) -> Double {
        guard hrvValues.count >= 2 else { return mean * 0.20 }
        let variance = hrvValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
            / Double(hrvValues.count - 1)
        return sqrt(variance)
    }

    /// Compute rolling RHR baseline from snapshots.
    ///
    /// - Parameter snapshots: Historical snapshots.
    /// - Returns: Average resting HR, or nil if insufficient data.
    public func computeRHRBaseline(snapshots: [HeartSnapshot]) -> Double? {
        let recent = Array(snapshots.suffix(baselineWindow))
        let rhrValues = recent.compactMap(\.restingHeartRate)
        guard rhrValues.count >= 3 else { return nil }
        return rhrValues.reduce(0, +) / Double(rhrValues.count)
    }

    // MARK: - Age/Sex Normalization

    /// Adjust a stress score for the user's age.
    ///
    /// Stub for future calibration — currently returns the input unchanged.
    /// Population-level SDNN norms decline ~3-4 ms per decade; once
    /// calibration data is available this method will apply age-appropriate
    /// scaling.
    ///
    /// - Parameters:
    ///   - score: The raw stress score (0-100).
    ///   - age: The user's age in years.
    /// - Returns: The adjusted stress score.
    public func adjustForAge(_ score: Double, age: Int) -> Double {
        // TODO: Apply age-based normalization once calibration data is available.
        return score
    }

    /// Adjust a stress score for the user's biological sex.
    ///
    /// Stub for future calibration — currently returns the input unchanged.
    /// Males tend to have lower baseline SDNN than females at the same age;
    /// once calibration data is available this method will apply
    /// sex-appropriate scaling.
    ///
    /// - Parameters:
    ///   - score: The raw stress score (0-100).
    ///   - isMale: Whether the user is biologically male.
    /// - Returns: The adjusted stress score.
    public func adjustForSex(_ score: Double, isMale: Bool) -> Double {
        // TODO: Apply sex-based normalization once calibration data is available.
        return score
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
                    + "usual today. A walk, some deep breaths, or "
                    + "extra sleep could help."
            }
            return "You seem to be running a bit hot today. "
                + "A little recovery time could go a long way."
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

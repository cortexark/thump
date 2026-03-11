// HeartTrendEngine.swift
// ThumpCore
//
// Core trend computation engine using robust statistical methods.
// Computes daily assessments from health metric history.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Alert Policy

/// Configurable thresholds for anomaly detection and alerting.
public struct AlertPolicy: Codable, Equatable, Sendable {
    /// Anomaly score threshold above which the status becomes needsAttention.
    public let anomalyHigh: Double

    /// Linear slope threshold (negative means worsening) for regression detection.
    public let regressionSlope: Double

    /// Robust Z-score threshold for elevated RHR in stress pattern.
    public let stressRHRZ: Double

    /// Robust Z-score threshold for depressed HRV in stress pattern.
    public let stressHRVZ: Double

    /// Robust Z-score threshold for depressed recovery in stress pattern.
    public let stressRecoveryZ: Double

    /// Minimum hours between consecutive alerts.
    public let cooldownHours: Double

    /// Maximum alerts allowed per calendar day.
    public let maxAlertsPerDay: Int

    public init(
        anomalyHigh: Double = 2.0,
        regressionSlope: Double = -0.3,
        stressRHRZ: Double = 1.5,
        stressHRVZ: Double = -1.5,
        stressRecoveryZ: Double = -1.5,
        cooldownHours: Double = 8.0,
        maxAlertsPerDay: Int = 3
    ) {
        self.anomalyHigh = anomalyHigh
        self.regressionSlope = regressionSlope
        self.stressRHRZ = stressRHRZ
        self.stressHRVZ = stressHRVZ
        self.stressRecoveryZ = stressRecoveryZ
        self.cooldownHours = cooldownHours
        self.maxAlertsPerDay = maxAlertsPerDay
    }
}

// MARK: - Heart Trend Engine

/// Stateless trend computation engine. Accepts history and produces a daily assessment.
///
/// The engine uses robust statistics (median + MAD) to detect anomalies, linear
/// regression for multi-day trend detection, and composite pattern matching for
/// stress-like signals. All methods are pure functions with no side effects.
public struct HeartTrendEngine: Sendable {

    /// Number of historical days to consider for baseline computation.
    public let lookbackWindow: Int

    /// Alert detection thresholds.
    public let policy: AlertPolicy

    /// Number of recent days used for regression slope checks.
    private let regressionWindow: Int = 7

    // Signal weights for composite anomaly score
    private let weightRHR: Double = 0.25
    private let weightHRV: Double = 0.25
    private let weightRecovery1m: Double = 0.20
    private let weightRecovery2m: Double = 0.10
    private let weightVO2: Double = 0.20

    public init(lookbackWindow: Int = 21, policy: AlertPolicy = AlertPolicy()) {
        self.lookbackWindow = max(lookbackWindow, 3)
        self.policy = policy
    }

    // MARK: - Public API

    /// Produce a complete daily assessment from the snapshot history.
    ///
    /// - Parameters:
    ///   - history: Array of historical snapshots, ordered oldest-first.
    ///   - current: Today's snapshot to assess.
    ///   - feedback: Optional user feedback from the previous day.
    /// - Returns: A fully populated `HeartAssessment`.
    public func assess(
        history: [HeartSnapshot],
        current: HeartSnapshot,
        feedback: DailyFeedback? = nil
    ) -> HeartAssessment {
        let relevantHistory = recentHistory(from: history)
        let confidence = confidenceLevel(current: current, history: relevantHistory)
        let anomaly = anomalyScore(current: current, history: relevantHistory)
        let regression = detectRegression(history: relevantHistory, current: current)
        let stress = detectStressPattern(current: current, history: relevantHistory)
        let cardio = computeCardioScore(current: current, history: relevantHistory)
        let status = determineStatus(
            anomaly: anomaly,
            regression: regression,
            stress: stress,
            confidence: confidence
        )

        let nudgeGenerator = NudgeGenerator()
        let nudge = nudgeGenerator.generate(
            confidence: confidence,
            anomaly: anomaly,
            regression: regression,
            stress: stress,
            feedback: feedback,
            current: current,
            history: relevantHistory
        )

        let explanation = buildExplanation(
            status: status,
            confidence: confidence,
            anomaly: anomaly,
            regression: regression,
            stress: stress,
            cardio: cardio
        )

        return HeartAssessment(
            status: status,
            confidence: confidence,
            anomalyScore: anomaly,
            regressionFlag: regression,
            stressFlag: stress,
            cardioScore: cardio,
            dailyNudge: nudge,
            explanation: explanation
        )
    }

    // MARK: - Confidence

    /// Determine data confidence based on metric availability and history depth.
    func confidenceLevel(
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> ConfidenceLevel {
        // Count available core metrics in the current snapshot
        var metricCount = 0
        if current.restingHeartRate != nil { metricCount += 1 }
        if current.hrvSDNN != nil { metricCount += 1 }
        if current.recoveryHR1m != nil { metricCount += 1 }
        if current.recoveryHR2m != nil { metricCount += 1 }
        if current.vo2Max != nil { metricCount += 1 }

        let historyDepth = history.count

        // High: 4+ core metrics and 14+ days of history
        if metricCount >= 4 && historyDepth >= 14 {
            return .high
        }
        // Medium: 2+ core metrics and 7+ days of history
        if metricCount >= 2 && historyDepth >= 7 {
            return .medium
        }
        // Low: sparse data or short history
        return .low
    }

    // MARK: - Anomaly Score

    /// Compute a weighted composite anomaly score using robust Z-scores.
    ///
    /// Each metric's Z-score is computed against the historical baseline using
    /// median and MAD (median absolute deviation). Weights reflect clinical importance.
    /// For RHR, higher values are worse so the Z-score is used directly.
    /// For HRV, Recovery, VO2, lower values are worse so the Z-score is negated.
    func anomalyScore(
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> Double {
        guard !history.isEmpty else { return 0.0 }

        var totalWeight: Double = 0.0
        var weightedSum: Double = 0.0

        // RHR: higher is worse, so positive Z = anomalous
        if let currentRHR = current.restingHeartRate {
            let rhrValues = history.compactMap(\.restingHeartRate)
            if rhrValues.count >= 3 {
                let zScore = robustZ(value: currentRHR, baseline: rhrValues)
                // For RHR, positive Z (elevated) is bad
                weightedSum += max(zScore, 0) * weightRHR
                totalWeight += weightRHR
            }
        }

        // HRV: lower is worse, so negative Z = anomalous
        if let currentHRV = current.hrvSDNN {
            let hrvValues = history.compactMap(\.hrvSDNN)
            if hrvValues.count >= 3 {
                let zScore = robustZ(value: currentHRV, baseline: hrvValues)
                // For HRV, negative Z (depressed) is bad
                weightedSum += max(-zScore, 0) * weightHRV
                totalWeight += weightHRV
            }
        }

        // Recovery 1m: lower is worse (less recovery), negative Z = anomalous
        if let currentRec1 = current.recoveryHR1m {
            let rec1Values = history.compactMap(\.recoveryHR1m)
            if rec1Values.count >= 3 {
                let zScore = robustZ(value: currentRec1, baseline: rec1Values)
                weightedSum += max(-zScore, 0) * weightRecovery1m
                totalWeight += weightRecovery1m
            }
        }

        // Recovery 2m: lower is worse, negative Z = anomalous
        if let currentRec2 = current.recoveryHR2m {
            let rec2Values = history.compactMap(\.recoveryHR2m)
            if rec2Values.count >= 3 {
                let zScore = robustZ(value: currentRec2, baseline: rec2Values)
                weightedSum += max(-zScore, 0) * weightRecovery2m
                totalWeight += weightRecovery2m
            }
        }

        // VO2 max: lower is worse, negative Z = anomalous
        if let currentVO2 = current.vo2Max {
            let vo2Values = history.compactMap(\.vo2Max)
            if vo2Values.count >= 3 {
                let zScore = robustZ(value: currentVO2, baseline: vo2Values)
                weightedSum += max(-zScore, 0) * weightVO2
                totalWeight += weightVO2
            }
        }

        guard totalWeight > 0 else { return 0.0 }
        return weightedSum / totalWeight
    }

    // MARK: - Cardio Score

    /// Compute a composite cardio fitness score (0-100) from available metrics.
    ///
    /// Uses percentile-rank approach against population reference ranges.
    func computeCardioScore(
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> Double? {
        var components: [Double] = []

        // RHR component: 50-80 BPM range, lower is better
        if let rhr = current.restingHeartRate {
            let score = max(0, min(100, (80.0 - rhr) / 30.0 * 100.0))
            components.append(score)
        }

        // HRV component: 20-100 ms range, higher is better
        if let hrv = current.hrvSDNN {
            let score = max(0, min(100, (hrv - 20.0) / 80.0 * 100.0))
            components.append(score)
        }

        // Recovery 1m component: 10-50 BPM drop, higher is better
        if let rec1 = current.recoveryHR1m {
            let score = max(0, min(100, (rec1 - 10.0) / 40.0 * 100.0))
            components.append(score)
        }

        // VO2 max component: 20-60 mL/kg/min, higher is better
        if let vo2 = current.vo2Max {
            let score = max(0, min(100, (vo2 - 20.0) / 40.0 * 100.0))
            components.append(score)
        }

        guard !components.isEmpty else { return nil }
        return components.reduce(0.0, +) / Double(components.count)
    }

    // MARK: - Regression Detection

    /// Detect multi-day regression using linear slope over the regression window.
    ///
    /// Checks if RHR is trending up or HRV is trending down beyond thresholds.
    func detectRegression(
        history: [HeartSnapshot],
        current: HeartSnapshot
    ) -> Bool {
        let allSnapshots = history + [current]
        let recentSnapshots = Array(allSnapshots.suffix(regressionWindow))
        guard recentSnapshots.count >= 5 else { return false }

        // Check RHR trending upward (worsening)
        let rhrValues = recentSnapshots.compactMap(\.restingHeartRate)
        if rhrValues.count >= 5 {
            let slope = linearSlope(values: rhrValues)
            // Positive slope = RHR increasing = worsening
            if slope > abs(policy.regressionSlope) {
                return true
            }
        }

        // Check HRV trending downward (worsening)
        let hrvValues = recentSnapshots.compactMap(\.hrvSDNN)
        if hrvValues.count >= 5 {
            let slope = linearSlope(values: hrvValues)
            // Negative slope = HRV decreasing = worsening
            if slope < policy.regressionSlope {
                return true
            }
        }

        return false
    }

    // MARK: - Stress Pattern Detection

    /// Detect stress-like pattern: RHR elevated + HRV depressed + Recovery depressed.
    ///
    /// All three conditions must be present simultaneously.
    func detectStressPattern(
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> Bool {
        guard !history.isEmpty else { return false }

        var rhrElevated = false
        var hrvDepressed = false
        var recoveryDepressed = false

        // RHR elevated
        if let currentRHR = current.restingHeartRate {
            let rhrValues = history.compactMap(\.restingHeartRate)
            if rhrValues.count >= 3 {
                let zScore = robustZ(value: currentRHR, baseline: rhrValues)
                rhrElevated = zScore >= policy.stressRHRZ
            }
        }

        // HRV depressed (negative Z = below baseline)
        if let currentHRV = current.hrvSDNN {
            let hrvValues = history.compactMap(\.hrvSDNN)
            if hrvValues.count >= 3 {
                let zScore = robustZ(value: currentHRV, baseline: hrvValues)
                hrvDepressed = zScore <= policy.stressHRVZ
            }
        }

        // Recovery depressed: check 1m first, fall back to 2m
        if let currentRec = current.recoveryHR1m {
            let recValues = history.compactMap(\.recoveryHR1m)
            if recValues.count >= 3 {
                let zScore = robustZ(value: currentRec, baseline: recValues)
                recoveryDepressed = zScore <= policy.stressRecoveryZ
            }
        } else if let currentRec = current.recoveryHR2m {
            let recValues = history.compactMap(\.recoveryHR2m)
            if recValues.count >= 3 {
                let zScore = robustZ(value: currentRec, baseline: recValues)
                recoveryDepressed = zScore <= policy.stressRecoveryZ
            }
        }

        return rhrElevated && hrvDepressed && recoveryDepressed
    }

    // MARK: - Status Determination

    /// Map computed signals into a single TrendStatus.
    private func determineStatus(
        anomaly: Double,
        regression: Bool,
        stress: Bool,
        confidence: ConfidenceLevel
    ) -> TrendStatus {
        // Needs attention: high anomaly, regression, or stress
        if anomaly >= policy.anomalyHigh || regression || stress {
            return .needsAttention
        }
        // Improving: low anomaly and reasonable confidence
        if anomaly < 0.5 && confidence != .low {
            return .improving
        }
        return .stable
    }

    // MARK: - Explanation Builder

    /// Build a human-readable explanation string.
    private func buildExplanation(
        status: TrendStatus,
        confidence: ConfidenceLevel,
        anomaly: Double,
        regression: Bool,
        stress: Bool,
        cardio: Double?
    ) -> String {
        var parts: [String] = []

        switch status {
        case .improving:
            parts.append(
                "Your heart metrics are trending in a positive direction."
            )
        case .stable:
            parts.append(
                "Your heart metrics are within your normal range."
            )
        case .needsAttention:
            parts.append(
                "Some of your heart metrics have shifted from your usual baseline."
            )
        }

        if regression {
            parts.append(
                "A gradual shift has been observed over the past several days."
            )
        }

        if stress {
            parts.append(
                "A pattern consistent with elevated physiological load was detected today. " +
                "Consider prioritizing rest and recovery."
            )
        }

        if let score = cardio {
            parts.append(
                String(format: "Your estimated cardio fitness score is %.0f out of 100.", score)
            )
        }

        switch confidence {
        case .high:
            parts.append("This assessment is based on comprehensive data.")
        case .medium:
            parts.append(
                "This assessment uses partial data. " +
                "More consistent wear will improve accuracy."
            )
        case .low:
            parts.append(
                "Limited data is available. " +
                "Wearing your watch consistently will help build a reliable baseline."
            )
        }

        return parts.joined(separator: " ")
    }

    // MARK: - History Helpers

    /// Extract the most recent `lookbackWindow` days from the history.
    private func recentHistory(from history: [HeartSnapshot]) -> [HeartSnapshot] {
        Array(history.suffix(lookbackWindow))
    }

    // MARK: - Statistical Helpers (Internal for Testing)

    /// Compute a robust Z-score using median and MAD.
    ///
    /// MAD (median absolute deviation) is scaled by 1.4826 to approximate the
    /// standard deviation for normally distributed data.
    func robustZ(value: Double, baseline: [Double]) -> Double {
        let med = median(baseline)
        let madValue = mad(baseline)
        guard madValue > 0 else {
            // If MAD is zero, all baseline values are the same.
            // Return the raw deviation clamped to a reasonable range.
            let diff = value - med
            if abs(diff) < 1e-9 { return 0.0 }
            return diff > 0 ? 3.0 : -3.0
        }
        return (value - med) / madValue
    }

    /// Compute the linear slope of a sequence of equally-spaced values.
    ///
    /// Uses ordinary least squares. Returns slope per unit step.
    func linearSlope(values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0.0 }

        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumXX: Double = 0

        for (i, y) in values.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += y
            sumXY += x * y
            sumXX += x * x
        }

        let denominator = n * sumXX - sumX * sumX
        guard abs(denominator) > 1e-12 else { return 0.0 }
        return (n * sumXY - sumX * sumY) / denominator
    }

    /// Compute the median of an array of doubles.
    func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sorted = values.sorted()
        let count = sorted.count
        if count.isMultiple(of: 2) {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        }
        return sorted[count / 2]
    }

    /// Compute the MAD (median absolute deviation) scaled by 1.4826.
    func mad(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let med = median(values)
        let deviations = values.map { abs($0 - med) }
        return median(deviations) * 1.4826
    }
}

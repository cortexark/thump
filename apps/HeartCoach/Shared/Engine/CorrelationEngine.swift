// CorrelationEngine.swift
// ThumpCore
//
// Pearson correlation analysis between activity factors and
// heart-health metrics. Used by the dashboard's "Insight Cards"
// to surface actionable relationships in the user's data.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Correlation Engine

/// Stateless engine that computes Pearson correlations between
/// lifestyle activity factors and cardiovascular health metrics.
///
/// The engine evaluates four factor pairs:
/// 1. **Daily Steps** vs. **Resting Heart Rate**
/// 2. **Walk Minutes** vs. **HRV (SDNN)**
/// 3. **Activity Minutes** vs. **Recovery HR (1 min)**
/// 4. **Sleep Hours** vs. **HRV (SDNN)**
///
/// A minimum of ``ConfigService/minimumCorrelationPoints`` paired
/// data points (default 7) is required for each correlation to be
/// considered meaningful. Pairs where either value is `nil` are
/// excluded before calculation.
public struct CorrelationEngine: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Analyze the snapshot history and return correlation results
    /// for all factor pairs that have sufficient data.
    ///
    /// - Parameter history: Array of ``HeartSnapshot``, ideally at
    ///   least 14 days for meaningful results.
    /// - Returns: Array of ``CorrelationResult``, one per factor
    ///   pair that meets the minimum data threshold. May be empty.
    public func analyze(history: [HeartSnapshot]) -> [CorrelationResult] {
        let minimumPoints = ConfigService.minimumCorrelationPoints
        var results: [CorrelationResult] = []

        // 1. Steps vs Resting Heart Rate
        let stepsRHR = pairedValues(
            history: history,
            xKeyPath: \.steps,
            yKeyPath: \.restingHeartRate
        )
        if stepsRHR.x.count >= minimumPoints {
            let r = pearsonCorrelation(x: stepsRHR.x, y: stepsRHR.y)
            let result = interpretCorrelation(
                factor: "Daily Steps",
                metric: "resting heart rate",
                r: r,
                expectedDirection: .negative
            )
            results.append(CorrelationResult(
                factorName: "Daily Steps",
                correlationStrength: r,
                interpretation: result.interpretation,
                confidence: result.confidence,
                isBeneficial: result.isBeneficial
            ))
        }

        // 2. Walk Minutes vs HRV
        let walkHRV = pairedValues(
            history: history,
            xKeyPath: \.walkMinutes,
            yKeyPath: \.hrvSDNN
        )
        if walkHRV.x.count >= minimumPoints {
            let r = pearsonCorrelation(x: walkHRV.x, y: walkHRV.y)
            let result = interpretCorrelation(
                factor: "Walk Minutes",
                metric: "heart rate variability",
                r: r,
                expectedDirection: .positive
            )
            results.append(CorrelationResult(
                factorName: "Walk Minutes",
                correlationStrength: r,
                interpretation: result.interpretation,
                confidence: result.confidence,
                isBeneficial: result.isBeneficial
            ))
        }

        // 3. Activity Minutes (walk + workout) vs Recovery HR 1m (ENG-3)
        let workoutRec = pairedValues(
            history: history,
            xKeyPath: \.activityMinutes,
            yKeyPath: \.recoveryHR1m
        )
        if workoutRec.x.count >= minimumPoints {
            let r = pearsonCorrelation(x: workoutRec.x, y: workoutRec.y)
            let result = interpretCorrelation(
                factor: "Activity Minutes",
                metric: "heart rate recovery",
                r: r,
                expectedDirection: .positive
            )
            results.append(CorrelationResult(
                factorName: "Activity Minutes",
                correlationStrength: r,
                interpretation: result.interpretation,
                confidence: result.confidence,
                isBeneficial: result.isBeneficial
            ))
        }

        // 4. Sleep Hours vs Resting Heart Rate (ZE-003)
        // Tobaldini et al. (2019): short sleep → elevated RHR (+2-5 bpm/hr deficit)
        // Cappuccio et al. (2010): sleep <6h → 48% increased CV risk
        let sleepRHR = pairedValues(
            history: history,
            xKeyPath: \.sleepHours,
            yKeyPath: \.restingHeartRate
        )
        if sleepRHR.x.count >= minimumPoints {
            let r = pearsonCorrelation(x: sleepRHR.x, y: sleepRHR.y)
            let result = interpretCorrelation(
                factor: "Sleep Hours",
                metric: "resting heart rate",
                r: r,
                expectedDirection: .negative  // more sleep → lower RHR
            )
            results.append(CorrelationResult(
                factorName: "Sleep Hours vs RHR",
                correlationStrength: r,
                interpretation: result.interpretation,
                confidence: result.confidence,
                isBeneficial: result.isBeneficial
            ))
        }

        // 5. Sleep Hours vs HRV
        let sleepHRV = pairedValues(
            history: history,
            xKeyPath: \.sleepHours,
            yKeyPath: \.hrvSDNN
        )
        if sleepHRV.x.count >= minimumPoints {
            let r = pearsonCorrelation(x: sleepHRV.x, y: sleepHRV.y)
            let result = interpretCorrelation(
                factor: "Sleep Hours",
                metric: "heart rate variability",
                r: r,
                expectedDirection: .positive
            )
            results.append(CorrelationResult(
                factorName: "Sleep Hours",
                correlationStrength: r,
                interpretation: result.interpretation,
                confidence: result.confidence,
                isBeneficial: result.isBeneficial
            ))
        }

        return results
    }

    // MARK: - Pearson Correlation

    /// Compute the Pearson product-moment correlation coefficient
    /// between two equal-length arrays of doubles.
    ///
    /// Returns a value in [-1.0, 1.0] where:
    /// - +1.0 = perfect positive linear relationship
    /// -  0.0 = no linear relationship
    /// - -1.0 = perfect negative linear relationship
    ///
    /// - Precondition: `x.count == y.count` and `x.count >= 2`.
    private func pearsonCorrelation(x: [Double], y: [Double]) -> Double {
        let n = Double(x.count)
        guard n >= 2 else { return 0.0 }

        let sumX  = x.reduce(0, +)
        let sumY  = y.reduce(0, +)
        let sumXY = zip(x, y).reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumX2 = x.reduce(0.0) { $0 + $1 * $1 }
        let sumY2 = y.reduce(0.0) { $0 + $1 * $1 }

        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt(
            (n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY)
        )

        guard denominator > 1e-12 else { return 0.0 }

        // Clamp to [-1, 1] to guard against floating-point drift.
        return max(-1.0, min(1.0, numerator / denominator))
    }

    // MARK: - Interpretation

    /// Expected direction of a beneficial correlation.
    private enum ExpectedDirection {
        case positive  // More activity -> higher metric is good
        case negative  // More activity -> lower metric is good
    }

    /// Generate a personal, actionable interpretation from a Pearson
    /// coefficient. Avoids clinical jargon like "correlation" or
    /// "associated with" in favour of plain language the user can act on.
    ///
    /// Strength thresholds (absolute |r|):
    /// - 0.0  ..< 0.2  : negligible
    /// - 0.2  ..< 0.4  : noticeable
    /// - 0.4  ..< 0.6  : clear
    /// - 0.6  ..< 0.8  : strong
    /// - 0.8  ... 1.0  : very consistent
    private func interpretCorrelation(
        factor: String,
        metric: String,
        r: Double,
        expectedDirection: ExpectedDirection
    ) -> (interpretation: String, confidence: ConfidenceLevel, isBeneficial: Bool) {
        let absR = abs(r)

        // Determine strength label and confidence
        let strengthLabel: String
        let confidence: ConfidenceLevel

        switch absR {
        case 0.0..<0.2:
            let factorDisplay = Self.friendlyFactor(factor)
            let metricDisplay = Self.friendlyMetric(metric)
            return (
                "We haven't found a clear link between \(factorDisplay) "
                    + "and \(metricDisplay) in your data yet. "
                    + "More days of tracking will sharpen the picture.",
                .low,
                true  // neutral — not harmful
            )
        case 0.2..<0.4:
            strengthLabel = "noticeable"
            confidence = .low
        case 0.4..<0.6:
            strengthLabel = "clear"
            confidence = .medium
        case 0.6..<0.8:
            strengthLabel = "strong"
            confidence = .high
        default: // 0.8 ... 1.0
            strengthLabel = "very consistent"
            confidence = .high
        }

        // Check whether the observed direction matches the beneficial one
        let isBeneficial: Bool
        switch expectedDirection {
        case .negative: isBeneficial = r < 0
        case .positive: isBeneficial = r > 0
        }

        let interpretation = isBeneficial
            ? Self.beneficialInterpretation(factor: factor, metric: metric, strength: strengthLabel)
            : Self.nonBeneficialInterpretation(factor: factor, metric: metric, strength: strengthLabel)

        return (interpretation, confidence, isBeneficial)
    }

    // MARK: - Interpretation Templates

    /// Personal, actionable text for factor pairs where the data shows
    /// a beneficial pattern.
    private static func beneficialInterpretation(
        factor: String,
        metric: String,
        strength: String
    ) -> String {
        switch factor {
        case "Daily Steps":
            return "On days you walk more, your resting heart rate tends to be lower. "
                + "Your data shows this \(strength) pattern \u{2014} keep it up."
        case "Walk Minutes":
            return "More walking time tracks with higher HRV in your data. "
                + "This is a \(strength) pattern worth maintaining."
        case "Activity Minutes":
            return "Active days lead to faster heart rate recovery in your data. "
                + "This \(strength) pattern shows your fitness is paying off."
        case "Sleep Hours" where metric == "resting heart rate":
            return "On nights you sleep more, your resting heart rate the next day tends to be lower. "
                + "This is a \(strength) pattern — quality sleep helps your heart recover."
        case "Sleep Hours":
            return "Longer sleep nights are followed by better HRV readings. "
                + "This is one of the \(strength)est patterns in your data."
        default:
            let factorDisplay = friendlyFactor(factor)
            let metricDisplay = friendlyMetric(metric)
            return "More \(factorDisplay) lines up with better \(metricDisplay) in your data. "
                + "This is a \(strength) pattern worth keeping."
        }
    }

    /// Personal text for factor pairs where the data doesn't show the
    /// expected beneficial direction.
    private static func nonBeneficialInterpretation(
        factor: String,
        metric: String,
        strength: String
    ) -> String {
        let factorDisplay = friendlyFactor(factor)
        let metricDisplay = friendlyMetric(metric)
        return "Your data shows more \(factorDisplay) hasn't been helping "
            + "\(metricDisplay) yet. Consider adjusting intensity or timing."
    }

    /// Convert factor names to casual, user-facing phrasing.
    private static func friendlyFactor(_ factor: String) -> String {
        switch factor {
        case "Daily Steps": return "daily steps"
        case "Walk Minutes": return "walking time"
        case "Activity Minutes": return "activity"
        case "Sleep Hours": return "sleep"
        default: return factor.lowercased()
        }
    }

    /// Convert metric names to casual, user-facing phrasing.
    private static func friendlyMetric(_ metric: String) -> String {
        switch metric {
        case "resting heart rate": return "resting heart rate"
        case "heart rate variability": return "HRV"
        case "heart rate recovery": return "heart rate recovery"
        default: return metric
        }
    }

    // MARK: - Data Pairing Helpers

    /// Extract paired non-nil values from the history for two
    /// optional key paths.
    ///
    /// Only days where both the x and y values are present are included.
    private func pairedValues(
        history: [HeartSnapshot],
        xKeyPath: KeyPath<HeartSnapshot, Double?>,
        yKeyPath: KeyPath<HeartSnapshot, Double?>
    ) -> (x: [Double], y: [Double]) {
        var xs: [Double] = []
        var ys: [Double] = []

        for snapshot in history {
            if let xVal = snapshot[keyPath: xKeyPath],
               let yVal = snapshot[keyPath: yKeyPath] {
                xs.append(xVal)
                ys.append(yVal)
            }
        }

        return (xs, ys)
    }
}

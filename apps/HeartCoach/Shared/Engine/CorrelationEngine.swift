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
/// 3. **Workout Minutes** vs. **Recovery HR (1 min)**
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
            let (interpretation, confidence) = interpretCorrelation(
                factor: "Daily Steps",
                metric: "resting heart rate",
                r: r,
                expectedDirection: .negative
            )
            results.append(CorrelationResult(
                factorName: "Daily Steps",
                correlationStrength: r,
                interpretation: interpretation,
                confidence: confidence
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
            let (interpretation, confidence) = interpretCorrelation(
                factor: "Walk Minutes",
                metric: "heart rate variability",
                r: r,
                expectedDirection: .positive
            )
            results.append(CorrelationResult(
                factorName: "Walk Minutes",
                correlationStrength: r,
                interpretation: interpretation,
                confidence: confidence
            ))
        }

        // 3. Workout Minutes vs Recovery HR 1m
        let workoutRec = pairedValues(
            history: history,
            xKeyPath: \.workoutMinutes,
            yKeyPath: \.recoveryHR1m
        )
        if workoutRec.x.count >= minimumPoints {
            let r = pearsonCorrelation(x: workoutRec.x, y: workoutRec.y)
            let (interpretation, confidence) = interpretCorrelation(
                factor: "Workout Minutes",
                metric: "heart rate recovery",
                r: r,
                expectedDirection: .positive
            )
            results.append(CorrelationResult(
                factorName: "Workout Minutes",
                correlationStrength: r,
                interpretation: interpretation,
                confidence: confidence
            ))
        }

        // 4. Sleep Hours vs HRV
        let sleepHRV = pairedValues(
            history: history,
            xKeyPath: \.sleepHours,
            yKeyPath: \.hrvSDNN
        )
        if sleepHRV.x.count >= minimumPoints {
            let r = pearsonCorrelation(x: sleepHRV.x, y: sleepHRV.y)
            let (interpretation, confidence) = interpretCorrelation(
                factor: "Sleep Hours",
                metric: "heart rate variability",
                r: r,
                expectedDirection: .positive
            )
            results.append(CorrelationResult(
                factorName: "Sleep Hours",
                correlationStrength: r,
                interpretation: interpretation,
                confidence: confidence
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

    /// Generate a human-readable interpretation and confidence level
    /// from a Pearson coefficient.
    ///
    /// Strength thresholds (absolute |r|):
    /// - 0.0  ..< 0.2  : negligible
    /// - 0.2  ..< 0.4  : weak
    /// - 0.4  ..< 0.6  : moderate
    /// - 0.6  ..< 0.8  : strong
    /// - 0.8  ... 1.0  : very strong
    private func interpretCorrelation(
        factor: String,
        metric: String,
        r: Double,
        expectedDirection: ExpectedDirection
    ) -> (String, ConfidenceLevel) {
        let absR = abs(r)

        // Determine strength label and confidence
        let strengthLabel: String
        let confidence: ConfidenceLevel

        switch absR {
        case 0.0..<0.2:
            return (
                "No meaningful relationship was found between \(factor.lowercased()) "
                    + "and \(metric) in your recent data.",
                .low
            )
        case 0.2..<0.4:
            strengthLabel = "weak"
            confidence = .low
        case 0.4..<0.6:
            strengthLabel = "moderate"
            confidence = .medium
        case 0.6..<0.8:
            strengthLabel = "strong"
            confidence = .high
        default: // 0.8 ... 1.0
            strengthLabel = "very strong"
            confidence = .high
        }

        // Determine direction description
        let directionText: String
        let isBeneficial: Bool

        switch expectedDirection {
        case .negative:
            if r < 0 {
                directionText = "Higher \(factor.lowercased()) is associated with lower \(metric)"
                isBeneficial = true
            } else {
                directionText = "Higher \(factor.lowercased()) is associated with higher \(metric)"
                isBeneficial = false
            }
        case .positive:
            if r > 0 {
                directionText = "More \(factor.lowercased()) is associated with higher \(metric)"
                isBeneficial = true
            } else {
                directionText = "More \(factor.lowercased()) is associated with lower \(metric)"
                isBeneficial = false
            }
        }

        let benefitNote = isBeneficial
            ? "This is a positive sign for your cardiovascular health."
            : "This is worth monitoring over the coming weeks."

        let interpretation = "\(directionText) "
            + "(a \(strengthLabel) \(r > 0 ? "positive" : "negative") correlation). "
            + benefitNote

        return (interpretation, confidence)
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

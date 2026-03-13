// BioAgeEngine.swift
// ThumpCore
//
// Estimates a "Bio Age" from Apple Watch health metrics. This is a
// wellness-oriented fitness age estimate — NOT a clinical biomarker.
// The calculation compares the user's current metrics against
// population-average age norms derived from published research
// (NTNU fitness age, HRV-age correlations, RHR normative data).
//
// All computation is on-device. No server calls.
//
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Bio Age Engine

/// Estimates biological/fitness age from Apple Watch health metrics.
///
/// Uses a weighted multi-metric approach inspired by the NTNU fitness
/// age formula and HRV-age research. Each metric contributes a partial
/// age offset, weighted by its predictive strength for cardiovascular
/// fitness and longevity.
///
/// **This is a wellness estimate, not a medical measurement.**
public struct BioAgeEngine: Sendable {

    // MARK: - Configuration

    /// Weights for each metric's contribution to the bio age offset.
    /// Sum to 1.0. Rebalanced per NTNU fitness age research (Nes et al.):
    /// VO2 Max reduced from 0.30→0.20; freed weight redistributed to
    /// RHR and HRV which are the next most validated predictors.
    /// BMI included per NTNU fitness age formula (waist/BMI is a primary input).
    private let weights = MetricWeights(
        vo2Max: 0.20,
        restingHR: 0.22,
        hrv: 0.22,
        sleep: 0.12,
        activity: 0.12,
        bmi: 0.12
    )

    /// Maximum age offset any single metric can contribute (years).
    private let maxOffsetPerMetric: Double = 8.0

    public init() {}

    // MARK: - Public API

    /// Compute a bio age estimate from a health snapshot and the user's
    /// chronological age, optionally stratified by biological sex.
    ///
    /// - Parameters:
    ///   - snapshot: Today's health metrics.
    ///   - chronologicalAge: The user's actual age in years.
    ///   - sex: Biological sex for norm stratification. Defaults to `.notSet`
    ///     which uses averaged male/female population norms.
    /// - Returns: A `BioAgeResult` with the estimated bio age, or nil
    ///   if insufficient data (need at least 2 of 5 metrics).
    public func estimate(
        snapshot: HeartSnapshot,
        chronologicalAge: Int,
        sex: BiologicalSex = .notSet
    ) -> BioAgeResult? {
        guard chronologicalAge > 0 else { return nil }

        let age = Double(chronologicalAge)
        var totalOffset: Double = 0
        var totalWeight: Double = 0
        var metricBreakdown: [BioAgeMetricContribution] = []

        // VO2 Max — strongest predictor
        if let vo2 = snapshot.vo2Max, vo2 > 0 {
            let expected = expectedVO2Max(for: age, sex: sex)
            // Each 1 mL/kg/min above expected ≈ 0.8 years younger (NTNU)
            let rawOffset = (expected - vo2) * 0.8
            let offset = clampOffset(rawOffset)
            totalOffset += offset * weights.vo2Max
            totalWeight += weights.vo2Max
            metricBreakdown.append(BioAgeMetricContribution(
                metric: .vo2Max,
                value: vo2,
                expectedValue: expected,
                ageOffset: offset,
                direction: offset < 0 ? .younger : (offset > 0 ? .older : .onTrack)
            ))
        }

        // Resting Heart Rate — lower is younger
        if let rhr = snapshot.restingHeartRate, rhr > 0 {
            let expected = expectedRHR(for: age, sex: sex)
            // Each 1 bpm below expected ≈ 0.4 years younger
            let rawOffset = (rhr - expected) * 0.4
            let offset = clampOffset(rawOffset)
            totalOffset += offset * weights.restingHR
            totalWeight += weights.restingHR
            metricBreakdown.append(BioAgeMetricContribution(
                metric: .restingHR,
                value: rhr,
                expectedValue: expected,
                ageOffset: offset,
                direction: offset < 0 ? .younger : (offset > 0 ? .older : .onTrack)
            ))
        }

        // HRV (SDNN) — higher is younger
        if let hrv = snapshot.hrvSDNN, hrv > 0 {
            let expected = expectedHRV(for: age, sex: sex)
            // Each 1ms above expected ≈ 0.15 years younger
            let rawOffset = (expected - hrv) * 0.15
            let offset = clampOffset(rawOffset)
            totalOffset += offset * weights.hrv
            totalWeight += weights.hrv
            metricBreakdown.append(BioAgeMetricContribution(
                metric: .hrv,
                value: hrv,
                expectedValue: expected,
                ageOffset: offset,
                direction: offset < 0 ? .younger : (offset > 0 ? .older : .onTrack)
            ))
        }

        // Sleep — optimal zone is 7-9 hours (flat, no penalty within zone)
        if let sleep = snapshot.sleepHours, sleep > 0 {
            let optimalLow = 7.0
            let optimalHigh = 9.0
            let deviation: Double
            if sleep < optimalLow {
                deviation = optimalLow - sleep
            } else if sleep > optimalHigh {
                deviation = sleep - optimalHigh
            } else {
                deviation = 0  // Within 7-9hr zone = no penalty
            }
            // Each hour outside optimal zone ≈ 1.5 years older
            let rawOffset = deviation * 1.5
            let offset = clampOffset(rawOffset)
            totalOffset += offset * weights.sleep
            totalWeight += weights.sleep
            metricBreakdown.append(BioAgeMetricContribution(
                metric: .sleep,
                value: sleep,
                expectedValue: 8.0,
                ageOffset: offset,
                direction: deviation < 0.3 ? .onTrack : .older
            ))
        }

        // Active Minutes (walk + workout) — more is younger
        let walkMin = snapshot.walkMinutes ?? 0
        let workoutMin = snapshot.workoutMinutes ?? 0
        let activeMin = walkMin + workoutMin
        if activeMin > 0 {
            let expectedActive = expectedActiveMinutes(for: age)
            // Each 10 min above expected ≈ 0.5 years younger
            let rawOffset = (expectedActive - activeMin) * 0.05
            let offset = clampOffset(rawOffset)
            totalOffset += offset * weights.activity
            totalWeight += weights.activity
            metricBreakdown.append(BioAgeMetricContribution(
                metric: .activeMinutes,
                value: activeMin,
                expectedValue: expectedActive,
                ageOffset: offset,
                direction: offset < 0 ? .younger : (offset > 0 ? .older : .onTrack)
            ))
        }

        // BMI — optimal zone 22-25 (NTNU fitness age, WHO longevity data)
        // Requires both weight and a user-provided height (stored in profile).
        // For now we use weight alone against age-expected BMI ranges,
        // using sex-stratified average height. When height is available, use actual BMI.
        if let weightKg = snapshot.bodyMassKg, weightKg > 0 {
            let optimalBMI = 23.5  // Center of longevity-optimal 22-25 range
            // Sex-stratified average heights (WHO global data):
            // Male: ~1.75m → heightSq = 3.0625
            // Female: ~1.62m → heightSq = 2.6244
            // Averaged: ~1.70m → heightSq = 2.89
            let heightSq: Double = switch sex {
            case .male: 3.0625
            case .female: 2.6244
            case .notSet: 2.89
            }
            let estimatedBMI = weightKg / heightSq
            let deviation = abs(estimatedBMI - optimalBMI)
            // Each BMI point away from optimal ≈ 0.6 years older
            let rawOffset = deviation * 0.6
            let offset = clampOffset(rawOffset)
            totalOffset += offset * weights.bmi
            totalWeight += weights.bmi
            metricBreakdown.append(BioAgeMetricContribution(
                metric: .bmi,
                value: estimatedBMI,
                expectedValue: optimalBMI,
                ageOffset: offset,
                direction: deviation < 1.5 ? .onTrack : .older
            ))
        }

        // Need at least 2 metrics for a meaningful estimate
        guard totalWeight >= 0.3 else { return nil }

        // Normalize the offset by actual weight coverage
        let normalizedOffset = totalOffset / totalWeight
        let bioAge = max(16, age + normalizedOffset)
        let roundedBioAge = Int(round(bioAge))
        let difference = roundedBioAge - chronologicalAge

        let category: BioAgeCategory
        if difference <= -5 {
            category = .excellent
        } else if difference <= -2 {
            category = .good
        } else if difference <= 2 {
            category = .onTrack
        } else if difference <= 5 {
            category = .watchful
        } else {
            category = .needsWork
        }

        return BioAgeResult(
            bioAge: roundedBioAge,
            chronologicalAge: chronologicalAge,
            difference: difference,
            category: category,
            metricsUsed: metricBreakdown.count,
            breakdown: metricBreakdown,
            explanation: buildExplanation(
                category: category,
                difference: difference,
                breakdown: metricBreakdown
            )
        )
    }

    /// Compute bio age from a history of snapshots (uses the most recent).
    public func estimate(
        history: [HeartSnapshot],
        chronologicalAge: Int,
        sex: BiologicalSex = .notSet
    ) -> BioAgeResult? {
        guard let latest = history.last else { return nil }
        return estimate(snapshot: latest, chronologicalAge: chronologicalAge, sex: sex)
    }

    // MARK: - Age-Normative Expected Values

    /// Expected VO2 Max by age and sex (mL/kg/min).
    /// Based on ACSM percentile data, 50th percentile.
    /// Males typically 15-20% higher than females (ACSM 2022 guidelines).
    private func expectedVO2Max(for age: Double, sex: BiologicalSex) -> Double {
        let base: Double = switch age {
        case ..<25:  42.0
        case 25..<35: 40.0
        case 35..<45: 37.0
        case 45..<55: 34.0
        case 55..<65: 30.0
        case 65..<75: 26.0
        default:      23.0
        }
        // Sex adjustment: males ~+4, females ~-4 from averaged norm
        return switch sex {
        case .male: base + 4.0
        case .female: base - 4.0
        case .notSet: base
        }
    }

    /// Expected resting heart rate by age and sex (bpm).
    /// Population average from AHA data.
    /// Females typically 2-4 bpm higher than males (AHA 2023).
    private func expectedRHR(for age: Double, sex: BiologicalSex) -> Double {
        let base: Double = switch age {
        case ..<25:  68.0
        case 25..<35: 69.0
        case 35..<45: 70.0
        case 45..<55: 71.0
        case 55..<65: 72.0
        case 65..<75: 73.0
        default:      74.0
        }
        // Sex adjustment: males ~-1.5, females ~+1.5
        return switch sex {
        case .male: base - 1.5
        case .female: base + 1.5
        case .notSet: base
        }
    }

    /// Expected HRV SDNN by age and sex (ms).
    /// From Nunan et al. meta-analysis and MyBioAge reference data.
    /// Males typically have 5-10ms higher HRV than females (Koenig 2016).
    private func expectedHRV(for age: Double, sex: BiologicalSex) -> Double {
        let base: Double = switch age {
        case ..<25:  60.0
        case 25..<35: 52.0
        case 35..<45: 44.0
        case 45..<55: 38.0
        case 55..<65: 32.0
        case 65..<75: 28.0
        default:      24.0
        }
        // Sex adjustment: males ~+3, females ~-3
        return switch sex {
        case .male: base + 3.0
        case .female: base - 3.0
        case .notSet: base
        }
    }

    /// Expected daily active minutes by age.
    /// Based on WHO recommendation of 150 min/week moderate activity.
    private func expectedActiveMinutes(for age: Double) -> Double {
        switch age {
        case ..<35:  return 30.0  // ~210 min/week
        case 35..<55: return 25.0  // ~175 min/week
        case 55..<70: return 20.0  // ~140 min/week
        default:      return 15.0  // ~105 min/week
        }
    }

    // MARK: - Helpers

    private func clampOffset(_ offset: Double) -> Double {
        max(-maxOffsetPerMetric, min(maxOffsetPerMetric, offset))
    }

    private func buildExplanation(
        category: BioAgeCategory,
        difference: Int,
        breakdown: [BioAgeMetricContribution]
    ) -> String {
        let strongestYounger = breakdown
            .filter { $0.direction == .younger }
            .sorted { $0.ageOffset < $1.ageOffset }
            .first

        let strongestOlder = breakdown
            .filter { $0.direction == .older }
            .sorted { $0.ageOffset > $1.ageOffset }
            .first

        var parts: [String] = []

        switch category {
        case .excellent:
            parts.append("Your metrics suggest your body is performing well below your actual age.")
        case .good:
            parts.append("Your body is showing signs of being a bit younger than your calendar age.")
        case .onTrack:
            parts.append("Your metrics are right around where they should be for your age.")
        case .watchful:
            parts.append("Some of your metrics are a bit above typical for your age.")
        case .needsWork:
            parts.append("Your metrics suggest there's room for improvement.")
        }

        if let best = strongestYounger {
            parts.append("Your \(best.metric.displayName.lowercased()) is a strong point.")
        }

        if let worst = strongestOlder, category != .excellent {
            parts.append("Improving your \(worst.metric.displayName.lowercased()) could make the biggest difference.")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Metric Weights

private struct MetricWeights {
    let vo2Max: Double
    let restingHR: Double
    let hrv: Double
    let sleep: Double
    let activity: Double
    let bmi: Double
}

// MARK: - Bio Age Result

/// The output of a bio age estimation.
public struct BioAgeResult: Codable, Equatable, Sendable {
    /// Estimated biological/fitness age in years.
    public let bioAge: Int

    /// The user's actual chronological age.
    public let chronologicalAge: Int

    /// Difference: bioAge - chronologicalAge. Negative = younger.
    public let difference: Int

    /// Overall category based on the difference.
    public let category: BioAgeCategory

    /// How many of the 5 metrics were available for computation.
    public let metricsUsed: Int

    /// Per-metric breakdown showing each contribution.
    public let breakdown: [BioAgeMetricContribution]

    /// Human-readable explanation of the result.
    public let explanation: String
}

// MARK: - Bio Age Category

/// Overall bio age assessment category.
public enum BioAgeCategory: String, Codable, Equatable, Sendable {
    case excellent    // 5+ years younger
    case good         // 2-5 years younger
    case onTrack      // within 2 years
    case watchful     // 2-5 years older
    case needsWork    // 5+ years older

    /// Friendly display label.
    public var displayLabel: String {
        switch self {
        case .excellent:  return "Excellent"
        case .good:       return "Looking Good"
        case .onTrack:    return "On Track"
        case .watchful:   return "Room to Grow"
        case .needsWork:  return "Let's Work on It"
        }
    }

    /// SF Symbol icon.
    public var icon: String {
        switch self {
        case .excellent:  return "star.fill"
        case .good:       return "arrow.up.heart.fill"
        case .onTrack:    return "checkmark.circle.fill"
        case .watchful:   return "exclamationmark.circle.fill"
        case .needsWork:  return "arrow.triangle.2.circlepath"
        }
    }

    /// Color name for SwiftUI tinting.
    public var colorName: String {
        switch self {
        case .excellent:  return "bioAgeExcellent"
        case .good:       return "bioAgeGood"
        case .onTrack:    return "bioAgeOnTrack"
        case .watchful:   return "bioAgeWatchful"
        case .needsWork:  return "bioAgeNeedsWork"
        }
    }
}

// MARK: - Bio Age Metric Type

/// The metrics that contribute to the bio age score.
public enum BioAgeMetricType: String, Codable, Equatable, Sendable {
    case vo2Max
    case restingHR
    case hrv
    case sleep
    case activeMinutes
    case bmi

    /// Display name for UI.
    public var displayName: String {
        switch self {
        case .vo2Max:         return "Cardio Fitness"
        case .restingHR:      return "Resting Heart Rate"
        case .hrv:            return "Heart Rate Variability"
        case .sleep:          return "Sleep"
        case .activeMinutes:  return "Activity"
        case .bmi:            return "Body Composition"
        }
    }

    /// SF Symbol icon.
    public var icon: String {
        switch self {
        case .vo2Max:         return "lungs.fill"
        case .restingHR:      return "heart.fill"
        case .hrv:            return "waveform.path.ecg"
        case .sleep:          return "bed.double.fill"
        case .activeMinutes:  return "figure.run"
        case .bmi:            return "scalemass.fill"
        }
    }
}

// MARK: - Age Direction

/// Whether a metric is pulling the bio age younger or older.
public enum BioAgeDirection: String, Codable, Equatable, Sendable {
    case younger
    case onTrack
    case older
}

// MARK: - Bio Age Metric Contribution

/// How a single metric contributes to the overall bio age score.
public struct BioAgeMetricContribution: Codable, Equatable, Sendable {
    /// Which metric this represents.
    public let metric: BioAgeMetricType

    /// The user's actual value for this metric.
    public let value: Double

    /// The population-expected value for their age.
    public let expectedValue: Double

    /// The age offset this metric contributes (negative = younger).
    public let ageOffset: Double

    /// Direction this metric is pulling.
    public let direction: BioAgeDirection
}

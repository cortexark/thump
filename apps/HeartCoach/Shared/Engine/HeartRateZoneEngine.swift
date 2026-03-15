// HeartRateZoneEngine.swift
// ThumpCore
//
// Heart rate zone computation using the Karvonen formula (heart rate
// reserve method) with age-predicted max HR. Tracks daily zone
// distribution and generates coaching recommendations based on
// AHA/ACSM exercise guidelines.
//
// Zone Model (5 zones):
//   Zone 1: 50-60% HRR  — Recovery / warm-up
//   Zone 2: 60-70% HRR  — Fat burn / base endurance
//   Zone 3: 70-80% HRR  — Aerobic / cardio fitness
//   Zone 4: 80-90% HRR  — Threshold / performance
//   Zone 5: 90-100% HRR — Peak / VO2max intervals
//
// All computation is on-device. No server calls.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Heart Rate Zone Engine

/// Computes personal heart rate zones and evaluates daily zone distribution
/// against evidence-based targets for cardiovascular health.
///
/// Uses the Karvonen method (% of Heart Rate Reserve) which accounts for
/// individual fitness level via resting HR, producing more accurate zones
/// than flat %HRmax methods.
///
/// **This is a wellness tool, not a medical device.**
public struct HeartRateZoneEngine: Sendable {

    public init() {}

    // MARK: - Zone Computation

    /// Compute personalized HR zones using the Karvonen formula.
    ///
    /// HRR = HRmax - HRrest
    /// Zone boundary = HRrest + (intensity% × HRR)
    ///
    /// - Parameters:
    ///   - age: User's age in years.
    ///   - restingHR: Resting heart rate (bpm). Uses 70 if nil.
    ///   - sex: Biological sex for HRmax formula selection.
    /// - Returns: Array of 5 ``HeartRateZone`` with personalized boundaries.
    public func computeZones(
        age: Int,
        restingHR: Double? = nil,
        sex: BiologicalSex = .notSet
    ) -> [HeartRateZone] {
        let maxHR = estimateMaxHR(age: age, sex: sex)
        let rhr = restingHR ?? 70.0
        let hrr = maxHR - rhr

        let definitions: [(HeartRateZoneType, Double, Double)] = [
            (.recovery,   0.50, 0.60),
            (.fatBurn,    0.60, 0.70),
            (.aerobic,    0.70, 0.80),
            (.threshold,  0.80, 0.90),
            (.peak,       0.90, 1.00)
        ]

        return definitions.map { zoneType, lowPct, highPct in
            HeartRateZone(
                type: zoneType,
                lowerBPM: Int(round(rhr + lowPct * hrr)),
                upperBPM: Int(round(rhr + highPct * hrr)),
                lowerPercent: lowPct,
                upperPercent: highPct
            )
        }
    }

    // MARK: - Max HR Estimation

    /// Estimate maximum heart rate using sex-specific formulas:
    ///
    /// - **Male**: Tanaka et al. (2001, n=18,712): HRmax = 208 − 0.7 × age
    /// - **Female**: Gulati et al. (2010, n=5,437): HRmax = 206 − 0.88 × age
    /// - **notSet**: Average of both formulas
    ///
    /// The Gulati formula was derived from the St. James Women Take Heart
    /// Project and produces lower max HR estimates for women, especially
    /// at older ages (e.g. age 60: Tanaka 166, Gulati 153 — 13 bpm gap).
    /// This shifts all zone boundaries meaningfully. (ZE-002 fix)
    ///
    /// A floor of 150 bpm prevents pathological zones at extreme ages.
    func estimateMaxHR(age: Int, sex: BiologicalSex) -> Double {
        let ageD = Double(age)
        let tanaka = 208.0 - 0.7 * ageD   // Tanaka et al. 2001
        let gulati = 206.0 - 0.88 * ageD  // Gulati et al. 2010
        let base: Double = switch sex {
        case .female: gulati
        case .male:   tanaka
        case .notSet: (tanaka + gulati) / 2.0
        }
        return max(base, 150.0)
    }

    // MARK: - Zone Distribution Analysis

    /// Analyze a day's zone minutes against evidence-based targets.
    ///
    /// AHA/ACSM weekly targets (converted to daily):
    /// - Zone 1-2: No limit (base activity)
    /// - Zone 3 (aerobic): ~22 min/day (150 min/week moderate)
    /// - Zone 4 (threshold): ~5-10 min/day (for cardiac adaptation)
    /// - Zone 5 (peak): ~2-5 min/day (for VO2max improvement)
    ///
    /// "80/20 rule": ~80% of training in zones 1-2, ~20% in zones 3-5.
    ///
    /// - Parameters:
    ///   - zoneMinutes: Array of 5 doubles (zone 1-5 minutes).
    ///   - fitnessLevel: User's approximate fitness level for target adjustment.
    /// - Returns: A ``ZoneAnalysis`` with targets, completion, and coaching.
    public func analyzeZoneDistribution(
        zoneMinutes: [Double],
        fitnessLevel: FitnessLevel = .moderate
    ) -> ZoneAnalysis {
        guard zoneMinutes.count >= 5 else {
            return ZoneAnalysis(
                pillars: [],
                overallScore: 0,
                coachingMessage: "Not enough zone data available today.",
                recommendation: nil
            )
        }

        let totalMinutes = zoneMinutes.reduce(0, +)
        guard totalMinutes > 0 else {
            return ZoneAnalysis(
                pillars: [],
                overallScore: 0,
                coachingMessage: "No heart rate zone data recorded today.",
                recommendation: .needsMoreActivity
            )
        }

        let targets = dailyTargets(for: fitnessLevel)
        var pillars: [ZonePillar] = []

        for (index, zoneType) in HeartRateZoneType.allCases.enumerated() {
            guard index < zoneMinutes.count, index < targets.count else { break }
            let actual = zoneMinutes[index]
            let target = targets[index]
            let completion = target > 0 ? min(actual / target, 2.0) : (actual > 0 ? 1.5 : 1.0)

            pillars.append(ZonePillar(
                zone: zoneType,
                actualMinutes: actual,
                targetMinutes: target,
                completion: completion
            ))
        }

        // Compute overall score (0-100)
        // Weight zones 3-5 more heavily since they drive adaptation
        let weights: [Double] = [0.10, 0.15, 0.35, 0.25, 0.15]
        let weightedScore = zip(pillars, weights).map { pillar, weight in
            min(pillar.completion, 1.0) * 100.0 * weight
        }.reduce(0, +)

        let score = Int(round(min(weightedScore, 100)))

        // Zone ratio check (80/20 principle)
        let hardMinutes = zoneMinutes[2] + zoneMinutes[3] + zoneMinutes[4]
        let hardRatio = totalMinutes > 0 ? hardMinutes / totalMinutes : 0

        let coaching = buildCoachingMessage(
            pillars: pillars,
            score: score,
            hardRatio: hardRatio,
            totalMinutes: totalMinutes
        )

        let recommendation = determineRecommendation(
            pillars: pillars,
            hardRatio: hardRatio,
            totalMinutes: totalMinutes
        )

        return ZoneAnalysis(
            pillars: pillars,
            overallScore: score,
            coachingMessage: coaching,
            recommendation: recommendation
        )
    }

    // MARK: - Daily Targets

    /// Evidence-based daily zone targets by fitness level (minutes).
    private func dailyTargets(for level: FitnessLevel) -> [Double] {
        switch level {
        case .beginner:
            // Focus on zone 2, minimal high-intensity
            return [60, 30, 15, 3, 0]
        case .moderate:
            // Balanced: strong zone 2-3 base, some threshold
            return [45, 30, 22, 7, 2]
        case .active:
            // Performance-oriented: more zone 3-4
            return [30, 25, 25, 12, 5]
        case .athletic:
            // Competitive: significant zone 3-5
            return [20, 20, 30, 15, 8]
        }
    }

    // MARK: - Coaching Messages

    private func buildCoachingMessage(
        pillars: [ZonePillar],
        score: Int,
        hardRatio: Double,
        totalMinutes: Double
    ) -> String {
        if totalMinutes < 15 {
            return "You haven't spent much time in your heart rate zones today. "
                + "Even a 15-minute brisk walk can get you into zone 2-3."
        }

        if score >= 80 {
            return "Excellent zone distribution today! You're hitting your targets "
                + "across all zones. This kind of balanced training builds real fitness."
        }

        if hardRatio > 0.40 {
            return "You're pushing hard today — over \(Int(hardRatio * 100))% in high zones. "
                + "Balance is key: most training should be in zones 1-2 for sustainable gains."
        }

        if hardRatio < 0.10 && totalMinutes > 30 {
            return "You've been active but mostly in easy zones. "
                + "Adding a few minutes in zone 3 (brisk walk or jog) would boost your cardio fitness."
        }

        // Check which zone needs the most attention
        let aerobicPillar = pillars.first { $0.zone == .aerobic }
        if let aerobic = aerobicPillar, aerobic.completion < 0.5 {
            return "Your aerobic zone (zone 3) could use more time today. "
                + "This is where your heart gets the most benefit — try a brisk walk or bike ride."
        }

        return "You're making progress on your zone targets. Keep mixing "
            + "easy and moderate-intensity activities for the best results."
    }

    private func determineRecommendation(
        pillars: [ZonePillar],
        hardRatio: Double,
        totalMinutes: Double
    ) -> ZoneRecommendation? {
        if totalMinutes < 15 {
            return .needsMoreActivity
        }
        if hardRatio > 0.40 {
            return .tooMuchIntensity
        }

        let aerobicCompletion = pillars.first { $0.zone == .aerobic }?.completion ?? 0
        if aerobicCompletion < 0.5 {
            return .needsMoreAerobic
        }

        let thresholdCompletion = pillars.first { $0.zone == .threshold }?.completion ?? 0
        if thresholdCompletion < 0.3 && totalMinutes > 30 {
            return .needsMoreThreshold
        }

        if hardRatio >= 0.15 && hardRatio <= 0.25 {
            return .perfectBalance
        }

        return nil
    }

    // MARK: - Weekly Zone Summary

    /// Compute a weekly zone summary from daily snapshots.
    ///
    /// - Parameters:
    ///   - history: Recent daily snapshots with zone minutes.
    ///   - referenceDate: Anchor date for the 7-day window. Defaults to
    ///     the latest snapshot date (or wall-clock ``Date()`` if history
    ///     is empty). Using snapshot dates makes the function deterministic
    ///     and testable with historical data. (ZE-001 fix)
    /// - Returns: A ``WeeklyZoneSummary`` or nil if no zone data.
    public func weeklyZoneSummary(
        history: [HeartSnapshot],
        referenceDate: Date? = nil
    ) -> WeeklyZoneSummary? {
        let calendar = Calendar.current
        let refDate = referenceDate ?? history.last?.date ?? Date()
        let today = calendar.startOfDay(for: refDate)
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else {
            return nil
        }

        let thisWeek = history.filter { $0.date >= weekAgo }
        let zoneData = thisWeek.map(\.zoneMinutes).filter { $0.count >= 5 }
        guard !zoneData.isEmpty else { return nil }

        var weeklyTotals: [Double] = [0, 0, 0, 0, 0]
        for daily in zoneData {
            for i in 0..<5 {
                weeklyTotals[i] += daily[i]
            }
        }

        let totalMinutes = weeklyTotals.reduce(0, +)
        let moderateMinutes = weeklyTotals[2] + weeklyTotals[3] // Zones 3-4
        let vigorousMinutes = weeklyTotals[4] // Zone 5

        // AHA weekly targets: 150 min moderate OR 75 min vigorous
        // Combined formula: moderate + 2 × vigorous >= 150
        let ahaScore = moderateMinutes + 2.0 * vigorousMinutes
        let ahaCompletion = min(ahaScore / 150.0, 1.0)

        return WeeklyZoneSummary(
            weeklyTotals: weeklyTotals,
            totalMinutes: totalMinutes,
            ahaCompletion: ahaCompletion,
            daysWithData: zoneData.count,
            topZone: HeartRateZoneType.allCases[weeklyTotals.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0]
        )
    }
}

// MARK: - Fitness Level

/// Approximate user fitness level for target calibration.
public enum FitnessLevel: String, Codable, Equatable, Sendable {
    case beginner
    case moderate
    case active
    case athletic

    /// Infer fitness level from VO2 Max and age.
    public static func infer(vo2Max: Double?, age: Int) -> FitnessLevel {
        guard let vo2 = vo2Max else { return .moderate }
        let ageDouble = Double(age)

        // ACSM percentile-based classification
        let threshold: (beginner: Double, active: Double, athletic: Double)
        switch ageDouble {
        case ..<30:  threshold = (30, 42, 50)
        case 30..<40: threshold = (28, 38, 46)
        case 40..<50: threshold = (25, 35, 42)
        case 50..<60: threshold = (22, 32, 38)
        default:      threshold = (20, 28, 34)
        }

        if vo2 >= threshold.athletic { return .athletic }
        if vo2 >= threshold.active { return .active }
        if vo2 >= threshold.beginner { return .moderate }
        return .beginner
    }
}

// MARK: - Heart Rate Zone Type

/// The five training zones based on heart rate reserve.
public enum HeartRateZoneType: Int, Codable, Equatable, Sendable, CaseIterable {
    case recovery = 1
    case fatBurn = 2
    case aerobic = 3
    case threshold = 4
    case peak = 5

    public var displayName: String {
        switch self {
        case .recovery:  return "Recovery"
        case .fatBurn:   return "Fat Burn"
        case .aerobic:   return "Aerobic"
        case .threshold: return "Threshold"
        case .peak:      return "Peak"
        }
    }

    public var shortName: String {
        "Z\(rawValue)"
    }

    public var icon: String {
        switch self {
        case .recovery:  return "heart.fill"
        case .fatBurn:   return "flame.fill"
        case .aerobic:   return "wind"
        case .threshold: return "bolt.fill"
        case .peak:      return "bolt.heart.fill"
        }
    }

    public var colorName: String {
        switch self {
        case .recovery:  return "zoneRecovery"   // Light blue
        case .fatBurn:   return "zoneFatBurn"     // Green
        case .aerobic:   return "zoneAerobic"     // Yellow
        case .threshold: return "zoneThreshold"   // Orange
        case .peak:      return "zonePeak"        // Red
        }
    }

    /// Fallback color for when asset catalog colors aren't available.
    public var fallbackHex: String {
        switch self {
        case .recovery:  return "#64B5F6"
        case .fatBurn:   return "#81C784"
        case .aerobic:   return "#FFD54F"
        case .threshold: return "#FFB74D"
        case .peak:      return "#E57373"
        }
    }
}

// MARK: - Heart Rate Zone

/// A single HR zone with personalized BPM boundaries.
public struct HeartRateZone: Codable, Equatable, Sendable {
    public let type: HeartRateZoneType
    public let lowerBPM: Int
    public let upperBPM: Int
    public let lowerPercent: Double
    public let upperPercent: Double

    public var displayRange: String {
        "\(lowerBPM)-\(upperBPM) bpm"
    }
}

// MARK: - Zone Analysis

/// Result of analyzing daily zone distribution against targets.
public struct ZoneAnalysis: Codable, Equatable, Sendable {
    public let pillars: [ZonePillar]
    public let overallScore: Int
    public let coachingMessage: String
    public let recommendation: ZoneRecommendation?
}

// MARK: - Zone Pillar

/// A single zone's actual vs target comparison.
public struct ZonePillar: Codable, Equatable, Sendable {
    public let zone: HeartRateZoneType
    public let actualMinutes: Double
    public let targetMinutes: Double
    /// 0.0 = none, 1.0 = fully met, >1.0 = exceeded
    public let completion: Double
}

// MARK: - Zone Recommendation

/// Actionable recommendation based on zone analysis.
public enum ZoneRecommendation: String, Codable, Equatable, Sendable {
    case needsMoreActivity
    case needsMoreAerobic
    case needsMoreThreshold
    case tooMuchIntensity
    case perfectBalance

    public var title: String {
        switch self {
        case .needsMoreActivity:  return "Get Moving"
        case .needsMoreAerobic:   return "Build Your Aerobic Base"
        case .needsMoreThreshold: return "Push a Little Harder"
        case .tooMuchIntensity:   return "Easy Does It"
        case .perfectBalance:     return "Perfect Balance"
        }
    }

    public var description: String {
        switch self {
        case .needsMoreActivity:
            return "Try a 15-20 minute brisk walk to start building your zone minutes."
        case .needsMoreAerobic:
            return "Add more zone 3 time — a brisk walk or light jog where you can still talk but not sing."
        case .needsMoreThreshold:
            return "Mix in some tempo efforts — short bursts where your breathing is heavy but controlled."
        case .tooMuchIntensity:
            return "Ease off today. Too many hard sessions back-to-back can wear you down. Try a gentle walk or rest."
        case .perfectBalance:
            return "You're nailing the 80/20 balance. Keep this up for sustainable fitness gains."
        }
    }

    public var icon: String {
        switch self {
        case .needsMoreActivity:  return "figure.walk"
        case .needsMoreAerobic:   return "heart.fill"
        case .needsMoreThreshold: return "bolt.fill"
        case .tooMuchIntensity:   return "moon.zzz.fill"
        case .perfectBalance:     return "star.fill"
        }
    }
}

// MARK: - Weekly Zone Summary

/// Weekly aggregation of zone training.
public struct WeeklyZoneSummary: Codable, Equatable, Sendable {
    /// Total minutes per zone for the week.
    public let weeklyTotals: [Double]
    /// Total training minutes.
    public let totalMinutes: Double
    /// AHA guideline completion (0-1): (moderate + 2×vigorous) / 150.
    public let ahaCompletion: Double
    /// Number of days with zone data.
    public let daysWithData: Int
    /// Most-used zone this week.
    public let topZone: HeartRateZoneType
}

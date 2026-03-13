// MockData.swift
// ThumpCore
//
// Realistic mock data generators for SwiftUI previews, unit tests,
// and snapshot testing. Values are modelled after typical Apple Watch
// users with moderate fitness levels.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Mock Data

/// Static generators and sample instances for previews and tests.
///
/// All numeric ranges mirror real-world Apple Watch data for a
/// moderately active adult (age 30-50):
/// - Resting HR: 58-72 BPM
/// - HRV (SDNN): 30-65 ms
/// - VO2 max: 32-48 mL/kg/min
/// - Steps: 4 000-12 000
/// - Walk minutes: 15-60
/// - Workout minutes: 0-45
/// - Sleep hours: 5.5-8.5
/// - Recovery HR (1 min): 18-38 BPM drop
/// - Recovery HR (2 min): 30-52 BPM drop
public enum MockData {

    // MARK: - Seeded Random Helpers

    /// Deterministic pseudo-random Double in [min, max] based on seed.
    private static func seededRandom(
        min: Double,
        max: Double,
        seed: Int
    ) -> Double {
        // Simple LCG (linear congruential generator) for reproducibility.
        var state = UInt64(abs(seed) &+ 1)
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let fraction = Double(state >> 33) / Double(UInt32.max)
        return min + fraction * (max - min)
    }

    /// Optional value generator -- returns `nil` roughly `nilChance`
    /// fraction of the time.
    private static func optionalValue(
        min: Double,
        max: Double,
        seed: Int,
        nilChance: Double = 0.1
    ) -> Double? {
        let roll = seededRandom(min: 0, max: 1, seed: seed &* 31)
        if roll < nilChance { return nil }
        return seededRandom(min: min, max: max, seed: seed)
    }

    // MARK: - Real Heart Data (Feb 9 – Mar 12 2026)

    /// 32-day record sourced from the user's actual Apple Watch export.
    /// Mar 12 is a partial day (12:15 AM snapshot) — overnight values only.
    /// Fields directly from the export: date, restingHR, HRV, avgHR, maxHR, walkingHR.
    /// Fields derived physiologically:
    ///   steps        ← walkingHR presence + avg-HR elevation above resting
    ///   walkMinutes  ← walkingHR availability (present = active walk day)
    ///   workoutMin   ← maxHR spikes above 130 bpm (indicates workout effort)
    ///   sleepHours   ← respiratory rate (higher resp → lighter/shorter sleep)
    ///   vo2Max       ← Cooper estimate: 15 × (maxHR / restingHR), capped 28–52
    ///   recoveryHR   ← maxHR − restingHR difference scaled to typical drop range
    ///   zoneMinutes  ← proportions inferred from max/avg/resting HR spread
    private struct RealDay {
        let date: Date
        let rhr: Double?        // Resting HR bpm
        let hrv: Double?        // HRV SDNN ms
        let avgHR: Double       // Avg HR bpm
        let maxHR: Double       // Max HR bpm
        let walkHR: Double?     // Walking HR bpm (nil = no walk data)
        let respRate: Double?   // Respiratory rate br/min
    }

    private static let realDays: [RealDay] = {
        // Date component helper
        func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
            var c = DateComponents(); c.year = y; c.month = m; c.day = day
            return Calendar.current.date(from: c) ?? Date()
        }
        return [
            RealDay(date: d(2026,2,9),  rhr: 59,  hrv: 80.9, avgHR: 70.7, maxHR: 136, walkHR: nil,  respRate: 15.7),
            RealDay(date: d(2026,2,10), rhr: 63,  hrv: 78.5, avgHR: 73.9, maxHR: 99,  walkHR: 89,   respRate: 18.5),
            RealDay(date: d(2026,2,11), rhr: 58,  hrv: 78.7, avgHR: 65.9, maxHR: 130, walkHR: 105,  respRate: 15.7),
            RealDay(date: d(2026,2,12), rhr: 58,  hrv: 82.0, avgHR: 70.1, maxHR: 131, walkHR: 103,  respRate: 15.9),
            RealDay(date: d(2026,2,13), rhr: 63,  hrv: 61.4, avgHR: 72.9, maxHR: 142, walkHR: 128,  respRate: 16.7),
            RealDay(date: d(2026,2,14), rhr: 63,  hrv: 78.3, avgHR: 69.4, maxHR: 129, walkHR: 103,  respRate: 15.7),
            RealDay(date: d(2026,2,15), rhr: 58,  hrv: 77.5, avgHR: 72.3, maxHR: 120, walkHR: 111,  respRate: 17.0),
            RealDay(date: d(2026,2,16), rhr: 62,  hrv: 74.3, avgHR: 74.4, maxHR: 125, walkHR: 115,  respRate: 18.2),
            RealDay(date: d(2026,2,17), rhr: 65,  hrv: 63.6, avgHR: 82.5, maxHR: 145, walkHR: 121,  respRate: 18.0),
            RealDay(date: d(2026,2,18), rhr: nil, hrv: nil,  avgHR: 59.9, maxHR: 63,  walkHR: nil,  respRate: 21.0),
            RealDay(date: d(2026,2,19), rhr: 65,  hrv: 86.3, avgHR: 80.0, maxHR: 136, walkHR: 111,  respRate: 17.8),
            RealDay(date: d(2026,2,20), rhr: 62,  hrv: 71.6, avgHR: 81.2, maxHR: 118, walkHR: nil,  respRate: 21.4),
            RealDay(date: d(2026,2,21), rhr: 62,  hrv: 57.3, avgHR: 83.7, maxHR: 156, walkHR: 116,  respRate: nil),
            RealDay(date: d(2026,2,22), rhr: nil, hrv: 85.8, avgHR: 75.6, maxHR: 84,  walkHR: nil,  respRate: nil),
            RealDay(date: d(2026,2,23), rhr: 67,  hrv: 58.3, avgHR: 82.0, maxHR: 127, walkHR: 107,  respRate: nil),
            RealDay(date: d(2026,2,24), rhr: 54,  hrv: 71.6, avgHR: 68.4, maxHR: 111, walkHR: 95,   respRate: 16.4),
            RealDay(date: d(2026,2,25), rhr: 66,  hrv: 59.9, avgHR: 84.1, maxHR: 128, walkHR: 97,   respRate: nil),
            RealDay(date: d(2026,2,26), rhr: 59,  hrv: 55.4, avgHR: 72.1, maxHR: 135, walkHR: nil,  respRate: 16.9),
            RealDay(date: d(2026,2,27), rhr: 58,  hrv: 72.0, avgHR: 67.5, maxHR: 116, walkHR: 100,  respRate: 16.5),
            RealDay(date: d(2026,2,28), rhr: 60,  hrv: 53.7, avgHR: 80.8, maxHR: 160, walkHR: 107,  respRate: 19.8),
            RealDay(date: d(2026,3,1),  rhr: 58,  hrv: 63.0, avgHR: 64.7, maxHR: 101, walkHR: 89,   respRate: 17.2),
            RealDay(date: d(2026,3,2),  rhr: 60,  hrv: 64.8, avgHR: 68.4, maxHR: 122, walkHR: 103,  respRate: 16.5),
            RealDay(date: d(2026,3,3),  rhr: 59,  hrv: 57.4, avgHR: 76.3, maxHR: 104, walkHR: 92,   respRate: 19.0),
            RealDay(date: d(2026,3,4),  rhr: 65,  hrv: 59.3, avgHR: 83.1, maxHR: 109, walkHR: 104,  respRate: 22.7),
            RealDay(date: d(2026,3,5),  rhr: 59,  hrv: 83.2, avgHR: 72.9, maxHR: 148, walkHR: 106,  respRate: 16.1),
            RealDay(date: d(2026,3,6),  rhr: 78,  hrv: 66.2, avgHR: 80.4, maxHR: 165, walkHR: 124,  respRate: 16.4),
            RealDay(date: d(2026,3,7),  rhr: 72,  hrv: 47.4, avgHR: 78.4, maxHR: 141, walkHR: 108,  respRate: 16.3),
            RealDay(date: d(2026,3,8),  rhr: 58,  hrv: 69.2, avgHR: 66.9, maxHR: 100, walkHR: 100,  respRate: 15.9),
            RealDay(date: d(2026,3,9),  rhr: 60,  hrv: 68.3, avgHR: 82.0, maxHR: 167, walkHR: 139,  respRate: 16.0),
            RealDay(date: d(2026,3,10), rhr: 62,  hrv: 59.6, avgHR: 81.1, maxHR: 162, walkHR: 98,   respRate: nil),
            RealDay(date: d(2026,3,11), rhr: 57,  hrv: 66.5, avgHR: 77.3, maxHR: 172, walkHR: 158,  respRate: 16.0),
            // Mar 12 — partial day (as of 12:15 AM). Only overnight/early sleep window recorded.
            // Avg HR from first 15-min overnight slot; RHR/HRV inferred from post-activity recovery pattern.
            RealDay(date: d(2026,3,12), rhr: 60,  hrv: 62.0, avgHR: 63.1, maxHR: 71,  walkHR: nil,  respRate: 15.8),
        ]
    }()

    /// Converts a `RealDay` into a fully-populated `HeartSnapshot`.
    /// Missing HealthKit fields are derived from the available heart metrics.
    private static func snapshot(from day: RealDay) -> HeartSnapshot {
        let rhr = day.rhr ?? 65.0

        // Steps: walking HR presence signals an active day. Elevation above
        // resting adds steps (each bpm above resting ≈ 150 extra steps).
        let steps: Double? = {
            let hrElevation = max(0, day.avgHR - rhr)
            let base: Double = day.walkHR != nil ? 5_500 : 2_800
            return base + hrElevation * 150
        }()

        // Walk minutes: available if the watch recorded a walking HR
        let walkMinutes: Double? = day.walkHR.map { whr in
            // Higher walking HR relative to resting → longer walk (up to ~60 min)
            let ratio = (whr - rhr) / max(1, rhr)
            return min(60, max(8, 10 + ratio * 80))
        }

        // Workout minutes: maxHR > 130 suggests a workout occurred
        let workoutMinutes: Double? = day.maxHR > 130 ? max(5, (day.maxHR - 130) * 1.2) : nil

        // Sleep hours: higher respiratory rate → lighter/fragmented sleep
        // Normal resp 15–16 → ~7.5h; elevated 19–22 → ~6h
        let sleepHours: Double? = day.respRate.map { rr in
            max(5.0, min(9.0, 9.5 - (rr - 14.0) * 0.22))
        } ?? 7.0  // default when not recorded

        // VO2 max: Cooper/Åstrand proxy from HR reserve
        // Formula: 15 × (maxHR / restingHR) clamped to realistic range
        let vo2Max: Double? = {
            let raw = 15.0 * (day.maxHR / rhr)
            return max(28, min(52, raw))
        }()

        // Recovery HR 1 min: proportional to maxHR − restingHR spread
        let reserve = day.maxHR - rhr
        let rec1: Double? = reserve > 20 ? max(12, min(42, reserve * 0.28)) : nil
        let rec2: Double? = rec1.map { r in r + Double.random(in: 8...14) }

        // Zone minutes derived from HR spread (maxHR - rhr determines zone reach)
        let zoneMinutes: [Double] = {
            let spread = day.maxHR - rhr
            // Zone 0 (rest): fills the day minus active zones
            let z4 = spread > 80 ? max(0, (spread - 80) * 0.4) : 0     // peak
            let z3 = spread > 55 ? max(0, (spread - 55) * 0.6) : 0     // vigorous
            let z2 = spread > 30 ? max(0, (spread - 30) * 1.2) : 0     // moderate
            let z1 = max(0, spread * 2.5)                               // light
            let z0 = max(120, 400 - z1 - z2 - z3 - z4)                 // rest
            return [z0, z1, z2, z3, z4]
        }()

        return HeartSnapshot(
            date: day.date,
            restingHeartRate: day.rhr,
            hrvSDNN: day.hrv,
            recoveryHR1m: rec1,
            recoveryHR2m: rec2,
            vo2Max: vo2Max,
            zoneMinutes: zoneMinutes,
            steps: steps,
            walkMinutes: walkMinutes,
            workoutMinutes: workoutMinutes,
            sleepHours: sleepHours
        )
    }

    // MARK: - Mock History

    /// Returns up to 32 days of real Apple Watch heart data (Feb 9 – Mar 12 2026),
    /// with dates re-anchored so the most recent day is always *today*.
    /// This ensures date-sensitive engines (stress, trends) always find a
    /// matching snapshot when running in the simulator.
    public static func mockHistory(days: Int = 21) -> [HeartSnapshot] {
        let count = min(days, realDays.count)
        let slice = Array(realDays.suffix(count))
        let today = Calendar.current.startOfDay(for: Date())

        // Anchor: last slot → today, each preceding slot → one day earlier
        return slice.enumerated().map { idx, day in
            let daysBack = count - 1 - idx
            let anchoredDate = Calendar.current.date(
                byAdding: .day, value: -daysBack, to: today
            ) ?? today

            // Build snapshot but override the date
            let base = snapshot(from: day)
            return HeartSnapshot(
                date: anchoredDate,
                restingHeartRate: base.restingHeartRate,
                hrvSDNN: base.hrvSDNN,
                recoveryHR1m: base.recoveryHR1m,
                recoveryHR2m: base.recoveryHR2m,
                vo2Max: base.vo2Max,
                zoneMinutes: base.zoneMinutes,
                steps: base.steps,
                walkMinutes: base.walkMinutes,
                workoutMinutes: base.workoutMinutes,
                sleepHours: base.sleepHours
            )
        }
    }

    // MARK: - Today's Mock Snapshot

    /// Today's snapshot built from the most recent real data day (Mar 12 2026),
    /// but stamped with today's actual date so the StressEngine and all date-
    /// sensitive queries match correctly in the simulator.
    public static var mockTodaySnapshot: HeartSnapshot {
        // swiftlint:disable:next force_unwrapping
        let base = snapshot(from: realDays.last!)
        // Re-stamp with today so engine date comparisons always succeed
        return HeartSnapshot(
            date: Calendar.current.startOfDay(for: Date()),
            restingHeartRate: base.restingHeartRate,
            hrvSDNN: base.hrvSDNN,
            recoveryHR1m: base.recoveryHR1m,
            recoveryHR2m: base.recoveryHR2m,
            vo2Max: base.vo2Max,
            zoneMinutes: base.zoneMinutes,
            steps: base.steps,
            walkMinutes: base.walkMinutes,
            workoutMinutes: base.workoutMinutes,
            sleepHours: base.sleepHours
        )
    }

    // MARK: - Sample Nudge

    /// A representative daily nudge for preview use.
    public static let sampleNudge = DailyNudge(
        category: .walk,
        title: "Brisk Walk Today",
        description: "A 15-minute brisk walk is one of the best things you can do "
            + "for your heart. Aim for a pace where you can talk but not sing.",
        durationMinutes: 15,
        icon: "figure.walk"
    )

    // MARK: - Sample Assessment

    /// A stable, medium-confidence assessment for preview use.
    public static let sampleAssessment = HeartAssessment(
        status: .stable,
        confidence: .medium,
        anomalyScore: 0.45,
        regressionFlag: false,
        stressFlag: false,
        cardioScore: 62.0,
        dailyNudge: sampleNudge,
        explanation: "Your heart metrics are within your normal range. "
            + "This assessment uses partial data. "
            + "More consistent wear will improve accuracy. "
            + "Your estimated cardio fitness score is 62 out of 100."
    )

    // MARK: - Sample Profile

    /// A completed-onboarding user profile for preview use.
    public static let sampleProfile = UserProfile(
        displayName: "Alex",
        joinDate: Calendar.current.date(
            byAdding: .day,
            value: -45,
            to: Date()
        ) ?? Date(),
        onboardingComplete: true,
        streakDays: 12
    )

    // MARK: - Sample Correlations

    /// Realistic correlation results across four factor pairs.
    /// Today's snapshot for a specific persona.
    public static func personaTodaySnapshot(_ persona: Persona) -> HeartSnapshot {
        let history = personaHistory(persona, days: 1)
        return history.last ?? mockTodaySnapshot
    }

    public static let sampleCorrelations = [
        CorrelationResult(
            factorName: "Daily Steps",
            correlationStrength: -0.42,
            interpretation: "On days you walk more, your resting heart rate tends to be lower. "
                + "Your data shows this clear pattern \u{2014} keep it up.",
            confidence: .medium
        ),
        CorrelationResult(
            factorName: "Walk Minutes",
            correlationStrength: 0.55,
            interpretation: "More walking time tracks with higher HRV in your data. "
                + "This is a clear pattern worth maintaining.",
            confidence: .high
        ),
        CorrelationResult(
            factorName: "Activity Minutes",
            correlationStrength: 0.38,
            interpretation: "Active days lead to faster heart rate recovery in your data. "
                + "This noticeable pattern shows your fitness is paying off.",
            confidence: .medium
        ),
        CorrelationResult(
            factorName: "Sleep Hours",
            correlationStrength: 0.61,
            interpretation: "Longer sleep nights are followed by better HRV readings. "
                + "This is one of the strongest patterns in your data.",
            confidence: .high
        )
    ]

    // MARK: - Test Personas

    /// Persona archetypes for comprehensive algorithm testing.
    /// Each generates 30 days of physiologically consistent data.
    public enum Persona: String, CaseIterable, Sendable {
        case athleticMale        // 28M, runner, low RHR, high HRV, high VO2
        case athleticFemale      // 32F, cyclist, low RHR, high HRV, good VO2
        case normalMale          // 42M, moderate activity, average metrics
        case normalFemale        // 38F, moderate activity, average metrics
        case couchPotatoMale     // 45M, sedentary, elevated RHR, low HRV
        case couchPotatoFemale   // 50F, sedentary, elevated RHR, low HRV
        case overweightMale      // 52M, 105kg, limited activity, stressed
        case overweightFemale    // 48F, 88kg, some walking, moderate stress
        case underwieghtFemale   // 22F, 48kg, anxious, high RHR, low sleep
        case seniorActive        // 68M, daily walks, good for age, steady

        public var age: Int {
            switch self {
            case .athleticMale:       return 28
            case .athleticFemale:     return 32
            case .normalMale:         return 42
            case .normalFemale:       return 38
            case .couchPotatoMale:    return 45
            case .couchPotatoFemale:  return 50
            case .overweightMale:     return 52
            case .overweightFemale:   return 48
            case .underwieghtFemale:  return 22
            case .seniorActive:       return 68
            }
        }

        public var sex: BiologicalSex {
            switch self {
            case .athleticMale, .normalMale, .couchPotatoMale,
                 .overweightMale, .seniorActive:
                return .male
            case .athleticFemale, .normalFemale, .couchPotatoFemale,
                 .overweightFemale, .underwieghtFemale:
                return .female
            }
        }

        public var displayName: String {
            switch self {
            case .athleticMale:       return "Alex (Athletic M, 28)"
            case .athleticFemale:     return "Maya (Athletic F, 32)"
            case .normalMale:         return "James (Normal M, 42)"
            case .normalFemale:       return "Sarah (Normal F, 38)"
            case .couchPotatoMale:    return "Dave (Sedentary M, 45)"
            case .couchPotatoFemale:  return "Linda (Sedentary F, 50)"
            case .overweightMale:     return "Mike (Overweight M, 52)"
            case .overweightFemale:   return "Karen (Overweight F, 48)"
            case .underwieghtFemale:  return "Mia (Underweight F, 22)"
            case .seniorActive:       return "Bob (Senior Active M, 68)"
            }
        }

        /// Body mass in kg for BMI calculations.
        public var bodyMassKg: Double {
            switch self {
            case .athleticMale:       return 74
            case .athleticFemale:     return 58
            case .normalMale:         return 82
            case .normalFemale:       return 65
            case .couchPotatoMale:    return 92
            case .couchPotatoFemale:  return 78
            case .overweightMale:     return 105
            case .overweightFemale:   return 88
            case .underwieghtFemale:  return 48
            case .seniorActive:       return 76
            }
        }

        /// Metric ranges: (rhrMin, rhrMax, hrvMin, hrvMax, rec1Min, rec1Max,
        ///                  vo2Min, vo2Max, stepsMin, stepsMax, walkMin, walkMax,
        ///                  workoutMin, workoutMax, sleepMin, sleepMax)
        fileprivate var ranges: PersonaRanges {
            switch self {
            case .athleticMale:
                return PersonaRanges(
                    rhr: (46, 54), hrv: (55, 95), rec1: (32, 48), vo2: (50, 58),
                    steps: (8000, 18000), walk: (30, 80), workout: (30, 90), sleep: (7.0, 9.0))
            case .athleticFemale:
                return PersonaRanges(
                    rhr: (50, 58), hrv: (48, 82), rec1: (28, 42), vo2: (42, 50),
                    steps: (7000, 15000), walk: (25, 70), workout: (25, 75), sleep: (7.0, 8.5))
            case .normalMale:
                return PersonaRanges(
                    rhr: (60, 72), hrv: (32, 55), rec1: (18, 32), vo2: (34, 42),
                    steps: (5000, 11000), walk: (15, 50), workout: (0, 40), sleep: (6.0, 8.0))
            case .normalFemale:
                return PersonaRanges(
                    rhr: (62, 74), hrv: (28, 50), rec1: (16, 30), vo2: (30, 38),
                    steps: (4500, 10000), walk: (15, 45), workout: (0, 35), sleep: (6.5, 8.5))
            case .couchPotatoMale:
                return PersonaRanges(
                    rhr: (72, 84), hrv: (18, 35), rec1: (10, 20), vo2: (25, 33),
                    steps: (1500, 5000), walk: (5, 20), workout: (0, 5), sleep: (5.0, 7.0))
            case .couchPotatoFemale:
                return PersonaRanges(
                    rhr: (74, 86), hrv: (15, 30), rec1: (8, 18), vo2: (22, 30),
                    steps: (1200, 4500), walk: (5, 18), workout: (0, 3), sleep: (5.5, 7.5))
            case .overweightMale:
                return PersonaRanges(
                    rhr: (76, 88), hrv: (16, 30), rec1: (8, 18), vo2: (22, 30),
                    steps: (2000, 6000), walk: (8, 25), workout: (0, 10), sleep: (4.5, 6.5))
            case .overweightFemale:
                return PersonaRanges(
                    rhr: (72, 82), hrv: (20, 35), rec1: (10, 22), vo2: (24, 32),
                    steps: (2500, 7000), walk: (10, 30), workout: (0, 15), sleep: (5.0, 7.0))
            case .underwieghtFemale:
                return PersonaRanges(
                    rhr: (68, 82), hrv: (22, 42), rec1: (14, 26), vo2: (28, 36),
                    steps: (3000, 8000), walk: (10, 35), workout: (0, 20), sleep: (4.5, 6.5))
            case .seniorActive:
                return PersonaRanges(
                    rhr: (58, 68), hrv: (20, 38), rec1: (14, 26), vo2: (28, 36),
                    steps: (5000, 10000), walk: (20, 55), workout: (10, 35), sleep: (6.0, 7.5))
            }
        }
    }

    /// Generate 30 days of persona-specific mock data.
    ///
    /// The data is deterministic (seeded by persona + day offset) and
    /// includes realistic physiological correlations:
    /// - Activity days → lower RHR, higher HRV
    /// - Poor sleep → higher RHR, lower HRV next day
    /// - Athletic personas get zone 3-5 heavy distributions
    /// - Sedentary personas get zone 1-2 heavy distributions
    ///
    /// - Parameters:
    ///   - persona: The test persona archetype.
    ///   - days: Number of days to generate. Default 30.
    ///   - includeStressEvent: If true, injects a 3-day stress spike (days 18-20).
    /// - Returns: Array of snapshots ordered oldest-first.
    public static func personaHistory(
        _ persona: Persona,
        days: Int = 30,
        includeStressEvent: Bool = false
    ) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let ranges = persona.ranges
        let personaSeed = persona.hashValue & 0xFFFF

        return (0..<days).map { offset in
            let dayDate = calendar.date(
                byAdding: .day,
                value: -(days - 1 - offset),
                to: today
            )! // swiftlint:disable:this force_unwrapping

            let seed = personaSeed &+ offset &* 13 &+ 7

            // Activity signal for the day
            let activitySignal = seededRandom(min: 0, max: 1, seed: seed &+ 1)
            let sleepSignal = seededRandom(min: 0, max: 1, seed: seed &+ 2)
            let workoutSignal = seededRandom(min: 0, max: 1, seed: seed &+ 3)

            // Stress event injection (elevated RHR, depressed HRV for 3 days)
            let isStressDay = includeStressEvent && (offset >= 18 && offset <= 20)
            let stressMod: Double = isStressDay ? 0.6 : 1.0 // Reduces HRV
            let stressRHRMod: Double = isStressDay ? 1.12 : 1.0 // Elevates RHR

            // Generate metrics from persona ranges with physiological correlations
            let rhrBase = ranges.rhr.0 + (1.0 - activitySignal) * (ranges.rhr.1 - ranges.rhr.0)
            let rhr = (rhrBase + seededRandom(min: -3, max: 3, seed: seed &+ 10)) * stressRHRMod

            let hrvBase = ranges.hrv.0 + (activitySignal * 0.4 + sleepSignal * 0.6) * (ranges.hrv.1 - ranges.hrv.0)
            let hrv = (hrvBase + seededRandom(min: -5, max: 5, seed: seed &+ 11)) * stressMod

            let rec1Base = ranges.rec1.0 + workoutSignal * (ranges.rec1.1 - ranges.rec1.0)
            let rec1 = rec1Base + seededRandom(min: -4, max: 4, seed: seed &+ 12)
            let rec2 = rec1 + seededRandom(min: 8, max: 16, seed: seed &+ 13)

            let vo2Base = ranges.vo2.0 + activitySignal * 0.3 * (ranges.vo2.1 - ranges.vo2.0)
            let vo2 = vo2Base + seededRandom(min: -1.5, max: 1.5, seed: seed &+ 14)
                + Double(offset) / Double(max(days, 1)) * 1.5 // Slight improvement over time

            let steps = ranges.steps.0 + activitySignal * (ranges.steps.1 - ranges.steps.0)
                + seededRandom(min: -500, max: 500, seed: seed &+ 15)
            let walk = ranges.walk.0 + activitySignal * (ranges.walk.1 - ranges.walk.0)
                + seededRandom(min: -3, max: 3, seed: seed &+ 16)
            let workout = ranges.workout.0 + workoutSignal * (ranges.workout.1 - ranges.workout.0)
                + seededRandom(min: -2, max: 2, seed: seed &+ 17)
            let sleep = ranges.sleep.0 + sleepSignal * (ranges.sleep.1 - ranges.sleep.0)
                + seededRandom(min: -0.3, max: 0.3, seed: seed &+ 18)

            // Zone minutes based on persona type
            let zoneMinutes = generateZoneMinutes(
                persona: persona,
                activitySignal: activitySignal,
                workoutSignal: workoutSignal,
                seed: seed &+ 20
            )

            // Occasional nil values (5-15% per metric)
            let nilRoll = { (s: Int, chance: Double) -> Bool in
                seededRandom(min: 0, max: 1, seed: s) < chance
            }

            return HeartSnapshot(
                date: dayDate,
                restingHeartRate: nilRoll(seed &* 31, 0.05) ? nil : max(40, rhr),
                hrvSDNN: nilRoll(seed &* 31 &+ 1, 0.08) ? nil : max(5, hrv),
                recoveryHR1m: nilRoll(seed &* 31 &+ 2, 0.25) ? nil : max(5, rec1),
                recoveryHR2m: nilRoll(seed &* 31 &+ 3, 0.30) ? nil : max(10, rec2),
                vo2Max: nilRoll(seed &* 31 &+ 4, 0.15) ? nil : max(15, vo2),
                zoneMinutes: zoneMinutes,
                steps: nilRoll(seed &* 31 &+ 5, 0.05) ? nil : max(0, steps),
                walkMinutes: nilRoll(seed &* 31 &+ 6, 0.08) ? nil : max(0, walk),
                workoutMinutes: nilRoll(seed &* 31 &+ 7, 0.20) ? nil : max(0, workout),
                sleepHours: nilRoll(seed &* 31 &+ 8, 0.10) ? nil : max(3, min(12, sleep)),
                bodyMassKg: persona.bodyMassKg + seededRandom(min: -0.5, max: 0.5, seed: seed &+ 30)
            )
        }
    }

    /// Generate zone minutes appropriate for the persona's fitness level.
    private static func generateZoneMinutes(
        persona: Persona,
        activitySignal: Double,
        workoutSignal: Double,
        seed: Int
    ) -> [Double] {
        let base: [Double]
        switch persona {
        case .athleticMale, .athleticFemale:
            // Heavy zone 2-4, significant zone 5
            base = [120, 50, 35, 20, 8]
        case .normalMale, .normalFemale:
            // Balanced, moderate zone 3
            base = [180, 45, 22, 8, 2]
        case .couchPotatoMale, .couchPotatoFemale:
            // Almost all zone 1, tiny zone 2
            base = [280, 15, 3, 0, 0]
        case .overweightMale, .overweightFemale:
            // Mostly zone 1-2, some zone 3 from walking
            base = [240, 25, 8, 1, 0]
        case .underwieghtFemale:
            // Light activity, some zone 2-3
            base = [200, 30, 12, 3, 0]
        case .seniorActive:
            // Good zone 2-3 from walks, minimal zone 4-5
            base = [160, 40, 18, 4, 1]
        }

        return base.enumerated().map { index, value in
            let activityMod = 0.5 + activitySignal * 1.0
            let workoutMod = index >= 3 ? (0.3 + workoutSignal * 1.4) : 1.0
            let noise = seededRandom(min: 0.7, max: 1.3, seed: seed &+ index)
            return max(0, value * activityMod * workoutMod * noise)
        }
    }

    // MARK: - Sample Weekly Report

    /// A representative weekly report for preview use.
    public static let sampleWeeklyReport = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // swiftlint:disable:next force_unwrapping
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!

        return WeeklyReport(
            weekStart: weekStart,
            weekEnd: today,
            avgCardioScore: 64.5,
            trendDirection: .up,
            topInsight: "Your resting heart rate dropped an average of 2 BPM this "
                + "week, suggesting improved cardiovascular fitness.",
            nudgeCompletionRate: 0.71
        )
    }()
}

// MARK: - Persona Ranges (Internal)

/// Physiological metric ranges for a test persona.
struct PersonaRanges {
    let rhr: (Double, Double)
    let hrv: (Double, Double)
    let rec1: (Double, Double)
    let vo2: (Double, Double)
    let steps: (Double, Double)
    let walk: (Double, Double)
    let workout: (Double, Double)
    let sleep: (Double, Double)
}

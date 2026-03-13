// SyntheticPersonaProfiles.swift
// HeartCoach Tests
//
// 20+ synthetic personas with diverse demographics for exhaustive
// engine validation. Each persona defines baseline physiology,
// lifestyle data, a 14-day snapshot history with realistic daily
// noise, and expected outcome ranges for every engine.

import Foundation
@testable import Thump

// MARK: - Expected Outcome Ranges

/// Expected per-engine outcome for a persona.
struct EngineExpectation {
    // StressEngine
    let stressScoreRange: ClosedRange<Double>

    // HeartTrendEngine
    let expectedTrendStatus: Set<TrendStatus>
    let expectsConsecutiveAlert: Bool
    let expectsRegression: Bool
    let expectsStressPattern: Bool

    // BioAgeEngine
    let bioAgeDirection: BioAgeExpectedDirection

    // ReadinessEngine
    let readinessLevelRange: Set<ReadinessLevel>

    // NudgeGenerator
    let expectedNudgeCategories: Set<NudgeCategory>

    // BuddyRecommendationEngine
    let minBuddyPriority: RecommendationPriority

    // HeartRateZoneEngine — zones are always valid; we check zone count
    // CoachingEngine — checked via non-empty insights
    // CorrelationEngine — checked via non-empty results with 14-day data
}

enum BioAgeExpectedDirection {
    case younger       // bioAge < chronologicalAge
    case onTrack       // bioAge ~ chronologicalAge (within 2 years)
    case older         // bioAge > chronologicalAge
    case anyValid      // just needs a non-nil result
}

// MARK: - Synthetic Persona

struct SyntheticPersona {
    let name: String
    let age: Int
    let sex: BiologicalSex
    let weightKg: Double

    // Physiological baselines
    let restingHR: Double
    let hrvSDNN: Double
    let vo2Max: Double
    let recoveryHR1m: Double
    let recoveryHR2m: Double

    // Lifestyle baselines
    let sleepHours: Double
    let steps: Double
    let walkMinutes: Double
    let workoutMinutes: Double
    let zoneMinutes: [Double] // 5 zones

    // Expected outcomes
    let expectations: EngineExpectation

    // Optional: override history generation for special patterns
    let historyOverride: ((_ persona: SyntheticPersona) -> [HeartSnapshot])?

    init(
        name: String, age: Int, sex: BiologicalSex, weightKg: Double,
        restingHR: Double, hrvSDNN: Double, vo2Max: Double,
        recoveryHR1m: Double, recoveryHR2m: Double,
        sleepHours: Double, steps: Double, walkMinutes: Double,
        workoutMinutes: Double, zoneMinutes: [Double],
        expectations: EngineExpectation,
        historyOverride: ((_ persona: SyntheticPersona) -> [HeartSnapshot])? = nil
    ) {
        self.name = name; self.age = age; self.sex = sex; self.weightKg = weightKg
        self.restingHR = restingHR; self.hrvSDNN = hrvSDNN; self.vo2Max = vo2Max
        self.recoveryHR1m = recoveryHR1m; self.recoveryHR2m = recoveryHR2m
        self.sleepHours = sleepHours; self.steps = steps
        self.walkMinutes = walkMinutes; self.workoutMinutes = workoutMinutes
        self.zoneMinutes = zoneMinutes; self.expectations = expectations
        self.historyOverride = historyOverride
    }
}

// MARK: - Deterministic RNG for Reproducible Tests

private struct PersonaRNG {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let shifted = state >> 33
        return Double(shifted) / Double(UInt64(1) << 31)
    }

    mutating func gaussian(mean: Double, sd: Double) -> Double {
        let u1 = max(next(), 1e-10)
        let u2 = next()
        let normal = (-2.0 * log(u1)).squareRoot() * cos(2.0 * .pi * u2)
        return mean + normal * sd
    }
}

// MARK: - History Generation

extension SyntheticPersona {

    /// Generate 14-day snapshot history with realistic daily noise.
    func generateHistory() -> [HeartSnapshot] {
        if let override = historyOverride {
            return override(self)
        }
        return generateStandardHistory()
    }

    private func generateStandardHistory() -> [HeartSnapshot] {
        var rng = PersonaRNG(seed: UInt64(abs(name.hashValue)))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<14).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -(13 - dayOffset), to: today) else {
                return nil
            }
            return HeartSnapshot(
                date: date,
                restingHeartRate: rng.gaussian(mean: restingHR, sd: 3.0),
                hrvSDNN: max(5, rng.gaussian(mean: hrvSDNN, sd: 8.0)),
                recoveryHR1m: max(5, rng.gaussian(mean: recoveryHR1m, sd: 3.0)),
                recoveryHR2m: max(5, rng.gaussian(mean: recoveryHR2m, sd: 3.0)),
                vo2Max: max(10, rng.gaussian(mean: vo2Max, sd: 1.0)),
                zoneMinutes: zoneMinutes.map { max(0, rng.gaussian(mean: $0, sd: $0 * 0.2)) },
                steps: max(0, rng.gaussian(mean: steps, sd: 2000)),
                walkMinutes: max(0, rng.gaussian(mean: walkMinutes, sd: 5)),
                workoutMinutes: max(0, rng.gaussian(mean: workoutMinutes, sd: 5)),
                sleepHours: max(0, rng.gaussian(mean: sleepHours, sd: 0.5)),
                bodyMassKg: weightKg
            )
        }
    }
}

// MARK: - Overtraining History Generator

/// Generates a 14-day history where the last 3+ days show elevated RHR
/// and depressed HRV simulating overtraining syndrome.
private func overtainingHistory(persona: SyntheticPersona) -> [HeartSnapshot] {
    var rng = PersonaRNG(seed: 99999)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    return (0..<14).compactMap { dayOffset in
        guard let date = calendar.date(byAdding: .day, value: -(13 - dayOffset), to: today) else {
            return nil
        }
        let isElevatedDay = dayOffset >= 10 // last 4 days elevated
        let rhr = isElevatedDay
            ? rng.gaussian(mean: persona.restingHR + 12, sd: 1.5)
            : rng.gaussian(mean: persona.restingHR, sd: 2.0)
        let hrv = isElevatedDay
            ? rng.gaussian(mean: persona.hrvSDNN * 0.65, sd: 3.0)
            : rng.gaussian(mean: persona.hrvSDNN, sd: 5.0)
        let recovery = isElevatedDay
            ? rng.gaussian(mean: persona.recoveryHR1m * 0.6, sd: 2.0)
            : rng.gaussian(mean: persona.recoveryHR1m, sd: 3.0)

        return HeartSnapshot(
            date: date,
            restingHeartRate: rhr,
            hrvSDNN: max(5, hrv),
            recoveryHR1m: max(5, recovery),
            recoveryHR2m: max(5, recovery * 1.3),
            vo2Max: rng.gaussian(mean: persona.vo2Max, sd: 0.5),
            zoneMinutes: persona.zoneMinutes.map { max(0, rng.gaussian(mean: $0, sd: 3)) },
            steps: max(0, rng.gaussian(mean: persona.steps, sd: 1500)),
            walkMinutes: max(0, rng.gaussian(mean: persona.walkMinutes, sd: 5)),
            workoutMinutes: max(0, rng.gaussian(mean: persona.workoutMinutes, sd: 5)),
            sleepHours: max(0, rng.gaussian(mean: persona.sleepHours - (isElevatedDay ? 1.5 : 0), sd: 0.3)),
            bodyMassKg: persona.weightKg
        )
    }
}

/// Generates history where RHR slowly normalizes from elevated state
/// simulating recovery from illness.
private func recoveringFromIllnessHistory(persona: SyntheticPersona) -> [HeartSnapshot] {
    var rng = PersonaRNG(seed: 88888)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    return (0..<14).compactMap { dayOffset in
        guard let date = calendar.date(byAdding: .day, value: -(13 - dayOffset), to: today) else {
            return nil
        }
        // Progress: 0.0 = sick (day 0), 1.0 = recovered (day 13)
        let progress = Double(dayOffset) / 13.0
        let rhrElevation = 10.0 * (1.0 - progress) // starts +10, ends +0
        let hrvSuppression = 0.7 + 0.3 * progress  // starts 70%, ends 100%

        return HeartSnapshot(
            date: date,
            restingHeartRate: rng.gaussian(mean: persona.restingHR + rhrElevation, sd: 2.0),
            hrvSDNN: max(5, rng.gaussian(mean: persona.hrvSDNN * hrvSuppression, sd: 5.0)),
            recoveryHR1m: max(5, rng.gaussian(mean: persona.recoveryHR1m * (0.8 + 0.2 * progress), sd: 2.0)),
            recoveryHR2m: max(5, rng.gaussian(mean: persona.recoveryHR2m * (0.8 + 0.2 * progress), sd: 2.0)),
            vo2Max: rng.gaussian(mean: persona.vo2Max - 2 * (1 - progress), sd: 0.5),
            zoneMinutes: persona.zoneMinutes.map { max(0, $0 * (0.3 + 0.7 * progress)) },
            steps: max(0, rng.gaussian(mean: persona.steps * (0.3 + 0.7 * progress), sd: 1000)),
            walkMinutes: max(0, persona.walkMinutes * (0.3 + 0.7 * progress)),
            workoutMinutes: max(0, persona.workoutMinutes * (0.2 + 0.8 * progress)),
            sleepHours: max(0, rng.gaussian(mean: persona.sleepHours + 1.0 * (1 - progress), sd: 0.5)),
            bodyMassKg: persona.weightKg
        )
    }
}

/// Generates erratic sleep/activity pattern for shift worker.
private func shiftWorkerHistory(persona: SyntheticPersona) -> [HeartSnapshot] {
    var rng = PersonaRNG(seed: 77777)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    return (0..<14).compactMap { dayOffset in
        guard let date = calendar.date(byAdding: .day, value: -(13 - dayOffset), to: today) else {
            return nil
        }
        // Alternate between day shift (even) and night shift (odd)
        let isNightShift = dayOffset % 3 == 0
        let sleep = isNightShift
            ? rng.gaussian(mean: 4.5, sd: 0.5)
            : rng.gaussian(mean: 7.0, sd: 0.5)
        let rhr = isNightShift
            ? rng.gaussian(mean: persona.restingHR + 5, sd: 2)
            : rng.gaussian(mean: persona.restingHR, sd: 2)
        let hrv = isNightShift
            ? rng.gaussian(mean: persona.hrvSDNN * 0.8, sd: 5)
            : rng.gaussian(mean: persona.hrvSDNN, sd: 5)

        return HeartSnapshot(
            date: date,
            restingHeartRate: rhr,
            hrvSDNN: max(5, hrv),
            recoveryHR1m: max(5, rng.gaussian(mean: persona.recoveryHR1m, sd: 3)),
            recoveryHR2m: max(5, rng.gaussian(mean: persona.recoveryHR2m, sd: 3)),
            vo2Max: rng.gaussian(mean: persona.vo2Max, sd: 0.5),
            zoneMinutes: persona.zoneMinutes.map { max(0, rng.gaussian(mean: $0, sd: 5)) },
            steps: max(0, rng.gaussian(mean: isNightShift ? 4000 : persona.steps, sd: 1500)),
            walkMinutes: max(0, rng.gaussian(mean: isNightShift ? 10 : persona.walkMinutes, sd: 5)),
            workoutMinutes: max(0, rng.gaussian(mean: isNightShift ? 0 : persona.workoutMinutes, sd: 5)),
            sleepHours: max(0, sleep),
            bodyMassKg: persona.weightKg
        )
    }
}

/// Weekend warrior: sedentary weekdays, intense weekends.
private func weekendWarriorHistory(persona: SyntheticPersona) -> [HeartSnapshot] {
    var rng = PersonaRNG(seed: 66666)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    return (0..<14).compactMap { dayOffset in
        guard let date = calendar.date(byAdding: .day, value: -(13 - dayOffset), to: today) else {
            return nil
        }
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7

        let steps = isWeekend
            ? rng.gaussian(mean: 15000, sd: 2000)
            : rng.gaussian(mean: 3000, sd: 1000)
        let workout = isWeekend
            ? rng.gaussian(mean: 90, sd: 15)
            : rng.gaussian(mean: 5, sd: 3)

        return HeartSnapshot(
            date: date,
            restingHeartRate: rng.gaussian(mean: persona.restingHR, sd: 3),
            hrvSDNN: max(5, rng.gaussian(mean: persona.hrvSDNN, sd: 6)),
            recoveryHR1m: max(5, rng.gaussian(mean: persona.recoveryHR1m, sd: 3)),
            recoveryHR2m: max(5, rng.gaussian(mean: persona.recoveryHR2m, sd: 3)),
            vo2Max: rng.gaussian(mean: persona.vo2Max, sd: 0.5),
            zoneMinutes: isWeekend
                ? [10, 20, 30, 20, 10]
                : [5, 5, 2, 0, 0],
            steps: max(0, steps),
            walkMinutes: max(0, isWeekend ? 40 : 10),
            workoutMinutes: max(0, workout),
            sleepHours: max(0, rng.gaussian(mean: persona.sleepHours, sd: 0.5)),
            bodyMassKg: persona.weightKg
        )
    }
}

// MARK: - All Personas

enum SyntheticPersonas {

    static let all: [SyntheticPersona] = [
        youngAthlete,
        youngSedentary,
        active30sProfessional,
        newMom,
        middleAgedFit,
        middleAgedUnfit,
        perimenopause,
        activeSenior,
        sedentarySenior,
        teenAthlete,
        overtrainingSyndrome,
        recoveringFromIllness,
        highStressExecutive,
        shiftWorker,
        weekendWarrior,
        sleepApnea,
        excellentSleeper,
        underweightRunner,
        obeseSedentary,
        anxietyProfile,
    ]

    // MARK: 1. Young Athlete (22M)
    static let youngAthlete = SyntheticPersona(
        name: "Young Athlete (22M)",
        age: 22, sex: .male, weightKg: 75,
        restingHR: 48, hrvSDNN: 85, vo2Max: 58,
        recoveryHR1m: 45, recoveryHR2m: 55,
        sleepHours: 8.0, steps: 14000, walkMinutes: 40,
        workoutMinutes: 60, zoneMinutes: [15, 20, 25, 15, 8],
        expectations: EngineExpectation(
            stressScoreRange: 20...50,
            expectedTrendStatus: [.improving, .stable],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .younger,
            readinessLevelRange: [.primed, .ready],
            expectedNudgeCategories: [.celebrate, .moderate, .walk, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 2. Young Sedentary (25F)
    static let youngSedentary = SyntheticPersona(
        name: "Young Sedentary (25F)",
        age: 25, sex: .female, weightKg: 68,
        restingHR: 78, hrvSDNN: 32, vo2Max: 28,
        recoveryHR1m: 18, recoveryHR2m: 25,
        sleepHours: 6.5, steps: 3500, walkMinutes: 10,
        workoutMinutes: 0, zoneMinutes: [5, 5, 2, 0, 0],
        expectations: EngineExpectation(
            stressScoreRange: 40...65,
            expectedTrendStatus: [.stable, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .older,
            readinessLevelRange: [.moderate, .recovering, .ready],
            expectedNudgeCategories: [.walk, .rest, .hydrate, .moderate],
            minBuddyPriority: .low
        )
    )

    // MARK: 3. Active 30s Professional (35M)
    static let active30sProfessional = SyntheticPersona(
        name: "Active 30s Professional (35M)",
        age: 35, sex: .male, weightKg: 80,
        restingHR: 62, hrvSDNN: 50, vo2Max: 42,
        recoveryHR1m: 32, recoveryHR2m: 42,
        sleepHours: 7.5, steps: 9000, walkMinutes: 25,
        workoutMinutes: 30, zoneMinutes: [20, 15, 15, 8, 3],
        expectations: EngineExpectation(
            stressScoreRange: 30...55,
            expectedTrendStatus: [.improving, .stable, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .younger,
            readinessLevelRange: [.ready, .primed],
            expectedNudgeCategories: [.celebrate, .walk, .moderate, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 4. New Mom (32F)
    static let newMom = SyntheticPersona(
        name: "New Mom (32F)",
        age: 32, sex: .female, weightKg: 72,
        restingHR: 74, hrvSDNN: 28, vo2Max: 30,
        recoveryHR1m: 20, recoveryHR2m: 28,
        sleepHours: 4.5, steps: 4000, walkMinutes: 15,
        workoutMinutes: 0, zoneMinutes: [5, 5, 2, 0, 0],
        expectations: EngineExpectation(
            stressScoreRange: 45...75,
            expectedTrendStatus: [.stable, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .older,
            readinessLevelRange: [.recovering, .moderate],
            expectedNudgeCategories: [.rest, .breathe, .walk, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 5. Middle-Aged Fit (45M)
    static let middleAgedFit = SyntheticPersona(
        name: "Middle-Aged Fit (45M)",
        age: 45, sex: .male, weightKg: 76,
        restingHR: 54, hrvSDNN: 52, vo2Max: 48,
        recoveryHR1m: 38, recoveryHR2m: 48,
        sleepHours: 7.5, steps: 12000, walkMinutes: 35,
        workoutMinutes: 45, zoneMinutes: [15, 20, 25, 12, 5],
        expectations: EngineExpectation(
            stressScoreRange: 25...50,
            expectedTrendStatus: [.improving, .stable, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .younger,
            readinessLevelRange: [.primed, .ready],
            expectedNudgeCategories: [.celebrate, .moderate, .walk, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 6. Middle-Aged Unfit (48F)
    static let middleAgedUnfit = SyntheticPersona(
        name: "Middle-Aged Unfit (48F)",
        age: 48, sex: .female, weightKg: 95,
        restingHR: 80, hrvSDNN: 22, vo2Max: 24,
        recoveryHR1m: 15, recoveryHR2m: 22,
        sleepHours: 5.5, steps: 3000, walkMinutes: 10,
        workoutMinutes: 0, zoneMinutes: [5, 3, 1, 0, 0],
        expectations: EngineExpectation(
            stressScoreRange: 45...70,
            expectedTrendStatus: [.stable, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .older,
            readinessLevelRange: [.recovering, .moderate],
            expectedNudgeCategories: [.rest, .walk, .hydrate, .breathe],
            minBuddyPriority: .low
        )
    )

    // MARK: 7. Perimenopause (50F)
    static let perimenopause = SyntheticPersona(
        name: "Perimenopause (50F)",
        age: 50, sex: .female, weightKg: 70,
        restingHR: 70, hrvSDNN: 30, vo2Max: 32,
        recoveryHR1m: 25, recoveryHR2m: 33,
        sleepHours: 6.0, steps: 7000, walkMinutes: 20,
        workoutMinutes: 15, zoneMinutes: [10, 10, 8, 3, 1],
        expectations: EngineExpectation(
            stressScoreRange: 35...65,
            expectedTrendStatus: [.stable, .needsAttention, .improving],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .onTrack,
            readinessLevelRange: [.moderate, .ready],
            expectedNudgeCategories: [.walk, .rest, .hydrate, .breathe, .moderate],
            minBuddyPriority: .low
        )
    )

    // MARK: 8. Active Senior (65M)
    static let activeSenior = SyntheticPersona(
        name: "Active Senior (65M)",
        age: 65, sex: .male, weightKg: 78,
        restingHR: 62, hrvSDNN: 35, vo2Max: 32,
        recoveryHR1m: 28, recoveryHR2m: 38,
        sleepHours: 7.5, steps: 8000, walkMinutes: 30,
        workoutMinutes: 20, zoneMinutes: [15, 15, 10, 3, 0],
        expectations: EngineExpectation(
            stressScoreRange: 30...55,
            expectedTrendStatus: [.improving, .stable],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .younger,
            readinessLevelRange: [.ready, .primed],
            expectedNudgeCategories: [.celebrate, .walk, .moderate, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 9. Sedentary Senior (70F)
    static let sedentarySenior = SyntheticPersona(
        name: "Sedentary Senior (70F)",
        age: 70, sex: .female, weightKg: 72,
        restingHR: 78, hrvSDNN: 18, vo2Max: 20,
        recoveryHR1m: 14, recoveryHR2m: 20,
        sleepHours: 6.0, steps: 2000, walkMinutes: 10,
        workoutMinutes: 0, zoneMinutes: [5, 3, 0, 0, 0],
        expectations: EngineExpectation(
            stressScoreRange: 40...70,
            expectedTrendStatus: [.stable, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .older,
            readinessLevelRange: [.recovering, .moderate],
            expectedNudgeCategories: [.rest, .walk, .hydrate, .breathe],
            minBuddyPriority: .low
        )
    )

    // MARK: 10. Teen Athlete (17M)
    static let teenAthlete = SyntheticPersona(
        name: "Teen Athlete (17M)",
        age: 17, sex: .male, weightKg: 68,
        restingHR: 50, hrvSDNN: 90, vo2Max: 55,
        recoveryHR1m: 48, recoveryHR2m: 58,
        sleepHours: 8.5, steps: 15000, walkMinutes: 45,
        workoutMinutes: 75, zoneMinutes: [10, 15, 25, 18, 10],
        expectations: EngineExpectation(
            stressScoreRange: 20...48,
            expectedTrendStatus: [.improving, .stable],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .younger,
            readinessLevelRange: [.primed, .ready],
            expectedNudgeCategories: [.celebrate, .moderate, .walk, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 11. Overtraining Syndrome
    static let overtrainingSyndrome = SyntheticPersona(
        name: "Overtraining Syndrome (30M)",
        age: 30, sex: .male, weightKg: 78,
        restingHR: 58, hrvSDNN: 55, vo2Max: 45,
        recoveryHR1m: 35, recoveryHR2m: 45,
        sleepHours: 6.5, steps: 10000, walkMinutes: 30,
        workoutMinutes: 60, zoneMinutes: [10, 15, 20, 15, 10],
        expectations: EngineExpectation(
            stressScoreRange: 50...85,
            expectedTrendStatus: [.needsAttention],
            expectsConsecutiveAlert: true,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .anyValid,
            readinessLevelRange: [.recovering, .moderate],
            expectedNudgeCategories: [.rest, .breathe, .walk, .hydrate],
            minBuddyPriority: .medium
        ),
        historyOverride: overtainingHistory
    )

    // MARK: 12. Recovering from Illness
    static let recoveringFromIllness = SyntheticPersona(
        name: "Recovering from Illness (38F)",
        age: 38, sex: .female, weightKg: 65,
        restingHR: 66, hrvSDNN: 42, vo2Max: 35,
        recoveryHR1m: 28, recoveryHR2m: 38,
        sleepHours: 7.5, steps: 7000, walkMinutes: 20,
        workoutMinutes: 15, zoneMinutes: [10, 10, 8, 3, 1],
        expectations: EngineExpectation(
            stressScoreRange: 35...65,
            expectedTrendStatus: [.stable, .improving, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .anyValid,
            readinessLevelRange: [.moderate, .ready, .recovering],
            expectedNudgeCategories: [.rest, .walk, .breathe, .hydrate, .celebrate, .moderate],
            minBuddyPriority: .low
        ),
        historyOverride: recoveringFromIllnessHistory
    )

    // MARK: 13. High Stress Executive (42M)
    static let highStressExecutive = SyntheticPersona(
        name: "High Stress Executive (42M)",
        age: 42, sex: .male, weightKg: 88,
        restingHR: 76, hrvSDNN: 28, vo2Max: 32,
        recoveryHR1m: 20, recoveryHR2m: 28,
        sleepHours: 5.0, steps: 4000, walkMinutes: 10,
        workoutMinutes: 5, zoneMinutes: [5, 5, 2, 0, 0],
        expectations: EngineExpectation(
            stressScoreRange: 50...80,
            expectedTrendStatus: [.stable, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .older,
            readinessLevelRange: [.recovering, .moderate],
            expectedNudgeCategories: [.rest, .breathe, .walk, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 14. Shift Worker (35F)
    static let shiftWorker = SyntheticPersona(
        name: "Shift Worker (35F)",
        age: 35, sex: .female, weightKg: 66,
        restingHR: 70, hrvSDNN: 35, vo2Max: 33,
        recoveryHR1m: 24, recoveryHR2m: 32,
        sleepHours: 5.5, steps: 6000, walkMinutes: 15,
        workoutMinutes: 10, zoneMinutes: [10, 8, 5, 2, 0],
        expectations: EngineExpectation(
            stressScoreRange: 35...70,
            expectedTrendStatus: [.stable, .needsAttention, .improving],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .anyValid,
            readinessLevelRange: [.recovering, .moderate, .ready],
            expectedNudgeCategories: [.rest, .walk, .breathe, .hydrate, .moderate],
            minBuddyPriority: .low
        ),
        historyOverride: shiftWorkerHistory
    )

    // MARK: 15. Weekend Warrior (40M)
    static let weekendWarrior = SyntheticPersona(
        name: "Weekend Warrior (40M)",
        age: 40, sex: .male, weightKg: 85,
        restingHR: 68, hrvSDNN: 38, vo2Max: 35,
        recoveryHR1m: 26, recoveryHR2m: 35,
        sleepHours: 7.0, steps: 5000, walkMinutes: 15,
        workoutMinutes: 10, zoneMinutes: [8, 8, 5, 2, 0],
        expectations: EngineExpectation(
            stressScoreRange: 35...60,
            expectedTrendStatus: [.stable, .improving, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .onTrack,
            readinessLevelRange: [.moderate, .ready],
            expectedNudgeCategories: [.walk, .moderate, .rest, .hydrate, .celebrate],
            minBuddyPriority: .low
        ),
        historyOverride: weekendWarriorHistory
    )

    // MARK: 16. Sleep Apnea Profile (55M)
    static let sleepApnea = SyntheticPersona(
        name: "Sleep Apnea (55M)",
        age: 55, sex: .male, weightKg: 100,
        restingHR: 76, hrvSDNN: 24, vo2Max: 28,
        recoveryHR1m: 18, recoveryHR2m: 25,
        sleepHours: 5.0, steps: 4000, walkMinutes: 10,
        workoutMinutes: 5, zoneMinutes: [5, 5, 2, 0, 0],
        expectations: EngineExpectation(
            stressScoreRange: 45...75,
            expectedTrendStatus: [.stable, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .older,
            readinessLevelRange: [.recovering, .moderate],
            expectedNudgeCategories: [.rest, .walk, .breathe, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 17. Excellent Sleeper (28F)
    static let excellentSleeper = SyntheticPersona(
        name: "Excellent Sleeper (28F)",
        age: 28, sex: .female, weightKg: 60,
        restingHR: 60, hrvSDNN: 58, vo2Max: 38,
        recoveryHR1m: 32, recoveryHR2m: 42,
        sleepHours: 8.5, steps: 8000, walkMinutes: 25,
        workoutMinutes: 20, zoneMinutes: [15, 15, 12, 5, 2],
        expectations: EngineExpectation(
            stressScoreRange: 25...50,
            expectedTrendStatus: [.improving, .stable],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .younger,
            readinessLevelRange: [.ready, .primed],
            expectedNudgeCategories: [.celebrate, .walk, .moderate, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 18. Underweight Runner (30F)
    static let underweightRunner = SyntheticPersona(
        name: "Underweight Runner (30F)",
        age: 30, sex: .female, weightKg: 47,
        restingHR: 52, hrvSDNN: 65, vo2Max: 50,
        recoveryHR1m: 42, recoveryHR2m: 52,
        sleepHours: 7.5, steps: 13000, walkMinutes: 35,
        workoutMinutes: 50, zoneMinutes: [10, 15, 25, 15, 8],
        expectations: EngineExpectation(
            stressScoreRange: 20...50,
            expectedTrendStatus: [.improving, .stable],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .younger,
            readinessLevelRange: [.primed, .ready],
            expectedNudgeCategories: [.celebrate, .moderate, .walk, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 19. Obese Sedentary (50M)
    static let obeseSedentary = SyntheticPersona(
        name: "Obese Sedentary (50M)",
        age: 50, sex: .male, weightKg: 120,
        restingHR: 82, hrvSDNN: 20, vo2Max: 22,
        recoveryHR1m: 12, recoveryHR2m: 18,
        sleepHours: 5.0, steps: 2000, walkMinutes: 5,
        workoutMinutes: 0, zoneMinutes: [3, 2, 0, 0, 0],
        expectations: EngineExpectation(
            stressScoreRange: 50...80,
            expectedTrendStatus: [.stable, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .older,
            readinessLevelRange: [.recovering, .moderate],
            expectedNudgeCategories: [.rest, .walk, .breathe, .hydrate],
            minBuddyPriority: .low
        )
    )

    // MARK: 20. Anxiety/Stress Profile (27F)
    static let anxietyProfile = SyntheticPersona(
        name: "Anxiety Profile (27F)",
        age: 27, sex: .female, weightKg: 58,
        restingHR: 78, hrvSDNN: 25, vo2Max: 34,
        recoveryHR1m: 22, recoveryHR2m: 30,
        sleepHours: 5.5, steps: 6000, walkMinutes: 15,
        workoutMinutes: 10, zoneMinutes: [8, 8, 5, 2, 0],
        expectations: EngineExpectation(
            stressScoreRange: 50...80,
            expectedTrendStatus: [.stable, .needsAttention],
            expectsConsecutiveAlert: false,
            expectsRegression: false,
            expectsStressPattern: false,
            bioAgeDirection: .older,
            readinessLevelRange: [.recovering, .moderate],
            expectedNudgeCategories: [.rest, .breathe, .walk, .hydrate],
            minBuddyPriority: .low
        )
    )
}

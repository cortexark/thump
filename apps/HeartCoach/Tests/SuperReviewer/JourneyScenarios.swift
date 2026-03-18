// JourneyScenarios.swift
// ThumpTests
//
// Five journey scenario families, each applied to 4 base persona types.
// Journeys model real-world multi-day health transitions:
// crash, escalation, deterioration, recovery, and mixed signals.

import Foundation
@testable import Thump

// MARK: - Journey Definitions

enum JourneyScenarios {

    // MARK: 1. Good Then Crash

    /// Normal baseline followed by severe sleep crash and gradual recovery.
    static let goodThenCrash = JourneyScenario(
        id: "good_then_crash",
        name: "Good Then Crash",
        description: "2 normal days, then a severe sleep crash (days 3-4) followed by gradual recovery (days 5-6). "
            + "Tests response to sudden deterioration and recovery arc messaging.",
        dayCount: 7,
        dayOverrides: [
            // Days 0-2: Normal (no overrides)
            3: DayMetricOverride(sleep: 1.5, rhrDelta: +10, hrvDelta: -45),
            4: DayMetricOverride(sleep: 2.0, rhrDelta: +12, hrvDelta: -50),
            5: DayMetricOverride(sleep: 9.0, rhrDelta: +5,  hrvDelta: -20),
            6: DayMetricOverride(sleep: 8.0, rhrDelta: +2,  hrvDelta: -5),
        ],
        criticalDays: [3, 4, 5]
    )

    // MARK: 2. Intensity Escalation

    /// Progressive exercise overload leading to body crash.
    static let intensityEscalation = JourneyScenario(
        id: "intensity_escalation",
        name: "Intensity Escalation",
        description: "Normal baseline, then 3 days of escalating workout intensity and steps, "
            + "ending with a body crash from overtraining on day 6.",
        dayCount: 7,
        dayOverrides: [
            // Days 0-2: Normal (no overrides)
            3: DayMetricOverride(steps: 15000, workout: 90),
            4: DayMetricOverride(steps: 18000, workout: 120),
            5: DayMetricOverride(steps: 20000, workout: 150),
            6: DayMetricOverride(sleep: 5, rhrDelta: +8, hrvDelta: -30),
        ],
        criticalDays: [5, 6]
    )

    // MARK: 3. Gradual Deterioration

    /// Slow, steady decline across all metrics over 7 days.
    static let gradualDeterioration = JourneyScenario(
        id: "gradual_deterioration",
        name: "Gradual Deterioration",
        description: "Progressive worsening: sleep drops by 0.5h/day, RHR rises +1.5/day, "
            + "HRV drops -5%/day. Tests whether the system detects slow decline.",
        dayCount: 7,
        dayOverrides: [
            // Day 0: Normal (no overrides)
            1: DayMetricOverride(sleep: -0.5, rhrDelta: +1.5, hrvDelta: -5),
            2: DayMetricOverride(sleep: -1.0, rhrDelta: +3,   hrvDelta: -10),
            3: DayMetricOverride(sleep: -1.5, rhrDelta: +4.5, hrvDelta: -15),
            4: DayMetricOverride(sleep: -2.0, rhrDelta: +6,   hrvDelta: -20),
            5: DayMetricOverride(sleep: -2.5, rhrDelta: +7.5, hrvDelta: -25),
            6: DayMetricOverride(sleep: -3.0, rhrDelta: +9,   hrvDelta: -30),
        ],
        criticalDays: [4, 5, 6]
    )

    // MARK: 4. Rapid Recovery

    /// Starts in poor condition and recovers rapidly over 4 days.
    static let rapidRecovery = JourneyScenario(
        id: "rapid_recovery",
        name: "Rapid Recovery",
        description: "3 days of poor metrics (sleep 3.5h, elevated RHR, depressed HRV) "
            + "followed by rapid recovery. Tests transition from warning to celebration.",
        dayCount: 7,
        dayOverrides: [
            0: DayMetricOverride(sleep: 3.5, rhrDelta: +12, hrvDelta: -40),
            1: DayMetricOverride(sleep: 3.5, rhrDelta: +12, hrvDelta: -40),
            2: DayMetricOverride(sleep: 3.5, rhrDelta: +12, hrvDelta: -40),
            3: DayMetricOverride(sleep: 7,   rhrDelta: +8,  hrvDelta: -25),
            4: DayMetricOverride(sleep: 8,   rhrDelta: +4,  hrvDelta: -10),
            5: DayMetricOverride(sleep: 8.5, rhrDelta: +1,  hrvDelta: -3),
            6: DayMetricOverride(sleep: 9,   rhrDelta: 0,   hrvDelta: 0),
        ],
        criticalDays: [0, 3, 6]
    )

    // MARK: 5. Mixed Signals

    /// Contradictory metrics each day to test coherence under ambiguity.
    static let mixedSignals = JourneyScenario(
        id: "mixed_signals",
        name: "Mixed Signals",
        description: "Each day has contradictory metrics: good sleep + stressed body, "
            + "bad sleep + relaxed body, high activity + low sleep, etc. "
            + "Tests coherence when signals conflict.",
        dayCount: 7,
        dayOverrides: [
            0: DayMetricOverride(sleep: 9,    rhrDelta: +10, hrvDelta: -35),
            1: DayMetricOverride(sleep: 3,    rhrDelta: -3,  hrvDelta: +15),
            2: DayMetricOverride(sleep: 4,    steps: 15000,  workout: 90),
            3: DayMetricOverride(sleep: 10,   steps: 200,    workout: 0),
            // Day 4: Normal balanced day (no overrides)
            5: DayMetricOverride(sleep: 9,    rhrDelta: +10, workout: 120),
            6: DayMetricOverride(sleep: 10,   rhrDelta: +8,  hrvDelta: -25,
                                 steps: 20000, workout: 120),
        ],
        criticalDays: [0, 1, 2, 3, 6]
    )

    /// All journey scenarios.
    static let all: [JourneyScenario] = [
        goodThenCrash,
        intensityEscalation,
        gradualDeterioration,
        rapidRecovery,
        mixedSignals,
    ]
}

// MARK: - Journey x Persona Combinations

/// The 4 base persona types used with each journey.
enum JourneyPersonas {

    static let all: [PersonaBaseline] = [
        TestPersonas.youngAthlete,
        TestPersonas.stressedExecutive,
        TestPersonas.newMom,
        TestPersonas.activeSenior,
    ]

    /// All (journey, persona) combinations: 5 journeys x 4 personas = 20.
    static var allCombinations: [(journey: JourneyScenario, persona: PersonaBaseline)] {
        JourneyScenarios.all.flatMap { journey in
            all.map { persona in (journey: journey, persona: persona) }
        }
    }
}

// MARK: - Override Application

extension PersonaBaseline {

    /// Apply a DayMetricOverride to this baseline and return a HeartSnapshot.
    ///
    /// - Parameters:
    ///   - override: The metric override for this day. nil means use baseline with noise.
    ///   - dayIndex: The day index in the journey (0-based).
    ///   - rng: Seeded RNG for reproducible noise.
    ///   - date: The calendar date for the snapshot.
    /// - Returns: A HeartSnapshot with overrides applied.
    func applyOverride(
        _ override: DayMetricOverride?,
        dayIndex: Int,
        rng: inout SeededRNG,
        date: Date
    ) -> HeartSnapshot {
        let ov = override

        // Sleep: if override sleep is negative, treat as delta from baseline
        let baseSleep: Double
        if let overrideSleep = ov?.sleepHours {
            baseSleep = overrideSleep < 0
                ? max(0, sleepHours + overrideSleep)
                : overrideSleep
        } else {
            baseSleep = sleepHours
        }

        // RHR: baseline + additive delta
        let baseRHR = restingHR + (ov?.rhrDelta ?? 0)

        // HRV: baseline * (1 + percentage/100)
        let baseHRV = hrvSDNN * (1.0 + (ov?.hrvDelta ?? 0) / 100.0)

        // Steps, workout, walk: override replaces baseline
        let baseSteps = ov?.steps ?? steps
        let baseWorkout = ov?.workoutMinutes ?? workoutMinutes
        let baseWalk = ov?.walkMinutes ?? walkMinutes

        return HeartSnapshot(
            date: date,
            restingHeartRate: max(35, min(180, rng.gaussian(mean: baseRHR, sd: rhrNoise))),
            hrvSDNN: max(5, min(250, rng.gaussian(mean: baseHRV, sd: hrvNoise))),
            recoveryHR1m: max(2, rng.gaussian(mean: recoveryHR1m, sd: recoveryNoise)),
            recoveryHR2m: max(2, rng.gaussian(mean: recoveryHR2m, sd: recoveryNoise)),
            vo2Max: max(10, rng.gaussian(mean: vo2Max, sd: 0.8)),
            zoneMinutes: zoneMinutes.map { max(0, rng.gaussian(mean: $0, sd: max(1, $0 * 0.2))) },
            steps: max(0, rng.gaussian(mean: baseSteps, sd: stepsNoise)),
            walkMinutes: max(0, rng.gaussian(mean: baseWalk, sd: 5)),
            workoutMinutes: max(0, rng.gaussian(mean: baseWorkout, sd: 5)),
            sleepHours: max(0, min(14, rng.gaussian(mean: baseSleep, sd: sleepNoise * 0.3))),
            bodyMassKg: weightKg
        )
    }

    /// Generate a full journey history: 7 days of preceding baseline + journey days.
    /// Returns snapshots for the journey days only (journeyDayCount items),
    /// but builds on 7 days of prior history for engine warm-up.
    ///
    /// - Parameters:
    ///   - journey: The journey scenario to apply.
    /// - Returns: Array of HeartSnapshots for the full history (warmup + journey).
    func generateJourneyHistory(journey: JourneyScenario) -> [HeartSnapshot] {
        let warmupDays = 7
        let totalDays = warmupDays + journey.dayCount
        var rng = SeededRNG(seed: stableJourneyHash(journeyID: journey.id))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<totalDays).compactMap { i in
            guard let date = calendar.date(
                byAdding: .day, value: -(totalDays - 1 - i), to: today
            ) else { return nil }

            if i < warmupDays {
                // Warm-up days: baseline with normal noise, no overrides
                return applyOverride(nil, dayIndex: i, rng: &rng, date: date)
            } else {
                let journeyDay = i - warmupDays
                let override = journey.dayOverrides[journeyDay]
                return applyOverride(override, dayIndex: journeyDay, rng: &rng, date: date)
            }
        }
    }

    /// Deterministic hash combining persona name + journey ID.
    private func stableJourneyHash(journeyID: String) -> UInt64 {
        var h: UInt64 = 5381
        for byte in name.utf8 {
            h = h &* 33 &+ UInt64(byte)
        }
        for byte in journeyID.utf8 {
            h = h &* 33 &+ UInt64(byte)
        }
        return h &+ UInt64(age)
    }
}

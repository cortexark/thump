// TimeSeriesTestInfra.swift
// ThumpTests
//
// Shared infrastructure for time-series engine validation.
// Generates 30-day persona histories, runs engines at checkpoints
// (day 1, 2, 7, 14, 20, 25, 30), and stores results to disk
// so downstream engine agents can review upstream outputs.

import Foundation
@testable import Thump

// MARK: - Time Series Checkpoints

/// The days at which we checkpoint engine outputs.
enum TimeSeriesCheckpoint: Int, CaseIterable, Comparable {
    case day1 = 1
    case day2 = 2
    case day7 = 7
    case day14 = 14
    case day20 = 20
    case day25 = 25
    case day30 = 30

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String { "day\(rawValue)" }
}

// MARK: - Engine Result Store

/// Stores engine results per persona per checkpoint to a JSON file on disk.
/// Each engine agent writes its results here; downstream engines read them.
struct EngineResultStore {

    /// Directory where result files are written.
    static var storeDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Results")
    }

    /// Write a result for a specific engine/persona/checkpoint.
    static func write(
        engine: String,
        persona: String,
        checkpoint: TimeSeriesCheckpoint,
        result: [String: Any]
    ) {
        let dir = storeDir
            .appendingPathComponent(engine)
            .appendingPathComponent(persona)

        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)

        let file = dir.appendingPathComponent("\(checkpoint.label).json")

        // Convert to simple JSON-safe dict
        if let data = try? JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: file)
        }
    }

    /// Read results from a previous engine for a persona at a checkpoint.
    static func read(
        engine: String,
        persona: String,
        checkpoint: TimeSeriesCheckpoint
    ) -> [String: Any]? {
        let file = storeDir
            .appendingPathComponent(engine)
            .appendingPathComponent(persona)
            .appendingPathComponent("\(checkpoint.label).json")

        guard let data = try? Data(contentsOf: file),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return dict
    }

    /// Read ALL checkpoints for a persona from a given engine.
    static func readAll(
        engine: String,
        persona: String
    ) -> [TimeSeriesCheckpoint: [String: Any]] {
        var results: [TimeSeriesCheckpoint: [String: Any]] = [:]
        for cp in TimeSeriesCheckpoint.allCases {
            if let r = read(engine: engine, persona: persona, checkpoint: cp) {
                results[cp] = r
            }
        }
        return results
    }

    /// Clear all stored results (call at start of full suite).
    static func clearAll() {
        try? FileManager.default.removeItem(at: storeDir)
        try? FileManager.default.createDirectory(
            at: storeDir, withIntermediateDirectories: true)
    }
}

// MARK: - 30-Day History Generator

/// Deterministic RNG for reproducible persona histories.
struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 33) / Double(UInt64(1) << 31)
    }

    /// Returns a value in [lo, hi].
    mutating func uniform(_ lo: Double, _ hi: Double) -> Double {
        lo + next() * (hi - lo)
    }

    /// Returns true with the given probability [0,1].
    mutating func chance(_ probability: Double) -> Bool {
        next() < probability
    }

    mutating func gaussian(mean: Double, sd: Double) -> Double {
        let u1 = max(next(), 1e-10)
        let u2 = next()
        let normal = (-2.0 * log(u1)).squareRoot() * cos(2.0 * .pi * u2)
        return mean + normal * sd
    }
}

// MARK: - Persona Baseline

/// Defines a persona's physiological and lifestyle baseline for 30-day generation.
struct PersonaBaseline {
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

    // Daily noise standard deviations
    var rhrNoise: Double { 2.0 }
    var hrvNoise: Double { 8.0 }
    var sleepNoise: Double { 0.5 }
    var stepsNoise: Double { 2000.0 }
    var recoveryNoise: Double { 3.0 }

    // Optional trend overlay (e.g., overtraining = RHR rises over last 5 days)
    var trendOverlay: TrendOverlay?
}

/// Defines a progressive trend applied over the 30-day window.
struct TrendOverlay {
    /// Day at which the trend starts (0-indexed).
    let startDay: Int
    /// Per-day RHR delta (positive = rising).
    let rhrDeltaPerDay: Double
    /// Per-day HRV delta (negative = declining).
    let hrvDeltaPerDay: Double
    /// Per-day sleep delta (negative = less sleep).
    let sleepDeltaPerDay: Double
    /// Per-day steps delta.
    let stepsDeltaPerDay: Double
}

// MARK: - 30-Day Snapshot Generation

extension PersonaBaseline {

    /// Deterministic hash — Swift's String.hashValue is randomized per process.
    private var stableNameHash: UInt64 {
        var h: UInt64 = 5381
        for byte in name.utf8 {
            h = h &* 33 &+ UInt64(byte)
        }
        return h
    }

    /// Generate a 30-day history of HeartSnapshots with realistic noise and optional trends.
    func generate30DayHistory() -> [HeartSnapshot] {
        var rng = SeededRNG(seed: stableNameHash &+ UInt64(age))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<30).compactMap { dayIndex in
            guard let date = calendar.date(
                byAdding: .day, value: -(29 - dayIndex), to: today
            ) else { return nil }

            // Apply trend overlay if active
            var rhrBase = restingHR
            var hrvBase = hrvSDNN
            var sleepBase = sleepHours
            var stepsBase = steps

            if let trend = trendOverlay, dayIndex >= trend.startDay {
                let trendDays = Double(dayIndex - trend.startDay)
                rhrBase += trend.rhrDeltaPerDay * trendDays
                hrvBase += trend.hrvDeltaPerDay * trendDays
                sleepBase += trend.sleepDeltaPerDay * trendDays
                stepsBase += trend.stepsDeltaPerDay * trendDays
            }

            return HeartSnapshot(
                date: date,
                restingHeartRate: max(35, min(180, rng.gaussian(mean: rhrBase, sd: rhrNoise))),
                hrvSDNN: max(5, min(250, rng.gaussian(mean: hrvBase, sd: hrvNoise))),
                recoveryHR1m: max(2, rng.gaussian(mean: recoveryHR1m, sd: recoveryNoise)),
                recoveryHR2m: max(2, rng.gaussian(mean: recoveryHR2m, sd: recoveryNoise)),
                vo2Max: max(10, rng.gaussian(mean: vo2Max, sd: 0.8)),
                zoneMinutes: zoneMinutes.map { max(0, rng.gaussian(mean: $0, sd: max(1, $0 * 0.2))) },
                steps: max(0, rng.gaussian(mean: stepsBase, sd: stepsNoise)),
                walkMinutes: max(0, rng.gaussian(mean: walkMinutes, sd: 5)),
                workoutMinutes: max(0, rng.gaussian(mean: workoutMinutes, sd: 5)),
                sleepHours: max(0, min(14, rng.gaussian(mean: sleepBase, sd: sleepNoise))),
                bodyMassKg: weightKg
            )
        }
    }

    /// Get snapshots up to a specific checkpoint day count.
    func snapshotsUpTo(day: Int) -> [HeartSnapshot] {
        Array(generate30DayHistory().prefix(day))
    }
}

// MARK: - KPI Tracker

/// Tracks pass/fail counts per engine for the final KPI report.
class KPITracker {
    struct EngineResult {
        var personasTested: Int = 0
        var passed: Int = 0
        var failed: Int = 0
        var edgeCasesTested: Int = 0
        var edgeCasesPassed: Int = 0
        var checkpointsTested: Int = 0
        var failures: [(persona: String, checkpoint: String, reason: String)] = []
    }

    private var results: [String: EngineResult] = [:]

    func record(engine: String, persona: String, checkpoint: String,
                passed: Bool, reason: String = "") {
        var r = results[engine] ?? EngineResult()
        r.personasTested += 1
        r.checkpointsTested += 1
        if passed {
            r.passed += 1
        } else {
            r.failed += 1
            r.failures.append((persona, checkpoint, reason))
        }
        results[engine] = r
    }

    func recordEdgeCase(engine: String, passed: Bool, reason: String = "") {
        var r = results[engine] ?? EngineResult()
        r.edgeCasesTested += 1
        if passed { r.edgeCasesPassed += 1 }
        else { r.failures.append(("edge-case", "", reason)) }
        results[engine] = r
    }

    func printReport() {
        print("\n" + String(repeating: "=", count: 70))
        print("  THUMP ENGINE KPI REPORT — 30-DAY TIME SERIES VALIDATION")
        print(String(repeating: "=", count: 70))

        var totalTests = 0, totalPassed = 0, totalFailed = 0
        var totalEdge = 0, totalEdgePassed = 0

        for (engine, r) in results.sorted(by: { $0.key < $1.key }) {
            let status = r.failed == 0 ? "✅" : "❌"
            print("\(status) \(engine.padding(toLength: 28, withPad: " ", startingAt: 0)) "
                + "| Checkpoints: \(r.passed)/\(r.personasTested) "
                + "| Edge: \(r.edgeCasesPassed)/\(r.edgeCasesTested)")
            totalTests += r.personasTested
            totalPassed += r.passed
            totalFailed += r.failed
            totalEdge += r.edgeCasesTested
            totalEdgePassed += r.edgeCasesPassed
        }

        print(String(repeating: "-", count: 70))
        let pct = totalTests > 0 ? Double(totalPassed) / Double(totalTests) * 100 : 0
        print("TOTAL: \(totalPassed)/\(totalTests) checkpoint tests (\(String(format: "%.1f", pct))%)")
        print("EDGE:  \(totalEdgePassed)/\(totalEdge) edge case tests")
        print("OVERALL: \(totalPassed + totalEdgePassed)/\(totalTests + totalEdge)")

        // Print failures
        let allFailures = results.flatMap { engine, r in
            r.failures.map { (engine, $0.persona, $0.checkpoint, $0.reason) }
        }
        if !allFailures.isEmpty {
            print("\n⚠️  FAILURES:")
            for (engine, persona, cp, reason) in allFailures {
                print("  [\(engine)] \(persona) @ \(cp): \(reason)")
            }
        }
        print(String(repeating: "=", count: 70) + "\n")
    }
}

// MARK: - 20 Personas

/// All 20 test personas with 30-day baselines.
enum TestPersonas {

    static let all: [PersonaBaseline] = [
        youngAthlete, youngSedentary, activeProfessional, newMom,
        middleAgeFit, middleAgeUnfit, perimenopause, activeSenior,
        sedentarySenior, teenAthlete, overtraining, recoveringIllness,
        stressedExecutive, shiftWorker, weekendWarrior, sleepApnea,
        excellentSleeper, underweightRunner, obeseSedentary, anxietyProfile
    ]

    // 1. Young athlete (22M)
    static let youngAthlete = PersonaBaseline(
        name: "YoungAthlete", age: 22, sex: .male, weightKg: 75,
        restingHR: 50, hrvSDNN: 72, vo2Max: 55, recoveryHR1m: 45, recoveryHR2m: 55,
        sleepHours: 8.5, steps: 14000, walkMinutes: 60, workoutMinutes: 60,
        zoneMinutes: [20, 20, 30, 15, 8]
    )

    // 2. Young sedentary (25F)
    static let youngSedentary = PersonaBaseline(
        name: "YoungSedentary", age: 25, sex: .female, weightKg: 68,
        restingHR: 78, hrvSDNN: 30, vo2Max: 28, recoveryHR1m: 18, recoveryHR2m: 25,
        sleepHours: 6.0, steps: 3000, walkMinutes: 10, workoutMinutes: 0,
        zoneMinutes: [60, 5, 0, 0, 0]
    )

    // 3. Active 30s professional (35M)
    static let activeProfessional = PersonaBaseline(
        name: "ActiveProfessional", age: 35, sex: .male, weightKg: 82,
        restingHR: 62, hrvSDNN: 48, vo2Max: 42, recoveryHR1m: 32, recoveryHR2m: 42,
        sleepHours: 7.2, steps: 9000, walkMinutes: 35, workoutMinutes: 30,
        zoneMinutes: [40, 25, 20, 8, 3]
    )

    // 4. New mom (32F) — sleep deprived, stressed, poor autonomic recovery
    static let newMom = PersonaBaseline(
        name: "NewMom", age: 32, sex: .female, weightKg: 70,
        restingHR: 75, hrvSDNN: 28, vo2Max: 30, recoveryHR1m: 15, recoveryHR2m: 22,
        sleepHours: 3.5, steps: 4000, walkMinutes: 15, workoutMinutes: 0,
        zoneMinutes: [45, 10, 0, 0, 0]
    )

    // 5. Middle-aged fit (45M) — marathon runner
    static let middleAgeFit = PersonaBaseline(
        name: "MiddleAgeFit", age: 45, sex: .male, weightKg: 73,
        restingHR: 52, hrvSDNN: 55, vo2Max: 50, recoveryHR1m: 40, recoveryHR2m: 50,
        sleepHours: 7.8, steps: 12000, walkMinutes: 50, workoutMinutes: 55,
        zoneMinutes: [25, 20, 30, 15, 8]
    )

    // 6. Middle-aged unfit (48F) — overweight, poor sleep
    static let middleAgeUnfit = PersonaBaseline(
        name: "MiddleAgeUnfit", age: 48, sex: .female, weightKg: 95,
        restingHR: 80, hrvSDNN: 22, vo2Max: 24, recoveryHR1m: 15, recoveryHR2m: 22,
        sleepHours: 5.5, steps: 2500, walkMinutes: 10, workoutMinutes: 0,
        zoneMinutes: [55, 5, 0, 0, 0]
    )

    // 7. Perimenopause (50F) — hormonal HRV fluctuation
    static let perimenopause = PersonaBaseline(
        name: "Perimenopause", age: 50, sex: .female, weightKg: 72,
        restingHR: 68, hrvSDNN: 35, vo2Max: 33, recoveryHR1m: 25, recoveryHR2m: 33,
        sleepHours: 6.5, steps: 7000, walkMinutes: 30, workoutMinutes: 20,
        zoneMinutes: [40, 20, 15, 5, 0]
    )

    // 8. Active senior (65M) — daily walker
    static let activeSenior = PersonaBaseline(
        name: "ActiveSenior", age: 65, sex: .male, weightKg: 78,
        restingHR: 60, hrvSDNN: 35, vo2Max: 35, recoveryHR1m: 28, recoveryHR2m: 36,
        sleepHours: 7.5, steps: 10000, walkMinutes: 60, workoutMinutes: 25,
        zoneMinutes: [50, 30, 15, 3, 0]
    )

    // 9. Sedentary senior (70F) — minimal activity
    static let sedentarySenior = PersonaBaseline(
        name: "SedentarySenior", age: 70, sex: .female, weightKg: 70,
        restingHR: 74, hrvSDNN: 20, vo2Max: 22, recoveryHR1m: 12, recoveryHR2m: 18,
        sleepHours: 6.0, steps: 1500, walkMinutes: 8, workoutMinutes: 0,
        zoneMinutes: [55, 5, 0, 0, 0]
    )

    // 10. Teen athlete (17M)
    static let teenAthlete = PersonaBaseline(
        name: "TeenAthlete", age: 17, sex: .male, weightKg: 68,
        restingHR: 48, hrvSDNN: 80, vo2Max: 58, recoveryHR1m: 48, recoveryHR2m: 58,
        sleepHours: 8.0, steps: 15000, walkMinutes: 45, workoutMinutes: 70,
        zoneMinutes: [15, 15, 35, 18, 10]
    )

    // 11. Overtraining syndrome — RHR rises progressively last 5 days
    static let overtraining = PersonaBaseline(
        name: "Overtraining", age: 30, sex: .male, weightKg: 78,
        restingHR: 58, hrvSDNN: 50, vo2Max: 45, recoveryHR1m: 35, recoveryHR2m: 44,
        sleepHours: 6.5, steps: 11000, walkMinutes: 40, workoutMinutes: 50,
        zoneMinutes: [20, 20, 25, 15, 10],
        trendOverlay: TrendOverlay(
            startDay: 25, rhrDeltaPerDay: 3.0, hrvDeltaPerDay: -4.0,
            sleepDeltaPerDay: -0.2, stepsDeltaPerDay: -500
        )
    )

    // 12. Recovering from illness — RHR was high, slowly normalizing
    static let recoveringIllness = PersonaBaseline(
        name: "RecoveringIllness", age: 40, sex: .female, weightKg: 65,
        restingHR: 80, hrvSDNN: 25, vo2Max: 30, recoveryHR1m: 15, recoveryHR2m: 22,
        sleepHours: 8.0, steps: 3000, walkMinutes: 15, workoutMinutes: 0,
        zoneMinutes: [60, 5, 0, 0, 0],
        trendOverlay: TrendOverlay(
            startDay: 10, rhrDeltaPerDay: -1.0, hrvDeltaPerDay: 1.5,
            sleepDeltaPerDay: 0, stepsDeltaPerDay: 200
        )
    )

    // 13. High stress executive (42M)
    static let stressedExecutive = PersonaBaseline(
        name: "StressedExecutive", age: 42, sex: .male, weightKg: 88,
        restingHR: 76, hrvSDNN: 25, vo2Max: 34, recoveryHR1m: 20, recoveryHR2m: 28,
        sleepHours: 5.0, steps: 4000, walkMinutes: 15, workoutMinutes: 5,
        zoneMinutes: [55, 10, 3, 0, 0]
    )

    // 14. Shift worker (35F) — erratic sleep
    static let shiftWorker = PersonaBaseline(
        name: "ShiftWorker", age: 35, sex: .female, weightKg: 68,
        restingHR: 70, hrvSDNN: 35, vo2Max: 32, recoveryHR1m: 24, recoveryHR2m: 32,
        sleepHours: 5.5, steps: 7000, walkMinutes: 30, workoutMinutes: 15,
        zoneMinutes: [45, 20, 10, 3, 0]
    )

    // 15. Weekend warrior (40M)
    static let weekendWarrior = PersonaBaseline(
        name: "WeekendWarrior", age: 40, sex: .male, weightKg: 85,
        restingHR: 72, hrvSDNN: 38, vo2Max: 36, recoveryHR1m: 25, recoveryHR2m: 33,
        sleepHours: 6.5, steps: 5000, walkMinutes: 15, workoutMinutes: 10,
        zoneMinutes: [50, 15, 8, 3, 0]
    )

    // 16. Sleep apnea profile (55M)
    static let sleepApnea = PersonaBaseline(
        name: "SleepApnea", age: 55, sex: .male, weightKg: 100,
        restingHR: 75, hrvSDNN: 22, vo2Max: 28, recoveryHR1m: 16, recoveryHR2m: 23,
        sleepHours: 5.0, steps: 4000, walkMinutes: 15, workoutMinutes: 5,
        zoneMinutes: [55, 10, 3, 0, 0]
    )

    // 17. Excellent sleeper (28F)
    static let excellentSleeper = PersonaBaseline(
        name: "ExcellentSleeper", age: 28, sex: .female, weightKg: 60,
        restingHR: 60, hrvSDNN: 55, vo2Max: 40, recoveryHR1m: 35, recoveryHR2m: 44,
        sleepHours: 8.5, steps: 8000, walkMinutes: 35, workoutMinutes: 25,
        zoneMinutes: [35, 25, 20, 8, 3]
    )

    // 18. Underweight runner (30F)
    static let underweightRunner = PersonaBaseline(
        name: "UnderweightRunner", age: 30, sex: .female, weightKg: 48,
        restingHR: 52, hrvSDNN: 65, vo2Max: 52, recoveryHR1m: 42, recoveryHR2m: 52,
        sleepHours: 7.5, steps: 13000, walkMinutes: 50, workoutMinutes: 55,
        zoneMinutes: [20, 20, 30, 15, 8]
    )

    // 19. Obese sedentary (50M)
    static let obeseSedentary = PersonaBaseline(
        name: "ObeseSedentary", age: 50, sex: .male, weightKg: 120,
        restingHR: 82, hrvSDNN: 18, vo2Max: 22, recoveryHR1m: 12, recoveryHR2m: 18,
        sleepHours: 5.5, steps: 2000, walkMinutes: 8, workoutMinutes: 0,
        zoneMinutes: [60, 3, 0, 0, 0]
    )

    // 20. Anxiety/stress profile (27F)
    static let anxietyProfile = PersonaBaseline(
        name: "AnxietyProfile", age: 27, sex: .female, weightKg: 58,
        restingHR: 74, hrvSDNN: 28, vo2Max: 35, recoveryHR1m: 22, recoveryHR2m: 30,
        sleepHours: 5.5, steps: 6000, walkMinutes: 25, workoutMinutes: 15,
        zoneMinutes: [45, 15, 10, 3, 0]
    )
}

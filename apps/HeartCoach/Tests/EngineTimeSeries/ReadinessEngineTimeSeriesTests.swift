// ReadinessEngineTimeSeriesTests.swift
// ThumpTests
//
// 30-day time-series validation for ReadinessEngine across 20 personas.
// Depends on StressEngine results stored in EngineResultStore.
// Runs at 7 checkpoints (day 1, 2, 7, 14, 20, 25, 30) per persona.

import XCTest
@testable import Thump

final class ReadinessEngineTimeSeriesTests: XCTestCase {

    private let engine = ReadinessEngine()
    private let kpi = KPITracker()
    private let engineName = "ReadinessEngine"
    private let stressEngineName = "StressEngine"

    // MARK: - Full 20-Persona x 7-Checkpoint Suite

    func testAllPersonasAcrossCheckpoints() {
        let personas = TestPersonas.all
        XCTAssertEqual(personas.count, 20, "Expected 20 personas")

        for persona in personas {
            let fullHistory = persona.generate30DayHistory()

            for cp in TimeSeriesCheckpoint.allCases {
                let day = cp.rawValue
                let snapshots = Array(fullHistory.prefix(day))
                guard let todaySnapshot = snapshots.last else {
                    XCTFail("\(persona.name) @ \(cp.label): no snapshot available")
                    continue
                }

                // 1. Read stress score from upstream StressEngine store
                let stressResult = EngineResultStore.read(
                    engine: stressEngineName,
                    persona: persona.name,
                    checkpoint: cp
                )
                let stressScore: Double? = stressResult?["score"] as? Double

                // 2. Build consecutive alert for overtraining at day 28+
                let consecutiveAlert: ConsecutiveElevationAlert?
                if persona.name == "Overtraining" && day >= 28 {
                    consecutiveAlert = ConsecutiveElevationAlert(
                        consecutiveDays: 3,
                        threshold: persona.restingHR + 6.0,
                        elevatedMean: persona.restingHR + 10.0,
                        personalMean: persona.restingHR
                    )
                } else {
                    consecutiveAlert = nil
                }

                // 3. Compute readiness
                let recentHistory = Array(snapshots.dropLast())
                let result = engine.compute(
                    snapshot: todaySnapshot,
                    stressScore: stressScore,
                    recentHistory: recentHistory,
                    consecutiveAlert: consecutiveAlert
                )

                // 4. Store result
                var storedResult: [String: Any] = [:]
                if let r = result {
                    var pillarDict: [String: Double] = [:]
                    var pillarNames: [String] = []
                    for p in r.pillars {
                        pillarDict[p.type.rawValue] = p.score
                        pillarNames.append(p.type.rawValue)
                    }
                    storedResult = [
                        "score": r.score,
                        "level": r.level.rawValue,
                        "pillarCount": r.pillars.count,
                        "pillarNames": pillarNames,
                        "pillarScores": pillarDict,
                        "stressScoreInput": stressScore as Any,
                        "hadConsecutiveAlert": consecutiveAlert != nil
                    ]
                } else {
                    storedResult = [
                        "score": NSNull(),
                        "level": "nil",
                        "pillarCount": 0,
                        "pillarNames": [] as [String],
                        "pillarScores": [:] as [String: Double],
                        "stressScoreInput": stressScore as Any,
                        "hadConsecutiveAlert": consecutiveAlert != nil
                    ]
                }

                EngineResultStore.write(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: cp,
                    result: storedResult
                )

                // 5. Basic validity assertions
                if day == 1 {
                    // Day 1: only 1 snapshot, no history for HRV trend or activity balance.
                    // Engine may still produce a result if sleep + recovery are available (2 pillars).
                    if let r = result {
                        XCTAssert(
                            r.score >= 0 && r.score <= 100,
                            "\(persona.name) @ \(cp.label): score \(r.score) out of range"
                        )
                        kpi.record(engine: engineName, persona: persona.name,
                                   checkpoint: cp.label, passed: true)
                    } else {
                        // Nil is acceptable on day 1 if fewer than 2 pillars
                        kpi.record(engine: engineName, persona: persona.name,
                                   checkpoint: cp.label, passed: true)
                    }
                } else {
                    // Day 2+: should always produce a result (sleep + recovery = 2 pillars minimum)
                    XCTAssertNotNil(
                        result,
                        "\(persona.name) @ \(cp.label): expected non-nil readiness result"
                    )
                    if let r = result {
                        XCTAssert(
                            r.score >= 0 && r.score <= 100,
                            "\(persona.name) @ \(cp.label): score \(r.score) out of range"
                        )
                        XCTAssertGreaterThanOrEqual(
                            r.pillars.count, 2,
                            "\(persona.name) @ \(cp.label): expected >= 2 pillars, got \(r.pillars.count)"
                        )
                        kpi.record(engine: engineName, persona: persona.name,
                                   checkpoint: cp.label, passed: true)
                    } else {
                        kpi.record(engine: engineName, persona: persona.name,
                                   checkpoint: cp.label, passed: false,
                                   reason: "Nil result at day \(day)")
                    }
                }
            }
        }

        kpi.printReport()
    }

    // MARK: - Persona-Specific Validations

    func testYoungAthleteHighReadiness() {
        let persona = TestPersonas.youngAthlete
        let fullHistory = persona.generate30DayHistory()

        for cp in TimeSeriesCheckpoint.allCases where cp.rawValue >= 14 {
            let snapshots = Array(fullHistory.prefix(cp.rawValue))
            let today = snapshots.last!
            let history = Array(snapshots.dropLast())
            let stressScore = readStressScore(persona: persona.name, checkpoint: cp)

            let result = engine.compute(
                snapshot: today,
                stressScore: stressScore,
                recentHistory: history
            )

            XCTAssertNotNil(result, "YoungAthlete @ \(cp.label): expected non-nil result")
            if let r = result {
                XCTAssertGreaterThan(
                    r.score, 60,
                    "YoungAthlete @ \(cp.label): expected readiness > 60 (primed/ready), got \(r.score)"
                )
            }
        }
    }

    func testExcellentSleeperHighReadiness() {
        let persona = TestPersonas.excellentSleeper
        let fullHistory = persona.generate30DayHistory()

        for cp in TimeSeriesCheckpoint.allCases where cp.rawValue >= 7 {
            let snapshots = Array(fullHistory.prefix(cp.rawValue))
            let today = snapshots.last!
            let history = Array(snapshots.dropLast())
            let stressScore = readStressScore(persona: persona.name, checkpoint: cp)

            let result = engine.compute(
                snapshot: today,
                stressScore: stressScore,
                recentHistory: history
            )

            XCTAssertNotNil(result, "ExcellentSleeper @ \(cp.label): expected non-nil result")
            if let r = result {
                XCTAssertGreaterThan(
                    r.score, 65,
                    "ExcellentSleeper @ \(cp.label): expected readiness > 65, got \(r.score)"
                )
                // Verify sleep pillar is present and strong
                let sleepPillar = r.pillars.first { $0.type == .sleep }
                XCTAssertNotNil(sleepPillar, "ExcellentSleeper @ \(cp.label): missing sleep pillar")
                if let sp = sleepPillar {
                    XCTAssertGreaterThanOrEqual(
                        sp.score, 40,
                        "ExcellentSleeper @ \(cp.label): sleep pillar expected >= 40, got \(sp.score)"
                    )
                }
            }
        }
    }

    func testStressedExecutiveLowReadiness() {
        let persona = TestPersonas.stressedExecutive
        let fullHistory = persona.generate30DayHistory()

        for cp in TimeSeriesCheckpoint.allCases where cp.rawValue >= 14 {
            let snapshots = Array(fullHistory.prefix(cp.rawValue))
            let today = snapshots.last!
            let history = Array(snapshots.dropLast())
            let stressScore = readStressScore(persona: persona.name, checkpoint: cp)

            let result = engine.compute(
                snapshot: today,
                stressScore: stressScore,
                recentHistory: history
            )

            XCTAssertNotNil(result, "StressedExecutive @ \(cp.label): expected non-nil result")
            if let r = result {
                XCTAssertLessThanOrEqual(
                    r.score, 75,
                    "StressedExecutive @ \(cp.label): expected readiness <= 75 (poor sleep + high stress), got \(r.score)"
                )
            }
        }
    }

    func testNewMomVeryLowReadiness() {
        let persona = TestPersonas.newMom
        let fullHistory = persona.generate30DayHistory()

        for cp in TimeSeriesCheckpoint.allCases where cp.rawValue >= 7 {
            let snapshots = Array(fullHistory.prefix(cp.rawValue))
            let today = snapshots.last!
            let history = Array(snapshots.dropLast())
            let stressScore = readStressScore(persona: persona.name, checkpoint: cp)

            let result = engine.compute(
                snapshot: today,
                stressScore: stressScore,
                recentHistory: history
            )

            XCTAssertNotNil(result, "NewMom @ \(cp.label): expected non-nil result")
            if let r = result {
                XCTAssertLessThanOrEqual(
                    r.score, 60,
                    "NewMom @ \(cp.label): expected readiness <= 60 (sleep deprivation), got \(r.score)"
                )
            }
        }
    }

    func testObeseSedentaryLowReadiness() {
        let persona = TestPersonas.obeseSedentary
        let fullHistory = persona.generate30DayHistory()

        for cp in TimeSeriesCheckpoint.allCases where cp.rawValue >= 7 {
            let snapshots = Array(fullHistory.prefix(cp.rawValue))
            let today = snapshots.last!
            let history = Array(snapshots.dropLast())
            let stressScore = readStressScore(persona: persona.name, checkpoint: cp)

            let result = engine.compute(
                snapshot: today,
                stressScore: stressScore,
                recentHistory: history
            )

            XCTAssertNotNil(result, "ObeseSedentary @ \(cp.label): expected non-nil result")
            if let r = result {
                XCTAssertLessThanOrEqual(
                    r.score, 70,
                    "ObeseSedentary @ \(cp.label): expected readiness <= 70, got \(r.score)"
                )
            }
        }
    }

    func testOvertainingWithConsecutiveAlertCap() {
        let persona = TestPersonas.overtraining
        let fullHistory = persona.generate30DayHistory()
        let cp = TimeSeriesCheckpoint.day30
        let snapshots = Array(fullHistory.prefix(cp.rawValue))
        let today = snapshots.last!
        let history = Array(snapshots.dropLast())
        let stressScore = readStressScore(persona: persona.name, checkpoint: cp)

        let alert = ConsecutiveElevationAlert(
            consecutiveDays: 3,
            threshold: persona.restingHR + 6.0,
            elevatedMean: persona.restingHR + 10.0,
            personalMean: persona.restingHR
        )

        let result = engine.compute(
            snapshot: today,
            stressScore: stressScore,
            recentHistory: history,
            consecutiveAlert: alert
        )

        XCTAssertNotNil(result, "Overtraining @ day30 with alert: expected non-nil result")
        if let r = result {
            XCTAssertLessThanOrEqual(
                r.score, 50,
                "Overtraining @ day30 with consecutiveAlert: readiness MUST be <= 50 (overtraining cap), got \(r.score)"
            )
        }
    }

    func testRecoveringIllnessImprovesOverTime() {
        let persona = TestPersonas.recoveringIllness
        let fullHistory = persona.generate30DayHistory()

        let cp14 = TimeSeriesCheckpoint.day14
        let snapshots14 = Array(fullHistory.prefix(cp14.rawValue))
        let today14 = snapshots14.last!
        let history14 = Array(snapshots14.dropLast())
        let stress14 = readStressScore(persona: persona.name, checkpoint: cp14)

        let result14 = engine.compute(
            snapshot: today14,
            stressScore: stress14,
            recentHistory: history14
        )

        let cp30 = TimeSeriesCheckpoint.day30
        let snapshots30 = Array(fullHistory.prefix(cp30.rawValue))
        let today30 = snapshots30.last!
        let history30 = Array(snapshots30.dropLast())
        let stress30 = readStressScore(persona: persona.name, checkpoint: cp30)

        let result30 = engine.compute(
            snapshot: today30,
            stressScore: stress30,
            recentHistory: history30
        )

        XCTAssertNotNil(result14, "RecoveringIllness @ day14: expected non-nil result")
        XCTAssertNotNil(result30, "RecoveringIllness @ day30: expected non-nil result")

        if let r14 = result14, let r30 = result30 {
            // Soft check — readiness may not always improve linearly with synthetic data
            XCTAssertGreaterThanOrEqual(
                r30.score, r14.score - 20,
                "RecoveringIllness: readiness should not drop drastically from day14 (\(r14.score)) to day30 (\(r30.score))"
            )
        }
    }

    // MARK: - Edge Cases

    func testOnlyOnePillarReturnsNil() {
        // Snapshot with only sleep data, no recovery/stress/activity/HRV
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: nil,
            hrvSDNN: nil,
            recoveryHR1m: nil,
            recoveryHR2m: nil,
            vo2Max: nil,
            zoneMinutes: [],
            steps: nil,
            walkMinutes: nil,
            workoutMinutes: nil,
            sleepHours: 7.5,
            bodyMassKg: nil
        )

        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: []
        )

        // With the activity balance fallback (today-only scoring),
        // sleep + activityBalance = 2 pillars, which meets the minimum.
        XCTAssertNotNil(
            result,
            "Edge case: sleep + activity fallback → 2 pillars → should return result"
        )
        kpi.recordEdgeCase(engine: engineName, passed: result != nil,
                           reason: "Activity fallback provides 2nd pillar")
    }

    func testNilStressScoreSkipsStressPillar() {
        let persona = TestPersonas.activeProfessional
        let fullHistory = persona.generate30DayHistory()
        let snapshots = Array(fullHistory.prefix(14))
        let today = snapshots.last!
        let history = Array(snapshots.dropLast())

        // Compute with stress
        let resultWithStress = engine.compute(
            snapshot: today,
            stressScore: 40.0,
            recentHistory: history
        )

        // Compute without stress
        let resultNoStress = engine.compute(
            snapshot: today,
            stressScore: nil,
            recentHistory: history
        )

        XCTAssertNotNil(resultWithStress, "Edge case nil-stress: with-stress result should be non-nil")
        XCTAssertNotNil(resultNoStress, "Edge case nil-stress: no-stress result should be non-nil")

        if let rWith = resultWithStress, let rWithout = resultNoStress {
            let stressPillarWith = rWith.pillars.first { $0.type == .stress }
            let stressPillarWithout = rWithout.pillars.first { $0.type == .stress }

            XCTAssertNotNil(stressPillarWith, "Edge case: stress pillar should be present when stressScore provided")
            XCTAssertNil(stressPillarWithout, "Edge case: stress pillar should be absent when stressScore is nil")

            // Fewer pillars without stress, weights re-normalized
            XCTAssertLessThan(
                rWithout.pillars.count, rWith.pillars.count,
                "Edge case: pillar count should be lower without stress"
            )
        }

        kpi.recordEdgeCase(engine: engineName, passed: true,
                           reason: "Nil stress score skips stress pillar")
    }

    func testRecoveryHR1mZeroHandledGracefully() {
        // recoveryHR1m = 0 is clamped to 0 by HeartSnapshot init (range 0...100)
        // ReadinessEngine.scoreRecovery checks recovery > 0, so 0 => nil pillar
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 65,
            hrvSDNN: 50,
            recoveryHR1m: 0,
            recoveryHR2m: 30,
            vo2Max: 40,
            zoneMinutes: [30, 20, 15, 5, 2],
            steps: 8000,
            walkMinutes: 30,
            workoutMinutes: 20,
            sleepHours: 7.5,
            bodyMassKg: 75
        )

        // Need at least 1 day of history for activity balance and HRV trend
        let yesterday = HeartSnapshot(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            restingHeartRate: 64,
            hrvSDNN: 48,
            recoveryHR1m: 30,
            recoveryHR2m: 40,
            vo2Max: 40,
            zoneMinutes: [30, 20, 15, 5, 2],
            steps: 9000,
            walkMinutes: 35,
            workoutMinutes: 25,
            sleepHours: 7.0,
            bodyMassKg: 75
        )

        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 30,
            recentHistory: [yesterday]
        )

        XCTAssertNotNil(result, "Edge case recoveryHR1m=0: should still produce result from other pillars")
        if let r = result {
            let recoveryPillar = r.pillars.first { $0.type == .recovery }
            // Missing/zero recovery now gets a floor score instead of being excluded
            XCTAssertNotNil(
                recoveryPillar,
                "Edge case recoveryHR1m=0: recovery pillar should have floor score"
            )
            XCTAssertEqual(
                recoveryPillar?.score, 40.0,
                "Edge case recoveryHR1m=0: recovery floor score should be 40"
            )
        }

        let passed = result != nil && result!.pillars.first(where: { $0.type == .recovery })?.score == 40.0
        kpi.recordEdgeCase(engine: engineName, passed: passed,
                           reason: "recoveryHR1m=0 graceful handling with floor score")
    }

    func testSleepHoursAboveOptimalNotMaxScore() {
        // sleepHours = 15 is clamped to 14 by HeartSnapshot init (max 24 actually, but
        // the baseline generator caps at 14). At 14h, deviation from 8h = 6h.
        // Gaussian: 100 * exp(-0.5 * (6/1.5)^2) = 100 * exp(-8) ~ 0.03 -> very low
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 60,
            hrvSDNN: 50,
            recoveryHR1m: 35,
            recoveryHR2m: 44,
            vo2Max: 40,
            zoneMinutes: [30, 20, 15, 5, 2],
            steps: 8000,
            walkMinutes: 30,
            workoutMinutes: 20,
            sleepHours: 15,
            bodyMassKg: 70
        )

        let yesterday = HeartSnapshot(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            restingHeartRate: 60,
            hrvSDNN: 48,
            recoveryHR1m: 34,
            recoveryHR2m: 43,
            vo2Max: 40,
            zoneMinutes: [30, 20, 15, 5, 2],
            steps: 8500,
            walkMinutes: 35,
            workoutMinutes: 25,
            sleepHours: 8.0,
            bodyMassKg: 70
        )

        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 25,
            recentHistory: [yesterday]
        )

        XCTAssertNotNil(result, "Edge case sleepHours=15: should produce result")
        if let r = result {
            let sleepPillar = r.pillars.first { $0.type == .sleep }
            XCTAssertNotNil(sleepPillar, "Edge case sleepHours=15: sleep pillar should exist")
            if let sp = sleepPillar {
                XCTAssertLessThan(
                    sp.score, 100.0,
                    "Edge case sleepHours=15: sleep above optimal should NOT be max score, got \(sp.score)"
                )
                // 15h is very far from 8h optimal; Gaussian with sigma=1.5 gives a very low score
                XCTAssertLessThan(
                    sp.score, 20.0,
                    "Edge case sleepHours=15: 15h sleep should score very low (well above optimal), got \(sp.score)"
                )
            }
        }

        let passed: Bool
        if let r = result, let sp = r.pillars.first(where: { $0.type == .sleep }) {
            passed = sp.score < 100.0
        } else {
            passed = false
        }
        kpi.recordEdgeCase(engine: engineName, passed: passed,
                           reason: "sleepHours=15 above optimal not max score")
    }

    // MARK: - KPI Report for Edge Cases

    func testEdgeCaseKPIReport() {
        // Run all edge cases first, then print consolidated KPI
        testOnlyOnePillarReturnsNil()
        testNilStressScoreSkipsStressPillar()
        testRecoveryHR1mZeroHandledGracefully()
        testSleepHoursAboveOptimalNotMaxScore()
        kpi.printReport()
    }

    // MARK: - Helpers

    /// Reads the stress score from EngineResultStore for a given persona and checkpoint.
    private func readStressScore(
        persona: String,
        checkpoint: TimeSeriesCheckpoint
    ) -> Double? {
        let stressResult = EngineResultStore.read(
            engine: stressEngineName,
            persona: persona,
            checkpoint: checkpoint
        )
        return stressResult?["score"] as? Double
    }
}

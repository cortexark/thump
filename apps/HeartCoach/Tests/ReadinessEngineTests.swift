// ReadinessEngineTests.swift
// ThumpTests
//
// Tests for the ReadinessEngine: pillar scoring, weight normalization,
// edge cases, composite score thresholds, and user profile scenarios.

import XCTest
@testable import Thump

final class ReadinessEngineTests: XCTestCase {

    private var engine: ReadinessEngine!

    override func setUp() {
        super.setUp()
        engine = ReadinessEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Minimum Data Requirements

    func testCompute_noPillars_returnsFloorScore() {
        // Snapshot with no usable data → floor scores for sleep + recovery
        // (no longer returns nil — missing critical pillars get penalty scores)
        let snapshot = HeartSnapshot(date: Date())
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: []
        )
        XCTAssertNotNil(result, "Missing pillars should get floor scores, not be excluded")
        if let result {
            XCTAssertLessThanOrEqual(result.score, 50, "Floor scores should produce a conservative result")
        }
    }

    func testCompute_onlyOnePillar_returnsNil() {
        // Sleep + activityBalance fallback (from today's zero activity) → 2 pillars
        // Previously this returned nil with only 1 pillar, but the activity balance
        // fallback now produces a today-only score even without history.
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 8.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: []
        )
        XCTAssertNotNil(result, "Activity balance fallback should provide 2nd pillar")
    }

    func testCompute_twoPillars_returnsResult() {
        // Sleep + stress → 2 pillars, should produce a result
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 8.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 30.0,
            recentHistory: []
        )
        XCTAssertNotNil(result)
    }

    // MARK: - Sleep Pillar

    func testSleep_optimalRange_highScore() {
        // 8 hours = dead center of bell curve → ~100
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 8.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 50.0,
            recentHistory: []
        )
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertGreaterThan(sleepPillar!.score, 95.0,
            "8h sleep should score ~100")
    }

    func testSleep_7hours_stillHigh() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 7.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 50.0,
            recentHistory: []
        )
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertGreaterThan(sleepPillar!.score, 80.0,
            "7h sleep should still score well")
    }

    func testSleep_5hours_degraded() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 5.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 50.0,
            recentHistory: []
        )
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertLessThan(sleepPillar!.score, 50.0,
            "5h sleep should have a degraded score")
    }

    func testSleep_11hours_oversleep_degraded() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 11.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 50.0,
            recentHistory: []
        )
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertLessThan(sleepPillar!.score, 50.0,
            "11h oversleep should degrade the score")
    }

    func testSleep_zero_getsFloorScore() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 50.0,
            recentHistory: []
        )
        XCTAssertNotNil(result)
        if let r = result {
            let sleepPillar = r.pillars.first { $0.type == .sleep }
            XCTAssertNotNil(sleepPillar, "Sleep pillar should be present with floor score")
            XCTAssertLessThanOrEqual(sleepPillar?.score ?? 100, 5.0, "Zero sleep should score near 0")
        }
    }

    // MARK: - Recovery Pillar

    func testRecovery_40bpmDrop_maxScore() {
        let snapshot = HeartSnapshot(
            date: Date(), recoveryHR1m: 40.0, sleepHours: 8.0
        )
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: []
        )
        let recoveryPillar = result?.pillars.first { $0.type == .recovery }
        XCTAssertNotNil(recoveryPillar)
        XCTAssertEqual(recoveryPillar!.score, 100.0, accuracy: 0.1)
    }

    func testRecovery_50bpmDrop_stillMax() {
        // Above threshold should cap at 100
        let snapshot = HeartSnapshot(
            date: Date(), recoveryHR1m: 50.0, sleepHours: 8.0
        )
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: []
        )
        let recoveryPillar = result?.pillars.first { $0.type == .recovery }
        XCTAssertNotNil(recoveryPillar)
        XCTAssertEqual(recoveryPillar!.score, 100.0, accuracy: 0.1)
    }

    func testRecovery_25bpmDrop_midRange() {
        let snapshot = HeartSnapshot(
            date: Date(), recoveryHR1m: 25.0, sleepHours: 8.0
        )
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: []
        )
        let recoveryPillar = result?.pillars.first { $0.type == .recovery }
        XCTAssertNotNil(recoveryPillar)
        XCTAssertEqual(recoveryPillar!.score, 50.0, accuracy: 1.0,
            "25 bpm drop should be ~50% (midpoint of 10-40 range)")
    }

    func testRecovery_10bpmDrop_zero() {
        let snapshot = HeartSnapshot(
            date: Date(), recoveryHR1m: 10.0, sleepHours: 8.0
        )
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: []
        )
        let recoveryPillar = result?.pillars.first { $0.type == .recovery }
        XCTAssertNotNil(recoveryPillar)
        XCTAssertEqual(recoveryPillar!.score, 0.0, accuracy: 0.1)
    }

    func testRecovery_nil_getsFloorScore() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 8.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 50.0,
            recentHistory: []
        )
        let recoveryPillar = result?.pillars.first { $0.type == .recovery }
        XCTAssertNotNil(recoveryPillar, "Missing recovery should get floor score")
        XCTAssertEqual(recoveryPillar?.score, 40.0, "Missing recovery floor score should be 40")
    }

    // MARK: - Stress Pillar

    func testStress_zeroStress_maxReadiness() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 8.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 0.0,
            recentHistory: []
        )
        let stressPillar = result?.pillars.first(where: { $0.type == .stress })
        XCTAssertNotNil(stressPillar)
        XCTAssertEqual(stressPillar!.score, 100.0, accuracy: 0.1)
    }

    func testStress_100stress_zeroReadiness() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 8.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 100.0,
            recentHistory: []
        )
        let stressPillar = result?.pillars.first(where: { $0.type == .stress })
        XCTAssertNotNil(stressPillar)
        XCTAssertEqual(stressPillar!.score, 0.0, accuracy: 0.1)
    }

    func testStress_50_midpoint() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 8.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 50.0,
            recentHistory: []
        )
        let stressPillar = result?.pillars.first(where: { $0.type == .stress })
        XCTAssertNotNil(stressPillar)
        XCTAssertEqual(stressPillar!.score, 50.0, accuracy: 0.1)
    }

    func testStress_nil_excludesPillar() {
        let snapshot = HeartSnapshot(date: Date(), recoveryHR1m: 30.0, sleepHours: 8.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: []
        )
        let stressPillar = result?.pillars.first(where: { $0.type == .stress })
        XCTAssertNil(stressPillar)
    }

    // MARK: - HRV Trend Pillar

    func testHRVTrend_aboveAverage_maxScore() {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = HeartSnapshot(date: today, hrvSDNN: 60.0, sleepHours: 8.0)
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                hrvSDNN: 50.0
            )
        }
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: history
        )
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        XCTAssertNotNil(hrvPillar)
        XCTAssertEqual(hrvPillar!.score, 100.0, accuracy: 0.1,
            "HRV above 7-day average should score 100")
    }

    func testHRVTrend_20PercentBelow_degraded() {
        let today = Calendar.current.startOfDay(for: Date())
        // Average is 50, today is 40 → 20% below → loses 40 points
        let snapshot = HeartSnapshot(date: today, hrvSDNN: 40.0, sleepHours: 8.0)
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                hrvSDNN: 50.0
            )
        }
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: history
        )
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        XCTAssertNotNil(hrvPillar)
        XCTAssertEqual(hrvPillar!.score, 60.0, accuracy: 5.0,
            "20% below average should score ~60")
    }

    func testHRVTrend_noHistory_excludesPillar() {
        let snapshot = HeartSnapshot(date: Date(), hrvSDNN: 50.0, sleepHours: 8.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 50.0,
            recentHistory: []
        )
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        XCTAssertNil(hrvPillar, "No history → cannot compute HRV trend")
    }

    // MARK: - Activity Balance Pillar

    func testActivityBalance_consistentModerate_maxScore() {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = HeartSnapshot(
            date: today, walkMinutes: 15, workoutMinutes: 15, sleepHours: 8.0
        )
        let history = (1...3).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                walkMinutes: 15,
                workoutMinutes: 15
            )
        }
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: history
        )
        let actPillar = result?.pillars.first { $0.type == .activityBalance }
        XCTAssertNotNil(actPillar)
        XCTAssertGreaterThanOrEqual(actPillar!.score, 90.0,
            "Consistent 30min/day should score ~100")
    }

    func testActivityBalance_activeYesterdayRestToday_goodRecovery() {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = HeartSnapshot(
            date: today, walkMinutes: 5, workoutMinutes: 0, sleepHours: 8.0
        )
        let history = [
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -1, to: today)!,
                walkMinutes: 30,
                workoutMinutes: 40
            )
        ]
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: history
        )
        let actPillar = result?.pillars.first { $0.type == .activityBalance }
        XCTAssertNotNil(actPillar)
        XCTAssertGreaterThanOrEqual(actPillar!.score, 80.0,
            "Active yesterday + rest today = smart recovery")
    }

    func testActivityBalance_threeInactiveDays_lowScore() {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = HeartSnapshot(
            date: today, walkMinutes: 5, workoutMinutes: 0, sleepHours: 8.0
        )
        let history = (1...3).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                walkMinutes: 3,
                workoutMinutes: 0
            )
        }
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: history
        )
        let actPillar = result?.pillars.first { $0.type == .activityBalance }
        XCTAssertNotNil(actPillar)
        XCTAssertLessThanOrEqual(actPillar!.score, 35.0,
            "Three inactive days should show low score")
    }

    // MARK: - Composite Score Ranges

    func testCompositeScore_clampedTo0_100() {
        let today = Calendar.current.startOfDay(for: Date())
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                hrvSDNN: 50.0,
                walkMinutes: 20,
                workoutMinutes: 10
            )
        }

        // Test with extreme inputs
        let extremeGood = HeartSnapshot(
            date: today, hrvSDNN: 80.0, recoveryHR1m: 50.0,
            walkMinutes: 30, workoutMinutes: 10, sleepHours: 8.0
        )
        let goodResult = engine.compute(
            snapshot: extremeGood,
            stressScore: 0.0,
            recentHistory: history
        )
        XCTAssertNotNil(goodResult)
        XCTAssertLessThanOrEqual(goodResult!.score, 100)
        XCTAssertGreaterThanOrEqual(goodResult!.score, 0)

        let extremeBad = HeartSnapshot(
            date: today, hrvSDNN: 10.0, recoveryHR1m: 8.0,
            walkMinutes: 0, workoutMinutes: 0, sleepHours: 3.0
        )
        let badResult = engine.compute(
            snapshot: extremeBad,
            stressScore: 100.0,
            recentHistory: history
        )
        XCTAssertNotNil(badResult)
        XCTAssertLessThanOrEqual(badResult!.score, 100)
        XCTAssertGreaterThanOrEqual(badResult!.score, 0)
    }

    // MARK: - Readiness Level Thresholds

    func testReadinessLevel_from_boundaries() {
        XCTAssertEqual(ReadinessLevel.from(score: 100), .primed)
        XCTAssertEqual(ReadinessLevel.from(score: 80), .primed)
        XCTAssertEqual(ReadinessLevel.from(score: 79), .ready)
        XCTAssertEqual(ReadinessLevel.from(score: 60), .ready)
        XCTAssertEqual(ReadinessLevel.from(score: 59), .moderate)
        XCTAssertEqual(ReadinessLevel.from(score: 40), .moderate)
        XCTAssertEqual(ReadinessLevel.from(score: 39), .recovering)
        XCTAssertEqual(ReadinessLevel.from(score: 0), .recovering)
    }

    func testReadinessLevel_displayProperties() {
        for level in [ReadinessLevel.primed, .ready, .moderate, .recovering] {
            XCTAssertFalse(level.displayName.isEmpty)
            XCTAssertFalse(level.icon.isEmpty)
            XCTAssertFalse(level.colorName.isEmpty)
        }
    }

    // MARK: - Weight Normalization

    func testWeightNormalization_threePillars_validScore() {
        // Sleep + stress + activityBalance(fallback) = 3 pillars.
        // Sleep ~100 (8h), Stress 100 (score 0), Activity 35 (no data today).
        // Weighted avg with normalization should be high but not 100.
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 8.0)
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 0.0,
            recentHistory: []
        )
        XCTAssertNotNil(result)
        // With activity fallback at 35, the weighted score drops below 100
        // but should still be solid (sleep .25 + stress .20 + activity .15 → high)
        XCTAssertGreaterThan(result!.score, 70,
            "Perfect sleep + zero stress + low activity fallback → should be > 70")
    }

    // MARK: - Summary Text

    func testSummary_matchesLevel() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 8.0)

        // High readiness (low stress)
        let highResult = engine.compute(
            snapshot: snapshot,
            stressScore: 0.0,
            recentHistory: []
        )
        XCTAssertNotNil(highResult)
        XCTAssertFalse(highResult!.summary.isEmpty)

        // Low readiness (high stress)
        let lowResult = engine.compute(
            snapshot: snapshot,
            stressScore: 100.0,
            recentHistory: []
        )
        XCTAssertNotNil(lowResult)
        XCTAssertFalse(lowResult!.summary.isEmpty)
        XCTAssertNotEqual(highResult!.summary, lowResult!.summary,
            "Different levels should produce different summaries")
    }

    // MARK: - Profile Scenarios

    /// Well-rested athlete: great sleep, high recovery, low stress, good activity.
    func testProfile_wellRestedAthlete() {
        let today = Calendar.current.startOfDay(for: Date())
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                hrvSDNN: 55.0,
                walkMinutes: 20,
                workoutMinutes: 15
            )
        }
        let snapshot = HeartSnapshot(
            date: today,
            hrvSDNN: 60.0,
            recoveryHR1m: 42.0,
            walkMinutes: 15,
            workoutMinutes: 20,
            sleepHours: 7.8
        )
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 20.0,
            recentHistory: history
        )
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.score, 75,
            "Well-rested athlete should be Ready or Primed")
        XCTAssertTrue(
            result!.level == .primed || result!.level == .ready,
            "Expected primed/ready, got \(result!.level)"
        )
    }

    /// Overtrained runner: poor sleep, low recovery, high stress, too much activity.
    func testProfile_overtrainedRunner() {
        let today = Calendar.current.startOfDay(for: Date())
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                hrvSDNN: 50.0,
                walkMinutes: 10,
                workoutMinutes: 60
            )
        }
        let snapshot = HeartSnapshot(
            date: today,
            hrvSDNN: 32.0,
            recoveryHR1m: 15.0,
            walkMinutes: 5,
            workoutMinutes: 70,
            sleepHours: 5.5
        )
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 75.0,
            recentHistory: history
        )
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!.score, 50,
            "Overtrained runner should be moderate or recovering")
    }

    /// Sleep-deprived parent: very short sleep, decent everything else.
    func testProfile_sleepDeprivedParent() {
        let today = Calendar.current.startOfDay(for: Date())
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                hrvSDNN: 45.0,
                walkMinutes: 20,
                workoutMinutes: 10
            )
        }
        let snapshot = HeartSnapshot(
            date: today,
            hrvSDNN: 44.0,
            recoveryHR1m: 30.0,
            walkMinutes: 20,
            workoutMinutes: 10,
            sleepHours: 4.5
        )
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 45.0,
            recentHistory: history
        )
        XCTAssertNotNil(result)
        // Sleep pillar should be the weakest
        let sleepPillar = result!.pillars.first { $0.type == .sleep }!
        let otherPillars = result!.pillars.filter { $0.type != .sleep }
        let otherAvg = otherPillars.map(\.score).reduce(0, +) / Double(otherPillars.count)
        XCTAssertLessThan(sleepPillar.score, otherAvg,
            "Sleep should be the weakest pillar for this profile")
    }

    /// Sedentary worker: minimal activity, high stress, okay everything else.
    func testProfile_sedentaryWorker() {
        let today = Calendar.current.startOfDay(for: Date())
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                hrvSDNN: 40.0,
                walkMinutes: 5,
                workoutMinutes: 0
            )
        }
        let snapshot = HeartSnapshot(
            date: today,
            hrvSDNN: 38.0,
            walkMinutes: 3,
            workoutMinutes: 0,
            sleepHours: 7.0
        )
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 65.0,
            recentHistory: history
        )
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!.score, 60,
            "Sedentary + stressed worker shouldn't score Ready")
    }

    // MARK: - Pillar Count

    func testAllFivePillars_present() {
        let today = Calendar.current.startOfDay(for: Date())
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                hrvSDNN: 50.0,
                walkMinutes: 20,
                workoutMinutes: 10
            )
        }
        let snapshot = HeartSnapshot(
            date: today,
            hrvSDNN: 52.0,
            recoveryHR1m: 30.0,
            walkMinutes: 20,
            workoutMinutes: 10,
            sleepHours: 7.5
        )
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 40.0,
            recentHistory: history
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.pillars.count, 5,
            "All 5 pillars should be present when full data is available")

        let types = Set(result!.pillars.map(\.type))
        XCTAssertTrue(types.contains(.sleep))
        XCTAssertTrue(types.contains(.recovery))
        XCTAssertTrue(types.contains(.stress))
        XCTAssertTrue(types.contains(.activityBalance))
        XCTAssertTrue(types.contains(.hrvTrend))
    }

    // MARK: - Pillar Detail Strings

    func testPillarDetails_neverEmpty() {
        let today = Calendar.current.startOfDay(for: Date())
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                hrvSDNN: 50.0,
                walkMinutes: 20,
                workoutMinutes: 10
            )
        }
        let snapshot = HeartSnapshot(
            date: today,
            hrvSDNN: 48.0,
            recoveryHR1m: 28.0,
            walkMinutes: 15,
            workoutMinutes: 10,
            sleepHours: 7.0
        )
        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 45.0,
            recentHistory: history
        )
        XCTAssertNotNil(result)
        for pillar in result!.pillars {
            XCTAssertFalse(pillar.detail.isEmpty,
                "\(pillar.type) detail should not be empty")
        }
    }
}

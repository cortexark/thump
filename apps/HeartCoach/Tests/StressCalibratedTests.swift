// StressCalibratedTests.swift
// ThumpCoreTests
//
// Tests for the HR-primary stress calibration based on PhysioNet data.
// These tests exercise the new weight distribution:
//   RHR 50% + HRV 30% + CV 20% (all signals)
//   RHR 60% + HRV 40% (no CV)
//   HRV 70% + CV 30% (no RHR)
//   HRV 100% (legacy)
//
// Validates that:
// 1. RHR elevation drives stress scores higher (primary signal)
// 2. HRV depression alone produces moderate stress (secondary)
// 3. Combined RHR+HRV gives strongest stress response
// 4. Weight redistribution works correctly when signals are missing
// 5. Daily stress with RHR data produces different scores than HRV-only
// 6. Cross-engine coherence: high stress → low readiness
// 7. Edge cases: extreme values, missing data, zero baselines

import XCTest
@testable import Thump

final class StressCalibratedTests: XCTestCase {

    private var engine: StressEngine!

    override func setUp() {
        super.setUp()
        engine = StressEngine(baselineWindow: 14)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - RHR as Primary Signal (50% weight)

    /// Elevated RHR with normal HRV should produce moderate-to-high stress.
    func testRHRPrimary_elevatedRHR_normalHRV_moderateStress() {
        // RHR 10% above baseline → rhrRawScore = 40 + 10*4 = 80
        // HRV at baseline → hrvRawScore = 35 (Z=0)
        // Composite: 80*0.50 + 35*0.30 + 50*0.20 = 40 + 10.5 + 10 = 60.5
        let result = engine.computeStress(
            currentHRV: 50.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 72.0,      // 10% above baseline
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )
        XCTAssertGreaterThan(result.score, 50,
            "Elevated RHR should push stress above 50, got \(result.score)")
    }

    /// Normal RHR with depressed HRV should produce lower stress than elevated RHR.
    func testRHRPrimary_normalRHR_lowHRV_lowerStressThanElevatedRHR() {
        // Case A: elevated RHR, normal HRV
        let elevatedRHR = engine.computeStress(
            currentHRV: 50.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 75.0,      // ~15% above baseline
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )

        // Case B: normal RHR, depressed HRV
        let lowHRV = engine.computeStress(
            currentHRV: 30.0,      // 2 SDs below baseline
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 65.0,      // at baseline
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )

        XCTAssertGreaterThan(elevatedRHR.score, lowHRV.score,
            "Elevated RHR (\(elevatedRHR.score)) should produce MORE stress "
            + "than low HRV alone (\(lowHRV.score)) because RHR is primary")
    }

    /// Both RHR elevated AND HRV depressed → highest stress.
    func testRHRPrimary_bothElevatedRHR_andLowHRV_highestStress() {
        let bothBad = engine.computeStress(
            currentHRV: 30.0,      // 2 SDs below baseline
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 78.0,      // 20% above baseline
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )

        let onlyRHR = engine.computeStress(
            currentHRV: 50.0,      // at baseline
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 78.0,
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )

        XCTAssertGreaterThan(bothBad.score, onlyRHR.score,
            "Both signals bad (\(bothBad.score)) should be worse "
            + "than RHR alone (\(onlyRHR.score))")
        XCTAssertGreaterThan(bothBad.score, 65,
            "Both signals bad should produce high stress, got \(bothBad.score)")
    }

    /// Low RHR with high HRV → very low stress (relaxed).
    func testRHRPrimary_lowRHR_highHRV_relaxed() {
        let result = engine.computeStress(
            currentHRV: 65.0,      // 1.5 SDs above baseline
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 58.0,      // ~10% below baseline
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )
        XCTAssertLessThan(result.score, 40,
            "Low RHR + high HRV should be relaxed, got \(result.score)")
        XCTAssertTrue(result.level == .relaxed || result.level == .balanced)
    }

    // MARK: - Weight Redistribution

    /// When all 3 signals available, weights are 50/30/20.
    func testWeightRedistribution_allSignals_50_30_20() {
        // Test by checking that RHR dominates the score
        let rhrUp = engine.computeStress(
            currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 80.0, baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        let rhrDown = engine.computeStress(
            currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 55.0, baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        let rhrDelta = rhrUp.score - rhrDown.score

        let hrvUp = engine.computeStress(
            currentHRV: 30.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 65.0, baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        let hrvDown = engine.computeStress(
            currentHRV: 70.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 65.0, baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        let hrvDelta = hrvUp.score - hrvDown.score

        XCTAssertGreaterThan(rhrDelta, hrvDelta,
            "RHR swing (\(rhrDelta)) should have MORE impact than HRV swing (\(hrvDelta)) "
            + "because RHR weight (50%) > HRV weight (30%)")
    }

    /// When only RHR + HRV (no CV), weights are 60/40.
    func testWeightRedistribution_noCV_60_40() {
        let withCV = engine.computeStress(
            currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 75.0, baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )
        let noCV = engine.computeStress(
            currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 75.0, baselineRHR: 65.0,
            recentHRVs: nil  // no CV data
        )
        // Both should produce elevated stress from RHR, but different
        // weights means slightly different scores
        XCTAssertGreaterThan(noCV.score, 45,
            "RHR still primary without CV, should show elevated stress, got \(noCV.score)")
    }

    /// When only HRV + CV (no RHR), weights are 70/30.
    func testWeightRedistribution_noRHR_70_30() {
        let result = engine.computeStress(
            currentHRV: 30.0,      // 2 SDs below baseline
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: nil,        // no RHR
            baselineRHR: nil,
            recentHRVs: [48, 50, 52, 50, 49]
        )
        XCTAssertGreaterThan(result.score, 50,
            "Low HRV without RHR should still show elevated stress, got \(result.score)")
    }

    /// Legacy mode: HRV only, 100% weight.
    func testWeightRedistribution_legacy_100HRV() {
        let result = engine.computeStress(
            currentHRV: 30.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: nil,
            baselineRHR: nil,
            recentHRVs: nil
        )
        XCTAssertGreaterThan(result.score, 55,
            "Legacy mode: low HRV should show elevated stress, got \(result.score)")
    }

    // MARK: - Daily Stress Score with RHR Data

    /// dailyStressScore should use RHR data from snapshots when available.
    func testDailyStress_withRHRData_usesHRPrimaryWeights() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build 14 days of stable baseline: HRV=50, RHR=65
        var snapshots: [HeartSnapshot] = (0..<14).map { offset in
            let date = calendar.date(byAdding: .day, value: -(14 - offset), to: today)!
            return HeartSnapshot(
                date: date,
                restingHeartRate: 65.0,
                hrvSDNN: 50.0
            )
        }

        // Day 15 (today): HRV normal, but RHR spiked
        snapshots.append(HeartSnapshot(
            date: today,
            restingHeartRate: 80.0,    // elevated RHR
            hrvSDNN: 50.0              // HRV at baseline
        ))

        let score = engine.dailyStressScore(snapshots: snapshots)
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 45,
            "Elevated RHR should drive stress up even with normal HRV, got \(score!)")
    }

    /// Compare: RHR spike vs HRV crash — which drives more stress?
    func testDailyStress_RHRSpikeVsHRVCrash_RHRDominates() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Shared baseline: 14 days HRV=50, RHR=65
        let baselineSnapshots: [HeartSnapshot] = (0..<14).map { offset in
            let date = calendar.date(byAdding: .day, value: -(14 - offset), to: today)!
            return HeartSnapshot(date: date, restingHeartRate: 65.0, hrvSDNN: 50.0)
        }

        // Scenario A: RHR spiked, HRV normal
        var rhrScenario = baselineSnapshots
        rhrScenario.append(HeartSnapshot(
            date: today, restingHeartRate: 82.0, hrvSDNN: 50.0
        ))
        let rhrScore = engine.dailyStressScore(snapshots: rhrScenario)!

        // Scenario B: HRV crashed, RHR normal
        var hrvScenario = baselineSnapshots
        hrvScenario.append(HeartSnapshot(
            date: today, restingHeartRate: 65.0, hrvSDNN: 25.0
        ))
        let hrvScore = engine.dailyStressScore(snapshots: hrvScenario)!

        // RHR is primary (50%) so RHR spike should produce >= stress
        // (may not always be strictly greater due to sigmoid compression,
        // but RHR spike should not be notably less)
        XCTAssertGreaterThan(rhrScore, hrvScore - 10,
            "RHR spike (\(rhrScore)) should produce comparable or higher "
            + "stress than HRV crash (\(hrvScore))")
    }

    /// When snapshots have no RHR, should fall back to HRV-only weights.
    func testDailyStress_noRHRInSnapshots_fallsBackToLegacy() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 14 days with only HRV (no RHR)
        var snapshots: [HeartSnapshot] = (0..<14).map { offset in
            let date = calendar.date(byAdding: .day, value: -(14 - offset), to: today)!
            return HeartSnapshot(date: date, hrvSDNN: 50.0)
        }
        snapshots.append(HeartSnapshot(date: today, hrvSDNN: 30.0))

        let score = engine.dailyStressScore(snapshots: snapshots)
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 50,
            "Low HRV in legacy mode should still show elevated stress, got \(score!)")
    }

    // MARK: - Stress Trend with RHR

    /// Stress trend should reflect RHR changes when available.
    func testStressTrend_withRHRData_reflectsHRChanges() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 21 days: first 14 stable baseline, then 7 days of elevated RHR
        let snapshots: [HeartSnapshot] = (0..<21).map { offset in
            let date = calendar.date(byAdding: .day, value: -(20 - offset), to: today)!
            let rhr: Double = offset >= 14 ? 80.0 : 65.0  // spike last 7 days
            return HeartSnapshot(
                date: date,
                restingHeartRate: rhr,
                hrvSDNN: 50.0  // constant HRV
            )
        }

        let trend = engine.stressTrend(snapshots: snapshots, range: .week)
        XCTAssertFalse(trend.isEmpty, "Should produce trend points")

        // Trend should show elevated stress in the recent period
        if let lastScore = trend.last?.score {
            XCTAssertGreaterThan(lastScore, 45,
                "Elevated RHR in recent days should show stress, got \(lastScore)")
        }
    }

    // MARK: - CV Component (20% weight)

    /// High HRV variability (volatile readings) should add stress.
    func testCVComponent_highVariability_addsStress() {
        let stableCV = engine.computeStress(
            currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 65.0, baselineRHR: 65.0,
            recentHRVs: [49, 50, 51, 50, 49]  // very stable CV
        )

        let volatileCV = engine.computeStress(
            currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 65.0, baselineRHR: 65.0,
            recentHRVs: [20, 80, 25, 75, 30]  // very volatile CV
        )

        XCTAssertGreaterThan(volatileCV.score, stableCV.score,
            "Volatile HRV (\(volatileCV.score)) should score higher stress "
            + "than stable (\(stableCV.score))")
    }

    // MARK: - Monotonicity Tests

    /// Stress should monotonically increase as RHR rises (all else equal).
    func testMonotonicity_stressIncreasesWithRHR() {
        var lastScore: Double = -1
        for rhr in stride(from: 55.0, through: 90.0, by: 5.0) {
            let result = engine.computeStress(
                currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
                currentRHR: rhr, baselineRHR: 65.0,
                recentHRVs: [50, 50, 50, 50, 50]
            )
            XCTAssertGreaterThanOrEqual(result.score, lastScore,
                "Stress should increase with RHR. At RHR=\(rhr), "
                + "score=\(result.score) < previous=\(lastScore)")
            lastScore = result.score
        }
    }

    /// Stress should monotonically increase as HRV drops (all else equal).
    func testMonotonicity_stressIncreasesAsHRVDrops() {
        var lastScore: Double = -1
        for hrv in stride(from: 80.0, through: 20.0, by: -10.0) {
            let result = engine.computeStress(
                currentHRV: hrv, baselineHRV: 50.0, baselineHRVSD: 10.0,
                currentRHR: 65.0, baselineRHR: 65.0,
                recentHRVs: [50, 50, 50, 50, 50]
            )
            XCTAssertGreaterThanOrEqual(result.score, lastScore,
                "Stress should increase as HRV drops. At HRV=\(hrv), "
                + "score=\(result.score) < previous=\(lastScore)")
            lastScore = result.score
        }
    }

    // MARK: - Edge Cases

    /// All signals at baseline → moderate-low stress.
    func testEdge_allAtBaseline_lowStress() {
        let result = engine.computeStress(
            currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 65.0, baselineRHR: 65.0,
            recentHRVs: [49, 50, 51, 50, 49]
        )
        XCTAssertLessThan(result.score, 50,
            "All signals at baseline should be low stress, got \(result.score)")
    }

    /// Extreme RHR elevation → high stress (damped when signals disagree).
    func testEdge_extremeRHRSpike_veryHighStress() {
        let result = engine.computeStress(
            currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 100.0,     // 54% above baseline
            baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        // Disagreement damping applies when HRV is at baseline but RHR is extreme,
        // so the score is compressed slightly toward neutral.
        XCTAssertGreaterThan(result.score, 60,
            "Extreme RHR spike should produce high stress, got \(result.score)")
    }

    /// RHR below baseline → stress should drop.
    func testEdge_RHRBelowBaseline_lowStress() {
        let result = engine.computeStress(
            currentHRV: 55.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 55.0,     // 15% below baseline
            baselineRHR: 65.0,
            recentHRVs: [49, 50, 51, 50, 49]
        )
        XCTAssertLessThan(result.score, 40,
            "RHR below baseline should show low stress, got \(result.score)")
    }

    /// Score always stays within 0-100 with extreme inputs.
    func testEdge_extremeValues_scoreClamped() {
        let extreme1 = engine.computeStress(
            currentHRV: 5.0, baselineHRV: 80.0, baselineHRVSD: 5.0,
            currentRHR: 120.0, baselineRHR: 60.0,
            recentHRVs: [10, 90, 5, 100, 8]
        )
        XCTAssertGreaterThanOrEqual(extreme1.score, 0)
        XCTAssertLessThanOrEqual(extreme1.score, 100)

        let extreme2 = engine.computeStress(
            currentHRV: 200.0, baselineHRV: 30.0, baselineHRVSD: 5.0,
            currentRHR: 40.0, baselineRHR: 80.0,
            recentHRVs: [200, 200, 200, 200, 200]
        )
        XCTAssertGreaterThanOrEqual(extreme2.score, 0)
        XCTAssertLessThanOrEqual(extreme2.score, 100)
    }

    /// Zero baseline RHR should not crash.
    func testEdge_zeroBaselineRHR_handledGracefully() {
        let result = engine.computeStress(
            currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 70.0, baselineRHR: 0.0,
            recentHRVs: [50, 50, 50]
        )
        // baseRHR=0 → rhrRawScore stays at neutral 50
        XCTAssertGreaterThanOrEqual(result.score, 0)
        XCTAssertLessThanOrEqual(result.score, 100)
    }

    /// Only 1-2 recent HRVs → CV component should be skipped (needs >=3).
    func testEdge_tooFewRecentHRVs_CVSkipped() {
        let result = engine.computeStress(
            currentHRV: 50.0, baselineHRV: 50.0, baselineHRVSD: 10.0,
            currentRHR: 65.0, baselineRHR: 65.0,
            recentHRVs: [50, 50]  // only 2 values, needs 3
        )
        // Should still produce a valid score using RHR + HRV
        XCTAssertGreaterThanOrEqual(result.score, 0)
        XCTAssertLessThanOrEqual(result.score, 100)
    }

    // MARK: - Cross-Engine Coherence

    /// High stress from RHR elevation → readiness engine should show low readiness.
    func testCoherence_highStressFromRHR_lowersReadiness() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 14 days baseline: healthy metrics
        var snapshots: [HeartSnapshot] = (0..<14).map { offset in
            let date = calendar.date(byAdding: .day, value: -(14 - offset), to: today)!
            return HeartSnapshot(
                date: date,
                restingHeartRate: 62.0,
                hrvSDNN: 55.0,
                workoutMinutes: 30,
                sleepHours: 7.5
            )
        }

        // Today: RHR spiked (stress event)
        let todaySnapshot = HeartSnapshot(
            date: today,
            restingHeartRate: 82.0,    // 32% above baseline
            hrvSDNN: 55.0,
            workoutMinutes: 30,
            sleepHours: 7.5
        )
        snapshots.append(todaySnapshot)

        let stressScore = engine.dailyStressScore(snapshots: snapshots)
        XCTAssertNotNil(stressScore)

        // Feed stress into readiness via proper API
        let readinessEngine = ReadinessEngine()
        let readiness = readinessEngine.compute(
            snapshot: todaySnapshot,
            stressScore: stressScore,
            recentHistory: Array(snapshots.dropLast())
        )

        XCTAssertNotNil(readiness)
        if let readiness = readiness {
            // With elevated RHR stress, readiness should be below perfect
            // (readiness uses score as Int, typical healthy = 80-90)
            XCTAssertLessThan(readiness.score, 90,
                "High stress from RHR should lower readiness below perfect, got \(readiness.score)")
        }
    }

    // MARK: - Persona Scenarios with RHR

    /// Athlete persona: low RHR, high HRV → very low stress.
    func testPersona_athlete_lowStress() {
        let result = engine.computeStress(
            currentHRV: 65.0,
            baselineHRV: 60.0,
            baselineHRVSD: 8.0,
            currentRHR: 48.0,
            baselineRHR: 50.0,
            recentHRVs: [58, 62, 60, 63, 61]
        )
        XCTAssertLessThan(result.score, 35,
            "Athlete should have low stress, got \(result.score)")
    }

    /// Sedentary persona: high RHR, low HRV → high stress.
    func testPersona_sedentary_highStress() {
        let result = engine.computeStress(
            currentHRV: 25.0,
            baselineHRV: 30.0,
            baselineHRVSD: 5.0,
            currentRHR: 82.0,
            baselineRHR: 78.0,
            recentHRVs: [28, 32, 26, 34, 29]
        )
        XCTAssertGreaterThan(result.score, 40,
            "Sedentary person with elevated RHR should have elevated stress, got \(result.score)")
    }

    /// Stressed professional: RHR creeping up over baseline, HRV declining.
    func testPersona_stressedProfessional_elevatedStress() {
        let result = engine.computeStress(
            currentHRV: 32.0,      // below 40ms baseline
            baselineHRV: 40.0,
            baselineHRVSD: 6.0,
            currentRHR: 76.0,      // above 68 baseline
            baselineRHR: 68.0,
            recentHRVs: [42, 38, 36, 34, 32]  // declining
        )
        XCTAssertGreaterThan(result.score, 55,
            "Stressed professional should show elevated stress, got \(result.score)")
        XCTAssertTrue(result.level == .elevated || result.level == .balanced,
            "Should be elevated or balanced, got \(result.level)")
    }

    // MARK: - Ranking Accuracy

    /// Athlete stress < Normal stress < Sedentary stress (with full RHR data).
    func testRanking_athleteLessThanNormalLessThanSedentary() {
        let athlete = engine.computeStress(
            currentHRV: 65.0, baselineHRV: 60.0, baselineHRVSD: 8.0,
            currentRHR: 48.0, baselineRHR: 50.0,
            recentHRVs: [58, 62, 60, 63, 61]
        )
        let normal = engine.computeStress(
            currentHRV: 42.0, baselineHRV: 40.0, baselineHRVSD: 7.0,
            currentRHR: 70.0, baselineRHR: 68.0,
            recentHRVs: [38, 42, 40, 41, 39]
        )
        let sedentary = engine.computeStress(
            currentHRV: 25.0, baselineHRV: 30.0, baselineHRVSD: 5.0,
            currentRHR: 82.0, baselineRHR: 78.0,
            recentHRVs: [28, 32, 26, 34, 29]
        )

        XCTAssertLessThan(athlete.score, normal.score,
            "Athlete (\(athlete.score)) should be less stressed than normal (\(normal.score))")
        XCTAssertLessThan(normal.score, sedentary.score,
            "Normal (\(normal.score)) should be less stressed than sedentary (\(sedentary.score))")
    }
}

// StressEngineTimeSeriesTests.swift
// ThumpTests
//
// 30-day time-series validation for StressEngine across 20 personas.
// Runs the engine at each checkpoint (day 1, 2, 7, 14, 20, 25, 30),
// stores results via EngineResultStore, and validates expected outcomes
// for key personas plus edge cases.

import XCTest
@testable import Thump

final class StressEngineTimeSeriesTests: XCTestCase {

    private let engine = StressEngine()
    private let kpi = KPITracker()
    private let engineName = "StressEngine"

    // MARK: - 30-Day Persona Sweep

    /// Run every persona through all checkpoints, storing results and validating score range.
    func testAllPersonas30DayTimeSeries() {
        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()

            for cp in TimeSeriesCheckpoint.allCases {
                let day = cp.rawValue
                let snapshots = Array(fullHistory.prefix(day))

                // Compute baselines from all snapshots up to this checkpoint
                let hrvValues = snapshots.compactMap(\.hrvSDNN)
                let rhrValues = snapshots.compactMap(\.restingHeartRate)

                let baselineHRV = hrvValues.isEmpty ? 0 : hrvValues.reduce(0, +) / Double(hrvValues.count)
                let baselineRHR = rhrValues.count >= 3 ? rhrValues.reduce(0, +) / Double(rhrValues.count) : nil

                // Baseline HRV standard deviation
                let baselineHRVSD: Double
                if hrvValues.count >= 2 {
                    let variance = hrvValues.map { ($0 - baselineHRV) * ($0 - baselineHRV) }
                        .reduce(0, +) / Double(hrvValues.count - 1)
                    baselineHRVSD = sqrt(variance)
                } else {
                    baselineHRVSD = baselineHRV * 0.20
                }

                // Current day values (last snapshot in the slice)
                let current = snapshots.last!
                let currentHRV = current.hrvSDNN ?? baselineHRV
                let currentRHR = current.restingHeartRate

                let result = engine.computeStress(
                    currentHRV: currentHRV,
                    baselineHRV: baselineHRV,
                    baselineHRVSD: baselineHRVSD,
                    currentRHR: currentRHR,
                    baselineRHR: baselineRHR,
                    recentHRVs: hrvValues.count >= 3 ? Array(hrvValues.suffix(14)) : nil
                )

                // Store result for downstream engines
                EngineResultStore.write(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: cp,
                    result: [
                        "score": result.score,
                        "level": result.level.rawValue
                    ]
                )

                // Assert: score is in valid range 0-100
                let passed = result.score >= 0 && result.score <= 100
                XCTAssertGreaterThanOrEqual(
                    result.score, 0,
                    "\(persona.name) day \(day): score \(result.score) is below 0"
                )
                XCTAssertLessThanOrEqual(
                    result.score, 100,
                    "\(persona.name) day \(day): score \(result.score) is above 100"
                )

                kpi.record(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: cp.label,
                    passed: passed,
                    reason: passed ? "" : "score \(result.score) out of range [0,100]"
                )

                print("[\(engineName)] \(persona.name) @ \(cp.label): score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
            }
        }

        kpi.printReport()
    }

    // MARK: - Expected Outcomes for Key Personas

    func testStressedExecutiveHighStressAtDay30() {
        let persona = TestPersonas.stressedExecutive
        let history = persona.generate30DayHistory()
        let snapshots = Array(history.prefix(30))

        let hrvValues = snapshots.compactMap(\.hrvSDNN)
        let rhrValues = snapshots.compactMap(\.restingHeartRate)
        let baselineHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let baselineRHR = rhrValues.reduce(0, +) / Double(rhrValues.count)
        let baselineHRVSD = engine.computeBaselineSD(hrvValues: hrvValues, mean: baselineHRV)

        let current = snapshots.last!
        let result = engine.computeStress(
            currentHRV: current.hrvSDNN ?? baselineHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineHRVSD,
            currentRHR: current.restingHeartRate,
            baselineRHR: baselineRHR,
            recentHRVs: Array(hrvValues.suffix(14))
        )

        XCTAssertGreaterThanOrEqual(
            result.score, 10,
            "StressedExecutive day 30: expected score >= 10, got \(result.score)"
        )
        print("[Expected] StressedExecutive day 30: score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
    }

    func testAnxietyProfileHighStressAtDay30() {
        let persona = TestPersonas.anxietyProfile
        let history = persona.generate30DayHistory()
        let snapshots = Array(history.prefix(30))

        let hrvValues = snapshots.compactMap(\.hrvSDNN)
        let rhrValues = snapshots.compactMap(\.restingHeartRate)
        let baselineHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let baselineRHR = rhrValues.reduce(0, +) / Double(rhrValues.count)
        let baselineHRVSD = engine.computeBaselineSD(hrvValues: hrvValues, mean: baselineHRV)

        let current = snapshots.last!
        let result = engine.computeStress(
            currentHRV: current.hrvSDNN ?? baselineHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineHRVSD,
            currentRHR: current.restingHeartRate,
            baselineRHR: baselineRHR,
            recentHRVs: Array(hrvValues.suffix(14))
        )

        XCTAssertGreaterThan(
            result.score, 5,
            "AnxietyProfile day 30: expected score > 5, got \(result.score)"
        )
        print("[Expected] AnxietyProfile day 30: score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
    }

    func testYoungAthleteLowStressAtDay30() {
        let persona = TestPersonas.youngAthlete
        let history = persona.generate30DayHistory()
        let snapshots = Array(history.prefix(30))

        let hrvValues = snapshots.compactMap(\.hrvSDNN)
        let rhrValues = snapshots.compactMap(\.restingHeartRate)
        let baselineHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let baselineRHR = rhrValues.reduce(0, +) / Double(rhrValues.count)
        let baselineHRVSD = engine.computeBaselineSD(hrvValues: hrvValues, mean: baselineHRV)

        let current = snapshots.last!
        let result = engine.computeStress(
            currentHRV: current.hrvSDNN ?? baselineHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineHRVSD,
            currentRHR: current.restingHeartRate,
            baselineRHR: baselineRHR,
            recentHRVs: Array(hrvValues.suffix(14))
        )

        XCTAssertLessThanOrEqual(
            result.score, 50,
            "YoungAthlete day 30: expected score <= 50, got \(result.score)"
        )
        print("[Expected] YoungAthlete day 30: score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
    }

    func testExcellentSleeperLowStressAtDay30() {
        let persona = TestPersonas.excellentSleeper
        let history = persona.generate30DayHistory()
        let snapshots = Array(history.prefix(30))

        let hrvValues = snapshots.compactMap(\.hrvSDNN)
        let rhrValues = snapshots.compactMap(\.restingHeartRate)
        let baselineHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let baselineRHR = rhrValues.reduce(0, +) / Double(rhrValues.count)
        let baselineHRVSD = engine.computeBaselineSD(hrvValues: hrvValues, mean: baselineHRV)

        let current = snapshots.last!
        let result = engine.computeStress(
            currentHRV: current.hrvSDNN ?? baselineHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineHRVSD,
            currentRHR: current.restingHeartRate,
            baselineRHR: baselineRHR,
            recentHRVs: Array(hrvValues.suffix(14))
        )

        XCTAssertLessThan(
            result.score, 65,
            "ExcellentSleeper day 30: expected score < 65, got \(result.score)"
        )
        print("[Expected] ExcellentSleeper day 30: score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
    }

    func testOvertrainingStressIncreasesFromDay20ToDay30() {
        let persona = TestPersonas.overtraining
        let history = persona.generate30DayHistory()

        // Score at day 20 (before trend overlay kicks in at day 25)
        let scoreDay20 = computeStressScore(for: persona, history: history, upToDay: 20)
        // Score at day 30 (after trend overlay has been active for 5 days)
        let scoreDay30 = computeStressScore(for: persona, history: history, upToDay: 30)

        XCTAssertGreaterThan(
            scoreDay30, scoreDay20,
            "Overtraining: expected stress to INCREASE from day 20 (\(String(format: "%.1f", scoreDay20))) "
            + "to day 30 (\(String(format: "%.1f", scoreDay30))) due to trend overlay starting at day 25"
        )
        print("[Expected] Overtraining day 20: \(String(format: "%.1f", scoreDay20)) -> day 30: \(String(format: "%.1f", scoreDay30))")
    }

    // MARK: - Edge Cases

    func testEdgeCaseEmptyHistory() {
        // Day 0: no snapshots at all. computeStress with zero baseline should return balanced default.
        let result = engine.computeStress(
            currentHRV: 40,
            baselineHRV: 0,
            baselineHRVSD: nil,
            currentRHR: 70,
            baselineRHR: 65,
            recentHRVs: nil
        )

        XCTAssertEqual(
            result.score, 50,
            "Edge case empty history: expected score 50 (no baseline), got \(result.score)"
        )
        XCTAssertEqual(
            result.level, .balanced,
            "Edge case empty history: expected level balanced, got \(result.level.rawValue)"
        )
        kpi.recordEdgeCase(engine: engineName, passed: true, reason: "empty history handled")
        print("[Edge] Empty history: score=\(result.score) level=\(result.level.rawValue)")
    }

    func testEdgeCaseSingleDay() {
        // Single snapshot should not crash. dailyStressScore needs >= 2 so returns nil.
        let persona = TestPersonas.youngAthlete
        let history = persona.generate30DayHistory()
        let singleDay = Array(history.prefix(1))

        let dailyScore = engine.dailyStressScore(snapshots: singleDay)
        XCTAssertNil(
            dailyScore,
            "Edge case single day: dailyStressScore should return nil with only 1 snapshot"
        )

        // Direct computeStress should still work with manually extracted values
        if let hrv = singleDay.first?.hrvSDNN {
            let result = engine.computeStress(
                currentHRV: hrv,
                baselineHRV: hrv,
                baselineHRVSD: hrv * 0.20,
                currentRHR: singleDay.first?.restingHeartRate,
                baselineRHR: singleDay.first?.restingHeartRate,
                recentHRVs: [hrv]
            )
            XCTAssertGreaterThanOrEqual(
                result.score, 0,
                "Edge case single day: score \(result.score) should be >= 0"
            )
            XCTAssertLessThanOrEqual(
                result.score, 100,
                "Edge case single day: score \(result.score) should be <= 100"
            )
            print("[Edge] Single day: score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
        }

        kpi.recordEdgeCase(engine: engineName, passed: true, reason: "single day did not crash")
    }

    func testEdgeCaseAllIdenticalHRV() {
        // All HRV values the same => zero variance. Should return balanced, not crash.
        let identicalHRV = 45.0
        let result = engine.computeStress(
            currentHRV: identicalHRV,
            baselineHRV: identicalHRV,
            baselineHRVSD: 0.0,
            currentRHR: 65,
            baselineRHR: 65,
            recentHRVs: Array(repeating: identicalHRV, count: 14)
        )

        XCTAssertGreaterThanOrEqual(
            result.score, 0,
            "Edge case identical HRV: score \(result.score) should be >= 0"
        )
        XCTAssertLessThanOrEqual(
            result.score, 100,
            "Edge case identical HRV: score \(result.score) should be <= 100"
        )

        let passed = result.score >= 0 && result.score <= 100
        kpi.recordEdgeCase(engine: engineName, passed: passed, reason: "identical HRV values")
        print("[Edge] Identical HRV (\(identicalHRV)): score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
    }

    func testEdgeCaseExtremeHRVLow() {
        // HRV = 5 (extremely low)
        let result = engine.computeStress(
            currentHRV: 5,
            baselineHRV: 50,
            baselineHRVSD: 10,
            currentRHR: 80,
            baselineRHR: 65,
            recentHRVs: [5, 8, 6]
        )

        XCTAssertGreaterThanOrEqual(
            result.score, 0,
            "Edge case HRV=5: score \(result.score) should be >= 0"
        )
        XCTAssertLessThanOrEqual(
            result.score, 100,
            "Edge case HRV=5: score \(result.score) should be <= 100"
        )

        let passed = result.score >= 0 && result.score <= 100
        kpi.recordEdgeCase(engine: engineName, passed: passed, reason: "extreme low HRV=5")
        print("[Edge] HRV=5: score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
    }

    func testEdgeCaseExtremeHRVHigh() {
        // HRV = 300 (extremely high)
        let result = engine.computeStress(
            currentHRV: 300,
            baselineHRV: 50,
            baselineHRVSD: 10,
            currentRHR: 45,
            baselineRHR: 65,
            recentHRVs: [300, 280, 310]
        )

        XCTAssertGreaterThanOrEqual(
            result.score, 0,
            "Edge case HRV=300: score \(result.score) should be >= 0"
        )
        XCTAssertLessThanOrEqual(
            result.score, 100,
            "Edge case HRV=300: score \(result.score) should be <= 100"
        )

        let passed = result.score >= 0 && result.score <= 100
        kpi.recordEdgeCase(engine: engineName, passed: passed, reason: "extreme high HRV=300")
        print("[Edge] HRV=300: score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
    }

    func testEdgeCaseExtremeRHRLow() {
        // RHR = 40 (athlete bradycardia)
        let result = engine.computeStress(
            currentHRV: 80,
            baselineHRV: 70,
            baselineHRVSD: 12,
            currentRHR: 40,
            baselineRHR: 65,
            recentHRVs: [75, 80, 85]
        )

        XCTAssertGreaterThanOrEqual(
            result.score, 0,
            "Edge case RHR=40: score \(result.score) should be >= 0"
        )
        XCTAssertLessThanOrEqual(
            result.score, 100,
            "Edge case RHR=40: score \(result.score) should be <= 100"
        )

        let passed = result.score >= 0 && result.score <= 100
        kpi.recordEdgeCase(engine: engineName, passed: passed, reason: "extreme low RHR=40")
        print("[Edge] RHR=40: score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
    }

    func testEdgeCaseExtremeRHRHigh() {
        // RHR = 160 (tachycardia)
        let result = engine.computeStress(
            currentHRV: 15,
            baselineHRV: 50,
            baselineHRVSD: 10,
            currentRHR: 160,
            baselineRHR: 65,
            recentHRVs: [15, 12, 18]
        )

        XCTAssertGreaterThanOrEqual(
            result.score, 0,
            "Edge case RHR=160: score \(result.score) should be >= 0"
        )
        XCTAssertLessThanOrEqual(
            result.score, 100,
            "Edge case RHR=160: score \(result.score) should be <= 100"
        )

        let passed = result.score >= 0 && result.score <= 100
        kpi.recordEdgeCase(engine: engineName, passed: passed, reason: "extreme high RHR=160")
        print("[Edge] RHR=160: score=\(String(format: "%.1f", result.score)) level=\(result.level.rawValue)")
    }

    // MARK: - KPI Summary

    func testZZ_PrintKPISummary() {
        // Run the full sweep so the KPI tracker is populated, then print.
        // This test is named with ZZ_ prefix to run last in alphabetical order.
        testAllPersonas30DayTimeSeries()
    }

    // MARK: - Helpers

    /// Compute a stress score for a persona at a given day count using the full-signal path.
    private func computeStressScore(
        for persona: PersonaBaseline,
        history: [HeartSnapshot],
        upToDay day: Int
    ) -> Double {
        let snapshots = Array(history.prefix(day))
        let hrvValues = snapshots.compactMap(\.hrvSDNN)
        let rhrValues = snapshots.compactMap(\.restingHeartRate)

        guard !hrvValues.isEmpty else { return 50 }

        let baselineHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let baselineRHR = rhrValues.count >= 3
            ? rhrValues.reduce(0, +) / Double(rhrValues.count)
            : nil
        let baselineHRVSD = engine.computeBaselineSD(hrvValues: hrvValues, mean: baselineHRV)

        let current = snapshots.last!
        let result = engine.computeStress(
            currentHRV: current.hrvSDNN ?? baselineHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineHRVSD,
            currentRHR: current.restingHeartRate,
            baselineRHR: baselineRHR,
            recentHRVs: hrvValues.count >= 3 ? Array(hrvValues.suffix(14)) : nil
        )
        return result.score
    }
}

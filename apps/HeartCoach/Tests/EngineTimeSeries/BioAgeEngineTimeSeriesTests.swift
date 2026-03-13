// BioAgeEngineTimeSeriesTests.swift
// ThumpTests
//
// 30-day time-series validation for BioAgeEngine across all 20 personas.
// Runs at 7 checkpoints (day 1, 2, 7, 14, 20, 25, 30), stores results
// via EngineResultStore, and validates directional bio-age expectations.

import XCTest
@testable import Thump

final class BioAgeEngineTimeSeriesTests: XCTestCase {

    private let engine = BioAgeEngine()
    private let kpi = KPITracker()
    private let engineName = "BioAgeEngine"

    // MARK: - Full 20-Persona Time-Series Sweep

    func testAllPersonasAcrossCheckpoints() {
        for persona in TestPersonas.all {
            let history = persona.generate30DayHistory()

            for checkpoint in TimeSeriesCheckpoint.allCases {
                let day = checkpoint.rawValue
                let sliced = Array(history.prefix(day))
                guard let latest = sliced.last else {
                    XCTFail("\(persona.name) @ \(checkpoint.label): no snapshot available")
                    kpi.record(engine: engineName, persona: persona.name,
                               checkpoint: checkpoint.label, passed: false,
                               reason: "No snapshot at checkpoint")
                    continue
                }

                let result = engine.estimate(
                    snapshot: latest,
                    chronologicalAge: persona.age,
                    sex: persona.sex
                )

                // Every persona with full metrics should produce a result
                let passed = result != nil
                XCTAssertNotNil(result,
                    "\(persona.name) @ \(checkpoint.label): expected non-nil BioAgeResult")

                if let r = result {
                    // Store for downstream engines
                    EngineResultStore.write(
                        engine: engineName,
                        persona: persona.name,
                        checkpoint: checkpoint,
                        result: [
                            "bioAge": r.bioAge,
                            "chronologicalAge": r.chronologicalAge,
                            "difference": r.difference,
                            "category": r.category.rawValue,
                            "metricsUsed": r.metricsUsed,
                            "explanation": r.explanation
                        ]
                    )

                    // Sanity: bioAge should be positive and reasonable
                    XCTAssertGreaterThan(r.bioAge, 0,
                        "\(persona.name) @ \(checkpoint.label): bioAge must be positive")
                    XCTAssertLessThan(r.bioAge, 150,
                        "\(persona.name) @ \(checkpoint.label): bioAge unreasonably high")
                    XCTAssertGreaterThanOrEqual(r.metricsUsed, 2,
                        "\(persona.name) @ \(checkpoint.label): need >= 2 metrics")
                }

                kpi.record(engine: engineName, persona: persona.name,
                           checkpoint: checkpoint.label, passed: passed,
                           reason: passed ? "" : "Returned nil")
            }
        }

        kpi.printReport()
    }

    // MARK: - Directional Assertions: Younger Bio Age

    func testYoungAthlete_BioAgeShouldBeYounger() {
        assertBioAgeDirection(
            persona: TestPersonas.youngAthlete,
            expectYounger: true,
            label: "YoungAthlete (22M, VO2=55, RHR=50)"
        )
    }

    func testTeenAthlete_BioAgeShouldBeYounger() {
        assertBioAgeDirection(
            persona: TestPersonas.teenAthlete,
            expectYounger: true,
            label: "TeenAthlete (17M, VO2=58)"
        )
    }

    func testMiddleAgeFit_BioAgeShouldBeYounger() {
        assertBioAgeDirection(
            persona: TestPersonas.middleAgeFit,
            expectYounger: true,
            label: "MiddleAgeFit (45M, VO2=50)"
        )
    }

    // MARK: - Directional Assertions: Older Bio Age

    func testObeseSedentary_BioAgeShouldBeOlder() {
        assertBioAgeDirection(
            persona: TestPersonas.obeseSedentary,
            expectYounger: false,
            label: "ObeseSedentary (50M, RHR=82, VO2=22)"
        )
    }

    func testMiddleAgeUnfit_BioAgeShouldBeOlder() {
        assertBioAgeDirection(
            persona: TestPersonas.middleAgeUnfit,
            expectYounger: false,
            label: "MiddleAgeUnfit (48F)"
        )
    }

    func testSedentarySenior_BioAgeShouldBeOlder() {
        assertBioAgeDirection(
            persona: TestPersonas.sedentarySenior,
            expectYounger: false,
            label: "SedentarySenior (70F)"
        )
    }

    // MARK: - Balanced: Active Professional

    func testActiveProfessional_BioAgeWithinRange() {
        let persona = TestPersonas.activeProfessional
        let history = persona.generate30DayHistory()

        for checkpoint in TimeSeriesCheckpoint.allCases {
            let day = checkpoint.rawValue
            let sliced = Array(history.prefix(day))
            guard let latest = sliced.last,
                  let result = engine.estimate(
                      snapshot: latest,
                      chronologicalAge: persona.age,
                      sex: persona.sex
                  ) else {
                XCTFail("ActiveProfessional @ \(checkpoint.label): expected non-nil result")
                continue
            }

            let diff = abs(result.difference)
            XCTAssertLessThanOrEqual(diff, 3,
                "ActiveProfessional @ \(checkpoint.label): bioAge \(result.bioAge) "
                + "should be within +/-3 of chronological \(persona.age), "
                + "got difference \(result.difference)")
        }
    }

    // MARK: - Trend Assertions: Recovery

    func testRecoveringIllness_BioAgeShouldImprove() {
        let persona = TestPersonas.recoveringIllness
        let history = persona.generate30DayHistory()

        // Get result at day 14 (early recovery) and day 30 (late recovery)
        let sliceDay14 = Array(history.prefix(14))
        let sliceDay30 = history

        guard let latestDay14 = sliceDay14.last,
              let resultDay14 = engine.estimate(
                  snapshot: latestDay14,
                  chronologicalAge: persona.age,
                  sex: persona.sex
              ) else {
            XCTFail("RecoveringIllness @ day14: expected non-nil result")
            return
        }

        guard let latestDay30 = sliceDay30.last,
              let resultDay30 = engine.estimate(
                  snapshot: latestDay30,
                  chronologicalAge: persona.age,
                  sex: persona.sex
              ) else {
            XCTFail("RecoveringIllness @ day30: expected non-nil result")
            return
        }

        // Bio age should decrease (improve) as recovery progresses
        XCTAssertLessThanOrEqual(resultDay30.bioAge, resultDay14.bioAge,
            "RecoveringIllness: bioAge should improve (decrease) from day14 (\(resultDay14.bioAge)) "
            + "to day30 (\(resultDay30.bioAge)) as metrics normalize")
    }

    // MARK: - Trend Assertions: Overtraining

    func testOvertraining_BioAgeShouldWorsen() {
        let persona = TestPersonas.overtraining
        let history = persona.generate30DayHistory()

        // Get result at day 25 (before overtraining ramp) and day 30 (peak overtraining)
        let sliceDay25 = Array(history.prefix(25))
        let sliceDay30 = history

        guard let latestDay25 = sliceDay25.last,
              let resultDay25 = engine.estimate(
                  snapshot: latestDay25,
                  chronologicalAge: persona.age,
                  sex: persona.sex
              ) else {
            XCTFail("Overtraining @ day25: expected non-nil result")
            return
        }

        guard let latestDay30 = sliceDay30.last,
              let resultDay30 = engine.estimate(
                  snapshot: latestDay30,
                  chronologicalAge: persona.age,
                  sex: persona.sex
              ) else {
            XCTFail("Overtraining @ day30: expected non-nil result")
            return
        }

        // Bio age should increase (worsen) as overtraining sets in
        XCTAssertGreaterThanOrEqual(resultDay30.bioAge, resultDay25.bioAge,
            "Overtraining: bioAge should worsen (increase) from day25 (\(resultDay25.bioAge)) "
            + "to day30 (\(resultDay30.bioAge)) as overtraining progresses")
    }

    // MARK: - Edge Cases

    func testEdge_AgeZero_ReturnsNil() {
        let snapshot = makeMinimalSnapshot(rhr: 65, vo2: 40)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 0, sex: .male)
        XCTAssertNil(result, "Edge: age=0 should return nil")
        kpi.recordEdgeCase(engine: engineName, passed: result == nil,
                           reason: "age=0 should return nil")
    }

    func testEdge_OnlyOneMetric_ReturnsNil() {
        // Only RHR, nothing else
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 65
        )
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35, sex: .male)
        XCTAssertNil(result,
            "Edge: only 1 metric (RHR) available should return nil (need >= 2)")
        kpi.recordEdgeCase(engine: engineName, passed: result == nil,
                           reason: "Only 1 metric should return nil")
    }

    func testEdge_AllMetricsNil_ReturnsNil() {
        let snapshot = HeartSnapshot(date: Date())
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 40, sex: .female)
        XCTAssertNil(result,
            "Edge: all metrics nil should return nil")
        kpi.recordEdgeCase(engine: engineName, passed: result == nil,
                           reason: "All metrics nil should return nil")
    }

    func testEdge_ExtremeVO2_OffsetCapped() {
        // VO2 of 90 is extremely high; offset should still be capped at +/-8
        let snapshot = makeMinimalSnapshot(rhr: 60, vo2: 90)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35, sex: .male)

        XCTAssertNotNil(result, "Edge: extreme VO2=90 should still produce a result")
        if let r = result {
            // With VO2=90 vs expected ~44 for 35M, the offset should be capped
            // The per-metric max offset is 8 years, so bio age should not drop
            // more than 8 from chronological when dominated by VO2
            let minReasonable = 35 - 8 - 3 // allow small contributions from other metrics
            XCTAssertGreaterThanOrEqual(r.bioAge, minReasonable,
                "Edge: extreme VO2=90 offset should be capped; bioAge=\(r.bioAge) "
                + "should not be unreasonably low")

            // Verify the VO2 metric contribution itself is capped
            if let vo2Contrib = r.breakdown.first(where: { $0.metric == .vo2Max }) {
                XCTAssertGreaterThanOrEqual(vo2Contrib.ageOffset, -8.0,
                    "Edge: VO2 metric offset \(vo2Contrib.ageOffset) should be >= -8.0 (capped)")
                XCTAssertLessThanOrEqual(vo2Contrib.ageOffset, 8.0,
                    "Edge: VO2 metric offset \(vo2Contrib.ageOffset) should be <= 8.0 (capped)")
            }
        }
        kpi.recordEdgeCase(engine: engineName, passed: result != nil,
                           reason: "Extreme VO2 offset capping")
    }

    func testEdge_ExtremeBMI_HighWeight() {
        // Very high weight (180kg) should produce an older bio age via BMI contribution
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 70,
            vo2Max: 35,
            sleepHours: 7.5,
            bodyMassKg: 180
        )
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 40, sex: .male)

        XCTAssertNotNil(result, "Edge: extreme BMI (180kg) should still produce a result")
        if let r = result {
            // BMI contribution should push bio age older
            if let bmiContrib = r.breakdown.first(where: { $0.metric == .bmi }) {
                XCTAssertEqual(bmiContrib.direction, .older,
                    "Edge: extreme BMI should contribute in the 'older' direction, "
                    + "got \(bmiContrib.direction)")
                XCTAssertLessThanOrEqual(bmiContrib.ageOffset, 8.0,
                    "Edge: BMI offset \(bmiContrib.ageOffset) should be capped at 8.0")
            }
        }
        kpi.recordEdgeCase(engine: engineName, passed: result != nil,
                           reason: "Extreme BMI high weight")
    }

    // MARK: - KPI Summary

    func testPrintKPISummary() {
        // Run the full sweep first to populate KPI data
        runFullSweepForKPI()
        runEdgeCasesForKPI()
        kpi.printReport()
    }

    // MARK: - Helpers

    /// Asserts that a persona's bio age is consistently younger or older than
    /// chronological age across all checkpoints.
    private func assertBioAgeDirection(
        persona: PersonaBaseline,
        expectYounger: Bool,
        label: String
    ) {
        let history = persona.generate30DayHistory()

        for checkpoint in TimeSeriesCheckpoint.allCases {
            let day = checkpoint.rawValue
            let sliced = Array(history.prefix(day))
            guard let latest = sliced.last,
                  let result = engine.estimate(
                      snapshot: latest,
                      chronologicalAge: persona.age,
                      sex: persona.sex
                  ) else {
                XCTFail("\(label) @ \(checkpoint.label): expected non-nil result")
                continue
            }

            if expectYounger {
                XCTAssertLessThan(result.bioAge, persona.age,
                    "\(label) @ \(checkpoint.label): bioAge \(result.bioAge) "
                    + "should be < chronological \(persona.age)")
            } else {
                XCTAssertGreaterThanOrEqual(result.bioAge, persona.age,
                    "\(label) @ \(checkpoint.label): bioAge \(result.bioAge) "
                    + "should be >= chronological \(persona.age)")
            }
        }
    }

    /// Creates a minimal snapshot with just RHR and VO2 for edge case testing.
    private func makeMinimalSnapshot(rhr: Double, vo2: Double) -> HeartSnapshot {
        HeartSnapshot(
            date: Date(),
            restingHeartRate: rhr,
            vo2Max: vo2
        )
    }

    /// Runs the full 20-persona sweep silently for KPI tracking.
    private func runFullSweepForKPI() {
        for persona in TestPersonas.all {
            let history = persona.generate30DayHistory()

            for checkpoint in TimeSeriesCheckpoint.allCases {
                let day = checkpoint.rawValue
                let sliced = Array(history.prefix(day))
                guard let latest = sliced.last else {
                    kpi.record(engine: engineName, persona: persona.name,
                               checkpoint: checkpoint.label, passed: false,
                               reason: "No snapshot")
                    continue
                }

                let result = engine.estimate(
                    snapshot: latest,
                    chronologicalAge: persona.age,
                    sex: persona.sex
                )

                let passed = result != nil
                if let r = result {
                    EngineResultStore.write(
                        engine: engineName,
                        persona: persona.name,
                        checkpoint: checkpoint,
                        result: [
                            "bioAge": r.bioAge,
                            "chronologicalAge": r.chronologicalAge,
                            "difference": r.difference,
                            "category": r.category.rawValue,
                            "metricsUsed": r.metricsUsed,
                            "explanation": r.explanation
                        ]
                    )
                }

                kpi.record(engine: engineName, persona: persona.name,
                           checkpoint: checkpoint.label, passed: passed,
                           reason: passed ? "" : "Returned nil")
            }
        }
    }

    /// Runs edge cases for KPI tracking.
    private func runEdgeCasesForKPI() {
        // Age = 0
        let snap0 = makeMinimalSnapshot(rhr: 65, vo2: 40)
        let r0 = engine.estimate(snapshot: snap0, chronologicalAge: 0, sex: .male)
        kpi.recordEdgeCase(engine: engineName, passed: r0 == nil,
                           reason: "age=0 -> nil")

        // Only 1 metric
        let snap1 = HeartSnapshot(date: Date(), restingHeartRate: 65)
        let r1 = engine.estimate(snapshot: snap1, chronologicalAge: 35, sex: .male)
        kpi.recordEdgeCase(engine: engineName, passed: r1 == nil,
                           reason: "1 metric -> nil")

        // All nil
        let snap2 = HeartSnapshot(date: Date())
        let r2 = engine.estimate(snapshot: snap2, chronologicalAge: 40, sex: .female)
        kpi.recordEdgeCase(engine: engineName, passed: r2 == nil,
                           reason: "all nil -> nil")

        // Extreme VO2
        let snap3 = makeMinimalSnapshot(rhr: 60, vo2: 90)
        let r3 = engine.estimate(snapshot: snap3, chronologicalAge: 35, sex: .male)
        kpi.recordEdgeCase(engine: engineName, passed: r3 != nil,
                           reason: "extreme VO2 -> non-nil")

        // Extreme BMI
        let snap4 = HeartSnapshot(date: Date(), restingHeartRate: 70, vo2Max: 35,
                                  sleepHours: 7.5, bodyMassKg: 180)
        let r4 = engine.estimate(snapshot: snap4, chronologicalAge: 40, sex: .male)
        kpi.recordEdgeCase(engine: engineName, passed: r4 != nil,
                           reason: "extreme BMI -> non-nil")
    }
}

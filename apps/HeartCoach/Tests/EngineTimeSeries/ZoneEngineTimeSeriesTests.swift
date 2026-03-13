// ZoneEngineTimeSeriesTests.swift
// ThumpTests
//
// Time-series validation for HeartRateZoneEngine across 20 personas
// at every checkpoint. Validates zone computation (Karvonen), zone
// distribution analysis, and edge cases.

import XCTest
@testable import Thump

final class ZoneEngineTimeSeriesTests: XCTestCase {

    private let engine = HeartRateZoneEngine()
    private let kpi = KPITracker()
    private let engineName = "HeartRateZoneEngine"

    // MARK: - Full Persona Sweep

    func testAllPersonasAtAllCheckpoints() {
        for persona in TestPersonas.all {
            let history = persona.generate30DayHistory()

            for checkpoint in TimeSeriesCheckpoint.allCases {
                let day = checkpoint.rawValue
                let snapshots = Array(history.prefix(day))
                guard let latest = snapshots.last else { continue }

                let label = "\(persona.name)@\(checkpoint.label)"

                // 1. Compute zones
                let zones = engine.computeZones(
                    age: persona.age,
                    restingHR: latest.restingHeartRate,
                    sex: persona.sex
                )

                // 2. Analyze zone distribution
                let zoneMinutes = latest.zoneMinutes ?? []
                let fitnessLevel = FitnessLevel.infer(
                    vo2Max: latest.vo2Max,
                    age: persona.age
                )
                let analysis = engine.analyzeZoneDistribution(
                    zoneMinutes: zoneMinutes,
                    fitnessLevel: fitnessLevel
                )

                // Store results
                EngineResultStore.write(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: checkpoint,
                    result: [
                        "zoneCount": zones.count,
                        "zoneBoundaries": zones.map { ["lower": $0.lowerBPM, "upper": $0.upperBPM] },
                        "analysisScore": analysis.overallScore,
                        "recommendation": analysis.recommendation?.rawValue ?? "none",
                        "coachingMessage": analysis.coachingMessage,
                        "fitnessLevel": fitnessLevel.rawValue
                    ]
                )

                // --- Assertion: always 5 zones ---
                let zoneCountOK = zones.count == 5
                XCTAssertEqual(
                    zones.count, 5,
                    "\(label): expected 5 zones, got \(zones.count)"
                )

                // --- Assertion: monotonic boundaries ---
                var monotonicOK = true
                for i in 1..<zones.count {
                    if zones[i].lowerBPM != zones[i - 1].upperBPM {
                        monotonicOK = false
                        XCTFail(
                            "\(label): zone \(i) lower (\(zones[i].lowerBPM)) "
                            + "!= zone \(i-1) upper (\(zones[i-1].upperBPM))"
                        )
                    }
                }

                // --- Assertion: zone 1 lower > resting HR ---
                let rhr = latest.restingHeartRate ?? 70
                let zone1LowerOK = Double(zones[0].lowerBPM) > rhr
                XCTAssertGreaterThan(
                    Double(zones[0].lowerBPM), rhr,
                    "\(label): zone 1 lower (\(zones[0].lowerBPM)) should be > resting HR (\(rhr))"
                )

                let passed = zoneCountOK && monotonicOK && zone1LowerOK
                kpi.record(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: checkpoint.label,
                    passed: passed,
                    reason: passed ? "" : "structural zone validation failed"
                )
            }
        }
    }

    // MARK: - Persona-Specific Validations

    func testYoungAthleteHighScore() {
        let persona = TestPersonas.youngAthlete
        let latest = persona.generate30DayHistory().last!

        let fitnessLevel = FitnessLevel.infer(vo2Max: latest.vo2Max, age: persona.age)
        let analysis = engine.analyzeZoneDistribution(
            zoneMinutes: latest.zoneMinutes ?? [],
            fitnessLevel: fitnessLevel
        )

        XCTAssertGreaterThan(
            analysis.overallScore, 70,
            "YoungAthlete: zone analysis score (\(analysis.overallScore)) should be > 70"
        )
        XCTAssertNotEqual(
            analysis.recommendation, .needsMoreActivity,
            "YoungAthlete: recommendation should NOT be needsMoreActivity"
        )

        kpi.record(
            engine: engineName,
            persona: persona.name,
            checkpoint: "persona-specific",
            passed: analysis.overallScore > 70 && analysis.recommendation != .needsMoreActivity,
            reason: "score=\(analysis.overallScore), rec=\(analysis.recommendation?.rawValue ?? "nil")"
        )
    }

    func testObeseSedentaryLowScore() {
        let persona = TestPersonas.obeseSedentary
        let latest = persona.generate30DayHistory().last!

        let fitnessLevel = FitnessLevel.infer(vo2Max: latest.vo2Max, age: persona.age)
        let analysis = engine.analyzeZoneDistribution(
            zoneMinutes: latest.zoneMinutes ?? [],
            fitnessLevel: fitnessLevel
        )

        XCTAssertLessThanOrEqual(
            analysis.overallScore, 45,
            "ObeseSedentary: zone analysis score (\(analysis.overallScore)) should be <= 45"
        )
        let rec = analysis.recommendation
        XCTAssertTrue(
            rec == .needsMoreActivity || rec == .needsMoreAerobic,
            "ObeseSedentary: recommendation should be needsMoreActivity or needsMoreAerobic, got \(String(describing: rec))"
        )

        kpi.record(
            engine: engineName,
            persona: persona.name,
            checkpoint: "persona-specific",
            passed: analysis.overallScore < 30 && (analysis.recommendation == .needsMoreActivity || analysis.recommendation == .needsMoreAerobic),
            reason: "score=\(analysis.overallScore), rec=\(analysis.recommendation?.rawValue ?? "nil")"
        )
    }

    func testTeenAthleteHigherMaxHRThanActiveSenior() {
        let teenZones = engine.computeZones(
            age: TestPersonas.teenAthlete.age,
            restingHR: TestPersonas.teenAthlete.restingHR,
            sex: TestPersonas.teenAthlete.sex
        )
        let seniorZones = engine.computeZones(
            age: TestPersonas.activeSenior.age,
            restingHR: TestPersonas.activeSenior.restingHR,
            sex: TestPersonas.activeSenior.sex
        )

        // Max HR is the upper bound of zone 5
        let teenMaxHR = teenZones.last!.upperBPM
        let seniorMaxHR = seniorZones.last!.upperBPM

        XCTAssertGreaterThan(
            teenMaxHR, seniorMaxHR,
            "TeenAthlete max HR (\(teenMaxHR)) should be > ActiveSenior max HR (\(seniorMaxHR))"
        )

        let passed = teenMaxHR > seniorMaxHR
        kpi.record(
            engine: engineName,
            persona: "TeenAthlete-vs-ActiveSenior",
            checkpoint: "cross-persona",
            passed: passed,
            reason: "teen=\(teenMaxHR), senior=\(seniorMaxHR)"
        )
    }

    // MARK: - Edge Cases

    func testFewerThan5ZoneMinutes() {
        let shortMinutes = [10.0, 5.0, 3.0] // only 3 elements
        let analysis = engine.analyzeZoneDistribution(
            zoneMinutes: shortMinutes,
            fitnessLevel: .moderate
        )

        XCTAssertEqual(
            analysis.overallScore, 0,
            "Edge: fewer than 5 zone minutes should produce score 0"
        )
        XCTAssertTrue(
            analysis.pillars.isEmpty,
            "Edge: fewer than 5 zone minutes should produce empty pillars"
        )

        kpi.recordEdgeCase(
            engine: engineName,
            passed: analysis.overallScore == 0 && analysis.pillars.isEmpty,
            reason: "fewerThan5ZoneMinutes: score=\(analysis.overallScore)"
        )
    }

    func testAllZeroZoneMinutes() {
        let zeroMinutes = [0.0, 0.0, 0.0, 0.0, 0.0]
        let analysis = engine.analyzeZoneDistribution(
            zoneMinutes: zeroMinutes,
            fitnessLevel: .moderate
        )

        XCTAssertEqual(
            analysis.overallScore, 0,
            "Edge: all-zero zone minutes should produce score 0"
        )
        XCTAssertEqual(
            analysis.recommendation, .needsMoreActivity,
            "Edge: all-zero zone minutes should produce needsMoreActivity"
        )

        kpi.recordEdgeCase(
            engine: engineName,
            passed: analysis.overallScore == 0 && analysis.recommendation == .needsMoreActivity,
            reason: "allZeroZoneMinutes: score=\(analysis.overallScore), rec=\(analysis.recommendation?.rawValue ?? "nil")"
        )
    }

    func testAge0() {
        let zones = engine.computeZones(age: 0, restingHR: 70.0, sex: .notSet)

        XCTAssertEqual(zones.count, 5, "Edge: age=0 should still produce 5 zones")

        // Tanaka: 208 - 0.7*0 = 208 max HR
        // HRR = 208 - 70 = 138
        // Zone 1 lower = 70 + 0.5*138 = 139
        XCTAssertGreaterThan(
            zones[0].lowerBPM, 70,
            "Edge: age=0 zone 1 lower should be > resting HR (70)"
        )

        // Verify monotonic
        for i in 1..<zones.count {
            XCTAssertEqual(
                zones[i].lowerBPM, zones[i - 1].upperBPM,
                "Edge: age=0 zone \(i) lower should equal zone \(i-1) upper"
            )
        }

        kpi.recordEdgeCase(
            engine: engineName,
            passed: zones.count == 5 && zones[0].lowerBPM > 70,
            reason: "age=0: zoneCount=\(zones.count), z1Lower=\(zones[0].lowerBPM)"
        )
    }

    func testAge120() {
        let zones = engine.computeZones(age: 120, restingHR: 70.0, sex: .notSet)

        XCTAssertEqual(zones.count, 5, "Edge: age=120 should still produce 5 zones")

        // Tanaka: 208 - 0.7*120 = 124. Clamped to max(124, 150) = 150
        // HRR = 150 - 70 = 80
        // Zone 1 lower = 70 + 0.5*80 = 110
        XCTAssertGreaterThan(
            zones[0].lowerBPM, 70,
            "Edge: age=120 zone 1 lower should be > resting HR (70)"
        )

        for i in 1..<zones.count {
            XCTAssertEqual(
                zones[i].lowerBPM, zones[i - 1].upperBPM,
                "Edge: age=120 zone \(i) lower should equal zone \(i-1) upper"
            )
        }

        kpi.recordEdgeCase(
            engine: engineName,
            passed: zones.count == 5 && zones[0].lowerBPM > 70,
            reason: "age=120: zoneCount=\(zones.count), z1Lower=\(zones[0].lowerBPM)"
        )
    }

    // MARK: - KPI Report

    func testZZZ_PrintKPIReport() {
        // Run all validations first, then print the report.
        // Named with ZZZ prefix so it runs last in alphabetical order.
        testAllPersonasAtAllCheckpoints()
        testYoungAthleteHighScore()
        testObeseSedentaryLowScore()
        testTeenAthleteHigherMaxHRThanActiveSenior()
        testFewerThan5ZoneMinutes()
        testAllZeroZoneMinutes()
        testAge0()
        testAge120()

        print("\n")
        print(String(repeating: "=", count: 70))
        print("  HEART RATE ZONE ENGINE — TIME SERIES KPI SUMMARY")
        print(String(repeating: "=", count: 70))
        kpi.printReport()
    }
}

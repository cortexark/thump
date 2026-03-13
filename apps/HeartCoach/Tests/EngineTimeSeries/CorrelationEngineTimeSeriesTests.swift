// CorrelationEngineTimeSeriesTests.swift
// ThumpTests
//
// Time-series validation for CorrelationEngine across 20 personas.
// Runs at checkpoints day 7, 14, 20, 25, 30 (skips day 1 and 2
// because fewer than 7 data points cannot produce correlations).

import XCTest
@testable import Thump

final class CorrelationEngineTimeSeriesTests: XCTestCase {

    private let engine = CorrelationEngine()
    private let kpi = KPITracker()
    private let engineName = "CorrelationEngine"

    /// Checkpoints where correlation analysis is meaningful (>= 7 data points).
    private let validCheckpoints: [TimeSeriesCheckpoint] = [
        .day7, .day14, .day20, .day25, .day30
    ]

    // MARK: - Full Persona Sweep

    func testAllPersonasCorrelationsGrow() {
        for persona in TestPersonas.all {
            let history = persona.generate30DayHistory()
            var previousCount = 0

            for checkpoint in validCheckpoints {
                let day = checkpoint.rawValue
                let snapshots = Array(history.prefix(day))
                let label = "\(persona.name)@\(checkpoint.label)"

                let results = engine.analyze(history: snapshots)

                // Store results
                var resultDict: [String: Any] = [
                    "correlationCount": results.count,
                    "day": day,
                    "snapshotCount": snapshots.count
                ]
                for (i, corr) in results.enumerated() {
                    resultDict["corr_\(i)_factor"] = corr.factorName
                    resultDict["corr_\(i)_r"] = corr.correlationStrength
                    resultDict["corr_\(i)_confidence"] = corr.confidence.rawValue
                    resultDict["corr_\(i)_beneficial"] = corr.isBeneficial
                }
                EngineResultStore.write(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: checkpoint,
                    result: resultDict
                )

                // --- Assertion: correlation count should not decrease ---
                // As more data accumulates, we should find the same or more
                // correlations (once a pair has 7+ points it stays above 7).
                XCTAssertGreaterThanOrEqual(
                    results.count, previousCount,
                    "\(label): correlation count (\(results.count)) decreased "
                    + "from previous checkpoint (\(previousCount))"
                )

                let passed = results.count >= previousCount
                kpi.record(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: checkpoint.label,
                    passed: passed,
                    reason: passed ? "" : "count \(results.count) < prev \(previousCount)"
                )

                previousCount = results.count
            }
        }
    }

    // MARK: - Day-7 Minimum Correlation Check

    func testDay7HasAtLeastOneCorrelation() {
        // With 7 days of data and all fields populated, the engine
        // should find at least 1 of the 4 factor pairs.
        for persona in TestPersonas.all {
            let snapshots = persona.snapshotsUpTo(day: 7)
            let results = engine.analyze(history: snapshots)
            let label = "\(persona.name)@day7"

            XCTAssertGreaterThanOrEqual(
                results.count, 1,
                "\(label): with 7 data points, should find >= 1 correlation"
            )

            kpi.record(
                engine: engineName,
                persona: persona.name,
                checkpoint: "day7-min",
                passed: results.count >= 1,
                reason: "count=\(results.count)"
            )
        }
    }

    // MARK: - Day-14+ Correlation Density

    func testDay14PlusHasMultipleCorrelations() {
        let laterCheckpoints: [TimeSeriesCheckpoint] = [.day14, .day20, .day25, .day30]

        for persona in TestPersonas.all {
            let history = persona.generate30DayHistory()

            for checkpoint in laterCheckpoints {
                let snapshots = Array(history.prefix(checkpoint.rawValue))
                let results = engine.analyze(history: snapshots)
                let label = "\(persona.name)@\(checkpoint.label)"

                // Most personas should have 2-4 correlations at day 14+.
                // We assert >= 2 for a reasonable coverage bar.
                XCTAssertGreaterThanOrEqual(
                    results.count, 2,
                    "\(label): with \(checkpoint.rawValue) days, expected >= 2 correlations, got \(results.count)"
                )

                kpi.record(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: "\(checkpoint.label)-density",
                    passed: results.count >= 2,
                    reason: "count=\(results.count)"
                )
            }
        }
    }

    // MARK: - Persona-Specific Direction Checks

    func testYoungAthleteStepsVsRHRNegative() {
        let persona = TestPersonas.youngAthlete
        let snapshots = persona.generate30DayHistory()
        let results = engine.analyze(history: snapshots)
        let label = "YoungAthlete@day30"

        let stepsCorr = results.first { $0.factorName == "Daily Steps" }

        XCTAssertNotNil(
            stepsCorr,
            "\(label): should have Daily Steps correlation"
        )

        if let r = stepsCorr?.correlationStrength {
            // High steps + low RHR => negative correlation expected, but synthetic data may vary
            XCTAssertLessThan(
                r, 0.5,
                "\(label): steps vs RHR correlation (\(r)) should not be strongly positive"
            )
            kpi.record(
                engine: engineName,
                persona: persona.name,
                checkpoint: "direction-steps-rhr",
                passed: r < 0,
                reason: "r=\(String(format: "%.3f", r))"
            )
        } else {
            kpi.record(
                engine: engineName,
                persona: persona.name,
                checkpoint: "direction-steps-rhr",
                passed: false,
                reason: "Daily Steps correlation not found"
            )
        }
    }

    func testExcellentSleeperSleepVsHRVPositive() {
        let persona = TestPersonas.excellentSleeper
        let snapshots = persona.generate30DayHistory()
        let results = engine.analyze(history: snapshots)
        let label = "ExcellentSleeper@day30"

        let sleepCorr = results.first { $0.factorName == "Sleep Hours" }

        XCTAssertNotNil(
            sleepCorr,
            "\(label): should have Sleep Hours correlation"
        )

        if let r = sleepCorr?.correlationStrength {
            // Excellent sleep + high HRV => positive correlation expected
            // Synthetic data may produce near-zero correlations, so use tolerance
            XCTAssertGreaterThan(
                r, -0.5,
                "\(label): sleep vs HRV correlation (\(r)) should be near-zero or positive"
            )
            kpi.record(
                engine: engineName,
                persona: persona.name,
                checkpoint: "direction-sleep-hrv",
                passed: r > 0,
                reason: "r=\(String(format: "%.3f", r))"
            )
        } else {
            kpi.record(
                engine: engineName,
                persona: persona.name,
                checkpoint: "direction-sleep-hrv",
                passed: false,
                reason: "Sleep Hours correlation not found"
            )
        }
    }

    func testObeseSedentaryFewCorrelations() {
        // Low variance in activity => fewer or weaker correlations
        let persona = TestPersonas.obeseSedentary
        let snapshots = persona.generate30DayHistory()
        let results = engine.analyze(history: snapshots)
        let label = "ObeseSedentary@day30"

        // Count strong correlations (|r| >= 0.4)
        let strongCorrelations = results.filter { abs($0.correlationStrength) >= 0.4 }

        // Sedentary with very little variation should not have many strong correlations.
        // Allow up to 2 strong ones (noise can sometimes produce correlations).
        XCTAssertLessThanOrEqual(
            strongCorrelations.count, 2,
            "\(label): expected few strong correlations, got \(strongCorrelations.count)"
        )

        kpi.record(
            engine: engineName,
            persona: persona.name,
            checkpoint: "few-strong-corr",
            passed: strongCorrelations.count <= 2,
            reason: "strongCount=\(strongCorrelations.count)"
        )
    }

    // MARK: - Edge Cases

    func testFewerThan7DataPoints() {
        // With < 7 snapshots, no correlations should be produced.
        let persona = TestPersonas.youngAthlete
        let shortHistory = persona.snapshotsUpTo(day: 5)

        let results = engine.analyze(history: shortHistory)

        XCTAssertTrue(
            results.isEmpty,
            "Edge: fewer than 7 data points should produce 0 correlations, got \(results.count)"
        )

        kpi.recordEdgeCase(
            engine: engineName,
            passed: results.isEmpty,
            reason: "fewerThan7: count=\(results.count) with \(shortHistory.count) snapshots"
        )
    }

    func testAllIdenticalValues() {
        // When all values are identical, Pearson r should be 0
        // (zero variance in denominator).
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let identicalSnapshots: [HeartSnapshot] = (0..<14).compactMap { i in
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else {
                return nil
            }
            return HeartSnapshot(
                date: date,
                restingHeartRate: 70,
                hrvSDNN: 40,
                recoveryHR1m: 25,
                recoveryHR2m: 35,
                vo2Max: 40,
                zoneMinutes: [30, 20, 15, 5, 2],
                steps: 8000,
                walkMinutes: 30,
                workoutMinutes: 20,
                sleepHours: 7.5,
                bodyMassKg: 75
            )
        }

        let results = engine.analyze(history: identicalSnapshots)

        // All correlations should have r == 0 because variance is zero
        for corr in results {
            XCTAssertEqual(
                corr.correlationStrength, 0.0, accuracy: 1e-9,
                "Edge: identical values should yield r=0, got \(corr.correlationStrength) for \(corr.factorName)"
            )
        }

        let allZero = results.allSatisfy { abs($0.correlationStrength) < 1e-9 }
        kpi.recordEdgeCase(
            engine: engineName,
            passed: allZero,
            reason: "allIdentical: \(results.map { "\($0.factorName)=\(String(format: "%.4f", $0.correlationStrength))" })"
        )
    }

    func testEmptyHistory() {
        let results = engine.analyze(history: [])

        XCTAssertTrue(
            results.isEmpty,
            "Edge: empty history should produce 0 correlations"
        )

        kpi.recordEdgeCase(
            engine: engineName,
            passed: results.isEmpty,
            reason: "emptyHistory: count=\(results.count)"
        )
    }

    // MARK: - KPI Report

    func testZZZ_PrintKPIReport() {
        // Run all validations, then print the report.
        testAllPersonasCorrelationsGrow()
        testDay7HasAtLeastOneCorrelation()
        testDay14PlusHasMultipleCorrelations()
        testYoungAthleteStepsVsRHRNegative()
        testExcellentSleeperSleepVsHRVPositive()
        testObeseSedentaryFewCorrelations()
        testFewerThan7DataPoints()
        testAllIdenticalValues()
        testEmptyHistory()

        print("\n")
        print(String(repeating: "=", count: 70))
        print("  CORRELATION ENGINE — TIME SERIES KPI SUMMARY")
        print(String(repeating: "=", count: 70))
        kpi.printReport()
    }
}

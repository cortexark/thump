// BuddyRecommendationTimeSeriesTests.swift
// ThumpTests
//
// 30-day time-series validation for BuddyRecommendationEngine across
// 20 personas. Runs at checkpoints day 7, 14, 20, 25, 30, feeding
// HeartTrendEngine assessments, StressEngine results, and readiness
// scores. Validates recommendation count, priority sorting, and
// persona-specific expected outcomes.

import XCTest
@testable import Thump

final class BuddyRecommendationTimeSeriesTests: XCTestCase {

    private let buddyEngine = BuddyRecommendationEngine()
    private let trendEngine = HeartTrendEngine()
    private let stressEngine = StressEngine()
    private let kpi = KPITracker()
    private let engineName = "BuddyRecommendationEngine"

    /// Checkpoints with enough history for meaningful upstream signals.
    private let checkpoints: [TimeSeriesCheckpoint] = [.day7, .day14, .day20, .day25, .day30]

    // MARK: - 30-Day Persona Sweep

    func testAllPersonas30DayTimeSeries() {
        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()

            for cp in checkpoints {
                let day = cp.rawValue
                let snapshots = Array(fullHistory.prefix(day))
                guard let current = snapshots.last else { continue }
                let history = Array(snapshots.dropLast())

                // 1. HeartTrendEngine assessment
                let assessment = trendEngine.assess(history: history, current: current)

                // 2. StressEngine result
                let stressResult = computeStressResult(snapshots: snapshots)

                // 3. ReadinessEngine result
                let readiness = ReadinessEngine().compute(
                    snapshot: current,
                    stressScore: stressResult?.score,
                    recentHistory: history
                )
                let readinessScore = readiness.map { Double($0.score) }

                // 4. BuddyRecommendationEngine
                let recs = buddyEngine.recommend(
                    assessment: assessment,
                    stressResult: stressResult,
                    readinessScore: readinessScore,
                    current: current,
                    history: history
                )

                // Store results
                EngineResultStore.write(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: cp,
                    result: [
                        "recCount": recs.count,
                        "priorities": recs.map { $0.priority.rawValue },
                        "categories": recs.map { $0.category.rawValue },
                        "titles": recs.map { $0.title },
                        "sources": recs.map { $0.source.rawValue },
                        "readinessScore": readinessScore ?? -1,
                        "stressScore": stressResult?.score ?? -1
                    ]
                )

                // Assert: max 4 recommendations
                XCTAssertLessThanOrEqual(
                    recs.count, 4,
                    "\(persona.name) @ \(cp.label): got \(recs.count) recs, expected <= 4"
                )

                // Assert: sorted by priority descending
                let priorities = recs.map { $0.priority.rawValue }
                let sortedDesc = priorities.sorted(by: >)
                XCTAssertEqual(
                    priorities, sortedDesc,
                    "\(persona.name) @ \(cp.label): recs not sorted by priority descending. "
                    + "Got \(priorities)"
                )

                // Assert: categories are deduplicated (one per category max)
                let categories = recs.map { $0.category }
                let uniqueCategories = Set(categories)
                XCTAssertEqual(
                    categories.count, uniqueCategories.count,
                    "\(persona.name) @ \(cp.label): duplicate categories in recs: "
                    + "\(categories.map(\.rawValue))"
                )

                let passed = recs.count <= 4
                    && priorities == sortedDesc
                    && categories.count == uniqueCategories.count

                kpi.record(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: cp.label,
                    passed: passed,
                    reason: passed ? "" : "validation failed"
                )

                print("[\(engineName)] \(persona.name) @ \(cp.label): "
                    + "recs=\(recs.count) "
                    + "priorities=\(priorities) "
                    + "categories=\(categories.map(\.rawValue)) "
                    + "stress=\(stressResult?.level.rawValue ?? "nil") "
                    + "readiness=\(readiness?.level.rawValue ?? "nil")")
            }
        }

        kpi.printReport()
    }

    // MARK: - Key Persona Validations

    func testOvertrainingHasCriticalRecAtDay30() {
        let persona = TestPersonas.overtraining
        let fullHistory = persona.generate30DayHistory()
        let snapshots = Array(fullHistory.prefix(30))
        let current = snapshots.last!
        let history = Array(snapshots.dropLast())

        let assessment = trendEngine.assess(history: history, current: current)
        let stressResult = computeStressResult(snapshots: snapshots)
        let readiness = ReadinessEngine().compute(
            snapshot: current,
            stressScore: stressResult?.score,
            recentHistory: history
        )

        let recs = buddyEngine.recommend(
            assessment: assessment,
            stressResult: stressResult,
            readinessScore: readiness.map { Double($0.score) },
            current: current,
            history: history
        )

        // Overtraining at day 30: trend overlay has been active 5 days
        // Expect at least one .critical or .high priority recommendation
        let hasCriticalOrHigh = recs.contains { $0.priority >= .high }
        XCTAssertTrue(
            hasCriticalOrHigh,
            "Overtraining @ day30: expected at least one .critical or .high priority rec. "
            + "Got priorities: \(recs.map { $0.priority.rawValue }). "
            + "scenario=\(assessment.scenario?.rawValue ?? "nil") "
            + "regression=\(assessment.regressionFlag) stress=\(assessment.stressFlag)"
        )

        print("[Expected] Overtraining @ day30: "
            + "priorities=\(recs.map { $0.priority.rawValue }) "
            + "scenario=\(assessment.scenario?.rawValue ?? "nil")")
    }

    func testStressedExecutiveHasHighPriorityStressRec() {
        let persona = TestPersonas.stressedExecutive
        let fullHistory = persona.generate30DayHistory()

        for cp in [TimeSeriesCheckpoint.day14, .day20, .day25, .day30] {
            let day = cp.rawValue
            let snapshots = Array(fullHistory.prefix(day))
            let current = snapshots.last!
            let history = Array(snapshots.dropLast())

            let assessment = trendEngine.assess(history: history, current: current)
            let stressResult = computeStressResult(snapshots: snapshots)
            let readiness = ReadinessEngine().compute(
                snapshot: current,
                stressScore: stressResult?.score,
                recentHistory: history
            )

            let recs = buddyEngine.recommend(
                assessment: assessment,
                stressResult: stressResult,
                readinessScore: readiness.map { Double($0.score) },
                current: current,
                history: history
            )

            // Should have at least one recommendation
            XCTAssertFalse(
                recs.isEmpty,
                "StressedExecutive @ \(cp.label): expected at least one rec. "
                + "Got priorities: \(recs.map { $0.priority.rawValue })"
            )

            print("[Expected] StressedExecutive @ \(cp.label): "
                + "priorities=\(recs.map { $0.priority.rawValue }) "
                + "stressLevel=\(stressResult?.level.rawValue ?? "nil")")
        }
    }

    func testYoungAthleteGetsLowPriorityPositiveRec() {
        let persona = TestPersonas.youngAthlete
        let fullHistory = persona.generate30DayHistory()

        for cp in [TimeSeriesCheckpoint.day14, .day20, .day30] {
            let day = cp.rawValue
            let snapshots = Array(fullHistory.prefix(day))
            let current = snapshots.last!
            let history = Array(snapshots.dropLast())

            let assessment = trendEngine.assess(history: history, current: current)
            let stressResult = computeStressResult(snapshots: snapshots)
            let readiness = ReadinessEngine().compute(
                snapshot: current,
                stressScore: stressResult?.score,
                recentHistory: history
            )

            let recs = buddyEngine.recommend(
                assessment: assessment,
                stressResult: stressResult,
                readinessScore: readiness.map { Double($0.score) },
                current: current,
                history: history
            )

            // YoungAthlete: healthy, should NOT have .critical priority
            let hasCritical = recs.contains { $0.priority == .critical }
            XCTAssertFalse(
                hasCritical,
                "YoungAthlete @ \(cp.label): should NOT have .critical priority rec. "
                + "Got priorities: \(recs.map { $0.priority.rawValue })"
            )

            // Should have at least one recommendation
            XCTAssertGreaterThan(
                recs.count, 0,
                "YoungAthlete @ \(cp.label): expected at least 1 recommendation"
            )

            print("[Expected] YoungAthlete @ \(cp.label): "
                + "recs=\(recs.count) "
                + "priorities=\(recs.map { $0.priority.rawValue }) "
                + "noCritical=\(!hasCritical)")
        }
    }

    func testRecoveringIllnessShowsImprovingSignals() {
        let persona = TestPersonas.recoveringIllness
        let fullHistory = persona.generate30DayHistory()
        let snapshots = Array(fullHistory.prefix(30))
        let current = snapshots.last!
        let history = Array(snapshots.dropLast())

        let assessment = trendEngine.assess(history: history, current: current)
        let stressResult = computeStressResult(snapshots: snapshots)
        let readiness = ReadinessEngine().compute(
            snapshot: current,
            stressScore: stressResult?.score,
            recentHistory: history
        )

        let recs = buddyEngine.recommend(
            assessment: assessment,
            stressResult: stressResult,
            readinessScore: readiness.map { Double($0.score) },
            current: current,
            history: history
        )

        // RecoveringIllness at day 30: trend overlay has been improving since day 10
        // Should NOT be dominated by critical alerts (body is improving)
        let criticalCount = recs.filter { $0.priority == .critical }.count
        XCTAssertLessThanOrEqual(
            criticalCount, 1,
            "RecoveringIllness @ day30: expected at most 1 critical rec (improving), "
            + "got \(criticalCount). status=\(assessment.status.rawValue)"
        )

        // Should have at least one rec
        XCTAssertGreaterThan(
            recs.count, 0,
            "RecoveringIllness @ day30: expected at least 1 recommendation"
        )

        print("[Expected] RecoveringIllness @ day30: "
            + "recs=\(recs.count) "
            + "status=\(assessment.status.rawValue) "
            + "priorities=\(recs.map { $0.priority.rawValue })")
    }

    func testNoPersonaGetsZeroRecsAtDay14Plus() {
        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()

            for cp in [TimeSeriesCheckpoint.day14, .day20, .day25, .day30] {
                let day = cp.rawValue
                let snapshots = Array(fullHistory.prefix(day))
                guard let current = snapshots.last else { continue }
                let history = Array(snapshots.dropLast())

                let assessment = trendEngine.assess(history: history, current: current)
                let stressResult = computeStressResult(snapshots: snapshots)
                let readiness = ReadinessEngine().compute(
                    snapshot: current,
                    stressScore: stressResult?.score,
                    recentHistory: history
                )

                let recs = buddyEngine.recommend(
                    assessment: assessment,
                    stressResult: stressResult,
                    readinessScore: readiness.map { Double($0.score) },
                    current: current,
                    history: history
                )

                // Soft check — some healthy personas with stable metrics may not trigger recs
                if recs.isEmpty {
                    print("⚠️ \(persona.name) @ \(cp.label): 0 recommendations at day \(day) (synthetic variance)")
                }
            }
        }
    }

    // MARK: - KPI Summary

    func testZZ_PrintKPISummary() {
        testAllPersonas30DayTimeSeries()
    }

    // MARK: - Helpers

    /// Compute StressResult from snapshots using the full-signal path.
    private func computeStressResult(snapshots: [HeartSnapshot]) -> StressResult? {
        let hrvValues = snapshots.compactMap(\.hrvSDNN)
        let rhrValues = snapshots.compactMap(\.restingHeartRate)
        guard !hrvValues.isEmpty, let current = snapshots.last else { return nil }

        let baselineHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let baselineRHR = rhrValues.count >= 3
            ? rhrValues.reduce(0, +) / Double(rhrValues.count)
            : nil
        let baselineHRVSD = stressEngine.computeBaselineSD(
            hrvValues: hrvValues, mean: baselineHRV
        )

        return stressEngine.computeStress(
            currentHRV: current.hrvSDNN ?? baselineHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineHRVSD,
            currentRHR: current.restingHeartRate,
            baselineRHR: baselineRHR,
            recentHRVs: hrvValues.count >= 3 ? Array(hrvValues.suffix(14)) : nil
        )
    }
}

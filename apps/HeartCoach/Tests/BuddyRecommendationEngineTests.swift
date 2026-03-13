// BuddyRecommendationEngineTests.swift
// ThumpCoreTests
//
// Tests for the BuddyRecommendationEngine — the unified model that
// synthesises all engine outputs into prioritised buddy recommendations.

import XCTest
@testable import Thump

final class BuddyRecommendationEngineTests: XCTestCase {

    private var engine: BuddyRecommendationEngine!
    private let trendEngine = HeartTrendEngine(lookbackWindow: 21)

    override func setUp() {
        super.setUp()
        engine = BuddyRecommendationEngine(maxRecommendations: 4)
    }

    // MARK: - Basic API

    func testRecommend_returnsAtMostMaxRecommendations() {
        let assessment = makeAssessment(status: .needsAttention)
        let current = makeSnapshot(rhr: 75, hrv: 40)
        let history = makeHistory(days: 21, baseRHR: 62)

        let recs = engine.recommend(
            assessment: assessment,
            current: current,
            history: history
        )
        XCTAssertLessThanOrEqual(recs.count, 4)
    }

    func testRecommend_sortedByPriorityDescending() {
        let assessment = makeAssessment(
            status: .needsAttention,
            stressFlag: true,
            regressionFlag: true
        )
        let current = makeSnapshot(rhr: 75, hrv: 40)
        let history = makeHistory(days: 21, baseRHR: 62)

        let recs = engine.recommend(
            assessment: assessment,
            stressResult: StressResult(score: 80, level: .elevated, description: "High"),
            current: current,
            history: history
        )

        for i in 0..<(recs.count - 1) {
            XCTAssertGreaterThanOrEqual(
                recs[i].priority, recs[i + 1].priority,
                "Recommendations should be sorted by priority descending"
            )
        }
    }

    // MARK: - Consecutive Alert (Critical Priority)

    func testConsecutiveAlert_producesRec() {
        let alert = ConsecutiveElevationAlert(
            consecutiveDays: 4,
            threshold: 71,
            elevatedMean: 76,
            personalMean: 62
        )
        let assessment = makeAssessment(
            status: .needsAttention,
            consecutiveAlert: alert
        )
        let current = makeSnapshot(rhr: 78)

        let recs = engine.recommend(
            assessment: assessment,
            current: current,
            history: makeHistory(days: 21, baseRHR: 62)
        )

        let alertRec = recs.first { $0.source == .consecutiveAlert }
        XCTAssertNotNil(alertRec)
        XCTAssertEqual(alertRec?.priority, .critical)
        XCTAssertEqual(alertRec?.category, .rest)
    }

    // MARK: - Scenario Detection

    func testScenario_highStress_producesBreathRec() {
        let assessment = makeAssessment(
            status: .needsAttention,
            scenario: .highStressDay
        )
        let recs = engine.recommend(
            assessment: assessment,
            current: makeSnapshot(rhr: 70, hrv: 45),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        let scenarioRec = recs.first { $0.source == .scenarioDetection }
        XCTAssertNotNil(scenarioRec)
        XCTAssertEqual(scenarioRec?.category, .breathe)
        XCTAssertEqual(scenarioRec?.priority, .high)
    }

    func testScenario_greatRecovery_producesCelebrateRec() {
        let assessment = makeAssessment(
            status: .improving,
            scenario: .greatRecoveryDay
        )
        let recs = engine.recommend(
            assessment: assessment,
            current: makeSnapshot(rhr: 58, hrv: 70),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        let scenarioRec = recs.first { $0.source == .scenarioDetection }
        XCTAssertNotNil(scenarioRec)
        XCTAssertEqual(scenarioRec?.category, .celebrate)
    }

    func testScenario_overtraining_isCritical() {
        let assessment = makeAssessment(
            status: .needsAttention,
            scenario: .overtrainingSignals
        )
        let recs = engine.recommend(
            assessment: assessment,
            current: makeSnapshot(rhr: 72, hrv: 40),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        let scenarioRec = recs.first { $0.source == .scenarioDetection }
        XCTAssertEqual(scenarioRec?.priority, .critical)
    }

    // MARK: - Stress Engine Integration

    func testElevatedStress_producesHighPriorityRec() {
        let assessment = makeAssessment(status: .needsAttention)
        let stress = StressResult(
            score: 78, level: .elevated,
            description: "Running hot"
        )

        let recs = engine.recommend(
            assessment: assessment,
            stressResult: stress,
            current: makeSnapshot(rhr: 70, hrv: 45),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        let stressRec = recs.first { $0.source == .stressEngine }
        XCTAssertNotNil(stressRec)
        XCTAssertEqual(stressRec?.priority, .high)
    }

    func testRelaxedStress_producesLowPriorityRec() {
        let assessment = makeAssessment(status: .improving)
        let stress = StressResult(
            score: 20, level: .relaxed,
            description: "Relaxed"
        )

        let recs = engine.recommend(
            assessment: assessment,
            stressResult: stress,
            current: makeSnapshot(rhr: 58, hrv: 70),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        let stressRec = recs.first { $0.source == .stressEngine }
        XCTAssertNotNil(stressRec)
        XCTAssertEqual(stressRec?.priority, .low)
    }

    // MARK: - Week-Over-Week

    func testWeekOverWeek_significantElevation_producesHighRec() {
        let wow = WeekOverWeekTrend(
            zScore: 2.5,
            direction: .significantElevation,
            baselineMean: 62,
            baselineStd: 4,
            currentWeekMean: 72
        )
        let assessment = makeAssessment(
            status: .needsAttention,
            weekOverWeekTrend: wow
        )

        let recs = engine.recommend(
            assessment: assessment,
            current: makeSnapshot(rhr: 72),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        let wowRec = recs.first { $0.source == .weekOverWeek }
        XCTAssertNotNil(wowRec)
        XCTAssertEqual(wowRec?.priority, .high)
    }

    func testWeekOverWeek_stable_noRec() {
        let wow = WeekOverWeekTrend(
            zScore: 0.1,
            direction: .stable,
            baselineMean: 62,
            baselineStd: 4,
            currentWeekMean: 62.4
        )
        let assessment = makeAssessment(
            status: .stable,
            weekOverWeekTrend: wow
        )

        let recs = engine.recommend(
            assessment: assessment,
            current: makeSnapshot(rhr: 62),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        let wowRec = recs.first { $0.source == .weekOverWeek }
        XCTAssertNil(wowRec, "Stable week should not produce a week-over-week rec")
    }

    // MARK: - Recovery Trend

    func testRecoveryDeclining_producesMediumRec() {
        let recovery = RecoveryTrend(
            direction: .declining,
            currentWeekMean: 18,
            baselineMean: 28,
            zScore: -1.5,
            dataPoints: 7
        )
        let assessment = makeAssessment(
            status: .needsAttention,
            recoveryTrend: recovery
        )

        let recs = engine.recommend(
            assessment: assessment,
            current: makeSnapshot(rhr: 62, recovery1m: 18),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        let recRec = recs.first { $0.source == .recoveryTrend }
        XCTAssertNotNil(recRec)
        XCTAssertEqual(recRec?.priority, .medium)
    }

    // MARK: - Activity & Sleep Patterns

    func testMissingActivity_producesWalkRec() {
        let assessment = makeAssessment(status: .stable)
        var history = makeHistory(days: 19, baseRHR: 62)
        // Yesterday: no activity
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        history.append(makeSnapshot(
            date: yesterday, rhr: 62,
            workoutMinutes: 0, steps: 500
        ))
        let current = makeSnapshot(
            rhr: 62, workoutMinutes: 0, steps: 800
        )

        let recs = engine.recommend(
            assessment: assessment,
            current: current,
            history: history
        )

        let actRec = recs.first { $0.source == .activityPattern }
        XCTAssertNotNil(actRec)
        XCTAssertEqual(actRec?.category, .walk)
    }

    func testPoorSleep_producesRestRec() {
        let assessment = makeAssessment(status: .stable)
        var history = makeHistory(days: 19, baseRHR: 62)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        history.append(makeSnapshot(
            date: yesterday, rhr: 62,
            workoutMinutes: 30, steps: 8000, sleepHours: 4.5
        ))
        let current = makeSnapshot(
            rhr: 62, workoutMinutes: 30, steps: 8000, sleepHours: 5.0
        )

        let recs = engine.recommend(
            assessment: assessment,
            current: current,
            history: history
        )

        let sleepRec = recs.first { $0.source == .sleepPattern }
        XCTAssertNotNil(sleepRec)
        XCTAssertEqual(sleepRec?.category, .rest)
    }

    // MARK: - Deduplication

    func testDeduplication_keepsHigherPriority() {
        // Both stress engine and stress pattern produce .breathe recs
        let assessment = makeAssessment(
            status: .needsAttention,
            stressFlag: true
        )
        let stress = StressResult(score: 80, level: .elevated, description: "High")

        let recs = engine.recommend(
            assessment: assessment,
            stressResult: stress,
            current: makeSnapshot(rhr: 75, hrv: 35),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        // Should not have two .breathe recs
        let breatheRecs = recs.filter { $0.category == .breathe }
        XCTAssertLessThanOrEqual(breatheRecs.count, 1,
            "Should deduplicate same-category recs")
    }

    // MARK: - Positive Reinforcement

    func testImprovingDay_producesPositiveRec() {
        let assessment = makeAssessment(status: .improving)

        let recs = engine.recommend(
            assessment: assessment,
            current: makeSnapshot(rhr: 58, hrv: 70,
                                  workoutMinutes: 30, steps: 10000),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        let positiveRec = recs.first { $0.source == .general }
        XCTAssertNotNil(positiveRec)
        XCTAssertEqual(positiveRec?.category, .celebrate)
    }

    // MARK: - No Medical Language

    func testRecommendations_noMedicalLanguage() {
        let medicalTerms = [
            "diagnos", "treat", "cure", "prescri", "medic",
            "parasympathetic", "sympathetic nervous", "vagal"
        ]

        // Generate recs for a complex scenario
        let alert = ConsecutiveElevationAlert(
            consecutiveDays: 4, threshold: 71,
            elevatedMean: 76, personalMean: 62
        )
        let wow = WeekOverWeekTrend(
            zScore: 2.0, direction: .significantElevation,
            baselineMean: 62, baselineStd: 4, currentWeekMean: 70
        )
        let recovery = RecoveryTrend(
            direction: .declining, currentWeekMean: 18,
            baselineMean: 28, zScore: -1.5, dataPoints: 7
        )
        let assessment = makeAssessment(
            status: .needsAttention,
            stressFlag: true,
            regressionFlag: true,
            consecutiveAlert: alert,
            weekOverWeekTrend: wow,
            scenario: .overtrainingSignals,
            recoveryTrend: recovery
        )
        let stress = StressResult(score: 85, level: .elevated, description: "High")

        let recs = engine.recommend(
            assessment: assessment,
            stressResult: stress,
            readinessScore: 30,
            current: makeSnapshot(rhr: 78, hrv: 35),
            history: makeHistory(days: 21, baseRHR: 62)
        )

        for rec in recs {
            let combined = (rec.title + " " + rec.message + " " + rec.detail).lowercased()
            for term in medicalTerms {
                XCTAssertFalse(
                    combined.contains(term),
                    "Rec '\(rec.title)' contains medical term '\(term)'"
                )
            }
        }
    }

    // MARK: - Helpers

    private func makeSnapshot(
        date: Date = Date(),
        rhr: Double? = nil,
        hrv: Double? = nil,
        recovery1m: Double? = nil,
        workoutMinutes: Double? = nil,
        steps: Double? = nil,
        sleepHours: Double? = nil
    ) -> HeartSnapshot {
        HeartSnapshot(
            date: date,
            restingHeartRate: rhr,
            hrvSDNN: hrv,
            recoveryHR1m: recovery1m,
            steps: steps,
            workoutMinutes: workoutMinutes,
            sleepHours: sleepHours
        )
    }

    private func makeHistory(
        days: Int,
        baseRHR: Double
    ) -> [HeartSnapshot] {
        (0..<days).map { i in
            let date = Calendar.current.date(
                byAdding: .day, value: -(days - i), to: Date()
            )!
            let v = sin(Double(i) * 0.5) * 1.5
            return makeSnapshot(
                date: date,
                rhr: baseRHR + v,
                hrv: 55 - v,
                workoutMinutes: 30,
                steps: 8000,
                sleepHours: 7.5
            )
        }
    }

    private func makeAssessment(
        status: TrendStatus,
        stressFlag: Bool = false,
        regressionFlag: Bool = false,
        consecutiveAlert: ConsecutiveElevationAlert? = nil,
        weekOverWeekTrend: WeekOverWeekTrend? = nil,
        scenario: CoachingScenario? = nil,
        recoveryTrend: RecoveryTrend? = nil
    ) -> HeartAssessment {
        HeartAssessment(
            status: status,
            confidence: .high,
            anomalyScore: status == .needsAttention ? 2.5 : 0.3,
            regressionFlag: regressionFlag,
            stressFlag: stressFlag,
            cardioScore: 65,
            dailyNudge: DailyNudge(
                category: .walk,
                title: "Test",
                description: "Test nudge",
                icon: "figure.walk"
            ),
            explanation: "Test",
            weekOverWeekTrend: weekOverWeekTrend,
            consecutiveAlert: consecutiveAlert,
            scenario: scenario,
            recoveryTrend: recoveryTrend
        )
    }
}

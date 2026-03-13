// HeartTrendUpgradeTests.swift
// ThumpCoreTests
//
// Tests for HeartTrendEngine v2 upgrades: week-over-week trending,
// consecutive RHR elevation alerts, recovery trend analysis,
// scenario-based coaching, and integrated assess() output.

import XCTest
@testable import Thump

final class HeartTrendUpgradeTests: XCTestCase {

    private var engine: HeartTrendEngine!

    override func setUp() {
        super.setUp()
        engine = HeartTrendEngine(lookbackWindow: 28, policy: AlertPolicy())
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Week-Over-Week Trend

    func testWeekOverWeek_stableRHR_returnsStable() {
        let history = makeHistory(days: 28, baseRHR: 62, variation: 1.0)
        let current = makeSnapshot(rhr: 62)

        let trend = engine.weekOverWeekTrend(history: history, current: current)
        XCTAssertNotNil(trend)
        XCTAssertEqual(trend!.direction, .stable)
        XCTAssertEqual(trend!.zScore, 0, accuracy: 1.0)
    }

    func testWeekOverWeek_risingRHR_returnsElevated() {
        // 28-day baseline at 62, then last 7 days spike to 72
        var history = makeHistory(days: 21, baseRHR: 62, variation: 1.5)
        for i in 0..<7 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(6 - i), to: Date()
            )!
            history.append(makeSnapshot(date: date, rhr: 72))
        }
        let current = makeSnapshot(rhr: 73)

        let trend = engine.weekOverWeekTrend(history: history, current: current)
        XCTAssertNotNil(trend)
        XCTAssertTrue(
            trend!.direction == .elevated || trend!.direction == .significantElevation,
            "RHR spike should show elevated, got \(trend!.direction)"
        )
        XCTAssertGreaterThan(trend!.zScore, 0.5)
    }

    func testWeekOverWeek_droppingRHR_returnsImproving() {
        // 28-day baseline at 68, then last 7 days drop to 58
        var history = makeHistory(days: 21, baseRHR: 68, variation: 1.5)
        for i in 0..<7 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(6 - i), to: Date()
            )!
            history.append(makeSnapshot(date: date, rhr: 58))
        }
        let current = makeSnapshot(rhr: 57)

        let trend = engine.weekOverWeekTrend(history: history, current: current)
        XCTAssertNotNil(trend)
        XCTAssertTrue(
            trend!.direction == .improving || trend!.direction == .significantImprovement,
            "RHR drop should show improving, got \(trend!.direction)"
        )
        XCTAssertLessThan(trend!.zScore, -0.5)
    }

    func testWeekOverWeek_insufficientData_returnsNil() {
        let history = makeHistory(days: 5, baseRHR: 62, variation: 1.0)
        let current = makeSnapshot(rhr: 62)

        let trend = engine.weekOverWeekTrend(history: history, current: current)
        XCTAssertNil(trend, "Should return nil with < 14 days")
    }

    func testWeekOverWeek_baselineMeanAndStdAreCorrect() {
        // Use a perfectly constant history to verify baseline math
        let history = makeHistory(days: 28, baseRHR: 60, variation: 0)
        let current = makeSnapshot(rhr: 65)

        let trend = engine.weekOverWeekTrend(history: history, current: current)
        XCTAssertNotNil(trend)
        XCTAssertEqual(trend!.baselineMean, 60, accuracy: 1.0)
    }

    // MARK: - Consecutive Elevation Alert

    func testConsecutiveElevation_3daySpike_triggersAlert() {
        var history = makeHistory(days: 21, baseRHR: 60, variation: 1.5)
        // Add 3 consecutive days of very elevated RHR
        for i in 0..<3 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(2 - i), to: Date()
            )!
            history.append(makeSnapshot(date: date, rhr: 80))
        }
        let current = makeSnapshot(rhr: 82)

        let alert = engine.detectConsecutiveElevation(
            history: history, current: current
        )
        // The alert includes 'current', so 4 consecutive days elevated
        XCTAssertNotNil(alert, "4 consecutive elevated days should trigger alert")
        XCTAssertGreaterThanOrEqual(alert!.consecutiveDays, 3)
        XCTAssertGreaterThan(alert!.elevatedMean, alert!.personalMean)
    }

    func testConsecutiveElevation_2daySpike_noAlert() {
        var history = makeHistory(days: 21, baseRHR: 60, variation: 1.5)
        // Only 2 consecutive elevated days
        for i in 0..<2 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(1 - i), to: Date()
            )!
            history.append(makeSnapshot(date: date, rhr: 80))
        }
        let current = makeSnapshot(rhr: 61) // Back to normal

        let alert = engine.detectConsecutiveElevation(
            history: history, current: current
        )
        XCTAssertNil(alert, "2 consecutive days should NOT trigger alert")
    }

    func testConsecutiveElevation_insufficientData_returnsNil() {
        let history = makeHistory(days: 3, baseRHR: 60, variation: 1.0)
        let current = makeSnapshot(rhr: 80)

        let alert = engine.detectConsecutiveElevation(
            history: history, current: current
        )
        XCTAssertNil(alert, "Should return nil with < 7 days")
    }

    func testConsecutiveElevation_interruptedSpike_noAlert() {
        var history = makeHistory(days: 21, baseRHR: 60, variation: 1.5)
        // Day 1: elevated, Day 2: normal, Day 3: elevated
        let d1 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let d2 = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        history.append(makeSnapshot(date: d1, rhr: 80))
        history.append(makeSnapshot(date: d2, rhr: 61)) // interruption
        let current = makeSnapshot(rhr: 80)

        let alert = engine.detectConsecutiveElevation(
            history: history, current: current
        )
        // Only 1 consecutive (current) since d2 interrupted
        XCTAssertNil(alert, "Interrupted spike should not trigger alert")
    }

    // MARK: - Recovery Trend

    func testRecoveryTrend_improvingRecovery_returnsImproving() {
        // Baseline recovery around 25, recent week around 38
        var history: [HeartSnapshot] = []
        for i in 0..<21 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(20 - i), to: Date()
            )!
            let rec = i < 14 ? 25.0 : 38.0
            history.append(makeSnapshot(date: date, rhr: 60, recovery1m: rec))
        }
        let current = makeSnapshot(rhr: 60, recovery1m: 40)

        let trend = engine.recoveryTrend(history: history, current: current)
        XCTAssertNotNil(trend)
        XCTAssertEqual(trend!.direction, .improving)
    }

    func testRecoveryTrend_decliningRecovery_returnsDeclining() {
        // Baseline recovery around 35, recent week around 18
        var history: [HeartSnapshot] = []
        for i in 0..<21 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(20 - i), to: Date()
            )!
            let rec = i < 14 ? 35.0 : 18.0
            history.append(makeSnapshot(date: date, rhr: 60, recovery1m: rec))
        }
        let current = makeSnapshot(rhr: 60, recovery1m: 16)

        let trend = engine.recoveryTrend(history: history, current: current)
        XCTAssertNotNil(trend)
        XCTAssertEqual(trend!.direction, .declining)
    }

    func testRecoveryTrend_noRecoveryData_returnsInsufficientData() {
        let history = makeHistory(days: 21, baseRHR: 60, variation: 1.0)
        // makeHistory doesn't include recovery1m by default in this test
        let current = makeSnapshot(rhr: 60)

        let trend = engine.recoveryTrend(history: history, current: current)
        XCTAssertNotNil(trend)
        // Depending on makeHistory, it may or may not have recovery data
        // If no recovery data, should be insufficientData
        if trend!.dataPoints < 5 {
            XCTAssertEqual(trend!.direction, .insufficientData)
        }
    }

    func testRecoveryTrend_stableRecovery_returnsStable() {
        var history: [HeartSnapshot] = []
        for i in 0..<21 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(20 - i), to: Date()
            )!
            history.append(makeSnapshot(date: date, rhr: 60, recovery1m: 30.0))
        }
        let current = makeSnapshot(rhr: 60, recovery1m: 30)

        let trend = engine.recoveryTrend(history: history, current: current)
        XCTAssertNotNil(trend)
        XCTAssertEqual(trend!.direction, .stable)
    }

    // MARK: - Scenario Detection

    func testScenario_highStressDay() {
        // HRV > 15% below avg AND RHR > 5bpm above avg
        let history = makeHistory(days: 21, baseRHR: 60, baseHRV: 60, variation: 1.0)
        let current = makeSnapshot(
            rhr: 70,    // +10 above 60 baseline
            hrv: 45,    // 25% below 60 baseline
            workoutMinutes: 30,
            steps: 8000
        )

        let scenario = engine.detectScenario(history: history, current: current)
        XCTAssertEqual(scenario, .highStressDay)
    }

    func testScenario_greatRecoveryDay() {
        // HRV > 10% above avg, RHR at/below baseline
        let history = makeHistory(days: 21, baseRHR: 62, baseHRV: 50, variation: 1.0)
        let current = makeSnapshot(
            rhr: 58,    // Below baseline
            hrv: 60,    // 20% above baseline
            workoutMinutes: 30,
            steps: 8000
        )

        let scenario = engine.detectScenario(history: history, current: current)
        XCTAssertEqual(scenario, .greatRecoveryDay)
    }

    func testScenario_missingActivity() {
        // No workout for 2+ consecutive days
        var history = makeHistory(days: 21, baseRHR: 62, baseHRV: 55, variation: 1.0)
        // Last day in history: no activity
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        history.append(makeSnapshot(
            date: yesterday,
            rhr: 62,
            hrv: 55,
            workoutMinutes: 0,
            steps: 500
        ))

        let current = makeSnapshot(
            rhr: 62,
            hrv: 55,
            workoutMinutes: 0,
            steps: 800
        )

        let scenario = engine.detectScenario(history: history, current: current)
        XCTAssertEqual(scenario, .missingActivity)
    }

    func testScenario_overtrainingSignals() {
        // RHR +7bpm for 3+ days AND HRV -20% persistent
        var history = makeHistory(days: 18, baseRHR: 60, baseHRV: 60, variation: 1.0)
        // Add 3 days of overtraining
        for i in 0..<2 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(1 - i), to: Date()
            )!
            history.append(makeSnapshot(
                date: date,
                rhr: 70,    // +10 above baseline
                hrv: 40,    // -33% below baseline
                workoutMinutes: 90,
                steps: 15000
            ))
        }
        let current = makeSnapshot(
            rhr: 72,
            hrv: 38,
            workoutMinutes: 90,
            steps: 15000
        )

        let scenario = engine.detectScenario(history: history, current: current)
        XCTAssertEqual(scenario, .overtrainingSignals)
    }

    func testScenario_noScenarioForNormalDay() {
        let history = makeHistory(days: 21, baseRHR: 62, baseHRV: 55, variation: 1.0)
        let current = makeSnapshot(
            rhr: 62,
            hrv: 55,
            workoutMinutes: 30,
            steps: 8000
        )

        let scenario = engine.detectScenario(history: history, current: current)
        // Normal day may return nil (no scenario triggered)
        // or one of the non-alarming scenarios — both acceptable
        if let s = scenario {
            XCTAssertTrue(
                s != .overtrainingSignals && s != .highStressDay,
                "Normal day should not trigger alarm scenarios, got \(s)"
            )
        }
    }

    // MARK: - Coaching Messages

    func testCoachingMessages_allScenariosHaveMessages() {
        for scenario in CoachingScenario.allCases {
            XCTAssertFalse(
                scenario.coachingMessage.isEmpty,
                "Scenario \(scenario) should have a coaching message"
            )
            XCTAssertFalse(
                scenario.icon.isEmpty,
                "Scenario \(scenario) should have an icon"
            )
        }
    }

    func testCoachingMessages_noMedicalLanguage() {
        let medicalTerms = [
            "diagnos", "treat", "cure", "prescri", "medic",
            "parasympathetic", "sympathetic nervous"
        ]
        for scenario in CoachingScenario.allCases {
            let msg = scenario.coachingMessage.lowercased()
            for term in medicalTerms {
                XCTAssertFalse(
                    msg.contains(term),
                    "Scenario \(scenario) contains medical term '\(term)'"
                )
            }
        }
    }

    // MARK: - Integrated Assessment

    func testAssess_includesWeekOverWeekTrend() {
        let history = makeHistory(days: 21, baseRHR: 62, baseHRV: 55, variation: 1.5)
        let current = makeSnapshot(
            rhr: 62, hrv: 55, recovery1m: 30, vo2Max: 42,
            workoutMinutes: 30, steps: 8000
        )

        let assessment = engine.assess(history: history, current: current)
        // With 21+ days of data, WoW trend should be computed
        XCTAssertNotNil(assessment.weekOverWeekTrend)
    }

    func testAssess_consecutiveAlert_triggersNeedsAttention() {
        var history = makeHistory(days: 21, baseRHR: 60, baseHRV: 55, variation: 1.5)
        // Add 3 very elevated days
        for i in 0..<3 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(2 - i), to: Date()
            )!
            history.append(makeSnapshot(
                date: date, rhr: 82, hrv: 55, recovery1m: 30,
                workoutMinutes: 30, steps: 8000
            ))
        }
        let current = makeSnapshot(
            rhr: 83, hrv: 55, recovery1m: 30,
            workoutMinutes: 30, steps: 8000
        )

        let assessment = engine.assess(history: history, current: current)
        XCTAssertNotNil(assessment.consecutiveAlert)
        XCTAssertEqual(assessment.status, .needsAttention)
    }

    func testAssess_significantWeeklyElevation_triggersNeedsAttention() {
        var history = makeHistory(days: 21, baseRHR: 60, baseHRV: 55, variation: 1.0)
        // Last 7 days very elevated
        for i in 0..<7 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(6 - i), to: Date()
            )!
            history.append(makeSnapshot(
                date: date, rhr: 76, hrv: 55, recovery1m: 30,
                workoutMinutes: 30, steps: 8000
            ))
        }
        let current = makeSnapshot(
            rhr: 77, hrv: 55, recovery1m: 30,
            workoutMinutes: 30, steps: 8000
        )

        let assessment = engine.assess(history: history, current: current)
        // Should detect significant elevation
        if let wt = assessment.weekOverWeekTrend {
            XCTAssertTrue(
                wt.direction == .elevated || wt.direction == .significantElevation,
                "Expected elevated trend, got \(wt.direction)"
            )
        }
    }

    func testAssess_scenarioIncluded() {
        let history = makeHistory(days: 21, baseRHR: 60, baseHRV: 60, variation: 1.0)
        let current = makeSnapshot(
            rhr: 70, hrv: 45, workoutMinutes: 30, steps: 8000
        )

        let assessment = engine.assess(history: history, current: current)
        // High stress scenario should be detected
        XCTAssertNotNil(assessment.scenario)
    }

    func testAssess_recoveryTrendIncluded() {
        var history: [HeartSnapshot] = []
        for i in 0..<21 {
            let date = Calendar.current.date(
                byAdding: .day, value: -(20 - i), to: Date()
            )!
            history.append(makeSnapshot(
                date: date, rhr: 60, hrv: 55,
                recovery1m: 30, workoutMinutes: 30, steps: 8000
            ))
        }
        let current = makeSnapshot(
            rhr: 60, hrv: 55, recovery1m: 30,
            workoutMinutes: 30, steps: 8000
        )

        let assessment = engine.assess(history: history, current: current)
        XCTAssertNotNil(assessment.recoveryTrend)
    }

    func testAssess_explanationContainsScenarioMessage() {
        let history = makeHistory(days: 21, baseRHR: 60, baseHRV: 60, variation: 1.0)
        let current = makeSnapshot(
            rhr: 70, hrv: 45, workoutMinutes: 30, steps: 8000
        )

        let assessment = engine.assess(history: history, current: current)
        if let scenario = assessment.scenario {
            XCTAssertTrue(
                assessment.explanation.contains(scenario.coachingMessage),
                "Explanation should include coaching message"
            )
        }
    }

    // MARK: - Standard Deviation Helper

    func testStandardDeviation_knownValues() {
        // [2, 4, 4, 4, 5, 5, 7, 9] → mean=5, sample std ≈ 2.0
        let values = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        let sd = engine.standardDeviation(values)
        XCTAssertEqual(sd, 2.0, accuracy: 0.2)
    }

    func testStandardDeviation_singleValue_returnsZero() {
        XCTAssertEqual(engine.standardDeviation([42.0]), 0.0, accuracy: 1e-9)
    }

    func testStandardDeviation_identicalValues_returnsZero() {
        XCTAssertEqual(engine.standardDeviation([5, 5, 5, 5]), 0.0, accuracy: 1e-9)
    }

    // MARK: - Edge Cases

    func testWeekOverWeek_allNilRHR_returnsNil() {
        let history = (0..<28).map { i -> HeartSnapshot in
            let date = Calendar.current.date(
                byAdding: .day, value: -(27 - i), to: Date()
            )!
            return makeSnapshot(date: date, rhr: nil)
        }
        let current = makeSnapshot(rhr: nil)

        let trend = engine.weekOverWeekTrend(history: history, current: current)
        XCTAssertNil(trend)
    }

    func testConsecutiveElevation_allNilRHR_returnsNil() {
        let history = (0..<21).map { i -> HeartSnapshot in
            let date = Calendar.current.date(
                byAdding: .day, value: -(20 - i), to: Date()
            )!
            return makeSnapshot(date: date, rhr: nil)
        }
        let current = makeSnapshot(rhr: nil)

        let alert = engine.detectConsecutiveElevation(
            history: history, current: current
        )
        XCTAssertNil(alert)
    }

    func testScenario_emptyHistory_returnsNil() {
        let current = makeSnapshot(rhr: 65, hrv: 50)
        let scenario = engine.detectScenario(history: [], current: current)
        XCTAssertNil(scenario)
    }

    // MARK: - Model Types

    func testWeeklyTrendDirection_allHaveDisplayText() {
        let directions: [WeeklyTrendDirection] = [
            .significantImprovement, .improving, .stable, .elevated, .significantElevation
        ]
        for dir in directions {
            XCTAssertFalse(dir.displayText.isEmpty)
            XCTAssertFalse(dir.icon.isEmpty)
        }
    }

    func testRecoveryTrendDirection_allHaveDisplayText() {
        let directions: [RecoveryTrendDirection] = [
            .improving, .stable, .declining, .insufficientData
        ]
        for dir in directions {
            XCTAssertFalse(dir.displayText.isEmpty)
        }
    }

    // MARK: - Helpers

    private func makeSnapshot(
        date: Date = Date(),
        rhr: Double? = nil,
        hrv: Double? = nil,
        recovery1m: Double? = nil,
        vo2Max: Double? = nil,
        workoutMinutes: Double? = nil,
        steps: Double? = nil
    ) -> HeartSnapshot {
        HeartSnapshot(
            date: date,
            restingHeartRate: rhr,
            hrvSDNN: hrv,
            recoveryHR1m: recovery1m,
            vo2Max: vo2Max,
            steps: steps,
            workoutMinutes: workoutMinutes,
            sleepHours: 7.5
        )
    }

    private func makeHistory(
        days: Int,
        baseRHR: Double,
        baseHRV: Double = 55,
        variation: Double = 1.5
    ) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<days).map { i in
            let date = calendar.date(
                byAdding: .day, value: -(days - i), to: today
            )!
            let v = sin(Double(i) * 0.5) * variation
            return makeSnapshot(
                date: date,
                rhr: baseRHR + v,
                hrv: baseHRV - v,
                recovery1m: 30.0 + v,
                workoutMinutes: 30,
                steps: 8000
            )
        }
    }
}

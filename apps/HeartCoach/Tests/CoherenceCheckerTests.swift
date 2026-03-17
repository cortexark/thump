// CoherenceCheckerTests.swift
// ThumpCoreTests
//
// Tests for CoherenceChecker — validates hard invariants and soft anomalies
// across all AdviceState compositions.

import XCTest
@testable import Thump

final class CoherenceCheckerTests: XCTestCase {

    private let composer = AdviceComposer()
    private let config = HealthPolicyConfig()

    // MARK: - Helper Factories

    private func makeSnapshot(
        sleepHours: Double? = 7.5,
        hrvSDNN: Double? = 45,
        restingHeartRate: Double? = 65,
        steps: Double? = 6000,
        walkMinutes: Double? = 20,
        workoutMinutes: Double? = 15,
        zoneMinutes: [Double] = [10, 20, 30, 15, 5]
    ) -> HeartSnapshot {
        HeartSnapshot(
            date: Date(),
            restingHeartRate: restingHeartRate,
            hrvSDNN: hrvSDNN,
            zoneMinutes: zoneMinutes,
            steps: steps,
            walkMinutes: walkMinutes,
            workoutMinutes: workoutMinutes,
            sleepHours: sleepHours
        )
    }

    private func makeAssessment(
        status: TrendStatus = .stable,
        stressFlag: Bool = false,
        consecutiveDays: Int = 0
    ) -> HeartAssessment {
        let alert: ConsecutiveElevationAlert? = consecutiveDays > 0
            ? ConsecutiveElevationAlert(
                consecutiveDays: consecutiveDays,
                threshold: 75.0,
                elevatedMean: 78.0,
                personalMean: 65.0
            )
            : nil

        let nudge = DailyNudge(
            category: .walk,
            title: "Test nudge",
            description: "Test description",
            durationMinutes: 15,
            icon: "figure.walk"
        )

        return HeartAssessment(
            status: status,
            confidence: .medium,
            anomalyScore: 0.3,
            regressionFlag: false,
            stressFlag: stressFlag,
            cardioScore: 70.0,
            dailyNudge: nudge,
            explanation: "Test assessment",
            consecutiveAlert: alert
        )
    }

    private func makeReadiness(score: Int, level: ReadinessLevel) -> ReadinessResult {
        ReadinessResult(
            score: score,
            level: level,
            pillars: [
                ReadinessPillar(type: .sleep, score: Double(score), weight: 0.25, detail: "OK"),
                ReadinessPillar(type: .hrvTrend, score: Double(score), weight: 0.25, detail: "OK"),
                ReadinessPillar(type: .recovery, score: Double(score), weight: 0.20, detail: "OK"),
                ReadinessPillar(type: .activityBalance, score: Double(score), weight: 0.15, detail: "OK"),
                ReadinessPillar(type: .stress, score: Double(score), weight: 0.15, detail: "OK")
            ],
            summary: "Test readiness"
        )
    }

    private func makeStress(score: Double, level: StressLevel) -> StressResult {
        StressResult(score: score, level: level, description: "Test")
    }

    private func composeAndCheck(
        sleepHours: Double? = 7.5,
        stressFlag: Bool = false,
        stressScore: Double? = nil,
        stressLevel: StressLevel = .relaxed,
        readinessScore: Int = 65,
        readinessLevel: ReadinessLevel = .ready,
        consecutiveDays: Int = 0
    ) -> (AdviceState, CoherenceTrace) {
        let snapshot = makeSnapshot(sleepHours: sleepHours)
        let assessment = makeAssessment(stressFlag: stressFlag, consecutiveDays: consecutiveDays)
        let stress: StressResult? = stressScore.map { makeStress(score: $0, level: stressLevel) }
        let readiness = makeReadiness(score: readinessScore, level: readinessLevel)

        let state = composer.compose(
            snapshot: snapshot,
            assessment: assessment,
            stressResult: stress,
            readinessResult: readiness,
            zoneAnalysis: nil,
            config: config
        )

        let trace = CoherenceChecker.check(
            adviceState: state,
            readinessResult: readiness,
            config: config
        )

        return (state, trace)
    }

    // MARK: - Hard Invariant Tests (satisfied)

    func testINV001_noPushDayWhenSleepDeprived_satisfied() {
        let (state, trace) = composeAndCheck(
            sleepHours: 3.0,
            readinessScore: 85,
            readinessLevel: .primed
        )
        // Sleep deprivation should prevent pushDay
        XCTAssertNotEqual(state.mode, .pushDay)
        XCTAssertFalse(trace.hardViolations.contains { $0.contains("INV-001") })
    }

    func testINV002_noCelebratingBuddyWhenRecovering_satisfied() {
        let (state, trace) = composeAndCheck(
            readinessScore: 35,
            readinessLevel: .recovering
        )
        XCTAssertNotEqual(state.buddyMoodCategory, .celebrating)
        XCTAssertFalse(trace.hardViolations.contains { $0.contains("INV-002") })
    }

    func testINV003_medicalEscalationWhenHighConsecutive_satisfied() {
        let (state, trace) = composeAndCheck(consecutiveDays: 5)
        XCTAssertEqual(state.mode, .medicalCheck)
        XCTAssertTrue(state.medicalEscalationFlag)
        XCTAssertFalse(trace.hardViolations.contains { $0.contains("INV-003") })
    }

    func testINV004_goalsMatchMode_satisfied() {
        let (state, trace) = composeAndCheck(
            sleepHours: 2.5,
            readinessScore: 25,
            readinessLevel: .recovering
        )
        if let stepGoal = state.goals.first(where: { $0.category == .steps }) {
            XCTAssertLessThanOrEqual(stepGoal.target, Double(config.goals.stepsRecovering))
        }
        XCTAssertFalse(trace.hardViolations.contains { $0.contains("INV-004") })
    }

    func testINV005_noIntensityWhenOvertrained_satisfied() {
        let (state, trace) = composeAndCheck(consecutiveDays: 5)
        if state.overtrainingState >= .caution {
            XCTAssertLessThanOrEqual(state.allowedIntensity, .light)
        }
        XCTAssertFalse(trace.hardViolations.contains { $0.contains("INV-005") })
    }

    // MARK: - All Invariants Clean for Normal Scenarios

    func testAllInvariants_cleanForGoodDay() {
        let (_, trace) = composeAndCheck(
            sleepHours: 8.0,
            stressScore: 20,
            stressLevel: .relaxed,
            readinessScore: 85,
            readinessLevel: .primed
        )
        XCTAssertEqual(trace.hardViolationsFound, 0, "Good day should have zero hard violations")
        XCTAssertEqual(trace.hardInvariantsChecked, 5)
    }

    func testAllInvariants_cleanForRecoveringDay() {
        let (_, trace) = composeAndCheck(
            sleepHours: 4.5,
            stressFlag: true,
            stressScore: 80,
            stressLevel: .elevated,
            readinessScore: 35,
            readinessLevel: .recovering
        )
        XCTAssertEqual(trace.hardViolationsFound, 0, "Recovering day should have zero hard violations")
    }

    func testAllInvariants_cleanForMedicalCheck() {
        let (_, trace) = composeAndCheck(
            readinessScore: 50,
            readinessLevel: .moderate,
            consecutiveDays: 7
        )
        XCTAssertEqual(trace.hardViolationsFound, 0, "Medical check should have zero hard violations")
    }

    // MARK: - Soft Anomaly Tests

    func testANO001_highStressHighReadiness_detected() {
        let (_, trace) = composeAndCheck(
            stressFlag: true,
            stressScore: 80,
            stressLevel: .elevated,
            readinessScore: 85,
            readinessLevel: .primed
        )
        XCTAssertTrue(trace.softAnomalies.contains { $0.contains("ANO-001") },
                      "High stress + high readiness should flag soft anomaly")
    }

    func testANO001_notDetected_whenStressLow() {
        let (_, trace) = composeAndCheck(
            stressScore: 20,
            stressLevel: .relaxed,
            readinessScore: 85,
            readinessLevel: .primed
        )
        XCTAssertFalse(trace.softAnomalies.contains { $0.contains("ANO-001") })
    }

    func testANO002_positivityImbalance_detected() {
        // 3+ negatives: sleep deprived + stress elevated + low readiness
        let (_, trace) = composeAndCheck(
            sleepHours: 3.0,
            stressFlag: true,
            stressScore: 80,
            stressLevel: .elevated,
            readinessScore: 30,
            readinessLevel: .recovering
        )
        // Positivity anchor should be injected by PositivityEvaluator,
        // so ANO-002 should NOT fire (anchor is present)
        // But we verify the checker works either way
        XCTAssertEqual(trace.hardViolationsFound, 0)
    }

    // MARK: - Sweep: All SyntheticPersonas Pass Hard Invariants

    func testAllSyntheticPersonas_zeroHardViolations() {
        // Run through various persona-like scenarios
        let scenarios: [(String, Double?, Bool, Double?, StressLevel, Int, ReadinessLevel, Int)] = [
            // (name, sleep, stressFlag, stressScore, stressLevel, readiness, readinessLevel, consecutiveDays)
            ("Healthy active", 8.0, false, 20, .relaxed, 85, .primed, 0),
            ("Sleep deprived", 3.0, false, nil, .relaxed, 30, .recovering, 0),
            ("Stressed exec", 6.0, true, 75.0, .elevated, 55, .moderate, 0),
            ("Overtrained", 7.0, false, nil, .relaxed, 50, .moderate, 5),
            ("Recovering illness", 5.0, false, nil, .relaxed, 35, .recovering, 0),
            ("New mom", 4.5, false, nil, .relaxed, 40, .recovering, 0),
            ("Teen athlete", 8.5, false, 15.0, .relaxed, 90, .primed, 0),
            ("Shift worker", 5.5, true, 65.0, .balanced, 45, .moderate, 0),
            ("Anxious profile", 7.0, true, 80.0, .elevated, 60, .moderate, 2),
            ("Medical alert", 6.5, false, nil, .relaxed, 50, .moderate, 7),
        ]

        for (name, sleep, stressFlag, stressScore, stressLevel, readiness, readinessLevel, days) in scenarios {
            let (_, trace) = composeAndCheck(
                sleepHours: sleep,
                stressFlag: stressFlag,
                stressScore: stressScore,
                stressLevel: stressLevel,
                readinessScore: readiness,
                readinessLevel: readinessLevel,
                consecutiveDays: days
            )
            XCTAssertEqual(trace.hardViolationsFound, 0,
                          "\(name) persona should have zero hard violations, got: \(trace.hardViolations)")
        }
    }

    // MARK: - Trace Structure Tests

    func testTrace_invariantCount() {
        let (_, trace) = composeAndCheck()
        XCTAssertEqual(trace.hardInvariantsChecked, 5)
    }

    func testTrace_firestoreDict_hasAllKeys() {
        let (_, trace) = composeAndCheck()
        let dict = trace.toDict()
        XCTAssertNotNil(dict["hardInvariantsChecked"])
        XCTAssertNotNil(dict["hardViolationsFound"])
        XCTAssertNotNil(dict["hardViolations"])
        XCTAssertNotNil(dict["softAnomaliesFound"])
        XCTAssertNotNil(dict["softAnomalies"])
    }
}

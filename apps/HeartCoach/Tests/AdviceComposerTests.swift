// AdviceComposerTests.swift
// ThumpCoreTests
//
// Tests for AdviceComposer — the unified decision logic orchestrator.
// Validates mode selection, evaluator outputs, coherence invariants,
// and behavior parity with existing view helpers.

import XCTest
@testable import Thump

final class AdviceComposerTests: XCTestCase {

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

    // MARK: - 1. Mode Selection Tests

    func testMode_pushDay_whenPrimedAndRelaxed() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 8.0),
            assessment: makeAssessment(status: .improving, stressFlag: false),
            stressResult: makeStress(score: 20, level: .relaxed),
            readinessResult: makeReadiness(score: 85, level: .primed),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.mode, .pushDay)
    }

    func testMode_moderateMove_whenReadyButStressed() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(stressFlag: true),
            stressResult: makeStress(score: 75, level: .elevated),
            readinessResult: makeReadiness(score: 75, level: .ready),
            zoneAnalysis: nil,
            config: config
        )
        // Elevated stress prevents pushDay even with high readiness
        XCTAssertNotEqual(state.mode, .pushDay)
    }

    func testMode_lightRecovery_whenLowReadiness() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 5.5),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 40, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.mode, .lightRecovery)
    }

    func testMode_fullRest_whenSevereSleepDeprivation() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 2.5),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 30, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.mode, .fullRest)
    }

    func testMode_fullRest_whenElevatedStressAndLowReadiness() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(stressFlag: true),
            stressResult: makeStress(score: 80, level: .elevated),
            readinessResult: makeReadiness(score: 35, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.mode, .fullRest)
    }

    func testMode_medicalCheck_whenHighConsecutiveAlert() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(consecutiveDays: 5),
            stressResult: nil,
            readinessResult: makeReadiness(score: 50, level: .moderate),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.mode, .medicalCheck)
    }

    // MARK: - 2. Hero Category Tests

    func testHeroCategory_matchesMode() {
        let cases: [(GuidanceMode, HeroCategory)] = [
            (.pushDay, .celebrate),
            (.moderateMove, .encourage),
            (.lightRecovery, .caution),
            (.fullRest, .rest),
            (.medicalCheck, .medical)
        ]

        for (mode, expectedCategory) in cases {
            let readiness: ReadinessResult
            let assessment: HeartAssessment
            let stress: StressResult?

            switch mode {
            case .pushDay:
                readiness = makeReadiness(score: 85, level: .primed)
                assessment = makeAssessment(status: .improving)
                stress = makeStress(score: 20, level: .relaxed)
            case .moderateMove:
                readiness = makeReadiness(score: 55, level: .moderate)
                assessment = makeAssessment()
                stress = nil
            case .lightRecovery:
                readiness = makeReadiness(score: 40, level: .recovering)
                assessment = makeAssessment()
                stress = nil
            case .fullRest:
                readiness = makeReadiness(score: 30, level: .recovering)
                assessment = makeAssessment(stressFlag: true)
                stress = makeStress(score: 80, level: .elevated)
            case .medicalCheck:
                readiness = makeReadiness(score: 50, level: .moderate)
                assessment = makeAssessment(consecutiveDays: 5)
                stress = nil
            }

            let state = composer.compose(
                snapshot: makeSnapshot(),
                assessment: assessment,
                stressResult: stress,
                readinessResult: readiness,
                zoneAnalysis: nil,
                config: config
            )
            XCTAssertEqual(state.heroCategory, expectedCategory,
                           "Hero category for mode \(mode) should be \(expectedCategory)")
        }
    }

    // MARK: - 3. Buddy Mood Tests

    func testBuddyMood_celebrating_whenPushDay() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(status: .improving),
            stressResult: makeStress(score: 20, level: .relaxed),
            readinessResult: makeReadiness(score: 85, level: .primed),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.buddyMoodCategory, .celebrating)
    }

    func testBuddyMood_resting_whenFullRest() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 2.5),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 25, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.buddyMoodCategory, .resting)
    }

    // MARK: - 4. Sleep Deprivation Flag Tests

    func testSleepDeprivation_flagged_whenSeverelySleepDeprived() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 2.5),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 30, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertTrue(state.sleepDeprivationFlag)
    }

    func testSleepDeprivation_notFlagged_whenGoodSleep() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 8.0),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 75, level: .ready),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertFalse(state.sleepDeprivationFlag)
    }

    // MARK: - 5. Overtraining State Tests

    func testOvertraining_none_whenNoConsecutiveAlerts() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(consecutiveDays: 0),
            stressResult: nil,
            readinessResult: makeReadiness(score: 70, level: .ready),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.overtrainingState, .none)
    }

    func testOvertraining_watch_at3Days() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(consecutiveDays: 3),
            stressResult: nil,
            readinessResult: makeReadiness(score: 50, level: .moderate),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.overtrainingState, .watch)
    }

    func testOvertraining_monotonic() {
        let dayCounts = [0, 2, 3, 5, 7, 10, 20]
        var previousState: OvertrainingState = .none

        for days in dayCounts {
            let state = composer.compose(
                snapshot: makeSnapshot(),
                assessment: makeAssessment(consecutiveDays: days),
                stressResult: nil,
                readinessResult: makeReadiness(score: 50, level: .moderate),
                zoneAnalysis: nil,
                config: config
            )
            XCTAssertGreaterThanOrEqual(state.overtrainingState, previousState,
                                        "Overtraining state should be monotonically increasing at \(days) days")
            previousState = state.overtrainingState
        }
    }

    // MARK: - 6. Goal Tests

    func testGoals_stepTargetHigher_whenPrimed() {
        let primedState = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(),
            stressResult: makeStress(score: 20, level: .relaxed),
            readinessResult: makeReadiness(score: 85, level: .primed),
            zoneAnalysis: nil,
            config: config
        )

        let recoveringState = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 35, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )

        let primedSteps = primedState.goals.first { $0.category == .steps }?.target ?? 0
        let recoveringSteps = recoveringState.goals.first { $0.category == .steps }?.target ?? 0
        XCTAssertGreaterThan(primedSteps, recoveringSteps,
                            "Primed step target should be higher than recovering")
    }

    func testGoals_includesSleep_whenSleepDataAvailable() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 7.0),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 65, level: .ready),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertTrue(state.goals.contains { $0.category == .sleep })
    }

    func testGoals_excludesSleep_whenNoSleepData() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: nil),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 65, level: .ready),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertFalse(state.goals.contains { $0.category == .sleep })
    }

    // MARK: - 7. Intensity Band Tests

    func testIntensity_rest_whenFullRest() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 2.5),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 25, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.allowedIntensity, .rest)
    }

    func testIntensity_light_whenOvertrained() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(consecutiveDays: 5),
            stressResult: nil,
            readinessResult: makeReadiness(score: 50, level: .moderate),
            zoneAnalysis: nil,
            config: config
        )
        // Medical check mode due to 5 days + caution overtraining caps at light
        XCTAssertLessThanOrEqual(state.allowedIntensity, .light)
    }

    func testIntensity_full_whenPushDay() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(status: .improving),
            stressResult: makeStress(score: 20, level: .relaxed),
            readinessResult: makeReadiness(score: 85, level: .primed),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertEqual(state.allowedIntensity, .full)
    }

    // MARK: - 8. Positivity Anchor Tests

    func testPositivity_noAnchor_whenOneNegative() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 7.5),
            assessment: makeAssessment(stressFlag: true),
            stressResult: makeStress(score: 75, level: .elevated),
            readinessResult: makeReadiness(score: 65, level: .ready),
            zoneAnalysis: nil,
            config: config
        )
        // Only 1 negative (stress) — no anchor needed
        XCTAssertNil(state.positivityAnchorID)
    }

    func testPositivity_anchorInjected_whenTwoNegatives() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 4.5),
            assessment: makeAssessment(stressFlag: true),
            stressResult: makeStress(score: 80, level: .elevated),
            readinessResult: makeReadiness(score: 35, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )
        // Multiple negatives: sleep deprived + stress elevated + low readiness
        XCTAssertNotNil(state.positivityAnchorID)
    }

    // MARK: - 9. Smart Actions Tests

    func testSmartActions_includesBreathing_whenStressed() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(stressFlag: true),
            stressResult: makeStress(score: 75, level: .elevated),
            readinessResult: makeReadiness(score: 55, level: .moderate),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertTrue(state.smartActions.contains(.breathingSession))
    }

    func testSmartActions_includesBedtimeWindDown_whenSleepDeprived() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 4.0),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 40, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertTrue(state.smartActions.contains(where: {
            if case .bedtimeWindDown = $0 { return true }
            return false
        }))
    }

    // MARK: - 10. Hard Coherence Invariants

    /// INV-001: No pushDay when sleep-deprived
    func testInvariant_noPushDayWhenSleepDeprived() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 3.5),
            assessment: makeAssessment(status: .improving),
            stressResult: makeStress(score: 20, level: .relaxed),
            readinessResult: makeReadiness(score: 85, level: .primed),
            zoneAnalysis: nil,
            config: config
        )
        if state.sleepDeprivationFlag {
            XCTAssertNotEqual(state.mode, .pushDay,
                             "INV-001: No pushDay when sleep-deprived")
        }
    }

    /// INV-002: No celebrating buddy when recovering
    func testInvariant_noCelebratingBuddyWhenRecovering() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 4.0),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 35, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )
        if state.mode == .lightRecovery || state.mode == .fullRest {
            XCTAssertNotEqual(state.buddyMoodCategory, .celebrating,
                             "INV-002: No celebrating buddy when recovering")
        }
    }

    /// INV-003: Medical escalation when consecutiveAlert >= 5
    func testInvariant_medicalEscalationWhenHighConsecutive() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(consecutiveDays: 5),
            stressResult: nil,
            readinessResult: makeReadiness(score: 50, level: .moderate),
            zoneAnalysis: nil,
            config: config
        )
        XCTAssertTrue(state.medicalEscalationFlag,
                      "INV-003: Medical escalation flag should be set at 5+ consecutive days")
        XCTAssertEqual(state.mode, .medicalCheck,
                       "INV-003: Mode should be medicalCheck at 5+ consecutive days")
    }

    /// INV-004: Goals match mode — fullRest step target <= recovering target
    func testInvariant_goalsMatchMode() {
        let state = composer.compose(
            snapshot: makeSnapshot(sleepHours: 2.5),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 25, level: .recovering),
            zoneAnalysis: nil,
            config: config
        )
        if state.mode == .fullRest || state.mode == .medicalCheck {
            let stepTarget = state.goals.first { $0.category == .steps }?.target ?? 0
            XCTAssertLessThanOrEqual(stepTarget, Double(config.goals.stepsRecovering),
                                    "INV-004: Full rest step target should not exceed recovering target")
        }
    }

    /// INV-005: No high intensity when overtraining >= caution
    func testInvariant_noIntensityWhenOvertrained() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(consecutiveDays: 5),
            stressResult: nil,
            readinessResult: makeReadiness(score: 50, level: .moderate),
            zoneAnalysis: nil,
            config: config
        )
        if state.overtrainingState >= .caution {
            XCTAssertLessThanOrEqual(state.allowedIntensity, .light,
                                    "INV-005: Intensity should be <= light when overtraining >= caution")
        }
    }

    // MARK: - 11. AdvicePresenter Tests

    func testPresenter_heroMessage_nonEmpty() {
        let state = composer.compose(
            snapshot: makeSnapshot(),
            assessment: makeAssessment(),
            stressResult: nil,
            readinessResult: makeReadiness(score: 65, level: .ready),
            zoneAnalysis: nil,
            config: config
        )
        let message = AdvicePresenter.heroMessage(for: state, snapshot: makeSnapshot())
        XCTAssertFalse(message.isEmpty)
    }

    func testPresenter_stressGuidance_allLevels() {
        for level in [StressGuidanceLevel.relaxed, .balanced, .elevated] {
            let spec = AdvicePresenter.stressGuidance(for: level)
            XCTAssertFalse(spec.headline.isEmpty)
            XCTAssertFalse(spec.detail.isEmpty)
            XCTAssertFalse(spec.icon.isEmpty)
            XCTAssertFalse(spec.actions.isEmpty)
        }
    }

    func testPresenter_goalNudgeText_allIDs() {
        let ids = ["steps_achieved", "steps_start", "steps_almost",
                   "active_achieved", "active_start", "active_almost",
                   "sleep_achieved", "sleep_wind_down", "sleep_almost",
                   "zone_achieved", "zone_more"]

        for id in ids {
            let goal = GoalSpec(category: .steps, target: 8000, current: 3000, nudgeTextID: id, label: "Test")
            let text = AdvicePresenter.goalNudgeText(for: goal)
            XCTAssertFalse(text.isEmpty, "Nudge text for '\(id)' should not be empty")
        }
    }

    func testPresenter_positivityAnchor_allIDs() {
        let ids = ["positivity_recovery_progress",
                   "positivity_stress_awareness",
                   "positivity_general_encouragement"]
        for id in ids {
            let text = AdvicePresenter.positivityAnchor(for: id)
            XCTAssertNotNil(text, "Positivity anchor for '\(id)' should produce text")
        }
    }
}

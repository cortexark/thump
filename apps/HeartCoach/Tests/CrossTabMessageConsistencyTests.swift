// CrossTabMessageConsistencyTests.swift
// ThumpTests
//
// Regression coverage for contradictory guidance across Dashboard and Stress
// surfaces. These tests protect against "push hard" messaging when readiness
// is still low due to poor sleep or recovery debt.

import XCTest
@testable import Thump

final class CrossTabMessageConsistencyTests: XCTestCase {

    func testStressGuidance_relaxedButRecoveringReadiness_avoidsPerformanceActions() {
        let spec = AdvicePresenter.stressGuidance(for: .relaxed, readinessLevel: .recovering)

        XCTAssertFalse(spec.actions.contains("Workout"), "Recovering readiness should not promote hard workouts.")
        XCTAssertFalse(spec.actions.contains("Focus Time"), "Recovering readiness should avoid high-cognitive push framing.")
        XCTAssertTrue(spec.actions.contains("Rest"), "Recovering readiness should include recovery actions.")
        XCTAssertTrue(spec.actions.contains("Take a Walk"), "Recovering readiness should include low-intensity movement.")
    }

    func testStressGuidance_relaxedAndReady_keepsPerformanceActions() {
        let spec = AdvicePresenter.stressGuidance(for: .relaxed, readinessLevel: .ready)

        XCTAssertTrue(spec.actions.contains("Workout"), "Ready state should still allow performance-oriented actions.")
        XCTAssertTrue(spec.actions.contains("Focus Time"), "Ready state should preserve focus-window coaching.")
    }

    func testPoorSleepDashboardAndStressGuidance_areAligned() {
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 62,
            hrvSDNN: 56,
            recoveryHR1m: 24,
            sleepHours: 4.7
        )
        let state = makeRecoveryAdviceState(stressGuidanceLevel: .relaxed)

        let dashboardText = AdvicePresenter.checkRecommendation(
            for: state,
            readinessScore: 42,
            snapshot: snapshot
        ).lowercased()
        let stressSpec = AdvicePresenter.stressGuidance(for: .relaxed, readinessLevel: .recovering)

        let recoverySignals = [
            "skip structured training",
            "easy walk",
            "save harder sessions",
            "keep it light",
            "rest"
        ]

        XCTAssertTrue(
            recoverySignals.contains(where: { dashboardText.contains($0) }),
            "Low-readiness + poor-sleep dashboard guidance should clearly bias recovery."
        )
        XCTAssertFalse(
            dashboardText.contains("push hard") || dashboardText.contains("high-intensity"),
            "Low-readiness + poor-sleep dashboard guidance should avoid hard-intensity wording."
        )
        XCTAssertFalse(stressSpec.actions.contains("Workout"))
        XCTAssertFalse(stressSpec.actions.contains("Focus Time"))
    }

    private func makeRecoveryAdviceState(stressGuidanceLevel: StressGuidanceLevel?) -> AdviceState {
        AdviceState(
            mode: .lightRecovery,
            riskBand: .elevated,
            overtrainingState: .none,
            sleepDeprivationFlag: true,
            medicalEscalationFlag: false,
            heroCategory: .caution,
            heroMessageID: "hero_rough_night",
            buddyMoodCategory: .resting,
            focusInsightID: "insight_rough_night",
            checkBadgeID: "badge_recover",
            goals: [],
            recoveryDriver: .lowSleep,
            stressGuidanceLevel: stressGuidanceLevel,
            smartActions: [],
            allowedIntensity: .light,
            nudgePriorities: [.rest, .walk],
            positivityAnchorID: nil,
            dailyActionBudget: 3
        )
    }
}

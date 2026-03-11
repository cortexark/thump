// WatchConnectivityProviderTests.swift
// Thump Tests
//
// Tests for MockWatchConnectivityProvider contract compliance.
// Validates that the mock correctly simulates WatchConnectivity
// behavior for use in unit tests.
//
// Driven by: SKILL_SDE_TEST_SCAFFOLDING + SKILL_QA_TEST_PLAN (orchestrator v0.3.0)
// Acceptance: Mock provider passes contract tests; all behaviors configurable.

import XCTest
@testable import ThumpPackage

@MainActor
final class WatchConnectivityProviderTests: XCTestCase {

    // MARK: - Properties

    private var sut: MockWatchConnectivityProvider!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        sut = MockWatchConnectivityProvider()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_defaultValues() {
        XCTAssertNil(sut.latestAssessment)
        XCTAssertTrue(sut.isPhoneReachable)
        XCTAssertNil(sut.lastSyncDate)
        XCTAssertNil(sut.connectionError)
        XCTAssertEqual(sut.sendFeedbackCallCount, 0)
        XCTAssertEqual(sut.requestAssessmentCallCount, 0)
    }

    // MARK: - Send Feedback

    func testSendFeedback_success_returnsTrue() {
        sut.shouldSendSucceed = true
        let result = sut.sendFeedback(.positive)
        XCTAssertTrue(result)
        XCTAssertEqual(sut.sendFeedbackCallCount, 1)
        XCTAssertEqual(sut.lastSentFeedback, .positive)
    }

    func testSendFeedback_failure_returnsFalse() {
        sut.shouldSendSucceed = false
        let result = sut.sendFeedback(.negative)
        XCTAssertFalse(result)
        XCTAssertEqual(sut.sendFeedbackCallCount, 1)
        XCTAssertEqual(sut.lastSentFeedback, .negative)
    }

    func testSendFeedback_tracksMultipleCalls() {
        sut.sendFeedback(.positive)
        sut.sendFeedback(.negative)
        sut.sendFeedback(.positive)
        XCTAssertEqual(sut.sendFeedbackCallCount, 3)
        XCTAssertEqual(sut.lastSentFeedback, .positive)
    }

    // MARK: - Request Assessment

    func testRequestAssessment_phoneReachable_deliversAssessment() {
        let assessment = HeartAssessment(
            status: .stable,
            confidence: .high,
            anomalyScore: 0.3,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: 75.0,
            dailyNudge: "Keep it up!",
            explanation: "All good."
        )
        sut.assessmentToDeliver = assessment
        sut.shouldRespondToRequest = true

        sut.requestLatestAssessment()

        XCTAssertEqual(sut.requestAssessmentCallCount, 1)
        XCTAssertNotNil(sut.latestAssessment)
        XCTAssertEqual(sut.latestAssessment?.status, .stable)
        XCTAssertNotNil(sut.lastSyncDate)
        XCTAssertNil(sut.connectionError)
    }

    func testRequestAssessment_phoneUnreachable_setsError() {
        sut.isPhoneReachable = false

        sut.requestLatestAssessment()

        XCTAssertEqual(sut.requestAssessmentCallCount, 1)
        XCTAssertNil(sut.latestAssessment)
        XCTAssertNotNil(sut.connectionError)
        XCTAssertTrue(sut.connectionError?.contains("not reachable") == true)
    }

    func testRequestAssessment_serverError_setsErrorMessage() {
        sut.shouldRespondToRequest = false
        sut.requestErrorMessage = "Sync failed: timeout"

        sut.requestLatestAssessment()

        XCTAssertEqual(sut.requestAssessmentCallCount, 1)
        XCTAssertNil(sut.latestAssessment)
        XCTAssertEqual(sut.connectionError, "Sync failed: timeout")
    }

    // MARK: - Simulate Assessment Received

    func testSimulateAssessmentReceived_updatesState() {
        let assessment = HeartAssessment(
            status: .needsAttention,
            confidence: .medium,
            anomalyScore: 2.5,
            regressionFlag: true,
            stressFlag: false,
            cardioScore: 45.0,
            dailyNudge: "Take a rest day.",
            explanation: "Elevated resting heart rate."
        )

        sut.simulateAssessmentReceived(assessment)

        XCTAssertEqual(sut.latestAssessment?.status, .needsAttention)
        XCTAssertNotNil(sut.lastSyncDate)
    }

    // MARK: - Simulate Reachability Change

    func testSimulateReachabilityChange_updatesFlag() {
        XCTAssertTrue(sut.isPhoneReachable)
        sut.simulateReachabilityChange(false)
        XCTAssertFalse(sut.isPhoneReachable)
        sut.simulateReachabilityChange(true)
        XCTAssertTrue(sut.isPhoneReachable)
    }

    // MARK: - Reset

    func testReset_clearsAllState() {
        sut.sendFeedback(.positive)
        sut.requestLatestAssessment()
        let assessment = HeartAssessment(
            status: .stable,
            confidence: .high,
            anomalyScore: 0.1,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: 80.0,
            dailyNudge: "Great job!",
            explanation: "Looking good."
        )
        sut.simulateAssessmentReceived(assessment)

        sut.reset()

        XCTAssertEqual(sut.sendFeedbackCallCount, 0)
        XCTAssertNil(sut.lastSentFeedback)
        XCTAssertEqual(sut.requestAssessmentCallCount, 0)
        XCTAssertNil(sut.latestAssessment)
        XCTAssertNil(sut.lastSyncDate)
        XCTAssertNil(sut.connectionError)
    }
}

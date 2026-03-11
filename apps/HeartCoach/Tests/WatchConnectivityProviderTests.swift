// WatchConnectivityProviderTests.swift
// ThumpTests
//
// Contract tests for the watch-side mock connectivity provider.

import XCTest
@testable import Thump

@MainActor
final class WatchConnectivityProviderTests: XCTestCase {

    private var sut: MockWatchConnectivityProvider!

    override func setUp() {
        super.setUp()
        sut = MockWatchConnectivityProvider()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testInitialStateDefaultValues() {
        XCTAssertNil(sut.latestAssessment)
        XCTAssertTrue(sut.isPhoneReachable)
        XCTAssertNil(sut.lastSyncDate)
        XCTAssertNil(sut.connectionError)
        XCTAssertEqual(sut.sendFeedbackCallCount, 0)
        XCTAssertEqual(sut.requestAssessmentCallCount, 0)
    }

    func testSendFeedbackTracksCalls() {
        XCTAssertTrue(sut.sendFeedback(.positive))
        XCTAssertTrue(sut.sendFeedback(.negative))

        XCTAssertEqual(sut.sendFeedbackCallCount, 2)
        XCTAssertEqual(sut.lastSentFeedback, .negative)
    }

    func testRequestAssessmentDeliversConfiguredAssessment() {
        sut.assessmentToDeliver = makeAssessment(status: .stable)
        sut.shouldRespondToRequest = true

        sut.requestLatestAssessment()

        XCTAssertEqual(sut.requestAssessmentCallCount, 1)
        XCTAssertEqual(sut.latestAssessment?.status, .stable)
        XCTAssertNotNil(sut.lastSyncDate)
        XCTAssertNil(sut.connectionError)
    }

    func testRequestAssessmentWhenPhoneUnreachableSetsError() {
        sut.isPhoneReachable = false

        sut.requestLatestAssessment()

        XCTAssertEqual(sut.requestAssessmentCallCount, 1)
        XCTAssertNil(sut.latestAssessment)
        XCTAssertTrue(sut.connectionError?.contains("not reachable") == true)
    }

    func testResetClearsTrackedState() {
        sut.sendFeedback(.positive)
        sut.assessmentToDeliver = makeAssessment(status: .needsAttention)
        sut.requestLatestAssessment()

        sut.reset()

        XCTAssertEqual(sut.sendFeedbackCallCount, 0)
        XCTAssertNil(sut.lastSentFeedback)
        XCTAssertEqual(sut.requestAssessmentCallCount, 0)
        XCTAssertNil(sut.latestAssessment)
        XCTAssertNil(sut.lastSyncDate)
        XCTAssertNil(sut.connectionError)
    }

    private func makeAssessment(status: TrendStatus) -> HeartAssessment {
        HeartAssessment(
            status: status,
            confidence: .high,
            anomalyScore: status == .needsAttention ? 2.5 : 0.3,
            regressionFlag: status == .needsAttention,
            stressFlag: false,
            cardioScore: 72.0,
            dailyNudge: DailyNudge(
                category: .walk,
                title: "Keep Moving",
                description: "A short walk supports recovery.",
                durationMinutes: 10,
                icon: "figure.walk"
            ),
            explanation: "Assessment generated for test coverage."
        )
    }
}

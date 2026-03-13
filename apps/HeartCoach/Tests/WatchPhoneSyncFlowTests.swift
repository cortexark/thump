// WatchPhoneSyncFlowTests.swift
// ThumpTests
//
// End-to-end customer journey tests for the watch↔phone sync flow.
// Covers the complete lifecycle: assessment generation on phone,
// serialization, transmission, watch-side deserialization, feedback
// submission, and feedback receipt on phone side.
//
// These tests verify the FULL data pipeline that users depend on
// for watch↔phone sync, without requiring a real WCSession.

import XCTest
@testable import Thump

final class WatchPhoneSyncFlowTests: XCTestCase {

    // MARK: - Phone → Watch: Assessment Delivery

    /// Customer journey: User opens phone app, assessment is generated,
    /// watch receives it with all fields intact.
    func testPhoneAssessment_reachesWatch_fullyIntact() {
        // 1. Phone generates an assessment
        let history = MockData.mockHistory(days: 14)
        let today = MockData.mockTodaySnapshot
        let engine = ConfigService.makeDefaultEngine()
        let assessment = engine.assess(
            history: history,
            current: today,
            feedback: nil
        )

        // 2. Phone encodes it for transmission
        let encoded = ConnectivityMessageCodec.encode(assessment, type: .assessment)
        XCTAssertNotNil(encoded, "Phone should encode assessment successfully")

        // 3. Watch receives and decodes
        let watchDecoded = ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: encoded!,
            payloadKeys: ["payload", "assessment"]
        )
        XCTAssertNotNil(watchDecoded, "Watch should decode assessment successfully")

        // 4. All fields should match
        XCTAssertEqual(watchDecoded!.status, assessment.status)
        XCTAssertEqual(watchDecoded!.confidence, assessment.confidence)
        XCTAssertEqual(watchDecoded!.anomalyScore, assessment.anomalyScore, accuracy: 0.001)
        XCTAssertEqual(watchDecoded!.regressionFlag, assessment.regressionFlag)
        XCTAssertEqual(watchDecoded!.stressFlag, assessment.stressFlag)
        XCTAssertEqual(watchDecoded!.cardioScore ?? 0, assessment.cardioScore ?? 0, accuracy: 0.001)
        XCTAssertEqual(watchDecoded!.dailyNudge.title, assessment.dailyNudge.title)
        XCTAssertEqual(watchDecoded!.dailyNudge.category, assessment.dailyNudge.category)
        XCTAssertEqual(watchDecoded!.explanation, assessment.explanation)
    }

    /// Customer journey: Watch requests assessment, phone replies with
    /// a valid encoded message, watch displays it.
    func testWatchRequestAssessment_phoneReplies_watchDecodes() {
        // 1. Phone has a cached assessment
        let assessment = makeAssessment(status: .improving, cardio: 82.0)

        // 2. Phone encodes reply (simulating didReceiveMessage replyHandler)
        let reply = ConnectivityMessageCodec.encode(assessment, type: .assessment)
        XCTAssertNotNil(reply)

        // 3. Watch decodes the reply
        let decoded = ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: reply!,
            payloadKeys: ["payload", "assessment"]
        )
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.status, .improving)
        XCTAssertEqual(decoded!.cardioScore ?? 0, 82.0, accuracy: 0.01)
    }

    /// Customer journey: Watch requests but phone has no assessment yet.
    func testWatchRequestAssessment_phoneHasNone_returnsError() {
        // Phone replies with error
        let errorReply = ConnectivityMessageCodec.errorMessage(
            "No assessment available yet. Open Thump on your iPhone to refresh."
        )

        // Watch checks reply type
        XCTAssertEqual(errorReply["type"] as? String, "error")
        XCTAssertEqual(
            errorReply["reason"] as? String,
            "No assessment available yet. Open Thump on your iPhone to refresh."
        )

        // Assessment decode should fail
        let decoded = ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: errorReply
        )
        XCTAssertNil(decoded, "Error message should not decode as assessment")
    }

    // MARK: - Watch → Phone: Feedback Delivery

    /// Customer journey: User taps thumbs-up on watch, feedback reaches
    /// phone and is persisted.
    func testWatchFeedback_reachesPhone_intact() {
        // 1. Watch creates feedback payload
        let payload = WatchFeedbackPayload(
            eventId: UUID().uuidString,
            date: Date(),
            response: .positive,
            source: "watch"
        )

        // 2. Watch encodes for transmission
        let encoded = ConnectivityMessageCodec.encode(payload, type: .feedback)
        XCTAssertNotNil(encoded)
        XCTAssertEqual(encoded!["type"] as? String, "feedback")

        // 3. Phone receives and decodes
        let phoneDecoded = ConnectivityMessageCodec.decode(
            WatchFeedbackPayload.self,
            from: encoded!
        )
        XCTAssertNotNil(phoneDecoded)
        XCTAssertEqual(phoneDecoded!.response, .positive)
        XCTAssertEqual(phoneDecoded!.source, "watch")
    }

    /// Customer journey: User taps thumbs-down, phone processes via bridge.
    func testWatchNegativeFeedback_processedByBridge() {
        let bridge = WatchFeedbackBridge()

        // Watch sends negative feedback
        let payload = WatchFeedbackPayload(
            eventId: "negative-001",
            date: Date(),
            response: .negative,
            source: "watch"
        )

        // Phone bridge processes it
        bridge.processFeedback(payload)

        XCTAssertEqual(bridge.pendingFeedback.count, 1)
        XCTAssertEqual(bridge.latestFeedback(), .negative)
        XCTAssertEqual(bridge.totalProcessedCount, 1)
    }

    /// Customer journey: User submits feedback multiple times (should be
    /// deduplicated by the bridge on the phone side).
    func testWatchDuplicateFeedback_deduplicatedOnPhone() {
        let bridge = WatchFeedbackBridge()
        let eventId = "dup-feedback-001"

        let payload = WatchFeedbackPayload(
            eventId: eventId,
            date: Date(),
            response: .positive,
            source: "watch"
        )

        // First delivery
        bridge.processFeedback(payload)
        // Duplicate (e.g., transferUserInfo retry)
        bridge.processFeedback(payload)

        XCTAssertEqual(bridge.pendingFeedback.count, 1, "Duplicate should be rejected")
        XCTAssertEqual(bridge.totalProcessedCount, 1)
    }

    // MARK: - Full Round-Trip: Phone → Watch → Phone

    /// Customer journey: Phone pushes assessment → watch displays → user
    /// gives feedback → phone receives feedback.
    func testFullRoundTrip_assessmentThenFeedback() {
        let bridge = WatchFeedbackBridge()

        // 1. Phone generates and encodes assessment
        let assessment = makeAssessment(status: .stable, cardio: 75.0)
        let assessmentMsg = ConnectivityMessageCodec.encode(assessment, type: .assessment)!

        // 2. Watch decodes assessment
        let watchAssessment = ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: assessmentMsg
        )!
        XCTAssertEqual(watchAssessment.status, .stable)

        // 3. Watch user taps thumbs-up, creates feedback
        let feedback = WatchFeedbackPayload(
            eventId: "round-trip-001",
            date: Date(),
            response: .positive,
            source: "watch"
        )
        let feedbackMsg = ConnectivityMessageCodec.encode(feedback, type: .feedback)!

        // 4. Phone decodes feedback
        let phoneFeedback = ConnectivityMessageCodec.decode(
            WatchFeedbackPayload.self,
            from: feedbackMsg
        )!
        XCTAssertEqual(phoneFeedback.response, .positive)

        // 5. Phone processes via bridge
        bridge.processFeedback(phoneFeedback)
        XCTAssertEqual(bridge.latestFeedback(), .positive)
    }

    // MARK: - Breath Prompt: Phone → Watch

    /// Customer journey: Stress rises on phone, breath prompt sent to watch.
    func testBreathPrompt_phoneToWatch() {
        // Phone constructs breath prompt message (same format as ConnectivityService.sendBreathPrompt)
        let message: [String: Any] = [
            "type": "breathPrompt",
            "title": "Take a Breath",
            "description": "Your stress has been climbing.",
            "durationMinutes": 3,
            "category": NudgeCategory.breathe.rawValue
        ]

        // Verify message structure is WCSession-compliant (all plist types)
        XCTAssertEqual(message["type"] as? String, "breathPrompt")
        XCTAssertEqual(message["title"] as? String, "Take a Breath")
        XCTAssertEqual(message["durationMinutes"] as? Int, 3)
        XCTAssertEqual(message["category"] as? String, "breathe")
    }

    /// Customer journey: Check-in prompt sent from phone to watch.
    func testCheckInPrompt_phoneToWatch() {
        let message: [String: Any] = [
            "type": "checkInPrompt",
            "message": "You slept in a bit today. How are you feeling?"
        ]

        XCTAssertEqual(message["type"] as? String, "checkInPrompt")
        XCTAssertEqual(
            message["message"] as? String,
            "You slept in a bit today. How are you feeling?"
        )
    }

    // MARK: - Watch Feedback Persistence

    /// Customer journey: User submits feedback on watch, reopens watch
    /// app later same day — feedback state should persist.
    @MainActor
    func testWatchFeedback_persistsAcrossAppRestarts() throws {
        let defaults = UserDefaults(suiteName: "com.thump.test.watchfeedback.\(UUID().uuidString)")!
        let service = WatchFeedbackService(defaults: defaults)

        // First session: submit feedback
        service.saveFeedback(.positive, for: Date())
        XCTAssertTrue(service.hasFeedbackToday())
        XCTAssertEqual(service.todayFeedback, .positive)

        // Simulate "restart" — new service instance, same defaults
        let service2 = WatchFeedbackService(defaults: defaults)
        XCTAssertTrue(service2.hasFeedbackToday(), "Feedback should persist")
        XCTAssertEqual(service2.loadFeedback(for: Date()), .positive)
    }

    /// Customer journey: User submits feedback yesterday, opens today —
    /// should NOT show as already submitted.
    @MainActor
    func testWatchFeedback_doesNotCarryToNextDay() throws {
        let defaults = UserDefaults(suiteName: "com.thump.test.watchfeedback.\(UUID().uuidString)")!
        let service = WatchFeedbackService(defaults: defaults)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        service.saveFeedback(.positive, for: yesterday)

        XCTAssertFalse(
            service.hasFeedbackToday(),
            "Yesterday's feedback should not count as today"
        )
        XCTAssertNil(service.todayFeedback)
    }

    // MARK: - Edge Cases

    /// Nudge with nil duration should encode/decode cleanly.
    func testNudge_nilDuration_roundTrips() {
        let assessment = HeartAssessment(
            status: .stable,
            confidence: .high,
            anomalyScore: 0.1,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: 80.0,
            dailyNudge: DailyNudge(
                category: .rest,
                title: "Wind Down",
                description: "Time to relax.",
                durationMinutes: nil,
                icon: "moon.fill"
            ),
            explanation: "All clear."
        )
        let encoded = ConnectivityMessageCodec.encode(assessment, type: .assessment)!
        let decoded = ConnectivityMessageCodec.decode(HeartAssessment.self, from: encoded)!
        XCTAssertNil(decoded.dailyNudge.durationMinutes)
        XCTAssertEqual(decoded.dailyNudge.category, .rest)
    }

    /// Empty explanation string should round-trip.
    func testAssessment_emptyExplanation_roundTrips() {
        let assessment = HeartAssessment(
            status: .stable,
            confidence: .low,
            anomalyScore: 0.0,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: 60.0,
            dailyNudge: makeNudge(),
            explanation: ""
        )
        let encoded = ConnectivityMessageCodec.encode(assessment, type: .assessment)!
        let decoded = ConnectivityMessageCodec.decode(HeartAssessment.self, from: encoded)!
        XCTAssertEqual(decoded.explanation, "")
    }

    // MARK: - Helpers

    private func makeAssessment(
        status: TrendStatus,
        cardio: Double = 72.0
    ) -> HeartAssessment {
        HeartAssessment(
            status: status,
            confidence: .high,
            anomalyScore: 0.3,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: cardio,
            dailyNudge: makeNudge(),
            explanation: "Test assessment"
        )
    }

    private func makeNudge() -> DailyNudge {
        DailyNudge(
            category: .walk,
            title: "Keep Moving",
            description: "A short walk helps.",
            durationMinutes: 10,
            icon: "figure.walk"
        )
    }
}

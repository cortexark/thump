// ConnectivityCodecTests.swift
// ThumpTests
//
// Tests for the ConnectivityMessageCodec: the shared serialization
// layer between iOS and watchOS. Verifies encode/decode round-trips,
// error messages, acknowledgements, and edge cases that cause sync
// failures between the phone and watch apps.

import XCTest
@testable import Thump

final class ConnectivityCodecTests: XCTestCase {

    // MARK: - Assessment Round-Trip

    func testAssessment_encodeDecode_roundTrips() {
        let assessment = makeAssessment(status: .stable)
        let encoded = ConnectivityMessageCodec.encode(assessment, type: .assessment)
        XCTAssertNotNil(encoded, "Encoding assessment should succeed")

        let decoded = ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: encoded!
        )
        XCTAssertNotNil(decoded, "Decoding assessment should succeed")
        XCTAssertEqual(decoded?.status, .stable)
        XCTAssertEqual(decoded?.confidence, .high)
        XCTAssertEqual(decoded?.cardioScore, 72.0)
    }

    func testAssessment_allStatuses_roundTrip() {
        for status in TrendStatus.allCases {
            let assessment = makeAssessment(status: status)
            let encoded = ConnectivityMessageCodec.encode(assessment, type: .assessment)
            XCTAssertNotNil(encoded, "Encoding \(status) should succeed")

            let decoded = ConnectivityMessageCodec.decode(
                HeartAssessment.self,
                from: encoded!
            )
            XCTAssertEqual(decoded?.status, status, "\(status) should round-trip")
        }
    }

    func testAssessment_preservesFlags() {
        let assessment = HeartAssessment(
            status: .needsAttention,
            confidence: .medium,
            anomalyScore: 3.5,
            regressionFlag: true,
            stressFlag: true,
            cardioScore: 55.0,
            dailyNudge: makeNudge(),
            explanation: "Test explanation"
        )
        let encoded = ConnectivityMessageCodec.encode(assessment, type: .assessment)!
        let decoded = ConnectivityMessageCodec.decode(HeartAssessment.self, from: encoded)!

        XCTAssertTrue(decoded.regressionFlag)
        XCTAssertTrue(decoded.stressFlag)
        XCTAssertEqual(decoded.anomalyScore, 3.5, accuracy: 0.01)
        XCTAssertEqual(decoded.explanation, "Test explanation")
    }

    // MARK: - Feedback Round-Trip

    func testFeedback_encodeDecode_roundTrips() {
        let payload = WatchFeedbackPayload(
            eventId: "test-event-123",
            date: Date(),
            response: .positive,
            source: "watch"
        )
        let encoded = ConnectivityMessageCodec.encode(payload, type: .feedback)
        XCTAssertNotNil(encoded)

        let decoded = ConnectivityMessageCodec.decode(
            WatchFeedbackPayload.self,
            from: encoded!
        )
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.eventId, "test-event-123")
        XCTAssertEqual(decoded?.response, .positive)
        XCTAssertEqual(decoded?.source, "watch")
    }

    func testFeedback_allResponses_roundTrip() {
        for feedback in DailyFeedback.allCases {
            let payload = WatchFeedbackPayload(
                eventId: UUID().uuidString,
                date: Date(),
                response: feedback,
                source: "watch"
            )
            let encoded = ConnectivityMessageCodec.encode(payload, type: .feedback)!
            let decoded = ConnectivityMessageCodec.decode(
                WatchFeedbackPayload.self,
                from: encoded
            )
            XCTAssertEqual(decoded?.response, feedback, "\(feedback) should round-trip")
        }
    }

    // MARK: - Message Type Tags

    func testEncode_setsCorrectTypeTag() {
        let assessment = makeAssessment(status: .stable)

        let assessmentMsg = ConnectivityMessageCodec.encode(assessment, type: .assessment)!
        XCTAssertEqual(assessmentMsg["type"] as? String, "assessment")

        let feedbackPayload = WatchFeedbackPayload(
            eventId: "evt", date: Date(), response: .positive, source: "test"
        )
        let feedbackMsg = ConnectivityMessageCodec.encode(feedbackPayload, type: .feedback)!
        XCTAssertEqual(feedbackMsg["type"] as? String, "feedback")
    }

    func testEncode_payloadIsBase64String() {
        let assessment = makeAssessment(status: .stable)
        let encoded = ConnectivityMessageCodec.encode(assessment, type: .assessment)!

        let payload = encoded["payload"]
        XCTAssertTrue(payload is String, "Payload should be a Base64 string")
        XCTAssertNotNil(
            Data(base64Encoded: payload as! String),
            "Payload should be valid Base64"
        )
    }

    // MARK: - Error & Acknowledgement Messages

    func testErrorMessage_containsReasonAndType() {
        let msg = ConnectivityMessageCodec.errorMessage("Something went wrong")
        XCTAssertEqual(msg["type"] as? String, "error")
        XCTAssertEqual(msg["reason"] as? String, "Something went wrong")
    }

    func testAcknowledgement_containsTypeAndStatus() {
        let msg = ConnectivityMessageCodec.acknowledgement()
        XCTAssertEqual(msg["type"] as? String, "acknowledgement")
        XCTAssertEqual(msg["status"] as? String, "received")
    }

    // MARK: - Decode Robustness

    func testDecode_emptyMessage_returnsNil() {
        let result = ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: [:]
        )
        XCTAssertNil(result, "Empty message should decode to nil")
    }

    func testDecode_wrongPayloadKey_returnsNil() {
        let result = ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: ["wrongKey": "notBase64"]
        )
        XCTAssertNil(result)
    }

    func testDecode_corruptBase64_returnsNil() {
        let result = ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: ["payload": "not-valid-base64!!!"]
        )
        XCTAssertNil(result, "Corrupt Base64 should decode to nil, not crash")
    }

    func testDecode_validBase64ButWrongType_returnsNil() {
        // Encode a feedback payload, try to decode as assessment
        let payload = WatchFeedbackPayload(
            eventId: "evt", date: Date(), response: .positive, source: "test"
        )
        let encoded = ConnectivityMessageCodec.encode(payload, type: .feedback)!
        let result = ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: encoded
        )
        XCTAssertNil(result, "Wrong type decode should return nil")
    }

    func testDecode_alternatePayloadKey_works() {
        let assessment = makeAssessment(status: .improving)
        let data = try! JSONEncoder.thumpEncoder.encode(assessment)
        let base64 = data.base64EncodedString()

        // Use "assessment" key instead of "payload"
        let message: [String: Any] = [
            "type": "assessment",
            "assessment": base64
        ]
        let decoded = ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: message,
            payloadKeys: ["payload", "assessment"]
        )
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.status, .improving)
    }

    // MARK: - Date Serialization

    func testFeedback_datePreservedAcrossEncodeDecode() {
        let now = Date()
        let payload = WatchFeedbackPayload(
            eventId: "date-test",
            date: now,
            response: .negative,
            source: "watch"
        )
        let encoded = ConnectivityMessageCodec.encode(payload, type: .feedback)!
        let decoded = ConnectivityMessageCodec.decode(
            WatchFeedbackPayload.self,
            from: encoded
        )!

        // ISO8601 loses sub-second precision, so check within 1 second
        XCTAssertEqual(
            decoded.date.timeIntervalSince1970,
            now.timeIntervalSince1970,
            accuracy: 1.0,
            "Date should survive round-trip within 1 second"
        )
    }

    // MARK: - Helpers

    private func makeAssessment(status: TrendStatus) -> HeartAssessment {
        HeartAssessment(
            status: status,
            confidence: .high,
            anomalyScore: status == .needsAttention ? 2.5 : 0.3,
            regressionFlag: status == .needsAttention,
            stressFlag: false,
            cardioScore: 72.0,
            dailyNudge: makeNudge(),
            explanation: "Assessment for \(status.rawValue)"
        )
    }

    private func makeNudge() -> DailyNudge {
        DailyNudge(
            category: .walk,
            title: "Keep Moving",
            description: "A short walk supports recovery.",
            durationMinutes: 10,
            icon: "figure.walk"
        )
    }
}

// MARK: - JSONEncoder extension for tests

private extension JSONEncoder {
    static let thumpEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

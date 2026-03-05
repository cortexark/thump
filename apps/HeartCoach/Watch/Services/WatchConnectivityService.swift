// WatchConnectivityService.swift
// Thump Watch
//
// Watch-side WatchConnectivity service responsible for bidirectional
// communication with the companion iOS app. Receives assessment updates
// and transmits user feedback payloads.
//
// Message format:
//   Outbound feedback:  { "type": "feedback",   "payload": <JSON Data base64> }
//   Inbound assessment: { "type": "assessment",  "payload": <JSON Data base64> }
//   Request assessment: { "type": "requestAssessment" }

import Foundation
import WatchConnectivity
import Combine

/// Watch-side connectivity service that manages the WCSession lifecycle,
/// receives ``HeartAssessment`` updates from the phone, and sends
/// ``WatchFeedbackPayload`` messages back.
///
/// Payloads are serialised via `JSONEncoder` / `JSONDecoder` and embedded
/// in the WatchConnectivity message dictionary as Base-64 encoded `Data`
/// under the `"payload"` key. This avoids the fragile
/// `[String: Any]`-to-model manual mapping that the previous
/// implementation relied on.
@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {

    // MARK: - Published State

    /// The most recent assessment received from the companion phone app.
    @Published private(set) var latestAssessment: HeartAssessment?

    /// Whether the paired iPhone is currently reachable for live messaging.
    @Published private(set) var isPhoneReachable: Bool = false

    /// Timestamp of the last successful assessment sync.
    @Published private(set) var lastSyncDate: Date?

    /// User-facing error message when communication with the iPhone fails.
    /// Set when a request cannot be fulfilled (e.g., phone unreachable).
    /// The UI should observe this and clear it after displaying.
    @Published var connectionError: String?

    // MARK: - Private

    private var session: WCSession?

    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    // MARK: - Initialization

    override init() {
        super.init()
        activateSessionIfSupported()
    }

    // MARK: - Session Activation

    /// Activates the WCSession if Watch Connectivity is supported on this device.
    private func activateSessionIfSupported() {
        guard WCSession.isSupported() else { return }
        let wcSession = WCSession.default
        wcSession.delegate = self
        wcSession.activate()
        self.session = wcSession
    }

    // MARK: - Outbound: Send Feedback

    /// Sends a ``DailyFeedback`` to the companion phone app.
    /// Uses `sendMessage` for live delivery when reachable, falling back
    /// to `transferUserInfo` for guaranteed background delivery.
    ///
    /// - Parameter feedback: The user's daily feedback to transmit.
    /// - Returns: `true` if the message was dispatched successfully.
    @discardableResult
    func sendFeedback(_ feedback: DailyFeedback) -> Bool {
        guard let session = session else { return false }

        let payload = WatchFeedbackPayload(
            eventId: UUID().uuidString,
            date: Date(),
            response: feedback,
            source: "watch"
        )

        guard let message = encodeToMessage(payload, type: "feedback") else {
            return false
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                // Reachability changed between check and send; fall back to transfer.
                session.transferUserInfo(message)
                debugPrint("[WatchConnectivity] sendMessage failed, transferred userInfo: \(error.localizedDescription)")
            }
        } else {
            session.transferUserInfo(message)
        }

        return true
    }

    // MARK: - Outbound: Request Assessment

    /// Requests the latest assessment from the companion phone app.
    /// The phone should respond by calling `transferUserInfo` with the
    /// current ``HeartAssessment``.
    func requestLatestAssessment() {
        guard let session = session else {
            connectionError = "Watch Connectivity is not available."
            return
        }

        guard session.isReachable else {
            connectionError = "iPhone not reachable. Open Thump on your iPhone."
            return
        }

        // Clear any previous error on a new attempt.
        connectionError = nil

        let request: [String: Any] = ["type": "requestAssessment"]
        session.sendMessage(request, replyHandler: { [weak self] reply in
            self?.handleAssessmentReply(reply)
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.connectionError = "Sync failed: \(error.localizedDescription)"
            }
            debugPrint("[WatchConnectivity] requestAssessment failed: \(error.localizedDescription)")
        })
    }

    // MARK: - Inbound Handling

    nonisolated private func handleAssessmentReply(_ reply: [String: Any]) {
        guard let assessment = decodeAssessment(from: reply) else { return }

        Task { @MainActor [weak self] in
            self?.latestAssessment = assessment
            self?.lastSyncDate = Date()
        }
    }

    nonisolated private func handleIncomingMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "assessment":
            if let assessment = decodeAssessment(from: message) {
                Task { @MainActor [weak self] in
                    self?.latestAssessment = assessment
                    self?.lastSyncDate = Date()
                }
            }

        default:
            debugPrint("[WatchConnectivity] Unknown message type: \(type)")
        }
    }

    // MARK: - Coding Helpers

    /// Encode a `Codable` value into a WatchConnectivity-compatible
    /// `[String: Any]` message dictionary.
    ///
    /// The encoded JSON `Data` is stored as a Base-64 string under
    /// the `"payload"` key so that the dictionary remains
    /// property-list compliant (required by `transferUserInfo`).
    private func encodeToMessage<T: Encodable>(
        _ value: T,
        type: String
    ) -> [String: Any]? {
        do {
            let data = try encoder.encode(value)
            let base64 = data.base64EncodedString()
            return [
                "type": type,
                "payload": base64
            ]
        } catch {
            debugPrint("[WatchConnectivity] Encode failed for \(T.self): \(error.localizedDescription)")
            return nil
        }
    }

    /// Decode a ``HeartAssessment`` from a message dictionary.
    ///
    /// Supports two payload formats:
    /// 1. `"payload"` is a Base-64 encoded JSON string (preferred).
    /// 2. `"assessment"` is a Base-64 encoded JSON string (reply format).
    nonisolated private func decodeAssessment(from message: [String: Any]) -> HeartAssessment? {
        let localDecoder = JSONDecoder()
        localDecoder.dateDecodingStrategy = .iso8601
        // Try "payload" key first (standard push format)
        if let base64 = message["payload"] as? String,
           let data = Data(base64Encoded: base64) {
            return try? localDecoder.decode(HeartAssessment.self, from: data)
        }

        // Fall back to "assessment" key (reply format)
        if let base64 = message["assessment"] as? String,
           let data = Data(base64Encoded: base64) {
            return try? localDecoder.decode(HeartAssessment.self, from: data)
        }

        return nil
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = session.isReachable
        }
        if let error = error {
            debugPrint("[WatchConnectivity] Activation failed: \(error.localizedDescription)")
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = session.isReachable
        }
    }

    /// Handles live messages from the phone.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        handleIncomingMessage(message)
    }

    /// Handles live messages from the phone that expect a reply.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleIncomingMessage(message)
        replyHandler(["status": "received"])
    }

    /// Handles background `transferUserInfo` deliveries from the phone.
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        handleIncomingMessage(userInfo)
    }

    /// Handles application context updates from the phone.
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        handleIncomingMessage(applicationContext)
    }
}

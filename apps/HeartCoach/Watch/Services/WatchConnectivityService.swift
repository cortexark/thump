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
/// Payloads are serialized through ``ConnectivityMessageCodec`` so both
/// platforms share one transport contract.
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

    // MARK: - Initialization

    override init() {
        super.init()
        activateSessionIfSupported()
        injectSimulatorMockDataIfNeeded()
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

    // MARK: - Preview / Test Helpers

    /// Directly sets the latest assessment — used by SwiftUI previews and tests
    /// that cannot wait for the async simulator injection task.
    func simulateAssessmentForPreview(_ assessment: HeartAssessment) {
        latestAssessment = assessment
        lastSyncDate = Date()
        isPhoneReachable = true
    }

    // MARK: - Simulator Mock Data

    /// Injects realistic mock assessment data when running in the iOS/watchOS Simulator.
    ///
    /// The Simulator cannot establish a real WCSession between paired simulators,
    /// so `session.isReachable` is always false and `sendMessage` never delivers.
    /// This method seeds `latestAssessment` and `isPhoneReachable` directly so
    /// the watch UI renders with real-looking data during development.
    private func injectSimulatorMockDataIfNeeded() {
        #if targetEnvironment(simulator)
        Task { @MainActor [weak self] in
            // Brief delay so the view hierarchy is set up before data arrives.
            try? await Task.sleep(for: .seconds(0.5))
            guard let self else { return }
            self.isPhoneReachable = true
            let history = MockData.mockHistory(days: 21)
            let engine = ConfigService.makeDefaultEngine()
            let assessment = engine.assess(
                history: history,
                current: MockData.mockTodaySnapshot,
                feedback: nil
            )
            self.latestAssessment = assessment
            self.lastSyncDate = Date()

            // Seed a mock action plan so watch UI has content in the Simulator.
            self.latestActionPlan = WatchActionPlan.mock
        }
        #endif
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

        guard let message = ConnectivityMessageCodec.encode(
            payload,
            type: .feedback
        ) else {
            return false
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                // Reachability changed between check and send; fall back to transfer.
                session.transferUserInfo(message)
                debugPrint(
                    "[WatchConnectivity] sendMessage failed, "
                    + "transferred userInfo: \(error.localizedDescription)"
                )
            }
        } else {
            session.transferUserInfo(message)
        }

        return true
    }

    // MARK: - Outbound: Request Assessment

    /// Requests the latest assessment from the companion phone app.
    /// The phone responds synchronously through `replyHandler`.
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

        let request: [String: Any] = [
            "type": ConnectivityMessageType.requestAssessment.rawValue
        ]
        session.sendMessage(
            request,
            replyHandler: { [weak self] reply in
                self?.handleAssessmentReply(reply)
            },
            errorHandler: { [weak self] error in
                Task { @MainActor in
                    self?.connectionError = "Sync failed: \(error.localizedDescription)"
                }
                debugPrint(
                    "[WatchConnectivity] requestAssessment failed: "
                    + "\(error.localizedDescription)"
                )
            }
        )
    }

    // MARK: - Inbound Handling

    nonisolated private func handleAssessmentReply(_ reply: [String: Any]) {
        if let type = reply["type"] as? String,
           type == ConnectivityMessageType.error.rawValue {
            let reason = (reply["reason"] as? String) ?? "Unable to load the latest assessment."
            Task { @MainActor [weak self] in
                self?.connectionError = reason
            }
            return
        }

        guard let assessment = decodeAssessment(from: reply) else { return }

        Task { @MainActor [weak self] in
            self?.latestAssessment = assessment
            self?.lastSyncDate = Date()
            self?.connectionError = nil
        }
    }

    // MARK: - Published Prompts

    /// Breath prompt received from the phone (stress rising).
    @Published var breathPrompt: DailyNudge?

    /// Morning check-in prompt received from the phone.
    @Published var checkInPromptMessage: String?

    /// The most recent action plan received from the phone.
    /// Contains daily improvement items + weekly and monthly buddy summaries.
    @Published private(set) var latestActionPlan: WatchActionPlan?

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

        case "breathPrompt":
            let title = (message["title"] as? String) ?? "Take a Breath"
            let desc = (message["description"] as? String)
                ?? "A quick breathing exercise might help you reset."
            let duration = (message["durationMinutes"] as? Int) ?? 3
            let nudge = DailyNudge(
                category: .breathe,
                title: title,
                description: desc,
                durationMinutes: duration,
                icon: "wind"
            )
            Task { @MainActor [weak self] in
                self?.breathPrompt = nudge
            }

        case "checkInPrompt":
            let msg = (message["message"] as? String)
                ?? "How are you feeling this morning?"
            Task { @MainActor [weak self] in
                self?.checkInPromptMessage = msg
            }

        case "actionPlan":
            if let plan = ConnectivityMessageCodec.decode(WatchActionPlan.self, from: message) {
                Task { @MainActor [weak self] in
                    self?.latestActionPlan = plan
                }
            }

        default:
            debugPrint("[WatchConnectivity] Unknown message type: \(type)")
        }
    }

    /// Decode a ``HeartAssessment`` from a message dictionary.
    ///
    /// Supports two payload formats:
    /// 1. `"payload"` is a Base-64 encoded JSON string (preferred).
    /// 2. `"assessment"` is a Base-64 encoded JSON string (reply format).
    nonisolated private func decodeAssessment(from message: [String: Any]) -> HeartAssessment? {
        ConnectivityMessageCodec.decode(
            HeartAssessment.self,
            from: message,
            payloadKeys: ["payload", "assessment"]
        )
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
            return
        }
        guard activationState == .activated else { return }
        // Auto-request the latest assessment shortly after activation so
        // the watch never sits on the "Syncing..." placeholder on first open.
        // A brief delay lets WCSession settle its reachability state.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, self.latestAssessment == nil else { return }
            self.requestLatestAssessment()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPhoneReachable = session.isReachable
            // Auto-retry when the phone becomes reachable and we still
            // have no assessment (e.g., watch opened away from iPhone,
            // then iPhone came back into range).
            if session.isReachable && self.latestAssessment == nil {
                self.connectionError = nil
                self.requestLatestAssessment()
            }
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
        replyHandler(ConnectivityMessageCodec.acknowledgement())
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

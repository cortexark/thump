// ConnectivityService.swift
// Thump iOS
//
// iOS-side WatchConnectivity service responsible for bidirectional
// communication with the companion watchOS app. Sends HeartAssessment
// updates to the watch and receives WatchFeedbackPayload messages.
// Platforms: iOS 17+

import Foundation
import WatchConnectivity
import Combine

// MARK: - Connectivity Service

/// iOS-side WatchConnectivity service that manages the WCSession lifecycle,
/// sends `HeartAssessment` updates to the paired Apple Watch, and receives
/// `WatchFeedbackPayload` messages from the watch.
@MainActor
final class ConnectivityService: NSObject, ObservableObject {

    // MARK: - Published State

    /// Whether the paired Apple Watch is currently reachable for live messaging.
    @Published var isWatchReachable: Bool = false

    /// The most recent feedback payload received from the watch.
    @Published var latestWatchFeedback: WatchFeedbackPayload?

    // MARK: - Private Properties

    private var session: WCSession?
    private var localStore = LocalStore()
    private var latestAssessment: HeartAssessment?

    // MARK: - Initialization

    override init() {
        super.init()
        activateSessionIfSupported()
    }

    // MARK: - Session Activation

    /// Activates the WCSession if Watch Connectivity is supported.
    private func activateSessionIfSupported() {
        guard WCSession.isSupported() else {
            debugPrint("[ConnectivityService] WCSession not supported on this device.")
            return
        }
        let wcSession = WCSession.default
        wcSession.delegate = self
        wcSession.activate()
        self.session = wcSession
    }

    /// Binds the shared local store so inbound feedback and assessment replies
    /// can use persisted app state rather than transient in-memory state only.
    ///
    /// After binding, immediately caches and pushes the latest persisted assessment
    /// so the watch receives data as soon as the app finishes startup — without
    /// waiting for the Dashboard view to load and call `refresh()`.
    func bind(localStore: LocalStore) {
        self.localStore = localStore

        // Seed the in-memory cache from persisted history so reply handlers
        // have data even before the dashboard has run its first refresh.
        if let persisted = localStore.loadHistory().last?.assessment {
            latestAssessment = persisted
        }

        // Proactively push to the watch if it's already reachable.
        if let assessment = latestAssessment, session?.isReachable == true {
            sendAssessment(assessment)
        }
    }

    // MARK: - Outbound: Send Assessment

    /// Sends a `HeartAssessment` to the paired Apple Watch.
    ///
    /// Encodes the assessment to JSON, wraps it in a message dictionary,
    /// and uses `sendMessage` for live delivery when the watch is reachable,
    /// falling back to `transferUserInfo` for guaranteed background delivery.
    ///
    /// - Parameter assessment: The assessment to transmit to the watch.
    func sendAssessment(_ assessment: HeartAssessment) {
        guard let session = session else {
            debugPrint("[ConnectivityService] No active session.")
            return
        }

        guard let message = ConnectivityMessageCodec.encode(
            assessment,
            type: .assessment
        ) else {
            debugPrint("[ConnectivityService] Failed to encode assessment payload.")
            return
        }

        latestAssessment = assessment

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                // Reachability changed; fall back to guaranteed delivery.
                debugPrint(
                    "[ConnectivityService] sendMessage failed, "
                    + "using transferUserInfo: \(error.localizedDescription)"
                )
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Outbound: Breath Prompt

    /// Sends a breathing exercise prompt to the Apple Watch.
    ///
    /// When stress is rising, this delivers a gentle "take a breath"
    /// nudge directly to the watch via live messaging (or background
    /// transfer if the watch isn't currently reachable).
    ///
    /// - Parameter nudge: The breathing nudge to send.
    func sendBreathPrompt(_ nudge: DailyNudge) {
        guard let session = session else {
            debugPrint("[ConnectivityService] No active session for breath prompt.")
            return
        }

        let message: [String: Any] = [
            "type": "breathPrompt",
            "title": nudge.title,
            "description": nudge.description,
            "durationMinutes": nudge.durationMinutes ?? 3,
            "category": nudge.category.rawValue
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                debugPrint(
                    "[ConnectivityService] Breath prompt sendMessage failed: "
                    + "\(error.localizedDescription)"
                )
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Outbound: Action Plan

    /// Sends a ``WatchActionPlan`` (daily + weekly + monthly buddy recommendations)
    /// to the paired Apple Watch.
    ///
    /// Uses `sendMessage` for live delivery when the watch is reachable,
    /// falling back to `transferUserInfo` for guaranteed background delivery.
    ///
    /// - Parameter plan: The action plan to transmit.
    func sendActionPlan(_ plan: WatchActionPlan) {
        guard let session = session else {
            debugPrint("[ConnectivityService] No active session for action plan.")
            return
        }

        guard let message = ConnectivityMessageCodec.encode(
            plan,
            type: .actionPlan
        ) else {
            debugPrint("[ConnectivityService] Failed to encode action plan payload.")
            return
        }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                debugPrint(
                    "[ConnectivityService] Action plan sendMessage failed, "
                    + "using transferUserInfo: \(error.localizedDescription)"
                )
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Outbound: Check-In Request

    /// Sends a morning check-in prompt to the Apple Watch.
    ///
    /// - Parameter message: The check-in question to display.
    func sendCheckInPrompt(_ promptMessage: String) {
        guard let session = session else { return }

        let message: [String: Any] = [
            "type": "checkInPrompt",
            "message": promptMessage
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                debugPrint(
                    "[ConnectivityService] Check-in sendMessage failed: "
                    + "\(error.localizedDescription)"
                )
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Inbound Handling

    /// Processes an incoming message dictionary from the watch.
    ///
    /// Dispatches to the appropriate handler based on the "type" key.
    /// Called from nonisolated WCSessionDelegate callbacks.
    nonisolated private func handleIncomingMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else {
            debugPrint("[ConnectivityService] Received message without type key.")
            return
        }

        switch type {
        case "feedback":
            handleFeedbackMessage(message)
        case "requestAssessment":
            // The watch is requesting the latest assessment.
            // This is handled via the reply handler in didReceiveMessage.
            break
        default:
            debugPrint("[ConnectivityService] Unknown message type: \(type)")
        }
    }

    /// Decodes a `WatchFeedbackPayload` from the incoming message and publishes it.
    nonisolated private func handleFeedbackMessage(_ message: [String: Any]) {
        guard let payload = ConnectivityMessageCodec.decode(
            WatchFeedbackPayload.self,
            from: message
        ) else {
            debugPrint("[ConnectivityService] Feedback message missing or invalid payload.")
            return
        }

        Task { @MainActor [weak self] in
            self?.latestWatchFeedback = payload
            self?.localStore.saveLastFeedback(payload)
        }
    }

    private func currentAssessment() -> HeartAssessment? {
        if let latestAssessment {
            return latestAssessment
        }
        return localStore.loadHistory().last?.assessment
    }
}

// MARK: - WCSessionDelegate

extension ConnectivityService: WCSessionDelegate {

    /// Called when the session activation completes.
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isWatchReachable = reachable
        }

        if let error = error {
            debugPrint("[ConnectivityService] Activation error: \(error.localizedDescription)")
        } else {
            debugPrint("[ConnectivityService] Activation completed with state: \(activationState.rawValue)")
        }
    }

    /// Called when the session transitions to the inactive state.
    ///
    /// Required for iOS WCSessionDelegate conformance. No-op; the session
    /// will be reactivated automatically.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        debugPrint("[ConnectivityService] Session became inactive.")
    }

    /// Called when the session transitions to the deactivated state.
    ///
    /// Required for iOS WCSessionDelegate conformance. Reactivates the session
    /// to prepare for a new paired watch.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        debugPrint("[ConnectivityService] Session deactivated. Reactivating...")
        session.activate()
    }

    /// Called when the watch reachability status changes.
    ///
    /// When the watch becomes reachable, proactively push the latest cached
    /// assessment so the watch UI updates without needing to request it.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isWatchReachable = reachable
            if reachable, let assessment = self.latestAssessment {
                self.sendAssessment(assessment)
            }
        }
    }

    /// Handles a live message from the watch (no reply expected).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        handleIncomingMessage(message)
    }

    /// Handles a live message from the watch that expects a reply.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if let type = message["type"] as? String,
           type == ConnectivityMessageType.requestAssessment.rawValue {
            Task { @MainActor [weak self] in
                guard let self else {
                    replyHandler(ConnectivityMessageCodec.errorMessage("Connectivity service unavailable."))
                    return
                }

                guard let assessment = self.currentAssessment(),
                      let response = ConnectivityMessageCodec.encode(
                        assessment,
                        type: .assessment
                      ) else {
                    replyHandler(ConnectivityMessageCodec.errorMessage(
                        "No assessment available yet. Open Thump on your iPhone to refresh."
                    ))
                    return
                }

                replyHandler(response)
            }
            return
        }

        handleIncomingMessage(message)
        replyHandler(ConnectivityMessageCodec.acknowledgement())
    }

    /// Handles background `transferUserInfo` deliveries from the watch.
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        handleIncomingMessage(userInfo)
    }
}

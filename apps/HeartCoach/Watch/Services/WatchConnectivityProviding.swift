// WatchConnectivityProviding.swift
// Thump Watch
//
// Protocol abstraction over WatchConnectivity for testability.
// Allows unit tests to inject mock connectivity without requiring
// a paired iPhone or WCSession.
//
// Driven by: SKILL_SDE_TEST_SCAFFOLDING (orchestrator v0.3.0)
// Acceptance: Mock conforming type can simulate phone messages in tests.
// Platforms: watchOS 10+

import Foundation
import Combine

// MARK: - Watch Connectivity Provider Protocol

/// Abstraction over watch connectivity that enables dependency injection
/// and mock-based testing without a real WCSession.
///
/// Conforming types manage the session lifecycle, receive assessment
/// updates from the companion iOS app, and transmit feedback payloads.
///
/// Usage:
/// ```swift
/// // Production
/// let provider: WatchConnectivityProviding = WatchConnectivityService()
///
/// // Testing
/// let provider: WatchConnectivityProviding = MockWatchConnectivityProvider()
/// provider.simulateAssessmentReceived(assessment)
/// ```
public protocol WatchConnectivityProviding: AnyObject, ObservableObject {
    /// The most recent assessment received from the companion phone app.
    var latestAssessment: HeartAssessment? { get }

    /// Whether the paired iPhone is currently reachable.
    var isPhoneReachable: Bool { get }

    /// Timestamp of the last successful assessment sync.
    var lastSyncDate: Date? { get }

    /// User-facing error message when communication fails.
    var connectionError: String? { get set }

    /// Send daily feedback to the companion phone app.
    /// - Parameter feedback: The user's daily feedback to transmit.
    /// - Returns: `true` if the message was dispatched successfully.
    @discardableResult
    func sendFeedback(_ feedback: DailyFeedback) -> Bool

    /// Request the latest assessment from the companion phone app.
    func requestLatestAssessment()
}

// MARK: - WatchConnectivityService Conformance

extension WatchConnectivityService: WatchConnectivityProviding {}

// MARK: - Mock Watch Connectivity Provider

/// Mock implementation of `WatchConnectivityProviding` for unit tests.
///
/// Returns deterministic, configurable connectivity behavior without
/// requiring a paired iPhone or active WCSession.
///
/// Features:
/// - Configurable reachability and assessment state
/// - Simulated assessment delivery via `simulateAssessmentReceived`
/// - Call tracking for verification in tests
/// - Configurable feedback send behavior (success/failure)
@MainActor
public final class MockWatchConnectivityProvider: ObservableObject, WatchConnectivityProviding {

    // MARK: - Published State

    @Published public var latestAssessment: HeartAssessment?
    @Published public var isPhoneReachable: Bool
    @Published public var lastSyncDate: Date?
    @Published public var connectionError: String?

    // MARK: - Configuration

    /// Whether `sendFeedback` should report success.
    public var shouldSendSucceed: Bool

    /// Whether `requestLatestAssessment` should simulate a response.
    public var shouldRespondToRequest: Bool

    /// Assessment to deliver when `requestLatestAssessment` is called.
    public var assessmentToDeliver: HeartAssessment?

    /// Error message to set when request fails.
    public var requestErrorMessage: String?

    // MARK: - Call Tracking

    /// Number of times `sendFeedback` was called.
    public private(set) var sendFeedbackCallCount: Int = 0

    /// The most recent feedback sent via `sendFeedback`.
    public private(set) var lastSentFeedback: DailyFeedback?

    /// Number of times `requestLatestAssessment` was called.
    public private(set) var requestAssessmentCallCount: Int = 0

    // MARK: - Init

    public init(
        isPhoneReachable: Bool = true,
        shouldSendSucceed: Bool = true,
        shouldRespondToRequest: Bool = true,
        assessmentToDeliver: HeartAssessment? = nil,
        requestErrorMessage: String? = nil
    ) {
        self.isPhoneReachable = isPhoneReachable
        self.shouldSendSucceed = shouldSendSucceed
        self.shouldRespondToRequest = shouldRespondToRequest
        self.assessmentToDeliver = assessmentToDeliver
        self.requestErrorMessage = requestErrorMessage
    }

    // MARK: - Protocol Conformance

    @discardableResult
    public func sendFeedback(_ feedback: DailyFeedback) -> Bool {
        sendFeedbackCallCount += 1
        lastSentFeedback = feedback
        return shouldSendSucceed
    }

    public func requestLatestAssessment() {
        requestAssessmentCallCount += 1

        if !isPhoneReachable {
            connectionError = "iPhone not reachable. Open Thump on your iPhone."
            return
        }

        connectionError = nil

        if shouldRespondToRequest, let assessment = assessmentToDeliver {
            latestAssessment = assessment
            lastSyncDate = Date()
        } else if let errorMessage = requestErrorMessage {
            connectionError = errorMessage
        }
    }

    // MARK: - Test Helpers

    /// Simulate receiving an assessment from the phone.
    public func simulateAssessmentReceived(_ assessment: HeartAssessment) {
        latestAssessment = assessment
        lastSyncDate = Date()
    }

    /// Simulate phone reachability change.
    public func simulateReachabilityChange(_ reachable: Bool) {
        isPhoneReachable = reachable
    }

    /// Reset all call counts and state.
    public func reset() {
        sendFeedbackCallCount = 0
        lastSentFeedback = nil
        requestAssessmentCallCount = 0
        latestAssessment = nil
        lastSyncDate = nil
        connectionError = nil
    }
}

// AnalyticsEvents.swift
// Thump iOS
//
// Defines all analytics event names as a type-safe enum and
// provides a lightweight convenience wrapper around
// ObservabilityService for tracking events throughout the app.
// Platforms: iOS 17+

import Foundation

// MARK: - Analytics Event Name

/// Canonical event names tracked across the Thump iOS app.
///
/// Raw values use snake_case to match standard analytics conventions
/// and remain consistent across any future backend provider.
enum AnalyticsEventName: String, CaseIterable, Sendable {

    // Onboarding
    case onboardingStarted       = "onboarding_started"
    case onboardingCompleted     = "onboarding_completed"
    case healthkitAuthorized     = "healthkit_authorized"

    // Core screens
    case dashboardViewed         = "dashboard_viewed"
    case trendsViewed            = "trends_viewed"
    case insightsViewed          = "insights_viewed"

    // Subscription
    case paywallShown            = "paywall_shown"
    case subscriptionStarted     = "subscription_started"
    case subscriptionRestored    = "subscription_restored"

    // Nudges
    case nudgeCompleted          = "nudge_completed"
    case nudgeSkipped            = "nudge_skipped"

    // Watch
    case watchFeedbackReceived = "watch_feedback_received"

    // Sign In
    case appleSignInCompleted    = "apple_sign_in_completed"
    case appleSignInFailed       = "apple_sign_in_failed"

    // AI / Assessment
    case assessmentGenerated = "assessment_generated"
}

// MARK: - Analytics Tracker

/// Convenience wrapper around ``ObservabilityService`` for tracking
/// typed analytics events.
///
/// Provides a shared instance backed by a default ``ObservabilityService``
/// so callers can fire events with minimal boilerplate:
/// ```swift
/// Analytics.shared.track(.dashboardViewed)
/// Analytics.shared.track(.nudgeCompleted, properties: ["category": "walk"])
/// ```
final class Analytics {

    // MARK: - Singleton

    static let shared = Analytics()

    // MARK: - Properties

    /// The underlying observability service that dispatches events
    /// to registered analytics providers.
    let observability: ObservabilityService

    // MARK: - Initialization

    /// Creates a tracker backed by the given ``ObservabilityService``.
    ///
    /// - Parameter observability: The service to forward events to.
    ///   Defaults to a new instance (debug logging auto-enabled in DEBUG).
    init(observability: ObservabilityService = ObservabilityService()) {
        self.observability = observability
    }

    // MARK: - Tracking

    /// Track a typed analytics event with no additional properties.
    ///
    /// - Parameter event: The event name to track.
    func track(_ event: AnalyticsEventName) {
        observability.track(name: event.rawValue)
    }

    /// Track a typed analytics event with additional properties.
    ///
    /// - Parameters:
    ///   - event: The event name to track.
    ///   - properties: Flat dictionary of event metadata.
    func track(_ event: AnalyticsEventName, properties: [String: String]) {
        observability.track(name: event.rawValue, properties: properties)
    }

    /// Register an analytics provider (e.g. Mixpanel, Amplitude) that
    /// will receive all future tracked events.
    ///
    /// - Parameter provider: The provider to register.
    func register(provider: AnalyticsProvider) {
        observability.register(provider: provider)
    }
}

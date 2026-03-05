// ConfigService.swift
// ThumpCore
//
// App-wide configuration values, default thresholds, feature flags,
// and tier-based feature gating helpers.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Config Service

/// Centralized, static configuration for the Thump engine and services.
///
/// All values are compile-time constants or derived from the current
/// ``SubscriptionTier``. Nothing in this struct is mutable at runtime
/// -- feature flags are toggled via build configuration or remote config
/// in a future release.
public struct ConfigService: Sendable {

    // MARK: - Lookback & Window Defaults

    /// Number of historical days used by ``HeartTrendEngine`` for baseline
    /// computation (median / MAD calculations).
    public static let defaultLookbackWindow: Int = 21

    /// Number of recent days used for linear-regression slope checks
    /// when detecting multi-day regressions.
    public static let defaultRegressionWindow: Int = 7

    /// Minimum number of data points required before the engine
    /// will produce a high-confidence assessment.
    public static let minimumHighConfidenceDays: Int = 14

    /// Minimum data points for medium confidence.
    public static let minimumMediumConfidenceDays: Int = 7

    // MARK: - Default Alert Policy

    /// The default ``AlertPolicy`` shipped with the app.
    /// Individual thresholds can be overridden by Coach-tier users
    /// in a future settings screen.
    public static let defaultAlertPolicy: AlertPolicy = AlertPolicy(
        anomalyHigh: 2.0,
        regressionSlope: -0.3,
        stressRHRZ: 1.5,
        stressHRVZ: -1.5,
        stressRecoveryZ: -1.5,
        cooldownHours: 8.0,
        maxAlertsPerDay: 3
    )

    // MARK: - Correlation Engine

    /// Minimum number of paired data points required for a meaningful
    /// Pearson correlation calculation.
    public static let minimumCorrelationPoints: Int = 7

    // MARK: - Sync & Connectivity

    /// Minimum interval (in seconds) between consecutive Watch-to-Phone
    /// sync attempts to avoid excessive battery drain.
    public static let minimumSyncIntervalSeconds: TimeInterval = 300

    /// Maximum number of ``StoredSnapshot`` entries to keep in local storage
    /// before trimming the oldest records.
    public static let maxStoredSnapshots: Int = 365

    // MARK: - Feature Flags

    /// Whether the experimental weekly-report generation is enabled.
    public static let enableWeeklyReports: Bool = true

    /// Whether correlation insight cards are shown on the dashboard.
    public static let enableCorrelationInsights: Bool = true

    /// Whether the Watch complication tap-to-feedback flow is active.
    public static let enableWatchFeedbackCapture: Bool = true

    /// Whether push-based anomaly alerts are enabled.
    public static let enableAnomalyAlerts: Bool = true

    /// Whether the onboarding questionnaire collects baseline preferences.
    public static let enableOnboardingQuestionnaire: Bool = false

    // MARK: - Tier-Based Feature Gating

    /// Returns `true` when the given tier allows access to the full
    /// metric dashboard (HRV, Recovery HR, VO2, zone load).
    public static func canAccessFullMetrics(tier: SubscriptionTier) -> Bool {
        tier.canAccessFullMetrics
    }

    /// Returns `true` when the given tier allows personalized daily nudges
    /// with dosage information.
    public static func canAccessNudges(tier: SubscriptionTier) -> Bool {
        tier.canAccessNudges
    }

    /// Returns `true` when the given tier allows weekly reports
    /// and multi-week trend analysis.
    public static func canAccessReports(tier: SubscriptionTier) -> Bool {
        tier.canAccessReports
    }

    /// Returns `true` when the given tier allows correlation
    /// insight cards (activity vs. trend).
    public static func canAccessCorrelations(tier: SubscriptionTier) -> Bool {
        tier.canAccessCorrelations
    }

    /// Returns the complete set of feature strings available for a tier.
    public static func availableFeatures(for tier: SubscriptionTier) -> [String] {
        tier.features
    }

    /// Returns `true` when a given feature flag name is enabled.
    /// Useful for generic gating in view code without hard-coding booleans.
    public static func isFeatureEnabled(_ featureName: String) -> Bool {
        switch featureName {
        case "weeklyReports":          return enableWeeklyReports
        case "correlationInsights":    return enableCorrelationInsights
        case "watchFeedbackCapture":   return enableWatchFeedbackCapture
        case "anomalyAlerts":          return enableAnomalyAlerts
        case "onboardingQuestionnaire": return enableOnboardingQuestionnaire
        default:                       return false
        }
    }

    // MARK: - Engine Factory

    /// Convenience factory that builds a ``HeartTrendEngine`` with the
    /// default configuration values.
    public static func makeDefaultEngine() -> HeartTrendEngine {
        HeartTrendEngine(
            lookbackWindow: defaultLookbackWindow,
            policy: defaultAlertPolicy
        )
    }

    // MARK: - Init Prevention

    /// `ConfigService` is a namespace; it should not be instantiated.
    private init() {}
}

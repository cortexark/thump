// UserModels.swift
// ThumpCore
//
// User profile, subscription, preferences, and persistence models.
// Extracted from HeartModels.swift for domain isolation.
//
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Stored Snapshot

/// Persistence wrapper pairing a snapshot with its optional assessment.
public struct StoredSnapshot: Codable, Equatable, Sendable {
    public let snapshot: HeartSnapshot
    public let assessment: HeartAssessment?

    public init(snapshot: HeartSnapshot, assessment: HeartAssessment? = nil) {
        self.snapshot = snapshot
        self.assessment = assessment
    }
}

// MARK: - Alert Meta

/// Metadata tracking alert frequency to prevent alert fatigue.
public struct AlertMeta: Codable, Equatable, Sendable {
    /// Timestamp of the most recent alert fired.
    public var lastAlertAt: Date?

    /// Number of alerts fired today.
    public var alertsToday: Int

    /// Day stamp (yyyy-MM-dd) for resetting daily count.
    public var alertsDayStamp: String

    public init(
        lastAlertAt: Date? = nil,
        alertsToday: Int = 0,
        alertsDayStamp: String = ""
    ) {
        self.lastAlertAt = lastAlertAt
        self.alertsToday = alertsToday
        self.alertsDayStamp = alertsDayStamp
    }
}

// MARK: - Watch Feedback Payload

/// Payload for syncing watch feedback to the phone.
public struct WatchFeedbackPayload: Codable, Equatable, Sendable {
    /// Unique event identifier for deduplication.
    public let eventId: String

    /// Date of the feedback.
    public let date: Date

    /// User's feedback response.
    public let response: DailyFeedback

    /// Source device identifier.
    public let source: String

    public init(
        eventId: String = UUID().uuidString,
        date: Date,
        response: DailyFeedback,
        source: String
    ) {
        self.eventId = eventId
        self.date = date
        self.response = response
        self.source = source
    }
}

// MARK: - Feedback Preferences

/// User preferences for what dashboard content to show.
public struct FeedbackPreferences: Codable, Equatable, Sendable {
    /// Show daily buddy suggestions.
    public var showBuddySuggestions: Bool

    /// Show the daily mood check-in card.
    public var showDailyCheckIn: Bool

    /// Show stress insights on the dashboard.
    public var showStressInsights: Bool

    /// Show weekly trend summaries.
    public var showWeeklyTrends: Bool

    /// Show streak badge.
    public var showStreakBadge: Bool

    public init(
        showBuddySuggestions: Bool = true,
        showDailyCheckIn: Bool = true,
        showStressInsights: Bool = true,
        showWeeklyTrends: Bool = true,
        showStreakBadge: Bool = true
    ) {
        self.showBuddySuggestions = showBuddySuggestions
        self.showDailyCheckIn = showDailyCheckIn
        self.showStressInsights = showStressInsights
        self.showWeeklyTrends = showWeeklyTrends
        self.showStreakBadge = showStreakBadge
    }
}

// MARK: - Biological Sex

/// Biological sex for physiological norm stratification.
/// Used by BioAgeEngine, HRV norms, and VO2 Max expected values.
/// Not a gender identity field — purely for metric accuracy.
public enum BiologicalSex: String, Codable, Equatable, Sendable, CaseIterable {
    case male
    case female
    case notSet

    /// User-facing label.
    public var displayLabel: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .notSet: return "Prefer not to say"
        }
    }

    /// SF Symbol icon.
    public var icon: String {
        switch self {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        case .notSet: return "person.fill"
        }
    }
}

// MARK: - User Profile

/// Local user profile for personalization and streak tracking.
public struct UserProfile: Codable, Equatable, Sendable {
    /// User's display name.
    public var displayName: String

    /// Date the user joined / completed onboarding.
    public var joinDate: Date

    /// Whether onboarding has been completed.
    public var onboardingComplete: Bool

    /// Current consecutive-day engagement streak.
    public var streakDays: Int

    /// The last calendar date a streak credit was granted.
    /// Used to prevent same-day nudge taps from inflating the streak.
    public var lastStreakCreditDate: Date?

    /// Dates on which the user explicitly completed a nudge action.
    /// Keyed by ISO date string (yyyy-MM-dd) for Codable simplicity.
    public var nudgeCompletionDates: Set<String>

    /// User's date of birth for bio age calculation. Nil if not set.
    public var dateOfBirth: Date?

    /// Biological sex for metric norm stratification.
    public var biologicalSex: BiologicalSex

    /// Email address from Sign in with Apple (optional, only provided on first sign-in).
    public var email: String?

    /// Date when the launch free year started (first sign-in).
    /// Nil if the user signed up after the launch promotion ends.
    public var launchFreeStartDate: Date?

    public init(
        displayName: String = "",
        joinDate: Date = Date(),
        onboardingComplete: Bool = false,
        streakDays: Int = 0,
        lastStreakCreditDate: Date? = nil,
        nudgeCompletionDates: Set<String> = [],
        dateOfBirth: Date? = nil,
        biologicalSex: BiologicalSex = .notSet,
        email: String? = nil,
        launchFreeStartDate: Date? = nil
    ) {
        self.displayName = displayName
        self.joinDate = joinDate
        self.onboardingComplete = onboardingComplete
        self.streakDays = streakDays
        self.lastStreakCreditDate = lastStreakCreditDate
        self.nudgeCompletionDates = nudgeCompletionDates
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
        self.email = email
        self.launchFreeStartDate = launchFreeStartDate
    }

    /// Computed chronological age in years from date of birth.
    public var chronologicalAge: Int? {
        guard let dob = dateOfBirth else { return nil }
        let components = Calendar.current.dateComponents([.year], from: dob, to: Date())
        return components.year
    }

    /// Whether the user is currently within the launch free year.
    public var isInLaunchFreeYear: Bool {
        guard let start = launchFreeStartDate else { return false }
        guard let expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: start) else { return false }
        return Date() < expiryDate
    }

    /// Days remaining in the launch free year. Returns 0 if expired or not enrolled.
    public var launchFreeDaysRemaining: Int {
        guard let start = launchFreeStartDate else { return 0 }
        guard let expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: start) else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
        return max(0, days)
    }
}

// MARK: - Subscription Tier

/// Subscription tiers with feature gating and pricing.
public enum SubscriptionTier: String, Codable, Equatable, Sendable, CaseIterable {
    case free
    case pro
    case coach
    case family

    /// User-facing tier name.
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .coach: return "Coach"
        case .family: return "Family"
        }
    }

    /// Monthly price in USD.
    public var monthlyPrice: Double {
        switch self {
        case .free: return 0.0
        case .pro: return 3.99
        case .coach: return 6.99
        case .family: return 0.0  // Family is annual-only
        }
    }

    /// Annual price in USD.
    public var annualPrice: Double {
        switch self {
        case .free: return 0.0
        case .pro: return 29.99
        case .coach: return 59.99
        case .family: return 79.99
        }
    }

    /// List of features included in this tier.
    public var features: [String] {
        switch self {
        case .free:
            return [
                "Daily wellness snapshot (Building Momentum / Holding Steady / Check In)",
                "Basic trend view for resting heart rate and steps",
                "Watch feedback capture"
            ]
        case .pro:
            return [
                "Full wellness dashboard (HRV, Recovery, VO2, zone activity)",
                "Personalized daily suggestions",
                "Heads-up when patterns shift",
                "Stress pattern awareness",
                "Connection cards (activity vs. trends)",
                "Pattern strength on all insights"
            ]
        case .coach:
            return [
                "Everything in Pro",
                "Weekly wellness review and gentle plan tweaks",
                "Multi-week trend exploration and progress snapshots",
                "Shareable PDF wellness summaries",
                "Priority pattern alerts"
            ]
        case .family:
            return [
                "Everything in Coach for up to 5 members",
                "Shared goals and accountability view",
                "Caregiver mode for family members"
            ]
        }
    }

    /// Whether this tier grants access to full metric dashboards.
    /// NOTE: All features are currently free for all users.
    public var canAccessFullMetrics: Bool {
        return true
    }

    /// Whether this tier grants access to personalized nudges.
    /// NOTE: All features are currently free for all users.
    public var canAccessNudges: Bool {
        return true
    }

    /// Whether this tier grants access to weekly reports and trend analysis.
    /// NOTE: All features are currently free for all users.
    public var canAccessReports: Bool {
        return true
    }

    /// Whether this tier grants access to activity-trend correlation analysis.
    /// NOTE: All features are currently free for all users.
    public var canAccessCorrelations: Bool {
        return true
    }
}

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

// MARK: - User Copy Profile

/// Routes mission copy to the appropriate tone pool.
/// Set to `.constrained` when life context indicates high stress, burnout, therapist
/// referral, or a chronic condition — language becomes gentler and more supportive.
public enum UserCopyProfile: String, Codable, Equatable, Sendable, CaseIterable {
    /// Default copy pool — direct, goal-oriented language.
    case autonomous
    /// Softer, supportive copy pool — for high-stress or clinical contexts.
    case constrained
}

// MARK: - Training Phase

/// The user's current training phase.
/// Used to adjust stress thresholds and suppress overtraining alerts
/// when elevated scores are expected (building load, tapering, etc.).
///
/// `peaking` and `racing` are defined now to lock the enum for Codable
/// migration safety, even though they are not yet surfaced in v1.7 UI.
public enum TrainingPhase: String, Codable, Equatable, Sendable, CaseIterable {
    /// No structured training phase active.
    case none
    /// Base building phase — progressive load increase.
    case building
    /// Pre-competition taper — reduced volume, maintained intensity.
    case tapering
    /// High-intensity interval training focus block.
    case hiit
    /// Race-peak sharpening phase (deferred — not surfaced in v1.7).
    case peaking
    /// Active race period (deferred — not surfaced in v1.7).
    case racing
}

// MARK: - Activity Type

/// The primary activity type the user trains in.
/// Routes AdviceComposer to the appropriate copy pool and scoring logic.
public enum ActivityType: String, Codable, Equatable, Sendable, CaseIterable {
    /// General fitness / mixed activity.
    case general
    /// Mind-body practices: yoga, pilates, stretching.
    case mindBody
    /// High-intensity interval training.
    case hiit
    /// Endurance sports: running, cycling, swimming.
    case endurance
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

    // MARK: - Design System v1.7 Fields

    /// Copy routing profile — determines which tone/language pool is used.
    /// Set to `.constrained` when life context is high stress, burnout,
    /// therapist referral, or chronic condition.
    public var copyProfile: UserCopyProfile

    /// The user's current structured training phase.
    /// Drives threshold adjustments in StressEngine.
    public var trainingPhase: TrainingPhase

    /// The user's primary activity type.
    /// Routes AdviceComposer copy pools and HIIT CNS binary logic.
    public var activityType: ActivityType

    /// Consecutive days with a daily stress score in the 0–44 "steady" range.
    /// Incremented by StressEngine; reset when score > 44 for 3 consecutive days.
    public var steadyStreakDays: Int

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
        launchFreeStartDate: Date? = nil,
        copyProfile: UserCopyProfile = .autonomous,
        trainingPhase: TrainingPhase = .none,
        activityType: ActivityType = .general,
        steadyStreakDays: Int = 0
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
        self.copyProfile = copyProfile
        self.trainingPhase = trainingPhase
        self.activityType = activityType
        self.steadyStreakDays = steadyStreakDays
    }

    // MARK: - Codable (migration-safe)

    /// Custom decoder so pre-v1.7 profiles (missing the four new fields)
    /// survive the upgrade without wiping existing user data.
    /// All v1.7 fields fall back to their defaults if not present in the stored JSON.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName          = try c.decode(String.self, forKey: .displayName)
        joinDate             = try c.decode(Date.self, forKey: .joinDate)
        onboardingComplete   = try c.decode(Bool.self, forKey: .onboardingComplete)
        streakDays           = try c.decode(Int.self, forKey: .streakDays)
        lastStreakCreditDate = try c.decodeIfPresent(Date.self, forKey: .lastStreakCreditDate)
        nudgeCompletionDates = (try? c.decode(Set<String>.self, forKey: .nudgeCompletionDates)) ?? []
        dateOfBirth          = try c.decodeIfPresent(Date.self, forKey: .dateOfBirth)
        biologicalSex        = (try? c.decode(BiologicalSex.self, forKey: .biologicalSex)) ?? .notSet
        email                = try c.decodeIfPresent(String.self, forKey: .email)
        launchFreeStartDate  = try c.decodeIfPresent(Date.self, forKey: .launchFreeStartDate)
        // v1.7 fields — default when absent (pre-v1.7 stored profiles)
        copyProfile          = (try? c.decode(UserCopyProfile.self, forKey: .copyProfile)) ?? .autonomous
        trainingPhase        = (try? c.decode(TrainingPhase.self, forKey: .trainingPhase)) ?? .none
        activityType         = (try? c.decode(ActivityType.self, forKey: .activityType)) ?? .general
        steadyStreakDays      = (try? c.decode(Int.self, forKey: .steadyStreakDays)) ?? 0
    }

    /// Computed chronological age in years from date of birth.
    public var chronologicalAge: Int? {
        guard let dob = dateOfBirth else { return nil }
        let components = Calendar.current.dateComponents([.year], from: dob, to: Date())
        return components.year
    }

    /// Approximate age in years derived from `dateOfBirth`.
    /// Mirrors `chronologicalAge` — present for StressEngine compatibility.
    public var ageApprox: Int? {
        chronologicalAge
    }

    /// `true` when the user is in any structured training phase.
    public var isInTrainingPhase: Bool {
        trainingPhase != .none
    }

    /// `true` when `steadyStreakDays` has reached or exceeded 14 days.
    /// Signals chronic steady-state for copy and threshold routing.
    public var isChronicSteady: Bool {
        steadyStreakDays >= 14
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

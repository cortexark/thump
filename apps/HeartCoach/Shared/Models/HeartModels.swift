// HeartModels.swift
// ThumpCore
//
// Complete domain models for the Thump shared engine.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Trend Status

/// The overall daily heart-health trend assessment.
public enum TrendStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case improving
    case stable
    case needsAttention
}

// MARK: - Confidence Level

/// Confidence in the assessment based on data completeness and history depth.
public enum ConfidenceLevel: String, Codable, Equatable, Sendable, CaseIterable {
    case high
    case medium
    case low

    /// User-facing display name.
    public var displayName: String {
        switch self {
        case .high: return "Strong Pattern"
        case .medium: return "Emerging Pattern"
        case .low: return "Early Signal"
        }
    }

    /// Named color for SwiftUI asset catalogs or programmatic mapping.
    public var colorName: String {
        switch self {
        case .high: return "confidenceHigh"
        case .medium: return "confidenceMedium"
        case .low: return "confidenceLow"
        }
    }

    /// SF Symbol icon name.
    public var icon: String {
        switch self {
        case .high: return "checkmark.seal.fill"
        case .medium: return "exclamationmark.triangle"
        case .low: return "questionmark.circle"
        }
    }
}

// MARK: - Daily Feedback

/// Watch-captured user feedback for the day's nudge.
public enum DailyFeedback: String, Codable, Equatable, Sendable, CaseIterable {
    case positive
    case negative
    case skipped
}

// MARK: - Nudge Category

/// Categories of coaching nudges mapped to lifestyle actions.
public enum NudgeCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case walk
    case rest
    case hydrate
    case breathe
    case moderate
    case celebrate
    case seekGuidance

    /// SF Symbol icon for this nudge category.
    public var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .rest: return "bed.double.fill"
        case .hydrate: return "drop.fill"
        case .breathe: return "wind"
        case .moderate: return "gauge.with.dots.needle.33percent"
        case .celebrate: return "star.fill"
        case .seekGuidance: return "heart.text.square"
        }
    }

    /// Named tint color for the nudge card.
    public var tintColorName: String {
        switch self {
        case .walk: return "nudgeWalk"
        case .rest: return "nudgeRest"
        case .hydrate: return "nudgeHydrate"
        case .breathe: return "nudgeBreathe"
        case .moderate: return "nudgeModerate"
        case .celebrate: return "nudgeCelebrate"
        case .seekGuidance: return "nudgeGuidance"
        }
    }
}

// MARK: - Heart Snapshot

/// A single day's health metrics snapshot from HealthKit or manual entry.
public struct HeartSnapshot: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier derived from the snapshot date.
    public var id: Date { date }

    /// Calendar date for this snapshot (midnight-aligned).
    public let date: Date

    /// Resting heart rate in BPM.
    public let restingHeartRate: Double?

    /// Heart rate variability (SDNN) in milliseconds.
    public let hrvSDNN: Double?

    /// Heart rate recovery at 1 minute post-exercise in BPM drop.
    public let recoveryHR1m: Double?

    /// Heart rate recovery at 2 minutes post-exercise in BPM drop.
    public let recoveryHR2m: Double?

    /// Estimated VO2 max in mL/kg/min.
    public let vo2Max: Double?

    /// Minutes spent in each heart rate zone (indexed 0-4 or custom).
    public let zoneMinutes: [Double]

    /// Total step count for the day.
    public let steps: Double?

    /// Walking minutes for the day.
    public let walkMinutes: Double?

    /// Workout minutes for the day.
    public let workoutMinutes: Double?

    /// Sleep duration in hours.
    public let sleepHours: Double?

    public init(
        date: Date,
        restingHeartRate: Double? = nil,
        hrvSDNN: Double? = nil,
        recoveryHR1m: Double? = nil,
        recoveryHR2m: Double? = nil,
        vo2Max: Double? = nil,
        zoneMinutes: [Double] = [],
        steps: Double? = nil,
        walkMinutes: Double? = nil,
        workoutMinutes: Double? = nil,
        sleepHours: Double? = nil
    ) {
        self.date = date
        self.restingHeartRate = restingHeartRate
        self.hrvSDNN = hrvSDNN
        self.recoveryHR1m = recoveryHR1m
        self.recoveryHR2m = recoveryHR2m
        self.vo2Max = vo2Max
        self.zoneMinutes = zoneMinutes
        self.steps = steps
        self.walkMinutes = walkMinutes
        self.workoutMinutes = workoutMinutes
        self.sleepHours = sleepHours
    }
}

// MARK: - Daily Nudge

/// A concrete coaching nudge with actionable content.
public struct DailyNudge: Codable, Equatable, Sendable {
    /// The category of this nudge.
    public let category: NudgeCategory

    /// Short nudge title (e.g. "Take a Gentle Walk").
    public let title: String

    /// Detailed description with actionable guidance.
    public let description: String

    /// Suggested duration in minutes, if applicable.
    public let durationMinutes: Int?

    /// SF Symbol icon name for display.
    public let icon: String

    public init(
        category: NudgeCategory,
        title: String,
        description: String,
        durationMinutes: Int? = nil,
        icon: String
    ) {
        self.category = category
        self.title = title
        self.description = description
        self.durationMinutes = durationMinutes
        self.icon = icon
    }
}

// MARK: - Heart Assessment

/// The complete daily assessment output from the trend engine.
public struct HeartAssessment: Codable, Equatable, Sendable {
    /// Overall trend status.
    public let status: TrendStatus

    /// Data confidence level.
    public let confidence: ConfidenceLevel

    /// Composite anomaly score (0 = normal, higher = more anomalous).
    public let anomalyScore: Double

    /// Whether a multi-day regression trend was detected.
    public let regressionFlag: Bool

    /// Whether a stress-like physiological pattern was detected.
    public let stressFlag: Bool

    /// Composite cardio fitness score (0-100 scale), nil if insufficient data.
    public let cardioScore: Double?

    /// The daily coaching nudge.
    public let dailyNudge: DailyNudge

    /// Human-readable explanation of the assessment.
    public let explanation: String

    /// Convenience accessor for a one-line nudge summary.
    public var dailyNudgeText: String {
        if let duration = dailyNudge.durationMinutes {
            return "\(dailyNudge.title) (\(duration) min): \(dailyNudge.description)"
        }
        return "\(dailyNudge.title): \(dailyNudge.description)"
    }

    public init(
        status: TrendStatus,
        confidence: ConfidenceLevel,
        anomalyScore: Double,
        regressionFlag: Bool,
        stressFlag: Bool,
        cardioScore: Double?,
        dailyNudge: DailyNudge,
        explanation: String
    ) {
        self.status = status
        self.confidence = confidence
        self.anomalyScore = anomalyScore
        self.regressionFlag = regressionFlag
        self.stressFlag = stressFlag
        self.cardioScore = cardioScore
        self.dailyNudge = dailyNudge
        self.explanation = explanation
    }
}

// MARK: - Correlation Result

/// Result of correlating an activity factor with a heart metric trend.
public struct CorrelationResult: Codable, Equatable, Sendable {
    /// Name of the factor being correlated (e.g. "Daily Steps").
    public let factorName: String

    /// Pearson correlation coefficient (-1.0 to 1.0).
    public let correlationStrength: Double

    /// Human-readable interpretation of the correlation.
    public let interpretation: String

    /// Confidence in the correlation result.
    public let confidence: ConfidenceLevel

    /// Whether the correlation is moving in a beneficial direction for cardiovascular health.
    ///
    /// For example, a negative r between steps and RHR is beneficial (more steps → lower RHR),
    /// whereas a negative r between sleep and HRV would not be.
    public let isBeneficial: Bool

    public init(
        factorName: String,
        correlationStrength: Double,
        interpretation: String,
        confidence: ConfidenceLevel,
        isBeneficial: Bool = true
    ) {
        self.factorName = factorName
        self.correlationStrength = correlationStrength
        self.interpretation = interpretation
        self.confidence = confidence
        self.isBeneficial = isBeneficial
    }
}

// MARK: - Weekly Report

/// Aggregated weekly performance report.
public struct WeeklyReport: Codable, Equatable, Sendable {

    /// Weekly trend direction.
    public enum TrendDirection: String, Codable, Equatable, Sendable {
        case up
        case flat
        case down
    }

    /// Start date of the reporting week.
    public let weekStart: Date

    /// End date of the reporting week.
    public let weekEnd: Date

    /// Average cardio score across the week (0-100).
    public let avgCardioScore: Double?

    /// Direction the trend moved over the week.
    public let trendDirection: TrendDirection

    /// The most significant insight from the week.
    public let topInsight: String

    /// Percentage of nudges completed (0.0-1.0).
    public let nudgeCompletionRate: Double

    public init(
        weekStart: Date,
        weekEnd: Date,
        avgCardioScore: Double?,
        trendDirection: TrendDirection,
        topInsight: String,
        nudgeCompletionRate: Double
    ) {
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.avgCardioScore = avgCardioScore
        self.trendDirection = trendDirection
        self.topInsight = topInsight
        self.nudgeCompletionRate = nudgeCompletionRate
    }
}

// MARK: - Stress Level

/// Friendly stress level categories derived from HRV-based stress scoring.
///
/// Each level maps to a 0-100 score range and carries a friendly,
/// non-clinical display name suitable for the Thump voice.
public enum StressLevel: String, Codable, Equatable, Sendable, CaseIterable {
    case relaxed
    case balanced
    case elevated

    /// User-facing display name using friendly, non-medical language.
    public var displayName: String {
        switch self {
        case .relaxed: return "Feeling Relaxed"
        case .balanced: return "Finding Balance"
        case .elevated: return "Running Hot"
        }
    }

    /// SF Symbol icon for this stress level.
    public var icon: String {
        switch self {
        case .relaxed: return "leaf.fill"
        case .balanced: return "circle.grid.cross.fill"
        case .elevated: return "flame.fill"
        }
    }

    /// Named color for SwiftUI tinting.
    public var colorName: String {
        switch self {
        case .relaxed: return "stressRelaxed"
        case .balanced: return "stressBalanced"
        case .elevated: return "stressElevated"
        }
    }

    /// Friendly description of the current state.
    public var friendlyMessage: String {
        switch self {
        case .relaxed:
            return "You seem pretty relaxed right now"
        case .balanced:
            return "Things look balanced"
        case .elevated:
            return "You might be running a bit hot"
        }
    }

    /// Creates a stress level from a 0-100 score.
    ///
    /// - Parameter score: Stress score in the 0-100 range.
    /// - Returns: The corresponding stress level category.
    public static func from(score: Double) -> StressLevel {
        let clamped = max(0, min(100, score))
        if clamped <= 33 {
            return .relaxed
        } else if clamped <= 66 {
            return .balanced
        } else {
            return .elevated
        }
    }
}

// MARK: - Stress Result

/// The output of a single stress computation, pairing a numeric score
/// with its categorical level and a friendly description.
public struct StressResult: Codable, Equatable, Sendable {
    /// Stress score on a 0-100 scale (lower is more relaxed).
    public let score: Double

    /// Categorical stress level derived from the score.
    public let level: StressLevel

    /// Friendly, non-clinical description of the result.
    public let description: String

    public init(score: Double, level: StressLevel, description: String) {
        self.score = score
        self.level = level
        self.description = description
    }
}

// MARK: - Stress Data Point

/// A single data point in a stress trend time series.
public struct StressDataPoint: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier derived from the date.
    public var id: Date { date }

    /// The date this data point represents.
    public let date: Date

    /// Stress score on a 0-100 scale.
    public let score: Double

    /// Categorical stress level for this point.
    public let level: StressLevel

    public init(date: Date, score: Double, level: StressLevel) {
        self.date = date
        self.score = score
        self.level = level
    }
}

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

    public init(
        displayName: String = "",
        joinDate: Date = Date(),
        onboardingComplete: Bool = false,
        streakDays: Int = 0
    ) {
        self.displayName = displayName
        self.joinDate = joinDate
        self.onboardingComplete = onboardingComplete
        self.streakDays = streakDays
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

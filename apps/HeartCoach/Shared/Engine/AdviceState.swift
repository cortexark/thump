// AdviceState.swift
// Thump Shared
//
// Semantic state model for all coaching decisions. Uses enums and
// template IDs, NOT user-facing strings. The AdvicePresenter layer
// converts AdviceState to localized copy.
//
// Produced by AdviceComposer from a DailyEngineBundle.
// Consumed by views via AdvicePresenter.
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Advice State

/// Immutable semantic representation of all coaching decisions.
///
/// Every field is an enum, ID, or numeric target — never user-facing text.
/// The `AdvicePresenter` maps these to localized strings for display.
struct AdviceState: Codable, Sendable, Equatable {

    /// Schema version for forward-compatible persistence.
    let schemaVersion: Int = 1

    // MARK: - Global State

    /// The overarching guidance mode for the day.
    let mode: GuidanceMode

    /// Risk assessment band.
    let riskBand: RiskBand

    /// Overtraining escalation state.
    let overtrainingState: OvertrainingState

    /// Whether sleep deprivation is flagged.
    let sleepDeprivationFlag: Bool

    /// Whether medical escalation is warranted.
    let medicalEscalationFlag: Bool

    // MARK: - UI Decisions (semantic, not presentational)

    /// Category for the hero message.
    let heroCategory: HeroCategory

    /// Template ID for the hero message (not final copy).
    let heroMessageID: String

    /// Buddy character mood category.
    let buddyMoodCategory: BuddyMoodCategory

    /// Template ID for the focus insight.
    let focusInsightID: String

    /// Template ID for the check badge text.
    let checkBadgeID: String

    /// Dynamic daily goals.
    let goals: [GoalSpec]

    /// Primary recovery driver (if in recovery mode).
    let recoveryDriver: RecoveryDriver?

    /// Stress guidance level for the stress screen.
    let stressGuidanceLevel: StressGuidanceLevel?

    /// Smart actions ordered by priority.
    let smartActions: [TypedSmartAction]

    /// Allowed exercise intensity for the day.
    let allowedIntensity: IntensityBand

    /// Nudge categories in priority order.
    let nudgePriorities: [NudgeCategory]

    /// Positivity anchor template ID (injected when negativity imbalance detected).
    let positivityAnchorID: String?

    /// Maximum total action items allowed for the day (V-015 budget).
    /// Counts buddy recs + smart actions + goal nudge directives + Thump Check directives.
    /// Views use this to trim buddy recommendations to fit within the remaining budget.
    let dailyActionBudget: Int
}

// MARK: - Supporting Enums

/// The overarching guidance mode for the day.
enum GuidanceMode: String, Codable, Sendable, Comparable {
    case pushDay
    case moderateMove
    case lightRecovery
    case fullRest
    case medicalCheck

    private var severity: Int {
        switch self {
        case .pushDay:       return 0
        case .moderateMove:  return 1
        case .lightRecovery: return 2
        case .fullRest:      return 3
        case .medicalCheck:  return 4
        }
    }

    static func < (lhs: GuidanceMode, rhs: GuidanceMode) -> Bool {
        lhs.severity < rhs.severity
    }
}

/// Risk assessment band derived from composite signals.
enum RiskBand: String, Codable, Sendable {
    case low
    case moderate
    case elevated
    case high
}

/// Overtraining escalation state (monotonically increasing with consecutive days).
enum OvertrainingState: String, Codable, Sendable, Comparable {
    case none
    case watch       // 3+ consecutive alert days
    case caution     // 5+ consecutive alert days
    case deload      // 7+ consecutive alert days
    case consult     // 10+ consecutive alert days

    private var severity: Int {
        switch self {
        case .none:    return 0
        case .watch:   return 1
        case .caution: return 2
        case .deload:  return 3
        case .consult: return 4
        }
    }

    static func < (lhs: OvertrainingState, rhs: OvertrainingState) -> Bool {
        lhs.severity < rhs.severity
    }
}

/// Category for the hero / banner message.
enum HeroCategory: String, Codable, Sendable {
    case celebrate       // Great day — push it
    case encourage       // Decent recovery — moderate
    case caution         // Take it easy
    case rest            // Full rest recommended
    case medical         // See a doctor
    case neutral         // Generic check-in
}

/// Buddy character mood, derived from composite signals.
enum BuddyMoodCategory: String, Codable, Sendable {
    case celebrating
    case encouraging
    case concerned
    case resting
    case neutral
}

/// Primary driver of recovery recommendation.
enum RecoveryDriver: String, Codable, Sendable {
    case lowSleep
    case lowHRV
    case highStress
    case overtraining
    case highRHR
}

/// Stress guidance level for the stress screen.
enum StressGuidanceLevel: String, Codable, Sendable {
    case relaxed
    case balanced
    case elevated
}

/// Typed smart action (replaces string-based routing).
enum TypedSmartAction: Codable, Sendable, Equatable {
    case breathingSession
    case walkSuggestion
    case journalPrompt(promptID: String)
    case breatheOnWatch
    case bedtimeWindDown(driverID: String)
    case morningCheckIn
    case restSuggestion
    case focusTime
    case stretch
}

/// Allowed exercise intensity band for the day.
enum IntensityBand: String, Codable, Sendable, Comparable {
    case rest      // No exercise
    case light     // Walking, stretching only
    case moderate  // Aerobic OK, skip HIIT
    case full      // No restrictions

    private var level: Int {
        switch self {
        case .rest:     return 0
        case .light:    return 1
        case .moderate: return 2
        case .full:     return 3
        }
    }

    static func < (lhs: IntensityBand, rhs: IntensityBand) -> Bool {
        lhs.level < rhs.level
    }
}

// MARK: - Goal Spec

/// Specification for a single dynamic daily goal.
struct GoalSpec: Codable, Sendable, Equatable {
    let category: GoalCategory
    let target: Double
    let current: Double
    let nudgeTextID: String
    let label: String

    enum GoalCategory: String, Codable, Sendable {
        case steps
        case activeMinutes
        case sleep
        case zone
    }
}

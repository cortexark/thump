// WatchSyncModels.swift
// ThumpCore
//
// Watch-specific sync models — action plans, quick logs, and entries
// transferred between iPhone and Apple Watch via WatchConnectivity.
// Extracted from HeartModels.swift for domain isolation.
//
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Quick Log Category

/// User-initiated quick-log entries from the Apple Watch.
/// These are one-tap actions — minimal friction, maximum engagement.
public enum QuickLogCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case water
    case caffeine
    case alcohol
    case sunlight
    case meditate
    case activity
    case mood

    /// Whether this category supports a running counter (tap = +1) rather than a single toggle.
    public var isCounter: Bool {
        switch self {
        case .water, .caffeine, .alcohol: return true
        default: return false
        }
    }

    /// SF Symbol icon for the action button.
    public var icon: String {
        switch self {
        case .water:    return "drop.fill"
        case .caffeine: return "cup.and.saucer.fill"
        case .alcohol:  return "wineglass.fill"
        case .sunlight: return "sun.max.fill"
        case .meditate: return "figure.mind.and.body"
        case .activity: return "figure.run"
        case .mood:     return "face.smiling.fill"
        }
    }

    /// Short label for the button.
    public var label: String {
        switch self {
        case .water:    return "Water"
        case .caffeine: return "Caffeine"
        case .alcohol:  return "Alcohol"
        case .sunlight: return "Sunlight"
        case .meditate: return "Meditate"
        case .activity: return "Activity"
        case .mood:     return "Mood"
        }
    }

    /// Unit label shown next to the counter (counters only).
    public var unit: String {
        switch self {
        case .water:    return "cups"
        case .caffeine: return "cups"
        case .alcohol:  return "drinks"
        default:        return ""
        }
    }

    /// Named tint color — gender-neutral palette.
    public var tintColorHex: UInt32 {
        switch self {
        case .water:    return 0x06B6D4  // Cyan
        case .caffeine: return 0xF59E0B  // Amber
        case .alcohol:  return 0x8B5CF6  // Violet
        case .sunlight: return 0xFBBF24  // Yellow
        case .meditate: return 0x0D9488  // Teal
        case .activity: return 0x22C55E  // Green
        case .mood:     return 0xEC4899  // Pink
        }
    }
}

// MARK: - Watch Action Plan

/// A lightweight, Codable summary of today's actions + weekly/monthly context
/// synced from the iPhone to the Apple Watch via WatchConnectivity.
///
/// Kept small (<65 KB) to stay well within WatchConnectivity message limits.
public struct WatchActionPlan: Codable, Sendable {

    // MARK: - Daily Actions

    /// Today's prioritised action items (max 4 — one per domain).
    public let dailyItems: [WatchActionItem]

    /// Date these daily items were generated.
    public let dailyDate: Date

    // MARK: - Weekly Summary

    /// Buddy-voiced weekly headline, e.g. "You nailed 5 of 7 days this week!"
    public let weeklyHeadline: String

    /// Average heart score for the week (0-100), if available.
    public let weeklyAvgScore: Double?

    /// Number of days this week the user met their activity goal.
    public let weeklyActiveDays: Int

    /// Number of days this week flagged as low-stress.
    public let weeklyLowStressDays: Int

    // MARK: - Monthly Summary

    /// Buddy-voiced monthly headline, e.g. "Your best month yet — HRV up 12%!"
    public let monthlyHeadline: String

    /// Month-over-month score delta (+/-).
    public let monthlyScoreDelta: Double?

    /// Month name string for display, e.g. "February".
    public let monthName: String

    public init(
        dailyItems: [WatchActionItem],
        dailyDate: Date = Date(),
        weeklyHeadline: String,
        weeklyAvgScore: Double? = nil,
        weeklyActiveDays: Int = 0,
        weeklyLowStressDays: Int = 0,
        monthlyHeadline: String,
        monthlyScoreDelta: Double? = nil,
        monthName: String
    ) {
        self.dailyItems = dailyItems
        self.dailyDate = dailyDate
        self.weeklyHeadline = weeklyHeadline
        self.weeklyAvgScore = weeklyAvgScore
        self.weeklyActiveDays = weeklyActiveDays
        self.weeklyLowStressDays = weeklyLowStressDays
        self.monthlyHeadline = monthlyHeadline
        self.monthlyScoreDelta = monthlyScoreDelta
        self.monthName = monthName
    }
}

/// A single daily action item carried in ``WatchActionPlan``.
public struct WatchActionItem: Codable, Identifiable, Sendable {
    public let id: UUID
    public let category: NudgeCategory
    public let title: String
    public let detail: String
    public let icon: String
    /// Optional reminder hour (0-23) for this item.
    public let reminderHour: Int?

    public init(
        id: UUID = UUID(),
        category: NudgeCategory,
        title: String,
        detail: String,
        icon: String,
        reminderHour: Int? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
        self.icon = icon
        self.reminderHour = reminderHour
    }
}

extension WatchActionPlan {
    /// Mock plan for Simulator previews and tests.
    public static var mock: WatchActionPlan {
        WatchActionPlan(
            dailyItems: [
                WatchActionItem(
                    category: .rest,
                    title: "Wind Down by 9 PM",
                    detail: "You averaged 6.2 hrs last week — aim for 7+.",
                    icon: "bed.double.fill",
                    reminderHour: 21
                ),
                WatchActionItem(
                    category: .breathe,
                    title: "Morning Breathe",
                    detail: "3 min of box breathing before you start your day.",
                    icon: "wind",
                    reminderHour: 7
                ),
                WatchActionItem(
                    category: .walk,
                    title: "Walk 12 More Minutes",
                    detail: "You're 12 min short of your 30-min daily goal.",
                    icon: "figure.walk",
                    reminderHour: nil
                ),
                WatchActionItem(
                    category: .sunlight,
                    title: "Step Outside at Lunch",
                    detail: "You tend to be sedentary 12–1 PM — ideal sunlight window.",
                    icon: "sun.max.fill",
                    reminderHour: 12
                )
            ],
            weeklyHeadline: "You nailed 5 of 7 days this week!",
            weeklyAvgScore: 72,
            weeklyActiveDays: 5,
            weeklyLowStressDays: 4,
            monthlyHeadline: "Your best month yet — keep it up!",
            monthlyScoreDelta: 8,
            monthName: "March"
        )
    }
}

/// A single quick-log entry recorded from the watch.
public struct QuickLogEntry: Codable, Equatable, Sendable {
    /// Unique event identifier for deduplication.
    public let eventId: String

    /// Timestamp of the log.
    public let date: Date

    /// What was logged.
    public let category: QuickLogCategory

    /// Source device.
    public let source: String

    public init(
        eventId: String = UUID().uuidString,
        date: Date = Date(),
        category: QuickLogCategory,
        source: String = "watch"
    ) {
        self.eventId = eventId
        self.date = date
        self.category = category
        self.source = source
    }
}

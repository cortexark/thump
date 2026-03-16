// ActionPlanModels.swift
// ThumpCore
//
// Weekly action plan models — items, categories, sunlight windows.
// Extracted from HeartModels.swift for domain isolation.
//
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Weekly Action Plan

/// A single actionable recommendation surfaced in the weekly report detail view.
public struct WeeklyActionItem: Identifiable, Sendable {
    public let id: UUID
    public let category: WeeklyActionCategory
    /// Short headline shown on the card, e.g. "Wind Down Earlier".
    public let title: String
    /// One-sentence context derived from the user's data.
    public let detail: String
    /// SF Symbol name.
    public let icon: String
    /// Accent color name from the asset catalog.
    public let colorName: String
    /// Whether the user can set a reminder for this action.
    public let supportsReminder: Bool
    /// Suggested reminder hour (0-23) for UNCalendarNotificationTrigger.
    public let suggestedReminderHour: Int?
    /// For sunlight items: the inferred time-of-day windows with per-window reminders.
    /// Nil for all other categories.
    public let sunlightWindows: [SunlightWindow]?

    public init(
        id: UUID = UUID(),
        category: WeeklyActionCategory,
        title: String,
        detail: String,
        icon: String,
        colorName: String,
        supportsReminder: Bool = false,
        suggestedReminderHour: Int? = nil,
        sunlightWindows: [SunlightWindow]? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
        self.icon = icon
        self.colorName = colorName
        self.supportsReminder = supportsReminder
        self.suggestedReminderHour = suggestedReminderHour
        self.sunlightWindows = sunlightWindows
    }
}

/// Categories of weekly action items.
public enum WeeklyActionCategory: String, Sendable, CaseIterable {
    case sleep
    case breathe
    case activity
    case sunlight
    case hydrate

    public var defaultColorName: String {
        switch self {
        case .sleep:    return "nudgeRest"
        case .breathe:  return "nudgeBreathe"
        case .activity: return "nudgeWalk"
        case .sunlight: return "nudgeCelebrate"
        case .hydrate:  return "nudgeHydrate"
        }
    }

    public var icon: String {
        switch self {
        case .sleep:    return "moon.stars.fill"
        case .breathe:  return "wind"
        case .activity: return "figure.walk"
        case .sunlight: return "sun.max.fill"
        case .hydrate:  return "drop.fill"
        }
    }
}

// MARK: - Sunlight Window

/// A time-of-day opportunity for sunlight exposure inferred from the
/// user's movement patterns — no GPS required.
///
/// Thump detects three natural windows from HealthKit step data:
/// - **Morning** — first step burst of the day before 9 am (pre-commute / leaving home)
/// - **Lunch** — step activity around midday when many people are sedentary indoors
/// - **Evening** — step burst between 5-7 pm (commute home / after-work walk)
public struct SunlightWindow: Identifiable, Sendable {
    public let id: UUID

    /// Which time-of-day window this represents.
    public let slot: SunlightSlot

    /// Suggested reminder hour based on the inferred window.
    public let reminderHour: Int

    /// Whether Thump has observed movement in this window from historical data.
    /// `false` means we have no evidence the user goes outside at this time.
    public let hasObservedMovement: Bool

    /// Short label for the window, e.g. "Before your commute".
    public var label: String { slot.label }

    /// One-sentence coaching tip for this window.
    public var tip: String { slot.tip(hasObservedMovement: hasObservedMovement) }

    public init(
        id: UUID = UUID(),
        slot: SunlightSlot,
        reminderHour: Int,
        hasObservedMovement: Bool
    ) {
        self.id = id
        self.slot = slot
        self.reminderHour = reminderHour
        self.hasObservedMovement = hasObservedMovement
    }
}

/// The three inferred sunlight opportunity slots in a typical day.
public enum SunlightSlot: String, Sendable, CaseIterable {
    case morning
    case lunch
    case evening

    public var label: String {
        switch self {
        case .morning: return "Morning — before you head out"
        case .lunch:   return "Lunch — step away from your desk"
        case .evening: return "Evening — on the way home"
        }
    }

    public var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .lunch:   return "sun.max.fill"
        case .evening: return "sunset.fill"
        }
    }

    /// The default reminder hour for each slot.
    public var defaultHour: Int {
        switch self {
        case .morning: return 7
        case .lunch:   return 12
        case .evening: return 17
        }
    }

    public func tip(hasObservedMovement: Bool) -> String {
        switch self {
        case .morning:
            return hasObservedMovement
                ? "You already move in the morning — step outside for just 5 minutes before leaving to get direct sunlight."
                : "Even 5 minutes of sunlight before 9 am sets your body clock for the day. Try stepping outside before your commute."
        case .lunch:
            return hasObservedMovement
                ? "You tend to move at lunch. Swap even one indoor break for a short walk outside to get midday light."
                : "Midday is the most potent time for light exposure. A 5-minute walk outside at lunch beats any supplement."
        case .evening:
            return hasObservedMovement
                ? "Evening movement detected. Catching the last of the daylight on your commute home counts — face west if you can."
                : "A short walk when you get home captures evening light, which signals your body to wind down 2-3 hours later."
        }
    }
}

/// The full set of personalised action items for the weekly report detail.
public struct WeeklyActionPlan: Sendable {
    public let items: [WeeklyActionItem]
    public let weekStart: Date
    public let weekEnd: Date

    public init(items: [WeeklyActionItem], weekStart: Date, weekEnd: Date) {
        self.items = items
        self.weekStart = weekStart
        self.weekEnd = weekEnd
    }
}

// MARK: - Check-In Response

/// User response to a morning check-in.
public struct CheckInResponse: Codable, Equatable, Sendable {
    /// The date of the check-in.
    public let date: Date

    /// How the user is feeling (1-5 scale).
    public let feelingScore: Int

    /// Optional text note.
    public let note: String?

    public init(date: Date, feelingScore: Int, note: String? = nil) {
        self.date = date
        self.feelingScore = feelingScore
        self.note = note
    }
}

// MARK: - Check-In Mood

/// Quick mood check-in options for the dashboard.
public enum CheckInMood: String, Codable, Equatable, Sendable, CaseIterable {
    case great
    case good
    case okay
    case rough

    /// Emoji for display.
    public var emoji: String {
        switch self {
        case .great: return "😊"
        case .good:  return "🙂"
        case .okay:  return "😐"
        case .rough: return "😔"
        }
    }

    /// Short label for the mood.
    public var label: String {
        switch self {
        case .great: return "Great"
        case .good:  return "Good"
        case .okay:  return "Okay"
        case .rough: return "Rough"
        }
    }

    /// Numeric score (1-4) for storage.
    public var score: Int {
        switch self {
        case .great: return 4
        case .good:  return 3
        case .okay:  return 2
        case .rough: return 1
        }
    }
}

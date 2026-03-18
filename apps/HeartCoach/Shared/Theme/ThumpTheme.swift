// ThumpTheme.swift
// Thump
//
// Centralized design tokens for colors, spacing, and typography.
// All views should reference these tokens instead of hardcoded values.

import SwiftUI

// MARK: - App State

/// The four primary app states derived from the THUMP design system v1.7.
/// Used to drive color, copy pool, and coaching tone selection.
public enum AppState: String, Codable, Equatable, Sendable, CaseIterable {
    /// User's metrics are above baseline — high HRV, good recovery, low stress.
    case thriving

    /// User needs recovery — elevated stress, low HRV, reduced readiness.
    case recovering

    /// Acute or cumulative stress signal crossing threshold.
    case stressed

    /// Consistent baseline — no significant deviation in either direction.
    case steady
}

// MARK: - Color Palette

/// Semantic color tokens for the Thump app.
enum ThumpColors {

    // MARK: - Status Colors

    /// Status: Building Momentum / Improving
    static let improving = Color.green

    /// Status: Holding Steady / Stable
    static let stable = Color.blue

    /// Status: Check In / Needs Attention
    static let needsAttention = Color.orange

    // MARK: - Stress Level Colors

    /// Stress: Feeling Relaxed (0-33)
    static let relaxed = Color.green

    /// Stress: Finding Balance (34-66)
    static let balanced = Color.orange

    /// Stress: Running Hot (67-100)
    static let elevated = Color.red

    // MARK: - App State Colors (Design System v1.7)

    /// Thriving state — Gold (#EAB308).
    static let thriving = Color(hex: 0xEAB308)

    /// Recovering state — Violet/Purple (#8B5CF6).
    static let recovering = Color(hex: 0x8B5CF6)

    /// Stressed state — Orange (#F97316).
    static let stressed = Color(hex: 0xF97316)

    /// Steady state — Amber (#D97706).
    static let steady = Color(hex: 0xD97706)

    /// Background — OLED black (#090910).
    static let background = Color(hex: 0x090910)

    // MARK: - Metric Colors

    /// Resting Heart Rate metric
    static let heartRate = Color.red

    /// Heart Rate Variability metric
    static let hrv = Color.blue

    /// Recovery metric
    static let recovery = Color.green

    /// VO2 Max / Cardio Fitness metric
    static let cardioFitness = Color.purple

    /// Sleep metric
    static let sleep = Color.indigo

    /// Steps / Activity metric
    static let activity = Color.orange

    // MARK: - Confidence / Pattern Strength

    /// Strong Pattern
    static let highConfidence = Color.green

    /// Emerging Pattern
    static let mediumConfidence = Color.orange

    /// Early Signal
    static let lowConfidence = Color.gray

    // MARK: - Correlation Strength

    /// Strong / Clear Connection
    static let strongCorrelation = Color.green

    /// Moderate / Noticeable Connection
    static let moderateCorrelation = Color.orange

    /// Weak / Slight Connection
    static let weakCorrelation = Color.gray

    // MARK: - App Brand

    /// Primary brand accent
    static let accent = Color.pink

    /// Secondary brand color
    static let secondary = Color.purple
}

// MARK: - Thump Theme

/// Central theme accessor for the THUMP design system.
/// Use `ThumpTheme.color(for:)` to resolve app-state colors instead of
/// referencing `ThumpColors` directly from product code.
public enum ThumpTheme {

    /// Returns the semantic color for the given app state.
    ///
    /// - `.thriving`  → Gold (#EAB308)
    /// - `.recovering` → Violet (#8B5CF6)
    /// - `.stressed`  → Orange (#F97316)
    /// - `.steady`    → Amber (#D97706)
    public static func color(for state: AppState) -> Color {
        switch state {
        case .thriving:  return ThumpColors.thriving
        case .recovering: return ThumpColors.recovering
        case .stressed:  return ThumpColors.stressed
        case .steady:    return ThumpColors.steady
        }
    }
}

// MARK: - AppState UI Helpers

extension AppState {

    // MARK: - Derived from readiness score + chronic flag

    /// Derives the current app state from a readiness score and the chronic-steady flag.
    /// - Parameters:
    ///   - score: Readiness score 0–100.
    ///   - isChronicSteady: True when score has been 0–44 for 14+ consecutive days.
    static func from(score: Int, isChronicSteady: Bool) -> AppState {
        if isChronicSteady { return .steady }
        switch score {
        case 75...100: return .thriving
        case 45..<75:  return .recovering
        default:       return .stressed
        }
    }

    // MARK: - Design tokens

    /// Primary state color (exact hex values from design system §5 color table).
    var primaryColor: Color { ThumpTheme.color(for: self) }

    /// Human-readable state name for display.
    var stateName: String {
        switch self {
        case .thriving:  return "Thriving"
        case .recovering: return "Recovering"
        case .stressed:  return "Stressed"
        case .steady:    return "Steady"
        }
    }

    /// Buddy mood mapped from state (design system §5 mood → state mapping table).
    var buddyMood: BuddyMood {
        switch self {
        case .thriving:  return .conquering
        case .recovering: return .content
        case .stressed:  return .stressed
        case .steady:    return .tired
        }
    }

    /// Buddy breathe animation duration in seconds (design system §5).
    var buddyBreatheDuration: Double {
        switch self {
        case .thriving:  return 2.2
        case .recovering: return 4.5
        case .stressed:  return 2.8
        case .steady:    return 6.0
        }
    }
}

// MARK: - Spacing Scale

/// 4pt grid spacing tokens.
enum ThumpSpacing {
    /// 4pt
    static let xxs: CGFloat = 4
    /// 8pt
    static let xs: CGFloat = 8
    /// 12pt
    static let sm: CGFloat = 12
    /// 16pt
    static let md: CGFloat = 16
    /// 20pt
    static let lg: CGFloat = 20
    /// 24pt
    static let xl: CGFloat = 24
    /// 32pt
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius

/// Standard corner radius tokens.
enum ThumpRadius {
    /// Small elements (badges, chips)
    static let sm: CGFloat = 8
    /// Medium elements (cards)
    static let md: CGFloat = 14
    /// Large elements (sheets, modals)
    static let lg: CGFloat = 16
    /// Circular elements
    static let full: CGFloat = 999
}

// MARK: - Shared Date Formatters

/// Centralized DateFormatters to avoid duplicating identical formatters
/// across multiple views. DateFormatter allocation is expensive — sharing
/// static instances is both a DRY and performance win.
enum ThumpFormatters {
    /// "Jan 5" — used for date ranges in reports and insights.
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// "Mon" — abbreviated weekday name.
    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    /// "Monday, Jan 5" — full day header.
    static let dayHeader: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    /// "Mon, Jan 5" — short date with weekday.
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    /// "9AM" — hour only.
    static let hour: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f
    }()
}


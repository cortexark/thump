// ThumpTheme.swift
// Thump
//
// Centralized design tokens for colors, spacing, and typography.
// All views should reference these tokens instead of hardcoded values.

import SwiftUI

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

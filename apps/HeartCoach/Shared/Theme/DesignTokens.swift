// DesignTokens.swift
// Thump
//
// Centralized design constants for consistent visual appearance
// across iOS and watchOS. All card styles, spacing, and radii
// should reference these tokens.
//
// Platforms: iOS 17+, watchOS 10+

import SwiftUI

// MARK: - Card Style

/// Shared constants for card-based layouts throughout the app.
enum CardStyle {
    /// Standard card corner radius (used by most cards).
    static let cornerRadius: CGFloat = 16

    /// Hero card corner radius (status card, paywall pricing).
    static let heroCornerRadius: CGFloat = 18

    /// Inner element corner radius (nested cards, badges).
    static let innerCornerRadius: CGFloat = 12

    /// Standard card padding.
    static let padding: CGFloat = 16

    /// Hero card padding.
    static let heroPadding: CGFloat = 18
}

// MARK: - Spacing

/// Consistent spacing scale based on 4pt grid.
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Confidence Colors

/// Maps confidence levels to colors consistently across the app.
extension ConfidenceLevel {
    /// Display color for this confidence level.
    var displayColor: Color {
        switch self {
        case .high:   return .green
        case .medium: return .yellow
        case .low:    return .orange
        }
    }
}

// MARK: - Status Colors

/// Maps trend status to colors consistently across the app.
extension TrendStatus {
    /// Display color for this status.
    var displayColor: Color {
        switch self {
        case .improving:      return .green
        case .stable:         return .blue
        case .needsAttention: return .orange
        }
    }
}

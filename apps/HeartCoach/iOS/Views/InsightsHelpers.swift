// InsightsHelpers.swift
// Thump iOS
//
// Shared logic extracted from InsightsView so that both Design A and
// Design B can access it without widening InsightsView's API surface.

import SwiftUI

// MARK: - InsightsHelpers

/// Pure-function helpers shared between InsightsView (Design A) and
/// InsightsView+DesignB. No view state — just data transformations.
enum InsightsHelpers {

    // MARK: - Hero Text

    static func heroSubtitle(report: WeeklyReport?) -> String {
        guard let report else { return "Building your first weekly report" }
        switch report.trendDirection {
        case .up:   return "You're building momentum"
        case .flat: return "Consistency is your strength"
        case .down: return "A few small changes can help"
        }
    }

    static func heroInsightText(report: WeeklyReport?) -> String {
        if let report {
            return report.topInsight
        }
        return "Wear your Apple Watch for 7 days and we'll show you personalized insights about patterns in your data and ideas for your routine."
    }

    /// Picks the action plan item most relevant to the hero insight topic.
    /// Falls back to the first item if no match is found.
    static func heroActionText(plan: WeeklyActionPlan?, insightText: String) -> String? {
        guard let plan, !plan.items.isEmpty else { return nil }

        let insight = insightText.lowercased()
        let matched = plan.items.first { item in
            let title = item.title.lowercased()
            let detail = item.detail.lowercased()
            if insight.contains("step") || insight.contains("walk") || insight.contains("activity") || insight.contains("exercise") {
                return item.category == .activity || title.contains("walk") || title.contains("step") || title.contains("active") || detail.contains("walk")
            }
            if insight.contains("sleep") {
                return item.category == .sleep
            }
            if insight.contains("stress") || insight.contains("hrv") || insight.contains("heart rate variability") || insight.contains("recovery") {
                return item.category == .breathe
            }
            return false
        }
        return (matched ?? plan.items.first)?.title
    }

    // MARK: - Focus Targets

    /// Derives weekly focus targets from the action plan.
    static func weeklyFocusTargets(from plan: WeeklyActionPlan) -> [FocusTarget] {
        var targets: [FocusTarget] = []

        if let sleep = plan.items.first(where: { $0.category == .sleep }) {
            targets.append(FocusTarget(
                icon: "moon.stars.fill",
                title: "Bedtime Target",
                reason: sleep.detail,
                targetValue: sleep.suggestedReminderHour.map { "\($0 > 12 ? $0 - 12 : $0) PM" },
                color: Color(hex: 0x8B5CF6)
            ))
        }

        if let activity = plan.items.first(where: { $0.category == .activity }) {
            targets.append(FocusTarget(
                icon: "figure.walk",
                title: "Activity Goal",
                reason: activity.detail,
                targetValue: "30 min",
                color: Color(hex: 0x3B82F6)
            ))
        }

        if let breathe = plan.items.first(where: { $0.category == .breathe }) {
            targets.append(FocusTarget(
                icon: "wind",
                title: "Breathing Practice",
                reason: breathe.detail,
                targetValue: "5 min",
                color: Color(hex: 0x0D9488)
            ))
        }

        if let sun = plan.items.first(where: { $0.category == .sunlight }) {
            targets.append(FocusTarget(
                icon: "sun.max.fill",
                title: "Daylight Exposure",
                reason: sun.detail,
                targetValue: "3 windows",
                color: Color(hex: 0xF59E0B)
            ))
        }

        return targets
    }

    // MARK: - Formatters

    static func reportDateRange(_ report: WeeklyReport) -> String {
        "\(ThumpFormatters.monthDay.string(from: report.weekStart)) - \(ThumpFormatters.monthDay.string(from: report.weekEnd))"
    }
}

// MARK: - Focus Target

/// A weekly focus target derived from the action plan.
/// Shared between Design A and Design B layouts.
struct FocusTarget {
    let icon: String
    let title: String
    let reason: String
    let targetValue: String?
    let color: Color
}

// MARK: - Trend Badge View

/// A capsule badge showing the weekly trend direction.
/// Used by both Design A and Design B.
struct TrendBadgeView: View {
    let direction: WeeklyReport.TrendDirection

    private var icon: String {
        switch direction {
        case .up:   return "arrow.up.right"
        case .flat: return "minus"
        case .down: return "arrow.down.right"
        }
    }

    private var badgeColor: Color {
        switch direction {
        case .up:   return .green
        case .flat: return .blue
        case .down: return .orange
        }
    }

    private var label: String {
        switch direction {
        case .up:   return "Building Momentum"
        case .flat: return "Holding Steady"
        case .down: return "Worth Watching"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(badgeColor.opacity(0.12), in: Capsule())
    }
}

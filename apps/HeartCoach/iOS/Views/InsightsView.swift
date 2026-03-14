// InsightsView.swift
// Thump iOS
//
// Displays weekly reports and activity-trend correlation insights.
// All users see the weekly summary report card and correlation cards
// showing how activity factors relate to heart metrics.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - InsightsView

/// Insights screen presenting weekly reports and correlation analysis.
///
/// All content is available to all users. Data is loaded asynchronously
/// from `InsightsViewModel`.
struct InsightsView: View {

    // MARK: - Date Formatters (static to avoid per-render allocation)

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    // MARK: - View Model

    @StateObject private var viewModel = InsightsViewModel()
    @EnvironmentObject private var connectivityService: ConnectivityService
    @EnvironmentObject private var healthKitService: HealthKitService
    @EnvironmentObject private var localStore: LocalStore

    // MARK: - State

    @State private var showingReportDetail = false
    @State private var selectedCorrelation: CorrelationResult?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Insights")
                .navigationBarTitleDisplayMode(.large)
                .onAppear { InteractionLog.pageView("Insights") }
                .task {
                    viewModel.bind(healthKitService: healthKitService, localStore: localStore)
                    viewModel.connectivityService = connectivityService
                    await viewModel.loadInsights()
                }
                .sheet(isPresented: $showingReportDetail) {
                    if let report = viewModel.weeklyReport,
                       let plan = viewModel.actionPlan {
                        WeeklyReportDetailView(report: report, plan: plan)
                    }
                }
                .sheet(item: $selectedCorrelation) { correlation in
                    CorrelationDetailSheet(correlation: correlation)
                }
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            loadingView
        } else {
            scrollContent
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero: what the customer should focus on
                insightsHeroCard
                focusForTheWeekSection
                weeklyReportSection
                topActionCard
                howActivityAffectsSection
                correlationsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Insights Hero Card

    /// The single most important thing for the user to know this week.
    private var insightsHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Focus This Week")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(heroSubtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()
            }

            Text(heroInsightText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)

            if let actionText = heroActionText {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                    Text(actionText)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(.white.opacity(0.2)))
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x7C3AED), Color(hex: 0x6D28D9), Color(hex: 0x4C1D95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("insights_hero_card")
    }

    private var heroSubtitle: String {
        guard let report = viewModel.weeklyReport else { return "Building your first weekly report" }
        switch report.trendDirection {
        case .up: return "You're building momentum"
        case .flat: return "Consistency is your strength"
        case .down: return "A few small changes can help"
        }
    }

    private var heroInsightText: String {
        if let report = viewModel.weeklyReport {
            return report.topInsight
        }
        return "Wear your Apple Watch for 7 days and we'll show you personalized insights about patterns in your data and ideas for your routine."
    }

    /// Picks the action plan item most relevant to the hero insight topic.
    /// Falls back to the first item if no match is found.
    private var heroActionText: String? {
        guard let plan = viewModel.actionPlan, !plan.items.isEmpty else { return nil }

        // Try to match the action to the hero insight topic
        let insight = heroInsightText.lowercased()
        let matched = plan.items.first { item in
            let title = item.title.lowercased()
            let detail = item.detail.lowercased()
            // Match activity-related insights to activity actions
            if insight.contains("step") || insight.contains("walk") || insight.contains("activity") || insight.contains("exercise") {
                return item.category == .activity || title.contains("walk") || title.contains("step") || title.contains("active") || detail.contains("walk")
            }
            // Match sleep insights to sleep actions
            if insight.contains("sleep") {
                return item.category == .sleep
            }
            // Match stress/HRV insights to breathe actions
            if insight.contains("stress") || insight.contains("hrv") || insight.contains("heart rate variability") || insight.contains("recovery") {
                return item.category == .breathe
            }
            return false
        }
        return (matched ?? plan.items.first)?.title
    }

    // MARK: - Top Action Card

    @ViewBuilder
    private var topActionCard: some View {
        if let plan = viewModel.actionPlan, !plan.items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: 0x22C55E))
                    Text("What to Do This Week")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                ForEach(Array(plan.items.prefix(3).enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color(hex: 0x22C55E)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }

                if plan.items.count > 3 {
                    Button {
                        InteractionLog.log(.buttonTap, element: "see_all_actions", page: "Insights")
                        showingReportDetail = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("See all \(plan.items.count) actions")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(Color(hex: 0x22C55E))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                    .accessibilityIdentifier("see_all_actions_button")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(hex: 0x22C55E).opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Weekly Report Section

    @ViewBuilder
    private var weeklyReportSection: some View {
        if let report = viewModel.weeklyReport {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Weekly Report", icon: "doc.text.fill")

                Button {
                    InteractionLog.log(.cardTap, element: "weekly_report", page: "Insights")
                    showingReportDetail = true
                } label: {
                    weeklyReportCard(report: report)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("weekly_report_card")
            }
        }
    }

    /// The detailed weekly report card.
    private func weeklyReportCard(report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Date range header
            HStack {
                Text(reportDateRange(report))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                trendBadge(direction: report.trendDirection)
            }

            // Average cardio score
            if let score = report.avgCardioScore {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Avg Score")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(score))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)
                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Weekly summary (distinct from hero insight)
            Text(weeklyReportSummary(report: report))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Nudge completion rate
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Nudge Completion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(report.nudgeCompletionRate * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geo.size.width * report.nudgeCompletionRate, height: 8)
                    }
                }
                .frame(height: 8)
            }

            // Call-to-action footer
            HStack {
                Text("See your action plan")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.pink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.pink)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Correlations Section

    private var correlationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "How Activities Affect Your Numbers", icon: "arrow.triangle.branch")
                .accessibilityIdentifier("correlations_section")

            if viewModel.correlations.isEmpty {
                emptyCorrelationsView
            } else {
                ForEach(viewModel.correlations, id: \.factorName) { correlation in
                    Button {
                        InteractionLog.log(.cardTap, element: "correlation_card", page: "Insights", details: correlation.factorName)
                        selectedCorrelation = correlation
                    } label: {
                        CorrelationCardView(correlation: correlation)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("correlation_card_\(correlation.factorName)")
                    .accessibilityHint("Double tap for recommendations")
                }
            }
        }
    }

    // MARK: - Empty Correlations

    private var emptyCorrelationsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.dots.scatter")
                .font(.title)
                .foregroundStyle(.secondary)

            Text("Not enough data yet")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text("Continue wearing your Apple Watch daily. Correlations require at least 7 days of activity and heart data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Helpers

    /// Builds a section header with icon and title.
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.pink)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.top, 8)
    }

    /// Generates a summary for the weekly report card that is distinct from
    /// the hero insight. Focuses on metric changes rather than correlations.
    private func weeklyReportSummary(report: WeeklyReport) -> String {
        var parts: [String] = []

        if let score = report.avgCardioScore {
            switch report.trendDirection {
            case .up:
                parts.append("Your average score of \(Int(score)) is up from last week.")
            case .flat:
                parts.append("Your average score held steady at \(Int(score)) this week.")
            case .down:
                parts.append("Your average score of \(Int(score)) dipped from last week.")
            }
        }

        let completionPct = Int(report.nudgeCompletionRate * 100)
        if completionPct >= 70 {
            parts.append("You engaged with \(completionPct)% of daily suggestions — solid commitment.")
        } else if completionPct >= 40 {
            parts.append("You completed \(completionPct)% of your nudges. Aim for one extra nudge this week.")
        } else {
            parts.append("Try following more daily nudges this week to see progress.")
        }

        return parts.joined(separator: " ")
    }

    /// Formats the week date range for display.
    private func reportDateRange(_ report: WeeklyReport) -> String {
        "\(Self.monthDayFormatter.string(from: report.weekStart)) - \(Self.monthDayFormatter.string(from: report.weekEnd))"
    }

    /// A capsule badge showing the weekly trend direction.
    private func trendBadge(direction: WeeklyReport.TrendDirection) -> some View {
        let icon: String
        let color: Color
        let label: String

        switch direction {
        case .up:
            icon = "arrow.up.right"
            color = .green
            label = "Building Momentum"
        case .flat:
            icon = "minus"
            color = .blue
            label = "Holding Steady"
        case .down:
            icon = "arrow.down.right"
            color = .orange
            label = "Worth Watching"
        }

        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Focus for the Week (Engine-Driven Targets)

    /// Engine-driven weekly targets: bedtime, activity, walk, sun time.
    /// Each target is derived from the action plan items.
    @ViewBuilder
    private var focusForTheWeekSection: some View {
        if let plan = viewModel.actionPlan, !plan.items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Focus for the Week", icon: "target")
                    .accessibilityIdentifier("focus_card_section")

                let targets = weeklyFocusTargets(from: plan)
                ForEach(Array(targets.enumerated()), id: \.offset) { _, target in
                    HStack(spacing: 12) {
                        Image(systemName: target.icon)
                            .font(.subheadline)
                            .foregroundStyle(target.color)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(target.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(target.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        if let value = target.targetValue {
                            Text(value)
                                .font(.caption)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                                .foregroundStyle(target.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(target.color.opacity(0.12))
                                )
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(target.color.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(target.color.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
    }

    private struct FocusTarget {
        let icon: String
        let title: String
        let reason: String
        let targetValue: String?
        let color: Color
    }

    private func weeklyFocusTargets(from plan: WeeklyActionPlan) -> [FocusTarget] {
        var targets: [FocusTarget] = []

        // Bedtime target from sleep action
        if let sleep = plan.items.first(where: { $0.category == .sleep }) {
            targets.append(FocusTarget(
                icon: "moon.stars.fill",
                title: "Bedtime Target",
                reason: sleep.detail,
                targetValue: sleep.suggestedReminderHour.map { "\($0 > 12 ? $0 - 12 : $0) PM" },
                color: Color(hex: 0x8B5CF6)
            ))
        }

        // Activity target
        if let activity = plan.items.first(where: { $0.category == .activity }) {
            targets.append(FocusTarget(
                icon: "figure.walk",
                title: "Activity Goal",
                reason: activity.detail,
                targetValue: "30 min",
                color: Color(hex: 0x3B82F6)
            ))
        }

        // Breathing / stress management
        if let breathe = plan.items.first(where: { $0.category == .breathe }) {
            targets.append(FocusTarget(
                icon: "wind",
                title: "Breathing Practice",
                reason: breathe.detail,
                targetValue: "5 min",
                color: Color(hex: 0x0D9488)
            ))
        }

        // Sunlight
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

    // MARK: - How Activity Affects Your Numbers (Educational)

    /// Educational cards explaining the connection between activity and health metrics.
    private var howActivityAffectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "How Activity Affects Your Numbers", icon: "lightbulb.fill")
                .accessibilityIdentifier("activity_card_section")

            VStack(spacing: 10) {
                educationalCard(
                    icon: "figure.walk",
                    iconColor: Color(hex: 0x22C55E),
                    title: "Activity → VO2 Max",
                    explanation: "Regular moderate activity (brisk walking, cycling) strengthens your heart's pumping efficiency. Over weeks, your VO2 max score improves — meaning your heart delivers more oxygen with less effort."
                )

                educationalCard(
                    icon: "heart.circle",
                    iconColor: Color(hex: 0x3B82F6),
                    title: "Zone Training → Recovery Speed",
                    explanation: "Spending time in heart rate zones 2-3 (fat burn and cardio) trains your heart to recover faster after exertion. A lower recovery heart rate means a more efficient cardiovascular system."
                )

                educationalCard(
                    icon: "moon.fill",
                    iconColor: Color(hex: 0x8B5CF6),
                    title: "Sleep → HRV",
                    explanation: "Quality sleep is when your nervous system rebalances. Consistent 7-8 hour nights typically show as rising HRV over 2-4 weeks — a sign your body is recovering well between efforts."
                )

                educationalCard(
                    icon: "brain.head.profile",
                    iconColor: Color(hex: 0xF59E0B),
                    title: "Stress → Resting Heart Rate",
                    explanation: "Chronic stress keeps your fight-or-flight system active, raising resting heart rate. Breathing exercises and regular movement help lower it by activating your body's relaxation response."
                )
            }
        }
    }

    private func educationalCard(icon: String, iconColor: Color, title: String, explanation: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Analyzing your insights...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Preview

#Preview("Insights") {
    InsightsView()
}

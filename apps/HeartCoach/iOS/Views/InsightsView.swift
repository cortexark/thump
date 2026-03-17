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

    // MARK: - View Model

    @StateObject var viewModel = InsightsViewModel()
    @EnvironmentObject private var connectivityService: ConnectivityService
    @EnvironmentObject private var healthKitService: HealthKitService
    @EnvironmentObject private var localStore: LocalStore
    @EnvironmentObject private var coordinator: DailyEngineCoordinator

    // MARK: - State

    @AppStorage("thump_design_variant_b") private var useDesignB: Bool = false
    @State var showingReportDetail = false
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
                    viewModel.bind(coordinator: coordinator)
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
        } else if useDesignB {
            scrollContentB
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

    var heroSubtitle: String {
        InsightsHelpers.heroSubtitle(report: viewModel.weeklyReport)
    }

    var heroInsightText: String {
        InsightsHelpers.heroInsightText(report: viewModel.weeklyReport)
    }

    var heroActionText: String? {
        InsightsHelpers.heroActionText(plan: viewModel.actionPlan, insightText: heroInsightText)
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
                    Button {
                        InteractionLog.log(.cardTap, element: "action_item_\(index)", page: "Insights", details: item.title)
                        showingReportDetail = true
                    } label: {
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

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(CardButtonStyle())
                    .accessibilityHint("Double tap to view full action plan")
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
                Text(InsightsHelpers.reportDateRange(report))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                TrendBadgeView(direction: report.trendDirection)
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

    var correlationsSection: some View {
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

        let policy = ConfigService.activePolicy
        let completionPct = Int(report.nudgeCompletionRate * 100)
        if completionPct >= policy.view.nudgeCompletionSolid {
            parts.append("You engaged with \(completionPct)% of daily suggestions — solid commitment.")
        } else if completionPct >= policy.view.nudgeCompletionMinimum {
            parts.append("You completed \(completionPct)% of your nudges. Aim for one extra nudge this week.")
        } else {
            parts.append("Try following more daily nudges this week to see progress.")
        }

        return parts.joined(separator: " ")
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

                let targets = InsightsHelpers.weeklyFocusTargets(from: plan)
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

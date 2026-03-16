// StressView.swift
// Thump iOS
//
// Displays the HRV-based stress metric with a calendar-style heatmap,
// trend summary, smart nudge actions, and day/week/month views.
// Day view shows hourly boxes (green/red), week and month views
// show daily boxes in a calendar grid.
//
// Sub-views extracted for smaller diffing scope and faster rendering:
// - StressHeatmapViews.swift  → heatmap card, day/week/month grids, legend
// - StressTrendChartView.swift → trend line chart, zone background, axis labels
// - StressSmartActionsView.swift → smart actions, guidance card, action handler
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - StressView

/// Calendar-style stress heatmap with day/week/month views.
///
/// - **Day**: 24 hourly boxes colored by stress level
/// - **Week**: 7 daily boxes with stress level colors
/// - **Month**: Calendar grid with daily stress colors
///
/// Includes a trend summary ("stress is trending up/down") and
/// smart nudge actions (breath prompt, journal, check-in).
struct StressView: View {

    // MARK: - View Model

    @StateObject var viewModel = StressViewModel()
    @EnvironmentObject private var connectivityService: ConnectivityService
    @EnvironmentObject private var healthKitService: HealthKitService

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ThumpSpacing.md) {
                    currentStressBanner
                    stressExplainerCard
                    timeRangePicker
                    heatmapCard
                    stressTrendChart
                    trendSummaryCard
                    smartActionsSection
                    summaryStatsCard
                }
                .padding(ThumpSpacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stress")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { InteractionLog.pageView("Stress") }
            .task {
                viewModel.bind(healthKitService: healthKitService)
                viewModel.bind(connectivityService: connectivityService)
                await viewModel.loadData()
            }
            .sheet(isPresented: $viewModel.isJournalSheetPresented) {
                journalSheet
            }
            .sheet(isPresented: $viewModel.isBreathingSessionActive) {
                breathingSessionSheet
            }
            .alert("Time for a Walk",
                   isPresented: $viewModel.walkSuggestionShown) {
                Button("OK") {
                    InteractionLog.log(.buttonTap, element: "walk_suggestion_ok", page: "Stress")
                    viewModel.walkSuggestionShown = false
                }
            } message: {
                Text("A 10-minute walk can lower stress and boost your mood. Step outside and enjoy the fresh air.")
            }
        }
    }

    // MARK: - Current Stress Banner

    private var currentStressBanner: some View {
        HStack(spacing: ThumpSpacing.sm) {
            if let stress = viewModel.currentStress {
                // Color indicator dot
                Circle()
                    .fill(stressColor(for: stress.level))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stress.level.friendlyMessage)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text("Score: \(Int(stress.score))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if stress.confidence == .low {
                            Text(stress.confidence.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Color.orange.opacity(0.15))
                                )
                        }
                    }
                }

                Spacer()

                Image(systemName: stress.level.icon)
                    .font(.title2)
                    .foregroundStyle(stressColor(for: stress.level))
            } else {
                Image(systemName: "heart.text.square")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("Waiting for stress data…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(ThumpSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ThumpRadius.md)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stress_banner")
    }

    // MARK: - Stress Explainer Card

    /// Explains what the current stress reading means in plain language
    /// and what the user should consider doing about it.
    @ViewBuilder
    private var stressExplainerCard: some View {
        if let stress = viewModel.currentStress {
            VStack(alignment: .leading, spacing: ThumpSpacing.xs) {
                Text("What This Means")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(stress.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Level-specific actionable one-liner
                HStack(spacing: 6) {
                    Image(systemName: stressActionIcon(for: stress.level))
                        .font(.caption)
                        .foregroundStyle(stressColor(for: stress.level))

                    Text(stressActionTip(for: stress.level))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(stressColor(for: stress.level))
                }
                .padding(.top, 2)

                // Signal quality warnings
                if !stress.warnings.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(stress.warnings.first ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(ThumpSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ThumpRadius.md)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .accessibilityElement(children: .combine)
        }
    }

    private func stressActionIcon(for level: StressLevel) -> String {
        switch level {
        case .relaxed: return "arrow.up.heart.fill"
        case .balanced: return "checkmark.circle.fill"
        case .elevated: return "exclamationmark.circle.fill"
        }
    }

    private func stressActionTip(for level: StressLevel) -> String {
        switch level {
        case .relaxed:
            return "Great time for a workout or focused work"
        case .balanced:
            return "Stay the course. A walk or stretch can help maintain this"
        case .elevated:
            return "Try slow breathing, a short walk, or extra rest tonight"
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedRange) {
            Text("Day").tag(TimeRange.day)
            Text("Week").tag(TimeRange.week)
            Text("Month").tag(TimeRange.month)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Stress heatmap time range")
        .accessibilityIdentifier("stress_time_range_picker")
        .onChange(of: viewModel.selectedRange) { _, newValue in
            InteractionLog.log(.pickerChange, element: "stress_time_range", page: "Stress", details: "\(newValue)")
        }
    }

    // MARK: - Trend Summary Card

    private var trendSummaryCard: some View {
        VStack(alignment: .leading, spacing: ThumpSpacing.xs) {
            HStack(spacing: ThumpSpacing.xs) {
                Image(systemName: viewModel.trendDirection.icon)
                    .font(.title3)
                    .foregroundStyle(trendDirectionColor)

                Text(viewModel.trendDirection.displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            if let insight = viewModel.trendInsight {
                Text(insight)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(ThumpSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ThumpRadius.md)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private var trendDirectionColor: Color {
        switch viewModel.trendDirection {
        case .rising: return ThumpColors.elevated
        case .falling: return ThumpColors.relaxed
        case .steady: return ThumpColors.balanced
        }
    }

    // MARK: - Summary Stats Card

    private var summaryStatsCard: some View {
        VStack(alignment: .leading, spacing: ThumpSpacing.sm) {
            Text("Summary")
                .font(.headline)
                .foregroundStyle(.primary)

            if let avg = viewModel.averageStress {
                HStack(spacing: 0) {
                    statItem(
                        label: "Average",
                        value: "\(Int(avg))",
                        sublabel: StressLevel.from(score: avg).displayName
                    )

                    Divider().frame(height: 50)

                    if let relaxed = viewModel.mostRelaxedDay {
                        statItem(
                            label: "Most Relaxed",
                            value: "\(Int(relaxed.score))",
                            sublabel: formatDate(relaxed.date)
                        )
                    }

                    Divider().frame(height: 50)

                    if let elevated = viewModel.mostElevatedDay {
                        statItem(
                            label: "Highest",
                            value: "\(Int(elevated.score))",
                            sublabel: formatDate(elevated.date)
                        )
                    }
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("Wear your watch for a few more days to see stress stats.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ThumpSpacing.xs)
            }
        }
        .padding(ThumpSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ThumpRadius.md)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Supporting Views

    private func statItem(
        label: String,
        value: String,
        sublabel: String
    ) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(sublabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Journal Sheet

    private var journalSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ThumpSpacing.md) {
                if let prompt = viewModel.activeJournalPrompt {
                    Text(prompt.question)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(prompt.context)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("How are you feeling right now?")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Writing down your thoughts can help reduce stress.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Journal entry would go here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                Spacer()
            }
            .padding(ThumpSpacing.md)
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        InteractionLog.log(.buttonTap, element: "journal_close", page: "Stress")
                        viewModel.isJournalSheetPresented = false
                    }
                }
            }
        }
    }

    // MARK: - Breathing Session Sheet

    private var breathingSessionSheet: some View {
        NavigationStack {
            VStack(spacing: ThumpSpacing.lg) {
                Spacer()

                Image(systemName: "wind")
                    .font(.system(size: 60))
                    .foregroundStyle(ThumpColors.relaxed)

                Text("Breathe")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Inhale slowly… then exhale.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(viewModel.breathingSecondsRemaining)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(ThumpColors.relaxed)
                    .contentTransition(.numericText())

                Spacer()

                Button("End Session") {
                    InteractionLog.log(.buttonTap, element: "end_breathing_session", page: "Stress")
                    viewModel.stopBreathingSession()
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
            .padding(ThumpSpacing.md)
            .navigationTitle("Breathing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        InteractionLog.log(.buttonTap, element: "breathing_close", page: "Stress")
                        viewModel.stopBreathingSession()
                    }
                }
            }
        }
    }

    // MARK: - Shared Helpers
    // These are `internal` (not private) because extensions in
    // StressHeatmapViews.swift, StressTrendChartView.swift, and
    // StressSmartActionsView.swift need access.

    func stressColor(for level: StressLevel) -> Color {
        switch level {
        case .relaxed: return ThumpColors.relaxed
        case .balanced: return ThumpColors.balanced
        case .elevated: return ThumpColors.elevated
        }
    }

    func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "p" : "a"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour)\(period)"
    }

    func formatWeekday(_ date: Date) -> String {
        ThumpFormatters.weekday.string(from: date)
    }

    func formatDayHeader(_ date: Date) -> String {
        ThumpFormatters.dayHeader.string(from: date)
    }

    func formatDate(_ date: Date) -> String {
        ThumpFormatters.shortDate.string(from: date)
    }
}

// MARK: - Preview

#Preview("Stress View") {
    StressView()
}

// StressView.swift
// Thump iOS
//
// Displays the HRV-based stress metric with a calendar-style heatmap,
// trend summary, smart nudge actions, and day/week/month views.
// Day view shows hourly boxes (green/red), week and month views
// show daily boxes in a calendar grid.
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

    @StateObject private var viewModel = StressViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ThumpSpacing.md) {
                    currentStressBanner
                    timeRangePicker
                    heatmapCard
                    trendSummaryCard
                    smartActionCard
                    summaryStatsCard
                }
                .padding(ThumpSpacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stress")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadData()
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

                    Text("Score: \(Int(stress.score))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
    }

    // MARK: - Heatmap Card

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: ThumpSpacing.sm) {
            Text(heatmapTitle)
                .font(.headline)
                .foregroundStyle(.primary)

            switch viewModel.selectedRange {
            case .day:
                dayHeatmap
            case .week:
                weekHeatmap
            case .month:
                monthHeatmap
            }

            // Legend
            heatmapLegend
        }
        .padding(ThumpSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ThumpRadius.md)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var heatmapTitle: String {
        switch viewModel.selectedRange {
        case .day: return "Today — Hourly Stress"
        case .week: return "This Week"
        case .month: return "This Month"
        }
    }

    // MARK: - Day Heatmap (24 hourly boxes)

    private var dayHeatmap: some View {
        VStack(alignment: .leading, spacing: ThumpSpacing.xxs) {
            if viewModel.hourlyPoints.isEmpty {
                emptyHeatmapState
            } else {
                // 4 rows × 6 columns grid
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: ThumpSpacing.xxs) {
                        ForEach(0..<6, id: \.self) { col in
                            let hour = row * 6 + col
                            hourlyCell(hour: hour)
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Hourly stress heatmap for today")
    }

    private func hourlyCell(hour: Int) -> some View {
        let point = viewModel.hourlyPoints.first { $0.hour == hour }
        let color = point.map { stressColor(for: $0.level) }
            ?? Color(.systemGray5)
        let score = point.map { Int($0.score) } ?? 0
        let hourLabel = formatHour(hour)

        return VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(point != nil ? 0.8 : 0.3))
                .frame(height: 36)
                .overlay(
                    Text(point != nil ? "\(score)" : "")
                        .font(.system(size: 10, weight: .medium,
                                      design: .rounded))
                        .foregroundStyle(.white)
                )

            Text(hourLabel)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(
            "\(hourLabel): "
            + (point != nil
               ? "stress \(score), \(point!.level.displayName)"
               : "no data")
        )
    }

    // MARK: - Week Heatmap (7 daily boxes)

    private var weekHeatmap: some View {
        VStack(alignment: .leading, spacing: ThumpSpacing.xs) {
            if viewModel.trendPoints.isEmpty {
                emptyHeatmapState
            } else {
                HStack(spacing: ThumpSpacing.xxs) {
                    ForEach(viewModel.weekDayPoints, id: \.date) { point in
                        dailyCell(point: point)
                    }
                }

                // Show hourly breakdown for selected day if available
                if let selected = viewModel.selectedDayForDetail,
                   !viewModel.selectedDayHourlyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: ThumpSpacing.xxs) {
                        Text(formatDayHeader(selected))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        // Mini hourly grid for the selected day
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 2),
                                count: 8
                            ),
                            spacing: 2
                        ) {
                            ForEach(
                                viewModel.selectedDayHourlyPoints,
                                id: \.hour
                            ) { hp in
                                miniHourCell(point: hp)
                            }
                        }
                    }
                    .padding(.top, ThumpSpacing.xxs)
                }
            }
        }
        .accessibilityLabel("Weekly stress heatmap")
    }

    private func dailyCell(point: StressDataPoint) -> some View {
        let isSelected = viewModel.selectedDayForDetail != nil
            && Calendar.current.isDate(
                point.date,
                inSameDayAs: viewModel.selectedDayForDetail!
            )

        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(stressColor(for: point.level).opacity(0.8))
                .frame(height: 50)
                .overlay(
                    VStack(spacing: 2) {
                        Text("\(Int(point.score))")
                            .font(.system(size: 14, weight: .bold,
                                          design: .rounded))
                            .foregroundStyle(.white)

                        Image(systemName: point.level.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? Color.primary : Color.clear,
                            lineWidth: 2
                        )
                )

            Text(formatWeekday(point.date))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectDay(point.date)
            }
        }
        .accessibilityLabel(
            "\(formatWeekday(point.date)): "
            + "stress \(Int(point.score)), \(point.level.displayName)"
        )
        .accessibilityAddTraits(.isButton)
    }

    private func miniHourCell(point: HourlyStressPoint) -> some View {
        VStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 2)
                .fill(stressColor(for: point.level).opacity(0.7))
                .frame(height: 20)

            Text(formatHour(point.hour))
                .font(.system(size: 6))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Month Heatmap (calendar grid)

    private var monthHeatmap: some View {
        VStack(alignment: .leading, spacing: ThumpSpacing.xxs) {
            if viewModel.trendPoints.isEmpty {
                emptyHeatmapState
            } else {
                // Day of week headers
                HStack(spacing: 2) {
                    ForEach(
                        ["S", "M", "T", "W", "T", "F", "S"],
                        id: \.self
                    ) { day in
                        Text(day)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar grid
                let weeks = viewModel.monthCalendarWeeks
                ForEach(0..<weeks.count, id: \.self) { weekIdx in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { dayIdx in
                            if let point = weeks[weekIdx][dayIdx] {
                                monthDayCell(point: point)
                            } else {
                                Color.clear
                                    .frame(height: 32)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Monthly stress calendar heatmap")
    }

    private func monthDayCell(point: StressDataPoint) -> some View {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: point.date)
        let isToday = calendar.isDateInToday(point.date)

        return VStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 4)
                .fill(stressColor(for: point.level).opacity(0.75))
                .frame(height: 28)
                .overlay(
                    Text("\(day)")
                        .font(.system(size: 10, weight: isToday ? .bold : .regular,
                                      design: .rounded))
                        .foregroundStyle(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isToday ? Color.primary : Color.clear,
                            lineWidth: 1.5
                        )
                )
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(
            "Day \(day): stress \(Int(point.score)), "
            + "\(point.level.displayName)"
        )
    }

    // MARK: - Heatmap Legend

    private var heatmapLegend: some View {
        HStack(spacing: ThumpSpacing.md) {
            legendItem(color: ThumpColors.relaxed, label: "Relaxed")
            legendItem(color: ThumpColors.balanced, label: "Balanced")
            legendItem(color: ThumpColors.elevated, label: "Elevated")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, ThumpSpacing.xxs)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.8))
                .frame(width: 12, height: 12)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
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

    // MARK: - Smart Action Card

    @ViewBuilder
    private var smartActionCard: some View {
        switch viewModel.smartAction {
        case .journalPrompt(let prompt):
            actionCard(
                icon: prompt.icon,
                iconColor: .purple,
                title: "Journal Time",
                message: prompt.question,
                detail: prompt.context,
                buttonLabel: "Start Writing",
                buttonIcon: "pencil"
            )

        case .breatheOnWatch(let nudge):
            actionCard(
                icon: "wind",
                iconColor: ThumpColors.elevated,
                title: nudge.title,
                message: nudge.description,
                detail: nil,
                buttonLabel: "Open on Watch",
                buttonIcon: "applewatch"
            )

        case .morningCheckIn(let message):
            actionCard(
                icon: "sun.max.fill",
                iconColor: .yellow,
                title: "Morning Check-In",
                message: message,
                detail: nil,
                buttonLabel: "Share How You Feel",
                buttonIcon: "hand.wave.fill"
            )

        case .bedtimeWindDown(let nudge):
            actionCard(
                icon: "moon.fill",
                iconColor: .indigo,
                title: nudge.title,
                message: nudge.description,
                detail: nil,
                buttonLabel: "Got It",
                buttonIcon: "checkmark"
            )

        case .standardNudge:
            EmptyView()
        }
    }

    private func actionCard(
        icon: String,
        iconColor: Color,
        title: String,
        message: String,
        detail: String?,
        buttonLabel: String,
        buttonIcon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: ThumpSpacing.sm) {
            HStack(spacing: ThumpSpacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                // Action handled by view model
                viewModel.handleSmartAction()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: buttonIcon)
                        .font(.caption)
                    Text(buttonLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ThumpSpacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(iconColor)
        }
        .padding(ThumpSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ThumpRadius.md)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
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
                Text("Not enough data for summary yet.")
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

    private var emptyHeatmapState: some View {
        VStack(spacing: ThumpSpacing.xs) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Not enough data for this range")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Insufficient data for stress heatmap")
    }

    // MARK: - Helpers

    private func stressColor(for level: StressLevel) -> Color {
        switch level {
        case .relaxed: return ThumpColors.relaxed
        case .balanced: return ThumpColors.balanced
        case .elevated: return ThumpColors.elevated
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "p" : "a"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour)\(period)"
    }

    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func formatDayHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Stress View") {
    StressView()
}

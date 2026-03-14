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

    // MARK: - Date Formatters (static to avoid per-render allocation)

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()
    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f
    }()

    // MARK: - View Model

    @StateObject private var viewModel = StressViewModel()
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
        .accessibilityIdentifier("stress_calendar")
    }

    private var heatmapTitle: String {
        switch viewModel.selectedRange {
        case .day: return "Today: Hourly Stress"
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
            InteractionLog.log(.cardTap, element: "stress_calendar", page: "Stress", details: formatWeekday(point.date))
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

    // MARK: - Stress Trend Chart

    /// Line chart showing stress score trend over time with
    /// increase/decrease shading. Placed directly below the heatmap
    /// so users can see the pattern at a glance.
    @ViewBuilder
    private var stressTrendChart: some View {
        let points = viewModel.chartDataPoints
        if points.count >= 3 {
            VStack(alignment: .leading, spacing: ThumpSpacing.sm) {
                HStack {
                    Text("Stress Trend")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    if let latest = points.last {
                        Text("\(Int(latest.value))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(stressScoreColor(latest.value))
                        + Text(" now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Mini trend chart
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let minScore = max(0, (points.map(\.value).min() ?? 0) - 10)
                    let maxScore = min(100, (points.map(\.value).max() ?? 100) + 10)
                    let range = max(maxScore - minScore, 1)

                    ZStack {
                        // Background zones
                        stressZoneBackground(height: height, minScore: minScore, range: range)

                        // Line path
                        Path { path in
                            for (index, point) in points.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                                let y = height * (1 - CGFloat((point.value - minScore) / range))
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [ThumpColors.relaxed, ThumpColors.balanced, ThumpColors.elevated],
                                startPoint: .bottom,
                                endPoint: .top
                            ),
                            lineWidth: 2.5
                        )

                        // Data point dots
                        ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                            let x = width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                            let y = height * (1 - CGFloat((point.value - minScore) / range))
                            Circle()
                                .fill(stressScoreColor(point.value))
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(height: 140)

                // X-axis date labels
                HStack {
                    ForEach(xAxisLabels(points: points), id: \.offset) { item in
                        if item.offset > 0 { Spacer() }
                        Text(item.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)

                // Change indicator
                if points.count >= 2 {
                    let firstHalf = Array(points.prefix(points.count / 2))
                    let secondHalf = Array(points.suffix(points.count - points.count / 2))
                    let firstAvg = firstHalf.map(\.value).reduce(0, +) / Double(max(firstHalf.count, 1))
                    let secondAvg = secondHalf.map(\.value).reduce(0, +) / Double(max(secondHalf.count, 1))
                    let change = secondAvg - firstAvg

                    HStack(spacing: 6) {
                        Image(systemName: change < -2 ? "arrow.down.right" : (change > 2 ? "arrow.up.right" : "arrow.right"))
                            .font(.caption)
                            .foregroundStyle(change < -2 ? ThumpColors.relaxed : (change > 2 ? ThumpColors.elevated : ThumpColors.balanced))

                        Text(change < -2
                             ? String(format: "Stress decreased by %.0f points", abs(change))
                             : (change > 2
                                ? String(format: "Stress increased by %.0f points", change)
                                : "Stress level is steady"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(ThumpSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: ThumpRadius.md)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Stress trend chart")
        }
    }

    private func stressZoneBackground(height: CGFloat, minScore: Double, range: Double) -> some View {
        ZStack(alignment: .top) {
            // Relaxed zone (0-35)
            let relaxedTop = max(0, 1 - CGFloat((35 - minScore) / range))
            let relaxedBottom = 1.0 - max(0, CGFloat((0 - minScore) / range))
            Rectangle()
                .fill(ThumpColors.relaxed.opacity(0.05))
                .frame(height: height * (relaxedBottom - relaxedTop))
                .offset(y: height * relaxedTop)

            // Balanced zone (35-65)
            let balancedTop = max(0, 1 - CGFloat((65 - minScore) / range))
            let balancedBottom = max(0, 1 - CGFloat((35 - minScore) / range))
            Rectangle()
                .fill(ThumpColors.balanced.opacity(0.05))
                .frame(height: height * (balancedBottom - balancedTop))
                .offset(y: height * balancedTop)

            // Elevated zone (65-100)
            let elevatedTop = max(0, 1 - CGFloat((100 - minScore) / range))
            let elevatedBottom = max(0, 1 - CGFloat((65 - minScore) / range))
            Rectangle()
                .fill(ThumpColors.elevated.opacity(0.05))
                .frame(height: height * (elevatedBottom - elevatedTop))
                .offset(y: height * elevatedTop)
        }
        .frame(height: height)
    }

    private func stressScoreColor(_ score: Double) -> Color {
        if score < 35 { return ThumpColors.relaxed }
        if score < 65 { return ThumpColors.balanced }
        return ThumpColors.elevated
    }

    /// Generates evenly-spaced X-axis date labels for the stress trend chart.
    /// Shows 3-5 labels depending on data density.
    private func xAxisLabels(points: [(date: Date, value: Double)]) -> [(offset: Int, label: String)] {
        guard points.count >= 2 else { return [] }

        let count = points.count

        // Pick the pre-allocated formatter for the current time range
        let formatter: DateFormatter
        switch viewModel.selectedRange {
        case .day:
            formatter = Self.hourFormatter
        case .week:
            formatter = Self.weekdayFormatter
        case .month:
            formatter = Self.monthDayFormatter
        }

        // Pick 3-5 evenly spaced indices including first and last
        let maxLabels = min(5, count)
        let step = max(1, (count - 1) / (maxLabels - 1))
        var indices: [Int] = []
        var i = 0
        while i < count {
            indices.append(i)
            i += step
        }
        if indices.last != count - 1 {
            indices.append(count - 1)
        }

        return indices.enumerated().map { idx, pointIndex in
            (offset: idx, label: formatter.string(from: points[pointIndex].date))
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

    // MARK: - Smart Actions Section

    private var smartActionsSection: some View {
        VStack(alignment: .leading, spacing: ThumpSpacing.sm) {
            HStack {
                Text("Suggestions for You")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("Based on your data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("stress_checkin_section")

            ForEach(
                Array(viewModel.smartActions.enumerated()),
                id: \.offset
            ) { _, action in
                smartActionView(for: action)
            }
        }
    }

    @ViewBuilder
    private func smartActionView(
        for action: SmartNudgeAction
    ) -> some View {
        switch action {
        case .journalPrompt(let prompt):
            actionCard(
                icon: prompt.icon,
                iconColor: .purple,
                title: "Journal Time",
                message: prompt.question,
                detail: prompt.context,
                buttonLabel: "Start Writing",
                buttonIcon: "pencil",
                action: action
            )

        case .breatheOnWatch(let nudge):
            actionCard(
                icon: "wind",
                iconColor: ThumpColors.elevated,
                title: nudge.title,
                message: nudge.description,
                detail: nil,
                buttonLabel: "Open on Watch",
                buttonIcon: "applewatch",
                action: action
            )

        case .morningCheckIn(let message):
            actionCard(
                icon: "sun.max.fill",
                iconColor: .yellow,
                title: "Morning Check-In",
                message: message,
                detail: nil,
                buttonLabel: "Share How You Feel",
                buttonIcon: "hand.wave.fill",
                action: action
            )

        case .bedtimeWindDown(let nudge):
            actionCard(
                icon: "moon.fill",
                iconColor: .indigo,
                title: nudge.title,
                message: nudge.description,
                detail: nil,
                buttonLabel: "Got It",
                buttonIcon: "checkmark",
                action: action
            )

        case .activitySuggestion(let nudge):
            actionCard(
                icon: nudge.icon,
                iconColor: .green,
                title: nudge.title,
                message: nudge.description,
                detail: nudge.durationMinutes.map {
                    "\($0) min"
                },
                buttonLabel: "Let's Go",
                buttonIcon: "figure.walk",
                action: action
            )

        case .restSuggestion(let nudge):
            actionCard(
                icon: nudge.icon,
                iconColor: .indigo,
                title: nudge.title,
                message: nudge.description,
                detail: nil,
                buttonLabel: "Set Reminder",
                buttonIcon: "bell.fill",
                action: action
            )

        case .standardNudge:
            stressGuidanceCard
        }
    }

    private func actionCard(
        icon: String,
        iconColor: Color,
        title: String,
        message: String,
        detail: String?,
        buttonLabel: String,
        buttonIcon: String,
        action: SmartNudgeAction
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
                InteractionLog.log(.buttonTap, element: "nudge_card", page: "Stress", details: title)
                viewModel.handleSmartAction(action)
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

    // MARK: - Stress Guidance Card (Default Action)

    /// Always-visible guidance card that gives actionable tips based on
    /// the current stress level. Shown when no specific smart action
    /// (journal, breathe, check-in, wind-down) is triggered.
    private var stressGuidanceCard: some View {
        let stress = viewModel.currentStress
        let level = stress?.level ?? .balanced
        let guidance = stressGuidance(for: level)

        return VStack(alignment: .leading, spacing: ThumpSpacing.sm) {
            HStack(spacing: ThumpSpacing.xs) {
                Image(systemName: guidance.icon)
                    .font(.title3)
                    .foregroundStyle(guidance.color)

                Text("What You Can Do")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text(guidance.headline)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(guidance.color)

            Text(guidance.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Quick action buttons
            HStack(spacing: ThumpSpacing.xs) {
                ForEach(guidance.actions, id: \.label) { action in
                    Button {
                        InteractionLog.log(.buttonTap, element: "stress_guidance_action", page: "Stress", details: action.label)
                        handleGuidanceAction(action)
                    } label: {
                        Label(action.label, systemImage: action.icon)
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ThumpSpacing.xs)
                    }
                    .buttonStyle(.bordered)
                    .tint(guidance.color)
                }
            }
        }
        .padding(ThumpSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ThumpRadius.md)
                .fill(guidance.color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ThumpRadius.md)
                .strokeBorder(guidance.color.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private struct StressGuidance {
        let headline: String
        let detail: String
        let icon: String
        let color: Color
        let actions: [QuickAction]
    }

    private struct QuickAction: Hashable {
        let label: String
        let icon: String
    }

    private func stressGuidance(for level: StressLevel) -> StressGuidance {
        switch level {
        case .relaxed:
            return StressGuidance(
                headline: "You're in a Great Spot",
                detail: "Your body is recovered and ready. This is a good time for a challenging workout, creative work, or anything that takes focus.",
                icon: "leaf.fill",
                color: ThumpColors.relaxed,
                actions: [
                    QuickAction(label: "Workout", icon: "figure.run"),
                    QuickAction(label: "Focus Time", icon: "brain.head.profile")
                ]
            )
        case .balanced:
            return StressGuidance(
                headline: "Keep Up the Balance",
                detail: "Your stress is in a healthy range. A walk, some stretching, or a short break between tasks can help you stay here.",
                icon: "circle.grid.cross.fill",
                color: ThumpColors.balanced,
                actions: [
                    QuickAction(label: "Take a Walk", icon: "figure.walk"),
                    QuickAction(label: "Stretch", icon: "figure.cooldown")
                ]
            )
        case .elevated:
            return StressGuidance(
                headline: "Time to Ease Up",
                detail: "Your body could use some recovery. Try a few slow breaths, step outside for fresh air, or take a 10-minute break. Even small pauses make a difference.",
                icon: "flame.fill",
                color: ThumpColors.elevated,
                actions: [
                    QuickAction(label: "Breathe", icon: "wind"),
                    QuickAction(label: "Step Outside", icon: "sun.max.fill"),
                    QuickAction(label: "Rest", icon: "bed.double.fill")
                ]
            )
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

    private var emptyHeatmapState: some View {
        VStack(spacing: ThumpSpacing.xs) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Need 3+ days of data for this view")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Insufficient data for stress heatmap")
    }

    // MARK: - Guidance Action Handler

    private func handleGuidanceAction(_ action: QuickAction) {
        switch action.label {
        case "Breathe":
            viewModel.startBreathingSession()
        case "Take a Walk", "Step Outside", "Workout":
            viewModel.showWalkSuggestion()
        case "Rest":
            viewModel.startBreathingSession()
        default:
            break
        }
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
        Self.weekdayFormatter.string(from: date)
    }

    private func formatDayHeader(_ date: Date) -> String {
        Self.dayHeaderFormatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        Self.shortDateFormatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Stress View") {
    StressView()
}

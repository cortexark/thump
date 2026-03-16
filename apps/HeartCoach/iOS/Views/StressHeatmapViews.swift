// StressHeatmapViews.swift
// Thump iOS
//
// Extracted from StressView.swift — calendar-style heatmap components
// for day (hourly), week (daily), and month (calendar grid) views.
// Reduces StressView diffing scope for faster SwiftUI rendering.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - Heatmap Card

extension StressView {

    var heatmapCard: some View {
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

    var heatmapTitle: String {
        switch viewModel.selectedRange {
        case .day: return "Today: Hourly Stress"
        case .week: return "This Week"
        case .month: return "This Month"
        }
    }

    // MARK: - Day Heatmap (24 hourly boxes)

    var dayHeatmap: some View {
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

    func hourlyCell(hour: Int) -> some View {
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

    var weekHeatmap: some View {
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

    func dailyCell(point: StressDataPoint) -> some View {
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

    func miniHourCell(point: HourlyStressPoint) -> some View {
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

    var monthHeatmap: some View {
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

    func monthDayCell(point: StressDataPoint) -> some View {
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

    var heatmapLegend: some View {
        HStack(spacing: ThumpSpacing.md) {
            legendItem(color: ThumpColors.relaxed, label: "Relaxed")
            legendItem(color: ThumpColors.balanced, label: "Balanced")
            legendItem(color: ThumpColors.elevated, label: "Elevated")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, ThumpSpacing.xxs)
    }

    func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.8))
                .frame(width: 12, height: 12)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State

    var emptyHeatmapState: some View {
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
}

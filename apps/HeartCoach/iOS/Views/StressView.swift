// StressView.swift
// Thump iOS
//
// Displays the HRV-based stress metric with a visual gauge, friendly
// messaging, time range picker, trend chart, and summary statistics.
// Uses the same card-based visual style as TrendsView.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - StressView

/// A dedicated view for the HRV-based stress feature.
///
/// Shows the current stress level with a color-coded gauge, friendly
/// language, and day/week/month trend charting powered by the
/// ``StressEngine``.
struct StressView: View {

    // MARK: - View Model

    @StateObject private var viewModel = StressViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    currentStressCard
                    timeRangePicker
                    trendChartCard
                    summaryStatsCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stress")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Current Stress Card

    private var currentStressCard: some View {
        VStack(spacing: 16) {
            if let stress = viewModel.currentStress {
                stressGauge(stress: stress)

                Text(stress.level.friendlyMessage)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(
                        "Current stress level: "
                        + "\(stress.level.displayName)"
                    )

                Text(stress.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(
                        "Stress description: \(stress.description)"
                    )
            } else {
                emptyStressState
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stress Gauge

    /// A color-coded circular gauge showing the current stress score.
    private func stressGauge(stress: StressResult) -> some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    Color(.systemGray5),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 120, height: 120)

            // Filled arc representing score
            Circle()
                .trim(from: 0, to: stress.score / 100.0)
                .stroke(
                    stressColor(for: stress.level),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: stress.score)

            // Center content
            VStack(spacing: 4) {
                Image(systemName: stress.level.icon)
                    .font(.title2)
                    .foregroundStyle(stressColor(for: stress.level))

                Text("\(Int(stress.score))")
                    .font(.title)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityLabel(
            "Stress score \(Int(stress.score)) out of 100, "
            + "\(stress.level.displayName)"
        )
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedRange) {
            Text("Day").tag(TimeRange.day)
            Text("Week").tag(TimeRange.week)
            Text("Month").tag(TimeRange.month)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Stress trend time range")
    }

    // MARK: - Trend Chart Card

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stress Trend")
                .font(.headline)
                .foregroundStyle(.primary)

            if viewModel.chartDataPoints.isEmpty {
                emptyChartState
            } else {
                TrendChartView(
                    dataPoints: viewModel.chartDataPoints,
                    metricLabel: "Stress",
                    color: trendChartColor
                )
                .frame(height: 240)
                .accessibilityLabel(
                    "Stress trend chart showing "
                    + "\(viewModel.chartDataPoints.count) data points"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Summary Stats Card

    private var summaryStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                .accessibilityLabel(summaryAccessibilityLabel)
            } else {
                Text("Not enough data for summary statistics yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
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

    private var emptyStressState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No Stress Data Yet")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(
                "Wear your Apple Watch regularly to collect "
                + "HRV data. Your stress insights will appear "
                + "here once we have enough readings."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No stress data available yet")
    }

    private var emptyChartState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Not enough data for this range")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Insufficient data for stress trend chart")
    }

    // MARK: - Helpers

    /// Returns the accent color for the current stress level.
    private func stressColor(for level: StressLevel) -> Color {
        switch level {
        case .relaxed: return .green
        case .balanced: return .orange
        case .elevated: return .red
        }
    }

    /// The color used for the trend chart line, based on average stress.
    private var trendChartColor: Color {
        guard let avg = viewModel.averageStress else { return .blue }
        let level = StressLevel.from(score: avg)
        return stressColor(for: level)
    }

    /// Formats a date for display in summary stats.
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    /// Accessibility label for the full summary section.
    private var summaryAccessibilityLabel: String {
        var parts: [String] = []
        if let avg = viewModel.averageStress {
            let level = StressLevel.from(score: avg)
            parts.append(
                "Average stress score \(Int(avg)), \(level.displayName)"
            )
        }
        if let relaxed = viewModel.mostRelaxedDay {
            parts.append(
                "Most relaxed day: \(formatDate(relaxed.date)) "
                + "with score \(Int(relaxed.score))"
            )
        }
        if let elevated = viewModel.mostElevatedDay {
            parts.append(
                "Highest stress day: \(formatDate(elevated.date)) "
                + "with score \(Int(elevated.score))"
            )
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Preview

#Preview("Stress View") {
    StressView()
}

#Preview("Stress Gauge - Relaxed") {
    let stress = StressResult(
        score: 22,
        level: .relaxed,
        description: "You seem pretty relaxed right now"
    )
    StressView()
        .onAppear {}
}

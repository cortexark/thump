// TrendsView.swift
// Thump iOS
//
// Displays historical heart metric trends using Swift Charts. Users can
// switch between metric types (RHR, HRV, Recovery, VO2 Max, Steps) and
// time ranges (Week, Two Weeks, Month). A summary statistics row shows
// average, minimum, and maximum values for the selected metric.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - TrendsView

/// Historical trend visualization with metric and time range selectors.
///
/// Data is loaded asynchronously from `TrendsViewModel` and displayed
/// through the `TrendChartView` chart component.
struct TrendsView: View {

    // MARK: - View Model

    @StateObject private var viewModel = TrendsViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                metricPicker
                timeRangePicker
                chartSection
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadHistory()
            }
        }
    }

    // MARK: - Metric Picker

    private var metricPicker: some View {
        Picker("Metric", selection: $viewModel.selectedMetric) {
            Text("RHR").tag(TrendsViewModel.MetricType.restingHR)
            Text("HRV").tag(TrendsViewModel.MetricType.hrv)
            Text("Recovery").tag(TrendsViewModel.MetricType.recovery)
            Text("VO2").tag(TrendsViewModel.MetricType.vo2Max)
            Text("Steps").tag(TrendsViewModel.MetricType.steps)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.timeRange) {
            Text("7D").tag(TrendsViewModel.TimeRange.week)
            Text("14D").tag(TrendsViewModel.TimeRange.twoWeeks)
            Text("30D").tag(TrendsViewModel.TimeRange.month)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        let points = viewModel.dataPoints(for: viewModel.selectedMetric)

        return ScrollView {
            VStack(spacing: 20) {
                if points.isEmpty {
                    emptyDataView
                } else {
                    chartCard(points: points)
                    summaryStats(points: points)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Chart Card

    private func chartCard(points: [(date: Date, value: Double)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(metricDisplayName)
                .font(.headline)
                .foregroundStyle(.primary)

            TrendChartView(
                dataPoints: points,
                metricLabel: metricUnit,
                color: metricColor
            )
            .frame(height: 240)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Summary Statistics

    private func summaryStats(points: [(date: Date, value: Double)]) -> some View {
        let values = points.map(\.value)
        let avg = values.reduce(0, +) / Double(values.count)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 0) {
                statItem(label: "Average", value: formatValue(avg))
                Divider().frame(height: 40)
                statItem(label: "Minimum", value: formatValue(minVal))
                Divider().frame(height: 40)
                statItem(label: "Maximum", value: formatValue(maxVal))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Data Available")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Wear your Apple Watch regularly to collect health metrics. Data will appear here once available.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Metric Helpers

    /// Human-readable name for the currently selected metric.
    private var metricDisplayName: String {
        switch viewModel.selectedMetric {
        case .restingHR: return "Resting Heart Rate"
        case .hrv:       return "Heart Rate Variability"
        case .recovery:  return "Recovery Heart Rate"
        case .vo2Max:    return "VO2 Max"
        case .steps:     return "Daily Steps"
        }
    }

    /// Unit string for the currently selected metric.
    private var metricUnit: String {
        switch viewModel.selectedMetric {
        case .restingHR: return "bpm"
        case .hrv:       return "ms"
        case .recovery:  return "bpm"
        case .vo2Max:    return "mL/kg/min"
        case .steps:     return "steps"
        }
    }

    /// Accent color for the currently selected metric chart.
    private var metricColor: Color {
        switch viewModel.selectedMetric {
        case .restingHR: return .red
        case .hrv:       return .blue
        case .recovery:  return .green
        case .vo2Max:    return .purple
        case .steps:     return .orange
        }
    }

    /// Formats a Double value sensibly based on the selected metric.
    private func formatValue(_ value: Double) -> String {
        switch viewModel.selectedMetric {
        case .restingHR, .recovery, .steps:
            return "\(Int(value))"
        case .hrv, .vo2Max:
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Preview

#Preview("Trends View") {
    TrendsView()
}

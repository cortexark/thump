// TrendChartView.swift
// Thump iOS
//
// A Swift Charts component that renders a line + area chart for a given
// set of time-series data points. Includes:
// - LineMark with smooth interpolation
// - AreaMark with a gradient fill below the line
// - PointMark for each data point
// - RuleMark for the average (dashed line)
// - Configurable color and metric label
// - Empty data state handling
//
// Platforms: iOS 17+

import SwiftUI
import Charts

// MARK: - TrendChartView

/// A time-series chart component displaying health metric trends.
///
/// Uses Swift Charts to render line, area, point, and rule marks.
/// The chart automatically adapts axis labels to the data range
/// and shows a dashed average reference line.
struct TrendChartView: View {

    // MARK: - Properties

    /// The time-series data points to chart.
    let dataPoints: [(date: Date, value: Double)]

    /// The unit label for the Y axis (e.g. "bpm", "ms").
    let metricLabel: String

    /// The accent color for the chart elements.
    let color: Color

    // MARK: - Computed

    /// The average value across all data points.
    private var averageValue: Double {
        guard dataPoints.count > 0 else { return 0 }
        return dataPoints.map(\.value).reduce(0, +) / Double(dataPoints.count)
    }

    /// The minimum Y value with some padding for visual breathing room.
    private var yMin: Double {
        guard let minVal = dataPoints.map(\.value).min() else { return 0 }
        let range = (dataPoints.map(\.value).max() ?? 0) - minVal
        let padding = range == 0 ? Swift.max(abs(minVal * 0.1), 1.0) : range * 0.1
        return minVal - padding
    }

    /// The maximum Y value with padding.
    private var yMax: Double {
        guard let maxVal = dataPoints.map(\.value).max() else { return 100 }
        let range = maxVal - (dataPoints.map(\.value).min() ?? 0)
        let padding = range == 0 ? Swift.max(abs(maxVal * 0.1), 1.0) : range * 0.1
        return maxVal + padding
    }

    // MARK: - Body

    var body: some View {
        if dataPoints.isEmpty {
            emptyState
        } else {
            chart
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            // Area fill below the line
            ForEach(dataPoints.indices, id: \.self) { index in
                let point = dataPoints[index]
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value(metricLabel, point.value)
                )
                .foregroundStyle(areaGradient)
                .interpolationMethod(.catmullRom)
            }

            // Main line
            ForEach(dataPoints.indices, id: \.self) { index in
                let point = dataPoints[index]
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(metricLabel, point.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            // Data points
            ForEach(dataPoints.indices, id: \.self) { index in
                let point = dataPoints[index]
                PointMark(
                    x: .value("Date", point.date),
                    y: .value(metricLabel, point.value)
                )
                .foregroundStyle(color)
                .symbolSize(30)
            }

            // Average reference line
            RuleMark(y: .value("Average", averageValue))
                .foregroundStyle(color.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text("Avg: \(formattedAverage)")
                        .font(.caption2)
                        .foregroundStyle(color.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                }
        }
        .chartYScale(domain: yMin...yMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: axisStride)) { _ in
                AxisGridLine()
                    .foregroundStyle(Color(.systemGray5))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                    .foregroundStyle(Color(.systemGray5))
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
                .clipped()
        }
        .clipped()
    }

    // MARK: - Area Gradient

    /// A top-to-bottom gradient fill for the area beneath the line.
    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(0.3),
                color.opacity(0.08),
                color.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Axis Stride

    /// Determines appropriate axis label spacing based on data point count.
    private var axisStride: Int {
        let count = dataPoints.count
        if count <= 7 { return 1 }
        if count <= 14 { return 2 }
        return 5
    }

    // MARK: - Formatted Average

    private var formattedAverage: String {
        if averageValue >= 1000 {
            return String(format: "%.0f", averageValue)
        } else if averageValue >= 10 {
            return String(format: "%.0f", averageValue)
        } else {
            return String(format: "%.1f", averageValue)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No data available")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Wear your Apple Watch to start collecting data.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview Helpers

/// Generates mock time-series data for chart previews.
private func mockDataPoints(count: Int, baseValue: Double, variance: Double) -> [(date: Date, value: Double)] {
    let calendar = Calendar.current
    return (0..<count).compactMap { i in
        guard let date = calendar.date(
            byAdding: .day,
            value: -count + i + 1,
            to: Date()
        ) else {
            return nil
        }
        let jitter = Double.random(in: -variance...variance)
        let trend = Double(i) * 0.3 // slight upward trend
        return (date: date, value: baseValue + jitter + trend)
    }
}

#Preview("Resting HR - 7 Days") {
    TrendChartView(
        dataPoints: mockDataPoints(count: 7, baseValue: 62, variance: 4),
        metricLabel: "bpm",
        color: .red
    )
    .frame(height: 240)
    .padding()
}

#Preview("HRV - 30 Days") {
    TrendChartView(
        dataPoints: mockDataPoints(count: 30, baseValue: 45, variance: 8),
        metricLabel: "ms",
        color: .blue
    )
    .frame(height: 240)
    .padding()
}

#Preview("Steps - 14 Days") {
    TrendChartView(
        dataPoints: mockDataPoints(count: 14, baseValue: 8000, variance: 2000),
        metricLabel: "steps",
        color: .orange
    )
    .frame(height: 240)
    .padding()
}

#Preview("Empty State") {
    TrendChartView(
        dataPoints: [],
        metricLabel: "bpm",
        color: .red
    )
    .frame(height: 240)
    .padding()
}

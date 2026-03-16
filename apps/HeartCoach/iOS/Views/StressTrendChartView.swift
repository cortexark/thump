// StressTrendChartView.swift
// Thump iOS
//
// Extracted from StressView.swift — stress trend line chart with
// zone background, x-axis labels, data point dots, and change indicator.
// Isolated for smaller SwiftUI diffing scope.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - Stress Trend Chart

extension StressView {

    /// Line chart showing stress score trend over time with
    /// increase/decrease shading. Placed directly below the heatmap
    /// so users can see the pattern at a glance.
    @ViewBuilder
    var stressTrendChart: some View {
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

    // MARK: - Zone Background

    func stressZoneBackground(height: CGFloat, minScore: Double, range: Double) -> some View {
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

    // MARK: - Score Color

    func stressScoreColor(_ score: Double) -> Color {
        if score < 35 { return ThumpColors.relaxed }
        if score < 65 { return ThumpColors.balanced }
        return ThumpColors.elevated
    }

    // MARK: - X-Axis Labels

    /// Generates evenly-spaced X-axis date labels for the stress trend chart.
    /// Shows 3-5 labels depending on data density.
    func xAxisLabels(points: [(date: Date, value: Double)]) -> [(offset: Int, label: String)] {
        guard points.count >= 2 else { return [] }

        let count = points.count

        // Pick the pre-allocated formatter for the current time range
        let formatter: DateFormatter
        switch viewModel.selectedRange {
        case .day:
            formatter = ThumpFormatters.hour
        case .week:
            formatter = ThumpFormatters.weekday
        case .month:
            formatter = ThumpFormatters.monthDay
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
}

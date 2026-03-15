// TrendsView.swift
// Thump iOS
//
// Your health story over time. Warm, visual, narrative-driven —
// not just a chart with numbers. Each metric has personality and
// the insight card talks to you like a friend, not a lab report.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - TrendsView

struct TrendsView: View {

    @StateObject private var viewModel = TrendsViewModel()
    @EnvironmentObject private var healthKitService: HealthKitService

    @State private var animateChart = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero header with gradient + metric name
                    trendHeroHeader

                    VStack(spacing: 16) {
                        metricPicker
                        timeRangePicker

                        let points = viewModel.dataPoints(for: viewModel.selectedMetric)
                        if points.isEmpty {
                            emptyDataView
                        } else {
                            chartCard(points: points)
                            highlightStatsRow(points: points)
                            activityHeartCorrelationCard
                            coachingProgressCard
                            weeklyGoalCompletionCard
                            missedDaysCard(points: points)
                            trendInsightCard(points: points)
                            improvementTipCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { InteractionLog.pageView("Trends") }
            .task {
                viewModel.bind(healthKitService: healthKitService)
                await viewModel.loadHistory()
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    animateChart = true
                }
            }
            .onChange(of: viewModel.selectedMetric) { _, newValue in
                InteractionLog.log(.pickerChange, element: "metric_selector", page: "Trends", details: "\(newValue)")
            }
            .onChange(of: viewModel.timeRange) { _, newValue in
                InteractionLog.log(.pickerChange, element: "time_range_selector", page: "Trends", details: "\(newValue)")
            }
            .onChange(of: viewModel.selectedMetric) { _, _ in
                animateChart = false
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    animateChart = true
                }
            }
        }
    }

    // MARK: - Hero Header

    private var trendHeroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [metricColor.opacity(0.8), metricColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: 0
            ))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: metricIcon)
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text("Trends")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                Text("Your \(metricDisplayName.lowercased()) story")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Metric Picker

    private var metricPicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                metricChip("RHR", icon: "heart.fill", metric: .restingHR)
                metricChip("HRV", icon: "waveform.path.ecg", metric: .hrv)
                metricChip("Recovery", icon: "arrow.uturn.up", metric: .recovery)
            }
            HStack(spacing: 8) {
                metricChip("Cardio Fitness", icon: "lungs.fill", metric: .vo2Max)
                metricChip("Active", icon: "figure.run", metric: .activeMinutes)
            }
        }
        .accessibilityIdentifier("metric_selector")
    }

    private func metricChip(_ label: String, icon: String, metric: TrendsViewModel.MetricType) -> some View {
        let isSelected = viewModel.selectedMetric == metric
        let chipColor = isSelected ? metricColorFor(metric) : Color(.secondarySystemGroupedBackground)

        return Button {
            InteractionLog.log(.buttonTap, element: "metric_selector", page: "Trends", details: label)
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedMetric = metric
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(chipColor, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? .clear : Color(.separator).opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) metric")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 8) {
            ForEach(
                [(TrendsViewModel.TimeRange.week, "7D"),
                 (.twoWeeks, "14D"),
                 (.month, "30D")],
                id: \.0
            ) { range, label in
                let isSelected = viewModel.timeRange == range
                Button {
                    InteractionLog.log(.buttonTap, element: "time_range_selector", page: "Trends", details: label)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.timeRange = range
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            isSelected ? metricColor : Color(.tertiarySystemGroupedBackground),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Chart Card

    private func chartCard(points: [(date: Date, value: Double)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(metricDisplayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if let latest = points.last {
                    Text(formatValue(latest.value))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(metricColor)
                    + Text(" \(metricUnit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TrendChartView(
                dataPoints: points,
                metricLabel: metricUnit,
                color: metricColor
            )
            .frame(height: 220)
            .opacity(animateChart ? 1 : 0.3)
            .scaleEffect(y: animateChart ? 1 : 0.8, anchor: .bottom)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityIdentifier("trend_chart")
    }

    // MARK: - Highlight Stats

    private func highlightStatsRow(points: [(date: Date, value: Double)]) -> some View {
        let values = points.map(\.value)
        let avg = values.reduce(0, +) / Double(values.count)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0

        return HStack(spacing: 8) {
            statPill(label: "Avg", value: formatValue(avg), icon: "equal.circle.fill", color: metricColor)
            statPill(label: "Low", value: formatValue(minVal), icon: "arrow.down.circle.fill", color: Color(hex: 0x0D9488))
            statPill(label: "High", value: formatValue(maxVal), icon: "arrow.up.circle.fill", color: Color(hex: 0xF59E0B))
        }
    }

    private func statPill(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityLabel("\(label): \(value) \(metricUnit)")
    }

    // MARK: - Trend Insight Card

    private func trendInsightCard(points: [(date: Date, value: Double)]) -> some View {
        let insight = trendInsight(for: points)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: insight.icon)
                    .font(.title3)
                    .foregroundStyle(insight.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.headline)
                        .font(.headline)
                        .foregroundStyle(insight.color)
                    Text("What's happening")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(insight.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(insight.color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(insight.color.opacity(0.15), lineWidth: 1)
        )
    }

    private struct TrendInsight {
        let headline: String
        let detail: String
        let icon: String
        let color: Color
    }

    private func trendInsight(for points: [(date: Date, value: Double)]) -> TrendInsight {
        let values = points.map(\.value)
        guard values.count >= 4 else {
            return TrendInsight(
                headline: "Building Your Story",
                detail: "A few more days of wearing your watch and we'll have a clear picture of your trends. Hang tight!",
                icon: "clock.fill",
                color: .secondary
            )
        }

        let midpoint = values.count / 2
        let firstAvg = values.prefix(midpoint).reduce(0, +) / Double(midpoint)
        let secondAvg = values.suffix(values.count - midpoint).reduce(0, +) / Double(values.count - midpoint)
        let percentChange = (secondAvg - firstAvg) / firstAvg * 100

        let lowerIsBetter = viewModel.selectedMetric == .restingHR
        let improving = lowerIsBetter ? percentChange < -2 : percentChange > 2
        let worsening = lowerIsBetter ? percentChange > 2 : percentChange < -2
        let change = abs(percentChange)

        let rangeDescription = change < 2 ? "barely any" : (change < 5 ? "about \(Int(change))%" : "\(Int(change))%")
        let metricName = metricDisplayName.lowercased()

        let shortWindow = viewModel.timeRange == .week
        let windowNote = shortWindow
            ? " Try 14D or 30D for the bigger picture."
            : ""

        if change < 2 {
            return TrendInsight(
                headline: "Holding Steady",
                detail: "Your \(metricName) has remained stable through this period, showing steady patterns.",
                icon: "arrow.right.circle.fill",
                color: Color(hex: 0x3B82F6)
            )
        } else if improving {
            return TrendInsight(
                headline: "Looking Good!",
                detail: "Your \(metricName) shifted \(rangeDescription) in the right direction — the changes you've made are showing results.",
                icon: "arrow.up.right.circle.fill",
                color: Color(hex: 0x22C55E)
            )
        } else if worsening {
            return TrendInsight(
                headline: "Worth Watching",
                detail: "Your \(metricName) shifted \(rangeDescription). Consider factors like stress, sleep, or recent activity changes.\(windowNote)",
                icon: "arrow.down.right.circle.fill",
                color: Color(hex: 0xF59E0B)
            )
        } else {
            return TrendInsight(
                headline: "Holding Steady",
                detail: "Your \(metricName) has been consistent over this period — this consistency indicates stable patterns.",
                icon: "arrow.right.circle.fill",
                color: Color(hex: 0x3B82F6)
            )
        }
    }

    // MARK: - Missed Days Card

    @ViewBuilder
    private func missedDaysCard(points: [(date: Date, value: Double)]) -> some View {
        let expectedDays = viewModel.timeRange == .week ? 7 : (viewModel.timeRange == .twoWeeks ? 14 : 30)
        let missedCount = expectedDays - points.count

        if missedCount >= 2 {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(Color(hex: 0xF59E0B))

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(missedCount) day\(missedCount == 1 ? "" : "s") without data")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Wearing your Apple Watch daily helps build a clearer picture of your trends.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: 0xF59E0B).opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(hex: 0xF59E0B).opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Improvement Tip Card

    /// Actionable, metric-specific advice for the user.
    private var improvementTipCard: some View {
        let tip = improvementTip(for: viewModel.selectedMetric)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0xF59E0B))

                Text("What You Can Do")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text(tip.action)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let goal = tip.monthlyGoal {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundStyle(metricColor)
                    Text(goal)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(metricColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(metricColor.opacity(0.1))
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private struct ImprovementTip {
        let action: String
        let monthlyGoal: String?
    }

    private func improvementTip(for metric: TrendsViewModel.MetricType) -> ImprovementTip {
        switch metric {
        case .restingHR:
            return ImprovementTip(
                action: "Regular walking (30 min/day) is one of the easiest ways to bring resting heart rate down over time. Consistent sleep also helps.",
                monthlyGoal: "Goal: Walk 150+ minutes per week this month"
            )
        case .hrv:
            return ImprovementTip(
                action: "Good sleep habits and regular breathing exercises are commonly associated with higher HRV. Even 5 minutes of slow breathing daily can make a difference.",
                monthlyGoal: "Goal: Try 5 min of slow breathing 3x this week"
            )
        case .recovery:
            return ImprovementTip(
                action: "Recovery heart rate improves with aerobic fitness. Include 2-3 moderate cardio sessions per week — brisk walks, cycling, or swimming.",
                monthlyGoal: "Goal: 3 cardio sessions per week for 4 weeks"
            )
        case .vo2Max:
            return ImprovementTip(
                action: "VO2 Max improves with zone 2 training (conversational pace). Add one longer walk or jog per week alongside your regular activity.",
                monthlyGoal: "Goal: One 45+ min zone 2 session per week"
            )
        case .activeMinutes:
            return ImprovementTip(
                action: "Even short 10-minute walks throughout the day add up. Park farther away, take stairs, or add a post-meal walk to your routine.",
                monthlyGoal: "Goal: Hit 30+ active minutes on 5 days this week"
            )
        }
    }

    // MARK: - Activity → Heart Correlation Card

    /// Shows how activity levels are directly impacting heart metrics.
    /// This is the "hero coaching graph" — connecting effort to results.
    @ViewBuilder
    private var activityHeartCorrelationCard: some View {
        let activityPoints = viewModel.dataPoints(for: .activeMinutes)
        let heartPoints = viewModel.dataPoints(for: viewModel.selectedMetric)

        if activityPoints.count >= 5 && heartPoints.count >= 5
            && (viewModel.selectedMetric == .restingHR || viewModel.selectedMetric == .hrv) {

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.title3)
                        .foregroundStyle(Color(hex: 0x22C55E))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Activity → \(metricDisplayName)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Activity and heart rate patterns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Dual-axis mini chart with axis labels
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        // Left Y-axis label (active min)
                        VStack {
                            Text("\(Int(activityPoints.map(\.value).max() ?? 0))")
                                .font(.system(size: 8))
                                .foregroundStyle(Color(hex: 0x22C55E).opacity(0.6))
                            Spacer()
                            Text("\(Int(activityPoints.map(\.value).min() ?? 0))")
                                .font(.system(size: 8))
                                .foregroundStyle(Color(hex: 0x22C55E).opacity(0.6))
                        }
                        .frame(width: 24, height: 80)

                        GeometryReader { geo in
                            let w = geo.size.width
                            let h = geo.size.height

                            let actVals = activityPoints.map(\.value)
                            let actMin = (actVals.min() ?? 0) * 0.8
                            let actMax = (actVals.max() ?? 1) * 1.2
                            let actRange = max(actMax - actMin, 1)

                            let heartVals = heartPoints.map(\.value)
                            let heartMin = (heartVals.min() ?? 0) * 0.95
                            let heartMax = (heartVals.max() ?? 1) * 1.05
                            let heartRange = max(heartMax - heartMin, 1)

                            ZStack {
                                Path { path in
                                    for (i, point) in activityPoints.prefix(heartPoints.count).enumerated() {
                                        let x = w * CGFloat(i) / CGFloat(max(heartPoints.count - 1, 1))
                                        let y = h * (1 - CGFloat((point.value - actMin) / actRange))
                                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                                    }
                                }
                                .stroke(Color(hex: 0x22C55E).opacity(0.6), lineWidth: 2)

                                Path { path in
                                    for (i, point) in heartPoints.enumerated() {
                                        let x = w * CGFloat(i) / CGFloat(max(heartPoints.count - 1, 1))
                                        let y = h * (1 - CGFloat((point.value - heartMin) / heartRange))
                                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                                    }
                                }
                                .stroke(metricColor, lineWidth: 2)
                            }
                        }
                        .frame(height: 80)

                        // Right Y-axis label (heart metric)
                        VStack {
                            Text("\(Int(heartPoints.map(\.value).max() ?? 0))")
                                .font(.system(size: 8))
                                .foregroundStyle(metricColor.opacity(0.6))
                            Spacer()
                            Text("\(Int(heartPoints.map(\.value).min() ?? 0))")
                                .font(.system(size: 8))
                                .foregroundStyle(metricColor.opacity(0.6))
                        }
                        .frame(width: 24, height: 80)
                    }

                    // X-axis: date labels
                    HStack {
                        Text(heartPoints.first.map { $0.date.formatted(.dateTime.month(.abbreviated).day()) } ?? "")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(heartPoints.last.map { $0.date.formatted(.dateTime.month(.abbreviated).day()) } ?? "")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                }

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: 0x22C55E)).frame(width: 8, height: 8)
                        Text("Active Minutes").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(metricColor).frame(width: 8, height: 8)
                        Text(metricDisplayName).font(.caption2).foregroundStyle(.secondary)
                    }
                }

                // Correlation insight
                let correlation = computeCorrelation(
                    x: activityPoints.prefix(heartPoints.count).map(\.value),
                    y: heartPoints.map(\.value)
                )
                if abs(correlation) > 0.2 {
                    let isPositive = correlation > 0
                    let lowerIsBetter = viewModel.selectedMetric == .restingHR
                    let isGood = lowerIsBetter ? !isPositive : isPositive

                    HStack(spacing: 6) {
                        Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(isGood ? Color(hex: 0x22C55E) : Color(hex: 0xF59E0B))
                        Text(isGood
                             ? "Your activity is positively impacting your \(metricDisplayName.lowercased())!"
                             : "More consistent activity could help improve your \(metricDisplayName.lowercased()).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    /// Simple Pearson correlation coefficient.
    private func computeCorrelation(x: [Double], y: [Double]) -> Double {
        let n = Double(min(x.count, y.count))
        guard n >= 3 else { return 0 }
        let xArr = Array(x.prefix(Int(n)))
        let yArr = Array(y.prefix(Int(n)))
        let xMean = xArr.reduce(0, +) / n
        let yMean = yArr.reduce(0, +) / n
        var num: Double = 0
        var denomX: Double = 0
        var denomY: Double = 0
        for i in 0..<Int(n) {
            let dx = xArr[i] - xMean
            let dy = yArr[i] - yMean
            num += dx * dy
            denomX += dx * dx
            denomY += dy * dy
        }
        let denom = sqrt(denomX * denomY)
        return denom > 0 ? num / denom : 0
    }

    // MARK: - Coaching Progress Card

    /// Shows weekly coaching progress with AHA 150-min guideline explanations.
    @ViewBuilder
    private var coachingProgressCard: some View {
        if viewModel.history.count >= 7 {
            let engine = CoachingEngine()
            let latestSnapshot = viewModel.history.last ?? HeartSnapshot(date: Date())
            let report = engine.generateReport(
                current: latestSnapshot,
                history: viewModel.history,
                streakDays: 0
            )

            // AHA weekly activity computation
            let weekData = Array(viewModel.history.suffix(7))
            let weeklyModerate = weekData.reduce(0.0) { sum, s in
                let zones = s.zoneMinutes
                return sum + (zones.count >= 3 ? zones[2] : 0) // Zone 3 (cardio)
            }
            let weeklyVigorous = weekData.reduce(0.0) { sum, s in
                let zones = s.zoneMinutes
                return sum + (zones.count >= 4 ? zones[3] : 0) + (zones.count >= 5 ? zones[4] : 0)
            }
            let ahaTotal = weeklyModerate + weeklyVigorous * 2 // Vigorous counts double per AHA
            let ahaPercent = min(ahaTotal / 150.0, 1.0)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundStyle(Color(hex: 0x8B5CF6))
                    Text("Buddy Coach Progress")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()

                    // Progress score badge
                    Text("\(report.weeklyProgressScore)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(progressScoreColor(report.weeklyProgressScore))
                        )
                }

                Text(report.heroMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // AHA 150-min Weekly Activity Guideline
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.circle.fill")
                            .font(.caption)
                            .foregroundStyle(ahaPercent >= 1.0 ? Color(hex: 0x22C55E) : Color(hex: 0x3B82F6))
                        Text("AHA Weekly Activity")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(Int(ahaTotal))/150 min")
                            .font(.caption)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(ahaPercent >= 1.0 ? Color(hex: 0x22C55E) : .primary)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ahaPercent >= 1.0 ? Color(hex: 0x22C55E) : Color(hex: 0x3B82F6))
                                .frame(width: geo.size.width * CGFloat(ahaPercent), height: 8)
                        }
                    }
                    .frame(height: 8)

                    // Human explanation of what 150 min means
                    Text(ahaExplanation(percent: ahaPercent, totalMin: ahaTotal))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ahaPercent >= 1.0
                              ? Color(hex: 0x22C55E).opacity(0.06)
                              : Color(hex: 0x3B82F6).opacity(0.04))
                )

                // Metric insights
                ForEach(Array(report.insights.prefix(3).enumerated()), id: \.offset) { _, insight in
                    HStack(spacing: 8) {
                        Image(systemName: insight.icon)
                            .font(.caption)
                            .foregroundStyle(directionColor(insight.direction))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.message)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // Projections
                if !report.projections.isEmpty {
                    Divider()
                    ForEach(Array(report.projections.prefix(2).enumerated()), id: \.offset) { _, proj in
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(Color(hex: 0xF59E0B))
                            Text(proj.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: 0x8B5CF6).opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(hex: 0x8B5CF6).opacity(0.12), lineWidth: 1)
            )
            .accessibilityIdentifier("coach_progress")
        }
    }

    /// Human-readable explanation of what AHA 150-min guideline progress means.
    private func ahaExplanation(percent: Double, totalMin: Double) -> String {
        if percent >= 1.0 {
            return "You hit the AHA's 150-minute weekly guideline! This level of activity supports better endurance, faster recovery between workouts, and a stronger resting heart rate over time."
        } else if percent >= 0.7 {
            let remaining = Int(max(0, 150 - totalMin))
            return "Almost there — \(remaining) more minutes this week. At 100%, you're building the cardiovascular base that helps your body recover faster and maintain a lower resting heart rate."
        } else if percent >= 0.3 {
            return "You're building momentum. The 150-minute target is where your heart starts getting measurably more efficient — shorter recovery times, better endurance, and improved stress tolerance."
        } else {
            return "The AHA recommends 150 minutes of moderate activity weekly. This is the threshold where cardiovascular benefits become significant — stronger heart, faster recovery, and better sleep quality."
        }
    }

    private func progressScoreColor(_ score: Int) -> Color {
        if score >= 70 { return Color(hex: 0x22C55E) }
        if score >= 45 { return Color(hex: 0x3B82F6) }
        return Color(hex: 0xF59E0B)
    }

    private func directionColor(_ direction: CoachingDirection) -> Color {
        switch direction {
        case .improving: return Color(hex: 0x22C55E)
        case .stable: return Color(hex: 0x3B82F6)
        case .declining: return Color(hex: 0xF59E0B)
        }
    }

    // MARK: - Weekly Goal Completion Card

    /// Gamified weekly goal tracking: did you hit your activity, sleep, and zone targets?
    @ViewBuilder
    private var weeklyGoalCompletionCard: some View {
        if viewModel.history.count >= 3 {
            let weekData = Array(viewModel.history.suffix(7))
            let activeDays = weekData.filter {
                ($0.walkMinutes ?? 0) + ($0.workoutMinutes ?? 0) >= 30
            }.count
            let goodSleepDays = weekData.compactMap(\.sleepHours).filter {
                $0 >= 7.0 && $0 <= 9.0
            }.count
            let daysWithZone3 = weekData.map(\.zoneMinutes).filter {
                $0.count >= 3 && $0[2] >= 15
            }.count

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundStyle(Color(hex: 0xF59E0B))
                    Text("Weekly Goals")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }

                HStack(spacing: 12) {
                    weeklyGoalRing(
                        label: "Active 30+",
                        current: activeDays, target: 5,
                        color: Color(hex: 0x22C55E)
                    )
                    weeklyGoalRing(
                        label: "Good Sleep",
                        current: goodSleepDays, target: 5,
                        color: Color(hex: 0x8B5CF6)
                    )
                    weeklyGoalRing(
                        label: "Zone 3+",
                        current: daysWithZone3, target: 3,
                        color: Color(hex: 0xF59E0B)
                    )
                }

                let totalAchieved = activeDays + goodSleepDays + daysWithZone3
                let totalTarget = 13
                if totalAchieved >= totalTarget {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color(hex: 0xF59E0B))
                        Text("You hit all your weekly goals — excellent consistency this week.")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(hex: 0xF59E0B))
                    }
                } else {
                    let remaining = totalTarget - totalAchieved
                    Text("\(remaining) more goal\(remaining == 1 ? "" : "s") to complete this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func weeklyGoalRing(label: String, current: Int, target: Int, color: Color) -> some View {
        let progress = min(Double(current) / Double(target), 1.0)
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if current >= target {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(color)
                } else {
                    Text("\(current)/\(target)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 50, height: 50)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyDataView: some View {
        VStack(spacing: 16) {
            ThumpBuddy(mood: .nudging, size: 70)

            Text("No Data Yet")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Trends appear after 3–5 days of consistent Apple Watch wear. Keep it on and check back soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Metric Helpers

    private var metricDisplayName: String {
        switch viewModel.selectedMetric {
        case .restingHR:      return "Resting Heart Rate"
        case .hrv:            return "Heart Rate Variability"
        case .recovery:       return "Recovery Heart Rate"
        case .vo2Max:         return "Cardio Fitness"
        case .activeMinutes:  return "Active Minutes"
        }
    }

    private var metricUnit: String {
        switch viewModel.selectedMetric {
        case .restingHR:      return "bpm"
        case .hrv:            return "ms"
        case .recovery:       return "bpm"
        case .vo2Max:         return "score"
        case .activeMinutes:  return "min"
        }
    }

    private var metricColor: Color {
        metricColorFor(viewModel.selectedMetric)
    }

    private func metricColorFor(_ metric: TrendsViewModel.MetricType) -> Color {
        switch metric {
        case .restingHR:      return Color(hex: 0xEF4444)
        case .hrv:            return Color(hex: 0x3B82F6)
        case .recovery:       return Color(hex: 0x22C55E)
        case .vo2Max:         return Color(hex: 0x8B5CF6)
        case .activeMinutes:  return Color(hex: 0xF59E0B)
        }
    }

    private var metricIcon: String {
        switch viewModel.selectedMetric {
        case .restingHR:      return "heart.fill"
        case .hrv:            return "waveform.path.ecg"
        case .recovery:       return "arrow.uturn.up"
        case .vo2Max:         return "lungs.fill"
        case .activeMinutes:  return "figure.run"
        }
    }

    private func formatValue(_ value: Double) -> String {
        switch viewModel.selectedMetric {
        case .restingHR, .recovery, .activeMinutes:
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

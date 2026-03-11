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

    @StateObject private var viewModel = InsightsViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Insights")
                .navigationBarTitleDisplayMode(.large)
                .task {
                    await viewModel.loadInsights()
                }
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            loadingView
        } else {
            scrollContent
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                weeklyReportSection
                correlationsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Weekly Report Section

    @ViewBuilder
    private var weeklyReportSection: some View {
        if let report = viewModel.weeklyReport {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Weekly Report", icon: "doc.text.fill")
                weeklyReportCard(report: report)
            }
        }
    }

    /// The detailed weekly report card.
    private func weeklyReportCard(report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Date range header
            HStack {
                Text(reportDateRange(report))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                trendBadge(direction: report.trendDirection)
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

            // Top insight
            Text(report.topInsight)
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
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Correlations Section

    private var correlationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Activity Correlations", icon: "arrow.triangle.branch")

            if viewModel.correlations.isEmpty {
                emptyCorrelationsView
            } else {
                ForEach(viewModel.correlations, id: \.factorName) { correlation in
                    CorrelationCardView(correlation: correlation)
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

            Text("Continue wearing your Apple Watch daily. Correlations require at least 7 days of paired data.")
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

    /// Formats the week date range for display.
    private func reportDateRange(_ report: WeeklyReport) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: report.weekStart)) - \(formatter.string(from: report.weekEnd))"
    }

    /// A capsule badge showing the weekly trend direction.
    private func trendBadge(direction: WeeklyReport.TrendDirection) -> some View {
        let icon: String
        let color: Color
        let label: String

        switch direction {
        case .up:
            icon = "arrow.up.right"
            color = .green
            label = "Building Momentum"
        case .flat:
            icon = "minus"
            color = .blue
            label = "Holding Steady"
        case .down:
            icon = "arrow.down.right"
            color = .orange
            label = "Worth Watching"
        }

        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
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

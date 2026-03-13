// WatchDetailView.swift
// Thump Watch
//
// Detailed metrics view presenting compact, color-coded health data rows
// optimized for the watchOS form factor.
// Platforms: watchOS 10+

import SwiftUI

// MARK: - Watch Detail View

/// Displays a scrollable list of the user's key health metrics pulled from
/// the latest assessment. Values are color-coded to indicate healthy (green),
/// borderline (orange), or concerning (red) ranges.
struct WatchDetailView: View {

    // MARK: - Environment

    @EnvironmentObject var viewModel: WatchViewModel

    // MARK: - Body

    var body: some View {
        if let assessment = viewModel.latestAssessment {
            detailContent(assessment)
        } else {
            noDataPlaceholder
        }
    }

    // MARK: - Detail Content

    /// Main scrollable metric list when assessment data is available.
    @ViewBuilder
    private func detailContent(_ assessment: HeartAssessment) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                confidenceBadge(assessment.confidence)
                Divider()
                metricRows(assessment)
                Divider()
                assessmentFlags(assessment)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Confidence Badge

    /// Compact confidence indicator at the top of the detail view.
    @ViewBuilder
    private func confidenceBadge(_ confidence: ConfidenceLevel) -> some View {
        HStack(spacing: 4) {
            Image(systemName: confidence.icon)
                .font(.caption2)
            Text(confidence.displayName)
                .font(.caption2)
        }
        .foregroundStyle(confidenceColor(confidence))
        .padding(.vertical, 4)
    }

    // MARK: - Metric Rows

    /// Individual metric rows pulled from the assessment.
    ///
    /// Note: The assessment itself does not carry raw snapshot values,
    /// so we display the cardio score and status information. If the
    /// `WatchViewModel` exposes a snapshot in the future, raw values
    /// can be surfaced here.
    @ViewBuilder
    private func metricRows(_ assessment: HeartAssessment) -> some View {
        if let score = assessment.cardioScore {
            metricRow(
                icon: "heart.fill",
                label: "Cardio Fitness",
                value: String(format: "%.0f", score),
                color: scoreColor(score)
            )
        }

        metricRow(
            icon: "waveform.path.ecg",
            label: "Unusual Activity",
            value: anomalyLabel(assessment.anomalyScore),
            color: anomalyColor(assessment.anomalyScore)
        )

        metricRow(
            icon: "arrow.up.heart.fill",
            label: "Status",
            value: statusLabel(assessment.status),
            color: statusColor(assessment.status)
        )
    }

    // MARK: - Assessment Flags

    /// Displays regression and stress flags when active.
    @ViewBuilder
    private func assessmentFlags(_ assessment: HeartAssessment) -> some View {
        if assessment.regressionFlag {
            flagRow(
                icon: "chart.line.downtrend.xyaxis",
                label: "Pattern Worth Watching",
                color: .orange
            )
        }

        if assessment.stressFlag {
            flagRow(
                icon: "bolt.heart.fill",
                label: "Stress Pattern Noticed",
                color: .red
            )
        }

        if !assessment.regressionFlag && !assessment.stressFlag {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                Text("Everything looks good")
                    .font(.caption2)
            }
            .foregroundStyle(.green)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Reusable Row Components

    /// A single metric row with icon, label, and color-coded value.
    private func metricRow(
        icon: String,
        label: String,
        value: String,
        color: Color
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
    }

    /// A flag indicator row for regression or stress alerts.
    private func flagRow(
        icon: String,
        label: String,
        color: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(color)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - No Data Placeholder

    /// Shown when no assessment data is available.
    private var noDataPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Waiting for Data")
                .font(.headline)

            Text("Sync with your iPhone to view detailed metrics.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Color Helpers

    /// Maps a cardio score to a display color.
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 70...:   return .green
        case 40..<70: return .orange
        default:      return .red
        }
    }

    /// Maps an anomaly score to a human-readable label.
    private func anomalyLabel(_ score: Double) -> String {
        let percentage = score * 100
        switch percentage {
        case ..<30:  return "Normal"
        case 30..<60: return "Slightly Unusual"
        default:      return "Worth Checking"
        }
    }

    /// Maps an anomaly score to a display color.
    private func anomalyColor(_ score: Double) -> Color {
        switch score {
        case ..<1.0: return .green
        case 1.0..<2.0: return .orange
        default: return .red
        }
    }

    /// Maps a `TrendStatus` to a display color.
    private func statusColor(_ status: TrendStatus) -> Color {
        switch status {
        case .improving:      return .green
        case .stable:         return .blue
        case .needsAttention: return .orange
        }
    }

    /// Maps a `TrendStatus` to a short label.
    private func statusLabel(_ status: TrendStatus) -> String {
        switch status {
        case .improving:      return "Building Momentum"
        case .stable:         return "Holding Steady"
        case .needsAttention: return "Check In"
        }
    }

    /// Maps a `ConfidenceLevel` to a display color.
    private func confidenceColor(_ confidence: ConfidenceLevel) -> Color {
        switch confidence {
        case .high:   return .green
        case .medium: return .yellow
        case .low:    return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WatchDetailView()
            .environmentObject(WatchViewModel())
    }
}

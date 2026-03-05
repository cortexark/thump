// WatchHomeView.swift
// Thump Watch
//
// Main watch face presenting a compact status summary, cardio score,
// current nudge, quick feedback buttons, and navigation to detail views.
// Platforms: watchOS 10+

import SwiftUI

// MARK: - Watch Home View

/// The primary watch interface showing the current heart health assessment
/// at a glance with quick actions for feedback and deeper exploration.
struct WatchHomeView: View {

    // MARK: - Environment

    @EnvironmentObject var connectivityService: WatchConnectivityService
    @EnvironmentObject var viewModel: WatchViewModel

    // MARK: - Body

    var body: some View {
        NavigationStack {
            if let assessment = viewModel.latestAssessment {
                assessmentContent(assessment)
            } else {
                syncingPlaceholder
            }
        }
    }

    // MARK: - Assessment Content

    /// Main content displayed when an assessment is available.
    @ViewBuilder
    private func assessmentContent(_ assessment: HeartAssessment) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                statusIndicator(assessment)
                cardioScoreDisplay(assessment)
                nudgeRow(assessment)
                feedbackRow
                detailLink
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Thump")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status Indicator

    /// Colored circle with SF Symbol indicating the current trend status.
    @ViewBuilder
    private func statusIndicator(_ assessment: HeartAssessment) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(statusColor(for: assessment.status))
                    .frame(width: 44, height: 44)

                Image(systemName: statusIcon(for: assessment.status))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(statusLabel(for: assessment.status))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart health status: \(statusLabel(for: assessment.status))")
    }

    // MARK: - Cardio Score

    /// Large numeric display of the composite cardio fitness score.
    @ViewBuilder
    private func cardioScoreDisplay(_ assessment: HeartAssessment) -> some View {
        if let score = assessment.cardioScore {
            VStack(spacing: 2) {
                Text("\(Int(score))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(score))

                Text("Cardio Score")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cardio score: \(Int(score)) out of 100")
        }
    }

    // MARK: - Nudge Row

    /// Tappable nudge summary that navigates to the full nudge view.
    @ViewBuilder
    private func nudgeRow(_ assessment: HeartAssessment) -> some View {
        NavigationLink(destination: WatchNudgeView()) {
            HStack(spacing: 8) {
                Image(systemName: assessment.dailyNudge.icon)
                    .font(.body)
                    .foregroundStyle(Color(assessment.dailyNudge.category.tintColorName))

                Text(assessment.dailyNudge.title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Today's nudge: \(assessment.dailyNudge.title)")
        .accessibilityHint("Double tap to view full coaching nudge")
    }

    // MARK: - Feedback Row

    /// Quick thumbs up / thumbs down feedback buttons.
    private var feedbackRow: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.submitFeedback(.positive)
            } label: {
                Image(systemName: viewModel.submittedFeedbackType == .positive ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.feedbackSubmitted)
            .accessibilityLabel("Thumbs up")
            .accessibilityHint(viewModel.feedbackSubmitted ? "Feedback already submitted" : "Double tap to rate this assessment positively")

            Button {
                viewModel.submitFeedback(.negative)
            } label: {
                Image(systemName: viewModel.submittedFeedbackType == .negative ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.feedbackSubmitted)
            .accessibilityLabel("Thumbs down")
            .accessibilityHint(viewModel.feedbackSubmitted ? "Feedback already submitted" : "Double tap to rate this assessment negatively")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Detail Link

    /// Navigation link to the detailed metrics view.
    private var detailLink: some View {
        NavigationLink(destination: WatchDetailView()) {
            Label("View Details", systemImage: "chart.bar.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .accessibilityLabel("View detailed metrics")
        .accessibilityHint("Double tap to see all health metrics")
    }

    // MARK: - Syncing Placeholder

    /// Displayed when no assessment has been received from the phone yet.
    private var syncingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Syncing...")
                .font(.headline)

            Text("Waiting for data from iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.sync()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .accessibilityLabel("Retry sync")
            .accessibilityHint("Double tap to retry syncing with iPhone")
        }
        .padding()
    }

    // MARK: - Helpers

    /// Maps a `TrendStatus` to a display color.
    private func statusColor(for status: TrendStatus) -> Color {
        switch status {
        case .improving:      return .green
        case .stable:         return .blue
        case .needsAttention: return .orange
        }
    }

    /// Maps a `TrendStatus` to an SF Symbol icon name.
    private func statusIcon(for status: TrendStatus) -> String {
        switch status {
        case .improving:      return "arrow.up.heart.fill"
        case .stable:         return "heart.fill"
        case .needsAttention: return "exclamationmark.heart.fill"
        }
    }

    /// Maps a `TrendStatus` to a short label.
    private func statusLabel(for status: TrendStatus) -> String {
        switch status {
        case .improving:      return "Improving"
        case .stable:         return "Stable"
        case .needsAttention: return "Needs Attention"
        }
    }

    /// Maps a cardio score to a color.
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 70...:   return .green
        case 40..<70: return .orange
        default:      return .red
        }
    }
}

// MARK: - Preview

#Preview {
    WatchHomeView()
        .environmentObject(WatchConnectivityService())
        .environmentObject(WatchViewModel())
}

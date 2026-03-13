// WatchNudgeView.swift
// Thump Watch
//
// Full nudge display showing the coaching recommendation with category icon,
// description, optional duration badge, and completion/feedback actions.
// Platforms: watchOS 10+

import SwiftUI

// MARK: - Watch Nudge View

/// Presents the complete daily nudge with all details, a completion button,
/// and a link to submit feedback about the nudge quality.
struct WatchNudgeView: View {

    // MARK: - Environment

    @EnvironmentObject var viewModel: WatchViewModel

    // MARK: - Body

    var body: some View {
        if let assessment = viewModel.latestAssessment {
            nudgeContent(assessment.dailyNudge)
        } else {
            noNudgePlaceholder
        }
    }

    // MARK: - Nudge Content

    /// Main scrollable nudge display.
    @ViewBuilder
    private func nudgeContent(_ nudge: DailyNudge) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                categoryIcon(nudge)
                nudgeTitle(nudge)
                nudgeDescription(nudge)
                durationBadge(nudge)
                completeButton
                feedbackLink
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Today's Idea")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Category Icon

    /// Large colored circle with the nudge category SF Symbol.
    @ViewBuilder
    private func categoryIcon(_ nudge: DailyNudge) -> some View {
        ZStack {
            Circle()
                .fill(Color(nudge.category.tintColorName).opacity(0.25))
                .frame(width: 52, height: 52)

            Image(systemName: nudge.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color(nudge.category.tintColorName))
        }
        .padding(.top, 4)
        .accessibilityHidden(true)
    }

    // MARK: - Title

    /// The nudge title in a prominent headline style.
    @ViewBuilder
    private func nudgeTitle(_ nudge: DailyNudge) -> some View {
        Text(nudge.title)
            .font(.headline)
            .multilineTextAlignment(.center)
            .lineLimit(3)
    }

    // MARK: - Description

    /// The full nudge description, scrollable for longer text.
    @ViewBuilder
    private func nudgeDescription(_ nudge: DailyNudge) -> some View {
        Text(nudge.description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    // MARK: - Duration Badge

    /// Displays the suggested duration when applicable.
    @ViewBuilder
    private func durationBadge(_ nudge: DailyNudge) -> some View {
        if let duration = nudge.durationMinutes {
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                Text("\(duration) min")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Duration: \(duration) minutes")
        }
    }

    // MARK: - Complete Button

    /// Button to mark the nudge as complete.
    private var completeButton: some View {
        Button {
            viewModel.markNudgeComplete()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: viewModel.nudgeCompleted
                      ? "checkmark.circle.fill"
                      : "checkmark.circle")
                    .font(.body)

                Text(viewModel.nudgeCompleted ? "Completed" : "Mark Complete")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.nudgeCompleted ? .gray : .green)
        .disabled(viewModel.nudgeCompleted)
        .accessibilityLabel(viewModel.nudgeCompleted ? "Done! Nice work." : "Mark as done")
        .accessibilityHint(viewModel.nudgeCompleted ? "" : "Double tap to mark this suggestion as done")
    }

    // MARK: - Feedback Link

    /// Navigation link to the feedback submission view.
    private var feedbackLink: some View {
        NavigationLink(destination: WatchFeedbackView()) {
            Label("Give Feedback", systemImage: "bubble.left.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
        .accessibilityLabel("Share how this felt")
        .accessibilityHint("Double tap to let us know what you thought")
    }

    // MARK: - No Nudge Placeholder

    /// Shown when no nudge data is available.
    private var noNudgePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "lightbulb.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Nothing Here Yet")
                .font(.headline)

            Text("Sync with your iPhone to get today's suggestion.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nothing here yet. Sync with your iPhone to get today's suggestion.")
        .navigationTitle("Today's Idea")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WatchNudgeView()
            .environmentObject(WatchViewModel())
    }
}

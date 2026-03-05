// WatchFeedbackView.swift
// Thump Watch
//
// Feedback submission view allowing users to rate the day's nudge
// with a simple three-option interface optimized for the small watch screen.
// Platforms: watchOS 10+

import SwiftUI

// MARK: - Watch Feedback View

/// Presents a compact prompt asking the user how the day's nudge felt,
/// with three response options: positive, negative, and skipped.
/// Shows a confirmation animation upon successful submission.
struct WatchFeedbackView: View {

    // MARK: - Environment

    @EnvironmentObject var viewModel: WatchViewModel
    @Environment(\.dismiss) var dismiss

    // MARK: - State

    /// Tracks the selected response for the confirmation animation.
    @State private var selectedResponse: DailyFeedback?

    /// Controls the visibility of the confirmation overlay.
    @State private var showConfirmation: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            feedbackContent
            confirmationOverlay
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Feedback Content

    /// Main prompt and button layout.
    private var feedbackContent: some View {
        VStack(spacing: 12) {
            Text("How did today's nudge feel?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            feedbackButton(
                title: "Great",
                icon: "hand.thumbsup.fill",
                color: .green,
                response: .positive
            )

            feedbackButton(
                title: "Not for me",
                icon: "hand.thumbsdown.fill",
                color: .orange,
                response: .negative
            )

            feedbackButton(
                title: "Skip",
                icon: "forward.fill",
                color: .gray,
                response: .skipped
            )
        }
        .padding(.horizontal, 8)
        .opacity(showConfirmation ? 0.3 : 1.0)
        .allowsHitTesting(!showConfirmation)
    }

    // MARK: - Feedback Button

    /// A single feedback option button with icon, label, and color.
    private func feedbackButton(
        title: String,
        icon: String,
        color: Color,
        response: DailyFeedback
    ) -> some View {
        Button {
            submitResponse(response)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.2))
            )
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Confirmation Overlay

    /// Animated checkmark overlay shown after feedback submission.
    @ViewBuilder
    private var confirmationOverlay: some View {
        if showConfirmation {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))

                Text("Thanks!")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .transition(.opacity)
        }
    }

    // MARK: - Actions

    /// Submits the feedback response and triggers the confirmation animation.
    private func submitResponse(_ response: DailyFeedback) {
        selectedResponse = response
        viewModel.submitFeedback(response)

        withAnimation(.easeInOut(duration: 0.3)) {
            showConfirmation = true
        }

        // Dismiss after a short delay to let the user see confirmation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WatchFeedbackView()
            .environmentObject(WatchViewModel())
    }
}

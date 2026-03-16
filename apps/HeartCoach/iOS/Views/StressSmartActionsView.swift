// StressSmartActionsView.swift
// Thump iOS
//
// Extracted from StressView.swift — smart nudge actions section,
// action cards, stress guidance card, and guidance action handler.
// Isolated for smaller SwiftUI diffing scope.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - Smart Actions

extension StressView {

    var smartActionsSection: some View {
        VStack(alignment: .leading, spacing: ThumpSpacing.sm) {
            HStack {
                Text("Suggestions for You")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("Based on your data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("stress_checkin_section")

            ForEach(
                Array(viewModel.smartActions.enumerated()),
                id: \.offset
            ) { _, action in
                smartActionView(for: action)
            }
        }
    }

    @ViewBuilder
    func smartActionView(
        for action: SmartNudgeAction
    ) -> some View {
        switch action {
        case .journalPrompt(let prompt):
            actionCard(
                icon: prompt.icon,
                iconColor: .purple,
                title: "Journal Time",
                message: prompt.question,
                detail: prompt.context,
                buttonLabel: "Start Writing",
                buttonIcon: "pencil",
                action: action
            )

        case .breatheOnWatch(let nudge):
            actionCard(
                icon: "wind",
                iconColor: ThumpColors.elevated,
                title: nudge.title,
                message: nudge.description,
                detail: nil,
                buttonLabel: "Open on Watch",
                buttonIcon: "applewatch",
                action: action
            )

        case .morningCheckIn(let message):
            actionCard(
                icon: "sun.max.fill",
                iconColor: .yellow,
                title: "Morning Check-In",
                message: message,
                detail: nil,
                buttonLabel: "Share How You Feel",
                buttonIcon: "hand.wave.fill",
                action: action
            )

        case .bedtimeWindDown(let nudge):
            actionCard(
                icon: "moon.fill",
                iconColor: .indigo,
                title: nudge.title,
                message: nudge.description,
                detail: nil,
                buttonLabel: "Got It",
                buttonIcon: "checkmark",
                action: action
            )

        case .activitySuggestion(let nudge):
            actionCard(
                icon: nudge.icon,
                iconColor: .green,
                title: nudge.title,
                message: nudge.description,
                detail: nudge.durationMinutes.map {
                    "\($0) min"
                },
                buttonLabel: "Let's Go",
                buttonIcon: "figure.walk",
                action: action
            )

        case .restSuggestion(let nudge):
            actionCard(
                icon: nudge.icon,
                iconColor: .indigo,
                title: nudge.title,
                message: nudge.description,
                detail: nil,
                buttonLabel: "Set Reminder",
                buttonIcon: "bell.fill",
                action: action
            )

        case .standardNudge:
            stressGuidanceCard
        }
    }

    func actionCard(
        icon: String,
        iconColor: Color,
        title: String,
        message: String,
        detail: String?,
        buttonLabel: String,
        buttonIcon: String,
        action: SmartNudgeAction
    ) -> some View {
        VStack(alignment: .leading, spacing: ThumpSpacing.sm) {
            HStack(spacing: ThumpSpacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                InteractionLog.log(.buttonTap, element: "nudge_card", page: "Stress", details: title)
                viewModel.handleSmartAction(action)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: buttonIcon)
                        .font(.caption)
                    Text(buttonLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ThumpSpacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(iconColor)
        }
        .padding(ThumpSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ThumpRadius.md)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stress Guidance Card (Default Action)

    /// Always-visible guidance card that gives actionable tips based on
    /// the current stress level. Shown when no specific smart action
    /// (journal, breathe, check-in, wind-down) is triggered.
    var stressGuidanceCard: some View {
        let stress = viewModel.currentStress
        let level = stress?.level ?? .balanced
        let guidance = stressGuidance(for: level)

        return VStack(alignment: .leading, spacing: ThumpSpacing.sm) {
            HStack(spacing: ThumpSpacing.xs) {
                Image(systemName: guidance.icon)
                    .font(.title3)
                    .foregroundStyle(guidance.color)

                Text("What You Can Do")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text(guidance.headline)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(guidance.color)

            Text(guidance.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Quick action buttons
            HStack(spacing: ThumpSpacing.xs) {
                ForEach(guidance.actions, id: \.label) { action in
                    Button {
                        InteractionLog.log(.buttonTap, element: "stress_guidance_action", page: "Stress", details: action.label)
                        handleGuidanceAction(action)
                    } label: {
                        Label(action.label, systemImage: action.icon)
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ThumpSpacing.xs)
                    }
                    .buttonStyle(.bordered)
                    .tint(guidance.color)
                }
            }
        }
        .padding(ThumpSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ThumpRadius.md)
                .fill(guidance.color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ThumpRadius.md)
                .strokeBorder(guidance.color.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Guidance Data

    struct StressGuidance {
        let headline: String
        let detail: String
        let icon: String
        let color: Color
        let actions: [QuickAction]
    }

    struct QuickAction: Hashable {
        let label: String
        let icon: String
    }

    func stressGuidance(for level: StressLevel) -> StressGuidance {
        switch level {
        case .relaxed:
            return StressGuidance(
                headline: "You're in a Great Spot",
                detail: "Your body is recovered and ready. This is a good time for a challenging workout, creative work, or anything that takes focus.",
                icon: "leaf.fill",
                color: ThumpColors.relaxed,
                actions: [
                    QuickAction(label: "Workout", icon: "figure.run"),
                    QuickAction(label: "Focus Time", icon: "brain.head.profile")
                ]
            )
        case .balanced:
            return StressGuidance(
                headline: "Keep Up the Balance",
                detail: "Your stress is in a healthy range. A walk, some stretching, or a short break between tasks can help you stay here.",
                icon: "circle.grid.cross.fill",
                color: ThumpColors.balanced,
                actions: [
                    QuickAction(label: "Take a Walk", icon: "figure.walk"),
                    QuickAction(label: "Stretch", icon: "figure.cooldown")
                ]
            )
        case .elevated:
            return StressGuidance(
                headline: "Time to Ease Up",
                detail: "Your body could use some recovery. Try a few slow breaths, step outside for fresh air, or take a 10-minute break. Even small pauses make a difference.",
                icon: "flame.fill",
                color: ThumpColors.elevated,
                actions: [
                    QuickAction(label: "Breathe", icon: "wind"),
                    QuickAction(label: "Step Outside", icon: "sun.max.fill"),
                    QuickAction(label: "Rest", icon: "bed.double.fill")
                ]
            )
        }
    }

    // MARK: - Guidance Action Handler

    func handleGuidanceAction(_ action: QuickAction) {
        InteractionLog.log(.buttonTap, element: "stress_guidance_action", page: "Stress", details: action.label)
        switch action.label {
        case "Breathe", "Rest":
            viewModel.startBreathingSession()
        case "Take a Walk", "Step Outside", "Workout":
            viewModel.showWalkSuggestion()
        case "Focus Time":
            // Gentle breathing session for focused calm
            viewModel.startBreathingSession()
        case "Stretch":
            // Light movement suggestion — same as walk prompt
            viewModel.showWalkSuggestion()
        default:
            break
        }
    }
}

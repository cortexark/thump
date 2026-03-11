// NudgeCardView.swift
// Thump iOS
//
// Displays today's coaching nudge with category icon, title, description,
// optional duration badge, and a completion action. The card uses the nudge
// category's tint color for visual branding.

import SwiftUI

struct NudgeCardView: View {
    let nudge: DailyNudge
    let onMarkComplete: () -> Void

    @State private var isCompleted = false

    private var categoryColor: Color {
        switch nudge.category {
        case .walk:         return .green
        case .rest:         return .indigo
        case .hydrate:      return .cyan
        case .breathe:      return .teal
        case .moderate:     return .orange
        case .celebrate:    return .yellow
        case .seekGuidance: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: icon + title + optional duration
            HStack(alignment: .top, spacing: 12) {
                // Category icon
                Image(systemName: nudge.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(categoryColor.gradient, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(nudge.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let minutes = nudge.durationMinutes {
                        Label("\(minutes) min", systemImage: "clock")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(categoryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(categoryColor.opacity(0.12), in: Capsule())
                    }
                }

                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(nudge.title)"
                    + "\(nudge.durationMinutes.map { ", \($0) minutes" } ?? "")"
            )

            // Description
            Text(nudge.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Mark Complete button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isCompleted = true
                }
                onMarkComplete()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.body)

                    Text(isCompleted ? "Completed" : "Mark Complete")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(isCompleted ? .white : categoryColor)
                .background(
                    isCompleted ? AnyShapeStyle(categoryColor) : AnyShapeStyle(categoryColor.opacity(0.12)),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
            .buttonStyle(.plain)
            .disabled(isCompleted)
            .accessibilityLabel(isCompleted ? "Nudge completed" : "Mark nudge as complete")
            .accessibilityHint(isCompleted ? "" : "Double tap to mark this coaching nudge as complete")
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Walk Nudge") {
    NudgeCardView(
        nudge: DailyNudge(
            category: .walk,
            title: "Take a Gentle Walk",
            description: "Your HRV has been looking nice lately. "
                + "A 15-minute walk could keep that good momentum going.",
            durationMinutes: 15,
            icon: "figure.walk"
        ),
        onMarkComplete: {}
    )
    .padding()
}

#Preview("Rest Nudge") {
    NudgeCardView(
        nudge: DailyNudge(
            category: .rest,
            title: "Prioritize Recovery",
            description: "Your resting heart rate has been elevated for 3 days. Take it easy today and focus on sleep.",
            durationMinutes: nil,
            icon: "bed.double.fill"
        ),
        onMarkComplete: {}
    )
    .padding()
}

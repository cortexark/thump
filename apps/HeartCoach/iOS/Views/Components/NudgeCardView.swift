// NudgeCardView.swift
// Thump iOS
//
// Your buddy's daily suggestion card. Friendly, warm, action-oriented.
// Each card has a colorful icon, encouraging copy, and a satisfying
// completion animation. Feels like a friend giving you a nudge, not
// a clinical prescription.

import SwiftUI

struct NudgeCardView: View {
    let nudge: DailyNudge
    var isAlreadyActive: Bool = false
    let onMarkComplete: () -> Void

    @State private var isCompleted = false

    private var categoryColor: Color {
        switch nudge.category {
        case .walk:         return Color(hex: 0x22C55E)
        case .rest:         return Color(hex: 0x6366F1)
        case .hydrate:      return Color(hex: 0x06B6D4)
        case .breathe:      return Color(hex: 0x0D9488)
        case .moderate:     return Color(hex: 0xF59E0B)
        case .celebrate:    return Color(hex: 0xFBBF24)
        case .seekGuidance: return Color(hex: 0xEF4444)
        case .sunlight:     return Color(hex: 0xFBBF24)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: icon + title + optional duration
            HStack(alignment: .top, spacing: 12) {
                // Category icon with gradient background
                Image(systemName: nudge.icon)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [categoryColor, categoryColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .shadow(color: categoryColor.opacity(0.3), radius: 4, y: 2)
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
                            .background(categoryColor.opacity(0.1), in: Capsule())
                    }
                }

                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(nudge.title)"
                    + "\(nudge.durationMinutes.map { ", \($0) minutes" } ?? "")"
            )

            // Already active badge
            if isAlreadyActive {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color(hex: 0x22C55E))
                    Text("You're already on it! Keep going.")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(hex: 0x22C55E))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Color(hex: 0x22C55E).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }

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
                        .contentTransition(.symbolEffect(.replace))

                    Text(isCompleted ? "Done!" : "Mark Complete")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(isCompleted ? .white : categoryColor)
                .background(
                    isCompleted
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [categoryColor, categoryColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(categoryColor.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .buttonStyle(.plain)
            .disabled(isCompleted)
            .accessibilityLabel(isCompleted ? "Nudge completed" : "Mark nudge as complete")
            .accessibilityHint(isCompleted ? "" : "Double tap to mark this suggestion as complete")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(categoryColor.opacity(0.08), lineWidth: 1)
        )
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

// PillarWhySheet.swift
// Thump iOS
//
// "Why?" explanation sheet shown when a user taps a readiness pillar
// (Recovery, Activity, Stress, Sleep Score) on the Thump Check card.
// Provides plain-language explanation of what drove the score.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - Pillar Why Content

/// Data model for a pillar "Why?" explanation.
struct PillarWhyContent: Identifiable {
    let id = UUID()
    let pillarName: String
    let icon: String
    let score: String
    let color: Color
    let headline: String
    let explanation: String
    let suggestion: String
}

// MARK: - Pillar Why Sheet

/// Bottom sheet showing why a readiness pillar has its current score.
struct PillarWhySheet: View {
    let content: PillarWhyContent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                // Score hero
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(content.color.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: content.icon)
                            .font(.title2)
                            .foregroundStyle(content.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(content.pillarName)
                            .font(.headline)
                        Text(content.score)
                            .font(.title)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(content.color)
                    }
                }

                // Headline
                Text(content.headline)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // Explanation
                Text(content.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Suggestion
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .padding(.top, 2)
                    Text(content.suggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.yellow.opacity(0.06))
                )

                Spacer()
            }
            .padding(20)
            .navigationTitle("Why This Score?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Why Content Builder

/// Generates "Why?" content for each pillar from the current view model state.
enum PillarWhyBuilder {

    static func recovery(
        score: Int,
        rhrTrend: String?,
        hrvBaseline: String?
    ) -> PillarWhyContent {
        let explanation: String
        if score >= 80 {
            explanation = "Your resting heart rate and HRV are both tracking near or better than your 28-day baseline. Your body has absorbed recent effort well."
        } else if score >= 60 {
            explanation = "Recovery is in a moderate range. \(rhrTrend ?? "Your resting heart rate is near your baseline.") \(hrvBaseline ?? "HRV is within your typical range.")"
        } else {
            explanation = "Recovery is below your usual range. \(rhrTrend ?? "Resting heart rate may be elevated.") \(hrvBaseline ?? "HRV may be suppressed compared to your baseline.")"
        }

        return PillarWhyContent(
            pillarName: "Recovery",
            icon: "heart.fill",
            score: "\(score)/100",
            color: pillColor(score),
            headline: score >= 70 ? "Recovery looks solid" : "Recovery is rebuilding",
            explanation: explanation,
            suggestion: score >= 70
                ? "A good day for quality effort. Your body has capacity."
                : "An easier day tends to help recovery rebound within 24-48 hours."
        )
    }

    static func activity(
        activeMinutes: Int
    ) -> PillarWhyContent {
        let explanation: String
        if activeMinutes >= 30 {
            explanation = "You've logged \(activeMinutes) active minutes today. That's a solid amount of movement."
        } else if activeMinutes > 0 {
            explanation = "You've logged \(activeMinutes) active minutes so far. A short walk can bring this closer to your target."
        } else {
            explanation = "No active minutes recorded yet today. Even 10 minutes of walking counts and tends to improve your evening metrics."
        }

        return PillarWhyContent(
            pillarName: "Activity",
            icon: "flame.fill",
            score: "\(activeMinutes) min",
            color: activeMinutes >= 30 ? .green : (activeMinutes > 0 ? .orange : .gray),
            headline: activeMinutes >= 30 ? "On track" : "Room to move",
            explanation: explanation,
            suggestion: activeMinutes >= 30
                ? "You're hitting your movement target. Keep it up."
                : "A 10-15 minute walk is often the easiest way to shift this metric."
        )
    }

    static func stress(
        score: Int,
        confidence: String?
    ) -> PillarWhyContent {
        let explanation: String
        if score <= 33 {
            explanation = "Your stress markers are in the relaxed range. HRV is near or above your baseline, and resting heart rate is stable."
        } else if score <= 66 {
            explanation = "Stress is in a moderate range. Your body is managing the day's load. \(confidence ?? "")"
        } else {
            explanation = "Stress is elevated above your baseline. HRV tends to dip and resting heart rate tends to rise when the body is under sustained load."
        }

        return PillarWhyContent(
            pillarName: "Stress",
            icon: "brain.head.profile",
            score: "\(score)/100",
            color: score <= 33 ? .green : (score <= 66 ? .orange : .red),
            headline: score <= 33 ? "Feeling relaxed" : (score <= 66 ? "Finding balance" : "Running hot"),
            explanation: explanation,
            suggestion: score <= 50
                ? "Good conditions for focused work or training."
                : "A few slow breaths or a short walk often helps bring this down."
        )
    }

    static func sleep(
        score: String,
        sleepHours: Double?
    ) -> PillarWhyContent {
        let hrs = sleepHours.map { String(format: "%.1f", $0) } ?? "—"
        let explanation: String
        if let hours = sleepHours {
            if hours >= 7.0 {
                explanation = "You got \(hrs) hours of sleep, which is within the optimal 7-9 hour range. This supports recovery and readiness."
            } else if hours >= 5.0 {
                explanation = "You got \(hrs) hours, below the 7-9 hour optimal range. Short sleep tends to suppress HRV and slow recovery."
            } else {
                explanation = "You got \(hrs) hours, well below the optimal range. Sleep debt at this level tends to impair recovery more than any workout can offset."
            }
        } else {
            explanation = "Sleep data is not available for last night. This may affect the accuracy of today's readiness score."
        }

        return PillarWhyContent(
            pillarName: "Sleep",
            icon: "moon.fill",
            score: score,
            color: (sleepHours ?? 0) >= 7.0 ? .indigo : ((sleepHours ?? 0) >= 5.0 ? .orange : .red),
            headline: (sleepHours ?? 0) >= 7.0 ? "Sleep was solid" : "Sleep was short",
            explanation: explanation,
            suggestion: (sleepHours ?? 0) >= 7.0
                ? "Well rested. Sleep is supporting your readiness today."
                : "An earlier bedtime tonight tends to help tomorrow's score rebound."
        )
    }

    private static func pillColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .blue }
        if score >= 40 { return .orange }
        return .red
    }
}

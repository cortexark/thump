// CorrelationDetailSheet.swift
// Thump iOS
//
// Detail sheet presented when a correlation card is tapped. Shows the
// correlation data with actionable, personalized recommendations and
// links to third-party wellness tools where appropriate.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - CorrelationDetailSheet

struct CorrelationDetailSheet: View {

    let correlation: CorrelationResult

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    strengthHero
                    whatThisMeans
                    recommendations
                    relatedTools
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(correlation.factorName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Strength Hero

    private var accentColor: Color {
        if abs(correlation.correlationStrength) < 0.3 { return .gray }
        return correlation.isBeneficial ? .green : .orange
    }

    private var strengthHero: some View {
        VStack(spacing: 16) {
            // Lead with human-readable strength
            Text(strengthDescription)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)

            Text(String(format: "%+.2f", correlation.correlationStrength))
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Beneficial indicator
            HStack(spacing: 6) {
                Image(systemName: correlation.isBeneficial ? "arrow.up.heart.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                Text(correlation.isBeneficial ? "This looks like a positive pattern in your data." : "This pattern may need attention")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(accentColor.opacity(0.1), in: Capsule())
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var strengthDescription: String {
        let abs = abs(correlation.correlationStrength)
        switch abs {
        case 0..<0.1:  return "Not Enough Data to Tell"
        case 0.1..<0.3: return "Slight Connection"
        case 0.3..<0.5: return "Moderate Connection"
        case 0.5..<0.7: return "Strong Connection"
        default:         return "Very Strong Connection"
        }
    }

    // MARK: - What This Means

    private var whatThisMeans: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What This Means", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(correlation.interpretation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Data context
            HStack(spacing: 8) {
                Label("Confidence", systemImage: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(correlation.confidence.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(confidenceColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(confidenceColor.opacity(0.1), in: Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var confidenceColor: Color {
        switch correlation.confidence {
        case .high:   return .green
        case .medium: return .orange
        case .low:    return .gray
        }
    }

    // MARK: - Recommendations

    private var recommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What You Can Do", systemImage: "target")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(Array(actionableRecommendations.enumerated()), id: \.offset) { index, rec in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(accentColor))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rec.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text(rec.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let goal = rec.weeklyGoal {
                            HStack(spacing: 4) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 9))
                                Text("Goal: \(goal)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(accentColor)
                            .padding(.top, 2)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Related Tools

    private var relatedTools: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Try These", systemImage: "apps.iphone")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(suggestedTools, id: \.name) { tool in
                HStack(spacing: 12) {
                    Image(systemName: tool.icon)
                        .font(.title3)
                        .foregroundStyle(tool.color)
                        .frame(width: 40, height: 40)
                        .background(tool.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tool.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text(tool.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Data-Driven Recommendations

    private struct Recommendation {
        let title: String
        let detail: String
        let weeklyGoal: String?
    }

    private struct ToolSuggestion {
        let name: String
        let icon: String
        let detail: String
        let color: Color
    }

    /// Recommendations based on the correlation factor type.
    private var actionableRecommendations: [Recommendation] {
        let factor = correlation.factorName.lowercased()

        if factor.contains("step") || factor.contains("walk") {
            return [
                Recommendation(
                    title: "Build a daily walking habit",
                    detail: "Start with a 10-minute walk after your biggest meal. Even short walks lower resting heart rate over time.",
                    weeklyGoal: "7,000+ steps on 5 days"
                ),
                Recommendation(
                    title: "Track your best times",
                    detail: "Notice when you feel most energized for walks. Morning walks tend to boost HRV for the rest of the day.",
                    weeklyGoal: nil
                ),
                Recommendation(
                    title: "Increase gradually",
                    detail: "Add 500 steps per week. Small, consistent increases are more sustainable than big jumps.",
                    weeklyGoal: "Increase weekly average by 500 steps"
                )
            ]
        }

        if factor.contains("sleep") {
            return [
                Recommendation(
                    title: "Create a wind-down routine",
                    detail: "Start dimming lights 30 minutes before bed. Use warm/amber lighting in the evening to support your circadian rhythm.",
                    weeklyGoal: "Consistent bedtime within 30 min window"
                ),
                Recommendation(
                    title: "Try guided sleep meditation",
                    detail: "Apps like Headspace or Calm offer sleep-specific sessions. Even 5 minutes of guided breathing before bed can improve sleep quality.",
                    weeklyGoal: "5 nights with wind-down routine"
                ),
                Recommendation(
                    title: "Improve your sleep environment",
                    detail: "A cool, dark, quiet room tends to support better sleep. Blue light filters on devices 2 hours before bed.",
                    weeklyGoal: "7-9 hours on 5+ nights"
                )
            ]
        }

        if factor.contains("exercise") || factor.contains("active") || factor.contains("workout") {
            return [
                Recommendation(
                    title: "Mix intensities throughout the week",
                    detail: "Alternate between easy days (zone 2 cardio) and harder sessions. Your heart recovers and adapts between efforts.",
                    weeklyGoal: "150 min moderate activity"
                ),
                Recommendation(
                    title: "Don't skip recovery days",
                    detail: "Rest days aren't lazy days — they're when your cardiovascular system actually improves. Aim for 2 recovery days per week.",
                    weeklyGoal: "2 active recovery days"
                ),
                Recommendation(
                    title: "Find activities you enjoy",
                    detail: "Consistency beats intensity. Swimming, cycling, dancing — whatever keeps you coming back is the best exercise.",
                    weeklyGoal: nil
                )
            ]
        }

        if factor.contains("hrv") || factor.contains("heart rate variability") {
            return [
                Recommendation(
                    title: "Practice slow breathing daily",
                    detail: "5 minutes of box breathing (4-4-4-4) or 4-7-8 breathing Many people find that regular breathing exercises correlate with higher HRV readings.",
                    weeklyGoal: "5 min breathing practice daily"
                ),
                Recommendation(
                    title: "Prioritize sleep consistency",
                    detail: "HRV is most influenced by sleep quality. A regular sleep schedule has the biggest impact.",
                    weeklyGoal: nil
                ),
                Recommendation(
                    title: "Manage stress proactively",
                    detail: "Regular mindfulness, nature time, or social connection all support higher HRV. Pick what works for you.",
                    weeklyGoal: "3 mindfulness sessions"
                )
            ]
        }

        // Default recommendations
        return [
            Recommendation(
                title: "Keep tracking consistently",
                detail: "Wear your Apple Watch daily and check in here. More data means more accurate insights about what works for you.",
                weeklyGoal: "7 days of data"
            ),
            Recommendation(
                title: "Focus on one change at a time",
                detail: "Pick the recommendation that feels easiest and stick with it for 2 weeks before adding another.",
                weeklyGoal: nil
            ),
            Recommendation(
                title: "Review your weekly report",
                detail: "Check the Insights tab each week to see how your changes are showing up in the data.",
                weeklyGoal: nil
            )
        ]
    }

    /// Suggested tools/apps based on the correlation factor.
    private var suggestedTools: [ToolSuggestion] {
        let factor = correlation.factorName.lowercased()

        if factor.contains("sleep") {
            return [
                ToolSuggestion(name: "Apple Mindfulness", icon: "brain.head.profile.fill", detail: "Built-in breathing exercises on Apple Watch", color: .teal),
                ToolSuggestion(name: "Headspace", icon: "moon.fill", detail: "Guided sleep meditations and wind-down routines", color: .blue),
                ToolSuggestion(name: "Night Shift / Focus Mode", icon: "moon.circle.fill", detail: "Reduce blue light and silence notifications at bedtime", color: .indigo)
            ]
        }

        if factor.contains("step") || factor.contains("walk") || factor.contains("active") {
            return [
                ToolSuggestion(name: "Apple Fitness+", icon: "figure.run", detail: "Guided walks and workouts with Apple Watch integration", color: .green),
                ToolSuggestion(name: "Activity Rings", icon: "circle.circle", detail: "Use Move, Exercise, and Stand goals to stay motivated", color: .red),
                ToolSuggestion(name: "Podcasts & Audiobooks", icon: "headphones", detail: "Make walks more enjoyable with something to listen to", color: .purple)
            ]
        }

        if factor.contains("hrv") || factor.contains("stress") || factor.contains("breathe") {
            return [
                ToolSuggestion(name: "Apple Mindfulness", icon: "brain.head.profile.fill", detail: "Reflect and breathe sessions on your Apple Watch", color: .teal),
                ToolSuggestion(name: "Headspace", icon: "leaf.fill", detail: "Guided meditations for stress, focus, and calm", color: .orange),
                ToolSuggestion(name: "Oak Meditation", icon: "wind", detail: "Simple breathing and meditation timer", color: .mint)
            ]
        }

        return [
            ToolSuggestion(name: "Apple Health", icon: "heart.fill", detail: "Check your full health data and trends", color: .red),
            ToolSuggestion(name: "Apple Fitness+", icon: "figure.run", detail: "Guided workouts for every fitness level", color: .green)
        ]
    }
}

// MARK: - Preview

#Preview("Steps Correlation") {
    CorrelationDetailSheet(
        correlation: CorrelationResult(
            factorName: "Daily Steps",
            correlationStrength: 0.72,
            interpretation: "On days you walk more, your HRV tends to be higher the next day. This is a strong, positive pattern.",
            confidence: .high
        )
    )
}

#Preview("Sleep Correlation") {
    CorrelationDetailSheet(
        correlation: CorrelationResult(
            factorName: "Sleep Duration",
            correlationStrength: 0.55,
            interpretation: "Longer sleep nights are followed by better HRV readings. This is one of the clearest patterns in your data.",
            confidence: .medium
        )
    )
}

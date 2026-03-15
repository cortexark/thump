// DashboardView+BuddyCards.swift
// Thump iOS
//
// Buddy-related cards: Suggestions, Check-In, and Recommendations
// — extracted from DashboardView for readability.

import SwiftUI

extension DashboardView {

    // MARK: - Buddy Suggestions

    @ViewBuilder
    var nudgeSection: some View {
        // Only show Buddy Says after bio age is unlocked (DOB set)
        // so nudges are based on full analysis including age-stratified norms
        if let assessment = viewModel.assessment,
           localStore.profile.dateOfBirth != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Your Daily Coaching", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    if let trend = viewModel.weeklyTrendSummary {
                        Label(trend, systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Based on your data today")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(
                    Array(assessment.dailyNudges.enumerated()),
                    id: \.offset
                ) { index, nudge in
                    Button {
                        InteractionLog.log(.cardTap, element: "nudge_\(index)", page: "Dashboard", details: nudge.category.rawValue)
                        // Navigate to Stress tab for rest/breathe nudges,
                        // Insights tab for everything else
                        withAnimation {
                            let stressCategories: [NudgeCategory] = [.rest, .breathe, .seekGuidance]
                            selectedTab = stressCategories.contains(nudge.category) ? 2 : 1
                        }
                    } label: {
                        NudgeCardView(
                            nudge: nudge,
                            onMarkComplete: {
                                viewModel.markNudgeComplete(at: index)
                            }
                        )
                    }
                    .buttonStyle(CardButtonStyle())
                    .accessibilityHint("Double tap to view details")
                }
            }
        }
    }

    // MARK: - Check-In Section

    var checkInSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Daily Check-In", systemImage: "face.smiling.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("How are you feeling?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.hasCheckedInToday {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: 0x22C55E))
                    Text("You checked in today. Nice!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: 0x22C55E).opacity(0.08))
                )
            } else {
                HStack(spacing: 10) {
                    ForEach(CheckInMood.allCases, id: \.self) { mood in
                        Button {
                            InteractionLog.log(.buttonTap, element: "checkin_\(mood.label.lowercased())", page: "Dashboard")
                            viewModel.submitCheckIn(mood: mood)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: moodIcon(for: mood))
                                    .font(.title2)
                                    .foregroundStyle(moodColor(for: mood))

                                Text(mood.label)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(moodColor(for: mood).opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        moodColor(for: mood).opacity(0.15),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Feeling \(mood.label)")
                    }
                }
            }
        }
        .accessibilityIdentifier("dashboard_checkin")
    }

    func moodIcon(for mood: CheckInMood) -> String {
        switch mood {
        case .great: return "sun.max.fill"
        case .good:  return "cloud.sun.fill"
        case .okay:  return "cloud.fill"
        case .rough: return "cloud.rain.fill"
        }
    }

    func moodColor(for mood: CheckInMood) -> Color {
        switch mood {
        case .great: return Color(hex: 0x22C55E)
        case .good:  return Color(hex: 0x0D9488)
        case .okay:  return Color(hex: 0xF59E0B)
        case .rough: return Color(hex: 0x8B5CF6)
        }
    }

    // MARK: - Buddy Recommendations Section

    /// Engine-driven actionable advice cards below Daily Goals.
    /// Pulls from readiness, stress, zones, coaching, and recovery to give
    /// specific, human-readable recommendations.
    @ViewBuilder
    var buddyRecommendationsSection: some View {
        if let recs = viewModel.buddyRecommendations, !recs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Buddy Says", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                ForEach(Array(recs.prefix(3).enumerated()), id: \.offset) { index, rec in
                    Button {
                        InteractionLog.log(.cardTap, element: "buddy_recommendation_\(index)", page: "Dashboard", details: rec.category.rawValue)
                        withAnimation { selectedTab = 1 }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: buddyRecIcon(rec))
                                .font(.subheadline)
                                .foregroundStyle(buddyRecColor(rec))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(rec.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(rec.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                // Metric impact tag
                                HStack(spacing: 4) {
                                    Image(systemName: metricImpactIcon(rec.category))
                                        .font(.system(size: 8))
                                    Text(metricImpactLabel(rec.category))
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundStyle(buddyRecColor(rec))
                                .padding(.top, 2)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(buddyRecColor(rec).opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(buddyRecColor(rec).opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(CardButtonStyle())
                    .accessibilityLabel("\(rec.title): \(rec.message)")
                    .accessibilityHint("Double tap for details")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .accessibilityIdentifier("dashboard_buddy_recommendations")
        }
    }

    func buddyRecIcon(_ rec: BuddyRecommendation) -> String {
        switch rec.category {
        case .rest:         return "bed.double.fill"
        case .breathe:      return "wind"
        case .walk:         return "figure.walk"
        case .moderate:     return "figure.run"
        case .hydrate:      return "drop.fill"
        case .seekGuidance: return "stethoscope"
        case .celebrate:    return "party.popper.fill"
        case .sunlight:     return "sun.max.fill"
        }
    }

    func buddyRecColor(_ rec: BuddyRecommendation) -> Color {
        switch rec.category {
        case .rest:         return Color(hex: 0x8B5CF6)
        case .breathe:      return Color(hex: 0x0D9488)
        case .walk:         return Color(hex: 0x3B82F6)
        case .moderate:     return Color(hex: 0xF97316)
        case .hydrate:      return Color(hex: 0x06B6D4)
        case .seekGuidance: return Color(hex: 0xEF4444)
        case .celebrate:    return Color(hex: 0x22C55E)
        case .sunlight:     return Color(hex: 0xF59E0B)
        }
    }

    /// Maps a recommendation category to the metric it improves.
    func metricImpactLabel(_ category: NudgeCategory) -> String {
        switch category {
        case .walk:         return "Improves VO2 max & recovery"
        case .rest:         return "Lowers resting heart rate"
        case .hydrate:      return "Supports HRV & recovery"
        case .breathe:      return "Reduces stress score"
        case .moderate:     return "Boosts cardio fitness"
        case .celebrate:    return "Keep it up!"
        case .seekGuidance: return "Protect your heart health"
        case .sunlight:     return "Improves sleep & circadian rhythm"
        }
    }

    func metricImpactIcon(_ category: NudgeCategory) -> String {
        switch category {
        case .walk:         return "arrow.up.heart.fill"
        case .rest:         return "heart.fill"
        case .hydrate:      return "waveform.path.ecg"
        case .breathe:      return "brain.head.profile"
        case .moderate:     return "lungs.fill"
        case .celebrate:    return "star.fill"
        case .seekGuidance: return "shield.fill"
        case .sunlight:     return "moon.zzz.fill"
        }
    }
}

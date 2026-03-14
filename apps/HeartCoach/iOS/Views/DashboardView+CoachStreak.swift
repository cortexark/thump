// DashboardView+CoachStreak.swift
// Thump iOS
//
// Buddy Coach, Streak Badge, Loading, and Error views
// — extracted from DashboardView for readability.

import SwiftUI

extension DashboardView {

    // MARK: - Buddy Coach (was "Your Heart Coach")

    @ViewBuilder
    var buddyCoachSection: some View {
        if let report = viewModel.coachingReport {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(Color(hex: 0x8B5CF6))
                    Text("Buddy Coach")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()

                    // Progress score
                    Text("\(report.weeklyProgressScore)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(
                                report.weeklyProgressScore >= 70
                                    ? Color(hex: 0x22C55E)
                                    : (report.weeklyProgressScore >= 45
                                       ? Color(hex: 0x3B82F6)
                                       : Color(hex: 0xF59E0B))
                            )
                        )
                        .accessibilityLabel("Progress score: \(report.weeklyProgressScore)")
                }

                // Hero message
                Text(report.heroMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Top 2 insights
                ForEach(Array(report.insights.prefix(2).enumerated()), id: \.offset) { _, insight in
                    HStack(spacing: 8) {
                        Image(systemName: insight.icon)
                            .font(.caption)
                            .foregroundStyle(
                                insight.direction == .improving
                                    ? Color(hex: 0x22C55E)
                                    : (insight.direction == .declining
                                       ? Color(hex: 0xF59E0B)
                                       : Color(hex: 0x3B82F6))
                            )
                            .frame(width: 20)
                        Text(insight.message)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Top projection
                if let proj = report.projections.first {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                            .foregroundStyle(Color(hex: 0xF59E0B))
                        Text(proj.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: 0xF59E0B).opacity(0.06))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: 0x8B5CF6).opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(hex: 0x8B5CF6).opacity(0.12), lineWidth: 1)
            )
            .accessibilityIdentifier("dashboard_coaching_card")
        }
    }

    // MARK: - Streak Badge

    @ViewBuilder
    var streakSection: some View {
        let streak = viewModel.profileStreakDays
        if streak > 0 {
            Button {
                InteractionLog.log(.cardTap, element: "streak_badge", page: "Dashboard", details: "\(streak) days")
                withAnimation { selectedTab = 1 }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0xF97316), Color(hex: 0xEF4444)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(streak)-Day Streak")
                            .font(.headline)
                            .fontDesign(.rounded)
                            .foregroundStyle(.primary)

                        Text("Keep checking in daily to build your streak.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0xF97316).opacity(0.08),
                                    Color(hex: 0xEF4444).opacity(0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(hex: 0xF97316).opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak)-day streak. Double tap to view insights.")
            .accessibilityHint("Opens the Insights tab")
            .accessibilityIdentifier("dashboard_streak_badge")
        }
    }

    // MARK: - Loading View

    var loadingView: some View {
        VStack(spacing: 20) {
            ThumpBuddy(mood: .content, size: 80)

            Text("Getting your wellness snapshot ready...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Getting your wellness snapshot ready")
    }

    // MARK: - Error View

    func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            ThumpBuddy(mood: .stressed, size: 70)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                InteractionLog.log(.buttonTap, element: "try_again", page: "Dashboard")
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: 0xF97316))
            .accessibilityHint("Double tap to reload your wellness data")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

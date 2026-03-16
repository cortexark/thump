// InsightsView+DesignB.swift
// Thump iOS
//
// Design B variant of the Insights tab — a refreshed layout with gradient hero,
// visual focus cards, and a more magazine-style presentation.
// Activated via Settings toggle (thump_design_variant_b).

import SwiftUI

extension InsightsView {

    // MARK: - Design B Scroll Content

    /// Design B replaces the scroll content with a reskinned layout.
    var scrollContentB: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                insightsHeroCardB
                focusForTheWeekSectionB
                weeklyReportSectionB
                topActionCardB
                howActivityAffectsSectionB
                correlationsSection          // reuse A — data-driven, no reskin needed
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Hero Card B (Wider gradient, metric pills)

    private var insightsHeroCardB: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row: icon + subtitle
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.title3)
                    .foregroundStyle(.white)
                Text("Weekly Insight")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }

            Text(heroInsightText)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            if let actionText = heroActionText {
                HStack(spacing: 6) {
                    Text(actionText)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.white.opacity(0.2)))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x6D28D9), Color(hex: 0x7C3AED), Color(hex: 0xA855F7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color(hex: 0x7C3AED).opacity(0.2), radius: 12, y: 4)
        .accessibilityIdentifier("insights_hero_card_b")
    }

    // MARK: - Focus for the Week B (Card grid)

    @ViewBuilder
    private var focusForTheWeekSectionB: some View {
        if let plan = viewModel.actionPlan, !plan.items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.subheadline)
                        .foregroundStyle(.pink)
                    Text("Focus for the Week")
                        .font(.headline)
                }
                .padding(.top, 8)

                let targets = InsightsHelpers.weeklyFocusTargets(from: plan)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(targets.enumerated()), id: \.offset) { _, target in
                        VStack(spacing: 8) {
                            Image(systemName: target.icon)
                                .font(.title2)
                                .foregroundStyle(target.color)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle().fill(target.color.opacity(0.12))
                                )

                            Text(target.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                            if let value = target.targetValue {
                                Text(value)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(target.color)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(target.color.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Weekly Report B (Compact summary)

    @ViewBuilder
    private var weeklyReportSectionB: some View {
        if let report = viewModel.weeklyReport {
            Button {
                InteractionLog.log(.cardTap, element: "weekly_report_b", page: "Insights")
                showingReportDetail = true
            } label: {
                HStack(spacing: 14) {
                    // Score circle
                    if let score = report.avgCardioScore {
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 5)
                            Circle()
                                .trim(from: 0, to: score / 100.0)
                                .stroke(trendColorB(report.trendDirection), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(score))")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .frame(width: 48, height: 48)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Weekly Report")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            TrendBadgeView(direction: report.trendDirection)
                        }
                        Text(InsightsHelpers.reportDateRange(report))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("weekly_report_card_b")
        }
    }

    // MARK: - Top Action Card B (Numbered pills)

    @ViewBuilder
    private var topActionCardB: some View {
        if let plan = viewModel.actionPlan, !plan.items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: 0x22C55E))
                    Text("This Week's Actions")
                        .font(.headline)
                }

                ForEach(Array(plan.items.prefix(3).enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(actionCategoryColor(item.category)))

                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Image(systemName: actionCategoryIcon(item.category))
                            .font(.caption)
                            .foregroundStyle(actionCategoryColor(item.category))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(actionCategoryColor(item.category).opacity(0.04))
                    )
                }

                if plan.items.count > 3 {
                    Button {
                        InteractionLog.log(.buttonTap, element: "see_all_actions_b", page: "Insights")
                        showingReportDetail = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("See all \(plan.items.count) actions")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(Color(hex: 0x22C55E))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(hex: 0x22C55E).opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - Educational Cards B (Horizontal scroll)

    private var howActivityAffectsSectionB: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(.pink)
                Text("Did You Know?")
                    .font(.headline)
            }
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    educationalCardB(
                        icon: "figure.walk",
                        iconColor: Color(hex: 0x22C55E),
                        title: "Activity & VO2 Max",
                        snippet: "Regular brisk walking strengthens your heart's pumping efficiency over weeks."
                    )
                    educationalCardB(
                        icon: "heart.circle",
                        iconColor: Color(hex: 0x3B82F6),
                        title: "Zone Training",
                        snippet: "Zones 2-3 train your heart to recover faster after exertion."
                    )
                    educationalCardB(
                        icon: "moon.fill",
                        iconColor: Color(hex: 0x8B5CF6),
                        title: "Sleep & HRV",
                        snippet: "Consistent 7-8 hour nights typically raise HRV over 2-4 weeks."
                    )
                    educationalCardB(
                        icon: "brain.head.profile",
                        iconColor: Color(hex: 0xF59E0B),
                        title: "Stress & RHR",
                        snippet: "Breathing exercises help lower resting heart rate by calming fight-or-flight."
                    )
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Design B Helpers

    private func educationalCardB(icon: String, iconColor: Color, title: String, snippet: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(Circle().fill(iconColor.opacity(0.12)))

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(snippet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 160)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func trendColorB(_ direction: WeeklyReport.TrendDirection) -> Color {
        switch direction {
        case .up: return .green
        case .flat: return .blue
        case .down: return .orange
        }
    }

    private func actionCategoryColor(_ category: WeeklyActionCategory) -> Color {
        switch category {
        case .activity: return Color(hex: 0x3B82F6)
        case .sleep:    return Color(hex: 0x8B5CF6)
        case .breathe:  return Color(hex: 0x0D9488)
        case .sunlight: return Color(hex: 0xF59E0B)
        case .hydrate:  return Color(hex: 0x06B6D4)
        }
    }

    private func actionCategoryIcon(_ category: WeeklyActionCategory) -> String {
        switch category {
        case .activity: return "figure.walk"
        case .sleep:    return "moon.stars.fill"
        case .breathe:  return "wind"
        case .sunlight: return "sun.max.fill"
        case .hydrate:  return "drop.fill"
        }
    }
}

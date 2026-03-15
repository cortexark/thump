// DashboardView+DesignB.swift
// Thump iOS
//
// Design B variant of Dashboard cards — a refreshed layout with gradient-tinted cards,
// larger typography, and a more visual presentation. Activated via Settings toggle.

import SwiftUI

extension DashboardView {

    // MARK: - Design B Dashboard Content

    /// Design B card stack — reorders and reskins the dashboard cards.
    @ViewBuilder
    var designBCardStack: some View {
        readinessSectionB              // 1. Thump Check (gradient card)
        checkInSectionB               // 2. Daily check-in (compact)
        howYouRecoveredCardB           // 3. Recovery (visual trend)
        consecutiveAlertCard           // 4. Alert (same — critical info)
        buddyRecommendationsSectionB   // 5. Buddy Says (pill style)
        dailyGoalsSection              // 6. Goals (reuse A)
        zoneDistributionSection        // 7. Zones (reuse A)
        streakSection                  // 8. Streak (reuse A)
    }

    // MARK: - Thump Check B (Gradient Card)

    @ViewBuilder
    var readinessSectionB: some View {
        if let result = viewModel.readinessResult {
            VStack(spacing: 0) {
                // Gradient header with score
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Thump Check")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))
                            .textCase(.uppercase)
                            .tracking(1)
                        Text(thumpCheckBadge(result))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    // Score circle
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: Double(result.score) / 100.0)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(result.score)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 56, height: 56)
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: readinessBGradientColors(result.level),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                // Body content
                VStack(spacing: 12) {
                    Text(thumpCheckRecommendation(result))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Horizontal metric strip
                    HStack(spacing: 0) {
                        metricStripItem(
                            icon: "heart.fill",
                            value: "\(result.score)",
                            label: "Recovery",
                            color: recoveryPillColor(result)
                        )
                        Divider().frame(height: 32)
                        metricStripItem(
                            icon: "flame.fill",
                            value: viewModel.zoneAnalysis.map { "\($0.overallScore)" } ?? "—",
                            label: "Activity",
                            color: activityPillColor
                        )
                        Divider().frame(height: 32)
                        metricStripItem(
                            icon: "brain.head.profile",
                            value: viewModel.stressResult.map { "\(Int($0.score))" } ?? "—",
                            label: "Stress",
                            color: stressPillColor
                        )
                    }
                    .padding(.vertical, 4)

                    // Week-over-week trend (inline)
                    if let wow = viewModel.assessment?.weekOverWeekTrend {
                        weekOverWeekBannerB(wow)
                    }

                    // Recovery context
                    if let ctx = viewModel.assessment?.recoveryContext {
                        recoveryContextBanner(ctx)
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: readinessColor(for: result.level).opacity(0.15), radius: 12, y: 4)
            .accessibilityIdentifier("dashboard_readiness_card_b")
        }
    }

    // MARK: - Check-In B (Compact Horizontal)

    @ViewBuilder
    var checkInSectionB: some View {
        if !viewModel.hasCheckedInToday {
            VStack(spacing: 10) {
                HStack {
                    Label("Daily Check-In", systemImage: "face.smiling.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("How are you feeling?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    checkInButtonB(emoji: "☀️", label: "Great", mood: .great, color: .green)
                    checkInButtonB(emoji: "🌤️", label: "Good", mood: .good, color: .teal)
                    checkInButtonB(emoji: "☁️", label: "Okay", mood: .okay, color: .orange)
                    checkInButtonB(emoji: "🌧️", label: "Rough", mood: .rough, color: .purple)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        } else {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Checked in today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.green.opacity(0.08))
            )
        }
    }

    // MARK: - Recovery Card B (Visual)

    @ViewBuilder
    var howYouRecoveredCardB: some View {
        if let recoveryTrend = viewModel.assessment?.recoveryTrend,
           let current = recoveryTrend.currentWeekMean,
           let baseline = recoveryTrend.baselineMean {
            let trendColor = recoveryDirectionColor(recoveryTrend.direction)
            VStack(spacing: 12) {
                HStack {
                    Label("Recovery", systemImage: "arrow.up.heart.fill")
                        .font(.headline)
                    Spacer()
                    Text(recoveryTrend.direction.displayText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(trendColor)
                        )
                }

                // Visual bar comparison
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(current)) bpm")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(trendColor)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Baseline")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(baseline)) bpm")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }

                // Trend bar
                GeometryReader { geo in
                    let maxVal = max(baseline, current, 1)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(trendColor)
                            .frame(width: geo.size.width * (current / maxVal))
                    }
                }
                .frame(height: 8)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .onTapGesture {
                InteractionLog.log(.cardTap, element: "recovery_card_b", page: "Dashboard")
                withAnimation { selectedTab = 3 }
            }
        }
    }

    // MARK: - Buddy Recommendations B (Pill Style)

    @ViewBuilder
    var buddyRecommendationsSectionB: some View {
        if let recs = viewModel.buddyRecommendations, !recs.isEmpty {
            VStack(spacing: 10) {
                HStack {
                    Label("Buddy Says", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.headline)
                    Spacer()
                }

                ForEach(recs.prefix(3), id: \.title) { rec in
                    HStack(spacing: 12) {
                        Image(systemName: nudgeCategoryIcon(rec.category))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(nudgeCategoryColor(rec.category))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle().fill(nudgeCategoryColor(rec.category).opacity(0.12))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(metricImpactLabel(rec.category))
                                .font(.caption2)
                                .foregroundStyle(nudgeCategoryColor(rec.category))
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(nudgeCategoryColor(rec.category).opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(nudgeCategoryColor(rec.category).opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - Design B Helpers

    private func readinessBGradientColors(_ level: ReadinessLevel) -> [Color] {
        switch level {
        case .primed:     return [Color(hex: 0x059669), Color(hex: 0x34D399)]
        case .ready:      return [Color(hex: 0x0D9488), Color(hex: 0x5EEAD4)]
        case .moderate:   return [Color(hex: 0xD97706), Color(hex: 0xFBBF24)]
        case .recovering: return [Color(hex: 0xDC2626), Color(hex: 0xFCA5A5)]
        }
    }

    private func metricStripItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func checkInButtonB(emoji: String, label: String, mood: CheckInMood, color: Color) -> some View {
        Button {
            viewModel.submitCheckIn(mood: mood)
            InteractionLog.log(.buttonTap, element: "check_in_\(label.lowercased())_b", page: "Dashboard")
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title3)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func weekOverWeekBannerB(_ wow: WeekOverWeekTrend) -> some View {
        let isElevated = wow.direction == .elevated || wow.direction == .significantElevation
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: isElevated ? "arrow.up.right" : wow.direction == .stable ? "arrow.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text("RHR \(Int(wow.baselineMean)) → \(Int(wow.currentWeekMean)) bpm")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text(recoveryTrendLabel(wow.direction))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.06))
        )
        .onTapGesture {
            InteractionLog.log(.cardTap, element: "wow_banner_b", page: "Dashboard")
            withAnimation { selectedTab = 3 }
        }
    }

    // MARK: - Missing Helpers for Design B

    private func recoveryDirectionColor(_ direction: RecoveryTrendDirection) -> Color {
        switch direction {
        case .improving:        return .green
        case .stable:           return .blue
        case .declining:        return .orange
        case .insufficientData: return .gray
        }
    }

    private func nudgeCategoryIcon(_ category: NudgeCategory) -> String {
        category.icon
    }

    private func nudgeCategoryColor(_ category: NudgeCategory) -> Color {
        switch category {
        case .walk:         return .green
        case .rest:         return .purple
        case .hydrate:      return .cyan
        case .breathe:      return .teal
        case .moderate:     return .orange
        case .celebrate:    return .yellow
        case .seekGuidance: return .red
        case .sunlight:     return .orange
        }
    }

}

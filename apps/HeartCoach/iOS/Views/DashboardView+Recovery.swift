// DashboardView+Recovery.swift
// Thump iOS
//
// How You Recovered card + Consecutive Alert  - extracted from DashboardView for readability.

import SwiftUI

extension DashboardView {

    // MARK: - How You Recovered Card (replaces Weekly RHR Trend)

    @ViewBuilder
    var howYouRecoveredCard: some View {
        if let wow = viewModel.assessment?.weekOverWeekTrend {
            let diff = wow.currentWeekMean - wow.baselineMean
            let trendingDown = diff <= 0
            let trendColor = trendingDown ? Color(hex: 0x22C55E) : Color(hex: 0xEF4444)

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: trendingDown ? "arrow.down.heart.fill" : "arrow.up.heart.fill")
                        .font(.subheadline)
                        .foregroundStyle(trendColor)

                    Text("How You Recovered")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    // Qualitative trend badge instead of raw bpm
                    Text(recoveryTrendLabel(wow.direction))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(trendColor))
                }

                // Narrative body  - human-readable recovery story
                Text(recoveryNarrative(wow: wow))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Trend direction message + action
                if trendingDown {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Color(hex: 0x22C55E))
                        Text("RHR trending down  - that often tracks with good sleep and consistent activity")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(hex: 0x22C55E))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: 0x22C55E).opacity(0.08))
                    )
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.fill")
                            .font(.caption)
                            .foregroundStyle(Color(hex: 0xF59E0B))
                        Text(recoveryAction(wow: wow))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: 0xF59E0B).opacity(0.08))
                    )
                }

                // Status pills: This Week / 28-Day as qualitative labels
                HStack(spacing: 8) {
                    recoveryStatusPill(
                        label: "This Week",
                        value: recoveryQualityLabel(bpm: wow.currentWeekMean, baseline: wow.baselineMean),
                        color: trendColor
                    )
                    recoveryStatusPill(
                        label: "Monthly Avg",
                        value: "Baseline",
                        color: Color(hex: 0x3B82F6)
                    )
                    // Diff pill
                    VStack(spacing: 4) {
                        Text(String(format: "%+.1f", diff))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(trendColor)
                        Text("Change")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(trendColor.opacity(0.08))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(trendColor.opacity(0.15), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("How you recovered: \(recoveryNarrative(wow: wow))")
            .accessibilityIdentifier("dashboard_recovery_card")
            .onTapGesture {
                InteractionLog.log(.cardTap, element: "recovery_card", page: "Dashboard")
                withAnimation { selectedTab = 3 }
            }
        }
    }

    // MARK: - How You Recovered Helpers

    func recoveryTrendLabel(_ direction: WeeklyTrendDirection) -> String {
        // Override with readiness context  - don't show "Steady" when sleep is critically low
        if let readiness = viewModel.readinessResult {
            if let sleepPillar = readiness.pillars.first(where: { $0.type == .sleep }),
               sleepPillar.score < 50 {  // NOTE: 50 differs from recoveryModerateScore (55)
                return "Low sleep"
            }
            if readiness.level == .recovering {
                return "Needs rest"
            }
        }
        switch direction {
        case .significantImprovement: return "Great"
        case .improving:             return "Improving"
        case .stable:                return "Steady"
        case .elevated:              return "Elevated"
        case .significantElevation:  return "Needs rest"
        }
    }

    func recoveryQualityLabel(bpm: Double, baseline: Double) -> String {
        let diff = bpm - baseline
        if diff <= -3   { return "Strong" }
        if diff <= -0.5 { return "Good" }
        if diff <= 1.5  { return "Normal" }
        return "Elevated"
    }

    /// Builds a human-readable recovery narrative from the trend data + sleep + stress.
    /// When coordinator is active, delegates to AdvicePresenter.
    func recoveryNarrative(wow: WeekOverWeekTrend) -> String {
        // Coordinator path: use AdvicePresenter
        if ConfigService.enableCoordinator,
           let adviceState = coordinator.bundle?.adviceState,
           let narrative = AdvicePresenter.recoveryNarrative(for: adviceState) {
            return narrative
        }

        // Legacy path
        let policy = ConfigService.activePolicy
        var parts: [String] = []
        var sleepIsLow = false

        if let readiness = viewModel.readinessResult {
            if let sleepPillar = readiness.pillars.first(where: { $0.type == .sleep }) {
                if sleepPillar.score >= Double(policy.view.recoveryStrongScore) {
                    let hrs = viewModel.todaySnapshot?.sleepHours ?? 0
                    parts.append("Sleep was solid\(hrs > 0 ? " (\(String(format: "%.1f", hrs)) hrs)" : "")")
                } else if sleepPillar.score >= 50 {
                    parts.append("Sleep was okay but could be better")
                } else {
                    parts.append("Short on sleep  - that slows recovery")
                    sleepIsLow = true
                }
            }
        }

        if let hrv = viewModel.todaySnapshot?.hrvSDNN, hrv > 0 {
            let diff = wow.currentWeekMean - wow.baselineMean
            if diff <= -1 {
                parts.append("HRV is trending up  - body is recovering well")
            } else if diff >= 2 {
                parts.append("HRV dipped  - body is still catching up")
            }
        }

        let diff = wow.currentWeekMean - wow.baselineMean
        if sleepIsLow {
            parts.append("Prioritize rest tonight  - sleep is the biggest lever for recovery.")
        } else if diff <= -2 {
            parts.append("Your recovery is looking strong this week.")
        } else if diff <= 0.5 {
            parts.append("Recovery is on track.")
        } else {
            parts.append("Your body could use a bit more rest.")
        }

        return parts.joined(separator: ". ")
    }

    /// Action recommendation when trend is going up (not great).
    func recoveryAction(wow: WeekOverWeekTrend) -> String {
        let stress = viewModel.stressResult
        if let stress, stress.level == .elevated {
            return "Stress is high  - an easy walk and early bedtime will help"
        }
        let diff = wow.currentWeekMean - wow.baselineMean
        if diff > 3 {
            return "Rest day recommended  - extra sleep tonight"
        }
        return "Consider a lighter day or an extra 30 min of sleep"
    }

    func recoveryStatusPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caption2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Consecutive Elevation Alert Card

    @ViewBuilder
    var consecutiveAlertCard: some View {
        if let alert = viewModel.assessment?.consecutiveAlert {
            Button {
                InteractionLog.log(.cardTap, element: "consecutive_alert", page: "Dashboard", details: "\(alert.consecutiveDays) days elevated")
                withAnimation { selectedTab = 3 }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: 0xF59E0B))

                        Text("Elevated Resting Heart Rate")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(alert.consecutiveDays) days")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color(hex: 0xF59E0B))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: 0xF59E0B).opacity(0.1), in: Capsule())
                    }

                    Text("Your resting heart rate has been above your personal average for \(alert.consecutiveDays) consecutive days. This sometimes happens during busy weeks, travel, or when your routine changes. Extra rest often helps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recent Avg")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f bpm", alert.elevatedMean))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(hex: 0xEF4444))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Normal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f bpm", alert.personalMean))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(hex: 0xF59E0B).opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(CardButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Alert: resting heart rate elevated for \(alert.consecutiveDays) consecutive days")
            .accessibilityHint("Double tap to view trends")
        }
    }
}

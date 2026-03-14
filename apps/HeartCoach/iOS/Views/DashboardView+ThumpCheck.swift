// DashboardView+ThumpCheck.swift
// Thump iOS
//
// Thump Check section and helpers — extracted from DashboardView for readability.

import SwiftUI

extension DashboardView {

    // MARK: - Thump Check Section (replaces raw Readiness score)

    /// Builds "Thump Check" — a context-aware recommendation card that tells you
    /// what to do today based on yesterday's zones, recovery, and stress.
    /// No raw numbers — just a human sentence and action pills.
    @ViewBuilder
    var readinessSection: some View {
        if let result = viewModel.readinessResult {
            VStack(spacing: 16) {
                // Section header
                HStack {
                    Label("Thump Check", systemImage: "heart.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    // Badge is tappable — navigates to buddy recommendations
                    Button {
                        InteractionLog.log(.buttonTap, element: "readiness_badge", page: "Dashboard")
                        withAnimation { selectedTab = 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Text(thumpCheckBadge(result))
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(readinessColor(for: result.level))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View buddy recommendations")
                    .accessibilityHint("Opens Insights tab")
                }

                // Main recommendation — context-aware sentence
                Text(thumpCheckRecommendation(result))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Status pills: Recovery | Activity | Stress → Action
                HStack(spacing: 8) {
                    todaysPlayPill(
                        icon: "heart.fill",
                        label: "Recovery",
                        value: recoveryLabel(result),
                        color: recoveryPillColor(result)
                    )
                    todaysPlayPill(
                        icon: "flame.fill",
                        label: "Activity",
                        value: activityLabel,
                        color: activityPillColor
                    )
                    todaysPlayPill(
                        icon: "brain.head.profile",
                        label: "Stress",
                        value: stressLabel,
                        color: stressPillColor
                    )
                }

                // Recovery context banner — shown when readiness is low.
                if let ctx = viewModel.assessment?.recoveryContext {
                    recoveryContextBanner(ctx)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        readinessColor(for: result.level).opacity(0.15),
                        lineWidth: 1
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Thump Check: \(thumpCheckRecommendation(result))"
            )
            .accessibilityIdentifier("dashboard_readiness_card")
        } else if let assessment = viewModel.assessment {
            StatusCardView(
                status: assessment.status,
                confidence: assessment.confidence,
                cardioScore: assessment.cardioScore,
                explanation: assessment.explanation
            )
        }
    }

    // MARK: - Thump Check Helpers

    /// Human-readable badge for the Thump Check card.
    func thumpCheckBadge(_ result: ReadinessResult) -> String {
        switch result.level {
        case .primed:     return "Feeling great"
        case .ready:      return "Good to go"
        case .moderate:   return "Take it easy"
        case .recovering: return "Rest up"
        }
    }

    /// Context-aware recommendation sentence based on yesterday's zones, recovery, and stress.
    func thumpCheckRecommendation(_ result: ReadinessResult) -> String {
        let assessment = viewModel.assessment
        let zones = viewModel.zoneAnalysis
        let stress = viewModel.stressResult

        // What did yesterday look like?
        let yesterdayZoneContext = yesterdayZoneSummary()

        // Build recommendation based on current state
        if result.score < 45 {
            // Low recovery
            if let stress, stress.level == .elevated {
                return "\(yesterdayZoneContext)Recovery is low and stress is up — take a full rest day. Your body needs it."
            }
            return "\(yesterdayZoneContext)Recovery is low. A gentle walk or stretching is your best move today."
        }

        if result.score < 65 {
            // Moderate recovery
            if let zones, zones.recommendation == .tooMuchIntensity {
                return "\(yesterdayZoneContext)You've been pushing hard. A moderate effort today lets your body absorb those gains."
            }
            if assessment?.stressFlag == true {
                return "\(yesterdayZoneContext)Stress is elevated. Keep it light — a calm walk or easy movement."
            }
            return "\(yesterdayZoneContext)Decent recovery. A moderate workout works well today."
        }

        // Good recovery (65+)
        if result.score >= 80 {
            if let zones, zones.recommendation == .needsMoreThreshold {
                return "\(yesterdayZoneContext)You're fully charged. Great day for a harder effort or tempo session."
            }
            return "\(yesterdayZoneContext)You're primed. Push it if you want — your body can handle it."
        }

        // Ready (65-79)
        if let zones, zones.recommendation == .needsMoreAerobic {
            return "\(yesterdayZoneContext)Good recovery. A steady aerobic session would build your base nicely."
        }
        return "\(yesterdayZoneContext)Solid recovery. You can go moderate to hard depending on how you feel."
    }

    /// Summarizes yesterday's dominant zone activity for context.
    func yesterdayZoneSummary() -> String {
        guard let zones = viewModel.zoneAnalysis else { return "" }

        // Find the dominant zone from yesterday's analysis
        let sorted = zones.pillars.sorted { $0.actualMinutes > $1.actualMinutes }
        guard let dominant = sorted.first, dominant.actualMinutes > 5 else {
            return "Light day yesterday. "
        }

        let zoneName: String
        switch dominant.zone {
        case .recovery:  zoneName = "easy zone"
        case .fatBurn:   zoneName = "fat-burn zone"
        case .aerobic:   zoneName = "aerobic zone"
        case .threshold: zoneName = "threshold zone"
        case .peak:      zoneName = "peak zone"
        }

        let minutes = Int(dominant.actualMinutes)
        return "You spent \(minutes) min in \(zoneName) recently. "
    }

    /// Recovery label for the status pill.
    func recoveryLabel(_ result: ReadinessResult) -> String {
        if result.score >= 75 { return "Strong" }
        if result.score >= 55 { return "Moderate" }
        return "Low"
    }

    func recoveryPillColor(_ result: ReadinessResult) -> Color {
        if result.score >= 75 { return Color(hex: 0x22C55E) }
        if result.score >= 55 { return Color(hex: 0xF59E0B) }
        return Color(hex: 0xEF4444)
    }

    /// Activity label based on zone analysis.
    var activityLabel: String {
        guard let zones = viewModel.zoneAnalysis else { return "—" }
        if zones.overallScore >= 80 { return "High" }
        if zones.overallScore >= 50 { return "Moderate" }
        return "Low"
    }

    var activityPillColor: Color {
        guard let zones = viewModel.zoneAnalysis else { return .secondary }
        if zones.overallScore >= 80 { return Color(hex: 0x22C55E) }
        if zones.overallScore >= 50 { return Color(hex: 0xF59E0B) }
        return Color(hex: 0xEF4444)
    }

    /// Stress label from stress engine result.
    var stressLabel: String {
        guard let stress = viewModel.stressResult else { return "—" }
        switch stress.level {
        case .relaxed:  return "Low"
        case .balanced: return "Moderate"
        case .elevated: return "High"
        }
    }

    var stressPillColor: Color {
        guard let stress = viewModel.stressResult else { return .secondary }
        switch stress.level {
        case .relaxed:  return Color(hex: 0x22C55E)
        case .balanced: return Color(hex: 0xF59E0B)
        case .elevated: return Color(hex: 0xEF4444)
        }
    }

    /// A compact status pill showing icon + label + value.
    func todaysPlayPill(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
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

    func readinessPillarView(_ pillar: ReadinessPillar) -> some View {
        VStack(spacing: 6) {
            Image(systemName: pillar.type.icon)
                .font(.caption)
                .foregroundStyle(pillarColor(score: pillar.score))

            Text("\(Int(pillar.score))")
                .font(.caption2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)

            Text(pillar.type.displayName)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(pillarColor(score: pillar.score).opacity(0.08))
        )
        .accessibilityLabel(
            "\(pillar.type.displayName): \(Int(pillar.score)) out of 100"
        )
    }

    /// Recovery banner shown inside the readiness card when metrics signal the body needs to back off.
    /// Surfaces the WHY (driver metric + reason) and the WHAT (tonight's action).
    func recoveryContextBanner(_ ctx: RecoveryContext) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Why today is lighter
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hex: 0xF59E0B))
                Text(ctx.reason)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            Divider()

            // Tonight's action
            HStack(spacing: 6) {
                Image(systemName: "moon.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hex: 0x8B5CF6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tonight")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(ctx.tonightAction)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: 0xF59E0B).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: 0xF59E0B).opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recovery note: \(ctx.reason). Tonight: \(ctx.tonightAction)")
    }

    func readinessColor(for level: ReadinessLevel) -> Color {
        switch level {
        case .primed:     return Color(hex: 0x22C55E)
        case .ready:      return Color(hex: 0x0D9488)
        case .moderate:   return Color(hex: 0xF59E0B)
        case .recovering: return Color(hex: 0xEF4444)
        }
    }

    func pillarColor(score: Double) -> Color {
        switch score {
        case 80...:  return Color(hex: 0x22C55E)
        case 60..<80: return Color(hex: 0x0D9488)
        case 40..<60: return Color(hex: 0xF59E0B)
        default:      return Color(hex: 0xEF4444)
        }
    }
}

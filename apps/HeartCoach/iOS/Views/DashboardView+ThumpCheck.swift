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
                        showReadinessDetail = true
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
                    .accessibilityLabel("View readiness breakdown")
                    .accessibilityHint("Shows what's driving your score")
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
                        value: "\(result.score)",
                        color: recoveryPillColor(result)
                    )
                    todaysPlayPill(
                        icon: "flame.fill",
                        label: "Activity",
                        value: {
                            // Show actual active minutes (consistent with Daily Goals)
                            // instead of abstract zone quality score
                            let walk = viewModel.todaySnapshot?.walkMinutes ?? 0
                            let workout = viewModel.todaySnapshot?.workoutMinutes ?? 0
                            let total = Int(walk + workout)
                            return total > 0 ? "\(total)" : "—"
                        }(),
                        color: activityPillColor
                    )
                    todaysPlayPill(
                        icon: "brain.head.profile",
                        label: "Stress",
                        value: viewModel.stressResult.map { "\(Int($0.score))" } ?? "—",
                        color: stressPillColor
                    )
                }

                // Week-over-week trend indicators
                if let trend = viewModel.assessment?.weekOverWeekTrend {
                    weekOverWeekBanner(trend)
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
            .sheet(isPresented: $showReadinessDetail) {
                readinessDetailSheet(result)
            }
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

    /// Context-aware recommendation sentence based on yesterday's zones, recovery, stress, and sleep.
    /// When coordinator is active, delegates to AdvicePresenter.
    func thumpCheckRecommendation(_ result: ReadinessResult) -> String {
        let yesterdayZoneContext = yesterdayZoneSummary()

        // Coordinator path: use AdvicePresenter
        if ConfigService.enableCoordinator,
           let adviceState = coordinator.bundle?.adviceState,
           let snapshot = viewModel.todaySnapshot {
            let rec = AdvicePresenter.checkRecommendation(
                for: adviceState,
                readinessScore: result.score,
                snapshot: snapshot
            )
            return "\(yesterdayZoneContext)\(rec)"
        }

        // Legacy path
        let policy = ConfigService.activePolicy
        let assessment = viewModel.assessment
        let zones = viewModel.zoneAnalysis
        let stress = viewModel.stressResult
        let sleepHours = viewModel.todaySnapshot?.sleepHours

        if let hours = sleepHours, hours > 0, hours < policy.view.sleepLightOnlyHours {
            if hours < policy.view.sleepSkipWorkoutHours {
                return "\(yesterdayZoneContext)You got \(String(format: "%.1f", hours)) hours of sleep. Skip the workout — rest is the only thing that helps today. Get to bed early tonight."
            }
            return "\(yesterdayZoneContext)About \(String(format: "%.1f", hours)) hours of sleep last night. Keep it very light today — a short walk at most. Sleep is what your body needs most."
        }

        if result.score < 45 {
            if let stress, stress.level == .elevated {
                return "\(yesterdayZoneContext)Recovery is low and stress is up — take a full rest day. Your body needs it."
            }
            return "\(yesterdayZoneContext)Recovery is low. A gentle walk or stretching is your best move today."
        }

        if result.score < 65 {
            if let hours = sleepHours, hours < 6.0 {
                return "\(yesterdayZoneContext)\(String(format: "%.1f", hours)) hours of sleep. Take it easy — a walk is fine, but skip anything intense."
            }
            if let zones, zones.recommendation == .tooMuchIntensity {
                return "\(yesterdayZoneContext)You've been pushing hard. A moderate effort today lets your body absorb those gains."
            }
            if assessment?.stressFlag == true {
                return "\(yesterdayZoneContext)Stress is elevated. Keep it light — a calm walk or easy movement."
            }
            return "\(yesterdayZoneContext)Decent recovery. A moderate effort works well today."
        }

        let sleepTooLow = sleepHours.map { $0 < 6.0 } ?? false
        if result.score >= 80 && !sleepTooLow {
            if let zones, zones.recommendation == .needsMoreThreshold {
                return "\(yesterdayZoneContext)You're fully charged. Great day for a harder effort or tempo session."
            }
            return "\(yesterdayZoneContext)You're primed. Push it if you want — your body can handle it."
        }

        if sleepTooLow {
            return "\(yesterdayZoneContext)Your metrics look good, but sleep was short. A moderate effort is fine — don't push too hard."
        }
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
        let policy = ConfigService.activePolicy
        if result.score >= policy.view.recoveryStrongScore { return "Strong" }
        if result.score >= policy.view.recoveryModerateScore { return "Moderate" }
        return "Low"
    }

    func recoveryPillColor(_ result: ReadinessResult) -> Color {
        let policy = ConfigService.activePolicy
        if result.score >= policy.view.recoveryStrongScore { return Color(hex: 0x22C55E) }
        if result.score >= policy.view.recoveryModerateScore { return Color(hex: 0xF59E0B) }
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
        // Color based on actual active minutes (consistent with the pill value)
        let policy = ConfigService.activePolicy
        let walk = viewModel.todaySnapshot?.walkMinutes ?? 0
        let workout = viewModel.todaySnapshot?.workoutMinutes ?? 0
        let total = walk + workout
        if total >= policy.view.activityHighMinutes { return Color(hex: 0x22C55E) }
        if total >= policy.view.activityModerateMinutes { return Color(hex: 0xF59E0B) }
        return total > 0 ? Color(hex: 0xEF4444) : .secondary
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
        .onTapGesture {
            InteractionLog.log(.cardTap, element: "recovery_context_banner", page: "Dashboard")
            withAnimation { selectedTab = 2 }
        }
    }

    /// Shows week-over-week RHR change and recovery trend as a compact banner.
    func weekOverWeekBanner(_ trend: WeekOverWeekTrend) -> some View {
        let rhrChange = trend.currentWeekMean - trend.baselineMean
        let rhrArrow = rhrChange <= -1 ? "↓" : rhrChange >= 1 ? "↑" : "→"
        let rhrColor: Color = rhrChange <= -1
            ? Color(hex: 0x22C55E)
            : rhrChange >= 1 ? Color(hex: 0xEF4444) : .secondary

        return VStack(spacing: 6) {
            // RHR trend line
            HStack(spacing: 6) {
                Image(systemName: trend.direction.icon)
                    .font(.caption2)
                    .foregroundStyle(rhrColor)
                Text("RHR \(Int(trend.baselineMean)) \(rhrArrow) \(Int(trend.currentWeekMean)) bpm")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                Text(trendLabel(trend.direction))
                    .font(.system(size: 9))
                    .foregroundStyle(rhrColor)
            }

            // Recovery trend line (if available)
            if let recovery = viewModel.assessment?.recoveryTrend,
               recovery.direction != .insufficientData,
               let current = recovery.currentWeekMean,
               let baseline = recovery.baselineMean {
                let recChange = current - baseline
                let recArrow = recChange >= 1 ? "↑" : recChange <= -1 ? "↓" : "→"
                let recColor: Color = recChange >= 1
                    ? Color(hex: 0x22C55E)
                    : recChange <= -1 ? Color(hex: 0xEF4444) : .secondary

                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.up")
                        .font(.caption2)
                        .foregroundStyle(recColor)
                    Text("Recovery \(Int(baseline)) \(recArrow) \(Int(current)) bpm drop")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(recoveryDirectionLabel(recovery.direction))
                        .font(.system(size: 9))
                        .foregroundStyle(recColor)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("RHR trend: \(Int(trend.baselineMean)) to \(Int(trend.currentWeekMean)) bpm, \(trendLabel(trend.direction))")
        .onTapGesture {
            InteractionLog.log(.cardTap, element: "wow_trend_banner", page: "Dashboard")
            withAnimation { selectedTab = 3 }
        }
    }

    func trendLabel(_ direction: WeeklyTrendDirection) -> String {
        switch direction {
        case .significantImprovement: return "Improving fast"
        case .improving:             return "Trending down"
        case .stable:                return "Steady"
        case .elevated:              return "Creeping up"
        case .significantElevation:  return "Elevated"
        }
    }

    func recoveryDirectionLabel(_ direction: RecoveryTrendDirection) -> String {
        switch direction {
        case .improving:        return "Getting faster"
        case .stable:           return "Steady"
        case .declining:        return "Slowing down"
        case .insufficientData: return "Not enough data"
        }
    }

    // MARK: - Readiness Detail Sheet

    func readinessDetailSheet(_ result: ReadinessResult) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score circle + level
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(readinessColor(for: result.level).opacity(0.2), lineWidth: 10)
                                .frame(width: 100, height: 100)
                            Circle()
                                .trim(from: 0, to: Double(result.score) / 100.0)
                                .stroke(readinessColor(for: result.level), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 100, height: 100)
                            Text("\(result.score)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }

                        Text(thumpCheckBadge(result))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(readinessColor(for: result.level))

                        Text(result.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)

                    // Pillar breakdown
                    VStack(spacing: 12) {
                        Text("What's Driving Your Score")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(result.pillars, id: \.type) { pillar in
                            HStack(spacing: 12) {
                                Image(systemName: pillar.type.icon)
                                    .font(.title3)
                                    .foregroundStyle(pillarColor(score: pillar.score))
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(pillar.type.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Text("\(Int(pillar.score))")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .fontDesign(.rounded)
                                            .foregroundStyle(pillarColor(score: pillar.score))
                                    }

                                    // Score bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(.systemGray5))
                                                .frame(height: 6)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(pillarColor(score: pillar.score))
                                                .frame(width: geo.size.width * CGFloat(pillar.score / 100.0), height: 6)
                                        }
                                    }
                                    .frame(height: 6)

                                    Text(pillar.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(pillarColor(score: pillar.score).opacity(0.06))
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Readiness Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showReadinessDetail = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

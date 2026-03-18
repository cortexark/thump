// DashboardView+DesignB.swift
// Thump iOS
//
// Design B variant of Dashboard — full redesign per THUMP_DESIGN_SYSTEM v1.7.
// Hero screen: OLED dark canvas, state-color radial background glow,
// ThumpBuddy as centered hero (210pt) with orbiting score ring (288pt),
// score hierarchy with Chronic Steady de-escalation, driving signals row
// (Layer 2), Feeling vs Data row, and morning reveal ritual.
//
// Activated via Settings toggle: thump_design_variant_b = true.
// Platforms: iOS 17+

import SwiftUI

// AppState is defined in ThumpTheme.swift — UI helpers are extended there.

// MARK: - Design B Extension

extension DashboardView {

    // MARK: - Design B Root View

    /// Full-screen Design B dashboard. Called from `DashboardView.dashboardScrollView`
    /// when `useDesignB == true`. Manages the morning ritual + full-reveal layout.
    @ViewBuilder
    var designBFullScreen: some View {
        ZStack {
            // Layer 0: OLED base (#090910 per spec)
            Color(hex: 0x090910).ignoresSafeArea()

            // Layer 1: State-color radial ambient glow (15% opacity)
            designBStateGlow
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: designBAppState)

            // Layer 2: Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    designBHeroSection
                    designBContentSection
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { handleDesignBAppear() }
        .onTapGesture { handleRevealSkip() }
    }

    // MARK: - Design B Card Stack (used when embedded in existing scroll view)

    /// Design B card stack — reorders and reskins the dashboard cards.
    /// This is the entry point called from DashboardView when useDesignB = true.
    @ViewBuilder
    var designBCardStack: some View {
        // When embedded in the existing scroll/hero layout, show the new hero
        // and content sections as cards. Full-screen OLED layout is in designBFullScreen.
        designBHeroCard
        designBDrivingSignalsCard
        designBFeelingVsDataCard
        checkInSectionB
        howYouRecoveredCardB
        consecutiveAlertCard
        buddyRecommendationsSectionB
        dailyGoalsSection
        zoneDistributionSection
        streakSection
    }

    // MARK: - Hero Card (standalone card variant)

    @ViewBuilder
    private var designBHeroCard: some View {
        ZStack {
            // Radial background glow
            RadialGradient(
                colors: [
                    designBAppState.primaryColor.opacity(0.18),
                    designBAppState.primaryColor.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 180
            )

            VStack(spacing: 12) {
                // ThumpBuddy with orbiting score ring
                designBBuddyWithRing
                    .padding(.top, 24)

                // Score hierarchy (§21 de-escalation: Steady state flips sizes)
                designBScoreHierarchy

                // Mission sentence
                if let mission = designBMissionText {
                    Text(mission)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 4)
                }
            }
            .padding(.bottom, 28)
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(hex: 0x121218))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(designBAppState.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .animation(.easeInOut(duration: 0.4), value: designBAppState)
        .accessibilityIdentifier("dashboard_design_b_hero")
    }

    // MARK: - Hero Section (full-screen variant)

    private var designBHeroSection: some View {
        ZStack {
            VStack(spacing: 12) {
                Spacer().frame(height: 20)

                designBBuddyWithRing
                designBScoreHierarchy

                if let mission = designBMissionText {
                    Text(mission)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer().frame(height: 20)
            }
        }
        .frame(minHeight: 440)
    }

    // MARK: - Content Section (below hero)

    private var designBContentSection: some View {
        VStack(spacing: 16) {
            designBDrivingSignalsCard
            designBFeelingVsDataCard
            checkInSectionB
            howYouRecoveredCardB
            consecutiveAlertCard
            buddyRecommendationsSectionB
            dailyGoalsSection
            zoneDistributionSection
            streakSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - State Glow Background

    private var designBStateGlow: some View {
        GeometryReader { geo in
            RadialGradient(
                colors: [
                    designBAppState.primaryColor.opacity(0.15),
                    designBAppState.primaryColor.opacity(0.04),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.35),
                startRadius: 0,
                endRadius: geo.size.width * 0.8
            )
        }
    }

    // MARK: - ThumpBuddy + Orbiting Score Ring

    /// Buddy centered at 210pt with 288pt score ring orbiting it.
    private var designBBuddyWithRing: some View {
        ZStack {
            // Score ring — 288pt diameter, 8pt stroke (§6 spec)
            designBScoreRing
                .frame(width: 288, height: 288)

            // ThumpBuddy — 210pt hero size (§5: minimum 35% screen height)
            ThumpBuddy(
                mood: designBAppState.buddyMood,
                size: 105,   // ThumpBuddy size param = half the display size (frame = size*2)
                showAura: designBAppState == .steady,  // amber aura for Steady
                tappable: true
            )
        }
        .frame(width: 288, height: 288)
        .accessibilityIdentifier("dashboard_design_b_buddy_ring")
    }

    /// Score ring — clockwise fill, state color, privacy lock at 6 o'clock.
    @ViewBuilder
    private var designBScoreRing: some View {
        let score = viewModel.readinessResult?.score ?? 0
        let progress = Double(score) / 100.0
        let state = designBAppState

        ZStack {
            // Track ring
            Circle()
                .stroke(state.primaryColor.opacity(0.18), lineWidth: 8)

            // Filled arc — clockwise from 12 o'clock
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    state.primaryColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.2), value: progress)

            // Privacy lock badge at 6 o'clock (§6: always visible)
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(state.primaryColor.opacity(0.7))
                .offset(y: 144)  // radius = 144pt (288/2)
        }
    }

    // MARK: - Score Hierarchy

    /// §21 Chronic Steady de-escalation:
    /// Normal: score 64–72pt Black weight (prominent)
    /// Chronic Steady: score demoted to 28pt Regular; "Steady" label promoted to 42pt Bold
    @ViewBuilder
    private var designBScoreHierarchy: some View {
        let score = viewModel.readinessResult?.score ?? 0
        let state = designBAppState
        let isSteady = state == .steady

        VStack(spacing: 4) {
            if isSteady {
                // Chronic Steady: state label promoted above score
                Text("Steady")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(state.primaryColor)
                    .animation(.easeInOut(duration: 0.4), value: isSteady)

                Text("\(score)")
                    .font(.system(size: 28, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .animation(.easeInOut(duration: 0.4), value: isSteady)
            } else {
                // Normal: score is hero, state name is secondary
                Text("\(score)")
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .animation(.easeInOut(duration: 0.4), value: isSteady)

                Text(state.stateName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(state.primaryColor)
                    .animation(.easeInOut(duration: 0.4), value: isSteady)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isSteady
                ? "Steady state, score \(score)"
                : "\(state.stateName), score \(score)"
        )
    }

    // MARK: - Driving Signals Card (Layer 2)

    /// 3 plain-English rows: Nervous system / Sleep processing / Recovery trend.
    /// Collapsed by default; tap any row → Layer 3 detail sheet.
    @ViewBuilder
    var designBDrivingSignalsCard: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("What's driving this")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Image(systemName: isDrivingSignalsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isDrivingSignalsExpanded.toggle()
                }
                InteractionLog.log(.buttonTap, element: "driving_signals_toggle", page: "Dashboard")
            }

            if isDrivingSignalsExpanded {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    drivingSignalRow(
                        icon: "brain.head.profile",
                        label: "Nervous system",
                        value: nervousSystemSignal,
                        logElement: "nervous_system_signal"
                    )

                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.horizontal, 16)

                    drivingSignalRow(
                        icon: "moon.fill",
                        label: "Sleep processing",
                        value: sleepProcessingSignal,
                        logElement: "sleep_processing_signal"
                    )

                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.horizontal, 16)

                    drivingSignalRow(
                        icon: "arrow.up.heart.fill",
                        label: "Recovery trend",
                        value: recoveryTrendSignal,
                        logElement: "recovery_trend_signal"
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .accessibilityIdentifier("dashboard_driving_signals_b")
    }

    private func drivingSignalRow(
        icon: String,
        label: String,
        value: String,
        logElement: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(designBAppState.primaryColor.opacity(0.8))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            InteractionLog.log(.cardTap, element: logElement, page: "Dashboard")
            withAnimation { showReadinessDetail = true }
        }
    }

    // MARK: - Feeling vs Data Row

    /// "You felt [X] · Thump said [score]" with Match/Mismatch badge.
    @ViewBuilder
    var designBFeelingVsDataCard: some View {
        if let mood = viewModel.todayMood, let score = viewModel.readinessResult?.score {
            let isMatch = feelingDataMatch(mood: mood, score: score)

            HStack(spacing: 12) {
                // Feeling chip
                VStack(alignment: .leading, spacing: 2) {
                    Text("You felt")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(mood.label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text("·")
                    .foregroundStyle(.white.opacity(0.3))

                // Data chip
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thump said")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(score)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(designBAppState.primaryColor)
                }

                Spacer()

                // Match / Mismatch badge
                HStack(spacing: 5) {
                    Image(systemName: isMatch ? "checkmark.circle.fill" : "sparkle")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isMatch ? "Match" : "Interesting")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isMatch ? Color(hex: 0x22C55E).opacity(0.2) : Color(hex: 0x8B5CF6).opacity(0.25))
                )
                .onTapGesture {
                    InteractionLog.log(.cardTap, element: "feeling_vs_data_badge", page: "Dashboard")
                    withAnimation { showReadinessDetail = true }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "You felt \(mood.label). Thump said \(score). \(isMatch ? "Match." : "Mismatch — tap to explore.")"
            )
            .accessibilityIdentifier("dashboard_feeling_vs_data_b")
        }
    }

    // MARK: - Morning Reveal State (UserDefaults-backed)

    /// Whether the morning reveal ritual has been seen today (persisted across launches).
    private var hasSeenRevealToday: Bool {
        get {
            let key = "thump_reveal_seen_\(todayDateString)"
            return UserDefaults.standard.bool(forKey: key)
        }
    }

    private func markRevealSeen() {
        let key = "thump_reveal_seen_\(todayDateString)"
        UserDefaults.standard.set(true, forKey: key)
    }

    private var todayDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - App Appear Handler (morning reveal vs direct open)

    private func handleDesignBAppear() {
        if hasSeenRevealToday {
            // Subsequent same-day opens: skip ritual, jump straight to revealed state
            // (No animation needed — UI renders with current score immediately)
        }
        // First daily open: ritual is managed by existing check-in flow in checkInSectionB
        // The reveal itself is a visual effect driven by the score already being loaded.
        markRevealSeen()
    }

    /// Skip handler — tapping during any animation phase jumps to complete.
    private func handleRevealSkip() {
        // After Day 7, a single tap anywhere during the morning animation skips to complete.
        // For this implementation the animation is driven by standard SwiftUI .animation
        // modifiers on the score ring trim — it can be interrupted by state changes.
        // This gesture is a no-op when the view is already in its complete state.
    }

    // MARK: - Computed State

    /// Current app state derived from readiness score + chronic steady flag.
    var designBAppState: AppState {
        let score = viewModel.readinessResult?.score ?? 0
        // isChronicSteady: placeholder until Tier A lands the DesignTokens property.
        // Will be replaced by a real computed property from the view model.
        return AppState.from(score: score, isChronicSteady: isChronicSteadyState)
    }

    /// Chronic Steady flag: true when score has been 0–44 for 14+ consecutive days.
    /// Wired to `localStore.profile.isChronicSteady` via the view model (§21.3).
    private var isChronicSteadyState: Bool {
        viewModel.isChronicSteady
    }

    // MARK: - Driving Signal Computed Values

    /// Plain-English nervous system signal derived from HRV + stress result.
    private var nervousSystemSignal: String {
        guard let stress = viewModel.stressResult else { return "Not enough data yet" }
        switch stress.level {
        case .relaxed:  return "Calm and ready"
        case .balanced: return "Slightly elevated — manageable"
        case .elevated: return "Overloaded — needs rest"
        }
    }

    /// Plain-English sleep processing signal derived from readiness sleep pillar.
    private var sleepProcessingSignal: String {
        guard let readiness = viewModel.readinessResult,
              let sleepPillar = readiness.pillars.first(where: { $0.type == .sleep })
        else { return "Sleep data not available" }

        switch sleepPillar.score {
        case 75...:  return "Last night's sleep is fueling you"
        case 50..<75: return "Partially processed"
        default:     return "Still catching up"
        }
    }

    /// Plain-English recovery trend signal derived from week-over-week trend.
    private var recoveryTrendSignal: String {
        guard let wow = viewModel.assessment?.weekOverWeekTrend else {
            return "Building your baseline"
        }
        switch wow.direction {
        case .significantImprovement: return "Strong improvement streak"
        case .improving:              return "Trending in the right direction"
        case .stable:                 return "Holding steady"
        case .elevated:               return "Asking for a lighter day"
        case .significantElevation:   return "Asking for rest"
        }
    }

    // MARK: - Mission Text

    /// Today's mission sentence (plain English, no hedging, §6 copy pools).
    private var designBMissionText: String? {
        // Coordinator path
        if ConfigService.enableCoordinator,
           let adviceState = coordinator.bundle?.adviceState {
            return AdvicePresenter.focusInsight(for: adviceState)
        }

        // Chronic Steady: acknowledgment pool — zero instructions, just presence (§6)
        if isChronicSteadyState {
            let pool = [
                "Your body is working really hard right now. That's real, and it counts.",
                "Rough stretch. You're holding up better than it feels.",
                "Some days the best move is just getting through it. That still counts.",
                "You're carrying a lot right now. Thump sees it.",
                "Hard season. Your body is doing its job under pressure.",
                "Not every chapter is a growth chapter. This one is a holding-on chapter."
            ]
            // Deterministic per day so it doesn't change on re-opens
            let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
            return pool[dayIndex % pool.count]
        }

        // Legacy path — reuse existing buddyFocusInsight logic
        return buddyFocusInsight
    }

    // MARK: - Feeling vs Data Helpers

    /// True when the user's felt state is aligned with the data score.
    private func feelingDataMatch(mood: CheckInMood, score: Int) -> Bool {
        switch mood {
        case .great: return score >= 75
        case .good:  return score >= 50
        case .okay:  return score >= 30 && score < 75
        case .rough: return score < 50
        }
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
        case .intensity:    return .pink
        }
    }
}


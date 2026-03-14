// DashboardView.swift
// Thump iOS
//
// The primary dashboard screen — your daily wellness companion.
// ThumpBuddy greets you at the top with a mood-aware personality,
// followed by your single biggest insight, readiness score, bio age,
// metric tiles, coaching nudges, check-in, and streak.
//
// Design philosophy: warm, modern, emotionally engaging — like opening
// a favorite app that genuinely cares about you. Inspired by Oura's
// single-focus clarity, Duolingo's emotional bonds, and Finch's warmth.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {

    // MARK: - Tab Navigation

    /// Binding to the parent tab selection for cross-tab navigation.
    @Binding var selectedTab: Int

    @EnvironmentObject private var connectivityService: ConnectivityService
    @EnvironmentObject private var healthKitService: HealthKitService
    @EnvironmentObject var localStore: LocalStore
    @EnvironmentObject private var notificationService: NotificationService

    // MARK: - View Model

    @StateObject var viewModel = DashboardViewModel()
    // MARK: - Sheet State

    /// Controls the Bio Age detail sheet presentation.
    @State private var showBioAgeDetail = false

    // MARK: - Grid Layout

    private let metricColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            contentView
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .task {
                    viewModel.bind(
                        healthDataProvider: healthKitService,
                        localStore: localStore,
                        notificationService: notificationService
                    )
                    await viewModel.refresh()
                }
                .onChange(of: viewModel.assessment) { _, newAssessment in
                    guard let newAssessment else { return }
                    connectivityService.sendAssessment(newAssessment)
                }
                .refreshable {
                    InteractionLog.log(.pullToRefresh, element: "dashboard_refresh", page: "Dashboard")
                    await viewModel.refresh()
                }
                .onAppear {
                    InteractionLog.pageView("Dashboard")
                }
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.assessment == nil {
            loadingView
        } else if let error = viewModel.errorMessage {
            errorView(message: error)
        } else {
            dashboardScrollView
        }
    }

    // MARK: - Dashboard Content

    private var dashboardScrollView: some View {
        ZStack(alignment: .top) {
            // Layer 1: Extend the hero gradient into the safe area
            heroGradient
                .frame(height: 380)
                .ignoresSafeArea(edges: .top)

            // Layer 2: Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero: Buddy + Greeting + One Focus Insight
                    buddyHeroSection

                    // Main content cards
                    VStack(alignment: .leading, spacing: 16) {
                        checkInSection               // 1. Daily check-in right after hero
                        readinessSection              // 2. Thump Check (readiness)
                        howYouRecoveredCard           // 3. How You Recovered (replaces Weekly RHR)
                        consecutiveAlertCard          // 4. Alert if elevated
                        dailyGoalsSection             // 5. Daily Goals (engine-driven)
                        buddyRecommendationsSection   // 6. Buddy Recommendations
                        zoneDistributionSection       // 7. Heart Rate Zones (dynamic targets)
                        buddyCoachSection             // 8. Buddy Coach (was "Your Heart Coach")
                        streakSection                 // 9. Streak
                        // metricsSection — moved to Trends tab
                        // bioAgeSection — parked (see FEATURE_REQUESTS.md FR-001)
                        // nudgeSection — replaced by buddyRecommendationsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
        .accessibilityIdentifier("dashboard_scroll_view")
    }

    // MARK: - Buddy Hero Section

    private var buddyMood: BuddyMood {
        guard let assessment = viewModel.assessment else { return .content }
        return BuddyMood.from(assessment: assessment)
    }

    private var buddyHeroSection: some View {
        ZStack {
            // Animated gradient background (safe area handled by parent ZStack)
            heroGradient

            VStack(spacing: 8) {
                Spacer()
                    .frame(height: 16)

                // ThumpBuddy — the emotional anchor
                ThumpBuddy(mood: buddyMood, size: 100, tappable: true)
                    .padding(.top, 8)

                // Mood pill label
                HStack(spacing: 5) {
                    Image(systemName: buddyMood.badgeIcon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(buddyMood.label)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(buddyMood.labelColor.opacity(0.85))
                        .shadow(color: buddyMood.labelColor.opacity(0.3), radius: 4, y: 2)
                )

                // Greeting
                Text(greetingText)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))

                // One-line focus insight
                if let insight = buddyFocusInsight {
                    Text(insight)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                }

                Spacer()
                    .frame(height: 20)
            }
        }
        .frame(height: 320)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 28,
            bottomTrailingRadius: 28,
            topTrailingRadius: 0
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greetingText). Buddy is feeling \(buddyMood.label). \(buddyFocusInsight ?? "")")
    }

    /// Warm gradient that shifts with buddy mood.
    private var heroGradient: some View {
        let colors: [Color] = switch buddyMood {
        case .thriving:    [Color(hex: 0x059669), Color(hex: 0x10B981), Color(hex: 0x34D399)]
        case .content:     [Color(hex: 0x2563EB), Color(hex: 0x3B82F6), Color(hex: 0x60A5FA)]
        case .nudging:     [Color(hex: 0xD97706), Color(hex: 0xF59E0B), Color(hex: 0xFBBF24)]
        case .stressed:    [Color(hex: 0xEA580C), Color(hex: 0xF97316), Color(hex: 0xFB923C)]
        case .tired:       [Color(hex: 0x7C3AED), Color(hex: 0x8B5CF6), Color(hex: 0xA78BFA)]
        case .celebrating: [Color(hex: 0xB45309), Color(hex: 0xF59E0B), Color(hex: 0xFDE68A)]
        case .active:      [Color(hex: 0xDC2626), Color(hex: 0xEF4444), Color(hex: 0xFCA5A5)]
        case .conquering:  [Color(hex: 0xB45309), Color(hex: 0xEAB308), Color(hex: 0xFDE68A)]
        }
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 0.8), value: buddyMood)
    }

    /// Synthesizes ALL engine outputs into one human-readable sentence.
    /// Pulls from: readiness, stress, zones, recovery, assessment status.
    private var buddyFocusInsight: String? {
        guard let assessment = viewModel.assessment else { return nil }

        // Priority 1: High stress overrides everything
        if assessment.stressFlag, let stress = viewModel.stressResult, stress.level == .elevated {
            return "Stress is running high. A rest day would do you good."
        }

        // Priority 2: Poor recovery — body needs a break
        if let readiness = viewModel.readinessResult, readiness.score < 45 {
            let sleepPillar = readiness.pillars.first(where: { $0.type == .sleep })
            if let sleep = sleepPillar, sleep.score < 50 {
                return "Rough night. Take it easy — your body needs to catch up."
            }
            return "Recovery is low. A light day will help you bounce back."
        }

        // Priority 3: Good recovery + recent hard effort — earned rest
        if let readiness = viewModel.readinessResult, readiness.score < 65,
           let zones = viewModel.zoneAnalysis,
           zones.recommendation == .tooMuchIntensity {
            return "You pushed hard recently. A mellow day helps you absorb those gains."
        }

        // Priority 4: Well recovered and ready to go
        if let readiness = viewModel.readinessResult, readiness.score >= 75 {
            if assessment.stressFlag == false,
               let stress = viewModel.stressResult, stress.level == .relaxed {
                return "You recovered well. Ready for a solid day."
            }
            return "Body is charged up. Good day to move."
        }

        // Priority 5: Moderate readiness — keep it balanced
        if let readiness = viewModel.readinessResult, readiness.score >= 45 {
            return "Decent recovery. A moderate effort works well today."
        }

        // Fallback: general status-based
        if assessment.status == .needsAttention {
            return "Your body is asking for a lighter day."
        }
        return "Checking in on your wellness."
    }

    // MARK: - Greeting

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 0..<12:  greeting = "Good morning"
        case 12..<17: greeting = "Good afternoon"
        default:       greeting = "Good evening"
        }
        let name = viewModel.profileName
        return name.isEmpty ? greeting : "\(greeting), \(name)"
    }

    private var formattedDate: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    // MARK: - Bio Age Section

    @ViewBuilder
    private var bioAgeSection: some View {
        if let result = viewModel.bioAgeResult {
            Button {
                InteractionLog.log(.cardTap, element: "bio_age_card", page: "Dashboard")
                InteractionLog.log(.sheetOpen, element: "bio_age_detail_sheet", page: "Dashboard")
                showBioAgeDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Label("Bio Age", systemImage: "heart.text.square.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        HStack(spacing: 4) {
                            Text("\(result.metricsUsed) of 6 metrics")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    HStack(spacing: 16) {
                        // Bio Age number
                        VStack(spacing: 4) {
                            Text("\(result.bioAge)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(bioAgeColor(for: result.category))

                            Text("Bio Age")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 90)

                        VStack(alignment: .leading, spacing: 8) {
                            // Difference badge
                            HStack(spacing: 6) {
                                Image(systemName: result.category.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(bioAgeColor(for: result.category))

                                if result.difference < 0 {
                                    Text("\(abs(result.difference)) years younger")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(bioAgeColor(for: result.category))
                                } else if result.difference > 0 {
                                    Text("\(result.difference) years older")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(bioAgeColor(for: result.category))
                                } else {
                                    Text("Right on track")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(bioAgeColor(for: result.category))
                                }
                            }

                            Text(result.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            // Mini metric badges
                            HStack(spacing: 6) {
                                ForEach(result.breakdown, id: \.metric) { contribution in
                                    bioAgeMetricBadge(contribution)
                                }
                            }
                        }
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
                            bioAgeColor(for: result.category).opacity(0.15),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Bio Age \(result.bioAge). \(result.explanation). Double tap for details."
            )
            .accessibilityHint("Opens Bio Age details")
            .sheet(isPresented: $showBioAgeDetail) {
                BioAgeDetailSheet(result: result)
            }
        } else if viewModel.todaySnapshot != nil {
            bioAgeSetupPrompt
        }
    }

    private func bioAgeMetricBadge(
        _ contribution: BioAgeMetricContribution
    ) -> some View {
        let color: Color = switch contribution.direction {
        case .younger: Color(hex: 0x22C55E)
        case .onTrack: Color(hex: 0x3B82F6)
        case .older: Color(hex: 0xF59E0B)
        }

        return HStack(spacing: 3) {
            Image(systemName: contribution.metric.icon)
                .font(.system(size: 8))
            Image(systemName: directionArrow(for: contribution.direction))
                .font(.system(size: 7))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
        .accessibilityLabel(
            "\(contribution.metric.displayName): \(contribution.direction.rawValue)"
        )
    }

    private func directionArrow(for direction: BioAgeDirection) -> String {
        switch direction {
        case .younger: return "arrow.down"
        case .onTrack: return "equal"
        case .older:   return "arrow.up"
        }
    }

    private func bioAgeColor(for category: BioAgeCategory) -> Color {
        switch category {
        case .excellent:  return Color(hex: 0x22C55E)
        case .good:       return Color(hex: 0x0D9488)
        case .onTrack:    return Color(hex: 0x3B82F6)
        case .watchful:   return Color(hex: 0xF59E0B)
        case .needsWork:  return Color(hex: 0xEF4444)
        }
    }

    /// Whether the inline DOB picker is shown on the dashboard.
    @State private var showBioAgeDatePicker = false

    /// Prompt to set date of birth for bio age calculation.
    private var bioAgeSetupPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: 0x8B5CF6))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Your Bio Age")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Enter your date of birth to see how your body compares to your calendar age.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            if showBioAgeDatePicker {
                DatePicker(
                    "Date of Birth",
                    selection: Binding(
                        get: {
                            localStore.profile.dateOfBirth ?? Calendar.current.date(
                                byAdding: .year, value: -30, to: Date()
                            ) ?? Date()
                        },
                        set: { newDate in
                            localStore.profile.dateOfBirth = newDate
                            localStore.saveProfile()
                        }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()

                Button {
                    InteractionLog.log(.buttonTap, element: "bio_age_calculate", page: "Dashboard")
                    if localStore.profile.dateOfBirth == nil {
                        localStore.profile.dateOfBirth = Calendar.current.date(
                            byAdding: .year, value: -30, to: Date()
                        )
                        localStore.saveProfile()
                    }
                    Task { await viewModel.refresh() }
                } label: {
                    Text("Calculate My Bio Age")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(
                            Color(hex: 0x8B5CF6),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    InteractionLog.log(.buttonTap, element: "bio_age_set_dob", page: "Dashboard")
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showBioAgeDatePicker = true
                    }
                } label: {
                    Text("Set Date of Birth")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color(hex: 0x8B5CF6))
                        .background(
                            Color(hex: 0x8B5CF6).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: 0x8B5CF6).opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color(hex: 0x8B5CF6).opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set your date of birth to unlock Bio Age")
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        if let assessment = viewModel.assessment {
            StatusCardView(
                status: assessment.status,
                confidence: assessment.confidence,
                cardioScore: assessment.cardioScore,
                explanation: assessment.explanation
            )
        }
    }

    // MARK: - Metrics Grid

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's Metrics", systemImage: "heart.text.square")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    InteractionLog.log(.buttonTap, element: "see_trends", page: "Dashboard")
                    withAnimation { selectedTab = 3 }
                } label: {
                    HStack(spacing: 4) {
                        Text("See Trends")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .accessibilityLabel("See all trends")
            }

            LazyVGrid(columns: metricColumns, spacing: 12) {
                metricTileButton(label: "Resting Heart Rate", value: viewModel.todaySnapshot?.restingHeartRate, unit: "bpm")
                metricTileButton(label: "HRV", value: viewModel.todaySnapshot?.hrvSDNN, unit: "ms")
                metricTileButton(label: "Recovery", value: viewModel.todaySnapshot?.recoveryHR1m, unit: "bpm")
                metricTileButton(label: "Cardio Fitness", value: viewModel.todaySnapshot?.vo2Max, unit: "mL/kg/min", decimals: 1)
                metricTileButton(label: "Active Minutes", value: activeMinutesValue, unit: "min")
                metricTileButton(label: "Sleep", value: viewModel.todaySnapshot?.sleepHours, unit: "hrs", decimals: 1)
                metricTileButton(label: "Weight", value: viewModel.todaySnapshot?.bodyMassKg, unit: "kg", decimals: 1)
            }
        }
    }

    /// Combined active minutes or nil if no data.
    private var activeMinutesValue: Double? {
        let walkMin = viewModel.todaySnapshot?.walkMinutes ?? 0
        let workoutMin = viewModel.todaySnapshot?.workoutMinutes ?? 0
        let total = walkMin + workoutMin
        return total > 0 ? total : nil
    }

    /// A tappable metric tile that navigates to the Trends tab.
    private func metricTileButton(label: String, value: Double?, unit: String, decimals: Int = 0) -> some View {
        Button {
            InteractionLog.log(.cardTap, element: "metric_tile_\(label.lowercased().replacingOccurrences(of: " ", with: "_"))", page: "Dashboard")
            withAnimation { selectedTab = 3 }
        } label: {
            MetricTileView(
                label: label,
                optionalValue: value,
                unit: unit,
                decimals: decimals,
                trend: nil,
                confidence: nil,
                isLocked: false
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double tap to view trends")
    }

    // MARK: - Buddy Suggestions

    @ViewBuilder
    private var nudgeSection: some View {
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
                    .buttonStyle(.plain)
                    .accessibilityHint("Double tap to view details")
                }
            }
        }
    }

    // MARK: - Check-In Section

    @ViewBuilder
    private var checkInSection: some View {
        if !viewModel.hasCheckedInToday {
            // Only show when user hasn't checked in yet — disappears after tap
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

                HStack(spacing: 10) {
                    ForEach(CheckInMood.allCases, id: \.self) { mood in
                        Button {
                            InteractionLog.log(.buttonTap, element: "checkin_\(mood.label.lowercased())", page: "Dashboard")
                            withAnimation(.spring(response: 0.4)) {
                                viewModel.submitCheckIn(mood: mood)
                            }
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
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityIdentifier("dashboard_checkin")
        }
    }

    private func moodIcon(for mood: CheckInMood) -> String {
        switch mood {
        case .great: return "sun.max.fill"
        case .good:  return "cloud.sun.fill"
        case .okay:  return "cloud.fill"
        case .rough: return "cloud.rain.fill"
        }
    }

    private func moodColor(for mood: CheckInMood) -> Color {
        switch mood {
        case .great: return Color(hex: 0x22C55E)
        case .good:  return Color(hex: 0x0D9488)
        case .okay:  return Color(hex: 0xF59E0B)
        case .rough: return Color(hex: 0x8B5CF6)
        }
    }

    // MARK: - Zone Distribution (Dynamic Targets)

    private let zoneColors: [Color] = [
        Color(hex: 0x94A3B8), // Zone 1 - Easy (gray-blue)
        Color(hex: 0x22C55E), // Zone 2 - Fat Burn (green)
        Color(hex: 0x3B82F6), // Zone 3 - Cardio (blue)
        Color(hex: 0xF59E0B), // Zone 4 - Threshold (amber)
        Color(hex: 0xEF4444)  // Zone 5 - Peak (red)
    ]
    private let zoneNames = ["Easy", "Fat Burn", "Cardio", "Threshold", "Peak"]

    @ViewBuilder
    private var zoneDistributionSection: some View {
        if let zoneAnalysis = viewModel.zoneAnalysis,
           let snapshot = viewModel.todaySnapshot {
            let pillars = zoneAnalysis.pillars
            let totalMin = snapshot.zoneMinutes.reduce(0, +)
            let metCount = pillars.filter { $0.completion >= 1.0 }.count

            VStack(alignment: .leading, spacing: 14) {
                // Header with targets-met counter
                HStack {
                    Label("Heart Rate Zones", systemImage: "chart.bar.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(metCount)/\(pillars.count) targets")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                        if metCount == pillars.count && !pillars.isEmpty {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: 0xF59E0B))
                        }
                    }
                    .foregroundStyle(metCount == pillars.count && !pillars.isEmpty
                                     ? Color(hex: 0x22C55E) : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            metCount == pillars.count && !pillars.isEmpty
                                ? Color(hex: 0x22C55E).opacity(0.12)
                                : Color(.systemGray5)
                        )
                    )
                }

                // Per-zone rows with progress bars
                ForEach(Array(pillars.enumerated()), id: \.offset) { index, pillar in
                    let color = index < zoneColors.count ? zoneColors[index] : .gray
                    let name = index < zoneNames.count ? zoneNames[index] : "Zone \(index + 1)"
                    let met = pillar.completion >= 1.0
                    let progress = min(pillar.completion, 1.0)

                    VStack(spacing: 6) {
                        HStack {
                            // Zone name + icon
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 8, height: 8)
                                Text(name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            // Actual / Target
                            HStack(spacing: 2) {
                                Text("\(Int(pillar.actualMinutes))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(met ? color : .primary)
                                Text("/")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text("\(Int(pillar.targetMinutes)) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Checkmark or remaining
                            if met {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(color)
                            }
                        }

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color.opacity(0.12))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color)
                                    .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .accessibilityLabel(
                        "\(name): \(Int(pillar.actualMinutes)) of \(Int(pillar.targetMinutes)) minutes\(met ? ", target met" : "")"
                    )
                }

                // Coaching nudge per zone (show the most important one)
                if let rec = zoneAnalysis.recommendation {
                    HStack(spacing: 6) {
                        Image(systemName: rec.icon)
                            .font(.caption)
                            .foregroundStyle(rec == .perfectBalance ? Color(hex: 0x22C55E) : Color(hex: 0x3B82F6))
                        Text(zoneCoachingNudge(rec, pillars: pillars))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill((rec == .perfectBalance ? Color(hex: 0x22C55E) : Color(hex: 0x3B82F6)).opacity(0.06))
                    )
                }

                // Weekly activity target (AHA 150 min guideline)
                let moderateMin = snapshot.zoneMinutes.count >= 4 ? snapshot.zoneMinutes[2] + snapshot.zoneMinutes[3] : 0
                let vigorousMin = snapshot.zoneMinutes.count >= 5 ? snapshot.zoneMinutes[4] : 0
                let weeklyEstimate = (moderateMin + vigorousMin * 2) * 7
                let ahaPercent = min(weeklyEstimate / 150.0 * 100, 100)
                HStack(spacing: 6) {
                    Image(systemName: ahaPercent >= 100 ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.caption)
                        .foregroundStyle(ahaPercent >= 100 ? Color(hex: 0x22C55E) : Color(hex: 0xF59E0B))
                    Text(ahaPercent >= 100
                         ? "On pace for 150 min weekly activity goal"
                         : "\(Int(max(0, 150 - weeklyEstimate))) min to your weekly activity target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .accessibilityIdentifier("dashboard_zone_card")
        }
    }

    /// Context-aware coaching nudge based on zone recommendation.
    private func zoneCoachingNudge(_ rec: ZoneRecommendation, pillars: [ZonePillar]) -> String {
        switch rec {
        case .perfectBalance:
            return "Great balance today! You're hitting all zone targets."
        case .needsMoreActivity:
            return "A 15-minute walk gets you into your fat-burn and cardio zones."
        case .needsMoreAerobic:
            let cardio = pillars.first { $0.zone == .aerobic }
            let remaining = Int(max(0, (cardio?.targetMinutes ?? 22) - (cardio?.actualMinutes ?? 0)))
            return "\(remaining) more min of cardio (brisk walk or jog) to hit your target."
        case .needsMoreThreshold:
            let threshold = pillars.first { $0.zone == .threshold }
            let remaining = Int(max(0, (threshold?.targetMinutes ?? 7) - (threshold?.actualMinutes ?? 0)))
            return "\(remaining) more min of tempo effort to reach your threshold target."
        case .tooMuchIntensity:
            return "You've pushed hard. Try easy zone only for the rest of today."
        }
    }

    // MARK: - Buddy Recommendations Section

    /// Engine-driven actionable advice cards below Daily Goals.
    /// Pulls from readiness, stress, zones, coaching, and recovery to give
    /// specific, human-readable recommendations.
    @ViewBuilder
    private var buddyRecommendationsSection: some View {
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
                    .buttonStyle(.plain)
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

    private func buddyRecIcon(_ rec: BuddyRecommendation) -> String {
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

    private func buddyRecColor(_ rec: BuddyRecommendation) -> Color {
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

    // MARK: - Buddy Coach (was "Your Heart Coach")

    @ViewBuilder
    private var buddyCoachSection: some View {
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
    private var streakSection: some View {
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

    private var loadingView: some View {
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

    private func errorView(message: String) -> some View {
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

// MARK: - Preview

#Preview("Dashboard - Loaded") {
    DashboardView(selectedTab: .constant(0))
}

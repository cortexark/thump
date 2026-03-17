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
    @EnvironmentObject var coordinator: DailyEngineCoordinator

    // MARK: - View Model

    @StateObject var viewModel = DashboardViewModel()

    /// A/B design variant toggle.
    @AppStorage("thump_design_variant_b") private var useDesignB: Bool = false

    // MARK: - Sheet State

    /// Controls the Bio Age detail sheet presentation.
    @State private var showBioAgeDetail = false

    /// Controls the Readiness detail sheet presentation.
    @State var showReadinessDetail = false

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
                    #if targetEnvironment(simulator) && DEBUG
                    // Simulator: use MockHealthDataProvider loaded with real Apple Watch
                    // export data. We can't write RHR/VO2/exercise time to HealthKit
                    // (Apple-computed read-only types), so mock is the only way to get
                    // all metrics on simulator.
                    let provider: any HealthDataProviding = RealUserDataLoader.makeProvider(days: 74)
                    #else
                    let provider: any HealthDataProviding = healthKitService
                    #endif
                    viewModel.bind(
                        healthDataProvider: provider,
                        localStore: localStore,
                        notificationService: notificationService,
                        coordinator: coordinator
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
                        if useDesignB {
                            designBCardStack
                        } else {
                            checkInSection               // 1. Daily check-in right after hero
                            readinessSection              // 2. Thump Check (readiness)
                            howYouRecoveredCard           // 3. How You Recovered (replaces Weekly RHR)
                            consecutiveAlertCard          // 4. Alert if elevated
                            dailyGoalsSection             // 5. Daily Goals (engine-driven)
                            buddyRecommendationsSection   // 6. Buddy Recommendations
                            zoneDistributionSection       // 7. Heart Rate Zones (dynamic targets)
                            buddyCoachSection             // 8. Buddy Coach (was "Your Heart Coach")
                            streakSection                 // 9. Streak
                        }
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
    /// When coordinator is active, delegates to AdvicePresenter.
    private var buddyFocusInsight: String? {
        // Coordinator path: use AdvicePresenter
        if ConfigService.enableCoordinator,
           let adviceState = coordinator.bundle?.adviceState {
            return AdvicePresenter.focusInsight(for: adviceState)
        }

        // Legacy path
        guard let assessment = viewModel.assessment else { return nil }

        if assessment.stressFlag, let stress = viewModel.stressResult, stress.level == .elevated {
            return "Stress is running high. A rest day would do you good."
        }
        if let readiness = viewModel.readinessResult, readiness.score < 45 {
            let sleepPillar = readiness.pillars.first(where: { $0.type == .sleep })
            if let sleep = sleepPillar, sleep.score < 50 {
                return "Rough night. Take it easy — your body needs to catch up."
            }
            return "Recovery is low. A light day will help you bounce back."
        }
        if let readiness = viewModel.readinessResult, readiness.score < 65,
           let zones = viewModel.zoneAnalysis,
           zones.recommendation == .tooMuchIntensity {
            return "You pushed hard recently. A mellow day helps you absorb those gains."
        }
        if let readiness = viewModel.readinessResult, readiness.score >= 75 {
            if assessment.stressFlag == false,
               let stress = viewModel.stressResult, stress.level == .relaxed {
                return "You recovered well. Ready for a solid day."
            }
            return "Body is charged up. Good day to move."
        }
        if let readiness = viewModel.readinessResult, readiness.score >= 45 {
            return "Decent recovery. A moderate effort works well today."
        }
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

                            Text("Wellness estimate based on your recent trends — not a medical assessment")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

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
        .buttonStyle(CardButtonStyle())
        .accessibilityHint("Double tap to view trends")
    }
}

/// Button style that adds a subtle press effect for card-like buttons.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Dashboard - Loaded") {
    DashboardView(selectedTab: .constant(0))
}

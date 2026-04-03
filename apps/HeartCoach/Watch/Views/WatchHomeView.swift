// WatchHomeView.swift
// Thump Watch
//
// Hero-first watch face:
//   • Screen 1 (home): Cardio score dominates — that IS the goal
//   • Buddy icon sits below, face reflects current statew
//   • Single tap on buddy navigates to today's improvement plan
//   • All crowding eliminated — one number, one character, one action
//
// Buddy face logic:
//   idle        → nudging (ready to go)
//   tapped Start → active (pushing face, effort motion)
//   goal done   → conquering (flag raised, huge grin)
//   stress high → stressed
//   needs rest  → tired
//   score ≥ 70  → thriving
//
// Platforms: watchOS 10+

import SwiftUI

// MARK: - Watch Home View

struct WatchHomeView: View {

    // MARK: - Environment

    @EnvironmentObject var connectivityService: WatchConnectivityService
    @EnvironmentObject var viewModel: WatchViewModel

    // MARK: - State

    @State private var showBreathOverlay = false
    @State private var appearAnimation = false
    @State private var activityInProgress = false
    @State private var pulseScore = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if let assessment = viewModel.latestAssessment {
                    heroScreen(assessment)
                } else {
                    syncingPlaceholder
                }

                if showBreathOverlay, let prompt = connectivityService.breathPrompt {
                    breathOverlay(prompt)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(10)
                }
            }
        }
        .onChange(of: connectivityService.breathPrompt) { _, newPrompt in
            if newPrompt != nil {
                withAnimation(.spring(duration: 0.5)) { showBreathOverlay = true }
            }
        }
    }

    // MARK: - Hero Screen

    @ViewBuilder
    private func heroScreen(_ assessment: HeartAssessment) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 2)

            // ── Cardio Score: the entire goal in one number ──
            cardioScoreHero(assessment)
                .opacity(appearAnimation ? 1 : 0)
                .scaleEffect(appearAnimation ? 1 : 0.85)

            Spacer(minLength: 6)

            // ── Buddy: emotional mirror + primary nav anchor ──
            NavigationLink(destination: WatchInsightFlowView()) {
                buddyWithLabel(assessment)
            }
            .buttonStyle(.plain)
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 6)

            Spacer(minLength: 6)

            // ── Single action if nudge not complete ──
            if !viewModel.nudgeCompleted {
                nudgePill(assessment.dailyNudge)
                    .opacity(appearAnimation ? 1 : 0)
            }

            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.08)) {
                appearAnimation = true
            }
            // Pulse score number once on appear
            withAnimation(.easeInOut(duration: 0.3).delay(0.5)) { pulseScore = true }
            withAnimation(.easeInOut(duration: 0.3).delay(0.85)) { pulseScore = false }
        }
    }

    // MARK: - Cardio Score Hero

    @ViewBuilder
    private func cardioScoreHero(_ assessment: HeartAssessment) -> some View {
        VStack(spacing: 3) {
            if let score = assessment.cardioScore {
                VStack(spacing: 1) {
                    Text("\(Int(score))")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor(score))
                        .scaleEffect(pulseScore ? 1.05 : 1.0)
                        .contentTransition(.numericText())

                    // Plain-English meaning of the number — so user knows what to do
                    Text(scoreMeaning(score))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                }
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("Syncing...")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 70)
            }
        }
    }

    /// Tells the user exactly what their score means and what action moves it.
    private func scoreMeaning(_ score: Double) -> String {
        switch score {
        case 85...:   return "Excellent. Your body is building momentum."
        case 70..<85: return "Strong. Daily movement tends to keep it climbing."
        case 55..<70: return "Good base. One workout often bumps this up."
        case 40..<55: return "Moderate. A walk today tends to add up."
        case 25..<40: return "Below your range. Short walks make a real dent."
        default:      return "Good place to build from. Start small."
        }
    }

    // MARK: - Buddy With Label

    private func buddyWithLabel(_ assessment: HeartAssessment) -> some View {
        let mood = BuddyMood.from(
            assessment: assessment,
            nudgeCompleted: viewModel.nudgeCompleted,
            feedbackType: viewModel.submittedFeedbackType,
            activityInProgress: activityInProgress
        )

        return VStack(spacing: 2) {
            ThumpBuddy(mood: mood, size: 46, showAura: false)

            // Tap hint — only shown when goal pending
            if !viewModel.nudgeCompleted {
                HStack(spacing: 3) {
                    Text("Tap for plan")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7))
                        .foregroundStyle(.quaternary)
                }
            } else {
                // Conquering label
                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Goal Conquered!")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color(hex: 0xEAB308))
            }
        }
        .accessibilityLabel(
            viewModel.nudgeCompleted
                ? "Goal complete! Great work."
                : "Thump buddy, tap to see your improvement plan"
        )
    }

    // MARK: - Nudge Pill

    /// Single compact nudge chip — category icon + title + START tap.
    private func nudgePill(_ nudge: DailyNudge) -> some View {
        Button {
            // Phase 4: START now begins the activity — does NOT auto-complete or
            // auto-send positive feedback. User must explicitly complete via
            // the WatchInsightFlowView feedback screen.
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                activityInProgress = true
            }
            // Launch the appropriate workout or breathing session
            if nudge.category == .breathe {
                connectivityService.breathPrompt = nudge
            }
            // For walk/moderate nudges, open the Workout app via URL scheme
            if nudge.category == .walk || nudge.category == .moderate {
                if let url = URL(string: "workout://startWorkout?activityType=52") {
                    WKExtension.shared().openSystemURL(url)
                }
            }
        } label: {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: nudge.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(nudge.category.tintColorName))
                    Text(nudgeShortLabel(nudge))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 0)

                Text("START")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(nudge.category.tintColorName))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start \(nudge.title)")
    }

    // MARK: - Breath Overlay

    @ViewBuilder
    private func breathOverlay(_ nudge: DailyNudge) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            BreathBuddyOverlay(nudge: nudge) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showBreathOverlay = false
                    connectivityService.breathPrompt = nil
                }
            }
        }
    }

    // MARK: - Syncing Placeholder

    private var syncingPlaceholder: some View {
        VStack(spacing: 10) {
            ThumpBuddy(mood: .tired, size: 52).opacity(0.7)

            switch viewModel.syncState {
            case .waiting, .syncing:
                Text("Waking up...")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("Syncing with iPhone")
                    .font(.system(size: 10)).foregroundStyle(.secondary)

            case .phoneUnreachable:
                Text("Can't find iPhone")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("Open Thump nearby")
                    .font(.system(size: 10)).foregroundStyle(.secondary)

            case .failed(let reason):
                Text("Oops!")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(reason)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).lineLimit(3)

            case .ready:
                EmptyView()
            }

            if viewModel.syncState != .ready {
                Button {
                    viewModel.sync()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise").font(.system(size: 11))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue).controlSize(.small)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func nudgeShortLabel(_ nudge: DailyNudge) -> String {
        if let dur = nudge.durationMinutes {
            switch nudge.category {
            case .walk:    return "Walk \(dur) min"
            case .breathe: return "Breathe \(dur) min"
            case .moderate:return "Move \(dur) min"
            case .rest:    return "Rest up"
            case .hydrate: return "Hydrate"
            case .sunlight:return "Get outside"
            default:       return nudge.title.components(separatedBy: " ").prefix(2).joined(separator: " ")
            }
        }
        return nudge.title.components(separatedBy: " ").prefix(3).joined(separator: " ")
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 70...:   return Color(hex: 0x22C55E)
        case 40..<70: return Color(hex: 0xF59E0B)
        default:      return Color(hex: 0xEF4444)
        }
    }
}

// MARK: - Preview

#Preview {
    let connectivityService = WatchConnectivityService()
    let viewModel = WatchViewModel()
    let history = MockData.mockHistory(days: 21)
    let engine = ConfigService.makeDefaultEngine()
    let assessment = engine.assess(
        history: history,
        current: MockData.mockTodaySnapshot,
        feedback: nil
    )
    viewModel.bind(to: connectivityService)
    Task { @MainActor in
        connectivityService.simulateAssessmentForPreview(assessment)
    }
    return WatchHomeView()
        .environmentObject(connectivityService)
        .environmentObject(viewModel)
}

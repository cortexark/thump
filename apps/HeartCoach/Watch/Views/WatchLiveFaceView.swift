// WatchLiveFaceView.swift
// Thump Watch
//
// Screen 0: ThumpBuddy + one insight about YOUR body.
//
// No numbers. No checklists. No dashboards.
// The buddy is the interface. The message is the product.
//
// The message comes from real engine data:
//   consecutiveAlert → "Resting HR up 3 days in a row"
//   weekOverWeekTrend → "Heart working harder than last week"
//   recoveryTrend → "Recovery getting faster"
//   recoveryContext → "HRV below baseline — body asking for rest"
//   stressFlag → "Stress pattern showing up"
//   scenario → coaching scenario with why + what to do
//
// Every persona gets value:
//   Marcus (stressed pro): pattern detection he can't see himself
//   Priya (beginner): plain English, no jargon
//   David (ring chaser): recovery framed as growth, not failure
//   Jordan (anxious): normalizing, not alarming
//   Aisha (fitness): training load vs recovery intelligence
//   Sarah (parent): micro-intervention that respects 2 minutes
//
// Platforms: watchOS 10+

import SwiftUI
import HealthKit

// MARK: - Buddy Living Screen

struct BuddyLivingScreen: View {

    @EnvironmentObject var viewModel: WatchViewModel

    // MARK: - State

    @State private var appeared = false
    @State private var skyPhase: CGFloat = 0
    @State private var groundPulse: CGFloat = 1.0

    // Tap action overlay — only breathing
    @State private var activeOverlay: BuddyOverlayKind?
    @State private var overlayDismissTask: Task<Void, Never>?

    // Breathing session state
    @State private var breathPhase: CGFloat = 1.0
    @State private var breathCycleCount = 0
    @State private var breathLabel = "Breathe in..."

    // Particles
    @State private var particles: [AmbientParticle] = []

    // MARK: - Derived

    private var assessment: HeartAssessment {
        viewModel.latestAssessment ?? InsightMockData.demoAssessment
    }

    private var mood: BuddyMood {
        if viewModel.nudgeCompleted { return .conquering }
        return BuddyMood.from(assessment: assessment)
    }

    private var insight: BuddyInsight {
        BuddyInsight.generate(from: assessment, mood: mood, nudgeCompleted: viewModel.nudgeCompleted)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Atmospheric background
            atmosphericSky
            ambientParticleField
            groundGlow

            // Main content
            VStack(spacing: 0) {
                Spacer(minLength: 8)

                // ThumpBuddy — center stage, the emotional anchor
                buddyView
                    .scaleEffect(appeared ? 1 : 0.5)

                Spacer(minLength: 8)

                // The insight — or the active overlay
                if let overlay = activeOverlay {
                    overlayContent(overlay)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    insightMessage
                        .opacity(appeared ? 1 : 0)
                        .transition(.opacity)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            generateParticles()
            startParticleAnimation()
            withAnimation(.spring(duration: 0.8, bounce: 0.2)) { appeared = true }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                skyPhase = 1
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                groundPulse = 1.15
            }
        }
        .onTapGesture { handleTap() }
        .animation(.easeInOut(duration: 1.0), value: mood)
        .animation(.spring(duration: 0.4), value: activeOverlay)
    }

    // MARK: - Buddy View

    private var buddyView: some View {
        ZStack {
            if activeOverlay == .breathing {
                Circle()
                    .stroke(mood.glowColor.opacity(0.4), lineWidth: 2.5)
                    .frame(width: 100, height: 100)
                    .scaleEffect(breathPhase)
                    .opacity(Double(2.0 - breathPhase))
            }

            ThumpBuddy(
                mood: activeOverlay == .breathing ? .content : mood,
                size: 82,
                showAura: activeOverlay == nil
            )
            .scaleEffect(activeOverlay == .breathing ? breathPhase * 0.15 + 0.88 : 1.0)
        }
    }

    // MARK: - Insight Message
    //
    // Two lines from BuddyInsight:
    //   Line 1: What the buddy sees (observation from engine data)
    //   Line 2: Why it matters or what to do (contextual, not generic)

    private var insightMessage: some View {
        VStack(spacing: 5) {
            Text(insight.observation)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Text(insight.suggestion)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Tap Handler
    //
    // Tap = the micro-intervention.
    // Stressed/elevated → breathing session (functional: real 40s guided breathwork)
    // Everything else → depends on the nudge category

    private func handleTap() {
        if activeOverlay != nil {
            dismissOverlay()
            return
        }

        // If stressed or the buddy sees stress, breathing is the intervention
        if mood == .stressed || assessment.stressFlag {
            showOverlay(.breathing)
            startBreathingSession()
            return
        }

        // If there's a walk/moderate nudge, launch the workout
        let nudge = assessment.dailyNudge
        if nudge.category == .walk || nudge.category == .moderate {
            if let url = workoutURL(for: nudge.category) {
                #if os(watchOS)
                WKExtension.shared().openSystemURL(url)
                #endif
            }
            return
        }

        // If the nudge is breathe, start breathing
        if nudge.category == .breathe {
            showOverlay(.breathing)
            startBreathingSession()
            return
        }

        // Default: quick breathing (the universal micro-intervention)
        showOverlay(.breathing)
        startBreathingSession()
    }

    // MARK: - Overlay Management

    private func showOverlay(_ kind: BuddyOverlayKind) {
        overlayDismissTask?.cancel()
        activeOverlay = kind

        overlayDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(45))
            guard !Task.isCancelled else { return }
            dismissOverlay()
        }
    }

    private func dismissOverlay() {
        overlayDismissTask?.cancel()
        withAnimation(.spring(duration: 0.4)) {
            activeOverlay = nil
        }
        breathPhase = 1.0
        breathCycleCount = 0
    }

    // MARK: - Overlay Content

    @ViewBuilder
    private func overlayContent(_ kind: BuddyOverlayKind) -> some View {
        switch kind {
        case .breathing:
            breathingOverlay
        }
    }

    // MARK: - Breathing Overlay

    private var breathingOverlay: some View {
        VStack(spacing: 6) {
            Text(breathLabel)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(i < breathCycleCount
                              ? Color(hex: 0x5EEAD4)
                              : Color.white.opacity(0.2))
                        .frame(width: 5, height: 5)
                }
            }

            Text("Tap to stop")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private func startBreathingSession() {
        breathCycleCount = 0
        Task { @MainActor in
            for cycle in 0..<5 {
                guard activeOverlay == .breathing else { return }

                breathLabel = "Breathe in..."
                withAnimation(.easeInOut(duration: 4.0)) { breathPhase = 1.3 }
                try? await Task.sleep(for: .seconds(4))
                guard activeOverlay == .breathing else { return }

                breathLabel = "Breathe out..."
                withAnimation(.easeInOut(duration: 4.0)) { breathPhase = 0.85 }
                try? await Task.sleep(for: .seconds(4))
                guard activeOverlay == .breathing else { return }

                breathCycleCount = cycle + 1
            }
            breathLabel = "That helped"
            try? await Task.sleep(for: .seconds(1.5))
            dismissOverlay()
        }
    }

    // MARK: - Atmospheric Sky

    private var atmosphericSky: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: skyColors,
                    startPoint: UnitPoint(x: 0.5, y: skyPhase * 0.1),
                    endPoint: .bottom
                )
            )
            .overlay(
                RadialGradient(
                    colors: [
                        moodAccent.opacity(0.2 + skyPhase * 0.08),
                        moodAccent.opacity(0.05),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: 20,
                    endRadius: 120
                )
            )
            .ignoresSafeArea()
    }

    private var skyColors: [Color] {
        switch mood {
        case .thriving:
            return [
                Color(hex: 0x042F2E), Color(hex: 0x064E3B),
                Color(hex: 0x065F46), Color(hex: 0x34D399).opacity(0.35),
            ]
        case .content:
            return [
                Color(hex: 0x0F172A), Color(hex: 0x1E3A5F),
                Color(hex: 0x2563EB).opacity(0.6), Color(hex: 0x7DD3FC).opacity(0.25),
            ]
        case .nudging:
            return [
                Color(hex: 0x1C1917), Color(hex: 0x44403C),
                Color(hex: 0x92400E).opacity(0.5), Color(hex: 0xFBBF24).opacity(0.25),
            ]
        case .stressed:
            return [
                Color(hex: 0x1C1917), Color(hex: 0x3B1A2A),
                Color(hex: 0x9D4B6E).opacity(0.5), Color(hex: 0xF9A8D4).opacity(0.2),
            ]
        case .tired:
            return [
                Color(hex: 0x0C0A15), Color(hex: 0x1E1B3A),
                Color(hex: 0x4C3D7A).opacity(0.5), Color(hex: 0xA78BFA).opacity(0.15),
            ]
        case .celebrating, .conquering:
            return [
                Color(hex: 0x1C1917), Color(hex: 0x422006),
                Color(hex: 0x854D0E).opacity(0.6), Color(hex: 0xFDE047).opacity(0.3),
            ]
        case .active:
            return [
                Color(hex: 0x1C1917), Color(hex: 0x3B1A1A),
                Color(hex: 0x9B3A3A).opacity(0.5), Color(hex: 0xFCA5A5).opacity(0.2),
            ]
        }
    }

    // MARK: - Ground Glow

    private var groundGlow: some View {
        VStack {
            Spacer()
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            moodAccent.opacity(0.25),
                            moodAccent.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 30)
                .scaleEffect(groundPulse)
                .offset(y: -20)
        }
        .ignoresSafeArea()
    }

    // MARK: - Ambient Particles

    private var ambientParticleField: some View {
        Canvas { context, size in
            for particle in particles {
                let rect = CGRect(
                    x: particle.x * size.width - particle.size / 2,
                    y: particle.y * size.height - particle.size / 2,
                    width: particle.size,
                    height: particle.size
                )
                context.opacity = particle.opacity
                context.fill(Circle().path(in: rect), with: .color(particle.color))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func generateParticles() {
        particles = (0..<18).map { _ in
            AmbientParticle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 1.5...4),
                opacity: Double.random(in: 0.1...0.5),
                speed: Double.random(in: 0.003...0.012),
                drift: CGFloat.random(in: -0.002...0.002),
                color: particleColor
            )
        }
    }

    private func startParticleAnimation() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                for i in particles.indices {
                    particles[i].y -= particles[i].speed
                    particles[i].x += particles[i].drift
                    if particles[i].y < 0.15 { particles[i].opacity *= 0.97 }
                    if particles[i].y < -0.05 || particles[i].opacity < 0.02 {
                        particles[i].y = CGFloat.random(in: 0.85...1.1)
                        particles[i].x = CGFloat.random(in: 0...1)
                        particles[i].opacity = Double.random(in: 0.15...0.5)
                        particles[i].size = CGFloat.random(in: 1.5...4)
                        particles[i].color = particleColor
                    }
                }
            }
        }
    }

    private var particleColor: Color {
        switch mood {
        case .thriving:                return Color(hex: 0x6EE7B7).opacity(0.6)
        case .content:                 return Color(hex: 0x7DD3FC).opacity(0.5)
        case .nudging:                 return Color(hex: 0xFDE68A).opacity(0.5)
        case .stressed:                return Color(hex: 0xF9A8D4).opacity(0.4)
        case .tired:                   return Color(hex: 0xA78BFA).opacity(0.35)
        case .celebrating, .conquering: return Color(hex: 0xFDE047).opacity(0.6)
        case .active:                  return Color(hex: 0xFCA5A5).opacity(0.5)
        }
    }

    // MARK: - Helpers

    private var moodAccent: Color { mood.glowColor }

    private func workoutURL(for category: NudgeCategory) -> URL? {
        switch category {
        case .walk:     return URL(string: "workout://startWorkout?activityType=52")
        case .moderate: return URL(string: "workout://startWorkout?activityType=37")
        default:        return URL(string: "workout://")
        }
    }
}

// MARK: - Overlay Kind

enum BuddyOverlayKind: Equatable {
    case breathing
}

// MARK: - Buddy Insight
//
// The message generator. Takes raw engine output and produces
// two lines of plain English that feel personal.
//
// Priority order (most novel → least):
//   1. Consecutive elevation alert (multi-day pattern — rare, high value)
//   2. Recovery context (readiness-driven — specific cause + action)
//   3. Week-over-week trend (weekly comparison — periodic insight)
//   4. Recovery trend (fitness signal — training intelligence)
//   5. Coaching scenario (situational — matches current state)
//   6. Stress flag (acute detection)
//   7. Mood-based fallback (always available)

struct BuddyInsight {
    /// What the buddy sees — the observation.
    let observation: String
    /// Why it matters or what to do — the contextual suggestion.
    let suggestion: String

    static func generate(
        from assessment: HeartAssessment,
        mood: BuddyMood,
        nudgeCompleted: Bool
    ) -> BuddyInsight {

        // 0. Goal conquered
        if nudgeCompleted {
            return BuddyInsight(
                observation: "You showed up today",
                suggestion: "That consistency is what moves the needle"
            )
        }

        // 1. Consecutive elevation — multi-day pattern (most valuable insight)
        if let alert = assessment.consecutiveAlert {
            let days = alert.consecutiveDays
            let delta = Int(alert.elevatedMean - alert.personalMean)
            return BuddyInsight(
                observation: "Resting HR up \(delta) bpm for \(days) days",
                suggestion: days >= 4
                    ? "Your body's been working hard. A lighter day could turn this around"
                    : "Keeping an eye on it. Rest helps this recover"
            )
        }

        // 2. Recovery context — readiness-driven (specific driver + tonight action)
        if let recovery = assessment.recoveryContext {
            return BuddyInsight(
                observation: recovery.reason,
                suggestion: recovery.tonightAction
            )
        }

        // 3. Week-over-week trend (periodic insight)
        if let wow = assessment.weekOverWeekTrend {
            switch wow.direction {
            case .significantImprovement:
                return BuddyInsight(
                    observation: "Heart rate dropped this week vs last",
                    suggestion: "Whatever you did last week is working — keep it up"
                )
            case .improving:
                return BuddyInsight(
                    observation: "Trending a bit stronger than last week",
                    suggestion: "Small shifts like this add up over time"
                )
            case .elevated:
                let delta = Int(wow.currentWeekMean - wow.baselineMean)
                return BuddyInsight(
                    observation: "Heart working \(delta) bpm harder than your baseline",
                    suggestion: "This usually responds well to a rest day"
                )
            case .significantElevation:
                return BuddyInsight(
                    observation: "Your heart's been running hotter than usual",
                    suggestion: "Worth checking in — sleep and stress both affect this"
                )
            case .stable:
                break // Fall through to next priority
            }
        }

        // 4. Recovery trend (training intelligence)
        if let rt = assessment.recoveryTrend, rt.dataPoints >= 3 {
            switch rt.direction {
            case .improving:
                return BuddyInsight(
                    observation: "Recovery after exercise is getting faster",
                    suggestion: "That's a real fitness gain — your heart bounces back quicker"
                )
            case .declining:
                return BuddyInsight(
                    observation: "Taking longer to recover after activity",
                    suggestion: "Could mean you're pushing harder than your body's ready for"
                )
            case .stable, .insufficientData:
                break
            }
        }

        // 5. Coaching scenario
        if let scenario = assessment.scenario {
            switch scenario {
            case .overtrainingSignals:
                return BuddyInsight(
                    observation: "Signs of overtraining showing up",
                    suggestion: "A recovery day isn't lost time — it's when you get stronger"
                )
            case .highStressDay:
                return BuddyInsight(
                    observation: "Your body is carrying extra load today",
                    suggestion: "One slow breath can shift your nervous system. Tap to try"
                )
            case .greatRecoveryDay:
                return BuddyInsight(
                    observation: "Body bounced back well",
                    suggestion: "Good day to use this energy — or bank it for tomorrow"
                )
            case .decliningTrend:
                return BuddyInsight(
                    observation: "Metrics have been shifting the past couple weeks",
                    suggestion: "Sleep and stress are usually the first places to look"
                )
            case .improvingTrend:
                return BuddyInsight(
                    observation: "Two weeks of steady improvement",
                    suggestion: "Your habits are showing up in the numbers"
                )
            case .missingActivity:
                return BuddyInsight(
                    observation: "Been a quieter few days",
                    suggestion: "Even a short walk changes the trajectory"
                )
            }
        }

        // 6. Stress flag (acute)
        if assessment.stressFlag {
            return BuddyInsight(
                observation: "Stress pattern showing up",
                suggestion: "Not dangerous — just your nervous system running warm. Tap to breathe"
            )
        }

        // 7. Mood-based fallback (always available, uses assessment data)
        return moodFallback(mood: mood, assessment: assessment)
    }

    private static func moodFallback(mood: BuddyMood, assessment: HeartAssessment) -> BuddyInsight {
        let hour = Calendar.current.component(.hour, from: Date())

        switch mood {
        case .thriving:
            return BuddyInsight(
                observation: "Your body is in a strong place today",
                suggestion: hour < 17
                    ? "Good day to push a little harder if you want to"
                    : "Protect tonight's sleep to keep this going"
            )
        case .content:
            return BuddyInsight(
                observation: "Everything looks balanced",
                suggestion: "Steady days like this build the foundation"
            )
        case .nudging:
            if let mins = assessment.dailyNudge.durationMinutes {
                return BuddyInsight(
                    observation: "You've got a window for movement",
                    suggestion: "\(mins) minutes would make a real difference today"
                )
            }
            return BuddyInsight(
                observation: "Your body has energy to use",
                suggestion: "A little movement now pays off tonight"
            )
        case .stressed:
            return BuddyInsight(
                observation: "Running a bit activated right now",
                suggestion: "That's okay — one breath can shift things. Tap to try"
            )
        case .tired:
            return BuddyInsight(
                observation: "Your body is asking for recovery",
                suggestion: hour >= 17
                    ? "Early sleep tonight is the highest-leverage thing you can do"
                    : "A lighter day lets your body rebuild"
            )
        case .active:
            return BuddyInsight(
                observation: "You're in motion",
                suggestion: "Your heart is responding — keep going at your pace"
            )
        case .celebrating, .conquering:
            return BuddyInsight(
                observation: "You showed up today",
                suggestion: "That's the habit that compounds"
            )
        }
    }
}

// MARK: - Ambient Particle

struct AmbientParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: Double
    var drift: CGFloat
    var color: Color
}

// MARK: - Preview

#if DEBUG
#Preview("Living — Content") {
    BuddyLivingScreen()
        .environmentObject(WatchViewModel())
}
#endif

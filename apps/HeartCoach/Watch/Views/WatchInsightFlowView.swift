// WatchInsightFlowView.swift
// Thump Watch
//
// 6-screen architecture:
//   Screen 0: HERO — Score + Buddy + Nudge (the 2-second glance)
//   Screen 1: READINESS — 5-pillar breakdown (why is my score this?)
//   Screen 2: WALK — Step count + time-aware push + START (get moving)
//   Screen 3: STRESS — Buddy emoji + heatmap + Breathe on active stress
//   Screen 4: SLEEP — Hours + quality + trend (how did I sleep?)
//   Screen 5: TRENDS — HRV↑ RHR↓ + coaching note + streak (am I improving?)
//
// Design principles (from wearable UX research):
//   - 2-second rule: every screen communicates in under 2 seconds
//   - One number, one color, one action on the hero screen
//   - Score > raw data: interpreted scores, not sensor values
//   - Progressive disclosure: glance → tap → swipe → iPhone for full detail
//   - No scroll within screens: each screen is one viewport
//
// Platforms: watchOS 10+

import SwiftUI
import HealthKit

// MARK: - Insight Flow View

struct WatchInsightFlowView: View {

    // MARK: - Date Formatters (static to avoid per-render allocation)

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    @EnvironmentObject var viewModel: WatchViewModel
    @State private var selectedTab = 0
    private let totalTabs = 6

    private var assessment: HeartAssessment {
        viewModel.latestAssessment ?? InsightMockData.demoAssessment
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            heroScreen.tag(0)
            readinessScreen.tag(1)
            walkScreen.tag(2)
            stressScreen.tag(3)
            sleepScreen.tag(4)
            trendsScreen.tag(5)
        }
        .tabViewStyle(.page)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Screen 0: Hero (Score + Buddy + Nudge)

    private var heroScreen: some View {
        HeroScoreScreen()
    }

    // MARK: - Screen 1: Readiness Breakdown

    private var readinessScreen: some View {
        ReadinessBreakdownScreen(assessment: assessment)
    }

    // MARK: - Screen 2: Walk (Activity suggestion)

    private var walkScreen: some View {
        WalkSuggestionScreen(nudge: assessment.dailyNudge)
    }

    // MARK: - Screen 3: Stress (Buddy emoji + heatmap + breathe)

    private var stressScreen: some View {
        StressPulseScreen(isStressed: assessment.stressFlag)
    }

    // MARK: - Screen 4: Sleep Summary

    private var sleepScreen: some View {
        let needsRest = assessment.status == .needsAttention || assessment.stressFlag
        return SleepSummaryScreen(needsRest: needsRest)
    }

    // MARK: - Screen 5: Trends + Coaching

    private var trendsScreen: some View {
        TrendsScreen(assessment: assessment)
    }
}

// MARK: - Mock Data

enum InsightMockData {
    static var demoAssessment: HeartAssessment {
        HeartAssessment(
            status: .improving,
            confidence: .high,
            anomalyScore: 0.28,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: 74,
            dailyNudge: DailyNudge(
                category: .walk,
                title: "Midday Walk",
                description: "Step outside for 15 minutes — fresh air and movement help you reset.",
                durationMinutes: 15,
                icon: "figure.walk"
            ),
            explanation: "Consistent rhythm this week. Keep it up!"
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Screen 0: Hero Score Screen
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// The screen users see 50+ times/day. Must communicate in <2 seconds.
// Score is 60% of visual weight. Buddy is 25%. Nudge is 15%.
// Every successful wearable app leads with a single hero number.

private struct HeroScoreScreen: View {

    @EnvironmentObject var viewModel: WatchViewModel

    @State private var appeared = false
    @State private var scoreScale: CGFloat = 0.5
    @State private var skyPhase: CGFloat = 0
    @State private var groundPulse: CGFloat = 1.0

    private var assessment: HeartAssessment {
        viewModel.latestAssessment ?? InsightMockData.demoAssessment
    }

    private var mood: BuddyMood {
        if viewModel.nudgeCompleted { return .conquering }
        return BuddyMood.from(assessment: assessment)
    }

    private var score: Int {
        Int(assessment.cardioScore ?? 0)
    }

    private var scoreColor: Color {
        switch score {
        case 70...:  return Color(hex: 0x22C55E)
        case 40..<70: return Color(hex: 0xF59E0B)
        default:      return Color(hex: 0xEF4444)
        }
    }

    private var scoreContext: String {
        if viewModel.nudgeCompleted { return "Goal done — streak alive" }
        switch score {
        case 80...:  return "Strong day"
        case 70..<80: return "Ready to move"
        case 55..<70: return "Take it easy"
        case 40..<55: return "Rest & recover"
        default:      return "Listen to your body"
        }
    }

    var body: some View {
        ZStack {
            // Atmospheric background
            atmosphericSky
            groundGlow

            VStack(spacing: 0) {
                Spacer(minLength: 10)

                // ── Hero Score: the product IS this number ──
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor)
                        .scaleEffect(scoreScale)

                    Text(scoreContext)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 6)

                // ── ThumpBuddy: emotional anchor — tap to cycle moods ──
                ThumpBuddy(mood: mood, size: 46, showAura: false, tappable: true)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.6)

                Spacer(minLength: 8)

                // ── Daily Nudge: one-tap action ──
                if !viewModel.nudgeCompleted {
                    nudgePill
                        .opacity(appeared ? 1 : 0)
                } else {
                    // Completed state
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Done")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: 0xEAB308))
                    .opacity(appeared ? 1 : 0)
                }

                Spacer(minLength: 6)
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.25)) {
                appeared = true
                scoreScale = 1.0
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                skyPhase = 1
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                groundPulse = 1.15
            }
        }
        .onTapGesture { handleTap() }
        .animation(.easeInOut(duration: 1.0), value: mood)
    }

    // MARK: - Nudge Pill

    private var nudgePill: some View {
        let nudge = assessment.dailyNudge
        let isSleepHour = {
            let h = Calendar.current.component(.hour, from: Date())
            return h >= 22 || h < 5
        }()

        return Group {
            if isSleepHour {
                // Sleep hours: no action, just context
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Rest up")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.4))
            } else {
                // Active hours: tappable nudge pill with START
                Button {
                    launchNudge(nudge)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: nudge.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(nudgeLabel(nudge))
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(scoreColor.opacity(0.85))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func nudgeLabel(_ nudge: DailyNudge) -> String {
        if let mins = nudge.durationMinutes {
            return "\(nudge.title) · \(mins)m"
        }
        return nudge.title
    }

    // MARK: - Tap Handler

    private func handleTap() {
        let nudge = assessment.dailyNudge
        if mood == .stressed || assessment.stressFlag {
            // Open Apple Mindfulness for breathing
            if let url = URL(string: "mindfulness://") {
                #if os(watchOS)
                WKExtension.shared().openSystemURL(url)
                #endif
            }
            return
        }
        launchNudge(nudge)
    }

    private func launchNudge(_ nudge: DailyNudge) {
        if let url = workoutURL(for: nudge.category) {
            #if os(watchOS)
            WKExtension.shared().openSystemURL(url)
            #endif
        }
    }

    private func workoutURL(for category: NudgeCategory) -> URL? {
        switch category {
        case .walk:     return URL(string: "workout://startWorkout?activityType=52")
        case .moderate: return URL(string: "workout://startWorkout?activityType=37")
        case .breathe:  return URL(string: "mindfulness://")
        default:        return URL(string: "workout://")
        }
    }

    // MARK: - Atmospheric Background

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
                        scoreColor.opacity(0.15 + skyPhase * 0.05),
                        scoreColor.opacity(0.03),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.3),
                    startRadius: 20,
                    endRadius: 120
                )
            )
            .ignoresSafeArea()
    }

    private var skyColors: [Color] {
        switch mood {
        case .thriving:
            return [Color(hex: 0x042F2E), Color(hex: 0x064E3B), Color(hex: 0x065F46), Color(hex: 0x34D399).opacity(0.35)]
        case .content:
            return [Color(hex: 0x0F172A), Color(hex: 0x1E3A5F), Color(hex: 0x2563EB).opacity(0.6), Color(hex: 0x7DD3FC).opacity(0.25)]
        case .nudging:
            return [Color(hex: 0x1C1917), Color(hex: 0x44403C), Color(hex: 0x92400E).opacity(0.5), Color(hex: 0xFBBF24).opacity(0.25)]
        case .stressed:
            return [Color(hex: 0x1C1917), Color(hex: 0x3B1A2A), Color(hex: 0x9D4B6E).opacity(0.5), Color(hex: 0xF9A8D4).opacity(0.2)]
        case .tired:
            return [Color(hex: 0x0C0A15), Color(hex: 0x1E1B3A), Color(hex: 0x4C3D7A).opacity(0.5), Color(hex: 0xA78BFA).opacity(0.15)]
        case .celebrating, .conquering:
            return [Color(hex: 0x1C1917), Color(hex: 0x422006), Color(hex: 0x854D0E).opacity(0.6), Color(hex: 0xFDE047).opacity(0.3)]
        case .active:
            return [Color(hex: 0x1C1917), Color(hex: 0x3B1A1A), Color(hex: 0x9B3A3A).opacity(0.5), Color(hex: 0xFCA5A5).opacity(0.2)]
        }
    }

    private var groundGlow: some View {
        VStack {
            Spacer()
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [scoreColor.opacity(0.2), scoreColor.opacity(0.05), .clear],
                        center: .center, startRadius: 5, endRadius: 80
                    )
                )
                .frame(width: 160, height: 30)
                .scaleEffect(groundPulse)
                .offset(y: -15)
        }
        .ignoresSafeArea()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Screen 1: Readiness Breakdown
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// "Why is my score this?" — 5-pillar breakdown.
// Oura's readiness breakdown is their most-viewed detail screen.
// Users want to know the WHY behind the number.

private struct ReadinessBreakdownScreen: View {

    let assessment: HeartAssessment

    @State private var appeared = false

    private var score: Int { Int(assessment.cardioScore ?? 0) }

    private var scoreColor: Color {
        switch score {
        case 70...:  return Color(hex: 0x22C55E)
        case 40..<70: return Color(hex: 0xF59E0B)
        default:      return Color(hex: 0xEF4444)
        }
    }

    // Derive pillar scores from assessment data
    // Each pillar: 0.0-1.0 representing contribution to overall score
    private var pillars: [(name: String, icon: String, value: Double, color: Color)] {
        let baseScore = assessment.cardioScore ?? 70
        let isStressed = assessment.stressFlag
        let anomaly = assessment.anomalyScore

        // Sleep pillar: inferred from score + stress state
        let sleepValue = min(1.0, max(0.1, (baseScore / 100) * (isStressed ? 0.7 : 1.1)))

        // Recovery pillar: inverse of anomaly score
        let recoveryValue = min(1.0, max(0.1, 1.0 - anomaly))

        // Stress pillar: inverse of stress state
        let stressValue = isStressed ? 0.3 : min(1.0, max(0.2, 1.0 - anomaly * 0.8))

        // Activity pillar: mid-range by default, boosted by good score
        let activityValue = min(1.0, max(0.15, baseScore / 120))

        // HRV pillar: derived from overall cardio health
        let hrvValue: Double
        switch assessment.status {
        case .improving: hrvValue = min(1.0, baseScore / 90)
        case .stable:    hrvValue = min(1.0, baseScore / 100)
        default:         hrvValue = min(0.6, baseScore / 110)
        }

        return [
            ("Sleep", "moon.fill", sleepValue, Color(hex: 0x818CF8)),
            ("Recovery", "arrow.counterclockwise.heart.fill", recoveryValue, Color(hex: 0x34D399)),
            ("Stress", "brain.head.profile.fill", stressValue, Color(hex: 0xF9A8D4)),
            ("Activity", "figure.walk", activityValue, Color(hex: 0xFBBF24)),
            ("HRV", "waveform.path.ecg", hrvValue, Color(hex: 0xA78BFA)),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 6)

            // Header: score recap + label
            HStack(spacing: 6) {
                Text("\(score)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(scoreColor)
                Text("Readiness")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 10)

            // 5-pillar breakdown bars
            VStack(spacing: 7) {
                ForEach(Array(pillars.enumerated()), id: \.offset) { index, pillar in
                    pillarRow(pillar, delay: Double(index) * 0.08)
                }
            }
            .padding(.horizontal, 14)
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 8)

            // Context line
            Text(readinessContext)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(scoreColor.gradient.opacity(0.06), for: .tabView)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { appeared = true }
        }
    }

    private func pillarRow(_ pillar: (name: String, icon: String, value: Double, color: Color), delay: Double) -> some View {
        HStack(spacing: 6) {
            // Icon
            Image(systemName: pillar.icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(pillar.color)
                .frame(width: 14)

            // Label
            Text(pillar.name)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 52, alignment: .leading)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(pillar.color)
                        .frame(width: appeared ? geo.size.width * pillar.value : 0, height: 6)
                        .animation(.spring(duration: 0.6).delay(delay), value: appeared)
                }
            }
            .frame(height: 6)
        }
    }

    private var readinessContext: String {
        // Find the weakest pillar
        guard let weakest = pillars.min(by: { $0.value < $1.value }) else {
            return "All systems balanced"
        }
        if weakest.value >= 0.7 {
            return "All pillars strong — great day to push"
        }
        switch weakest.name {
        case "Sleep":    return "Sleep is holding you back — prioritize tonight"
        case "Recovery": return "Body still recovering — ease the intensity"
        case "Stress":   return "Stress is elevated — try a breathing session"
        case "Activity": return "Movement is low — a short walk helps"
        case "HRV":      return "HRV dipped — your nervous system needs rest"
        default:         return "Focus on your lowest pillar today"
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Screen 2: Walk Suggestion
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// "Get moving" — step count + time-aware push message + START button.
// Dedicated activity screen separate from stress.
// The nudge here is always about movement, not breathing.

private struct WalkSuggestionScreen: View {

    let nudge: DailyNudge

    @State private var appeared = false
    @State private var stepCount: Int?

    private let healthStore = HKHealthStore()

    private var isSleepHour: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 22 || h < 5
    }

    private var pushMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let steps = stepCount ?? 0
        if isSleepHour { return "Rest up — move tomorrow" }
        switch (steps, hour) {
        case (0..<1000, 5..<10):   return "Start the day with a win"
        case (0..<1000, 10..<14):  return "Steps are low — a short walk fixes that"
        case (0..<1000, 14...):    return "Under 1K steps. Even 10 min helps"
        case (1000..<4000, ..<12): return "Good start. Keep the momentum"
        case (1000..<4000, 12...): return "Feeling up for a little extra?"
        case (4000..<7000, _):     return "Nice pace — 15 more min puts you ahead"
        case (7000..<10000, _):    return "Almost at 10K. One more walk seals it"
        default:
            return steps >= 10000 ? "10K+ done — you're ahead today" : "A walk makes everything better"
        }
    }

    private var workoutURL: URL? {
        switch nudge.category {
        case .moderate: return URL(string: "workout://startWorkout?activityType=37")
        default:        return URL(string: "workout://startWorkout?activityType=52")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            // ThumpBuddy in nudging mood — pushing you to move
            ThumpBuddy(mood: .nudging, size: 50, showAura: false)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.6)

            Spacer(minLength: 8)

            // Step count
            if let steps = stepCount {
                HStack(spacing: 4) {
                    Image(systemName: "shoeprints.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x22C55E))
                    Text("\(steps.formatted()) steps")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .opacity(appeared ? 1 : 0)
            } else {
                Text("Counting steps...")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 6)

            // Push message
            Text(pushMessage)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 10)

            // START button (hidden during sleep hours)
            if !isSleepHour {
                Button {
                    if let url = workoutURL {
                        #if os(watchOS)
                        WKExtension.shared().openSystemURL(url)
                        #endif
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: nudge.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text("Start \(nudge.category == .moderate ? "Run" : "Walk")")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(Color(hex: 0x22C55E))
                    )
                    .padding(.horizontal, 24)
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(hex: 0x22C55E).gradient.opacity(0.07), for: .tabView)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { appeared = true }
            fetchStepCount()
        }
    }

    // MARK: - HealthKit

    private func fetchStepCount() {
        guard HKHealthStore.isHealthDataAvailable() else {
            stepCount = mockStepCount()
            return
        }
        let type = HKQuantityType(.stepCount)
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            if let error {
                AppLogger.healthKit.warning("Watch step count query failed: \(error.localizedDescription)")
            }
            let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            Task { @MainActor in
                self.stepCount = steps > 0 ? Int(steps) : self.mockStepCount()
            }
        }
        healthStore.execute(query)
    }

    private func mockStepCount() -> Int {
        let hour = Calendar.current.component(.hour, from: Date())
        let activeHours = max(0, min(hour - 7, 13))
        let base = activeHours * 480
        let jitter = (hour * 137 + 29) % 340
        return max(300, base + jitter)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Screen 3: Stress Pulse
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// "Am I stressed?" — ThumpBuddy emoji as the stress indicator.
// Buddy shows stressed face during active stress, calm face otherwise.
// Breathe button only appears when stress is detected.
// Heatmap shows the 6-hour stress pattern.

private struct StressPulseScreen: View {

    let isStressed: Bool

    @State private var appeared = false
    @State private var hourlyHR: [Double?] = Array(repeating: nil, count: 6)
    @State private var restingHR: Double = 70

    private let healthStore = HKHealthStore()

    private var stressLevel: String {
        isStressed ? "Elevated" : "Relaxed"
    }

    private var stressColor: Color {
        isStressed ? Color(hex: 0xF59E0B) : Color(hex: 0x0D9488)
    }

    /// Buddy mood reflects stress state — the emoji IS the indicator
    private var buddyMood: BuddyMood {
        isStressed ? .stressed : .content
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)

            // ── ThumpBuddy emoji — the stress indicator ──
            // Stressed: wide eyes, tense posture
            // Calm: peaceful eyes, relaxed
            ThumpBuddy(mood: buddyMood, size: 50, showAura: false)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)

            Spacer(minLength: 4)

            // Stress level label
            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(stressColor)
                        .frame(width: 8, height: 8)
                    Text(stressLevel)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(stressColor)
                }

                Text(isStressed ? "Nervous system running warm" : "Body is calm")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 8)

            // 6-hour heatmap
            sixHourHeatmap
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 10)

            // Breathe button — only visible during active stress
            if isStressed {
                Button {
                    if let url = URL(string: "mindfulness://") {
                        WKExtension.shared().openSystemURL(url)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "wind")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Breathe")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(Color(hex: 0x0D9488))
                    )
                    .padding(.horizontal, 24)
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
            } else {
                // Calm state — just a reassuring message
                Text("Keep it up")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(stressColor.gradient.opacity(0.08), for: .tabView)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { appeared = true }
            fetchHourlyHeartRate()
        }
    }

    // MARK: - 6-Hour Heatmap

    private var sixHourHeatmap: some View {
        let now = Date()
        let cal = Calendar.current
        let currentHour = cal.component(.hour, from: now)

        return VStack(spacing: 4) {
            // Single row of 6 dots
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { slotIndex in
                    let isNow = slotIndex == 5
                    let hoursAgo = 5 - slotIndex
                    let hour = (currentHour - hoursAgo + 24) % 24
                    let avgHR = hourlyHR[slotIndex]
                    dotWithLabel(avgHR: avgHR, isNow: isNow, hour: hour)
                }
            }
        }
    }

    @ViewBuilder
    private func dotWithLabel(avgHR: Double?, isNow: Bool, hour: Int) -> some View {
        VStack(spacing: 3) {
            ZStack {
                if let hr = avgHR {
                    let elevation = hr - restingHR
                    let color: Color = elevation < 5
                        ? Color(hex: 0x22C55E)
                        : elevation < 15
                            ? Color(hex: 0xF59E0B)
                            : Color(hex: 0xEF4444)
                    Circle()
                        .fill(color)
                        .frame(width: 14, height: 14)
                    if isNow {
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                    }
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        .frame(width: 12, height: 12)
                }
            }
            .frame(width: 20, height: 20)

            Text(isNow ? "now" : hourLabel(hour))
                .font(.system(size: 8, weight: isNow ? .heavy : .regular, design: .monospaced))
                .foregroundStyle(isNow ? Color.primary : Color.secondary.opacity(0.6))
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0:  return "12a"
        case 12: return "12p"
        case 1..<12: return "\(hour)a"
        default: return "\(hour - 12)p"
        }
    }

    // MARK: - HealthKit Fetch

    private func fetchHourlyHeartRate() {
        guard HKHealthStore.isHealthDataAvailable() else {
            hourlyHR = Self.mockHourlyHR(restingHR: restingHR)
            return
        }
        fetchRestingHR()
        fetchHRSamples()
    }

    private func fetchRestingHR() {
        let type = HKQuantityType(.restingHeartRate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
            if let error { AppLogger.healthKit.warning("Watch RHR query failed: \(error.localizedDescription)") }
            guard let sample = (samples as? [HKQuantitySample])?.first else { return }
            let bpm = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            Task { @MainActor in self.restingHR = bpm }
        }
        healthStore.execute(query)
    }

    private func fetchHRSamples() {
        let type = HKQuantityType(.heartRate)
        let now = Date()
        let start = now.addingTimeInterval(-6 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
            if let error { AppLogger.healthKit.warning("Watch HR samples query failed: \(error.localizedDescription)") }
            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                Task { @MainActor in
                    withAnimation(.easeIn(duration: 0.4)) {
                        self.hourlyHR = Self.mockHourlyHR(restingHR: self.restingHR)
                    }
                }
                return
            }

            let cal = Calendar.current
            let currentHour = cal.component(.hour, from: now)
            let unit = HKUnit.count().unitDivided(by: .minute())

            var buckets: [[Double]] = Array(repeating: [], count: 6)
            for sample in samples {
                let sampleHour = cal.component(.hour, from: sample.startDate)
                let hoursAgo = (currentHour - sampleHour + 24) % 24
                guard hoursAgo < 6 else { continue }
                let slotIndex = 5 - hoursAgo
                buckets[slotIndex].append(sample.quantity.doubleValue(for: unit))
            }

            let averages: [Double?] = buckets.map { $0.isEmpty ? nil : $0.reduce(0, +) / Double($0.count) }

            Task { @MainActor in
                withAnimation(.easeIn(duration: 0.4)) { self.hourlyHR = averages }
            }
        }
        healthStore.execute(query)
    }

    private static func mockHourlyHR(restingHR: Double) -> [Double?] {
        let cal = Calendar.current
        let currentHour = cal.component(.hour, from: Date())
        let realHourlyAvg: [Int: Double] = [
            0: 62.7, 1: 63.1, 2: 56.5, 3: 57.6, 4: 56.2, 5: 50.4,
            6: 53.9, 7: 55.3, 8: 60.0, 9: 58.9, 10: 68.1, 11: 68.5,
            12: 67.3, 13: 65.3, 14: 88.3, 15: 76.3, 16: 85.8, 17: 99.7,
            18: 99.8, 19: 141.5, 20: 85.0, 21: 75.0, 22: 68.0, 23: 64.0
        ]
        return (0..<6).map { slot in
            let hoursAgo = 5 - slot
            let hour = (currentHour - hoursAgo + 24) % 24
            return realHourlyAvg[hour] ?? restingHR
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Screen 3: Sleep Summary
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// "How did I sleep?" — Big hours number + quality + trend arrow.
// Sleep is the #2 most-viewed metric. Keep it to 3 data points max.

private struct SleepSummaryScreen: View {

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    let needsRest: Bool

    @State private var appeared = false
    @State private var lastNightHours: Double?
    @State private var recentSleepHours: [Double] = []
    @State private var wakeTime: Date?

    private let healthStore = HKHealthStore()

    private var sleepQuality: String {
        guard let hours = lastNightHours else { return "No data" }
        switch hours {
        case 7.5...: return "Excellent"
        case 7..<7.5: return "Good"
        case 6..<7:   return "Fair"
        default:      return "Poor"
        }
    }

    private var sleepQualityColor: Color {
        guard let hours = lastNightHours else { return .secondary }
        switch hours {
        case 7...:    return Color(hex: 0x22C55E)
        case 6..<7:   return Color(hex: 0xF59E0B)
        default:      return Color(hex: 0xEF4444)
        }
    }

    private var trendArrow: String {
        guard recentSleepHours.count >= 2 else { return "" }
        let recent = recentSleepHours.last ?? 0
        let prev = recentSleepHours.dropLast().last ?? 0
        if recent > prev + 0.3 { return "↑" }
        if recent < prev - 0.3 { return "↓" }
        return "→"
    }

    private var trendLabel: String {
        guard recentSleepHours.count >= 2 else { return "Track more nights" }
        let recent = recentSleepHours.last ?? 0
        let prev = recentSleepHours.dropLast().last ?? 0
        if recent > prev + 0.3 { return "Improving" }
        if recent < prev - 0.3 { return "Declining" }
        return "Stable"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 6)

            // ThumpBuddy — tired/sleeping face
            ThumpBuddy(mood: .tired, size: 46, showAura: false)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)

            Spacer(minLength: 6)

            // ── Big hours number ──
            if let hours = lastNightHours {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formattedHours(hours))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .opacity(appeared ? 1 : 0)
            } else {
                Text("—")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 4)

            // ── Quality badge ──
            HStack(spacing: 6) {
                Text(sleepQuality)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(sleepQualityColor)

                if !trendArrow.isEmpty {
                    Text(trendArrow)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 8)

            // ── 3-night mini trend ──
            if recentSleepHours.count >= 2 {
                HStack(spacing: 4) {
                    ForEach(Array(recentSleepHours.suffix(3).enumerated()), id: \.offset) { index, hours in
                        let isLast = index == recentSleepHours.suffix(3).count - 1
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor(hours))
                                .frame(width: 16, height: appeared ? barHeight(hours) : 4)
                                .animation(.spring(duration: 0.5).delay(Double(index) * 0.1), value: appeared)
                            Text(shortHours(hours))
                                .font(.system(size: 8, weight: isLast ? .heavy : .regular, design: .rounded))
                                .foregroundStyle(isLast ? .primary : .secondary)
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 6)

            // ── Trend label ──
            Text(trendLabel)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(hex: 0x6366F1).gradient.opacity(0.08), for: .tabView)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { appeared = true }
            fetchLastNightSleep()
            fetchRecentSleepHistory()
        }
    }

    // MARK: - Bar helpers

    private func barHeight(_ hours: Double) -> CGFloat {
        let clamped = max(4, min(8.5, hours))
        return CGFloat((clamped - 4) / 4.5) * 24 + 8  // 8-32pt range
    }

    private func barColor(_ hours: Double) -> Color {
        switch hours {
        case 7...:  return Color(hex: 0x818CF8)
        case 6..<7: return Color(hex: 0xF59E0B).opacity(0.7)
        default:    return Color(hex: 0xEF4444).opacity(0.6)
        }
    }

    private func shortHours(_ h: Double) -> String {
        let hrs = Int(h)
        let mins = Int((h - Double(hrs)) * 60)
        if mins < 10 { return "\(hrs)h" }
        return "\(hrs):\(mins)"
    }

    private func formattedHours(_ h: Double) -> String {
        let hrs = Int(h)
        let mins = Int((h - Double(hrs)) * 60)
        if mins == 0 { return "\(hrs)h" }
        return "\(hrs)h \(mins)m"
    }

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    // MARK: - HealthKit

    private func fetchLastNightSleep() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let sleepType = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let windowStart = startOfToday.addingTimeInterval(-18 * 3600)
        let windowEnd = startOfToday.addingTimeInterval(12 * 3600)

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
            if let error { AppLogger.healthKit.warning("Watch sleep query failed: \(error.localizedDescription)") }
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else { return }
            let asleepValues = HKCategoryValueSleepAnalysis.allAsleepValues.map { $0.rawValue }
            let asleepSamples = samples.filter { asleepValues.contains($0.value) }
            let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let hours = totalSeconds / 3600
            let latestEnd = samples.first?.endDate

            Task { @MainActor in
                withAnimation(.easeIn(duration: 0.3)) {
                    self.lastNightHours = hours > 0 ? hours : nil
                    self.wakeTime = latestEnd
                }
            }
        }
        healthStore.execute(query)
    }

    private func fetchRecentSleepHistory() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let sleepType = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        let now = Date()
        let windowStart = cal.date(byAdding: .day, value: -4, to: cal.startOfDay(for: now))!
        let windowEnd = cal.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
            if let error { AppLogger.healthKit.warning("Watch sleep history query failed: \(error.localizedDescription)") }
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else { return }
            let asleepValues = HKCategoryValueSleepAnalysis.allAsleepValues.map { $0.rawValue }
            let asleepSamples = samples.filter { asleepValues.contains($0.value) }

            var nightBuckets: [Date: Double] = [:]
            for sample in asleepSamples {
                let nightDate = cal.startOfDay(for: sample.startDate)
                nightBuckets[nightDate, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600
            }

            let sortedNights = nightBuckets.sorted { $0.key < $1.key }.suffix(3).map { $0.value }

            Task { @MainActor in self.recentSleepHours = sortedNights }
        }
        healthStore.execute(query)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Screen 4: Trends + Coaching
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// "Am I getting better?" — HRV↑ RHR↓ deltas + coaching note + streak.
// Gamification drives 28% increase in DAU (Strava data).
// Coaching message = perceived value that justifies subscription.

private struct TrendsScreen: View {

    let assessment: HeartAssessment

    @State private var appeared = false
    @State private var todayHRV: Double?
    @State private var todayRHR: Double?
    @State private var yesterdayHRV: Double?
    @State private var yesterdayRHR: Double?

    private let healthStore = HKHealthStore()

    // Streak count from UserDefaults (days the user has opened the app)
    private var streakCount: Int {
        UserDefaults.standard.integer(forKey: "thump_daily_streak")
    }

    private var coachingNote: String {
        if let scenario = assessment.scenario {
            switch scenario {
            case .overtrainingSignals: return "Recovery day — that's when you get stronger"
            case .highStressDay:       return "Stress is high — a walk or breathe session helps"
            case .greatRecoveryDay:    return "Great recovery — good day to push"
            case .decliningTrend:      return "Check sleep and stress first"
            case .improvingTrend:      return "Two weeks of progress — habits are paying off"
            case .missingActivity:     return "Even a short walk changes the trajectory"
            }
        }
        switch assessment.status {
        case .improving:      return "Your numbers are trending in the right direction"
        case .needsAttention: return "Body is asking for rest — listen to it"
        default:              return "Consistency is your edge — keep showing up"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 6)

            // Title
            Text("Trends")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 8)

            // HRV + RHR compact tiles
            VStack(spacing: 6) {
                compactMetricRow(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    unit: "ms",
                    value: todayHRV,
                    previous: yesterdayHRV,
                    higherIsBetter: true,
                    accentColor: Color(hex: 0xA78BFA)
                )
                compactMetricRow(
                    icon: "heart.fill",
                    label: "RHR",
                    unit: "bpm",
                    value: todayRHR,
                    previous: yesterdayRHR,
                    higherIsBetter: false,
                    accentColor: Color(hex: 0xEC4899)
                )
            }
            .padding(.horizontal, 10)
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 10)

            // Coaching note
            Text(coachingNote)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 8)

            // Streak counter
            if streakCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF59E0B))
                    Text("\(streakCount) day streak")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xF59E0B))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(hex: 0xF59E0B).opacity(0.12), in: Capsule())
                .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(hex: 0xEC4899).gradient.opacity(0.07), for: .tabView)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { appeared = true }
            fetchMetrics()
        }
    }

    // MARK: - Compact Metric Row

    private func compactMetricRow(
        icon: String,
        label: String,
        unit: String,
        value: Double?,
        previous: Double?,
        higherIsBetter: Bool,
        accentColor: Color
    ) -> some View {
        let delta: Double? = {
            guard let v = value, let p = previous else { return nil }
            return v - p
        }()
        let improved: Bool? = delta.map { higherIsBetter ? $0 > 0 : $0 < 0 }

        return HStack(spacing: 0) {
            // Icon + label
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accentColor)
            Text("  \(label)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            // Value
            if let v = value {
                Text("\(Int(v.rounded()))")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text(" \(unit)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Delta arrow
            if let d = delta {
                let sign = d > 0 ? "+" : ""
                let arrow = d > 0 ? "arrow.up" : "arrow.down"
                HStack(spacing: 2) {
                    Image(systemName: arrow)
                        .font(.system(size: 8, weight: .bold))
                    Text("\(sign)\(Int(d.rounded()))")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundStyle(improved == true ? Color(hex: 0x22C55E) : Color(hex: 0xEF4444))
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.2), lineWidth: 1))
        )
    }

    // MARK: - HealthKit Fetch

    private func fetchMetrics() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        fetchLatestSample(type: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) { today, yesterday in
            self.todayHRV = today
            self.yesterdayHRV = yesterday
        }
        fetchLatestSample(type: .restingHeartRate, unit: .count().unitDivided(by: .minute())) { today, yesterday in
            self.todayRHR = today
            self.yesterdayRHR = yesterday
        }
    }

    private func fetchLatestSample(
        type quantityTypeId: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping @MainActor (Double?, Double?) -> Void
    ) {
        let quantityType = HKQuantityType(quantityTypeId)
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
            if let error { AppLogger.healthKit.warning("Watch \(quantityTypeId.rawValue) query failed: \(error.localizedDescription)") }
            guard let samples = samples as? [HKQuantitySample] else {
                Task { @MainActor in completion(nil, nil) }
                return
            }
            var todayValue: Double?
            var yesterdayValue: Double?
            for sample in samples {
                let sampleDay = cal.startOfDay(for: sample.startDate)
                let value = sample.quantity.doubleValue(for: unit)
                if sampleDay >= startOfToday, todayValue == nil {
                    todayValue = value
                } else if sampleDay >= startOfYesterday, sampleDay < startOfToday, yesterdayValue == nil {
                    yesterdayValue = value
                }
                if todayValue != nil && yesterdayValue != nil { break }
            }
            Task { @MainActor in completion(todayValue, yesterdayValue) }
        }
        healthStore.execute(query)
    }
}

// MARK: - Preview

#Preview {
    let vm = WatchViewModel()
    return WatchInsightFlowView()
        .environmentObject(vm)
}

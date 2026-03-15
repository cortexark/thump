// WatchInsightFlowView.swift
// Thump Watch
//
// 5 swipeable screens — engagement first, stats never.
//
//   1. Today's Plan    — buddy + big GO shortcut. Pending → active → conquered.
//   2. Activity        — Walk / Run as two large equal tiles. Tap launches Apple Workout.
//   3. Stress          — 7-day heat-map dots + compact Breathe button.
//   4. Sleep           — last night hours + wind-down time + bedtime reminder.
//   5. Metrics         — HRV + RHR tiles with trend delta and action-oriented interpretation.
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
    @State private var nudgeInProgress = false
    private let totalTabs = 6

    private var assessment: HeartAssessment {
        viewModel.latestAssessment ?? InsightMockData.demoAssessment
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            planScreen.tag(0)
            walkNudgeScreen.tag(1)
            goalProgressScreen.tag(2)
            stressScreen.tag(3)
            sleepScreen.tag(4)
            metricsScreen.tag(5)
        }
        .tabViewStyle(.page)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Screen 1: Today's Plan

    private var planScreen: some View {
        let mood: BuddyMood = {
            if viewModel.nudgeCompleted { return .conquering }
            if nudgeInProgress { return .active }
            return BuddyMood.from(assessment: assessment)
        }()

        return PlanScreen(
            buddy: mood,
            nudge: assessment.dailyNudge,
            cardioScore: assessment.cardioScore,
            nudgeCompleted: viewModel.nudgeCompleted,
            nudgeInProgress: nudgeInProgress,
            onStart: {
                // Mark in-progress so buddy face and pulse ring animate.
                // Conquered state is set externally when a real workout completes.
                withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                    nudgeInProgress = true
                }
            }
        )
        .tag(0)
    }

    // MARK: - Screen 2: Walk nudge — emoji + today's step count

    private var walkNudgeScreen: some View {
        WalkNudgeScreen(nudge: assessment.dailyNudge)
            .tag(1)
    }

    // MARK: - Screen 3: Goal progress — activity remaining + start

    private var goalProgressScreen: some View {
        GoalProgressScreen(
            nudge: assessment.dailyNudge,
            nudgeInProgress: nudgeInProgress,
            nudgeCompleted: viewModel.nudgeCompleted,
            onStart: {
                withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                    nudgeInProgress = true
                }
                let url = workoutAppURL(for: assessment.dailyNudge.category)
                if let url { WKExtension.shared().openSystemURL(url) }
            }
        )
        .tag(2)
    }

    // MARK: - Screen 4: Stress + Breathe

    private var stressScreen: some View {
        StressScreen(isStressed: assessment.stressFlag)
            .tag(3)
    }

    // MARK: - Screen 5: Sleep

    private var sleepScreen: some View {
        let needsRest = assessment.status == .needsAttention || assessment.stressFlag
        return SleepScreen(needsRest: needsRest)
            .tag(4)
    }

    // MARK: - Screen 6: Heart Metrics

    private var metricsScreen: some View {
        HeartMetricsScreen()
            .tag(5)
    }

    // MARK: - Helpers

    /// Returns the Apple Workout deep-link URL for a given nudge category.
    private func workoutAppURL(for category: NudgeCategory) -> URL? {
        switch category {
        case .walk:     return URL(string: "workout://startWorkout?activityType=52")
        case .moderate: return URL(string: "workout://startWorkout?activityType=37")
        default:        return URL(string: "workout://")
        }
    }
}

// MARK: - Mock Data

enum InsightMockData {
    /// Mid-day walk nudge used when no phone assessment has arrived yet.
    /// Shows "Yet to Begin" state on Screen 1, realistic step progress on Screen 2,
    /// and 12 min remaining on Screen 3.
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

// ─────────────────────────────────────────
// MARK: - Screen 1: Plan
// ─────────────────────────────────────────

/// Screen 1: Today's goal in three explicit states.
///   • Yet to Begin  — idle buddy + goal chip + START button
///   • In Progress   — pulsing ring around buddy + "Active" label
///   • Complete      — flag pop + "Goal Done!" + streak message
private struct PlanScreen: View {

    let buddy: BuddyMood
    let nudge: DailyNudge
    let cardioScore: Double?
    let nudgeCompleted: Bool
    let nudgeInProgress: Bool
    let onStart: () -> Void

    @State private var appeared = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    @State private var completeScale: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Cardio score chip at top — hidden during sleep hours
            if !nudgeCompleted && !isSleepHour, let score = cardioScore {
                scoreChip(score)
                    .opacity(appeared ? 1 : 0)
                Spacer(minLength: 4)
            }

            buddyWithState
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 8)

            stateContent
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(nudge.category.tintColorName).gradient.opacity(0.08), for: .tabView)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) { appeared = true }
            if nudgeInProgress { startPulse() }
            if nudgeCompleted { startCompleteAnimation() }
        }
        .onChange(of: nudgeInProgress) { _, inProgress in
            if inProgress { startPulse() } else { stopPulse() }
        }
        .onChange(of: nudgeCompleted) { _, done in
            if done { startCompleteAnimation() }
        }
    }

    // MARK: - Score chip

    private func scoreChip(_ score: Double) -> some View {
        let scoreInt = Int(score)
        let chipColor: Color = scoreInt >= 80 ? Color(hex: 0x22C55E)
            : scoreInt >= 60 ? Color(hex: 0xF59E0B)
            : Color(hex: 0xEF4444)
        let label = scoreInt >= 80 ? "Heart \(scoreInt)" : scoreInt >= 60 ? "Score \(scoreInt)" : "Score \(scoreInt) ↓"
        return HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(chipColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(chipColor.opacity(0.15)))
    }

    // MARK: - Buddy with state ring

    @ViewBuilder
    private var buddyWithState: some View {
        ZStack {
            if nudgeInProgress {
                // Pulsing ring — shows activity is happening
                Circle()
                    .stroke(Color(nudge.category.tintColorName).opacity(pulseOpacity), lineWidth: 3)
                    .frame(width: 74, height: 74)
                    .scaleEffect(pulseScale)
            }
            ThumpBuddy(
                mood: buddy, size: 60,
                showAura: nudgeCompleted
            )
            .scaleEffect(nudgeCompleted ? completeScale : 1.0)
        }
    }

    // MARK: - State content

    @ViewBuilder
    private var stateContent: some View {
        if nudgeCompleted {
            // ── Complete ──
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Goal Done!")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Color(hex: 0xEAB308))

                Text("Streak alive. See you tomorrow.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else if nudgeInProgress {
            // ── In Progress ──
            VStack(spacing: 6) {
                Text(inProgressMessage)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(nudge.category.tintColorName))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)

                Text(nudgeLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        } else if isSleepHour {
            // ── Sleep / Tomorrow mode ──
            // No button. No nudge to start. Show tomorrow's plan quietly.
            VStack(spacing: 6) {
                Text(pushMessage)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)

                Spacer(minLength: 6)

                // Tomorrow's goal preview card
                HStack(spacing: 6) {
                    Image(systemName: nudge.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x6366F1))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tomorrow")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(nudge.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0x6366F1).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12)
            }
        } else {
            // ── Yet to Begin ──
            VStack(spacing: 7) {
                // Dynamic time-aware push message
                Text(pushMessage)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)

                // Goal action button — label and colour shift with time-of-day urgency
                Button(action: onStart) {
                    HStack(spacing: 5) {
                        Image(systemName: nudge.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(actionButtonLabel)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(buttonColor)
                    )
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Dynamic messaging helpers

    /// True during sleep hours (10 PM – 4:59 AM) when exercise nudges are inappropriate.
    private var isSleepHour: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 22 || hour < 5
    }

    private var pushMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let score = cardioScore ?? 70
        if isSleepHour {
            return score < 60 ? "Rest well — sleep is your recovery tonight." : "Rest up. Tomorrow is a fresh start."
        }
        switch hour {
        case 5..<9:
            return score >= 75 ? "Good morning. Your body is ready." : "Start the day with a win."
        case 9..<12:
            return "Morning window is open — great time to move."
        case 12..<14:
            return "Midday break is perfect for your goal."
        case 14..<17:
            return score < 65 ? "Your numbers are lower today. Even a short session helps." : "Afternoon energy is up — move now."
        case 17..<20:
            return "Evening is a great time for your \(nudgeActivityWord.lowercased())."
        default:
            return "There's still time for a quick session tonight."
        }
    }

    private var actionButtonLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if isSleepHour { return "Good Night" }
        switch hour {
        case 5..<12:  return "Start \(nudgeActivityWord)"
        case 12..<17: return "Go Now"
        case 17..<20: return "Do It"
        default:      return "Finish It"
        }
    }

    private var buttonColor: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        if isSleepHour { return Color(hex: 0x4B5563) }  // muted grey at night
        if hour < 17 { return Color(nudge.category.tintColorName) }
        if hour < 20 { return Color(hex: 0xF59E0B) }
        return Color(hex: 0xEF4444)
    }

    private var inProgressMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if isSleepHour { return "Sleep is your workout now" }
        switch hour {
        case 5..<12:  return "Morning move underway"
        case 12..<14: return "Midday goal — keep going"
        case 14..<18: return "Afternoon push — stay with it"
        case 18..<21: return "Evening streak — nearly there"
        default:      return "In progress — keep it up"
        }
    }

    private var nudgeActivityWord: String {
        switch nudge.category {
        case .walk:     return "Walk"
        case .moderate: return "Run"
        case .breathe:  return "Breathe"
        case .rest:     return "Stretch"
        default:        return "Activity"
        }
    }

    // MARK: - Animations

    private func startPulse() {
        withAnimation(
            .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.18
            pulseOpacity = 0.0
        }
    }

    private func stopPulse() {
        pulseScale = 1.0
        pulseOpacity = 0.6
    }

    private func startCompleteAnimation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            completeScale = 1.12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.3)) { completeScale = 1.0 }
        }
    }

    private var nudgeLabel: String {
        guard let dur = nudge.durationMinutes else { return nudge.title }
        switch nudge.category {
        case .walk:     return "Walk \(dur) min"
        case .breathe:  return "Breathe \(dur) min"
        case .moderate: return "Run \(dur) min"
        case .rest:     return "Stretch \(dur) min"
        case .hydrate:  return "Hydrate"
        case .sunlight: return "Get outside"
        default:        return "\(dur) min activity"
        }
    }
}

// ─────────────────────────────────────────
// MARK: - Screen 2: Walk nudge
// ─────────────────────────────────────────

/// Screen 2: Walk nudge card — emoji, live step count, and a contextual
/// "Feeling up for a little extra?" prompt that adapts to step count and time.
private struct WalkNudgeScreen: View {

    let nudge: DailyNudge

    @State private var appeared = false
    @State private var stepCount: Int? = nil
    private let healthStore = HKHealthStore()

    private var activityEmoji: String {
        switch nudge.category {
        case .walk:     return "🚶"
        case .moderate: return "🏃"
        case .breathe:  return "🧘"
        case .rest:     return "😴"
        case .hydrate:  return "💧"
        case .sunlight: return "☀️"
        default:        return "🏃"
        }
    }

    private var workoutURL: URL? {
        switch nudge.category {
        case .moderate: return URL(string: "workout://startWorkout?activityType=37")
        default:        return URL(string: "workout://startWorkout?activityType=52")
        }
    }

    private var isSleepHour: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 22 || h < 5
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Big activity emoji
            Text(activityEmoji)
                .font(.system(size: 48))
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)

            Spacer(minLength: 6)

            if isSleepHour {
                // ── Tomorrow's plan hint ──
                Text("Tomorrow's Plan")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 3)

                Text(nudge.title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 8)

                Text("Sleep now, move tomorrow.\nYour goal resets at sunrise.")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .opacity(appeared ? 1 : 0)

            } else {
                // ── Active nudge content ──
                Text(nudge.title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 4)

                stepRow
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 8)

                extraNudgeRow
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 10)

                Button {
                    if let url = workoutURL {
                        WKExtension.shared().openSystemURL(url)
                    }
                } label: {
                    Text(startButtonLabel)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: 0x22C55E))
                        )
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(hex: 0x22C55E).gradient.opacity(0.08), for: .tabView)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) { appeared = true }
            fetchStepCount()
        }
    }

    // MARK: - Step row

    @ViewBuilder
    private var stepRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "shoeprints.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: 0x22C55E))
            if let steps = stepCount {
                Text("\(steps.formatted()) steps today")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text("Counting steps…")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - "Feeling up for extra?" contextual nudge

    @ViewBuilder
    private var extraNudgeRow: some View {
        let steps = stepCount ?? 0
        let hour = Calendar.current.component(.hour, from: Date())
        let message = extraNudgeMessage(steps: steps, hour: hour)

        Text(message)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(Color(hex: 0x22C55E).opacity(0.8))
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
    }

    /// Returns a contextual message that changes based on step count and time-of-day.
    /// Never shows the same static text — always reflects the user's current state.
    private func extraNudgeMessage(steps: Int, hour: Int) -> String {
        switch (steps, hour) {
        case (0..<1000, 5..<10):
            return "Early in the day — an easy win is waiting."
        case (0..<1000, 10..<14):
            return "Steps are low. A short walk fixes that fast."
        case (0..<1000, 14...):
            return "Under 1,000 steps so far. A short walk makes a difference."
        case (1000..<4000, 5..<12):
            return "Decent start. Keep the morning momentum."
        case (1000..<4000, 12..<18):
            return "On track — feeling up for a little extra?"
        case (1000..<4000, 18...):
            return "Still time to add a few more steps tonight."
        case (4000..<7000, _):
            return "Good pace. Another 15 min puts you above average."
        case (7000..<10000, _):
            return "Almost at 10K. One more walk seals it."
        default:
            return steps >= 10000
                ? "10K+ done. You're already ahead today."
                : "Feeling up for a little extra today?"
        }
    }

    private var startButtonLabel: String {
        let steps = stepCount ?? 0
        if steps >= 8000 { return "Beat Yesterday" }
        if steps >= 4000 { return "Keep Going" }
        return "Start \(nudge.category == .moderate ? "Run" : "Walk")"
    }

    // MARK: - HealthKit: today's step count

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
        ) { _, result, _ in
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

// ─────────────────────────────────────────
// MARK: - Screen 3: Goal progress
// ─────────────────────────────────────────

/// Screen 3: Shows how much activity is left in today's goal,
/// a compact progress ring, and a "Start Activity" button.
private struct GoalProgressScreen: View {

    let nudge: DailyNudge
    let nudgeInProgress: Bool
    let nudgeCompleted: Bool
    let onStart: () -> Void

    @State private var appeared = false
    /// Minutes of activity logged today toward the nudge goal.
    @State private var minutesDone: Int = 0
    private let healthStore = HKHealthStore()

    private var goalMinutes: Int { nudge.durationMinutes ?? 15 }
    private var minutesLeft: Int { max(0, goalMinutes - minutesDone) }
    private var progress: Double { min(1.0, Double(minutesDone) / Double(goalMinutes)) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Progress ring + centre text
            ZStack {
                Circle()
                    .stroke(Color(hex: 0x22C55E).opacity(0.18), lineWidth: 8)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: appeared ? progress : 0)
                    .stroke(
                        nudgeCompleted ? Color(hex: 0xEAB308) : Color(hex: 0x22C55E),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: appeared)

                VStack(spacing: 1) {
                    if nudgeCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color(hex: 0xEAB308))
                    } else {
                        Text("\(minutesLeft)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("min left")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 8)

            // Status label
            Group {
                if nudgeCompleted {
                    Text("Goal complete!")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0xEAB308))
                } else if nudgeInProgress {
                    Text("Activity in progress")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0x22C55E))
                } else {
                    Text(nudge.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 4)

            // Sub-label: e.g. "3 of 15 min done"
            if !nudgeCompleted {
                Text("\(minutesDone) of \(goalMinutes) min done")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 10)

            // Start button — hidden when complete or during sleep hours
            if !nudgeCompleted {
                let sleepHour = { () -> Bool in
                    let h = Calendar.current.component(.hour, from: Date())
                    return h >= 22 || h < 5
                }()
                Group {
                    if sleepHour {
                        Text("Rest up — pick this up tomorrow")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                    } else {
                        Button(action: onStart) {
                            Text(nudgeInProgress ? "Resume Activity" : "Start Activity")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(nudgeInProgress
                                            ? Color(hex: 0xF59E0B)
                                            : Color(hex: 0x22C55E))
                                )
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(hex: 0x22C55E).gradient.opacity(0.07), for: .tabView)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { appeared = true }
            fetchActivityMinutes()
        }
    }

    // MARK: - HealthKit: minutes of exercise today

    private func fetchActivityMinutes() {
        guard HKHealthStore.isHealthDataAvailable() else {
            minutesDone = mockMinutesDone()
            return
        }
        let type = HKQuantityType(.appleExerciseTime)
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let mins = result?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
            Task { @MainActor in
                self.minutesDone = mins > 0 ? Int(mins) : self.mockMinutesDone()
            }
        }
        healthStore.execute(query)
    }

    /// Realistic mid-day exercise minutes for simulator.
    private func mockMinutesDone() -> Int {
        let hour = Calendar.current.component(.hour, from: Date())
        // Assume ~2 min of exercise per active hour after 8 AM
        let done = max(0, (hour - 8) * 2 + 3)
        return min(done, goalMinutes - 1)  // always leaves at least 1 min left
    }
}

// ─────────────────────────────────────────
// MARK: - Screen 3: Stress
// ─────────────────────────────────────────

/// Stress screen: buddy state + 12-hour hourly heart-rate heatmap fetched live from HealthKit.
///
/// Each column represents one hour (oldest left → now right). The dot's color encodes
/// how far that hour's average HR was above the user's resting HR baseline:
///   • Green  → at/below resting (calm)
///   • Amber  → moderately elevated
///   • Red    → notably elevated
/// The current-hour column has a white ring so "now" is always obvious.
/// Hours with no data render as dim placeholders.
private struct StressScreen: View {

    let isStressed: Bool

    // MARK: - State

    @State private var appeared = false
    /// Average heart rate per hour slot. Index 0 = 11 hours ago, index 11 = current hour.
    /// nil = no data for that slot.
    @State private var hourlyHR: [Double?] = Array(repeating: nil, count: 12)
    /// User's resting HR baseline, derived from the last available resting HR sample.
    @State private var restingHR: Double = 70

    private let healthStore = HKHealthStore()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)

            // Buddy — stressed or calm
            ThumpBuddy(mood: isStressed ? .stressed : .content, size: 46, showAura: false)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 4)

            // State label
            Text(isStressed ? "Stress is up" : "Calm today")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 8)

            // 12-hour hourly HR heatmap
            hourlyHeatMap
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 10)

            // Compact Breathe shortcut
            Button {
                if let url = URL(string: "mindfulness://") {
                    WKExtension.shared().openSystemURL(url)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "wind")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Breathe")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color(hex: 0x0D9488))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color(hex: 0x0D9488).opacity(0.18))
                        .overlay(
                            Capsule().stroke(Color(hex: 0x0D9488).opacity(0.4), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(
            (isStressed ? Color(hex: 0xF59E0B) : Color(hex: 0x0D9488)).gradient.opacity(0.08),
            for: .tabView
        )
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { appeared = true }
            fetchHourlyHeartRate()
        }
    }

    // MARK: - Hourly Heatmap

    /// 2-row × 6-column grid of dots with hour labels underneath each dot.
    /// Row 0 = slots 0-5 (hours −11…−6), row 1 = slots 6-11 (hours −5…now).
    /// Green = calm, orange = elevated, dim ring = no data.
    private var hourlyHeatMap: some View {
        let now = Date()
        let cal = Calendar.current
        let currentHour = cal.component(.hour, from: now)
        let rows = [[0, 1, 2, 3, 4, 5], [6, 7, 8, 9, 10, 11]]

        return VStack(spacing: 4) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { slotIndex in
                        let isNow = slotIndex == 11
                        let hoursAgo = 11 - slotIndex
                        let hour = (currentHour - hoursAgo + 24) % 24
                        let avgHR = hourlyHR[slotIndex]
                        dotWithLabel(avgHR: avgHR, isNow: isNow, hour: hour)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dotWithLabel(avgHR: Double?, isNow: Bool, hour: Int) -> some View {
        VStack(spacing: 2) {
            // Dot
            ZStack {
                if let hr = avgHR {
                    let elevation = hr - restingHR
                    let color: Color = elevation < 5
                        ? Color(hex: 0x22C55E)
                        : Color(hex: 0xF59E0B)
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                    if isNow {
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                            .frame(width: 16, height: 16)
                    }
                } else {
                    // No data — dim empty ring placeholder
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        .frame(width: 10, height: 10)
                }
            }
            .frame(width: 18, height: 18)

            // Hour label: "2p", "3p", "now"
            Text(isNow ? "now" : hourLabel(hour))
                .font(.system(size: 7, weight: isNow ? .heavy : .regular, design: .monospaced))
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

    /// Fetches heart-rate samples for the last 12 hours and buckets them by hour.
    /// Also reads the most recent resting HR sample to use as the calm baseline.
    private func fetchHourlyHeartRate() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        fetchRestingHR()
        fetchHRSamples()
    }

    /// Reads the latest resting HR value to use as the calm baseline.
    private func fetchRestingHR() {
        let type = HKQuantityType(.restingHeartRate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            guard let sample = (samples as? [HKQuantitySample])?.first else { return }
            let bpm = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            Task { @MainActor in
                self.restingHR = bpm
            }
        }
        healthStore.execute(query)
    }

    /// Fetches all HR samples from the last 12 hours and averages them per hour slot.
    private func fetchHRSamples() {
        let type = HKQuantityType(.heartRate)
        let now = Date()
        let start = now.addingTimeInterval(-12 * 3600)
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: now, options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                // No HealthKit data (simulator) — seed realistic circadian mock values
                Task { @MainActor in
                    withAnimation(.easeIn(duration: 0.4)) {
                        self.hourlyHR = Self.mockHourlyHR(restingHR: self.restingHR, now: now)
                    }
                }
                return
            }

            let cal = Calendar.current
            let currentHour = cal.component(.hour, from: now)
            let unit = HKUnit.count().unitDivided(by: .minute())

            // Bucket samples into 12 slots: slot i covers the hour that is (11-i) hours ago
            var buckets: [[Double]] = Array(repeating: [], count: 12)
            for sample in samples {
                let sampleHour = cal.component(.hour, from: sample.startDate)
                // Map sampleHour to a slot 0…11
                let hoursAgo = (currentHour - sampleHour + 24) % 24
                guard hoursAgo < 12 else { continue }
                let slotIndex = 11 - hoursAgo
                let bpm = sample.quantity.doubleValue(for: unit)
                buckets[slotIndex].append(bpm)
            }

            let averages: [Double?] = buckets.map { readings in
                readings.isEmpty ? nil : readings.reduce(0, +) / Double(readings.count)
            }

            Task { @MainActor in
                withAnimation(.easeIn(duration: 0.4)) {
                    self.hourlyHR = averages
                }
            }
        }
        healthStore.execute(query)
    }

    /// Generates realistic circadian HR mock values for the last 12 hours.
    /// Used when HealthKit returns no data (e.g., simulator).
    private static func mockHourlyHR(restingHR: Double, now: Date) -> [Double?] {
        let cal = Calendar.current
        let currentHour = cal.component(.hour, from: now)

        // Real observed avg HR per hour from Apple Watch data (Mar 11 2026).
        // Hours 20–23 are unrecorded that day; filled with a light taper from resting.
        let realHourlyAvg: [Int: Double] = [
            0: 62.7, 1: 63.1, 2: 56.5, 3: 57.6, 4: 56.2, 5: 50.4,
            6: 53.9, 7: 55.3, 8: 60.0, 9: 58.9, 10: 68.1, 11: 68.5,
            12: 67.3, 13: 65.3, 14: 88.3, 15: 76.3, 16: 85.8, 17: 99.7,
            18: 99.8, 19: 141.5,
            // Taper estimate for unrecorded late-evening hours
            20: 85.0, 21: 75.0, 22: 68.0, 23: 64.0
        ]

        return (0..<12).map { slot in
            let hoursAgo = 11 - slot
            let hour = (currentHour - hoursAgo + 24) % 24
            return realHourlyAvg[hour] ?? restingHR
        }
    }
}

// ─────────────────────────────────────────
// MARK: - Screen 4: Sleep
// ─────────────────────────────────────────

/// Shows last night's sleep hours from HealthKit, a suggested bedtime,
/// and a bedtime reminder button. All data is fetched locally on the watch.
private struct SleepScreen: View {

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    let needsRest: Bool

    @State private var appeared = false
    @State private var reminderSet = false
    /// Last 3 nights' sleep hours fetched from HealthKit (oldest first).
    @State private var recentSleepHours: [Double] = []

    /// True when all 3 recent nights were under 6.5 hours — flags a sleep debt trend.
    private var hasSleepTrend: Bool {
        guard recentSleepHours.count >= 3 else { return false }
        return recentSleepHours.suffix(3).allSatisfy { $0 < 6.5 }
    }

    /// Formatted streak count, e.g. "3 nights".
    private var streakLabel: String {
        let count = recentSleepHours.suffix(3).filter { $0 < 6.5 }.count
        return "\(count) nights"
    }
    /// Last night's total sleep in hours, loaded from HealthKit.
    @State private var lastNightHours: Double? = nil
    /// The wake-up time inferred from the last sleep sample end date.
    @State private var wakeTime: Date? = nil

    private let healthStore = HKHealthStore()

    // MARK: - Time mode

    private var hour: Int { Calendar.current.component(.hour, from: Date()) }

    /// 10 PM – 4:59 AM: user should be asleep, suppress all activity CTAs.
    private var isSleepTime: Bool { hour >= 22 || hour < 5 }

    /// 9 PM – 9:59 PM: wind-down window, shift tone to calm.
    private var isWindDown: Bool { hour == 21 }

    private var sleepHeadline: String {
        if isSleepTime {
            return hasSleepTrend ? "Building a better streak" : (needsRest ? "Sleep well tonight" : "Rest & recover")
        } else if isWindDown {
            return "Wind down soon"
        } else {
            return needsRest ? "Sleep more tonight" : "Well rested"
        }
    }

    private var sleepSubMessage: String? {
        if isSleepTime {
            if hasSleepTrend {
                return "Sleep has been light for \(streakLabel). An earlier bedtime tonight could help."
            }
            return needsRest
                ? "Sleep is where recovery happens. Every hour counts."
                : "Tonight's rest locks in today's progress. Sleep well."
        } else if isWindDown {
            return "Wind-down time — a calm evening sets up a good tomorrow."
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 2)

            ThumpBuddy(
                mood: isSleepTime ? .tired : (needsRest ? .tired : .content),
                size: 44,
                showAura: false
            )
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 4)

            Text(sleepHeadline)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .opacity(appeared ? 1 : 0)

            if let sub = sleepSubMessage {
                Spacer(minLength: 4)
                Text(sub)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .opacity(appeared ? 1 : 0)
            }

            // Trend warning pill — only during sleep hours when streak detected
            if isSleepTime && hasSleepTrend {
                Spacer(minLength: 6)
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF59E0B))
                    Text("Poor sleep \(streakLabel) in a row")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xF59E0B))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: 0xF59E0B).opacity(0.12), in: Capsule())
                .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 6)

            // ── Sleep stats row: last night + target bedtime ──
            // Hidden during sleep hours (nothing useful to show yet)
            if !isSleepTime {
                HStack(spacing: 10) {
                    sleepStatCell(
                        label: "Last night",
                        value: lastNightHours.map { formattedHours($0) } ?? "–",
                        icon: "moon.fill",
                        color: Color(hex: 0x818CF8)
                    )
                    Divider()
                        .frame(height: 28)
                        .opacity(0.3)
                    sleepStatCell(
                        label: "Target bed",
                        value: targetBedtime,
                        icon: "bed.double.fill",
                        color: Color(hex: 0x6366F1)
                    )
                }
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 8)

                // Bedtime reminder button — day & wind-down only
                Button {
                    withAnimation(.spring(duration: 0.3)) { reminderSet.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: reminderSet ? "checkmark.circle.fill" : "moon.zzz.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(reminderSet ? "Reminder set" : "Remind me at bedtime")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(reminderSet ? Color(hex: 0x22C55E) : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(reminderSet
                                  ? Color(hex: 0x22C55E).opacity(0.2)
                                  : Color(hex: 0x6366F1))
                    )
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(hex: 0x6366F1).gradient.opacity(0.08), for: .tabView)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { appeared = true }
            fetchLastNightSleep()
            fetchRecentSleepHistory()
        }
    }

    // MARK: - Sleep Stat Cell

    private func sleepStatCell(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed helpers

    /// Target bedtime: 8 hours before yesterday's wake time, or "10:00 PM" as a sensible default.
    private var targetBedtime: String {
        let cal = Calendar.current
        if let wake = wakeTime {
            // Target = wake time shifted back by 8 hours (same tonight)
            let target = wake.addingTimeInterval(-8 * 3600)
            return formatTime(target)
        }
        // Fallback: 10 PM tonight
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 22; comps.minute = 0
        return cal.date(from: comps).map { formatTime($0) } ?? "10:00 PM"
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

    // MARK: - HealthKit fetch

    /// Reads last night's sleep samples (yesterday 6 PM → today noon) from HealthKit.
    private func fetchLastNightSleep() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let sleepType = HKCategoryType(.sleepAnalysis)

        // Check authorization status without requesting (watch app reads, iOS grants)
        let status = healthStore.authorizationStatus(for: sleepType)
        guard status == .sharingAuthorized else {
            // Try to read anyway — watch may have read-only access granted by the paired iPhone
            performSleepQuery()
            return
        }
        performSleepQuery()
    }

    private func performSleepQuery() {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        let now = Date()
        // Window: yesterday at 6 PM → today at noon
        let startOfToday = cal.startOfDay(for: now)
        let windowStart = startOfToday.addingTimeInterval(-18 * 3600) // 6 PM yesterday
        let windowEnd   = startOfToday.addingTimeInterval(12 * 3600)  // noon today

        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: windowEnd,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else { return }

            // Sum only asleep stages
            let asleepValues = HKCategoryValueSleepAnalysis.allAsleepValues.map { $0.rawValue }
            let asleepSamples = samples.filter { asleepValues.contains($0.value) }
            let totalSeconds = asleepSamples.reduce(0.0) { acc, s in
                acc + s.endDate.timeIntervalSince(s.startDate)
            }
            let hours = totalSeconds / 3600

            // Latest end date = when they woke up
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

    /// Fetches the last 3 nights' sleep totals from HealthKit for trend detection.
    private func fetchRecentSleepHistory() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let sleepType = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        let now = Date()
        // Go back 4 days to capture 3 full nights
        let windowStart = cal.date(byAdding: .day, value: -4, to: cal.startOfDay(for: now))!
        let windowEnd = cal.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart, end: windowEnd, options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else { return }

            let asleepValues = HKCategoryValueSleepAnalysis.allAsleepValues.map { $0.rawValue }
            let asleepSamples = samples.filter { asleepValues.contains($0.value) }

            // Bucket by night (use the start date's calendar day)
            var nightBuckets: [Date: Double] = [:]
            for sample in asleepSamples {
                let nightDate = cal.startOfDay(for: sample.startDate)
                let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                nightBuckets[nightDate, default: 0] += duration
            }

            // Sort by date, take last 3 nights
            let sortedNights = nightBuckets.sorted { $0.key < $1.key }
                .suffix(3)
                .map { $0.value }

            Task { @MainActor in
                self.recentSleepHours = sortedNights
            }
        }
        healthStore.execute(query)
    }
}

// ─────────────────────────────────────────
// MARK: - Screen 6: Heart Metrics
// ─────────────────────────────────────────

/// Screen 6: HRV + RHR tiles with trend direction and an action-oriented
/// one-liner that connects the metric to what it means for today's behaviour.
///
/// Interpretation logic:
///   HRV ↑  →  "Better recovery — yesterday's effort is paying off"
///   HRV ↓  →  "Take it easy — your body is still catching up"
///   RHR ↓  →  "Intensity was good — heart is less stressed today"
///   RHR ↑  →  "Take it easy — your heart is still working"
private struct HeartMetricsScreen: View {

    @State private var todayHRV: Double?
    @State private var todayRHR: Double?
    @State private var yesterdayHRV: Double?
    @State private var yesterdayRHR: Double?

    @State private var appeared = false
    private let healthStore = HKHealthStore()

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)

            Text("Heart Metrics")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .opacity(appeared ? 1 : 0)

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                metricTile(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    unit: "ms",
                    value: todayHRV,
                    previous: yesterdayHRV,
                    higherIsBetter: true
                )
                metricTile(
                    icon: "heart.fill",
                    label: "RHR",
                    unit: "bpm",
                    value: todayRHR,
                    previous: yesterdayRHR,
                    higherIsBetter: false
                )
            }
            .padding(.horizontal, 8)
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(hex: 0xEC4899).gradient.opacity(0.07), for: .tabView)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) { appeared = true }
            fetchMetrics()
        }
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

    /// Fetches the most recent sample for today and yesterday for a given quantity type.
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

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfYesterday, end: now, options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: quantityType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, _ in
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

    // MARK: - Metric tile

    private func metricTile(
        icon: String,
        label: String,
        unit: String,
        value: Double?,
        previous: Double?,
        higherIsBetter: Bool
    ) -> some View {
        let delta: Double? = {
            guard let v = value, let p = previous else { return nil }
            return v - p
        }()
        let improved: Bool? = delta.map { higherIsBetter ? $0 > 0 : $0 < 0 }
        let tileColor = tileAccent(label: label, improved: improved)

        return VStack(alignment: .leading, spacing: 6) {
            // Top row: icon + label + value + arrow + delta
            HStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tileColor)

                Text("  \(label)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                if let v = value {
                    Text("\(Int(v.rounded()))")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(" \(unit)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .alignmentGuide(.firstTextBaseline) { d in d[.lastTextBaseline] }
                } else {
                    Text("—")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let d = delta {
                    let sign = d > 0 ? "+" : ""
                    let arrow = d > 0 ? "arrow.up" : "arrow.down"
                    HStack(spacing: 2) {
                        Image(systemName: arrow)
                            .font(.system(size: 9, weight: .bold))
                        Text("\(sign)\(Int(d.rounded()))")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(improved == true ? Color(hex: 0x22C55E) : Color(hex: 0xEF4444))
                    .padding(.leading, 4)
                }
            }

            // Interpretation — action-oriented one-liner
            Text(interpretation(label: label, delta: delta, higherIsBetter: higherIsBetter))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tileColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Interpretation logic

    /// Action-oriented sentence: metric + direction → consequence for TODAY.
    private func interpretation(label: String, delta: Double?, higherIsBetter: Bool) -> String {
        guard let d = delta else {
            return label == "HRV"
                ? "Track your recovery over time."
                : "Compare daily to spot trends."
        }
        let improved = higherIsBetter ? d > 0 : d < 0
        let magnitude = abs(d)

        if label == "HRV" {
            if improved {
                return magnitude >= 5
                    ? "Better recovery — yesterday's effort is paying off."
                    : "Slight recovery gain — body is adapting."
            } else {
                return magnitude >= 5
                    ? "Take it easy — your body is still catching up."
                    : "Minor dip — keep today's effort moderate."
            }
        } else {
            // RHR
            if improved {
                return magnitude >= 3
                    ? "Intensity was good — heart is less stressed today."
                    : "Heart is settling — good sign."
            } else {
                return magnitude >= 3
                    ? "Take it easy — your heart is still working."
                    : "Slight rise — watch your load today."
            }
        }
    }

    // MARK: - Accent colour

    private func tileAccent(label: String, improved: Bool?) -> Color {
        if label == "HRV" {
            return improved == true ? Color(hex: 0x22C55E)
                : improved == false ? Color(hex: 0xF59E0B)
                : Color(hex: 0xA78BFA)
        } else {
            return improved == true ? Color(hex: 0x22C55E)
                : improved == false ? Color(hex: 0xEF4444)
                : Color(hex: 0xEC4899)
        }
    }
}

// MARK: - Preview

#Preview {
    let vm = WatchViewModel()
    return WatchInsightFlowView()
        .environmentObject(vm)
}

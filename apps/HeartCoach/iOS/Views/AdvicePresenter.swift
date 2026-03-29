// AdvicePresenter.swift
// Thump iOS
//
// Thin view-mapping layer that converts semantic AdviceState IDs
// to localized user-facing strings. This is the ONLY place
// user-facing coaching copy lives.
//
// Views call AdvicePresenter methods instead of computing text inline.
// Platforms: iOS 17+

import Foundation

// MARK: - Advice Presenter

/// Maps semantic AdviceState to user-facing strings.
///
/// All coaching copy originates here. Views never build
/// text from business logic directly.
struct AdvicePresenter {

    enum CopySurface {
        case standard
        case heroCompact
    }

    // MARK: - Hero Message

    /// Returns the hero banner message for the dashboard.
    static func heroMessage(for state: AdviceState, snapshot: HeartSnapshot) -> String {
        switch state.heroMessageID {
        case "hero_stress_high":
            return "Stress is above your baseline. Make today a recovery day."
        case "hero_rough_night":
            let hrs = snapshot.sleepHours.map { String(format: "%.1f", $0) } ?? "not enough"
            return "You got \(hrs) hrs last night. Keep today light with a 20 minute walk."
        case "hero_recovery_low":
            return "Recovery is below your 7 day norm. A lighter day helps you bounce back."
        case "hero_zone_overload":
            return "You trained hard lately. Backing off today helps gains stick."
        case "hero_recovered_relaxed":
            return "Sleep and recovery look solid. Good day to push a little."
        case "hero_charged":
            return "Heart rate sleep and recovery look strong. Good day for quality work."
        case "hero_decent":
            return "Recovery is near your norm. Moderate effort fits today."
        case "hero_lighter_day":
            return "Heart rate and recovery point to a lighter day. Your body is still repairing."
        case "hero_checkin":
            return "Today's readiness data is in."
        default:
            return "Today's readiness data is in."
        }
    }

    // MARK: - Focus Insight

    /// Returns the buddy focus insight text.
    ///
    /// The insight adds something different from the hero, a specific action,
    /// data context, or "why", so both surfaces give distinct value. Never
    /// copy-paste hero text here (V-006).
    static func focusInsight(
        for state: AdviceState,
        surface: CopySurface = .standard
    ) -> String? {
        let copy: String?
        switch state.focusInsightID {
        case "insight_stress_rest":
            copy = "Stress is high and HRV is down. Give your nervous system a recovery day."
        case "insight_rough_night":
            copy = "Sleep drives muscle and nervous system recovery. After a short night, keep movement easy for 15 to 20 minutes."
        case "insight_recovery_low":
            copy = "Recovery is below your norm. Easy movement helps your nervous system rebound faster."
        case "insight_zone_overload":
            copy = "You stacked hard sessions recently. Recovery today lets your nervous system adapt and come back stronger."
        case "insight_recovered":
            copy = "HRV and resting heart rate look strong. Your nervous system is recovered and ready for quality effort."
        case "insight_decent":
            copy = "Moderate effort fits today while your nervous system stays stable."
        case "insight_lighter_day":
            copy = "A lighter day now helps your nervous system recharge for tomorrow."
        case "insight_checkin":
            copy = nil
        default:
            copy = nil
        }

        guard surface == .heroCompact else { return copy }
        return compactFocusInsight(for: state.focusInsightID, fallback: copy)
    }

    private static func compactFocusInsight(for id: String, fallback: String?) -> String? {
        switch id {
        case "insight_stress_rest":
            return "Stress is high today, so keep it a recovery day."
        case "insight_rough_night":
            return "Sleep was short, so keep effort easy today."
        case "insight_recovery_low":
            return "Recovery is low, so choose easy movement today."
        case "insight_zone_overload":
            return "Training load is high, so take a lighter day."
        case "insight_recovered":
            return "Recovery looks strong, so quality effort fits today."
        case "insight_decent":
            return "Recovery is steady, so moderate effort fits today."
        case "insight_lighter_day":
            return "A lighter day now helps you recover tomorrow."
        default:
            return fallback
        }
    }

    // MARK: - Check Recommendation

    /// Returns the Thump Check recommendation based on readiness score and AdviceState.
    static func checkRecommendation(
        for state: AdviceState,
        readinessScore: Int,
        snapshot: HeartSnapshot
    ) -> String {
        let sleepHours = snapshot.sleepHours
        let policy = ConfigService.activePolicy

        // Sleep override (critical)
        if let hours = sleepHours {
            if hours < policy.view.sleepSkipWorkoutHours {
                return "Skip structured training today. Sleep debt this high slows recovery. Rest is the best move."
            }
            if hours < policy.view.sleepLightOnlyHours {
                return "Sleep was short. Keep today easy with a 20 minute walk. Save hard sessions for better rest."
            }
        }

        // Low recovery
        if readinessScore < 45 {
            if state.stressGuidanceLevel == .elevated {
                return "Recovery is low and stress is high. Take a full rest day or only a short easy walk."
            }
            return "Recovery is below your norm. A 20 minute walk or short stretch is enough today."
        }

        // Moderate recovery
        if readinessScore < 65 {
            if let hours = sleepHours, hours < 6.0 {
                return "Recovery is moderate but sleep was short. Keep effort moderate for 30 to 40 minutes."
            }
            if state.stressGuidanceLevel == .elevated {
                return "Stress is elevated. Keep effort light with a walk or stretch today."
            }
            return "Recovery is near your norm. A moderate session is a good choice today."
        }

        // Good recovery
        if readinessScore >= 80 {
            if let hours = sleepHours, hours < 6.0 {
                return "Recovery is strong but sleep was short. Keep it moderate and save hard effort for a full night."
            }
            return "Recovery and heart rate look strong. This is a good day to push."
        }

        if let hours = sleepHours, hours < 6.0 {
            return "Metrics are solid but sleep was short. Moderate effort is the smart middle ground."
        }

        return "Recovery is solid and trending above your baseline. A moderate-to-hard effort fits well today."
    }

    // MARK: - Recovery Narrative

    /// Returns a recovery narrative for the Recovery card.
    static func recoveryNarrative(for state: AdviceState) -> String? {
        guard let driver = state.recoveryDriver else {
            if state.mode == .pushDay {
                return "Recovery has been consistent this week. Trend is pointing up."
            }
            return "Recovery is tracking near your recent baseline. No significant flags."
        }

        switch driver {
        case .lowSleep:
            return "Sleep is below your norm. Prioritize tonight to lift tomorrow's readiness."
        case .lowHRV:
            return "HRV is below your recent range. Your nervous system is still recovering, so keep today easy."
        case .highStress:
            return "Stress is elevated. A short easy walk and earlier bedtime can help recovery tonight."
        case .overtraining:
            return "Recent training load is high. Rest today is where your body adapts."
        case .highRHR:
            return "Resting heart rate is above baseline. Keep effort easy while your nervous system settles."
        }
    }

    // MARK: - Stress Guidance

    /// Returns the stress guidance spec for the Stress screen.
    static func stressGuidance(
        for level: StressGuidanceLevel,
        readinessLevel: ReadinessLevel? = nil
    ) -> StressGuidanceSpec {
        switch level {
        case .relaxed:
            if readinessLevel == nil || readinessLevel == .recovering || readinessLevel == .moderate {
                return StressGuidanceSpec(
                    headline: "Stress Is Low, Recovery Is Still Building",
                    detail: "Stress is calm, but recovery is still catching up. Keep effort light and stay consistent today.",
                    icon: "leaf.fill",
                    colorName: "relaxed",
                    actions: ["Easy Walk", "Focus Time"]
                )
            }
            return StressGuidanceSpec(
                headline: "Stress Is Low Right Now",
                detail: "Stress and recovery are both favorable. Great window for focused work or a quality workout.",
                icon: "leaf.fill",
                colorName: "relaxed",
                actions: ["Workout", "Focus Time"]
            )
        case .balanced:
            return StressGuidanceSpec(
                headline: "Stress Is in a Workable Range",
                detail: "Stress is near your baseline. A 20 minute walk, light stretch, or short break helps keep it steady.",
                icon: "circle.grid.cross.fill",
                colorName: "balanced",
                actions: ["Take a Walk", "Stretch"]
            )
        case .elevated:
            return StressGuidanceSpec(
                headline: "Stress Is Up, Recovery Would Help",
                detail: "Stress is elevated and recovery needs help. Try slow breathing, a short walk, or a 10 minute break.",
                icon: "flame.fill",
                colorName: "elevated",
                actions: ["Breathe", "Step Outside", "Rest"]
            )
        }
    }

    // MARK: - Goal Nudge Text

    /// Returns the nudge text for a goal spec.
    static func goalNudgeText(for goal: GoalSpec) -> String {
        switch goal.nudgeTextID {
        // Steps
        case "steps_achieved":
            return "Steps goal reached for today."
        case "steps_start":
            return "A 10 minute walk gets you on the board."
        case "steps_almost":
            let remaining = Int(goal.target - goal.current)
            return "\(remaining) more steps closes it out."

        // Active Minutes
        case "active_achieved":
            return "Active minutes goal reached today."
        case "active_start":
            return "Ten minutes of movement counts, and it often leads to more."
        case "active_almost":
            let remaining = Int(goal.target - goal.current)
            return "\(remaining) active minutes to go. You're nearly there."

        // Sleep
        case "sleep_achieved":
            return "Sleep goal met. Your body got what it needed."
        case "sleep_wind_down":
            return "Starting your wind down about 30 minutes earlier tonight tends to improve both sleep onset and sleep quality."
        case "sleep_almost":
            let target = String(format: "%.1f", goal.target)
            return "You're within reach. Aiming for \(target) hrs tonight would get you to your goal."

        // Zone
        case "zone_achieved":
            return "Cardio zone goal reached."
        case "zone_more":
            let remaining = Int(goal.target - goal.current)
            return "\(remaining) minutes of \(goal.label) left to reach your zone goal."

        default:
            return ""
        }
    }

    // MARK: - Positivity Anchor

    /// Returns the positivity anchor text when negativity balance is off.
    static func positivityAnchor(for anchorID: String?) -> String? {
        guard let id = anchorID else { return nil }
        switch id {
        case "positivity_recovery_progress":
            return "Rest is part of training. Your body adapts during recovery."
        case "positivity_stress_awareness":
            return "Noticing stress and responding early is a real skill."
        case "positivity_general_encouragement":
            return "Consistent check ins make recommendations smarter each day."
        default:
            return nil
        }
    }
}

// MARK: - Stress Guidance Spec

/// Presentational struct for stress guidance UI rendering.
struct StressGuidanceSpec {
    let headline: String
    let detail: String
    let icon: String
    let colorName: String
    let actions: [String]
}

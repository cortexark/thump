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
/// All coaching copy originates here — views never build
/// text from business logic directly.
struct AdvicePresenter {

    // MARK: - Hero Message

    /// Returns the hero banner message for the dashboard.
    static func heroMessage(for state: AdviceState, snapshot: HeartSnapshot) -> String {
        switch state.heroMessageID {
        case "hero_stress_high":
            return "Stress is running high. A rest day would do you good."
        case "hero_rough_night":
            let hrs = snapshot.sleepHours.map { String(format: "%.1f", $0) } ?? "not enough"
            return "Rough night (\(hrs) hrs). Take it easy — a walk is enough today."
        case "hero_recovery_low":
            return "Recovery is low. A light day is the smartest move."
        case "hero_zone_overload":
            return "You pushed hard recently. A mellow day would help you bounce back."
        case "hero_recovered_relaxed":
            return "You recovered well. Ready for a solid day."
        case "hero_charged":
            return "Body is charged up. Good day to move."
        case "hero_decent":
            return "Decent recovery. A moderate effort works well today."
        case "hero_lighter_day":
            return "Your body is asking for a lighter day."
        case "hero_checkin":
            return "Checking in on your wellness."
        default:
            return "Checking in on your wellness."
        }
    }

    // MARK: - Focus Insight

    /// Returns the buddy focus insight text.
    static func focusInsight(for state: AdviceState) -> String? {
        switch state.focusInsightID {
        case "insight_stress_rest":
            return "Stress is running high. A rest day would do you good."
        case "insight_rough_night":
            return "Rough night. Take it easy — a walk is enough today."
        case "insight_recovery_low":
            return "Recovery is low. A light day is the smartest move."
        case "insight_zone_overload":
            return "You pushed hard recently. A mellow day would help you bounce back."
        case "insight_recovered":
            return "You recovered well. Ready for a solid day."
        case "insight_decent":
            return "Decent recovery. A moderate effort works well today."
        case "insight_lighter_day":
            return "Your body is asking for a lighter day."
        case "insight_checkin":
            return nil // No special insight
        default:
            return nil
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
                return "Skip the workout — rest is the only thing that will help right now. "
                    + "Your body needs sleep more than exercise today."
            }
            if hours < policy.view.sleepLightOnlyHours {
                return "Keep it very light today — a short walk at most. "
                    + "Low sleep means your body isn't ready for real effort."
            }
        }

        // Low recovery
        if readinessScore < 45 {
            if state.stressGuidanceLevel == .elevated {
                return "Recovery is low and stress is up — take a full rest day. "
                    + "Even gentle movement should feel optional."
            }
            return "Recovery is low. A gentle walk or stretching is fine, "
                + "but skip anything intense."
        }

        // Moderate recovery
        if readinessScore < 65 {
            if let hours = sleepHours, hours < 6.0 {
                return "Take it easy — a walk is fine, but skip anything intense. "
                    + "Sleep was short, so recovery is limited."
            }
            if state.stressGuidanceLevel == .elevated {
                return "Stress is elevated. Keep it light — a walk or stretching, "
                    + "nothing that raises your heart rate much."
            }
            return "Decent recovery. A moderate effort works well today."
        }

        // Good recovery
        if readinessScore >= 80 {
            if let hours = sleepHours, hours < 6.0 {
                return "Your metrics look good, but sleep was short. "
                    + "A moderate session is fine — save the big effort for a better-rested day."
            }
            return "You're primed. Push it if you want — your body is ready for a challenge."
        }

        if let hours = sleepHours, hours < 6.0 {
            return "Your metrics look good, but sleep was short. "
                + "A moderate session is fine — save the big effort for a better-rested day."
        }

        return "Solid recovery. You can go moderate to hard today."
    }

    // MARK: - Recovery Narrative

    /// Returns a recovery narrative for the Recovery card.
    static func recoveryNarrative(for state: AdviceState) -> String? {
        guard let driver = state.recoveryDriver else {
            if state.mode == .pushDay {
                return "Your recovery is looking strong this week."
            }
            return "Recovery is on track."
        }

        switch driver {
        case .lowSleep:
            return "Prioritize rest tonight — sleep is the biggest lever for recovery."
        case .lowHRV:
            return "HRV dipped — body is still catching up. Easy day recommended."
        case .highStress:
            return "Stress is high — an easy walk and early bedtime will help."
        case .overtraining:
            return "Rest day recommended — your body needs time to recover."
        case .highRHR:
            return "Your body could use a bit more rest."
        }
    }

    // MARK: - Stress Guidance

    /// Returns the stress guidance spec for the Stress screen.
    static func stressGuidance(for level: StressGuidanceLevel) -> StressGuidanceSpec {
        switch level {
        case .relaxed:
            return StressGuidanceSpec(
                headline: "You're in a Great Spot",
                detail: "Your body is recovered and ready. This is a good time for a challenging workout, creative work, or focused deep work.",
                icon: "leaf.fill",
                colorName: "relaxed",
                actions: ["Workout", "Focus Time"]
            )
        case .balanced:
            return StressGuidanceSpec(
                headline: "Keep Up the Balance",
                detail: "Your stress is in a healthy range. A walk, stretching, or a short break can help you stay here.",
                icon: "circle.grid.cross.fill",
                colorName: "balanced",
                actions: ["Take a Walk", "Stretch"]
            )
        case .elevated:
            return StressGuidanceSpec(
                headline: "Time to Ease Up",
                detail: "Your body could use some recovery. Try slow breaths, step outside, or take a 10-minute break. Small pauses make a difference.",
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
            return "Steps goal hit!"
        case "steps_start":
            return "A short walk gets you started."
        case "steps_almost":
            let remaining = Int(goal.target - goal.current)
            return "Just \(remaining) more steps to go!"

        // Active Minutes
        case "active_achieved":
            return "Active minutes done!"
        case "active_start":
            return "Even 10 minutes of movement counts."
        case "active_almost":
            return "Almost there — keep moving!"

        // Sleep
        case "sleep_achieved":
            return "Great rest! Sleep goal met."
        case "sleep_wind_down":
            return "Try winding down 30 minutes earlier tonight."
        case "sleep_almost":
            let target = String(format: "%.1f", goal.target)
            return "Almost there — aim for \(target) hrs tonight."

        // Zone
        case "zone_achieved":
            return "Zone goal reached!"
        case "zone_more":
            let remaining = Int(goal.target - goal.current)
            return "\(remaining) min of \(goal.label) to go."

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
            return "Taking rest seriously is a sign of strength. Your body will thank you."
        case "positivity_stress_awareness":
            return "Noticing stress is the first step. You're already doing something about it."
        case "positivity_general_encouragement":
            return "Every day you check in is progress. You're building a healthier habit."
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

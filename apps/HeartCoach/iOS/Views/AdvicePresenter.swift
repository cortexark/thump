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
/// All coaching copy originates here  - views never build
/// text from business logic directly.
struct AdvicePresenter {

    // MARK: - Hero Message

    /// Returns the hero banner message for the dashboard.
    static func heroMessage(for state: AdviceState, snapshot: HeartSnapshot) -> String {
        switch state.heroMessageID {
        case "hero_stress_high":
            return "Stress markers are above your baseline. Today's work is recovery."
        case "hero_rough_night":
            let hrs = snapshot.sleepHours.map { String(format: "%.1f", $0) } ?? "not enough"
            return "You got \(hrs) hrs last night, below your usual range. A 20-min walk is likely enough today."
        case "hero_recovery_low":
            return "Recovery score is below your 7-day average. A lighter effort today pays off tomorrow."
        case "hero_zone_overload":
            return "You've put in solid work recently. Backing off today is part of the training, not a step back."
        case "hero_recovered_relaxed":
            return "Your sleep and recovery scores are both solid. A good day to push a little harder."
        case "hero_charged":
            return "Heart rate, sleep, and recovery scores are all tracking well. A good day to go after something."
        case "hero_decent":
            return "Recovery is near your norm. A moderate effort fits well here."
        case "hero_lighter_day":
            return "Your heart rate and recovery scores are pointing toward a lighter day. Your body is doing repair work right now."
        case "hero_checkin":
            return "Today's readiness data is in."
        default:
            return "Today's readiness data is in."
        }
    }

    // MARK: - Focus Insight

    /// Returns the buddy focus insight text.
    ///
    /// The insight adds something different from the hero — a specific action,
    /// data context, or "why" — so both surfaces give distinct value. Never
    /// copy-paste hero text here (V-006).
    static func focusInsight(for state: AdviceState) -> String? {
        switch state.focusInsightID {
        case "insight_stress_rest":
            return "Elevated stress tends to suppress HRV (heart rate variability) and slow muscle repair. A 20-min walk or full rest often outperforms a hard session right now."
        case "insight_rough_night":
            return "Sleep shapes how well your muscles and nervous system recover. On short nights, a 15–20 min easy walk tends to be more beneficial than skipping movement entirely — but keep the effort low."
        case "insight_recovery_low":
            return "When recovery dips below your norm, your body is likely still recovering from recent effort. A 20-min walk or light stretching is plenty — more won't accelerate the bounce-back."
        case "insight_zone_overload":
            return "You've stacked up hard sessions recently. Your muscles repair and get stronger during rest — today's easy day is what makes the next hard one actually count."
        case "insight_recovered":
            return "HRV (heart rate variability, a measure of nervous system recovery) and resting heart rate are both tracking well. Quality effort today tends to produce solid fitness gains."
        case "insight_decent":
            return "A moderate effort — something that raises your breathing but lets you hold a conversation — is likely a good fit for today's recovery level."
        case "insight_lighter_day":
            return "Your sleep and recovery data are consistent: a lower-effort day now tends to set up a stronger session within 24–48 hours. Rest or a 20-min walk, then reassess tomorrow."
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
                return "Skip structured training today. Sleep debt at this level tends to impair recovery more than any workout can improve it. Rest is the prescription."
            }
            if hours < policy.view.sleepLightOnlyHours {
                return "Sleep was shorter than your typical baseline. A 20-min easy walk tends to support recovery without adding strain. Save harder sessions for when you're more rested."
            }
        }

        // Low recovery
        if readinessScore < 45 {
            if state.stressGuidanceLevel == .elevated {
                return "Your recovery score is below your usual range and your stress score is elevated. A full rest day — or at most a short, easy walk — tends to produce better results than pushing through both."
            }
            return "Recovery sits below your norm. A 20-min walk or 10–15 min of stretching fits well here. Anything more intense is likely to slow the rebound rather than help it."
        }

        // Moderate recovery
        if readinessScore < 65 {
            if let hours = sleepHours, hours < 6.0 {
                return "Recovery is in a moderate range, though sleep was shorter than your baseline. A 30–40 min moderate session is reasonable — hold off on high-intensity work until you've had a fuller night."
            }
            if state.stressGuidanceLevel == .elevated {
                return "Stress is elevated, which raises resting heart rate and can slow recovery. Keeping it light — a walk or stretching — tends to work better than raising intensity right now."
            }
            return "Recovery is near your norm. A moderate effort — something that challenges you without leaving you depleted — fits well today."
        }

        // Good recovery
        if readinessScore >= 80 {
            if let hours = sleepHours, hours < 6.0 {
                return "Recovery metrics are strong, but sleep was short. A moderate session is appropriate. Reserve your high-effort work for when sleep and readiness align."
            }
            return "Your recovery and heart rate metrics are tracking well above your norm. If you've been waiting for a day to push, this is likely it."
        }

        if let hours = sleepHours, hours < 6.0 {
            return "Your metrics are solid, but sleep came up short. A moderate session is a smart middle ground — the high-end effort will be there when sleep catches up."
        }

        return "Recovery is solid and trending above your baseline. You can go moderate to hard today — the data supports it."
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
            return "Sleep has been below your norm. Prioritizing sleep tonight tends to have the fastest impact on tomorrow's readiness."
        case .lowHRV:
            return "Your HRV (heart rate variability) has dipped below your recent range — a sign your body is still processing recent demands. An easy day tends to support the shift back."
        case .highStress:
            return "Elevated stress tends to slow overnight recovery. A short easy walk and an earlier bedtime often help bring it back into your usual range."
        case .overtraining:
            return "Accumulated training effort is high relative to your recent baseline. Today's rest is where your body gets stronger."
        case .highRHR:
            return "Resting heart rate is elevated above your baseline — a sign your body is still absorbing recent effort. An easier day is supported."
        }
    }

    // MARK: - Stress Guidance

    /// Returns the stress guidance spec for the Stress screen.
    static func stressGuidance(for level: StressGuidanceLevel) -> StressGuidanceSpec {
        switch level {
        case .relaxed:
            return StressGuidanceSpec(
                headline: "Stress Is Low, Good Time to Push",
                detail: "Your stress and recovery scores are both looking good right now. This tends to be a good window for hard training, focused deep work, or anything that demands full engagement.",
                icon: "leaf.fill",
                colorName: "relaxed",
                actions: ["Workout", "Focus Time"]
            )
        case .balanced:
            return StressGuidanceSpec(
                headline: "Stress Is in a Workable Range",
                detail: "Your stress levels are near your personal baseline. A 20-min walk, some light stretching, or a short break during the day can help you maintain this range.",
                icon: "circle.grid.cross.fill",
                colorName: "balanced",
                actions: ["Take a Walk", "Stretch"]
            )
        case .elevated:
            return StressGuidanceSpec(
                headline: "Stress Is Up — Recovery Would Help",
                detail: "When stress is elevated, resting heart rate tends to rise and HRV (heart rate variability) tends to dip — both are signs your body is working harder than usual. A few slow breaths, a short walk outside, or a 10-min break often helps it settle.",
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
            return "A 10-min walk gets you on the board."
        case "steps_almost":
            let remaining = Int(goal.target - goal.current)
            return "\(remaining) more steps closes it out."

        // Active Minutes
        case "active_achieved":
            return "Active minutes goal reached today."
        case "active_start":
            return "Ten minutes of movement counts — and it often leads to more."
        case "active_almost":
            let remaining = Int(goal.target - goal.current)
            return "\(remaining) active minutes to go. You're nearly there."

        // Sleep
        case "sleep_achieved":
            return "Sleep goal met. Your body got what it needed."
        case "sleep_wind_down":
            return "Starting your wind-down about 30 minutes earlier tonight tends to improve both sleep onset and sleep quality."
        case "sleep_almost":
            let target = String(format: "%.1f", goal.target)
            return "You're within reach — aiming for \(target) hrs tonight would get you to your goal."

        // Zone
        case "zone_achieved":
            return "Cardio zone goal reached."
        case "zone_more":
            let remaining = Int(goal.target - goal.current)
            return "\(remaining) min of \(goal.label) left to reach your zone goal."

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
            return "Treating rest as part of training — not a pause from it — is what the research consistently supports. Your body adapts during recovery."
        case "positivity_stress_awareness":
            return "Recognizing elevated stress and choosing to respond to it is a skill. That awareness is useful data."
        case "positivity_general_encouragement":
            return "Consistent check-ins build the baseline that makes every recommendation sharper. You're adding to that baseline today."
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

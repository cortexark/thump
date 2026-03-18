// AdviceComposer.swift
// Thump Shared
//
// Thin orchestrator that merges evaluator outputs into a single
// AdviceState. Each evaluator is a pure function struct.
// The composer applies mode precedence and coherence rules.
//
// Phase 3a: reproduces existing view logic 1:1 (behavior-preserving).
// Phase 3b: new modes/ladder/positivity gated by enableAdvancedGuidance.
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Advice Composer

/// Merges evaluator outputs into a unified AdviceState.
///
/// All coaching decisions flow through this single entry point.
/// Views never compute business logic — they read AdviceState
/// via AdvicePresenter.
struct AdviceComposer: Sendable {

    private let sleepEvaluator = SleepEvaluator()
    private let stressEvaluator = StressEvaluator()
    private let goalEvaluator = GoalEvaluator()
    private let overtrainingEvaluator = OvertrainingEvaluator()
    private let positivityEvaluator = PositivityEvaluator()

    /// Composes a complete AdviceState from the engine bundle and user profile.
    func compose(
        snapshot: HeartSnapshot,
        assessment: HeartAssessment,
        stressResult: StressResult?,
        readinessResult: ReadinessResult?,
        zoneAnalysis: ZoneAnalysis?,
        config: HealthPolicyConfig
    ) -> AdviceState {

        // 1. Run evaluators
        let sleepAssessment = sleepEvaluator.evaluate(
            snapshot: snapshot,
            readinessResult: readinessResult,
            config: config.sleepReadiness
        )

        let stressAssessment = stressEvaluator.evaluate(
            stressResult: stressResult,
            assessment: assessment
        )

        let goals = goalEvaluator.evaluate(
            snapshot: snapshot,
            readinessResult: readinessResult,
            stressResult: stressResult,
            zoneAnalysis: zoneAnalysis,
            config: config.goals
        )

        let overtrainingState = overtrainingEvaluator.evaluate(
            consecutiveAlertDays: assessment.consecutiveAlert?.consecutiveDays ?? 0,
            config: config.stressOvertraining
        )

        let readinessScore = readinessResult?.score

        let positivity = positivityEvaluator.evaluate(
            sleepDeprived: sleepAssessment.isDeprived,
            stressElevated: stressAssessment.isElevated,
            readinessScore: readinessScore,
            overtrainingState: overtrainingState,
            medicalEscalation: assessment.consecutiveAlert?.consecutiveDays ?? 0 >= 5
        )

        // 2. Determine guidance mode (highest severity wins)
        let mode = resolveMode(
            sleepAssessment: sleepAssessment,
            stressAssessment: stressAssessment,
            readinessScore: readinessScore,
            overtrainingState: overtrainingState,
            assessment: assessment
        )

        // 3. Determine risk band
        let riskBand = resolveRiskBand(
            readinessScore: readinessScore,
            stressElevated: stressAssessment.isElevated,
            overtrainingState: overtrainingState
        )

        // 4. Determine hero category and message
        let heroCategory = resolveHeroCategory(mode: mode)
        let heroMessageID = resolveHeroMessageID(
            mode: mode,
            sleepAssessment: sleepAssessment,
            stressAssessment: stressAssessment,
            readinessScore: readinessScore,
            zoneAnalysis: zoneAnalysis,
            assessment: assessment
        )

        // 5. Determine buddy mood
        let buddyMood = resolveBuddyMood(
            mode: mode,
            stressInfluence: stressAssessment.buddyMoodInfluence,
            readinessScore: readinessScore
        )

        // 6. Focus insight ID
        let focusInsightID = resolveFocusInsightID(
            stressAssessment: stressAssessment,
            sleepAssessment: sleepAssessment,
            readinessScore: readinessScore,
            zoneAnalysis: zoneAnalysis,
            assessment: assessment
        )

        // 7. Check badge
        let checkBadgeID = resolveCheckBadgeID(mode: mode, readinessScore: readinessScore)

        // 8. Recovery driver (pick highest priority)
        let recoveryDriver: RecoveryDriver? = sleepAssessment.recoveryDriver
            ?? stressAssessment.recoveryDriver
            ?? (overtrainingState >= .watch ? .overtraining : nil)

        // 9. Smart actions (trimmed to fit within daily guidance budget)
        let budget = dailyGuidanceBudget(mode: mode)
        let rawSmartActions = resolveSmartActions(
            stressAssessment: stressAssessment,
            sleepAssessment: sleepAssessment,
            mode: mode
        )
        // Reserve budget space for buddy recs (typically 1-2 on restrictive days).
        // Smart actions take the remaining slots after reserving 1 slot for buddy recs.
        let smartActionCap = max(0, budget - 1)
        let smartActions = Array(rawSmartActions.prefix(smartActionCap))

        // 10. Allowed intensity
        let allowedIntensity = resolveIntensity(
            mode: mode,
            overtrainingState: overtrainingState
        )

        // 10b. Cap goals for restrictive modes (INV-004 compliance)
        let cappedGoals: [GoalSpec]
        if mode == .fullRest || mode == .medicalCheck {
            cappedGoals = goals.map { spec in
                switch spec.category {
                case .steps:
                    let cap = Double(config.goals.stepsRecovering)
                    return spec.target > cap
                        ? GoalSpec(category: spec.category, target: cap, current: spec.current, nudgeTextID: spec.nudgeTextID, label: spec.label)
                        : spec
                case .activeMinutes:
                    let cap = Double(config.goals.activeMinRecovering)
                    return spec.target > cap
                        ? GoalSpec(category: spec.category, target: cap, current: spec.current, nudgeTextID: spec.nudgeTextID, label: spec.label)
                        : spec
                default:
                    return spec
                }
            }
        } else {
            cappedGoals = goals
        }

        // 11. Nudge priorities
        let nudgePriorities = resolveNudgePriorities(
            sleepAssessment: sleepAssessment,
            stressAssessment: stressAssessment,
            mode: mode
        )

        // 12. Medical escalation flag
        let medicalEscalation = assessment.consecutiveAlert?.consecutiveDays ?? 0 >= 5

        return AdviceState(
            mode: mode,
            riskBand: riskBand,
            overtrainingState: overtrainingState,
            sleepDeprivationFlag: sleepAssessment.isDeprived,
            medicalEscalationFlag: medicalEscalation,
            heroCategory: heroCategory,
            heroMessageID: heroMessageID,
            buddyMoodCategory: buddyMood,
            focusInsightID: focusInsightID,
            checkBadgeID: checkBadgeID,
            goals: cappedGoals,
            recoveryDriver: recoveryDriver,
            stressGuidanceLevel: stressAssessment.guidanceLevel,
            smartActions: smartActions,
            allowedIntensity: allowedIntensity,
            nudgePriorities: nudgePriorities,
            positivityAnchorID: positivity.anchorID,
            dailyActionBudget: budget
        )
    }

    // MARK: - Mode Resolution

    /// Resolves guidance mode with severity precedence.
    /// Reproduces the same decision tree as the existing view helpers.
    private func resolveMode(
        sleepAssessment: SleepAssessment,
        stressAssessment: StressAssessment,
        readinessScore: Int?,
        overtrainingState: OvertrainingState,
        assessment: HeartAssessment
    ) -> GuidanceMode {
        // Medical check overrides everything
        if assessment.consecutiveAlert?.consecutiveDays ?? 0 >= 5 {
            return .medicalCheck
        }

        // Full rest for severe sleep deprivation or deload overtraining
        if sleepAssessment.deprivationLevel == .severe || overtrainingState >= .deload {
            return .fullRest
        }

        // Full rest for elevated stress + low readiness combo
        if stressAssessment.isElevated, let score = readinessScore, score < 45 {
            return .fullRest
        }

        // Light recovery for moderate sleep deprivation or overtraining watch/caution
        if sleepAssessment.deprivationLevel >= .moderate || overtrainingState >= .watch {
            return .lightRecovery
        }

        // Light recovery for low readiness
        if let score = readinessScore, score < 45 {
            return .lightRecovery
        }

        // Moderate move for moderate readiness
        if let score = readinessScore, score < 65 {
            return .moderateMove
        }

        // Push day when primed and not stressed
        if let score = readinessScore, score >= 75, !stressAssessment.isElevated {
            return .pushDay
        }

        return .moderateMove
    }

    // MARK: - Risk Band

    private func resolveRiskBand(
        readinessScore: Int?,
        stressElevated: Bool,
        overtrainingState: OvertrainingState
    ) -> RiskBand {
        if overtrainingState >= .caution { return .high }
        if stressElevated, let score = readinessScore, score < 45 { return .high }
        if stressElevated || (readinessScore ?? 50) < 45 { return .elevated }
        if (readinessScore ?? 50) < 65 { return .moderate }
        return .low
    }

    // MARK: - Hero Resolution

    private func resolveHeroCategory(mode: GuidanceMode) -> HeroCategory {
        switch mode {
        case .pushDay:       return .celebrate
        case .moderateMove:  return .encourage
        case .lightRecovery: return .caution
        case .fullRest:      return .rest
        case .medicalCheck:  return .medical
        }
    }

    /// Maps to the same priority chain as buddyFocusInsight in DashboardView.
    private func resolveHeroMessageID(
        mode: GuidanceMode,
        sleepAssessment: SleepAssessment,
        stressAssessment: StressAssessment,
        readinessScore: Int?,
        zoneAnalysis: ZoneAnalysis?,
        assessment: HeartAssessment
    ) -> String {
        // Priority 1: Stress elevated + flag
        if assessment.stressFlag && stressAssessment.isElevated {
            return "hero_stress_high"
        }

        // Priority 2: Low readiness
        if let score = readinessScore, score < 45 {
            if sleepAssessment.sleepPillarScore.map({ $0 < 50 }) ?? false {
                return "hero_rough_night"
            }
            return "hero_recovery_low"
        }

        // Priority 3: Moderate readiness + zone overload
        if let score = readinessScore, score < 65,
           zoneAnalysis?.recommendation == .tooMuchIntensity {
            return "hero_zone_overload"
        }

        // Priority 4: High readiness + relaxed
        if let score = readinessScore, score >= 75 {
            if !assessment.stressFlag && stressAssessment.guidanceLevel == .relaxed {
                return "hero_recovered_relaxed"
            }
            return "hero_charged"
        }

        // Priority 5: Decent recovery
        if let score = readinessScore, score >= 45 {
            return "hero_decent"
        }

        // Fallback
        if assessment.status == .needsAttention {
            return "hero_lighter_day"
        }
        return "hero_checkin"
    }

    // MARK: - Buddy Mood

    private func resolveBuddyMood(
        mode: GuidanceMode,
        stressInfluence: BuddyMoodCategory?,
        readinessScore: Int?
    ) -> BuddyMoodCategory {
        switch mode {
        case .medicalCheck, .fullRest:
            return .resting
        case .lightRecovery:
            return stressInfluence == .concerned ? .concerned : .resting
        case .moderateMove:
            return .encouraging
        case .pushDay:
            return .celebrating
        }
    }

    // MARK: - Focus Insight

    /// Maps to the same priority chain as buddyFocusInsight.
    private func resolveFocusInsightID(
        stressAssessment: StressAssessment,
        sleepAssessment: SleepAssessment,
        readinessScore: Int?,
        zoneAnalysis: ZoneAnalysis?,
        assessment: HeartAssessment
    ) -> String {
        if assessment.stressFlag && stressAssessment.isElevated {
            return "insight_stress_rest"
        }
        if let score = readinessScore, score < 45 {
            return sleepAssessment.sleepPillarScore.map({ $0 < 50 }) ?? false
                ? "insight_rough_night" : "insight_recovery_low"
        }
        if let score = readinessScore, score < 65,
           zoneAnalysis?.recommendation == .tooMuchIntensity {
            return "insight_zone_overload"
        }
        if let score = readinessScore, score >= 75, !assessment.stressFlag {
            return "insight_recovered"
        }
        if let score = readinessScore, score >= 45 {
            return "insight_decent"
        }
        if assessment.status == .needsAttention {
            return "insight_lighter_day"
        }
        return "insight_checkin"
    }

    // MARK: - Check Badge

    private func resolveCheckBadgeID(mode: GuidanceMode, readinessScore: Int?) -> String {
        switch mode {
        case .pushDay:       return "check_push"
        case .moderateMove:  return "check_moderate"
        case .lightRecovery: return "check_light"
        case .fullRest:      return "check_rest"
        case .medicalCheck:  return "check_medical"
        }
    }

    // MARK: - Smart Actions

    private func resolveSmartActions(
        stressAssessment: StressAssessment,
        sleepAssessment: SleepAssessment,
        mode: GuidanceMode
    ) -> [TypedSmartAction] {
        var actions: [TypedSmartAction] = []

        // Bedtime wind-down if sleep-deprived or low recovery
        if sleepAssessment.isDeprived {
            actions.append(.bedtimeWindDown(driverID: sleepAssessment.narrativeID))
        }

        // Breathing if stressed
        if stressAssessment.shouldSuggestBreathing {
            actions.append(.breathingSession)
        }

        // Mode-specific actions
        switch mode {
        case .pushDay:
            actions.append(.walkSuggestion)
            actions.append(.focusTime)
        case .moderateMove:
            actions.append(.walkSuggestion)
            actions.append(.stretch)
        case .lightRecovery:
            actions.append(.restSuggestion)
            actions.append(.breathingSession)
        case .fullRest:
            actions.append(.restSuggestion)
        case .medicalCheck:
            actions.append(.restSuggestion)
        }

        // Deduplicate
        var seen = Set<String>()
        return actions.filter { action in
            let key = String(describing: action)
            return seen.insert(key).inserted
        }
    }

    // MARK: - Intensity

    private func resolveIntensity(
        mode: GuidanceMode,
        overtrainingState: OvertrainingState
    ) -> IntensityBand {
        if overtrainingState >= .caution { return .light }
        switch mode {
        case .fullRest, .medicalCheck: return .rest
        case .lightRecovery:           return .light
        case .moderateMove:            return .moderate
        case .pushDay:                 return .full
        }
    }

    // MARK: - Daily Guidance Budget (V-015)

    /// Maximum total action items for the day.
    ///
    /// "Action items" = buddy recs + smart actions + goal nudge directives
    /// + Thump Check directive text + weekly report recommended actions.
    /// Hero message, narrative text, and passive goal displays do NOT count.
    ///
    /// Views use `AdviceState.dailyActionBudget` to trim buddy recommendations
    /// to `max(0, dailyActionBudget - smartActions.count)`.
    private func dailyGuidanceBudget(mode: GuidanceMode) -> Int {
        switch mode {
        case .fullRest:       return 2
        case .medicalCheck:   return 2
        case .lightRecovery:  return 3
        case .moderateMove:   return 5
        case .pushDay:        return 5  // V-015 caps any day at 5 to prevent cognitive overload
        }
    }

    // MARK: - Nudge Priorities

    private func resolveNudgePriorities(
        sleepAssessment: SleepAssessment,
        stressAssessment: StressAssessment,
        mode: GuidanceMode
    ) -> [NudgeCategory] {
        var priorities: [NudgeCategory] = []

        // Sleep always first if deprived
        if sleepAssessment.isDeprived {
            priorities.append(.rest)
        }

        // Breathe if stressed
        if stressAssessment.shouldSuggestBreathing {
            priorities.append(.breathe)
        }

        // Mode-based
        switch mode {
        case .fullRest, .medicalCheck:
            if !priorities.contains(.rest) { priorities.append(.rest) }
        case .lightRecovery:
            priorities.append(.walk)
            if !priorities.contains(.rest) { priorities.append(.rest) }
        case .moderateMove:
            priorities.append(.walk)
        case .pushDay:
            priorities.append(.intensity)
            priorities.append(.walk)
        }

        return priorities
    }
}

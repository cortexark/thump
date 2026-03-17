// GoalEvaluator.swift
// Thump Shared
//
// Pure function evaluator for dynamic daily goals.
// Adjusts step, active minute, sleep, and zone targets
// based on readiness score and stress level.
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Goal Evaluator

/// Evaluates dynamic daily goals from readiness, stress, and zone data.
struct GoalEvaluator: Sendable {

    func evaluate(
        snapshot: HeartSnapshot,
        readinessResult: ReadinessResult?,
        stressResult: StressResult?,
        zoneAnalysis: ZoneAnalysis?,
        config: HealthPolicyConfig.GoalTargets
    ) -> [GoalSpec] {
        let readinessScore = readinessResult?.score ?? 50
        let stressLevel = stressResult?.level
        var goals: [GoalSpec] = []

        // Goal 1: Steps
        let stepTarget = stepTarget(score: readinessScore, config: config)
        let currentSteps = Double(snapshot.steps ?? 0)
        let stepsNudge = stepsNudgeID(current: currentSteps, target: Double(stepTarget))
        goals.append(GoalSpec(
            category: .steps,
            target: Double(stepTarget),
            current: currentSteps,
            nudgeTextID: stepsNudge,
            label: "Steps"
        ))

        // Goal 2: Active Minutes
        let activeTarget = activeMinTarget(
            score: readinessScore,
            stressLevel: stressLevel,
            config: config
        )
        let currentActive = Double(snapshot.walkMinutes ?? 0) + Double(snapshot.workoutMinutes ?? 0)
        let activeNudge = activeNudgeID(current: currentActive, target: Double(activeTarget))
        goals.append(GoalSpec(
            category: .activeMinutes,
            target: Double(activeTarget),
            current: currentActive,
            nudgeTextID: activeNudge,
            label: "Active Minutes"
        ))

        // Goal 3: Sleep (only if data available)
        if let sleepHours = snapshot.sleepHours, sleepHours > 0 {
            let sleepTarget = sleepTarget(score: readinessScore, config: config)
            let sleepNudge = sleepNudgeID(current: sleepHours, target: sleepTarget)
            goals.append(GoalSpec(
                category: .sleep,
                target: sleepTarget,
                current: sleepHours,
                nudgeTextID: sleepNudge,
                label: "Sleep"
            ))
        }

        // Goal 4: Zone (only if zone analysis available)
        if zoneAnalysis != nil {
            let zoneGoal = zoneGoalSpec(
                readinessScore: readinessScore,
                stressLevel: stressLevel,
                snapshot: snapshot
            )
            if let zoneGoal {
                goals.append(zoneGoal)
            }
        }

        return goals
    }

    // MARK: - Target Computation

    private func stepTarget(score: Int, config: HealthPolicyConfig.GoalTargets) -> Int {
        if score >= 80 { return config.stepsPrimed }
        if score >= 65 { return config.stepsReady }
        if score >= 45 { return config.stepsModerate }
        return config.stepsRecovering
    }

    private func activeMinTarget(
        score: Int,
        stressLevel: StressLevel?,
        config: HealthPolicyConfig.GoalTargets
    ) -> Int {
        if score >= 80 && stressLevel != .elevated { return config.activeMinPrimed }
        if score >= 65 { return config.activeMinReady }
        if score >= 45 { return config.activeMinModerate }
        return config.activeMinRecovering
    }

    private func sleepTarget(score: Int, config: HealthPolicyConfig.GoalTargets) -> Double {
        if score < 45 { return config.sleepTargetRecovering }
        if score < 65 { return config.sleepTargetModerate }
        return config.sleepTargetReady
    }

    // MARK: - Nudge ID Selection

    private func stepsNudgeID(current: Double, target: Double) -> String {
        if current >= target { return "steps_achieved" }
        let remaining = target - current
        if remaining > target / 2 { return "steps_start" }
        return "steps_almost"
    }

    private func activeNudgeID(current: Double, target: Double) -> String {
        if current >= target { return "active_achieved" }
        if current < target / 2 { return "active_start" }
        return "active_almost"
    }

    private func sleepNudgeID(current: Double, target: Double) -> String {
        if current >= target { return "sleep_achieved" }
        if current < target - 1.0 { return "sleep_wind_down" }
        return "sleep_almost"
    }

    private func zoneGoalSpec(
        readinessScore: Int,
        stressLevel: StressLevel?,
        snapshot: HeartSnapshot
    ) -> GoalSpec? {
        let zones = snapshot.zoneMinutes
        guard zones.count >= 5 else { return nil }

        let zoneIndex: Int
        let label: String
        let target: Double

        if readinessScore >= 80 && stressLevel != .elevated {
            // Aerobic zone
            zoneIndex = 3
            label = "Cardio"
            target = 20
        } else if readinessScore < 45 {
            // Recovery zone
            zoneIndex = 1
            label = "Easy"
            target = 15
        } else {
            // Fat burn zone
            zoneIndex = 2
            label = "Fat Burn"
            target = 20
        }

        let current = Double(zones[zoneIndex])
        let nudge = current >= target ? "zone_achieved" : "zone_more"

        return GoalSpec(
            category: .zone,
            target: target,
            current: current,
            nudgeTextID: nudge,
            label: label
        )
    }
}

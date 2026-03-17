// StressEvaluator.swift
// Thump Shared
//
// Pure function evaluator for stress-related coaching decisions.
// Maps stress levels to guidance, buddy mood influence, and smart actions.
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Stress Assessment (for AdviceComposer)

/// Result of stress evaluation — used by AdviceComposer.
struct StressAssessment: Sendable {
    let guidanceLevel: StressGuidanceLevel?
    let buddyMoodInfluence: BuddyMoodCategory?
    let isElevated: Bool
    let shouldSuggestBreathing: Bool
    let recoveryDriver: RecoveryDriver?
}

// MARK: - Stress Evaluator

/// Evaluates stress state for coaching decisions.
struct StressEvaluator: Sendable {

    func evaluate(
        stressResult: StressResult?,
        assessment: HeartAssessment
    ) -> StressAssessment {
        guard let stress = stressResult else {
            // No stress data — use assessment stressFlag as fallback
            let isElevated = assessment.stressFlag
            return StressAssessment(
                guidanceLevel: nil,
                buddyMoodInfluence: isElevated ? .concerned : nil,
                isElevated: isElevated,
                shouldSuggestBreathing: isElevated,
                recoveryDriver: isElevated ? .highStress : nil
            )
        }

        let guidanceLevel: StressGuidanceLevel
        let buddyInfluence: BuddyMoodCategory?
        let shouldBreath: Bool

        switch stress.level {
        case .relaxed:
            guidanceLevel = .relaxed
            buddyInfluence = .celebrating
            shouldBreath = false
        case .balanced:
            guidanceLevel = .balanced
            buddyInfluence = nil
            shouldBreath = false
        case .elevated:
            guidanceLevel = .elevated
            buddyInfluence = .concerned
            shouldBreath = true
        }

        return StressAssessment(
            guidanceLevel: guidanceLevel,
            buddyMoodInfluence: buddyInfluence,
            isElevated: stress.level == .elevated,
            shouldSuggestBreathing: shouldBreath,
            recoveryDriver: stress.level == .elevated ? .highStress : nil
        )
    }
}

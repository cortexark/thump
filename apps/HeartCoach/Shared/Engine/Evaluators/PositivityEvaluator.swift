// PositivityEvaluator.swift
// Thump Shared
//
// Pure function evaluator for positivity balance.
// Counts negative signals and injects a positivity anchor
// when the user is receiving too many cautionary messages.
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Positivity Assessment

/// Result of positivity evaluation.
struct PositivityAssessment: Sendable {
    let negativeCount: Int
    let needsAnchor: Bool
    let anchorID: String?
}

// MARK: - Positivity Evaluator

/// Counts negative signals and determines whether a positivity anchor is needed.
struct PositivityEvaluator: Sendable {

    /// Evaluates whether the current advice state has too many negative signals
    /// and should inject a positivity anchor.
    ///
    /// A "negative" signal is: sleep deprivation, elevated stress, low readiness,
    /// overtraining watch+, or medical escalation.
    func evaluate(
        sleepDeprived: Bool,
        stressElevated: Bool,
        readinessScore: Int?,
        overtrainingState: OvertrainingState,
        medicalEscalation: Bool
    ) -> PositivityAssessment {
        var count = 0
        if sleepDeprived { count += 1 }
        if stressElevated { count += 1 }
        if let score = readinessScore, score < 45 { count += 1 }
        if overtrainingState >= .watch { count += 1 }
        if medicalEscalation { count += 1 }

        let needsAnchor = count >= 2
        let anchorID: String?

        if needsAnchor {
            // Pick context-appropriate anchor
            if overtrainingState >= .caution {
                anchorID = "positivity_recovery_progress"
            } else if stressElevated {
                anchorID = "positivity_stress_awareness"
            } else {
                anchorID = "positivity_general_encouragement"
            }
        } else {
            anchorID = nil
        }

        return PositivityAssessment(
            negativeCount: count,
            needsAnchor: needsAnchor,
            anchorID: anchorID
        )
    }
}

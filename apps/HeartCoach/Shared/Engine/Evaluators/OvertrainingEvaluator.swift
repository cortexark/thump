// OvertrainingEvaluator.swift
// Thump Shared
//
// Pure function evaluator for overtraining detection.
// Maps consecutive alert days to escalation states.
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Overtraining Evaluator

/// Evaluates overtraining state from consecutive alert day count.
struct OvertrainingEvaluator: Sendable {

    func evaluate(
        consecutiveAlertDays: Int,
        config: HealthPolicyConfig.StressOvertraining
    ) -> OvertrainingState {
        if consecutiveAlertDays >= config.overtainingDaysConsult {
            return .consult
        }
        if consecutiveAlertDays >= config.overtainingDaysCritical {
            return .deload
        }
        if consecutiveAlertDays >= config.overtainingDaysMedical {
            return .caution
        }
        if consecutiveAlertDays >= config.overtainingDaysWarning {
            return .watch
        }
        return .none
    }
}

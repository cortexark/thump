// SleepEvaluator.swift
// Thump Shared
//
// Pure function evaluator for sleep-related coaching decisions.
// Assesses sleep deprivation, recovery drivers, and sleep quality.
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Sleep Assessment

/// Result of sleep evaluation — used by AdviceComposer.
struct SleepAssessment: Sendable {
    let isDeprived: Bool
    let deprivationLevel: SleepDeprivationLevel
    let recoveryDriver: RecoveryDriver?
    let sleepHours: Double?
    let sleepPillarScore: Double?
    let narrativeID: String

    enum SleepDeprivationLevel: Int, Sendable, Comparable {
        case none      = 0
        case mild      = 1 // < target but > 5h
        case moderate  = 2 // < 5h
        case critical  = 3 // < 4h
        case severe    = 4 // < 3h

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - Sleep Evaluator

/// Evaluates sleep state from readiness pillars and snapshot data.
struct SleepEvaluator: Sendable {

    func evaluate(
        snapshot: HeartSnapshot,
        readinessResult: ReadinessResult?,
        config: HealthPolicyConfig.SleepReadiness
    ) -> SleepAssessment {
        let sleepHours = snapshot.sleepHours
        let sleepPillar = readinessResult?.pillars.first { $0.type == .sleep }

        // Determine deprivation level from sleep hours
        let deprivation: SleepAssessment.SleepDeprivationLevel
        if let hours = sleepHours {
            if hours < config.sleepCapCriticalHours {
                deprivation = .severe
            } else if hours < config.sleepCapLowHours {
                deprivation = .critical
            } else if hours < config.sleepCapModerateHours {
                deprivation = .moderate
            } else if hours < 6.0 {
                deprivation = .mild
            } else {
                deprivation = .none
            }
        } else {
            deprivation = .none
        }

        let isDeprived = deprivation != .none

        // Determine recovery driver
        let recoveryDriver: RecoveryDriver?
        if isDeprived {
            recoveryDriver = .lowSleep
        } else if let pillar = sleepPillar, pillar.score < 50.0 {
            recoveryDriver = .lowSleep
        } else {
            recoveryDriver = nil
        }

        // Narrative ID for AdvicePresenter
        let narrativeID: String
        switch deprivation {
        case .severe:   narrativeID = "sleep_severe"
        case .critical: narrativeID = "sleep_critical"
        case .moderate: narrativeID = "sleep_moderate"
        case .mild:     narrativeID = "sleep_mild"
        case .none:
            if let score = sleepPillar?.score, score >= Double(config.readinessPrimed) {
                narrativeID = "sleep_good"
            } else if let score = sleepPillar?.score, score >= 50.0 {
                narrativeID = "sleep_okay"
            } else if sleepPillar != nil {
                narrativeID = "sleep_low"
            } else {
                narrativeID = "sleep_unknown"
            }
        }

        return SleepAssessment(
            isDeprived: isDeprived,
            deprivationLevel: deprivation,
            recoveryDriver: recoveryDriver,
            sleepHours: sleepHours,
            sleepPillarScore: sleepPillar?.score,
            narrativeID: narrativeID
        )
    }
}

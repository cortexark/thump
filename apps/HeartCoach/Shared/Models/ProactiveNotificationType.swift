// ProactiveNotificationType.swift
// ThumpCore
//
// Shared proactive notification identifiers and metadata.
// Used by both iOS notification scheduling and shared persistence.
//
// Platforms: iOS 17+, watchOS 10+

import Foundation

/// All proactive notification types added by the gap analysis.
enum ProactiveNotificationType: String, Sendable, CaseIterable {
    case morningBriefing
    case bedtimeWindDown
    case postWorkoutRecovery
    case trainingOpportunity
    case illnessDetection
    case eveningRecovery
    case reboundConfirmation

    var threadIdentifier: String {
        "com.thump.alerts.\(rawValue)"
    }

    /// Stable identifier — one per type, no UUID, so scheduling replaces
    /// any existing pending notification of the same type.
    var notificationIdentifier: String {
        "com.thump.\(rawValue)"
    }

    /// Priority for daily budget arbitration (higher = more important).
    var priority: Int {
        switch self {
        case .illnessDetection:     return 100
        case .morningBriefing:      return 90
        case .reboundConfirmation:  return 80
        case .trainingOpportunity:  return 70
        case .eveningRecovery:      return 60
        case .bedtimeWindDown:      return 50
        case .postWorkoutRecovery:  return 40
        }
    }
}

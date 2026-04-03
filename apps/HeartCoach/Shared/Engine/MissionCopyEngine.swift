// MissionCopyEngine.swift
// Thump Shared
//
// Selects the mission sentence (Today's Mission copy) for display
// on the Today screen. Routes to the appropriate copy pool based on
// readiness score, UserCopyProfile, TrainingPhase, ActivityType,
// and pattern flags (isChronicSteady, isRapidHRVDrop, etc.).
//
// Architecture:
// - Pure function — no side effects, no stored state
// - Returns a MissionCopy value that includes the main sentence
//   and an optional temporal memory sentence shown below it
// - Additive: does not modify AdviceComposer, AdviceState, or StressEngine
//
// Copy pools are defined by the design system §13 / §22 voice guide.
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Mission Copy

/// The resolved mission copy for today's screen.
public struct MissionCopy: Sendable, Equatable {
    /// The primary mission sentence shown at full opacity.
    public let missionSentence: String

    /// Optional temporal memory sentence shown below the mission at
    /// 13pt, 60% opacity. Nil when no pattern warrants it.
    public let temporalMemorySentence: String?

    public init(missionSentence: String, temporalMemorySentence: String? = nil) {
        self.missionSentence = missionSentence
        self.temporalMemorySentence = temporalMemorySentence
    }
}

// MARK: - Mission Context

/// Input context for mission copy selection.
public struct MissionContext: Sendable {
    /// Readiness score 0–100. Drives state selection.
    public let readinessScore: Int

    /// User's copy routing profile.
    public let copyProfile: UserCopyProfile

    /// Current training phase.
    public let trainingPhase: TrainingPhase

    /// Primary activity type.
    public let activityType: ActivityType

    /// Whether the user has been in Steady state for 14+ consecutive days.
    public let isChronicSteady: Bool

    /// Whether a rapid HRV drop occurred AND user is female aged 40–60.
    /// Triggers hormonal recalibration copy pool.
    public let isHormonalRecalibration: Bool

    /// Number of consecutive days with elevated stress readings (score < 45).
    /// Used for multi-day stressed temporal memory sentence.
    public let consecutiveStressedDays: Int

    /// Number of days since the last app open.
    /// Used for post-gap temporal memory sentence.
    public let daysSinceLastOpen: Int

    public init(
        readinessScore: Int,
        copyProfile: UserCopyProfile = .autonomous,
        trainingPhase: TrainingPhase = .none,
        activityType: ActivityType = .general,
        isChronicSteady: Bool = false,
        isHormonalRecalibration: Bool = false,
        consecutiveStressedDays: Int = 0,
        daysSinceLastOpen: Int = 0
    ) {
        self.readinessScore = readinessScore
        self.copyProfile = copyProfile
        self.trainingPhase = trainingPhase
        self.activityType = activityType
        self.isChronicSteady = isChronicSteady
        self.isHormonalRecalibration = isHormonalRecalibration
        self.consecutiveStressedDays = consecutiveStressedDays
        self.daysSinceLastOpen = daysSinceLastOpen
    }
}

// MARK: - Mission Copy Engine

/// Selects mission copy from the appropriate pool for the given context.
///
/// Priority order (highest wins):
/// 1. Hormonal recalibration override (isHormonalRecalibration)
/// 2. Constrained copy profile (UserCopyProfile == .constrained)
/// 3. Chronic steady override (isChronicSteady, score 0–44)
/// 4. Training phase overrides (taper / build / HIIT CNS routing)
/// 5. Score-band defaults (Thriving 75–100 / Recovering 45–74 / Stressed 0–44)
public struct MissionCopyEngine: Sendable {

    // MARK: - Copy Pools

    // Thriving (score 75–100)
    private static let thrivingGeneral: [String] = [
        "Push in your workout today. Your body will thank you tonight.",
        "Great day to tackle something hard. You've got the energy.",
        "Personal record territory. Don't waste it."
    ]

    private static let thrivingHIIT: [String] = [
        "CNS recovery: complete. Go. Full effort today."
    ]

    private static let thrivingMindBody: [String] = [
        "Your nervous system is settled — a vigorous practice will feel alive today."
    ]

    // Recovering (score 45–74)
    private static let recoveringGeneral: [String] = [
        "A walk beats a workout today. Trust the numbers.",
        "Light movement only. Your body's still processing yesterday.",
        "Recovery IS training. You're doing it right now."
    ]

    private static let recoveringMindBody: [String] = [
        "Your nervous system is processing — restorative practice is the right call."
    ]

    // Stressed (score 0–44, non-constrained, not chronic steady)
    private static let stressedGeneral: [String] = [
        "Cancel the gym. A nap is your best performance move today.",
        "Slow down on purpose. Your nervous system is working hard.",
        "Rest isn't losing. It's the move."
    ]

    private static let stressedHIIT: [String] = [
        "CNS recovery: incomplete. Active recovery only. Skip the WOD or do a light version."
    ]

    // Constrained copy pool (UserCopyProfile == .constrained)
    // Zero-instruction missions — no "go to gym" or "skip workout" language
    private static let constrained: [String] = [
        "Your body is working really hard right now. That counts.",
        "You showed up. That's what matters today.",
        "Today's job: rest and let your body do its thing."
    ]

    // Steady state (score 0–44, isChronicSteady == true)
    private static let steady: [String] = [
        "Your body is holding steady. Keep showing up.",
        "Steady is a state, not a verdict.",
        "Today: just keep going. That's the whole job."
    ]

    // Taper phase copy
    private static let taper: [String] = [
        "HRV dip during taper is the signal you want — your body is absorbing the training.",
        "Trust the taper. What feels flat is your body consolidating."
    ]

    // Build phase copy
    private static let build: [String] = [
        "Accumulated load is normal during a build block — your body is adapting.",
        "Build fatigue is real. This is the plan working."
    ]

    // Hormonal recalibration copy (isRapidHRVDrop && isFemale40to60)
    private static let hormonalRecalibration: [String] = [
        "Your HRV shifted overnight — this is a known pattern, not a problem. Your body is recalibrating.",
        "Hormonal rhythms affect your HRV. This drop is recognized — not a warning sign."
    ]

    // MARK: - Public API

    public init() {}

    /// Selects a mission sentence and optional temporal memory sentence for the given context.
    ///
    /// - Parameter context: The current user context including score, profile, phase, and pattern flags.
    /// - Returns: A `MissionCopy` with the selected mission sentence and optional temporal memory line.
    public func select(context: MissionContext) -> MissionCopy {
        let sentence = selectMissionSentence(context: context)
        let temporal = selectTemporalMemorySentence(context: context)
        return MissionCopy(missionSentence: sentence, temporalMemorySentence: temporal)
    }

    // MARK: - Private Selection

    private func selectMissionSentence(context: MissionContext) -> String {
        // Priority 1: Hormonal recalibration
        if context.isHormonalRecalibration {
            return Self.hormonalRecalibration.randomElement()
                ?? Self.hormonalRecalibration[0]
        }

        // Priority 2: Constrained copy profile — zero-instruction language
        if context.copyProfile == .constrained {
            return Self.constrained.randomElement() ?? Self.constrained[0]
        }

        // Priority 3: Chronic steady state (score 0–44 for 14+ days)
        if context.isChronicSteady {
            return Self.steady.randomElement() ?? Self.steady[0]
        }

        // Priority 4: Training phase overrides
        switch context.trainingPhase {
        case .tapering:
            return Self.taper.randomElement() ?? Self.taper[0]
        case .building:
            // In build phase, stressed copy becomes "this is normal" copy
            if context.readinessScore < 45 {
                return Self.build.randomElement() ?? Self.build[0]
            }
        case .hiit:
            // HIIT: binary CNS routing by score band
            if context.readinessScore >= 75 {
                return Self.thrivingHIIT[0]
            } else if context.readinessScore < 45 {
                return Self.stressedHIIT[0]
            }
            // Score 45–74 in HIIT → fall through to score-band defaults
        case .none, .peaking, .racing:
            break
        }

        // Priority 5: Score-band defaults with activity type variants
        if context.readinessScore >= 75 {
            // Thriving
            if context.activityType == .mindBody {
                return Self.thrivingMindBody[0]
            }
            return Self.thrivingGeneral.randomElement() ?? Self.thrivingGeneral[0]
        } else if context.readinessScore >= 45 {
            // Recovering
            if context.activityType == .mindBody {
                return Self.recoveringMindBody[0]
            }
            return Self.recoveringGeneral.randomElement() ?? Self.recoveringGeneral[0]
        } else {
            // Stressed
            if context.activityType == .hiit {
                return Self.stressedHIIT[0]
            }
            return Self.stressedGeneral.randomElement() ?? Self.stressedGeneral[0]
        }
    }

    /// Returns a temporal memory sentence when a pattern warrants it, or nil otherwise.
    ///
    /// Shown at 13pt, 60% opacity below the mission sentence.
    private func selectTemporalMemorySentence(context: MissionContext) -> String? {
        // Multi-day stressed: shown when 3+ consecutive stressed days
        if context.consecutiveStressedDays >= 3 {
            return "You've had elevated stress readings for \(context.consecutiveStressedDays) days."
        }

        // Post-gap return: shown when 7+ days away
        if context.daysSinceLastOpen >= 7 {
            return "You were away for \(context.daysSinceLastOpen) days. "
                + "Give Thump 3–5 days to re-learn you."
        }

        return nil
    }
}

// MissionCopyEngineTests.swift
// ThumpTests
//
// Unit tests for MissionCopyEngine — validates that all 4 state copy pools
// (Thriving/Recovering/Stressed/Steady) fire correctly, training phase overrides
// work, constrained routing produces zero-instruction copy, and temporal memory
// sentences appear under the right conditions.
//
// Platforms: iOS 17+

import XCTest
@testable import Thump

// MARK: - Mission Copy Engine Tests

final class MissionCopyEngineTests: XCTestCase {

    private let engine = MissionCopyEngine()

    // MARK: - Thriving Pool (score 75–100)

    func testThriving_generalActivity_returnsCopy() {
        let context = MissionContext(
            readinessScore: 80,
            copyProfile: .autonomous,
            activityType: .general
        )
        let copy = engine.select(context: context)
        XCTAssertFalse(copy.missionSentence.isEmpty, "Thriving general copy must not be empty")
        // Verify it's from the thriving pool (not a recovery message)
        let recoveringMarkers = ["walk beats a workout", "Light movement", "Recovery IS training"]
        let isRecovering = recoveringMarkers.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isRecovering, "Score 80 should not return recovering copy")
    }

    func testThriving_hiitActivity_returnsCNSCompleteCopy() {
        let context = MissionContext(
            readinessScore: 80,
            copyProfile: .autonomous,
            trainingPhase: .hiit,
            activityType: .hiit
        )
        let copy = engine.select(context: context)
        XCTAssertTrue(
            copy.missionSentence.contains("CNS recovery: complete"),
            "HIIT thriving copy must contain 'CNS recovery: complete', got: \(copy.missionSentence)"
        )
    }

    func testThriving_mindBodyActivity_returnsMindBodyCopy() {
        let context = MissionContext(
            readinessScore: 85,
            copyProfile: .autonomous,
            activityType: .mindBody
        )
        let copy = engine.select(context: context)
        XCTAssertTrue(
            copy.missionSentence.contains("nervous system is settled"),
            "Mind-body thriving copy must mention nervous system, got: \(copy.missionSentence)"
        )
    }

    // MARK: - Recovering Pool (score 45–74)

    func testRecovering_generalActivity_returnsCopy() {
        let context = MissionContext(
            readinessScore: 60,
            copyProfile: .autonomous,
            activityType: .general
        )
        let copy = engine.select(context: context)
        XCTAssertFalse(copy.missionSentence.isEmpty, "Recovering general copy must not be empty")
        let thrivingMarkers = ["Personal record", "You've got the energy", "CNS recovery: complete"]
        let isThriving = thrivingMarkers.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isThriving, "Score 60 should not return thriving copy")
    }

    func testRecovering_mindBodyActivity_returnsMindBodyCopy() {
        let context = MissionContext(
            readinessScore: 55,
            copyProfile: .autonomous,
            activityType: .mindBody
        )
        let copy = engine.select(context: context)
        XCTAssertTrue(
            copy.missionSentence.contains("restorative practice"),
            "Mind-body recovering copy must mention restorative practice, got: \(copy.missionSentence)"
        )
    }

    func testBoundary_score74_isRecovering() {
        let context = MissionContext(readinessScore: 74, copyProfile: .autonomous)
        let copy = engine.select(context: context)
        let thrivingMarkers = ["Personal record", "You've got the energy"]
        let isThriving = thrivingMarkers.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isThriving, "Score 74 should be in recovering pool, not thriving")
    }

    func testBoundary_score75_isThriving() {
        let context = MissionContext(readinessScore: 75, copyProfile: .autonomous, activityType: .general)
        let copy = engine.select(context: context)
        // Thriving pool strings don't appear in recovering pool
        let recoveringMarkers = ["A walk beats a workout", "Light movement only", "Recovery IS training"]
        let isRecovering = recoveringMarkers.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isRecovering, "Score 75 should be in thriving pool, not recovering")
    }

    // MARK: - Stressed Pool (score 0–44)

    func testStressed_generalActivity_returnsCopy() {
        let context = MissionContext(
            readinessScore: 30,
            copyProfile: .autonomous,
            activityType: .general
        )
        let copy = engine.select(context: context)
        XCTAssertFalse(copy.missionSentence.isEmpty, "Stressed general copy must not be empty")
        let thrivingMarkers = ["Personal record", "CNS recovery: complete", "You've got the energy"]
        let isThriving = thrivingMarkers.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isThriving, "Score 30 should not return thriving copy")
    }

    func testStressed_hiitActivity_returnsCNSIncompleteCopy() {
        let context = MissionContext(
            readinessScore: 30,
            copyProfile: .autonomous,
            activityType: .hiit
        )
        let copy = engine.select(context: context)
        XCTAssertTrue(
            copy.missionSentence.contains("CNS recovery: incomplete"),
            "HIIT stressed copy must contain 'CNS recovery: incomplete', got: \(copy.missionSentence)"
        )
    }

    func testBoundary_score44_isStressed() {
        let context = MissionContext(
            readinessScore: 44,
            copyProfile: .autonomous,
            activityType: .general
        )
        let copy = engine.select(context: context)
        let recoveringMarkers = ["A walk beats a workout", "Light movement only", "Recovery IS training"]
        let isRecovering = recoveringMarkers.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isRecovering, "Score 44 should be in stressed pool, not recovering")
    }

    func testBoundary_score45_isRecovering() {
        let context = MissionContext(
            readinessScore: 45,
            copyProfile: .autonomous,
            activityType: .general
        )
        let copy = engine.select(context: context)
        let stressedMarkers = ["Cancel the gym", "Slow down on purpose", "Rest isn't losing"]
        let isStressed = stressedMarkers.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isStressed, "Score 45 should be in recovering pool, not stressed")
    }

    // MARK: - Constrained Copy Pool

    func testConstrained_returnsZeroInstructionCopy() {
        let context = MissionContext(
            readinessScore: 30,
            copyProfile: .constrained,
            activityType: .general
        )
        let copy = engine.select(context: context)
        // Constrained copy must not contain gym/workout instructions
        let forbiddenPhrases = ["gym", "workout", "exercise", "WOD", "training", "class", "PR"]
        let hasForbidden = forbiddenPhrases.contains { copy.missionSentence.lowercased().contains($0.lowercased()) }
        XCTAssertFalse(hasForbidden,
            "Constrained copy must not contain workout instructions, got: \(copy.missionSentence)")
    }

    func testConstrained_overridesScoreBand_evenWhenThriving() {
        // Constrained profile should always use the constrained pool, regardless of score
        let context = MissionContext(
            readinessScore: 90,
            copyProfile: .constrained,
            activityType: .general
        )
        let copy = engine.select(context: context)
        let thrivingPhrases = ["Personal record", "You've got the energy", "Push in your workout"]
        let isThriving = thrivingPhrases.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isThriving, "Constrained profile must not return thriving push copy, even at score 90")
    }

    func testConstrained_overridesTrainingPhase() {
        // Constrained takes priority over training phase
        let context = MissionContext(
            readinessScore: 40,
            copyProfile: .constrained,
            trainingPhase: .tapering
        )
        let copy = engine.select(context: context)
        let taperPhrases = ["Trust the taper", "HRV dip during taper"]
        let isTaper = taperPhrases.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isTaper, "Constrained profile must override training phase taper copy")
    }

    // MARK: - Steady State Pool

    func testChronicSteady_returnsStedyCopy() {
        let context = MissionContext(
            readinessScore: 30,
            copyProfile: .autonomous,
            isChronicSteady: true
        )
        let copy = engine.select(context: context)
        let steadyPhrases = ["holding steady", "Steady is a state", "just keep going"]
        let isSteady = steadyPhrases.contains { copy.missionSentence.contains($0) }
        XCTAssertTrue(isSteady, "isChronicSteady should return steady copy, got: \(copy.missionSentence)")
    }

    func testChronicSteady_doesNotReturnStressedCopy() {
        let context = MissionContext(
            readinessScore: 20,
            copyProfile: .autonomous,
            isChronicSteady: true
        )
        let copy = engine.select(context: context)
        let stressedPhrases = ["Cancel the gym", "Slow down on purpose", "Rest isn't losing"]
        let isStressed = stressedPhrases.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isStressed, "isChronicSteady must override stressed pool")
    }

    // MARK: - Training Phase Copy

    func testTaperPhase_returnsTaperCopy() {
        let context = MissionContext(
            readinessScore: 40,
            copyProfile: .autonomous,
            trainingPhase: .tapering
        )
        let copy = engine.select(context: context)
        let taperPhrases = ["Trust the taper", "HRV dip during taper"]
        let isTaper = taperPhrases.contains { copy.missionSentence.contains($0) }
        XCTAssertTrue(isTaper, "Tapering phase must return taper copy, got: \(copy.missionSentence)")
    }

    func testBuildPhase_lowScore_returnsBuildCopy() {
        let context = MissionContext(
            readinessScore: 35,
            copyProfile: .autonomous,
            trainingPhase: .building
        )
        let copy = engine.select(context: context)
        let buildPhrases = ["Accumulated load is normal", "Build fatigue is real"]
        let isBuild = buildPhrases.contains { copy.missionSentence.contains($0) }
        XCTAssertTrue(isBuild, "Building phase + low score must return build copy, got: \(copy.missionSentence)")
    }

    func testBuildPhase_highScore_fallsThroughToThriving() {
        let context = MissionContext(
            readinessScore: 80,
            copyProfile: .autonomous,
            trainingPhase: .building,
            activityType: .general
        )
        let copy = engine.select(context: context)
        // Build override only fires for score < 45; high score uses thriving pool
        let buildPhrases = ["Accumulated load is normal", "Build fatigue is real"]
        let isBuild = buildPhrases.contains { copy.missionSentence.contains($0) }
        XCTAssertFalse(isBuild, "Build phase at score 80 should fall through to thriving copy")
    }

    func testHIITPhase_lowScore_returnsCNSIncompleteCopy() {
        let context = MissionContext(
            readinessScore: 40,
            copyProfile: .autonomous,
            trainingPhase: .hiit
        )
        let copy = engine.select(context: context)
        XCTAssertTrue(
            copy.missionSentence.contains("CNS recovery: incomplete"),
            "HIIT phase + low score must return CNS incomplete copy, got: \(copy.missionSentence)"
        )
    }

    func testHIITPhase_highScore_returnsCNSCompleteCopy() {
        let context = MissionContext(
            readinessScore: 80,
            copyProfile: .autonomous,
            trainingPhase: .hiit
        )
        let copy = engine.select(context: context)
        XCTAssertTrue(
            copy.missionSentence.contains("CNS recovery: complete"),
            "HIIT phase + high score must return CNS complete copy, got: \(copy.missionSentence)"
        )
    }

    // MARK: - Hormonal Recalibration

    func testHormonalRecalibration_overridesAllOtherPools() {
        let context = MissionContext(
            readinessScore: 30,
            copyProfile: .autonomous,
            trainingPhase: .tapering,
            isHormonalRecalibration: true
        )
        let copy = engine.select(context: context)
        let hormonalPhrases = ["known pattern, not a problem", "Hormonal rhythms"]
        let isHormonal = hormonalPhrases.contains { copy.missionSentence.contains($0) }
        XCTAssertTrue(isHormonal,
            "isHormonalRecalibration must override all other copy pools, got: \(copy.missionSentence)")
    }

    // MARK: - Temporal Memory Sentences

    func testTemporalMemory_multiDayStressed_appearsAt3Days() {
        let context = MissionContext(
            readinessScore: 30,
            consecutiveStressedDays: 3
        )
        let copy = engine.select(context: context)
        XCTAssertNotNil(copy.temporalMemorySentence,
            "Temporal memory sentence should appear after 3 consecutive stressed days")
        XCTAssertTrue(
            copy.temporalMemorySentence?.contains("3 days") ?? false,
            "Temporal memory sentence should mention 3 days, got: \(String(describing: copy.temporalMemorySentence))"
        )
    }

    func testTemporalMemory_multiDayStressed_suppressedBelow3Days() {
        let context = MissionContext(
            readinessScore: 30,
            consecutiveStressedDays: 2
        )
        let copy = engine.select(context: context)
        XCTAssertNil(copy.temporalMemorySentence,
            "Temporal memory sentence must not appear before 3 consecutive stressed days")
    }

    func testTemporalMemory_postGap_appearsAt7Days() {
        let context = MissionContext(
            readinessScore: 60,
            daysSinceLastOpen: 7
        )
        let copy = engine.select(context: context)
        XCTAssertNotNil(copy.temporalMemorySentence,
            "Temporal memory sentence should appear after 7 days away")
        XCTAssertTrue(
            copy.temporalMemorySentence?.contains("7 days") ?? false,
            "Post-gap sentence should mention 7 days, got: \(String(describing: copy.temporalMemorySentence))"
        )
    }

    func testTemporalMemory_postGap_suppressedBelow7Days() {
        let context = MissionContext(
            readinessScore: 60,
            daysSinceLastOpen: 6
        )
        let copy = engine.select(context: context)
        // 6 days — only the stressed-days trigger would fire (none here)
        XCTAssertNil(copy.temporalMemorySentence,
            "Post-gap temporal memory must not appear before 7 days away")
    }

    func testTemporalMemory_multiDayStressedTakesPrecedence() {
        // Both conditions true: 3+ stressed days AND 7+ days since open
        let context = MissionContext(
            readinessScore: 30,
            consecutiveStressedDays: 5,
            daysSinceLastOpen: 10
        )
        let copy = engine.select(context: context)
        XCTAssertNotNil(copy.temporalMemorySentence)
        // Multi-day stressed takes priority (it's checked first)
        XCTAssertTrue(
            copy.temporalMemorySentence?.contains("5 days") ?? false,
            "Multi-day stressed pattern should take precedence over post-gap"
        )
    }

    // MARK: - Copy Completeness (No Empty Strings)

    func testAllStates_returnNonEmptyCopy() {
        let testCases: [MissionContext] = [
            MissionContext(readinessScore: 80, copyProfile: .autonomous),
            MissionContext(readinessScore: 60, copyProfile: .autonomous),
            MissionContext(readinessScore: 30, copyProfile: .autonomous),
            MissionContext(readinessScore: 30, copyProfile: .constrained),
            MissionContext(readinessScore: 30, isChronicSteady: true),
            MissionContext(readinessScore: 40, trainingPhase: .tapering),
            MissionContext(readinessScore: 35, trainingPhase: .building),
            MissionContext(readinessScore: 80, trainingPhase: .hiit),
            MissionContext(readinessScore: 30, trainingPhase: .hiit),
            MissionContext(readinessScore: 30, isHormonalRecalibration: true),
            MissionContext(readinessScore: 85, activityType: .mindBody),
            MissionContext(readinessScore: 55, activityType: .mindBody),
        ]

        for context in testCases {
            let copy = engine.select(context: context)
            XCTAssertFalse(
                copy.missionSentence.isEmpty,
                "Empty mission sentence for context: score=\(context.readinessScore), "
                    + "profile=\(context.copyProfile), phase=\(context.trainingPhase)"
            )
        }
    }
}

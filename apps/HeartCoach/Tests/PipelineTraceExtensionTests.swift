// PipelineTraceExtensionTests.swift
// ThumpCoreTests
//
// Tests for Phase 4 PipelineTrace extensions: AdviceTrace, CoherenceTrace,
// CorrelationTrace, NudgeSchedulerTrace.

import XCTest
@testable import Thump

final class PipelineTraceExtensionTests: XCTestCase {

    // MARK: - AdviceTrace Tests

    func testAdviceTrace_fromState_capturesCategoricalData() {
        let state = AdviceState(
            mode: .moderateMove,
            riskBand: .moderate,
            overtrainingState: .none,
            sleepDeprivationFlag: false,
            medicalEscalationFlag: false,
            heroCategory: .encourage,
            heroMessageID: "hero_decent",
            buddyMoodCategory: .encouraging,
            focusInsightID: "insight_decent",
            checkBadgeID: "check_moderate",
            goals: [
                GoalSpec(category: .steps, target: 7000, current: 3000, nudgeTextID: "steps_almost", label: "Steps")
            ],
            recoveryDriver: nil,
            stressGuidanceLevel: .balanced,
            smartActions: [.walkSuggestion],
            allowedIntensity: .moderate,
            nudgePriorities: [.walk],
            positivityAnchorID: nil
        )

        let trace = AdviceTrace(from: state, durationMs: 2.5)
        XCTAssertEqual(trace.mode, "moderateMove")
        XCTAssertEqual(trace.riskBand, "moderate")
        XCTAssertEqual(trace.overtrainingState, "none")
        XCTAssertEqual(trace.heroCategory, "encourage")
        XCTAssertEqual(trace.allowedIntensity, "moderate")
        XCTAssertEqual(trace.goalStepTarget, 7000)
        XCTAssertFalse(trace.positivityAnchorInjected)
        XCTAssertEqual(trace.durationMs, 2.5)
    }

    func testAdviceTrace_toDict_hasAllKeys() {
        let state = AdviceState(
            mode: .pushDay,
            riskBand: .low,
            overtrainingState: .none,
            sleepDeprivationFlag: false,
            medicalEscalationFlag: false,
            heroCategory: .celebrate,
            heroMessageID: "hero_charged",
            buddyMoodCategory: .celebrating,
            focusInsightID: "insight_recovered",
            checkBadgeID: "check_push",
            goals: [],
            recoveryDriver: nil,
            stressGuidanceLevel: .relaxed,
            smartActions: [],
            allowedIntensity: .full,
            nudgePriorities: [],
            positivityAnchorID: nil
        )

        let dict = AdviceTrace(from: state, durationMs: 1.0).toDict()
        XCTAssertEqual(dict.count, 8)
        XCTAssertNotNil(dict["mode"])
        XCTAssertNotNil(dict["riskBand"])
        XCTAssertNotNil(dict["overtrainingState"])
        XCTAssertNotNil(dict["heroCategory"])
        XCTAssertNotNil(dict["allowedIntensity"])
        XCTAssertNotNil(dict["goalStepTarget"])
        XCTAssertNotNil(dict["positivityAnchorInjected"])
        XCTAssertNotNil(dict["durationMs"])
    }

    func testAdviceTrace_positivityAnchorInjected_whenPresent() {
        let state = AdviceState(
            mode: .lightRecovery,
            riskBand: .elevated,
            overtrainingState: .none,
            sleepDeprivationFlag: true,
            medicalEscalationFlag: false,
            heroCategory: .caution,
            heroMessageID: "hero_rough_night",
            buddyMoodCategory: .resting,
            focusInsightID: "insight_rough_night",
            checkBadgeID: "check_light",
            goals: [],
            recoveryDriver: .lowSleep,
            stressGuidanceLevel: .elevated,
            smartActions: [],
            allowedIntensity: .light,
            nudgePriorities: [.rest],
            positivityAnchorID: "positivity_recovery_progress"
        )

        let trace = AdviceTrace(from: state, durationMs: 1.0)
        XCTAssertTrue(trace.positivityAnchorInjected)
    }

    // MARK: - CoherenceTrace Tests

    func testCoherenceTrace_toDict() {
        let trace = CoherenceTrace(
            hardInvariantsChecked: 5,
            hardViolationsFound: 1,
            hardViolations: ["INV-001: test"],
            softAnomaliesFound: 2,
            softAnomalies: ["ANO-001: test", "ANO-002: test"]
        )

        let dict = trace.toDict()
        XCTAssertEqual(dict["hardInvariantsChecked"] as? Int, 5)
        XCTAssertEqual(dict["hardViolationsFound"] as? Int, 1)
        XCTAssertEqual((dict["hardViolations"] as? [String])?.count, 1)
        XCTAssertEqual(dict["softAnomaliesFound"] as? Int, 2)
        XCTAssertEqual((dict["softAnomalies"] as? [String])?.count, 2)
    }

    // MARK: - CorrelationTrace Tests

    func testCorrelationTrace_fromResults() {
        let correlations = [
            CorrelationResult(factorName: "Sleep Hours", correlationStrength: 0.72, interpretation: "Strong", confidence: .high, isBeneficial: true),
            CorrelationResult(factorName: "Steps", correlationStrength: -0.35, interpretation: "Moderate", confidence: .medium, isBeneficial: true),
            CorrelationResult(factorName: "Workout", correlationStrength: 0.55, interpretation: "Strong", confidence: .medium, isBeneficial: true),
        ]

        let trace = CorrelationTrace(from: correlations, durationMs: 5.0)
        XCTAssertEqual(trace.pairsAnalyzed, 3)
        XCTAssertEqual(trace.significantPairs, 2) // Sleep (0.72) and Workout (0.55)
        XCTAssertEqual(trace.topFactorName, "Sleep Hours") // highest abs correlation
        XCTAssertEqual(trace.durationMs, 5.0)
    }

    func testCorrelationTrace_emptyCorrelations() {
        let trace = CorrelationTrace(from: [], durationMs: 0.1)
        XCTAssertEqual(trace.pairsAnalyzed, 0)
        XCTAssertEqual(trace.significantPairs, 0)
        XCTAssertNil(trace.topFactorName)
    }

    func testCorrelationTrace_toDict() {
        let trace = CorrelationTrace(from: [
            CorrelationResult(factorName: "HRV", correlationStrength: 0.6, interpretation: "OK", confidence: .medium)
        ], durationMs: 3.0)

        let dict = trace.toDict()
        XCTAssertEqual(dict["pairsAnalyzed"] as? Int, 1)
        XCTAssertEqual(dict["significantPairs"] as? Int, 1)
        XCTAssertEqual(dict["topFactorName"] as? String, "HRV")
        XCTAssertEqual(dict["durationMs"] as? Double, 3.0)
    }

    // MARK: - NudgeSchedulerTrace Tests

    func testNudgeSchedulerTrace_fromPatterns() {
        let patterns = [
            SleepPattern(dayOfWeek: 1, typicalBedtimeHour: 22, typicalWakeHour: 6, observationCount: 4),
            SleepPattern(dayOfWeek: 2, typicalBedtimeHour: 23, typicalWakeHour: 7, observationCount: 3),
        ]

        let trace = NudgeSchedulerTrace(from: patterns, durationMs: 1.5)
        XCTAssertEqual(trace.patternsLearned, 2)
        XCTAssertEqual(trace.bedtimeNudgeHour, 22) // first pattern's bedtime
        XCTAssertEqual(trace.durationMs, 1.5)
    }

    func testNudgeSchedulerTrace_emptyPatterns() {
        let trace = NudgeSchedulerTrace(from: [], durationMs: 0.5)
        XCTAssertEqual(trace.patternsLearned, 0)
        XCTAssertNil(trace.bedtimeNudgeHour)
    }

    func testNudgeSchedulerTrace_toDict() {
        let trace = NudgeSchedulerTrace(from: [
            SleepPattern(dayOfWeek: 3, typicalBedtimeHour: 21, typicalWakeHour: 5, observationCount: 7)
        ], durationMs: 2.0)

        let dict = trace.toDict()
        XCTAssertEqual(dict["patternsLearned"] as? Int, 1)
        XCTAssertEqual(dict["bedtimeNudgeHour"] as? Int, 21)
        XCTAssertEqual(dict["durationMs"] as? Double, 2.0)
    }

    // MARK: - Privacy: No Raw Health Values

    func testAdviceTrace_containsNoCategoricalDataOnly() {
        let state = AdviceState(
            mode: .lightRecovery,
            riskBand: .elevated,
            overtrainingState: .watch,
            sleepDeprivationFlag: true,
            medicalEscalationFlag: false,
            heroCategory: .caution,
            heroMessageID: "hero_rough_night",
            buddyMoodCategory: .concerned,
            focusInsightID: "insight_rough_night",
            checkBadgeID: "check_light",
            goals: [GoalSpec(category: .steps, target: 3000, current: 500, nudgeTextID: "steps_start", label: "Steps")],
            recoveryDriver: .lowSleep,
            stressGuidanceLevel: .elevated,
            smartActions: [.restSuggestion],
            allowedIntensity: .light,
            nudgePriorities: [.rest],
            positivityAnchorID: "positivity_recovery_progress"
        )

        let dict = AdviceTrace(from: state, durationMs: 1.0).toDict()

        // Verify only string/int/bool values — no raw health metrics
        for (key, value) in dict {
            XCTAssertTrue(
                value is String || value is Int || value is Bool || value is Double,
                "AdviceTrace key '\(key)' should be a simple type, got \(type(of: value))"
            )
            // Should not contain any raw values like heart rate, HRV, etc.
            if let str = value as? String {
                XCTAssertFalse(str.contains("bpm"), "AdviceTrace should not contain 'bpm'")
                XCTAssertFalse(str.contains("ms"), "AdviceTrace value should not contain raw 'ms' units")
            }
        }
    }
}

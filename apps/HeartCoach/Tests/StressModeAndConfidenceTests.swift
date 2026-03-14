// StressModeAndConfidenceTests.swift
// ThumpTests
//
// Tests for context-aware mode detection, confidence calibration,
// desk-branch RHR reduction, and disagreement damping behavior.

import XCTest
@testable import Thump

final class StressModeAndConfidenceTests: XCTestCase {

    // MARK: - Mode Detection

    func testModeDetection_highSteps_returnsAcute() {
        let engine = StressEngine()
        let mode = engine.detectMode(
            recentSteps: 10000,
            recentWorkoutMinutes: nil,
            sedentaryMinutes: nil
        )
        XCTAssertEqual(mode, .acute, "High step count should route to acute mode")
    }

    func testModeDetection_workout_returnsAcute() {
        let engine = StressEngine()
        let mode = engine.detectMode(
            recentSteps: nil,
            recentWorkoutMinutes: 30,
            sedentaryMinutes: nil
        )
        XCTAssertEqual(mode, .acute, "Active workout should route to acute mode")
    }

    func testModeDetection_lowSteps_returnsDesk() {
        let engine = StressEngine()
        let mode = engine.detectMode(
            recentSteps: 500,
            recentWorkoutMinutes: nil,
            sedentaryMinutes: 180
        )
        XCTAssertEqual(mode, .desk, "Low steps + high sedentary should route to desk mode")
    }

    func testModeDetection_lowStepsOnly_returnsDesk() {
        let engine = StressEngine()
        let mode = engine.detectMode(
            recentSteps: 1000,
            recentWorkoutMinutes: nil,
            sedentaryMinutes: nil
        )
        XCTAssertEqual(mode, .desk, "Low steps alone should route to desk mode")
    }

    func testModeDetection_noContext_returnsUnknown() {
        let engine = StressEngine()
        let mode = engine.detectMode(
            recentSteps: nil,
            recentWorkoutMinutes: nil,
            sedentaryMinutes: nil
        )
        XCTAssertEqual(mode, .unknown, "No context signals should return unknown mode")
    }

    func testModeDetection_moderateSteps_noWorkout_returnsDesk() {
        let engine = StressEngine()
        let mode = engine.detectMode(
            recentSteps: 3000,
            recentWorkoutMinutes: nil,
            sedentaryMinutes: nil
        )
        XCTAssertEqual(mode, .desk, "Moderate-low steps without workout should route to desk")
    }

    func testModeDetection_moderateSteps_withWorkout_returnsAcute() {
        let engine = StressEngine()
        let mode = engine.detectMode(
            recentSteps: 5000,
            recentWorkoutMinutes: 10,
            sedentaryMinutes: nil
        )
        XCTAssertEqual(mode, .acute, "Moderate steps + workout should route to acute")
    }

    // MARK: - Confidence Calibration

    func testConfidence_fullSignals_returnsHighOrModerate() {
        let engine = StressEngine()
        let context = StressContextInput(
            currentHRV: 40.0,
            baselineHRV: 50.0,
            baselineHRVSD: 8.0,
            currentRHR: 75.0,
            baselineRHR: 65.0,
            recentHRVs: [48, 52, 47, 51, 49, 50, 46],
            recentSteps: 500,
            recentWorkoutMinutes: 0,
            sedentaryMinutes: 200,
            sleepHours: 7.0
        )
        let result = engine.computeStress(context: context)
        XCTAssertTrue(
            result.confidence == .high || result.confidence == .moderate,
            "Full signals with good baseline should yield high or moderate confidence, got \(result.confidence)"
        )
    }

    func testConfidence_sparseSignals_reducesConfidence() {
        let engine = StressEngine()
        // No RHR, no recent HRVs, no baseline SD — very sparse signals
        let context = StressContextInput(
            currentHRV: 40.0,
            baselineHRV: 50.0,
            baselineHRVSD: nil,
            currentRHR: nil,
            baselineRHR: nil,
            recentHRVs: nil,
            recentSteps: nil,
            recentWorkoutMinutes: nil,
            sedentaryMinutes: nil,
            sleepHours: nil
        )
        let result = engine.computeStress(context: context)
        // With no RHR, no CV data, no baseline SD — confidence should be reduced
        XCTAssertTrue(
            result.confidence == .moderate || result.confidence == .low,
            "Sparse signals should reduce confidence, got \(result.confidence)"
        )
    }

    func testConfidence_zeroBaseline_returnsLow() {
        let engine = StressEngine()
        let context = StressContextInput(
            currentHRV: 40.0,
            baselineHRV: 0.0,
            baselineHRVSD: nil,
            currentRHR: nil,
            baselineRHR: nil,
            recentHRVs: nil,
            recentSteps: nil,
            recentWorkoutMinutes: nil,
            sedentaryMinutes: nil,
            sleepHours: nil
        )
        let result = engine.computeStress(context: context)
        XCTAssertEqual(result.confidence, .low, "Zero baseline should yield low confidence")
        XCTAssertEqual(result.score, 50.0, "Zero baseline should return default score of 50")
    }

    // MARK: - Desk Branch Behavior

    func testDeskMode_reducesRHRInfluence() {
        let engine = StressEngine()
        // Scenario: RHR elevated but HRV is fine — desk mode should not alarm
        let deskContext = StressContextInput(
            currentHRV: 50.0,
            baselineHRV: 50.0,
            baselineHRVSD: 8.0,
            currentRHR: 85.0,
            baselineRHR: 65.0,
            recentHRVs: [48, 52, 50, 49, 51],
            recentSteps: 500,
            recentWorkoutMinutes: 0,
            sedentaryMinutes: 200,
            sleepHours: nil
        )
        let deskResult = engine.computeStress(context: deskContext)

        // Same physiology but acute mode
        let acuteContext = StressContextInput(
            currentHRV: 50.0,
            baselineHRV: 50.0,
            baselineHRVSD: 8.0,
            currentRHR: 85.0,
            baselineRHR: 65.0,
            recentHRVs: [48, 52, 50, 49, 51],
            recentSteps: 10000,
            recentWorkoutMinutes: 30,
            sedentaryMinutes: nil,
            sleepHours: nil
        )
        let acuteResult = engine.computeStress(context: acuteContext)

        XCTAssertEqual(deskResult.mode, .desk)
        XCTAssertEqual(acuteResult.mode, .acute)
        XCTAssertLessThan(
            deskResult.score, acuteResult.score,
            "Desk mode should score lower than acute when only RHR is elevated "
                + "(desk=\(String(format: "%.1f", deskResult.score)), acute=\(String(format: "%.1f", acuteResult.score)))"
        )
    }

    // MARK: - Disagreement Damping

    func testDisagreementDamping_compressesScore() {
        let engine = StressEngine()
        // RHR high stress + HRV normal + CV stable → disagreement
        let context = StressContextInput(
            currentHRV: 52.0,
            baselineHRV: 50.0,
            baselineHRVSD: 8.0,
            currentRHR: 95.0,
            baselineRHR: 65.0,
            recentHRVs: [50, 51, 49, 50, 52],
            recentSteps: 500,
            recentWorkoutMinutes: 0,
            sedentaryMinutes: 200,
            sleepHours: nil
        )
        let result = engine.computeStress(context: context)

        // Score should be compressed toward neutral due to disagreement
        XCTAssertLessThan(
            result.score, 70,
            "Disagreement damping should compress score below 70, got \(result.score)"
        )
        // Warnings should mention signal conflict
        let hasConflictWarning = result.warnings.contains {
            $0.lowercased().contains("disagree") || $0.lowercased().contains("mixed")
        }
        if !result.warnings.isEmpty {
            XCTAssertTrue(
                hasConflictWarning,
                "Expected disagreement/mixed-signal warning in: \(result.warnings)"
            )
        }
    }

    // MARK: - Signal Breakdown

    func testStressResult_containsSignalBreakdown() {
        let engine = StressEngine()
        let context = StressContextInput(
            currentHRV: 35.0,
            baselineHRV: 50.0,
            baselineHRVSD: 8.0,
            currentRHR: 80.0,
            baselineRHR: 65.0,
            recentHRVs: [48, 52, 47, 51, 49],
            recentSteps: 500,
            recentWorkoutMinutes: 0,
            sedentaryMinutes: 200,
            sleepHours: nil
        )
        let result = engine.computeStress(context: context)
        XCTAssertNotNil(result.signalBreakdown, "Context-aware path should populate signal breakdown")

        if let breakdown = result.signalBreakdown {
            XCTAssertGreaterThanOrEqual(breakdown.rhrContribution, 0)
            XCTAssertGreaterThanOrEqual(breakdown.hrvContribution, 0)
            XCTAssertGreaterThanOrEqual(breakdown.cvContribution, 0)
            let total = breakdown.rhrContribution + breakdown.hrvContribution + breakdown.cvContribution
            XCTAssertGreaterThan(total, 0, "Signal breakdown should have non-zero total")
        }
    }
}

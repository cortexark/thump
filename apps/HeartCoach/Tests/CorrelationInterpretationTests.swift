// CorrelationInterpretationTests.swift
// ThumpCoreTests
//
// Tests that correlation interpretation strings use personal,
// actionable language instead of generic statistics textbook phrasing.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import Thump

// MARK: - CorrelationInterpretationTests

final class CorrelationInterpretationTests: XCTestCase {

    // MARK: - Properties

    private let engine = CorrelationEngine()

    // MARK: - Banned Phrases

    /// Phrases that should never appear in any interpretation string.
    private let bannedPhrases = [
        "correlation",
        "associated with",
        "positive sign for your cardiovascular"
    ]

    // MARK: - Test: Steps vs RHR — Strong Negative

    /// A strong negative relationship (r ~ -0.65) between steps and RHR
    /// should mention walking/steps and resting heart rate, never "correlation".
    func testStepsVsRHR_strongNegative_usesPersonalLanguage() throws {
        // Build data where steps go up and RHR goes down linearly
        // to produce r around -0.65 to -0.99
        let history = makeLinearHistory(
            days: 14,
            xStart: 4000, xStep: 600,   // steps: 4000 -> 11800
            yStart: 72,   yStep: -0.5,  // rhr: 72 -> 65.5
            factor: .stepsVsRHR
        )

        let results = engine.analyze(history: history)
        let stepsResult = try XCTUnwrap(
            results.first(where: { $0.factorName == "Daily Steps" }),
            "Should produce a Daily Steps correlation"
        )

        let text = stepsResult.interpretation.lowercased()

        // Must mention walking or steps
        let mentionsActivity = text.contains("walk") || text.contains("step")
        XCTAssertTrue(mentionsActivity,
            "Should mention walk or step, got: \(stepsResult.interpretation)")

        // Must mention resting heart rate
        XCTAssertTrue(text.contains("resting heart rate"),
            "Should mention resting heart rate, got: \(stepsResult.interpretation)")

        // Must NOT contain banned phrases
        assertNoBannedPhrases(in: stepsResult.interpretation)
    }

    // MARK: - Test: Sleep vs HRV — Moderate Positive

    /// A moderate positive relationship (r ~ 0.55) between sleep and HRV
    /// should mention sleep and HRV without clinical filler.
    func testSleepVsHRV_moderatePositive_usesPersonalLanguage() throws {
        let history = makeLinearHistory(
            days: 14,
            xStart: 5.5, xStep: 0.15,   // sleep: 5.5 -> 7.45 hours
            yStart: 35,  yStep: 1.2,     // hrv: 35 -> 51.8
            factor: .sleepVsHRV
        )

        let results = engine.analyze(history: history)
        let sleepResult = try XCTUnwrap(
            results.first(where: { $0.factorName == "Sleep Hours" }),
            "Should produce a Sleep Hours correlation"
        )

        let text = sleepResult.interpretation.lowercased()

        // Must mention sleep
        XCTAssertTrue(text.contains("sleep"),
            "Should mention sleep, got: \(sleepResult.interpretation)")

        // Must mention HRV
        XCTAssertTrue(text.contains("hrv"),
            "Should mention HRV, got: \(sleepResult.interpretation)")

        // Must NOT contain old filler
        XCTAssertFalse(
            text.contains("positive sign for your cardiovascular health"),
            "Should not contain generic AI filler, got: \(sleepResult.interpretation)"
        )

        assertNoBannedPhrases(in: sleepResult.interpretation)
    }

    // MARK: - Test: Activity vs Recovery — Strong Positive

    /// A strong positive relationship (r ~ 0.72) between activity and recovery
    /// should produce actionable text, not parenthetical stats.
    func testActivityVsRecovery_strongPositive_isActionable() throws {
        let history = makeLinearHistory(
            days: 14,
            xStart: 15,  xStep: 3,     // workout: 15 -> 54 min
            yStart: 18,  yStep: 1.0,   // recovery: 18 -> 31 bpm drop
            factor: .activityVsRecovery
        )

        let results = engine.analyze(history: history)
        let activityResult = try XCTUnwrap(
            results.first(where: { $0.factorName == "Activity Minutes" }),
            "Should produce an Activity Minutes correlation"
        )

        let text = activityResult.interpretation

        // Must NOT contain parenthetical stats jargon
        XCTAssertFalse(
            text.contains("(a very strong positive correlation)"),
            "Should not contain parenthetical stats, got: \(text)"
        )
        XCTAssertFalse(
            text.contains("(a strong positive correlation)"),
            "Should not contain parenthetical stats, got: \(text)"
        )

        assertNoBannedPhrases(in: activityResult.interpretation)
    }

    // MARK: - Test: Weak Correlation — No Scientific Jargon

    /// A weak relationship (|r| ~ 0.15) should produce reasonable text
    /// without scientific jargon.
    func testWeakCorrelation_noScientificJargon() throws {
        // Use near-constant data with small noise to get |r| < 0.2
        let history = makeNoisyHistory(
            days: 14,
            xBase: 8000, xNoise: 200,
            yBase: 62,   yNoise: 1.5,
            factor: .stepsVsRHR
        )

        let results = engine.analyze(history: history)
        let stepsResult = try XCTUnwrap(
            results.first(where: { $0.factorName == "Daily Steps" }),
            "Should produce a Daily Steps correlation"
        )

        assertNoBannedPhrases(in: stepsResult.interpretation)

        // Negligible result should still read naturally
        let text = stepsResult.interpretation.lowercased()
        XCTAssertFalse(text.isEmpty, "Even weak correlations should produce text")
    }

    // MARK: - Test: No Interpretation Contains Banned Words

    /// Comprehensive check: run all four factor pairs and verify none
    /// of the banned phrases appear in any interpretation string.
    func testNoInterpretationContainsBannedPhrases() {
        let history = makeLinearHistory(
            days: 14,
            xStart: 5000, xStep: 400,
            yStart: 68,   yStep: -0.4,
            factor: .all
        )

        let results = engine.analyze(history: history)
        XCTAssertFalse(results.isEmpty, "Should produce at least one result")

        for result in results {
            assertNoBannedPhrases(in: result.interpretation)
        }
    }
}

// MARK: - Test Helpers

extension CorrelationInterpretationTests {

    /// Factor pair selector for building targeted test data.
    private enum FactorPair {
        case stepsVsRHR
        case walkVsHRV
        case activityVsRecovery
        case sleepVsHRV
        case all
    }

    /// Assert that none of the banned phrases appear in the text.
    private func assertNoBannedPhrases(
        in text: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let lower = text.lowercased()
        for phrase in bannedPhrases {
            XCTAssertFalse(
                lower.contains(phrase.lowercased()),
                "Interpretation should not contain \"\(phrase)\", got: \(text)",
                file: file,
                line: line
            )
        }
    }

    /// Build a history where x and y increase linearly, producing a strong
    /// Pearson r close to +1 or -1 depending on step direction.
    private func makeLinearHistory(
        days: Int,
        xStart: Double,
        xStep: Double,
        yStart: Double,
        yStep: Double,
        factor: FactorPair
    ) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<days).compactMap { i in
            guard let date = calendar.date(
                byAdding: .day, value: -(days - i), to: today
            ) else { return nil }

            let xVal = xStart + Double(i) * xStep
            let yVal = yStart + Double(i) * yStep

            switch factor {
            case .stepsVsRHR:
                return HeartSnapshot(
                    date: date,
                    restingHeartRate: yVal,
                    steps: xVal
                )
            case .walkVsHRV:
                return HeartSnapshot(
                    date: date,
                    hrvSDNN: yVal,
                    walkMinutes: xVal
                )
            case .activityVsRecovery:
                return HeartSnapshot(
                    date: date,
                    recoveryHR1m: yVal,
                    workoutMinutes: xVal
                )
            case .sleepVsHRV:
                return HeartSnapshot(
                    date: date,
                    hrvSDNN: yVal,
                    sleepHours: xVal
                )
            case .all:
                return HeartSnapshot(
                    date: date,
                    restingHeartRate: yVal,
                    hrvSDNN: yVal + 10,
                    recoveryHR1m: yVal + 5,
                    steps: xVal,
                    walkMinutes: xVal / 100,
                    workoutMinutes: xVal / 80,
                    sleepHours: 5.0 + Double(i) * 0.15
                )
            }
        }
    }

    /// Build a history with near-random noise to produce a negligible |r|.
    private func makeNoisyHistory(
        days: Int,
        xBase: Double,
        xNoise: Double,
        yBase: Double,
        yNoise: Double,
        factor: FactorPair
    ) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<days).compactMap { i in
            guard let date = calendar.date(
                byAdding: .day, value: -(days - i), to: today
            ) else { return nil }

            // Use sin/cos with different frequencies to decorrelate x and y
            let xVal = xBase + sin(Double(i) * 2.7) * xNoise
            let yVal = yBase + cos(Double(i) * 1.3) * yNoise

            switch factor {
            case .stepsVsRHR:
                return HeartSnapshot(
                    date: date,
                    restingHeartRate: yVal,
                    steps: xVal
                )
            case .walkVsHRV:
                return HeartSnapshot(
                    date: date,
                    hrvSDNN: yVal,
                    walkMinutes: xVal
                )
            case .activityVsRecovery:
                return HeartSnapshot(
                    date: date,
                    recoveryHR1m: yVal,
                    workoutMinutes: xVal
                )
            case .sleepVsHRV:
                return HeartSnapshot(
                    date: date,
                    hrvSDNN: yVal,
                    sleepHours: xVal
                )
            case .all:
                return HeartSnapshot(
                    date: date,
                    restingHeartRate: yVal,
                    hrvSDNN: yVal,
                    recoveryHR1m: yVal,
                    steps: xVal,
                    walkMinutes: xVal,
                    workoutMinutes: xVal,
                    sleepHours: xVal
                )
            }
        }
    }
}

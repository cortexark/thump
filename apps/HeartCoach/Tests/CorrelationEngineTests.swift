// CorrelationEngineTests.swift
// ThumpCoreTests
//
// Unit tests for CorrelationEngine covering Pearson coefficient computation,
// interpretation logic, factor pairing, edge cases, and data sufficiency checks.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import Thump

// MARK: - CorrelationEngineTests

final class CorrelationEngineTests: XCTestCase {

    // MARK: - Properties

    private let engine = CorrelationEngine()

    // MARK: - Test: Empty History

    /// An empty history array should produce zero correlation results.
    func testEmptyHistoryReturnsNoResults() {
        let results = engine.analyze(history: [])
        XCTAssertTrue(results.isEmpty, "Empty history should produce no correlations")
    }

    // MARK: - Test: Insufficient Data Points

    /// Fewer than 7 paired data points should produce no results for that pair.
    func testInsufficientDataPointsReturnsNoResults() {
        let history = makeHistory(
            days: 5,
            steps: 8000,
            rhr: 62,
            walkMinutes: 30,
            hrv: 55,
            workoutMinutes: nil,
            recoveryHR1m: nil,
            sleepHours: nil
        )

        let results = engine.analyze(history: history)
        XCTAssertTrue(results.isEmpty, "5 days of data is below the 7-point minimum")
    }

    // MARK: - Test: Sufficient Data Produces Results

    /// 14 days of complete data should produce results for all 4 factor pairs.
    func testSufficientDataProducesAllFourPairs() {
        let history = makeHistory(
            days: 14,
            steps: 8000,
            rhr: 62,
            walkMinutes: 30,
            hrv: 55,
            workoutMinutes: 45,
            recoveryHR1m: 30,
            sleepHours: 7.5
        )

        let results = engine.analyze(history: history)
        XCTAssertEqual(results.count, 5, "14 days of complete data should yield 5 correlation pairs (ZE-003 added Sleep↔RHR)")

        let factorNames = Set(results.map(\.factorName))
        XCTAssertTrue(factorNames.contains("Daily Steps"))
        XCTAssertTrue(factorNames.contains("Walk Minutes"))
        XCTAssertTrue(factorNames.contains("Activity Minutes"))
        XCTAssertTrue(factorNames.contains("Sleep Hours"))
        XCTAssertTrue(factorNames.contains("Sleep Hours vs RHR"))
    }

    // MARK: - Test: Correlation Coefficient Range

    /// All returned correlation strengths must be in [-1.0, 1.0].
    func testCorrelationCoefficientBounds() {
        let history = makeHistory(
            days: 21,
            steps: 8000,
            rhr: 62,
            walkMinutes: 30,
            hrv: 55,
            workoutMinutes: 45,
            recoveryHR1m: 30,
            sleepHours: 7.5
        )

        let results = engine.analyze(history: history)
        for result in results {
            XCTAssertGreaterThanOrEqual(
                result.correlationStrength,
                -1.0,
                "\(result.factorName) correlation should be >= -1.0"
            )
            XCTAssertLessThanOrEqual(
                result.correlationStrength,
                1.0,
                "\(result.factorName) correlation should be <= 1.0"
            )
        }
    }

    // MARK: - Test: Perfect Positive Correlation

    /// Linearly increasing steps with linearly decreasing RHR should yield
    /// a strong negative correlation (beneficial direction for steps vs RHR).
    func testPerfectNegativeCorrelation() throws {
        let calendar = Calendar.current
        let baseDate = Date()

        var history: [HeartSnapshot] = []
        for i in 0..<14 {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: -(14 - i), to: baseDate))
            history.append(HeartSnapshot(
                date: date,
                restingHeartRate: 70.0 - Double(i) * 0.5,  // Decreasing RHR
                steps: 5000.0 + Double(i) * 500            // Increasing steps
            ))
        }

        let results = engine.analyze(history: history)
        let stepsResult = results.first(where: { $0.factorName == "Daily Steps" })

        XCTAssertNotNil(stepsResult, "Steps vs RHR correlation should exist")
        if let r = stepsResult {
            // Steps up, RHR down = negative correlation = beneficial
            XCTAssertLessThan(
                r.correlationStrength,
                -0.8,
                "Perfectly inverse linear relationship should yield strong negative r"
            )
        }
    }

    // MARK: - Test: No Correlation With Constant Values

    /// Constant steps with varying RHR should yield near-zero correlation.
    func testConstantFactorYieldsZeroCorrelation() throws {
        let calendar = Calendar.current
        let baseDate = Date()

        var history: [HeartSnapshot] = []
        for i in 0..<14 {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: -(14 - i), to: baseDate))
            let variation = sin(Double(i) * 0.7) * 3.0
            history.append(HeartSnapshot(
                date: date,
                restingHeartRate: 62.0 + variation,  // Varying RHR
                steps: 8000.0                         // Constant steps
            ))
        }

        let results = engine.analyze(history: history)
        let stepsResult = results.first(where: { $0.factorName == "Daily Steps" })

        XCTAssertNotNil(stepsResult, "Steps vs RHR correlation should exist")
        if let r = stepsResult {
            XCTAssertEqual(
                r.correlationStrength,
                0.0,
                accuracy: 0.01,
                "Constant steps should yield zero correlation with varying RHR"
            )
        }
    }

    // MARK: - Test: Nil Values Excluded From Pairing

    /// Days with nil steps should be excluded; only paired days count.
    func testNilValuesExcludedFromPairing() throws {
        let calendar = Calendar.current
        let baseDate = Date()

        var history: [HeartSnapshot] = []
        for i in 0..<14 {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: -(14 - i), to: baseDate))
            // Only give steps to even days (7 out of 14)
            let steps: Double? = i.isMultiple(of: 2) ? 8000.0 + Double(i) * 100 : nil
            history.append(HeartSnapshot(
                date: date,
                restingHeartRate: 62.0 + sin(Double(i)) * 2.0,
                steps: steps
            ))
        }

        let results = engine.analyze(history: history)
        let stepsResult = results.first(where: { $0.factorName == "Daily Steps" })

        // 7 paired points = exactly at threshold
        XCTAssertNotNil(stepsResult, "7 paired data points should meet the minimum threshold")
    }

    // MARK: - Test: Interpretation Contains Factor Name

    /// Each interpretation string should reference the factor name.
    func testInterpretationContainsFactorName() {
        let history = makeHistory(
            days: 14,
            steps: 8000,
            rhr: 62,
            walkMinutes: 30,
            hrv: 55,
            workoutMinutes: 45,
            recoveryHR1m: 30,
            sleepHours: 7.5
        )

        let results = engine.analyze(history: history)
        for result in results {
            XCTAssertFalse(
                result.interpretation.isEmpty,
                "\(result.factorName) interpretation should not be empty"
            )
        }
    }

    // MARK: - Test: Confidence Levels Valid

    /// All returned confidence levels should be valid ConfidenceLevel cases.
    func testConfidenceLevelsAreValid() {
        let history = makeHistory(
            days: 21,
            steps: 8000,
            rhr: 62,
            walkMinutes: 30,
            hrv: 55,
            workoutMinutes: 45,
            recoveryHR1m: 30,
            sleepHours: 7.5
        )

        let results = engine.analyze(history: history)
        let validLevels: Set<ConfidenceLevel> = [.high, .medium, .low]
        for result in results {
            XCTAssertTrue(
                validLevels.contains(result.confidence),
                "\(result.factorName) should have a valid confidence level"
            )
        }
    }

    // MARK: - Test: Partial Data Only Produces Available Pairs

    /// History with only steps + RHR (no walk, workout, sleep) should
    /// produce exactly 1 correlation result.
    func testPartialDataProducesOnlyAvailablePairs() {
        let history = makeHistory(
            days: 14,
            steps: 8000,
            rhr: 62,
            walkMinutes: nil,
            hrv: nil,
            workoutMinutes: nil,
            recoveryHR1m: nil,
            sleepHours: nil
        )

        let results = engine.analyze(history: history)
        XCTAssertEqual(results.count, 1, "Only steps+RHR data should yield 1 pair")
        XCTAssertEqual(results.first?.factorName, "Daily Steps")
    }
}

// MARK: - Test Helpers

extension CorrelationEngineTests {

    /// Creates an array of HeartSnapshots with deterministic pseudo-variation.
    private func makeHistory(
        days: Int,
        steps: Double?,
        rhr: Double?,
        walkMinutes: Double?,
        hrv: Double?,
        workoutMinutes: Double?,
        recoveryHR1m: Double?,
        sleepHours: Double?
    ) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<days).compactMap { i in
            guard let date = calendar.date(byAdding: .day, value: -(days - i), to: today) else {
                return nil
            }
            let variation = sin(Double(i) * 0.5) * 2.0
            return HeartSnapshot(
                date: date,
                restingHeartRate: rhr.map { $0 + variation },
                hrvSDNN: hrv.map { $0 - variation },
                recoveryHR1m: recoveryHR1m.map { $0 + variation },
                steps: steps.map { $0 + variation * 500 },
                walkMinutes: walkMinutes.map { $0 + variation * 5 },
                workoutMinutes: workoutMinutes.map { $0 + variation * 3 },
                sleepHours: sleepHours.map { $0 + variation * 0.3 }
            )
        }
    }
}

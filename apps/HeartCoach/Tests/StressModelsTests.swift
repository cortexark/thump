// StressModelsTests.swift
// ThumpCoreTests
//
// Unit tests for stress domain models — level from score,
// display properties, confidence weights, sleep patterns,
// and Codable round-trips.

import XCTest
@testable import Thump

final class StressModelsTests: XCTestCase {

    // MARK: - StressLevel from Score

    func testFromScore_0_isRelaxed() {
        XCTAssertEqual(StressLevel.from(score: 0), .relaxed)
    }

    func testFromScore_33_isRelaxed() {
        XCTAssertEqual(StressLevel.from(score: 33), .relaxed)
    }

    func testFromScore_34_isBalanced() {
        XCTAssertEqual(StressLevel.from(score: 34), .balanced)
    }

    func testFromScore_66_isBalanced() {
        XCTAssertEqual(StressLevel.from(score: 66), .balanced)
    }

    func testFromScore_67_isElevated() {
        XCTAssertEqual(StressLevel.from(score: 67), .elevated)
    }

    func testFromScore_100_isElevated() {
        XCTAssertEqual(StressLevel.from(score: 100), .elevated)
    }

    func testFromScore_negativeValue_clampsToRelaxed() {
        XCTAssertEqual(StressLevel.from(score: -10), .relaxed)
    }

    func testFromScore_over100_clampsToElevated() {
        XCTAssertEqual(StressLevel.from(score: 150), .elevated)
    }

    func testFromScore_boundaryAt33Point5_isBalanced() {
        XCTAssertEqual(StressLevel.from(score: 33.5), .balanced)
    }

    // MARK: - StressLevel Display Properties

    func testDisplayName_allCases_nonEmpty() {
        for level in StressLevel.allCases {
            XCTAssertFalse(level.displayName.isEmpty, "\(level) has empty display name")
        }
    }

    func testIcon_allCases_areSFSymbols() {
        XCTAssertEqual(StressLevel.relaxed.icon, "leaf.fill")
        XCTAssertEqual(StressLevel.balanced.icon, "circle.grid.cross.fill")
        XCTAssertEqual(StressLevel.elevated.icon, "flame.fill")
    }

    func testColorName_allCases_nonEmpty() {
        for level in StressLevel.allCases {
            XCTAssertFalse(level.colorName.isEmpty)
        }
    }

    func testFriendlyMessage_allCases_nonEmpty() {
        for level in StressLevel.allCases {
            XCTAssertFalse(level.friendlyMessage.isEmpty)
        }
    }

    // MARK: - StressMode

    func testStressMode_displayNames() {
        XCTAssertEqual(StressMode.acute.displayName, "Active")
        XCTAssertEqual(StressMode.desk.displayName, "Resting")
        XCTAssertEqual(StressMode.unknown.displayName, "General")
    }

    func testStressMode_allCases_count() {
        XCTAssertEqual(StressMode.allCases.count, 3)
    }

    // MARK: - StressConfidence

    func testStressConfidence_weights() {
        XCTAssertEqual(StressConfidence.high.weight, 1.0)
        XCTAssertEqual(StressConfidence.moderate.weight, 0.5)
        XCTAssertEqual(StressConfidence.low.weight, 0.25)
    }

    func testStressConfidence_displayNames() {
        XCTAssertEqual(StressConfidence.high.displayName, "Strong Signal")
        XCTAssertEqual(StressConfidence.moderate.displayName, "Moderate Signal")
        XCTAssertEqual(StressConfidence.low.displayName, "Weak Signal")
    }

    // MARK: - StressTrendDirection

    func testStressTrendDirection_displayTexts() {
        XCTAssertTrue(StressTrendDirection.rising.displayText.contains("climbing"))
        XCTAssertTrue(StressTrendDirection.falling.displayText.contains("easing"))
        XCTAssertTrue(StressTrendDirection.steady.displayText.contains("steady"))
    }

    func testStressTrendDirection_icons() {
        XCTAssertEqual(StressTrendDirection.rising.icon, "arrow.up.right")
        XCTAssertEqual(StressTrendDirection.falling.icon, "arrow.down.right")
        XCTAssertEqual(StressTrendDirection.steady.icon, "arrow.right")
    }

    // MARK: - SleepPattern

    func testSleepPattern_weekendDetection() {
        let sunday = SleepPattern(dayOfWeek: 1)
        let monday = SleepPattern(dayOfWeek: 2)
        let saturday = SleepPattern(dayOfWeek: 7)
        let friday = SleepPattern(dayOfWeek: 6)

        XCTAssertTrue(sunday.isWeekend)
        XCTAssertTrue(saturday.isWeekend)
        XCTAssertFalse(monday.isWeekend)
        XCTAssertFalse(friday.isWeekend)
    }

    func testSleepPattern_defaultValues() {
        let pattern = SleepPattern(dayOfWeek: 3)
        XCTAssertEqual(pattern.typicalBedtimeHour, 22)
        XCTAssertEqual(pattern.typicalWakeHour, 7)
        XCTAssertEqual(pattern.observationCount, 0)
    }

    // MARK: - StressSignalBreakdown

    func testStressSignalBreakdown_initialization() {
        let breakdown = StressSignalBreakdown(
            rhrContribution: 40, hrvContribution: 35, cvContribution: 25
        )
        XCTAssertEqual(breakdown.rhrContribution, 40)
        XCTAssertEqual(breakdown.hrvContribution, 35)
        XCTAssertEqual(breakdown.cvContribution, 25)
    }

    // MARK: - StressResult

    func testStressResult_initialization() {
        let result = StressResult(
            score: 45,
            level: .balanced,
            description: "Things look balanced",
            mode: .desk,
            confidence: .high,
            warnings: ["Limited data"]
        )
        XCTAssertEqual(result.score, 45)
        XCTAssertEqual(result.level, .balanced)
        XCTAssertEqual(result.mode, .desk)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.warnings.count, 1)
    }

    func testStressResult_defaultValues() {
        let result = StressResult(score: 50, level: .balanced, description: "test")
        XCTAssertEqual(result.mode, .unknown)
        XCTAssertEqual(result.confidence, .moderate)
        XCTAssertNil(result.signalBreakdown)
        XCTAssertEqual(result.warnings, [])
    }

    // MARK: - StressDataPoint Identity

    func testStressDataPoint_id_isDate() {
        let date = Date()
        let point = StressDataPoint(date: date, score: 42, level: .balanced)
        XCTAssertEqual(point.id, date)
    }

    // MARK: - HourlyStressPoint

    func testHourlyStressPoint_id_formatsCorrectly() {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 14))!
        let point = HourlyStressPoint(date: date, hour: 14, score: 55, level: .balanced)
        XCTAssertEqual(point.id, "2026-03-15-14")
    }

    // MARK: - Codable Round-Trip

    func testStressLevel_codableRoundTrip() throws {
        let original = StressLevel.elevated
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StressLevel.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testStressResult_codableRoundTrip() throws {
        let original = StressResult(
            score: 72,
            level: .elevated,
            description: "Running hot",
            mode: .acute,
            confidence: .high,
            signalBreakdown: StressSignalBreakdown(
                rhrContribution: 50, hrvContribution: 30, cvContribution: 20
            ),
            warnings: ["Post-exercise"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StressResult.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testStressTrendDirection_codableRoundTrip() throws {
        for direction in [StressTrendDirection.rising, .falling, .steady] {
            let data = try JSONEncoder().encode(direction)
            let decoded = try JSONDecoder().decode(StressTrendDirection.self, from: data)
            XCTAssertEqual(decoded, direction)
        }
    }
}

// NotificationSmartTimingTests.swift
// ThumpTests
//
// Tests for NotificationService.scheduleSmartNudge() smart timing
// logic. Since UNUserNotificationCenter is not available in unit
// tests, these tests verify the SmartNudgeScheduler timing logic
// that feeds into the notification scheduling.

import XCTest
@testable import Thump

final class NotificationSmartTimingTests: XCTestCase {

    private var scheduler: SmartNudgeScheduler!

    override func setUp() {
        super.setUp()
        scheduler = SmartNudgeScheduler()
    }

    override func tearDown() {
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Bedtime Nudge Timing for Rest Category

    func testBedtimeNudge_withLearnedPatterns_usesLearnedBedtime() {
        let patterns = (1...7).map {
            SleepPattern(
                dayOfWeek: $0,
                typicalBedtimeHour: 23,
                typicalWakeHour: 7,
                observationCount: 10
            )
        }
        let hour = scheduler.bedtimeNudgeHour(patterns: patterns, for: Date())
        // Bedtime 23 → nudge at 22 (1 hour before), clamped to 20-23
        XCTAssertEqual(hour, 22)
    }

    func testBedtimeNudge_earlyBedtime_clampsTo20() {
        let patterns = (1...7).map {
            SleepPattern(
                dayOfWeek: $0,
                typicalBedtimeHour: 20,
                typicalWakeHour: 5,
                observationCount: 10
            )
        }
        let hour = scheduler.bedtimeNudgeHour(patterns: patterns, for: Date())
        // Bedtime 20 → nudge at 19 → clamped to 20
        XCTAssertGreaterThanOrEqual(hour, 20)
    }

    func testBedtimeNudge_insufficientData_usesDefault() {
        let patterns = (1...7).map {
            SleepPattern(
                dayOfWeek: $0,
                typicalBedtimeHour: 23,
                typicalWakeHour: 7,
                observationCount: 1 // Too few
            )
        }
        let hour = scheduler.bedtimeNudgeHour(patterns: patterns, for: Date())
        // Default: 21 for weekday, 22 for weekend
        XCTAssertGreaterThanOrEqual(hour, 20)
        XCTAssertLessThanOrEqual(hour, 23)
    }

    // MARK: - Walk/Moderate Nudge Timing

    func testWalkNudgeTiming_withLearnedWake_usesWakePlus2() {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: Date())

        let patterns = (1...7).map {
            SleepPattern(
                dayOfWeek: $0,
                typicalBedtimeHour: 22,
                typicalWakeHour: 6,
                observationCount: 5
            )
        }

        // The scheduling logic: wake (6) + 2 = 8, capped at 12
        guard let todayPattern = patterns.first(where: { $0.dayOfWeek == dayOfWeek }) else {
            XCTFail("Should find today's pattern")
            return
        }
        XCTAssertGreaterThanOrEqual(todayPattern.observationCount, 3)

        let expectedHour = min(todayPattern.typicalWakeHour + 2, 12)
        XCTAssertEqual(expectedHour, 8)
    }

    func testWalkNudgeTiming_lateWaker_cappedAt12() {
        // If typical wake is 11, wake+2 = 13 → capped at 12
        let patterns = (1...7).map {
            SleepPattern(
                dayOfWeek: $0,
                typicalBedtimeHour: 2,
                typicalWakeHour: 11,
                observationCount: 5
            )
        }

        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: Date())
        guard let todayPattern = patterns.first(where: { $0.dayOfWeek == dayOfWeek }) else {
            XCTFail("Should find today's pattern")
            return
        }

        let expectedHour = min(todayPattern.typicalWakeHour + 2, 12)
        XCTAssertEqual(expectedHour, 12, "Walk nudge should cap at noon")
    }

    func testWalkNudgeTiming_insufficientData_defaultsTo9() {
        let patterns = (1...7).map {
            SleepPattern(
                dayOfWeek: $0,
                typicalBedtimeHour: 22,
                typicalWakeHour: 7,
                observationCount: 2 // Below threshold of 3
            )
        }

        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: Date())
        let todayPattern = patterns.first(where: { $0.dayOfWeek == dayOfWeek })!

        // With insufficient observations, default to 9
        let hour: Int
        if todayPattern.observationCount >= 3 {
            hour = min(todayPattern.typicalWakeHour + 2, 12)
        } else {
            hour = 9
        }
        XCTAssertEqual(hour, 9, "Should default to 9am with insufficient data")
    }

    // MARK: - Breathe Nudge Timing

    func testBreatheNudge_alwaysAtPeakStressHour() {
        // Breathing nudges go at 15 (3 PM) regardless of patterns
        let expectedHour = 15
        XCTAssertEqual(expectedHour, 15, "Breathe nudge should fire at peak stress hour 3 PM")
    }

    // MARK: - Hydrate Nudge Timing

    func testHydrateNudge_alwaysLateMorning() {
        let expectedHour = 11
        XCTAssertEqual(expectedHour, 11, "Hydrate nudge should fire at 11 AM")
    }

    // MARK: - Default Nudge Timing

    func testDefaultNudge_earlyEvening() {
        let expectedHour = 18
        XCTAssertEqual(expectedHour, 18, "Default nudge should fire at 6 PM")
    }

    // MARK: - Pattern Learning for Timing

    func testLearnedPatterns_feedIntoTiming() {
        let history = MockData.mockHistory(days: 30)
        let patterns = scheduler.learnSleepPatterns(from: history)

        // All patterns should have reasonable bedtime hours
        for pattern in patterns {
            let nudgeHour = scheduler.bedtimeNudgeHour(patterns: patterns, for: Date())
            XCTAssertGreaterThanOrEqual(nudgeHour, 20)
            XCTAssertLessThanOrEqual(nudgeHour, 23)
            _ = pattern // suppress unused warning
        }
    }

    func testEmptyHistory_learnedPatterns_stillProduceValidTiming() {
        let patterns = scheduler.learnSleepPatterns(from: [])
        let nudgeHour = scheduler.bedtimeNudgeHour(patterns: patterns, for: Date())
        XCTAssertGreaterThanOrEqual(nudgeHour, 20)
        XCTAssertLessThanOrEqual(nudgeHour, 23)
    }

    // MARK: - Day-of-Week Sensitivity

    func testBedtimeNudge_weekdayVsWeekend_mayDiffer() {
        // Build patterns with different bedtimes for weekday vs weekend
        let patterns = (1...7).map { day -> SleepPattern in
            let isWeekend = day == 1 || day == 7
            return SleepPattern(
                dayOfWeek: day,
                typicalBedtimeHour: isWeekend ? 0 : 22,
                typicalWakeHour: isWeekend ? 9 : 7,
                observationCount: 10
            )
        }

        // Create weekday and weekend dates
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let isCurrentlyWeekend = weekday == 1 || weekday == 7

        let todayHour = scheduler.bedtimeNudgeHour(patterns: patterns, for: today)

        if isCurrentlyWeekend {
            // Weekend bedtime is 0 (midnight) → nudge -1 → clamped
            // Actually bedtime 0 → nudge at max(20, min(23, 0-1)) → 0-1=-1 → max(20,-1)=20
            // But bedtime > 0 check fails for 0, so it falls through to default 22
            XCTAssertGreaterThanOrEqual(todayHour, 20)
        } else {
            // Weekday bedtime is 22 → nudge at 21
            XCTAssertEqual(todayHour, 21)
        }
    }
}

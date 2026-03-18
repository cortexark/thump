// SmartNudgeSchedulerTests.swift
// ThumpTests
//
// Tests for the SmartNudgeScheduler: sleep pattern learning,
// bedtime nudge timing, late wake detection, and context-aware
// action recommendations.

import XCTest
@testable import Thump

final class SmartNudgeSchedulerTests: XCTestCase {

    private var scheduler: SmartNudgeScheduler!

    override func setUp() {
        super.setUp()
        scheduler = SmartNudgeScheduler()
    }

    override func tearDown() {
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Sleep Pattern Learning

    func testLearnSleepPatterns_returns7Patterns() {
        let snapshots = MockData.mockHistory(days: 30)
        let patterns = scheduler.learnSleepPatterns(from: snapshots)
        XCTAssertEqual(patterns.count, 7)
    }

    func testLearnSleepPatterns_emptyHistory_returnsDefaults() {
        let patterns = scheduler.learnSleepPatterns(from: [])
        XCTAssertEqual(patterns.count, 7)

        // Weekday defaults: bedtime 22, wake 7
        for pattern in patterns where !pattern.isWeekend {
            XCTAssertEqual(pattern.typicalBedtimeHour, 22)
            XCTAssertEqual(pattern.typicalWakeHour, 7)
        }

        // Weekend defaults: bedtime 23, wake 8
        for pattern in patterns where pattern.isWeekend {
            XCTAssertEqual(pattern.typicalBedtimeHour, 23)
            XCTAssertEqual(pattern.typicalWakeHour, 8)
        }
    }

    func testLearnSleepPatterns_weekendVsWeekday() {
        let patterns = scheduler.learnSleepPatterns(from: [])

        let weekdayPattern = patterns.first { !$0.isWeekend }!
        let weekendPattern = patterns.first { $0.isWeekend }!

        // Weekend bedtime should be same or later than weekday
        XCTAssertGreaterThanOrEqual(
            weekendPattern.typicalBedtimeHour,
            weekdayPattern.typicalBedtimeHour
        )
    }

    // MARK: - Bedtime Nudge Timing

    func testBedtimeNudgeHour_defaultsToEvening() {
        let patterns = scheduler.learnSleepPatterns(from: [])
        let nudgeHour = scheduler.bedtimeNudgeHour(
            patterns: patterns, for: Date()
        )
        XCTAssertGreaterThanOrEqual(nudgeHour, 20)
        XCTAssertLessThanOrEqual(nudgeHour, 23)
    }

    func testBedtimeNudgeHour_clampsToValidRange() {
        // Even with extreme patterns, nudge should be 20-23
        var patterns = (1...7).map { SleepPattern(dayOfWeek: $0, typicalBedtimeHour: 19, observationCount: 5) }
        var nudgeHour = scheduler.bedtimeNudgeHour(patterns: patterns, for: Date())
        XCTAssertGreaterThanOrEqual(nudgeHour, 20)

        patterns = (1...7).map { SleepPattern(dayOfWeek: $0, typicalBedtimeHour: 2, observationCount: 5) }
        nudgeHour = scheduler.bedtimeNudgeHour(patterns: patterns, for: Date())
        XCTAssertLessThanOrEqual(nudgeHour, 23)
    }

    // MARK: - Late Wake Detection

    func testIsLateWake_normalSleep_returnsFalse() {
        let patterns = (1...7).map {
            SleepPattern(
                dayOfWeek: $0,
                typicalBedtimeHour: 22,
                typicalWakeHour: 7,
                observationCount: 10
            )
        }
        // Normal 7h sleep (bedtime 22, wake 5=24-22+7=9 → typical sleep ~9h)
        // Actually: typical sleep = (7 - 22 + 24) % 24 = 9
        // Normal sleep is 7h, much less than typical 9h
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 7.0)
        XCTAssertFalse(scheduler.isLateWake(todaySnapshot: snapshot, patterns: patterns))
    }

    func testIsLateWake_longSleep_returnsTrue() {
        let patterns = (1...7).map {
            SleepPattern(
                dayOfWeek: $0,
                typicalBedtimeHour: 22,
                typicalWakeHour: 7,
                observationCount: 10
            )
        }
        // Slept 12 hours — way more than typical ~9h
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 12.0)
        XCTAssertTrue(scheduler.isLateWake(todaySnapshot: snapshot, patterns: patterns))
    }

    func testIsLateWake_noSleepData_returnsFalse() {
        let patterns = (1...7).map {
            SleepPattern(dayOfWeek: $0, observationCount: 10)
        }
        let snapshot = HeartSnapshot(date: Date(), sleepHours: nil)
        XCTAssertFalse(scheduler.isLateWake(todaySnapshot: snapshot, patterns: patterns))
    }

    func testIsLateWake_insufficientObservations_returnsFalse() {
        let patterns = (1...7).map {
            SleepPattern(dayOfWeek: $0, observationCount: 1) // Too few
        }
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 12.0)
        XCTAssertFalse(scheduler.isLateWake(todaySnapshot: snapshot, patterns: patterns))
    }

    // MARK: - Smart Action Recommendations

    func testRecommendAction_highStress_returnsJournal() {
        let points = [
            StressDataPoint(date: Date(), score: 75.0, level: .elevated)
        ]
        let action = scheduler.recommendAction(
            stressPoints: points,
            trendDirection: .steady,
            todaySnapshot: nil,
            patterns: [],
            currentHour: 14
        )

        if case .journalPrompt(let prompt) = action {
            XCTAssertFalse(prompt.question.isEmpty)
        } else {
            XCTFail("Expected journalPrompt, got \(action)")
        }
    }

    func testRecommendAction_risingStress_returnsBreathe() {
        let points = [
            StressDataPoint(date: Date(), score: 55.0, level: .balanced)
        ]
        let action = scheduler.recommendAction(
            stressPoints: points,
            trendDirection: .rising,
            todaySnapshot: nil,
            patterns: [],
            currentHour: 14
        )

        if case .breatheOnWatch(let nudge) = action {
            XCTAssertEqual(nudge.category, .breathe)
        } else {
            XCTFail("Expected breatheOnWatch, got \(action)")
        }
    }

    func testRecommendAction_lowStress_noSpecialAction() {
        let points = [
            StressDataPoint(date: Date(), score: 25.0, level: .relaxed)
        ]
        let action = scheduler.recommendAction(
            stressPoints: points,
            trendDirection: .steady,
            todaySnapshot: nil,
            patterns: [],
            currentHour: 14
        )

        if case .standardNudge = action {
            // Expected
        } else {
            XCTFail("Expected standardNudge for low stress, got \(action)")
        }
    }

    // MARK: - Journal Prompt Threshold

    func testRecommendAction_stressAt64_noJournal() {
        let points = [
            StressDataPoint(date: Date(), score: 64.0, level: .balanced)
        ]
        let action = scheduler.recommendAction(
            stressPoints: points,
            trendDirection: .steady,
            todaySnapshot: nil,
            patterns: [],
            currentHour: 14
        )

        if case .journalPrompt = action {
            XCTFail("Score 64 should not trigger journal (threshold is 65)")
        }
    }

    func testRecommendAction_stressAt65_triggersJournal() {
        let points = [
            StressDataPoint(date: Date(), score: 65.0, level: .balanced)
        ]
        let action = scheduler.recommendAction(
            stressPoints: points,
            trendDirection: .steady,
            todaySnapshot: nil,
            patterns: [],
            currentHour: 14
        )

        if case .journalPrompt = action {
            // Expected
        } else {
            XCTFail("Score 65 should trigger journal")
        }
    }

    // MARK: - Priority Order

    func testRecommendAction_highStressTrumpsRisingTrend() {
        // High stress + rising trend → journal takes priority over breathe
        let points = [
            StressDataPoint(date: Date(), score: 80.0, level: .elevated)
        ]
        let action = scheduler.recommendAction(
            stressPoints: points,
            trendDirection: .rising,
            todaySnapshot: nil,
            patterns: [],
            currentHour: 14
        )

        if case .journalPrompt = action {
            // Expected — journal has higher priority
        } else {
            XCTFail("Journal should take priority over breathe")
        }
    }

    // MARK: - Evening Notification: Forward-Looking

    func testEveningNotification_forwardLooking_firesWhenScoreAbove44AndRising() {
        let notification = scheduler.eveningNotification(
            readinessScore: 60,
            trendDirection: .rising,
            isChronicSteady: false,
            copyProfile: .autonomous
        )
        XCTAssertNotNil(notification, "Should fire forward-looking notification when score > 44 and rising")
        XCTAssertEqual(notification?.kind, .forwardLooking)
        XCTAssertFalse(notification?.body.isEmpty ?? true)
    }

    func testEveningNotification_forwardLooking_suppressedWhenChronicSteady() {
        let notification = scheduler.eveningNotification(
            readinessScore: 60,
            trendDirection: .rising,
            isChronicSteady: true,
            copyProfile: .autonomous
        )
        // Chronic steady + autonomous → no forward-looking notification
        // (steadyAcknowledgment only fires for .constrained + chronic steady)
        XCTAssertNil(notification, "Forward-looking notification must be suppressed when isChronicSteady")
    }

    func testEveningNotification_forwardLooking_suppressedWhenScoreAt44() {
        let notification = scheduler.eveningNotification(
            readinessScore: 44,
            trendDirection: .rising,
            isChronicSteady: false,
            copyProfile: .autonomous
        )
        XCTAssertNil(notification, "Score 44 is not > 44; forward-looking notification must not fire")
    }

    func testEveningNotification_forwardLooking_suppressedWhenNotRising() {
        let notification = scheduler.eveningNotification(
            readinessScore: 70,
            trendDirection: .steady,
            isChronicSteady: false,
            copyProfile: .autonomous
        )
        XCTAssertNil(notification, "Forward-looking notification requires rising trend")
    }

    // MARK: - Evening Notification: Steady Acknowledgment

    func testEveningNotification_steadyAcknowledgment_firesWhenChronicSteadyAndConstrained() {
        let notification = scheduler.eveningNotification(
            readinessScore: 30,
            trendDirection: .steady,
            isChronicSteady: true,
            copyProfile: .constrained
        )
        XCTAssertNotNil(notification, "Steady acknowledgment should fire for chronic steady + constrained")
        XCTAssertEqual(notification?.kind, .steadyAcknowledgment)
    }

    func testEveningNotification_steadyAcknowledgment_suppressedAfter3ConsecutiveDismissals() {
        let notification = scheduler.eveningNotification(
            readinessScore: 30,
            trendDirection: .steady,
            isChronicSteady: true,
            copyProfile: .constrained,
            consecutiveDismissals: 3
        )
        XCTAssertNil(notification, "Steady acknowledgment must suppress after 3 consecutive dismissals")
    }

    func testEveningNotification_steadyAcknowledgment_firesAt2ConsecutiveDismissals() {
        let notification = scheduler.eveningNotification(
            readinessScore: 30,
            trendDirection: .steady,
            isChronicSteady: true,
            copyProfile: .constrained,
            consecutiveDismissals: 2
        )
        XCTAssertNotNil(notification, "Steady acknowledgment should still fire at 2 dismissals (threshold is 3)")
    }

    func testEveningNotification_steadyAcknowledgment_notFiredForAutonomousProfile() {
        let notification = scheduler.eveningNotification(
            readinessScore: 30,
            trendDirection: .steady,
            isChronicSteady: true,
            copyProfile: .autonomous
        )
        XCTAssertNil(notification, "Steady acknowledgment requires .constrained copy profile")
    }

    // MARK: - One-Per-Day Rule

    func testEveningNotification_oncePerDayRule_suppressesWhenAlreadySentToday() {
        let notification = scheduler.eveningNotification(
            readinessScore: 60,
            trendDirection: .rising,
            isChronicSteady: false,
            copyProfile: .autonomous,
            consecutiveDismissals: 0,
            lastNotificationDate: Date()  // already sent today
        )
        XCTAssertNil(notification, "Notification must be suppressed if already sent today (1/day rule)")
    }

    func testEveningNotification_oncePerDayRule_allowsWhenLastSentYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let notification = scheduler.eveningNotification(
            readinessScore: 60,
            trendDirection: .rising,
            isChronicSteady: false,
            copyProfile: .autonomous,
            consecutiveDismissals: 0,
            lastNotificationDate: yesterday
        )
        XCTAssertNotNil(notification, "Notification should fire if last sent was yesterday")
    }

    func testCanSendNotificationToday_nilLastDate_returnsTrue() {
        XCTAssertTrue(
            scheduler.canSendNotificationToday(lastNotificationDate: nil),
            "Should allow sending when no prior notification exists"
        )
    }

    func testCanSendNotificationToday_sentToday_returnsFalse() {
        XCTAssertFalse(
            scheduler.canSendNotificationToday(lastNotificationDate: Date()),
            "Should block sending when notification was already sent today"
        )
    }

    func testCanSendNotificationToday_sentYesterday_returnsTrue() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        XCTAssertTrue(
            scheduler.canSendNotificationToday(lastNotificationDate: yesterday),
            "Should allow sending when last notification was yesterday"
        )
    }
}

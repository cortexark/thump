// SmartNudgeMultiActionTests.swift
// ThumpTests
//
// Tests for SmartNudgeScheduler.recommendActions() multi-action
// generation, activity/rest suggestions, and the new enum cases.

import XCTest
@testable import Thump

final class SmartNudgeMultiActionTests: XCTestCase {

    private var scheduler: SmartNudgeScheduler!

    override func setUp() {
        super.setUp()
        scheduler = SmartNudgeScheduler()
    }

    override func tearDown() {
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Basic Contract

    func testRecommendActions_neverReturnsEmpty() {
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: nil,
            patterns: [],
            currentHour: 14
        )
        XCTAssertFalse(actions.isEmpty, "Should always return at least one action")
    }

    func testRecommendActions_maxThreeActions() {
        // Provide conditions that trigger many actions
        let points = [
            StressDataPoint(date: Date(), score: 80.0, level: .elevated)
        ]
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 0,
            workoutMinutes: 0,
            sleepHours: 5.0
        )
        let actions = scheduler.recommendActions(
            stressPoints: points,
            trendDirection: .rising,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        XCTAssertLessThanOrEqual(actions.count, 3, "Should cap at 3 actions")
    }

    func testRecommendActions_noConditions_returnsStandardNudge() {
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: nil,
            patterns: [],
            currentHour: 14
        )
        XCTAssertEqual(actions.count, 1)
        if case .standardNudge = actions.first! {
            // Expected
        } else {
            XCTFail("Expected standardNudge when no conditions met")
        }
    }

    // MARK: - Activity Suggestion

    func testRecommendActions_lowActivity_includesActivitySuggestion() {
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 3,
            workoutMinutes: 2,
            sleepHours: 8.0
        )
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        let hasActivity = actions.contains { action in
            if case .activitySuggestion = action { return true }
            return false
        }
        XCTAssertTrue(hasActivity, "Should suggest activity when walk+workout < 10 min")
    }

    func testRecommendActions_sufficientActivity_noActivitySuggestion() {
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 20,
            workoutMinutes: 15,
            sleepHours: 8.0
        )
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        let hasActivity = actions.contains { action in
            if case .activitySuggestion = action { return true }
            return false
        }
        XCTAssertFalse(hasActivity, "Should not suggest activity when user is active")
    }

    func testRecommendActions_activitySuggestionNudge_hasCorrectCategory() {
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 0,
            workoutMinutes: 0,
            sleepHours: 8.0
        )
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        for action in actions {
            if case .activitySuggestion(let nudge) = action {
                XCTAssertEqual(nudge.category, .walk)
                XCTAssertEqual(nudge.durationMinutes, 10)
                XCTAssertFalse(nudge.title.isEmpty)
                return
            }
        }
        XCTFail("Expected activitySuggestion in actions")
    }

    // MARK: - Rest Suggestion

    func testRecommendActions_lowSleep_includesRestSuggestion() {
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 30,
            workoutMinutes: 20,
            sleepHours: 5.5
        )
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        let hasRest = actions.contains { action in
            if case .restSuggestion = action { return true }
            return false
        }
        XCTAssertTrue(hasRest, "Should suggest rest when sleep < 6.5 hours")
    }

    func testRecommendActions_adequateSleep_noRestSuggestion() {
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 30,
            workoutMinutes: 20,
            sleepHours: 7.5
        )
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        let hasRest = actions.contains { action in
            if case .restSuggestion = action { return true }
            return false
        }
        XCTAssertFalse(hasRest, "Should not suggest rest when sleep is adequate")
    }

    func testRecommendActions_restSuggestionNudge_hasCorrectCategory() {
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 30,
            workoutMinutes: 20,
            sleepHours: 5.0
        )
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        for action in actions {
            if case .restSuggestion(let nudge) = action {
                XCTAssertEqual(nudge.category, .rest)
                XCTAssertFalse(nudge.title.isEmpty)
                XCTAssertTrue(nudge.description.contains("5.0"))
                return
            }
        }
        XCTFail("Expected restSuggestion in actions")
    }

    // MARK: - Sleep Threshold Boundary

    func testRecommendActions_sleepAt6Point5_noRestSuggestion() {
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 30,
            workoutMinutes: 20,
            sleepHours: 6.5
        )
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        let hasRest = actions.contains { action in
            if case .restSuggestion = action { return true }
            return false
        }
        XCTAssertFalse(hasRest, "Sleep at exactly 6.5h should NOT trigger rest suggestion")
    }

    func testRecommendActions_sleepAt6Point4_triggersRestSuggestion() {
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 30,
            workoutMinutes: 20,
            sleepHours: 6.4
        )
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        let hasRest = actions.contains { action in
            if case .restSuggestion = action { return true }
            return false
        }
        XCTAssertTrue(hasRest, "Sleep at 6.4h should trigger rest suggestion")
    }

    // MARK: - Activity Threshold Boundary

    func testRecommendActions_activityAt10Min_noActivitySuggestion() {
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 5,
            workoutMinutes: 5,
            sleepHours: 8.0
        )
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        let hasActivity = actions.contains { action in
            if case .activitySuggestion = action { return true }
            return false
        }
        XCTAssertFalse(hasActivity, "Walk+workout = 10 should NOT trigger activity suggestion")
    }

    func testRecommendActions_activityAt9Min_triggersActivitySuggestion() {
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 5,
            workoutMinutes: 4,
            sleepHours: 8.0
        )
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        let hasActivity = actions.contains { action in
            if case .activitySuggestion = action { return true }
            return false
        }
        XCTAssertTrue(hasActivity, "Walk+workout = 9 should trigger activity suggestion")
    }

    // MARK: - Combined Actions Priority

    func testRecommendActions_highStressAndLowActivity_journalFirst() {
        let points = [
            StressDataPoint(date: Date(), score: 80.0, level: .elevated)
        ]
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 2,
            workoutMinutes: 0,
            sleepHours: 5.0
        )
        let actions = scheduler.recommendActions(
            stressPoints: points,
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        XCTAssertGreaterThanOrEqual(actions.count, 1)
        if case .journalPrompt = actions.first! {
            // Expected: journal is highest priority
        } else {
            XCTFail("Journal prompt should be first action for high stress")
        }
    }

    func testRecommendActions_risingStressAndLowSleep_breatheAndRest() {
        let points = [
            StressDataPoint(date: Date(), score: 50.0, level: .balanced)
        ]
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 30,
            workoutMinutes: 20,
            sleepHours: 5.0
        )
        let actions = scheduler.recommendActions(
            stressPoints: points,
            trendDirection: .rising,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        let hasBreathe = actions.contains { if case .breatheOnWatch = $0 { return true }; return false }
        let hasRest = actions.contains { if case .restSuggestion = $0 { return true }; return false }
        XCTAssertTrue(hasBreathe, "Rising stress should include breathe")
        XCTAssertTrue(hasRest, "Low sleep should include rest suggestion")
    }

    func testRecommendActions_allConditionsMet_cappedAtThree() {
        // High stress + rising + low activity + low sleep = many triggers
        let points = [
            StressDataPoint(date: Date(), score: 80.0, level: .elevated)
        ]
        let snapshot = HeartSnapshot(
            date: Date(),
            walkMinutes: 0,
            workoutMinutes: 0,
            sleepHours: 4.0
        )
        let actions = scheduler.recommendActions(
            stressPoints: points,
            trendDirection: .rising,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14
        )
        XCTAssertEqual(actions.count, 3, "Should cap at exactly 3 actions")
        // First should be journal (highest priority)
        if case .journalPrompt = actions[0] { } else {
            XCTFail("First action should be journal prompt")
        }
        // Second should be breathe (rising stress)
        if case .breatheOnWatch = actions[1] { } else {
            XCTFail("Second action should be breathe on watch")
        }
    }

    // MARK: - No Snapshot

    func testRecommendActions_noSnapshot_skipsActivityAndRest() {
        let actions = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: nil,
            patterns: [],
            currentHour: 14
        )
        for action in actions {
            if case .activitySuggestion = action {
                XCTFail("Should not suggest activity without snapshot")
            }
            if case .restSuggestion = action {
                XCTFail("Should not suggest rest without snapshot")
            }
        }
    }
}

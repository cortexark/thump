// StressAndHeartModelPropertyTests.swift
// ThumpCoreTests
//
// Tests for model-level properties and edge cases: StressLevel from(score:),
// NudgeCategory properties, ConfidenceLevel properties, TrendStatus,
// HeartSnapshot empty initialization, and StressDataPoint/HourlyStressPoint.

import XCTest
@testable import Thump

final class StressAndHeartModelPropertyTests: XCTestCase {

    // MARK: - StressLevel from(score:)

    func testStressLevel_relaxed_range() {
        XCTAssertEqual(StressLevel.from(score: 0), .relaxed)
        XCTAssertEqual(StressLevel.from(score: 15), .relaxed)
        XCTAssertEqual(StressLevel.from(score: 33), .relaxed)
    }

    func testStressLevel_balanced_range() {
        XCTAssertEqual(StressLevel.from(score: 34), .balanced)
        XCTAssertEqual(StressLevel.from(score: 50), .balanced)
        XCTAssertEqual(StressLevel.from(score: 66), .balanced)
    }

    func testStressLevel_elevated_range() {
        XCTAssertEqual(StressLevel.from(score: 67), .elevated)
        XCTAssertEqual(StressLevel.from(score: 80), .elevated)
        XCTAssertEqual(StressLevel.from(score: 100), .elevated)
    }

    func testStressLevel_clamped_negative() {
        XCTAssertEqual(StressLevel.from(score: -10), .relaxed)
    }

    func testStressLevel_clamped_over100() {
        XCTAssertEqual(StressLevel.from(score: 150), .elevated)
    }

    // MARK: - StressLevel Display Properties

    func testStressLevel_displayNames() {
        XCTAssertEqual(StressLevel.relaxed.displayName, "Feeling Relaxed")
        XCTAssertEqual(StressLevel.balanced.displayName, "Finding Balance")
        XCTAssertEqual(StressLevel.elevated.displayName, "Running Hot")
    }

    func testStressLevel_icons() {
        XCTAssertEqual(StressLevel.relaxed.icon, "leaf.fill")
        XCTAssertEqual(StressLevel.balanced.icon, "circle.grid.cross.fill")
        XCTAssertEqual(StressLevel.elevated.icon, "flame.fill")
    }

    func testStressLevel_colorNames() {
        XCTAssertEqual(StressLevel.relaxed.colorName, "stressRelaxed")
        XCTAssertEqual(StressLevel.balanced.colorName, "stressBalanced")
        XCTAssertEqual(StressLevel.elevated.colorName, "stressElevated")
    }

    func testStressLevel_friendlyMessages() {
        XCTAssertFalse(StressLevel.relaxed.friendlyMessage.isEmpty)
        XCTAssertFalse(StressLevel.balanced.friendlyMessage.isEmpty)
        XCTAssertFalse(StressLevel.elevated.friendlyMessage.isEmpty)
    }

    // MARK: - NudgeCategory Properties

    func testNudgeCategory_allCases() {
        XCTAssertEqual(NudgeCategory.allCases.count, 9)
    }

    func testNudgeCategory_icons() {
        XCTAssertEqual(NudgeCategory.walk.icon, "figure.walk")
        XCTAssertEqual(NudgeCategory.rest.icon, "bed.double.fill")
        XCTAssertEqual(NudgeCategory.hydrate.icon, "drop.fill")
        XCTAssertEqual(NudgeCategory.breathe.icon, "wind")
        XCTAssertEqual(NudgeCategory.sunlight.icon, "sun.max.fill")
    }

    func testNudgeCategory_tintColorNames() {
        XCTAssertEqual(NudgeCategory.walk.tintColorName, "nudgeWalk")
        XCTAssertEqual(NudgeCategory.rest.tintColorName, "nudgeRest")
        XCTAssertEqual(NudgeCategory.breathe.tintColorName, "nudgeBreathe")
    }

    // MARK: - ConfidenceLevel Properties

    func testConfidenceLevel_displayNames() {
        XCTAssertEqual(ConfidenceLevel.high.displayName, "Strong Pattern")
        XCTAssertEqual(ConfidenceLevel.medium.displayName, "Emerging Pattern")
        XCTAssertEqual(ConfidenceLevel.low.displayName, "Early Signal")
    }

    func testConfidenceLevel_icons() {
        XCTAssertEqual(ConfidenceLevel.high.icon, "checkmark.seal.fill")
        XCTAssertEqual(ConfidenceLevel.medium.icon, "exclamationmark.triangle")
        XCTAssertEqual(ConfidenceLevel.low.icon, "questionmark.circle")
    }

    func testConfidenceLevel_colorNames() {
        XCTAssertEqual(ConfidenceLevel.high.colorName, "confidenceHigh")
        XCTAssertEqual(ConfidenceLevel.medium.colorName, "confidenceMedium")
        XCTAssertEqual(ConfidenceLevel.low.colorName, "confidenceLow")
    }

    // MARK: - TrendStatus

    func testTrendStatus_allCases() {
        let all = TrendStatus.allCases
        XCTAssertEqual(all.count, 3)
        XCTAssertTrue(all.contains(.improving))
        XCTAssertTrue(all.contains(.stable))
        XCTAssertTrue(all.contains(.needsAttention))
    }

    // MARK: - DailyFeedback

    func testDailyFeedback_allCases() {
        let all = DailyFeedback.allCases
        XCTAssertEqual(all.count, 3)
        XCTAssertTrue(all.contains(.positive))
        XCTAssertTrue(all.contains(.negative))
        XCTAssertTrue(all.contains(.skipped))
    }

    // MARK: - HeartSnapshot Empty Initialization

    func testHeartSnapshot_emptyInit_allNil() {
        let snapshot = HeartSnapshot(date: Date())
        XCTAssertNil(snapshot.restingHeartRate)
        XCTAssertNil(snapshot.hrvSDNN)
        XCTAssertNil(snapshot.recoveryHR1m)
        XCTAssertNil(snapshot.recoveryHR2m)
        XCTAssertNil(snapshot.vo2Max)
        XCTAssertNil(snapshot.steps)
        XCTAssertNil(snapshot.walkMinutes)
        XCTAssertNil(snapshot.workoutMinutes)
        XCTAssertNil(snapshot.sleepHours)
        XCTAssertTrue(snapshot.zoneMinutes.isEmpty)
    }

    func testHeartSnapshot_fullInit_allPresent() {
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 65.0,
            hrvSDNN: 50.0,
            recoveryHR1m: 28.0,
            recoveryHR2m: 42.0,
            vo2Max: 40.0,
            zoneMinutes: [100, 30, 15, 8, 2],
            steps: 9500,
            walkMinutes: 35.0,
            workoutMinutes: 25.0,
            sleepHours: 7.8
        )
        XCTAssertEqual(snapshot.restingHeartRate, 65.0)
        XCTAssertEqual(snapshot.hrvSDNN, 50.0)
        XCTAssertEqual(snapshot.recoveryHR1m, 28.0)
        XCTAssertEqual(snapshot.recoveryHR2m, 42.0)
        XCTAssertEqual(snapshot.vo2Max, 40.0)
        XCTAssertEqual(snapshot.zoneMinutes.count, 5)
        XCTAssertEqual(snapshot.steps, 9500)
        XCTAssertEqual(snapshot.walkMinutes, 35.0)
        XCTAssertEqual(snapshot.workoutMinutes, 25.0)
        XCTAssertEqual(snapshot.sleepHours, 7.8)
    }

    // MARK: - StressDataPoint

    func testStressDataPoint_idIsDate() {
        let date = Date()
        let point = StressDataPoint(date: date, score: 45, level: .balanced)
        XCTAssertEqual(point.id, date)
        XCTAssertEqual(point.score, 45)
        XCTAssertEqual(point.level, .balanced)
    }

    // MARK: - StressTrendDirection

    func testStressTrendDirection_rawValues() {
        XCTAssertEqual(StressTrendDirection.rising.rawValue, "rising")
        XCTAssertEqual(StressTrendDirection.falling.rawValue, "falling")
        XCTAssertEqual(StressTrendDirection.steady.rawValue, "steady")
    }

    // MARK: - JournalPrompt

    func testJournalPrompt_init() {
        let prompt = JournalPrompt(
            question: "What relaxed you?",
            context: "Your stress dropped this afternoon",
            icon: "pencil.circle.fill",
            date: Date()
        )
        XCTAssertEqual(prompt.question, "What relaxed you?")
        XCTAssertEqual(prompt.context, "Your stress dropped this afternoon")
        XCTAssertEqual(prompt.icon, "pencil.circle.fill")
    }

    // MARK: - StoredSnapshot

    func testStoredSnapshot_withAssessment() {
        let snapshot = HeartSnapshot(date: Date(), restingHeartRate: 64.0)
        let assessment = MockData.sampleAssessment
        let stored = StoredSnapshot(snapshot: snapshot, assessment: assessment)

        XCTAssertEqual(stored.snapshot.restingHeartRate, 64.0)
        XCTAssertNotNil(stored.assessment)
    }

    func testStoredSnapshot_withoutAssessment() {
        let snapshot = HeartSnapshot(date: Date())
        let stored = StoredSnapshot(snapshot: snapshot)
        XCTAssertNil(stored.assessment)
    }

    // MARK: - WatchFeedbackPayload

    func testWatchFeedbackPayload_hasEventId() {
        let payload = WatchFeedbackPayload(
            date: Date(),
            response: .positive,
            source: "test"
        )
        XCTAssertFalse(payload.eventId.isEmpty, "Should auto-generate an event ID")
    }

    func testWatchFeedbackPayload_customEventId() {
        let payload = WatchFeedbackPayload(
            eventId: "custom-123",
            date: Date(),
            response: .negative,
            source: "watch"
        )
        XCTAssertEqual(payload.eventId, "custom-123")
        XCTAssertEqual(payload.response, .negative)
    }

    // MARK: - AlertMeta

    func testAlertMeta_defaults() {
        let meta = AlertMeta()
        XCTAssertNil(meta.lastAlertAt)
        XCTAssertEqual(meta.alertsToday, 0)
        XCTAssertEqual(meta.alertsDayStamp, "")
    }
}

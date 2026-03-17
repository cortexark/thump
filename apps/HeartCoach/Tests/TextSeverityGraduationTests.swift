// TextSeverityGraduationTests.swift
// ThumpCoreTests
//
// Verifies that user-facing text changes at each severity threshold.
// Tests cover sleep, stress, HRV, and activity text tiers.
// Platforms: iOS 17+

import XCTest
@testable import Thump

final class TextSeverityGraduationTests: XCTestCase {

    private let engine = ReadinessEngine()

    // MARK: - Helper

    /// Creates a snapshot with the given sleep hours and sensible defaults.
    private func snapshot(
        sleepHours: Double? = 7.5,
        walkMinutes: Double? = 25,
        hrvSDNN: Double? = 45,
        restingHeartRate: Double? = 65,
        recoveryHR1m: Double? = 25
    ) -> HeartSnapshot {
        HeartSnapshot(
            date: Date(),
            restingHeartRate: restingHeartRate,
            hrvSDNN: hrvSDNN,
            recoveryHR1m: recoveryHR1m,
            walkMinutes: walkMinutes,
            workoutMinutes: 0,
            sleepHours: sleepHours
        )
    }

    /// Creates a history array with consistent HRV values for baseline.
    private func historyWithHRV(_ hrv: Double, days: Int = 14) -> [HeartSnapshot] {
        (0..<days).map { dayOffset in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!,
                restingHeartRate: 65,
                hrvSDNN: hrv,
                recoveryHR1m: 25,
                walkMinutes: 20,
                workoutMinutes: 0,
                sleepHours: 7.5
            )
        }
    }

    // MARK: - Sleep Text Tier Tests

    func testSleep_3h_showsVeryLow() {
        let s = snapshot(sleepHours: 3.0)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertTrue(sleepPillar!.detail.contains("very low"), "3h sleep should say 'very low', got: \(sleepPillar!.detail)")
    }

    func testSleep_4_5h_showsVeryLow() {
        let s = snapshot(sleepHours: 4.5)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertTrue(sleepPillar!.detail.contains("very low"), "4.5h sleep should say 'very low', got: \(sleepPillar!.detail)")
    }

    func testSleep_5_0h_showsWellBelow() {
        let s = snapshot(sleepHours: 5.0)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertTrue(sleepPillar!.detail.contains("well below"), "5.0h sleep should say 'well below', got: \(sleepPillar!.detail)")
    }

    func testSleep_5_9h_showsWellBelow() {
        let s = snapshot(sleepHours: 5.9)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertTrue(sleepPillar!.detail.contains("well below"), "5.9h sleep should say 'well below', got: \(sleepPillar!.detail)")
    }

    func testSleep_6_0h_showsABitUnder() {
        let s = snapshot(sleepHours: 6.0)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertTrue(sleepPillar!.detail.contains("a bit under"), "6.0h sleep should say 'a bit under', got: \(sleepPillar!.detail)")
    }

    func testSleep_6_9h_showsABitUnder() {
        let s = snapshot(sleepHours: 6.9)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertTrue(sleepPillar!.detail.contains("a bit under"), "6.9h sleep should say 'a bit under', got: \(sleepPillar!.detail)")
    }

    func testSleep_7_5h_showsSweetSpot() {
        let s = snapshot(sleepHours: 7.5)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertTrue(sleepPillar!.detail.contains("sweet spot"), "7.5h sleep should say 'sweet spot', got: \(sleepPillar!.detail)")
    }

    func testSleep_10h_showsMoreThanUsual() {
        let s = snapshot(sleepHours: 10.0)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertTrue(sleepPillar!.detail.contains("more rest than usual"), "10h sleep should say 'more rest than usual', got: \(sleepPillar!.detail)")
    }

    // MARK: - Stress Text Tier Tests

    func testStress_30_showsRelaxed() {
        let msg = StressLevel.friendlyMessage(for: 30)
        XCTAssertTrue(msg.contains("relaxed"), "Score 30 should say 'relaxed', got: \(msg)")
    }

    func testStress_50_showsBalanced() {
        let msg = StressLevel.friendlyMessage(for: 50)
        XCTAssertTrue(msg.contains("balanced"), "Score 50 should say 'balanced', got: \(msg)")
    }

    func testStress_70_showsABitWarm() {
        let msg = StressLevel.friendlyMessage(for: 70)
        XCTAssertTrue(msg.contains("a bit warm"), "Score 70 should say 'a bit warm', got: \(msg)")
    }

    func testStress_80_showsManagingMore() {
        let msg = StressLevel.friendlyMessage(for: 80)
        XCTAssertTrue(msg.contains("managing more"), "Score 80 should say 'managing more', got: \(msg)")
    }

    func testStress_90_showsUnderStrain() {
        let msg = StressLevel.friendlyMessage(for: 90)
        XCTAssertTrue(msg.contains("under a lot of strain"), "Score 90 should say 'under a lot of strain', got: \(msg)")
    }

    // MARK: - HRV Text Tier Tests

    func testHRV_ratio110_showsAbove() {
        // Today HRV = 55, baseline avg = 50 → ratio = 1.10
        let today = snapshot(hrvSDNN: 55)
        let history = historyWithHRV(50)
        let result = engine.compute(snapshot: today, stressScore: nil, recentHistory: history)
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        XCTAssertNotNil(hrvPillar)
        XCTAssertTrue(hrvPillar!.detail.contains("above"), "HRV ratio 1.10 should say 'above', got: \(hrvPillar!.detail)")
    }

    func testHRV_ratio97_showsBaseline() {
        // Today HRV = 48.5, baseline avg = 50 → ratio ≈ 0.97
        let today = snapshot(hrvSDNN: 48.5)
        let history = historyWithHRV(50)
        let result = engine.compute(snapshot: today, stressScore: nil, recentHistory: history)
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        XCTAssertNotNil(hrvPillar)
        XCTAssertTrue(hrvPillar!.detail.contains("baseline"), "HRV ratio 0.97 should say 'baseline', got: \(hrvPillar!.detail)")
    }

    func testHRV_ratio88_showsABitBelow() {
        // Today HRV = 44, baseline avg = 50 → ratio = 0.88
        let today = snapshot(hrvSDNN: 44)
        let history = historyWithHRV(50)
        let result = engine.compute(snapshot: today, stressScore: nil, recentHistory: history)
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        XCTAssertNotNil(hrvPillar)
        XCTAssertTrue(hrvPillar!.detail.contains("a bit below"), "HRV ratio 0.88 should say 'a bit below', got: \(hrvPillar!.detail)")
    }

    func testHRV_ratio70_showsNoticeablyLower() {
        // Today HRV = 35, baseline avg = 50 → ratio = 0.70
        let today = snapshot(hrvSDNN: 35)
        let history = historyWithHRV(50)
        let result = engine.compute(snapshot: today, stressScore: nil, recentHistory: history)
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        XCTAssertNotNil(hrvPillar)
        XCTAssertTrue(hrvPillar!.detail.contains("noticeably lower"), "HRV ratio 0.70 should say 'noticeably lower', got: \(hrvPillar!.detail)")
    }

    func testHRV_ratio50_showsWellBelow() {
        // Today HRV = 25, baseline avg = 50 → ratio = 0.50
        let today = snapshot(hrvSDNN: 25)
        let history = historyWithHRV(50)
        let result = engine.compute(snapshot: today, stressScore: nil, recentHistory: history)
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        XCTAssertNotNil(hrvPillar)
        XCTAssertTrue(hrvPillar!.detail.contains("well below"), "HRV ratio 0.50 should say 'well below', got: \(hrvPillar!.detail)")
    }

    // MARK: - Activity Text Tier Tests

    func testActivity_0min_showsRestDay() {
        let s = snapshot(walkMinutes: 0)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let actPillar = result?.pillars.first { $0.type == .activityBalance }
        XCTAssertNotNil(actPillar)
        XCTAssertTrue(actPillar!.detail.contains("Rest day"), "0 min should say 'Rest day', got: \(actPillar!.detail)")
    }

    func testActivity_2min_showsLow() {
        let s = snapshot(walkMinutes: 2)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let actPillar = result?.pillars.first { $0.type == .activityBalance }
        XCTAssertNotNil(actPillar)
        XCTAssertTrue(actPillar!.detail.contains("Movement is low"), "2 min should say 'Movement is low', got: \(actPillar!.detail)")
    }

    func testActivity_12min_showsGoodStart() {
        let s = snapshot(walkMinutes: 12)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let actPillar = result?.pillars.first { $0.type == .activityBalance }
        XCTAssertNotNil(actPillar)
        XCTAssertTrue(actPillar!.detail.contains("good start"), "12 min should say 'good start', got: \(actPillar!.detail)")
    }

    func testActivity_30min_showsKeepItUp() {
        let s = snapshot(walkMinutes: 30)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let actPillar = result?.pillars.first { $0.type == .activityBalance }
        XCTAssertNotNil(actPillar)
        XCTAssertTrue(actPillar!.detail.contains("keep it up"), "30 min should say 'keep it up', got: \(actPillar!.detail)")
    }

    func testActivity_50min_showsActiveDay() {
        let s = snapshot(walkMinutes: 50)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let actPillar = result?.pillars.first { $0.type == .activityBalance }
        XCTAssertNotNil(actPillar)
        XCTAssertTrue(actPillar!.detail.contains("active day"), "50 min should say 'active day', got: \(actPillar!.detail)")
    }
}

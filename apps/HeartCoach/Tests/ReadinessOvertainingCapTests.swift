// ReadinessOvertainingCapTests.swift
// ThumpTests
//
// Tests for the overtraining cap in ReadinessEngine: when a
// ConsecutiveElevationAlert is present (3+ days RHR above mean+2sigma),
// the readiness score must be capped at 50 regardless of pillar scores.

import XCTest
@testable import Thump

final class ReadinessOvertrainingCapTests: XCTestCase {

    private var engine: ReadinessEngine!

    override func setUp() {
        super.setUp()
        engine = ReadinessEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Builds a high-scoring snapshot and history that would normally
    /// produce a readiness score well above 50.
    private func makeExcellentInputs() -> (
        snapshot: HeartSnapshot,
        history: [HeartSnapshot]
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                hrvSDNN: 55.0,
                walkMinutes: 25,
                workoutMinutes: 10
            )
        }
        let snapshot = HeartSnapshot(
            date: today,
            hrvSDNN: 60.0,
            recoveryHR1m: 42.0,
            walkMinutes: 20,
            workoutMinutes: 15,
            sleepHours: 8.0
        )
        return (snapshot, history)
    }

    private func makeAlert(consecutiveDays: Int) -> ConsecutiveElevationAlert {
        ConsecutiveElevationAlert(
            consecutiveDays: consecutiveDays,
            threshold: 72.0,
            elevatedMean: 77.0,
            personalMean: 64.0
        )
    }

    // MARK: - Overtraining Cap Tests

    /// When consecutiveAlert is provided with 3+ days, readiness score
    /// should be capped at 50 even if all pillars score 90+.
    func testOvertrainingCap_kicksIn_withThreeDayAlert() {
        let (snapshot, history) = makeExcellentInputs()
        let alert = makeAlert(consecutiveDays: 3)

        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 10.0,
            recentHistory: history,
            consecutiveAlert: alert
        )

        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!.score, 50,
            "Readiness should be capped at 50 with a 3-day consecutive alert")
    }

    /// Same inputs without consecutiveAlert should produce score >50.
    func testNoCapWithoutAlert() {
        let (snapshot, history) = makeExcellentInputs()

        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 10.0,
            recentHistory: history,
            consecutiveAlert: nil
        )

        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.score, 50,
            "Without an alert, excellent inputs should score well above 50")
    }

    /// With excellent pillars + consecutive alert, score should be
    /// exactly 50 (capped, not zeroed out).
    func testCapIsExactly50_notLower() {
        let (snapshot, history) = makeExcellentInputs()
        let alert = makeAlert(consecutiveDays: 3)

        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 10.0,
            recentHistory: history,
            consecutiveAlert: alert
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.score, 50,
            "Excellent pillars with alert should be capped at exactly 50, not lower")
    }

    /// 4-day alert should also trigger the cap.
    func testFourDayAlert_stillCaps() {
        let (snapshot, history) = makeExcellentInputs()
        let alert = makeAlert(consecutiveDays: 4)

        let result = engine.compute(
            snapshot: snapshot,
            stressScore: 10.0,
            recentHistory: history,
            consecutiveAlert: alert
        )

        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!.score, 50,
            "4-day consecutive alert should also cap readiness at 50")
    }

    /// Passing nil for consecutiveAlert should let the score through
    /// unchanged (no cap applied).
    func testNilAlert_noCap() {
        let (snapshot, history) = makeExcellentInputs()

        let withoutAlert = engine.compute(
            snapshot: snapshot,
            stressScore: 10.0,
            recentHistory: history,
            consecutiveAlert: nil
        )

        let withoutParam = engine.compute(
            snapshot: snapshot,
            stressScore: 10.0,
            recentHistory: history
        )

        XCTAssertNotNil(withoutAlert)
        XCTAssertNotNil(withoutParam)
        XCTAssertEqual(withoutAlert!.score, withoutParam!.score,
            "Explicit nil and default nil should produce the same score")
        XCTAssertGreaterThan(withoutAlert!.score, 50,
            "No alert should let excellent scores through uncapped")
    }
}

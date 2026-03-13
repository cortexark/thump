// HeartSnapshotValidationTests.swift
// ThumpTests
//
// Tests for HeartSnapshot data bounds clamping to ensure all
// metrics are constrained to physiologically valid ranges.

import XCTest
@testable import Thump

final class HeartSnapshotValidationTests: XCTestCase {

    // MARK: - Nil Passthrough

    func testNilValuesRemainNil() {
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

    // MARK: - Valid Values Pass Through Unchanged

    func testValidValuesArePreserved() {
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 65.0,
            hrvSDNN: 42.0,
            recoveryHR1m: 30.0,
            recoveryHR2m: 45.0,
            vo2Max: 38.0,
            zoneMinutes: [60, 20, 10, 5, 1],
            steps: 8000,
            walkMinutes: 30.0,
            workoutMinutes: 45.0,
            sleepHours: 7.5
        )
        XCTAssertEqual(snapshot.restingHeartRate, 65.0)
        XCTAssertEqual(snapshot.hrvSDNN, 42.0)
        XCTAssertEqual(snapshot.recoveryHR1m, 30.0)
        XCTAssertEqual(snapshot.recoveryHR2m, 45.0)
        XCTAssertEqual(snapshot.vo2Max, 38.0)
        XCTAssertEqual(snapshot.steps, 8000)
        XCTAssertEqual(snapshot.walkMinutes, 30.0)
        XCTAssertEqual(snapshot.workoutMinutes, 45.0)
        XCTAssertEqual(snapshot.sleepHours, 7.5)
        XCTAssertEqual(snapshot.zoneMinutes, [60, 20, 10, 5, 1])
    }

    // MARK: - Resting Heart Rate (30-220 BPM)

    func testRHR_belowMinimum_returnsNil() {
        let snapshot = HeartSnapshot(date: Date(), restingHeartRate: 25.0)
        XCTAssertNil(snapshot.restingHeartRate, "RHR below 30 should be nil")
    }

    func testRHR_atMinimum_isPreserved() {
        let snapshot = HeartSnapshot(date: Date(), restingHeartRate: 30.0)
        XCTAssertEqual(snapshot.restingHeartRate, 30.0)
    }

    func testRHR_atMaximum_isPreserved() {
        let snapshot = HeartSnapshot(date: Date(), restingHeartRate: 220.0)
        XCTAssertEqual(snapshot.restingHeartRate, 220.0)
    }

    func testRHR_aboveMaximum_clampedTo220() {
        let snapshot = HeartSnapshot(date: Date(), restingHeartRate: 250.0)
        XCTAssertEqual(snapshot.restingHeartRate, 220.0)
    }

    // MARK: - HRV SDNN (5-300 ms)

    func testHRV_belowMinimum_returnsNil() {
        let snapshot = HeartSnapshot(date: Date(), hrvSDNN: 3.0)
        XCTAssertNil(snapshot.hrvSDNN, "HRV below 5 should be nil")
    }

    func testHRV_atMinimum_isPreserved() {
        let snapshot = HeartSnapshot(date: Date(), hrvSDNN: 5.0)
        XCTAssertEqual(snapshot.hrvSDNN, 5.0)
    }

    func testHRV_atMaximum_isPreserved() {
        let snapshot = HeartSnapshot(date: Date(), hrvSDNN: 300.0)
        XCTAssertEqual(snapshot.hrvSDNN, 300.0)
    }

    func testHRV_aboveMaximum_clampedTo300() {
        let snapshot = HeartSnapshot(date: Date(), hrvSDNN: 500.0)
        XCTAssertEqual(snapshot.hrvSDNN, 300.0)
    }

    // MARK: - Recovery HR 1 Minute (0-100 BPM)

    func testRecovery1m_negative_returnsNil() {
        let snapshot = HeartSnapshot(date: Date(), recoveryHR1m: -5.0)
        XCTAssertNil(snapshot.recoveryHR1m, "Negative recovery should be nil")
    }

    func testRecovery1m_atZero_isPreserved() {
        let snapshot = HeartSnapshot(date: Date(), recoveryHR1m: 0.0)
        XCTAssertEqual(snapshot.recoveryHR1m, 0.0)
    }

    func testRecovery1m_aboveMaximum_clampedTo100() {
        let snapshot = HeartSnapshot(date: Date(), recoveryHR1m: 120.0)
        XCTAssertEqual(snapshot.recoveryHR1m, 100.0)
    }

    // MARK: - Recovery HR 2 Minutes (0-120 BPM)

    func testRecovery2m_aboveMaximum_clampedTo120() {
        let snapshot = HeartSnapshot(date: Date(), recoveryHR2m: 150.0)
        XCTAssertEqual(snapshot.recoveryHR2m, 120.0)
    }

    func testRecovery2m_atMaximum_isPreserved() {
        let snapshot = HeartSnapshot(date: Date(), recoveryHR2m: 120.0)
        XCTAssertEqual(snapshot.recoveryHR2m, 120.0)
    }

    // MARK: - VO2 Max (10-90 mL/kg/min)

    func testVO2Max_belowMinimum_returnsNil() {
        let snapshot = HeartSnapshot(date: Date(), vo2Max: 5.0)
        XCTAssertNil(snapshot.vo2Max, "VO2 below 10 should be nil")
    }

    func testVO2Max_atMinimum_isPreserved() {
        let snapshot = HeartSnapshot(date: Date(), vo2Max: 10.0)
        XCTAssertEqual(snapshot.vo2Max, 10.0)
    }

    func testVO2Max_aboveMaximum_clampedTo90() {
        let snapshot = HeartSnapshot(date: Date(), vo2Max: 100.0)
        XCTAssertEqual(snapshot.vo2Max, 90.0)
    }

    // MARK: - Steps (0-200,000)

    func testSteps_negative_returnsNil() {
        let snapshot = HeartSnapshot(date: Date(), steps: -100)
        XCTAssertNil(snapshot.steps, "Negative steps should be nil")
    }

    func testSteps_atZero_isPreserved() {
        let snapshot = HeartSnapshot(date: Date(), steps: 0)
        XCTAssertEqual(snapshot.steps, 0)
    }

    func testSteps_aboveMaximum_clampedTo200k() {
        let snapshot = HeartSnapshot(date: Date(), steps: 300_000)
        XCTAssertEqual(snapshot.steps, 200_000)
    }

    // MARK: - Walk Minutes (0-1440)

    func testWalkMinutes_negative_returnsNil() {
        let snapshot = HeartSnapshot(date: Date(), walkMinutes: -10)
        XCTAssertNil(snapshot.walkMinutes, "Negative walk minutes should be nil")
    }

    func testWalkMinutes_aboveMaximum_clampedTo1440() {
        let snapshot = HeartSnapshot(date: Date(), walkMinutes: 2000)
        XCTAssertEqual(snapshot.walkMinutes, 1440)
    }

    // MARK: - Workout Minutes (0-1440)

    func testWorkoutMinutes_negative_returnsNil() {
        let snapshot = HeartSnapshot(date: Date(), workoutMinutes: -10)
        XCTAssertNil(snapshot.workoutMinutes, "Negative workout minutes should be nil")
    }

    func testWorkoutMinutes_aboveMaximum_clampedTo1440() {
        let snapshot = HeartSnapshot(date: Date(), workoutMinutes: 2000)
        XCTAssertEqual(snapshot.workoutMinutes, 1440)
    }

    // MARK: - Sleep Hours (0-24)

    func testSleepHours_negative_returnsNil() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: -1)
        XCTAssertNil(snapshot.sleepHours, "Negative sleep hours should be nil")
    }

    func testSleepHours_atZero_isPreserved() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 0)
        XCTAssertEqual(snapshot.sleepHours, 0)
    }

    func testSleepHours_aboveMaximum_clampedTo24() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 30)
        XCTAssertEqual(snapshot.sleepHours, 24)
    }

    func testSleepHours_atMaximum_isPreserved() {
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 24)
        XCTAssertEqual(snapshot.sleepHours, 24)
    }

    // MARK: - Zone Minutes Clamping

    func testZoneMinutes_negativeValuesClampedToZero() {
        let snapshot = HeartSnapshot(date: Date(), zoneMinutes: [-10, 20, -5])
        XCTAssertEqual(snapshot.zoneMinutes, [0, 20, 0])
    }

    func testZoneMinutes_aboveMaximumClampedTo1440() {
        let snapshot = HeartSnapshot(date: Date(), zoneMinutes: [60, 2000, 30])
        XCTAssertEqual(snapshot.zoneMinutes, [60, 1440, 30])
    }

    // MARK: - Boundary Edge Cases

    func testAllMetricsAtBoundaries_lowerBound() {
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 30.0,
            hrvSDNN: 5.0,
            recoveryHR1m: 0.0,
            recoveryHR2m: 0.0,
            vo2Max: 10.0,
            steps: 0,
            walkMinutes: 0,
            workoutMinutes: 0,
            sleepHours: 0
        )
        XCTAssertEqual(snapshot.restingHeartRate, 30.0)
        XCTAssertEqual(snapshot.hrvSDNN, 5.0)
        XCTAssertEqual(snapshot.recoveryHR1m, 0.0)
        XCTAssertEqual(snapshot.recoveryHR2m, 0.0)
        XCTAssertEqual(snapshot.vo2Max, 10.0)
        XCTAssertEqual(snapshot.steps, 0)
        XCTAssertEqual(snapshot.walkMinutes, 0)
        XCTAssertEqual(snapshot.workoutMinutes, 0)
        XCTAssertEqual(snapshot.sleepHours, 0)
    }

    func testAllMetricsAtBoundaries_upperBound() {
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 220.0,
            hrvSDNN: 300.0,
            recoveryHR1m: 100.0,
            recoveryHR2m: 120.0,
            vo2Max: 90.0,
            steps: 200_000,
            walkMinutes: 1440,
            workoutMinutes: 1440,
            sleepHours: 24
        )
        XCTAssertEqual(snapshot.restingHeartRate, 220.0)
        XCTAssertEqual(snapshot.hrvSDNN, 300.0)
        XCTAssertEqual(snapshot.recoveryHR1m, 100.0)
        XCTAssertEqual(snapshot.recoveryHR2m, 120.0)
        XCTAssertEqual(snapshot.vo2Max, 90.0)
        XCTAssertEqual(snapshot.steps, 200_000)
        XCTAssertEqual(snapshot.walkMinutes, 1440)
        XCTAssertEqual(snapshot.workoutMinutes, 1440)
        XCTAssertEqual(snapshot.sleepHours, 24)
    }

    func testAllMetricsAboveUpperBound_allClamped() {
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 999.0,
            hrvSDNN: 999.0,
            recoveryHR1m: 999.0,
            recoveryHR2m: 999.0,
            vo2Max: 999.0,
            steps: 999_999,
            walkMinutes: 9999,
            workoutMinutes: 9999,
            sleepHours: 99
        )
        XCTAssertEqual(snapshot.restingHeartRate, 220.0)
        XCTAssertEqual(snapshot.hrvSDNN, 300.0)
        XCTAssertEqual(snapshot.recoveryHR1m, 100.0)
        XCTAssertEqual(snapshot.recoveryHR2m, 120.0)
        XCTAssertEqual(snapshot.vo2Max, 90.0)
        XCTAssertEqual(snapshot.steps, 200_000)
        XCTAssertEqual(snapshot.walkMinutes, 1440)
        XCTAssertEqual(snapshot.workoutMinutes, 1440)
        XCTAssertEqual(snapshot.sleepHours, 24)
    }

    func testAllMetricsBelowLowerBound_allNil() {
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: -10,
            hrvSDNN: -5,
            recoveryHR1m: -1,
            recoveryHR2m: -1,
            vo2Max: -1,
            steps: -100,
            walkMinutes: -1,
            workoutMinutes: -1,
            sleepHours: -1
        )
        XCTAssertNil(snapshot.restingHeartRate)
        XCTAssertNil(snapshot.hrvSDNN)
        XCTAssertNil(snapshot.recoveryHR1m)
        XCTAssertNil(snapshot.recoveryHR2m)
        XCTAssertNil(snapshot.vo2Max)
        XCTAssertNil(snapshot.steps)
        XCTAssertNil(snapshot.walkMinutes)
        XCTAssertNil(snapshot.workoutMinutes)
        XCTAssertNil(snapshot.sleepHours)
    }
}

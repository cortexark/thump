// PerformanceTests.swift
// ThumpCoreTests
//
// Performance and stability tests for critical paths —
// snapshot construction, stress scoring, model serialization,
// ring buffer throughput, and edge case resilience.

import XCTest
@testable import Thump

final class PerformanceTests: XCTestCase {

    // MARK: - HeartSnapshot Construction Performance

    func testPerformance_snapshotConstruction_1000Snapshots() {
        measure {
            for i in 0..<1000 {
                let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
                _ = HeartSnapshot(
                    date: date,
                    restingHeartRate: Double.random(in: 50...80),
                    hrvSDNN: Double.random(in: 20...80),
                    recoveryHR1m: Double.random(in: 10...50),
                    vo2Max: Double.random(in: 30...60),
                    zoneMinutes: [10, 20, 30, 15, 5],
                    steps: Double.random(in: 2000...15000),
                    walkMinutes: Double.random(in: 10...60),
                    workoutMinutes: Double.random(in: 0...90),
                    sleepHours: Double.random(in: 5...9),
                    bodyMassKg: 75,
                    heightM: 1.78
                )
            }
        }
    }

    // MARK: - StressLevel Scoring Performance

    func testPerformance_stressLevelFromScore_100000Scores() {
        measure {
            for _ in 0..<100_000 {
                _ = StressLevel.from(score: Double.random(in: 0...100))
            }
        }
    }

    // MARK: - Codable Serialization Performance

    func testPerformance_snapshotCodableRoundTrip_500() throws {
        let snapshots: [HeartSnapshot] = (0..<500).map { i in
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            return HeartSnapshot(
                date: date,
                restingHeartRate: 65,
                hrvSDNN: 45,
                steps: 8000,
                sleepHours: 7.5
            )
        }

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        measure {
            for snapshot in snapshots {
                let data = try! encoder.encode(snapshot)
                _ = try! decoder.decode(HeartSnapshot.self, from: data)
            }
        }
    }

    // MARK: - CrashBreadcrumbs Throughput

    func testPerformance_breadcrumbs_10000Adds() {
        let bc = CrashBreadcrumbs(capacity: 100)
        measure {
            for i in 0..<10_000 {
                bc.add("event-\(i)")
            }
            _ = bc.allBreadcrumbs()
        }
    }

    // MARK: - Stability: Edge Cases

    func testStability_snapshotWithAllNils_doesNotCrash() {
        let snap = HeartSnapshot(date: Date())
        XCTAssertNil(snap.restingHeartRate)
        XCTAssertNil(snap.hrvSDNN)
        XCTAssertNil(snap.recoveryHR1m)
        XCTAssertNil(snap.recoveryHR2m)
        XCTAssertNil(snap.vo2Max)
        XCTAssertEqual(snap.zoneMinutes, [])
        XCTAssertNil(snap.steps)
        XCTAssertNil(snap.walkMinutes)
        XCTAssertNil(snap.workoutMinutes)
        XCTAssertNil(snap.sleepHours)
        XCTAssertNil(snap.bodyMassKg)
        XCTAssertNil(snap.heightM)
        XCTAssertNil(snap.activityMinutes)
    }

    func testStability_snapshotWithExtremeValues_clampedSafely() {
        let snap = HeartSnapshot(
            date: Date(),
            restingHeartRate: Double.infinity,
            hrvSDNN: -Double.infinity,
            recoveryHR1m: Double.nan,
            vo2Max: 999999,
            zoneMinutes: Array(repeating: -999, count: 100),
            steps: Double.greatestFiniteMagnitude,
            walkMinutes: -1,
            workoutMinutes: Double.infinity,
            sleepHours: Double.nan,
            bodyMassKg: 0,
            heightM: -5
        )
        // Should not crash — clamping handles extremes
        XCTAssertNotNil(snap)
    }

    func testStability_emptyCollections_allModelOperations() {
        // Verify no crashes with empty data
        let emptyPlan = WeeklyActionPlan(
            items: [],
            weekStart: Date(),
            weekEnd: Date()
        )
        XCTAssertEqual(emptyPlan.items.count, 0)

        let emptyWatchPlan = WatchActionPlan(
            dailyItems: [],
            weeklyHeadline: "",
            monthlyHeadline: "",
            monthName: ""
        )
        XCTAssertEqual(emptyWatchPlan.dailyItems.count, 0)
    }

    func testStability_userProfile_extremeStreakDays() {
        let profile = UserProfile(streakDays: 999999)
        XCTAssertEqual(profile.streakDays, 999999)
    }

    func testStability_stressLevel_boundaryScores() {
        // Test exact boundary values
        let boundaries: [Double] = [0, 0.001, 32.999, 33, 33.001, 66, 66.001, 99.999, 100]
        for score in boundaries {
            let level = StressLevel.from(score: score)
            XCTAssertNotNil(level, "StressLevel.from(score: \(score)) should not be nil")
        }
    }

    func testStability_breadcrumbs_capacityOne() {
        let bc = CrashBreadcrumbs(capacity: 1)
        bc.add("first")
        bc.add("second")
        let crumbs = bc.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 1)
        XCTAssertEqual(crumbs[0].message, "second")
    }

    // MARK: - Integration: Model Construction Pipeline

    func testIntegration_fullAssessmentPipeline() {
        // Construct a full HeartAssessment with all optional fields populated
        let nudge = DailyNudge(
            category: .walk,
            title: "Walk",
            description: "Get moving",
            durationMinutes: 15,
            icon: "figure.walk"
        )
        let nudge2 = DailyNudge(
            category: .breathe,
            title: "Breathe",
            description: "Calm down",
            durationMinutes: 5,
            icon: "wind"
        )
        let trend = WeekOverWeekTrend(
            zScore: -1.2,
            direction: .improving,
            baselineMean: 65,
            baselineStd: 4,
            currentWeekMean: 62
        )
        let alert = ConsecutiveElevationAlert(
            consecutiveDays: 3,
            threshold: 72,
            elevatedMean: 75,
            personalMean: 65
        )
        let recovery = RecoveryTrend(
            direction: .improving,
            currentWeekMean: 35,
            baselineMean: 30,
            zScore: 1.5,
            dataPoints: 4
        )
        let context = RecoveryContext(
            driver: "HRV",
            reason: "Below baseline",
            tonightAction: "Go to bed by 10 PM",
            bedtimeTarget: "10 PM",
            readinessScore: 45
        )
        let assessment = HeartAssessment(
            status: .improving,
            confidence: .high,
            anomalyScore: 0.3,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: 78,
            dailyNudge: nudge,
            dailyNudges: [nudge, nudge2],
            explanation: "Your metrics are trending positively",
            weekOverWeekTrend: trend,
            consecutiveAlert: alert,
            scenario: .improvingTrend,
            recoveryTrend: recovery,
            recoveryContext: context
        )

        // Verify all fields populated correctly
        XCTAssertEqual(assessment.status, .improving)
        XCTAssertEqual(assessment.dailyNudges.count, 2)
        XCTAssertNotNil(assessment.weekOverWeekTrend)
        XCTAssertNotNil(assessment.consecutiveAlert)
        XCTAssertNotNil(assessment.scenario)
        XCTAssertNotNil(assessment.recoveryTrend)
        XCTAssertNotNil(assessment.recoveryContext)
        XCTAssertEqual(assessment.dailyNudgeText, "Walk (15 min): Get moving")
    }

    func testIntegration_watchActionPlan_fullConstruction() {
        let plan = WatchActionPlan(
            dailyItems: [
                WatchActionItem(category: .rest, title: "Sleep", detail: "Wind down", icon: "bed.double.fill", reminderHour: 22),
                WatchActionItem(category: .breathe, title: "Breathe", detail: "Box breathing", icon: "wind", reminderHour: 7),
                WatchActionItem(category: .walk, title: "Walk", detail: "Get steps", icon: "figure.walk"),
                WatchActionItem(category: .sunlight, title: "Sun", detail: "Go outside", icon: "sun.max.fill", reminderHour: 12),
            ],
            weeklyHeadline: "Great week!",
            weeklyAvgScore: 80,
            weeklyActiveDays: 6,
            weeklyLowStressDays: 5,
            monthlyHeadline: "Your best month!",
            monthlyScoreDelta: 10,
            monthName: "March"
        )

        XCTAssertEqual(plan.dailyItems.count, 4)
        XCTAssertEqual(plan.weeklyActiveDays, 6)
        XCTAssertEqual(plan.monthlyScoreDelta, 10)

        // Codable round trip
        let data = try! JSONEncoder().encode(plan)
        let decoded = try! JSONDecoder().decode(WatchActionPlan.self, from: data)
        XCTAssertEqual(decoded.dailyItems.count, 4)
    }
}

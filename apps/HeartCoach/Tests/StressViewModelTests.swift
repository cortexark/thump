// StressViewModelTests.swift
// ThumpCoreTests
//
// Comprehensive tests for StressViewModel: computed properties,
// day selection, trend insight generation, empty state handling,
// range switching, month calendar, and edge cases.
// (Complements StressViewActionTests which covers action buttons.)

import XCTest
@testable import Thump

@MainActor
final class StressViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSnapshot(
        daysAgo: Int,
        rhr: Double = 64.0,
        hrv: Double = 48.0,
        sleepHours: Double? = 7.5
    ) -> HeartSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return HeartSnapshot(
            date: date,
            restingHeartRate: rhr,
            hrvSDNN: hrv,
            recoveryHR1m: 25.0,
            recoveryHR2m: 40.0,
            vo2Max: 38.0,
            zoneMinutes: [110, 25, 12, 5, 1],
            steps: 8000,
            walkMinutes: 30.0,
            workoutMinutes: 20.0,
            sleepHours: sleepHours
        )
    }

    private func makeHistory(days: Int) -> [HeartSnapshot] {
        (1...days).reversed().map { day in
            makeSnapshot(daysAgo: day, rhr: 60.0 + Double(day % 5), hrv: 40.0 + Double(day % 6))
        }
    }

    // MARK: - Initial State

    func testInitialState_defaults() {
        let vm = StressViewModel()
        XCTAssertNil(vm.currentStress)
        XCTAssertTrue(vm.trendPoints.isEmpty)
        XCTAssertTrue(vm.hourlyPoints.isEmpty)
        XCTAssertEqual(vm.selectedRange, .week)
        XCTAssertNil(vm.selectedDayForDetail)
        XCTAssertTrue(vm.selectedDayHourlyPoints.isEmpty)
        XCTAssertEqual(vm.trendDirection, .steady)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.history.isEmpty)
    }

    // MARK: - Computed Properties: Average Stress

    func testAverageStress_nilWhenEmpty() {
        let vm = StressViewModel()
        XCTAssertNil(vm.averageStress)
    }

    func testAverageStress_computesCorrectly() {
        let vm = StressViewModel()
        vm.trendPoints = [
            StressDataPoint(date: Date(), score: 30, level: .relaxed),
            StressDataPoint(date: Date(), score: 50, level: .balanced),
            StressDataPoint(date: Date(), score: 70, level: .elevated)
        ]
        XCTAssertEqual(vm.averageStress, 50.0)
    }

    // MARK: - Most Relaxed / Most Elevated

    func testMostRelaxedDay_returnsLowest() {
        let vm = StressViewModel()
        let d1 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let d2 = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let d3 = Date()
        vm.trendPoints = [
            StressDataPoint(date: d1, score: 40, level: .balanced),
            StressDataPoint(date: d2, score: 20, level: .relaxed),
            StressDataPoint(date: d3, score: 60, level: .balanced)
        ]
        XCTAssertEqual(vm.mostRelaxedDay?.score, 20)
    }

    func testMostElevatedDay_returnsHighest() {
        let vm = StressViewModel()
        let d1 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let d2 = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        vm.trendPoints = [
            StressDataPoint(date: d1, score: 40, level: .balanced),
            StressDataPoint(date: d2, score: 80, level: .elevated)
        ]
        XCTAssertEqual(vm.mostElevatedDay?.score, 80)
    }

    func testMostRelaxedDay_nilWhenEmpty() {
        let vm = StressViewModel()
        XCTAssertNil(vm.mostRelaxedDay)
    }

    func testMostElevatedDay_nilWhenEmpty() {
        let vm = StressViewModel()
        XCTAssertNil(vm.mostElevatedDay)
    }

    // MARK: - Chart Data Points

    func testChartDataPoints_returnsTuples() {
        let vm = StressViewModel()
        let date = Date()
        vm.trendPoints = [
            StressDataPoint(date: date, score: 45, level: .balanced)
        ]

        let chart = vm.chartDataPoints
        XCTAssertEqual(chart.count, 1)
        XCTAssertEqual(chart[0].date, date)
        XCTAssertEqual(chart[0].value, 45.0)
    }

    // MARK: - Week Day Points

    func testWeekDayPoints_filtersToLast7Days() {
        let vm = StressViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var points: [StressDataPoint] = []
        for i in 0..<14 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            points.append(StressDataPoint(date: date, score: Double(30 + i), level: .balanced))
        }
        vm.trendPoints = points

        let weekPoints = vm.weekDayPoints
        XCTAssertLessThanOrEqual(weekPoints.count, 7)
    }

    func testWeekDayPoints_sortedByDate() {
        let vm = StressViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var points: [StressDataPoint] = []
        for i in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            points.append(StressDataPoint(date: date, score: Double(30 + i), level: .balanced))
        }
        vm.trendPoints = points

        let weekPoints = vm.weekDayPoints
        if weekPoints.count >= 2 {
            for i in 0..<(weekPoints.count - 1) {
                XCTAssertLessThanOrEqual(weekPoints[i].date, weekPoints[i + 1].date)
            }
        }
    }

    // MARK: - Day Selection

    func testSelectDay_setsSelectedDayForDetail() {
        let vm = StressViewModel()
        vm.history = makeHistory(days: 14)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        vm.selectDay(yesterday)

        XCTAssertNotNil(vm.selectedDayForDetail)
    }

    func testSelectDay_togglesOff_whenSameDayTapped() {
        let vm = StressViewModel()
        vm.history = makeHistory(days: 14)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        vm.selectDay(yesterday)
        XCTAssertNotNil(vm.selectedDayForDetail)

        vm.selectDay(yesterday)
        XCTAssertNil(vm.selectedDayForDetail, "Tapping same day again should deselect")
        XCTAssertTrue(vm.selectedDayHourlyPoints.isEmpty)
    }

    // MARK: - Trend Insight Text

    func testTrendInsight_risingDirection() {
        let vm = StressViewModel()
        vm.trendDirection = .rising
        let insight = vm.trendInsight
        XCTAssertNotNil(insight)
        XCTAssertTrue(insight!.contains("climbing"), "Rising insight should mention climbing")
    }

    func testTrendInsight_fallingDirection() {
        let vm = StressViewModel()
        vm.trendDirection = .falling
        let insight = vm.trendInsight
        XCTAssertNotNil(insight)
        XCTAssertTrue(insight!.contains("easing"), "Falling insight should mention easing")
    }

    func testTrendInsight_steady_relaxed() {
        let vm = StressViewModel()
        vm.trendDirection = .steady
        vm.trendPoints = [
            StressDataPoint(date: Date(), score: 20, level: .relaxed)
        ]
        let insight = vm.trendInsight
        XCTAssertNotNil(insight)
        XCTAssertTrue(insight!.contains("relaxed"))
    }

    func testTrendInsight_steady_elevated() {
        let vm = StressViewModel()
        vm.trendDirection = .steady
        vm.trendPoints = [
            StressDataPoint(date: Date(), score: 80, level: .elevated)
        ]
        let insight = vm.trendInsight
        XCTAssertNotNil(insight)
        XCTAssertTrue(insight!.contains("higher"))
    }

    func testTrendInsight_steady_balanced() {
        let vm = StressViewModel()
        vm.trendDirection = .steady
        vm.trendPoints = [
            StressDataPoint(date: Date(), score: 50, level: .balanced)
        ]
        let insight = vm.trendInsight
        XCTAssertNotNil(insight)
        XCTAssertTrue(insight!.contains("consistent"))
    }

    func testTrendInsight_steady_nilWhenNoAverage() {
        let vm = StressViewModel()
        vm.trendDirection = .steady
        vm.trendPoints = []
        XCTAssertNil(vm.trendInsight)
    }

    // MARK: - Month Calendar Weeks

    func testMonthCalendarWeeks_hasCorrectStructure() {
        let vm = StressViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Add points for every day this month
        let monthRange = calendar.range(of: .day, in: .month, for: today)!
        var points: [StressDataPoint] = []
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        for day in monthRange {
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            points.append(StressDataPoint(date: date, score: 40, level: .balanced))
        }
        vm.trendPoints = points

        let weeks = vm.monthCalendarWeeks
        XCTAssertGreaterThan(weeks.count, 0, "Should have at least one week")
        for week in weeks {
            XCTAssertEqual(week.count, 7, "Each week should have exactly 7 slots")
        }
    }

    func testMonthCalendarWeeks_emptyTrendPoints_returnsStructure() {
        let vm = StressViewModel()
        vm.trendPoints = []
        let weeks = vm.monthCalendarWeeks
        // Should still generate the calendar structure even with no data
        XCTAssertGreaterThan(weeks.count, 0)
    }

    // MARK: - Handle Smart Action: morningCheckIn Dismissal

    func testHandleSmartAction_morningCheckIn_dismissesCard() {
        let vm = StressViewModel()
        vm.smartActions = [.morningCheckIn("How are you feeling?"), .standardNudge]
        vm.smartAction = .morningCheckIn("How are you feeling?")

        vm.handleSmartAction(.morningCheckIn("How are you feeling?"))

        XCTAssertFalse(vm.smartActions.contains(where: {
            if case .morningCheckIn = $0 { return true } else { return false }
        }))
        if case .standardNudge = vm.smartAction {} else {
            XCTFail("Smart action should reset to standardNudge after dismissing morningCheckIn")
        }
    }

    // MARK: - Handle Smart Action: bedtimeWindDown Dismissal

    func testHandleSmartAction_bedtimeWindDown_dismissesCard() {
        let nudge = DailyNudge(
            category: .rest,
            title: "Wind Down",
            description: "Time to rest",
            durationMinutes: nil,
            icon: "bed.double.fill"
        )
        let vm = StressViewModel()
        vm.smartActions = [.bedtimeWindDown(nudge), .standardNudge]
        vm.smartAction = .bedtimeWindDown(nudge)

        vm.handleSmartAction(.bedtimeWindDown(nudge))

        XCTAssertFalse(vm.smartActions.contains(where: {
            if case .bedtimeWindDown = $0 { return true } else { return false }
        }))
    }

    // MARK: - Handle Smart Action: restSuggestion Starts Breathing

    func testHandleSmartAction_restSuggestion_startsBreathing() {
        let nudge = DailyNudge(
            category: .rest,
            title: "Rest",
            description: "Take a break",
            durationMinutes: 5,
            icon: "bed.double.fill"
        )
        let vm = StressViewModel()
        vm.handleSmartAction(.restSuggestion(nudge))

        XCTAssertTrue(vm.isBreathingSessionActive)
    }

    // MARK: - Custom Breathing Duration

    func testStartBreathingSession_customDuration() {
        let vm = StressViewModel()
        vm.startBreathingSession(durationSeconds: 120)
        XCTAssertEqual(vm.breathingSecondsRemaining, 120)
        XCTAssertTrue(vm.isBreathingSessionActive)
        vm.stopBreathingSession()
    }

    // MARK: - Readiness Notification Listener

    func testReadinessNotification_updatesAssessmentReadinessLevel() async {
        let vm = StressViewModel()
        XCTAssertNil(vm.assessmentReadinessLevel)

        NotificationCenter.default.post(
            name: .thumpReadinessDidUpdate,
            object: nil,
            userInfo: ["readinessLevel": "recovering"]
        )

        // Give the RunLoop a chance to process the notification
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(vm.assessmentReadinessLevel, .recovering)
    }
}

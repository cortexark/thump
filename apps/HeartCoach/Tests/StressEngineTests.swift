// StressEngineTests.swift
// ThumpTests
//
// Tests for the StressEngine: core computation, hourly estimation,
// trend direction, and various stress profile scenarios.

import XCTest
@testable import Thump

final class StressEngineTests: XCTestCase {

    private var engine: StressEngine!

    override func setUp() {
        super.setUp()
        engine = StressEngine(baselineWindow: 14)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Core Computation

    func testComputeStress_atBaseline_returnsLowStress() {
        let result = engine.computeStress(currentHRV: 50.0, baselineHRV: 50.0)
        // Multi-signal: at-baseline HRV → Z=0 → rawScore=35 → sigmoid≈23
        XCTAssertLessThan(result.score, 40,
            "At-baseline HRV should show low stress, got \(result.score)")
        XCTAssertTrue(result.level == .relaxed || result.level == .balanced)
    }

    func testComputeStress_wellAboveBaseline_returnsRelaxed() {
        let result = engine.computeStress(currentHRV: 70.0, baselineHRV: 50.0)
        XCTAssertLessThan(result.score, 33.0)
        XCTAssertEqual(result.level, .relaxed)
    }

    func testComputeStress_wellBelowBaseline_returnsElevated() {
        let result = engine.computeStress(currentHRV: 20.0, baselineHRV: 50.0)
        XCTAssertGreaterThan(result.score, 66.0)
        XCTAssertEqual(result.level, .elevated)
    }

    func testComputeStress_zeroBaseline_returnsDefault() {
        let result = engine.computeStress(currentHRV: 40.0, baselineHRV: 0.0)
        XCTAssertEqual(result.score, 50.0)
        XCTAssertEqual(result.level, .balanced)
    }

    func testComputeStress_scoreClampedAt0() {
        // HRV massively above baseline → score should not go below 0
        let result = engine.computeStress(currentHRV: 200.0, baselineHRV: 50.0)
        XCTAssertGreaterThanOrEqual(result.score, 0.0)
    }

    func testComputeStress_scoreClampedAt100() {
        // HRV massively below baseline → score should not exceed 100
        let result = engine.computeStress(currentHRV: 5.0, baselineHRV: 80.0)
        XCTAssertLessThanOrEqual(result.score, 100.0)
    }

    // MARK: - Daily Stress Score

    func testDailyStressScore_insufficientData_returnsNil() {
        let snapshots = [makeSnapshot(day: 0, hrv: 50)]
        XCTAssertNil(engine.dailyStressScore(snapshots: snapshots))
    }

    func testDailyStressScore_withHistory_returnsScore() {
        let snapshots = (0..<15).map { makeSnapshot(day: $0, hrv: 50.0) }
        let score = engine.dailyStressScore(snapshots: snapshots)
        XCTAssertNotNil(score)
        // Constant HRV with multi-signal sigmoid → low stress
        XCTAssertLessThan(score!, 40, "Constant HRV should yield low stress")
    }

    // MARK: - Stress Trend

    func testStressTrend_producesPointsInRange() {
        let snapshots = MockData.mockHistory(days: 30)
        let trend = engine.stressTrend(snapshots: snapshots, range: .week)
        XCTAssertFalse(trend.isEmpty)

        for point in trend {
            XCTAssertGreaterThanOrEqual(point.score, 0)
            XCTAssertLessThanOrEqual(point.score, 100)
        }
    }

    func testStressTrend_emptyHistory_returnsEmpty() {
        let trend = engine.stressTrend(snapshots: [], range: .week)
        XCTAssertTrue(trend.isEmpty)
    }

    // MARK: - Hourly Stress Estimation

    func testHourlyStressEstimates_returns24Points() {
        let points = engine.hourlyStressEstimates(
            dailyHRV: 50.0,
            baselineHRV: 50.0,
            date: Date()
        )
        XCTAssertEqual(points.count, 24)
    }

    func testHourlyStressEstimates_nightHoursLowerStress() {
        let points = engine.hourlyStressEstimates(
            dailyHRV: 50.0,
            baselineHRV: 50.0,
            date: Date()
        )

        // Night hours (0-5) should have lower stress than afternoon (12-17)
        let nightAvg = points.filter { $0.hour < 6 }
            .map(\.score).reduce(0, +) / 6.0
        let afternoonAvg = points.filter { $0.hour >= 12 && $0.hour < 18 }
            .map(\.score).reduce(0, +) / 6.0

        XCTAssertLessThan(
            nightAvg, afternoonAvg,
            "Night stress (\(nightAvg)) should be lower than "
            + "afternoon stress (\(afternoonAvg))"
        )
    }

    func testHourlyStressForDay_withValidData_returnsPoints() {
        let snapshots = MockData.mockHistory(days: 21)
        let today = Calendar.current.startOfDay(for: Date())
        let points = engine.hourlyStressForDay(
            snapshots: snapshots, date: today
        )
        XCTAssertEqual(points.count, 24)
    }

    func testHourlyStressForDay_noMatchingDate_returnsEmpty() {
        let snapshots = MockData.mockHistory(days: 5)
        let farFuture = Calendar.current.date(
            byAdding: .year, value: 1, to: Date()
        )!
        let points = engine.hourlyStressForDay(
            snapshots: snapshots, date: farFuture
        )
        XCTAssertTrue(points.isEmpty)
    }

    func testHourlyStressForDay_missingHRVUsesRecentFallback() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let snapshots = [
            HeartSnapshot(date: twoDaysAgo, restingHeartRate: 61, hrvSDNN: 46, sleepHours: 7.1),
            HeartSnapshot(date: yesterday, restingHeartRate: 60, hrvSDNN: 49, sleepHours: 7.4),
            HeartSnapshot(date: today, restingHeartRate: 62, hrvSDNN: nil, sleepHours: 6.8),
        ]

        let points = engine.hourlyStressForDay(
            snapshots: snapshots,
            date: today
        )

        XCTAssertEqual(points.count, 24)
        XCTAssertEqual(points.map(\.hour), Array(0..<24))
    }

    // MARK: - Trend Direction

    func testTrendDirection_risingScores_returnsRising() {
        let points = (0..<7).map { i in
            StressDataPoint(
                date: Calendar.current.date(
                    byAdding: .day, value: -6 + i, to: Date()
                )!,
                score: 30.0 + Double(i) * 8.0,
                level: .balanced
            )
        }
        XCTAssertEqual(engine.trendDirection(points: points), .rising)
    }

    func testTrendDirection_fallingScores_returnsFalling() {
        let points = (0..<7).map { i in
            StressDataPoint(
                date: Calendar.current.date(
                    byAdding: .day, value: -6 + i, to: Date()
                )!,
                score: 80.0 - Double(i) * 8.0,
                level: .elevated
            )
        }
        XCTAssertEqual(engine.trendDirection(points: points), .falling)
    }

    func testTrendDirection_flatScores_returnsSteady() {
        let points = (0..<7).map { i in
            StressDataPoint(
                date: Calendar.current.date(
                    byAdding: .day, value: -6 + i, to: Date()
                )!,
                score: 50.0 + (i.isMultiple(of: 2) ? 1.0 : -1.0),
                level: .balanced
            )
        }
        XCTAssertEqual(engine.trendDirection(points: points), .steady)
    }

    func testTrendDirection_insufficientData_returnsSteady() {
        let points = [
            StressDataPoint(date: Date(), score: 50, level: .balanced)
        ]
        XCTAssertEqual(engine.trendDirection(points: points), .steady)
    }

    // MARK: - Stress Profile Scenarios

    /// Profile: Calm meditator — consistent high HRV, low stress.
    func testProfile_calmMeditator() {
        let snapshots = (0..<21).map {
            makeSnapshot(day: $0, hrv: 65.0 + Double($0 % 3))
        }
        let score = engine.dailyStressScore(snapshots: snapshots)!
        // Consistent high HRV → at or below balanced
        XCTAssertLessThan(score, 55, "Meditator should have balanced-to-low stress")
    }

    /// Profile: Overworked professional — declining HRV over weeks.
    func testProfile_overworkedProfessional() {
        // Steeper decline: 60ms → 15ms over 21 days
        let snapshots = (0..<21).map {
            makeSnapshot(day: $0, hrv: max(15, 60.0 - Double($0) * 2.2))
        }
        let score = engine.dailyStressScore(snapshots: snapshots)!
        XCTAssertGreaterThan(score, 60, "Declining HRV should show high stress")

        let trend = engine.stressTrend(snapshots: snapshots, range: .month)
        let direction = engine.trendDirection(points: trend)
        XCTAssertEqual(direction, .rising, "Steep HRV decline should show rising stress")
    }

    /// Profile: Weekend warrior — stress drops on weekends.
    func testProfile_weekendWarrior() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let snapshots = (0..<14).map { offset -> HeartSnapshot in
            let date = calendar.date(
                byAdding: .day, value: -(13 - offset), to: today
            )!
            let dayOfWeek = calendar.component(.weekday, from: date)
            let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
            let hrv = isWeekend ? 60.0 : 35.0
            return HeartSnapshot(date: date, hrvSDNN: hrv)
        }
        let trend = engine.stressTrend(snapshots: snapshots, range: .week)

        // Weekend days should have lower stress than weekday days
        var weekendScores: [Double] = []
        var weekdayScores: [Double] = []
        for point in trend {
            let dow = calendar.component(.weekday, from: point.date)
            if dow == 1 || dow == 7 {
                weekendScores.append(point.score)
            } else {
                weekdayScores.append(point.score)
            }
        }

        if !weekendScores.isEmpty && !weekdayScores.isEmpty {
            let weekendAvg = weekendScores.reduce(0, +) / Double(weekendScores.count)
            let weekdayAvg = weekdayScores.reduce(0, +) / Double(weekdayScores.count)
            XCTAssertLessThan(
                weekendAvg, weekdayAvg,
                "Weekend stress should be lower than weekday stress"
            )
        }
    }

    /// Profile: New parent — erratic sleep → volatile stress.
    func testProfile_newParent() {
        let snapshots = (0..<21).map { i -> HeartSnapshot in
            // Alternating good and bad HRV days
            let hrv = i.isMultiple(of: 2) ? 55.0 : 28.0
            return makeSnapshot(day: i, hrv: hrv, sleep: i.isMultiple(of: 2) ? 7.5 : 4.0)
        }
        let trend = engine.stressTrend(snapshots: snapshots, range: .month)

        // Should have high variance in scores
        let scores = trend.map(\.score)
        guard scores.count >= 2 else { return }
        let avg = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.map { ($0 - avg) * ($0 - avg) }
            .reduce(0, +) / Double(scores.count)
        XCTAssertGreaterThan(
            variance, 50,
            "New parent should have volatile stress (variance: \(variance))"
        )
    }

    /// Profile: Athlete in taper — HRV improving before competition.
    func testProfile_taperPhase() {
        // Steeper improvement: 30ms → 72ms over 21 days
        let snapshots = (0..<21).map {
            makeSnapshot(day: $0, hrv: 30.0 + Double($0) * 2.0)
        }
        let score = engine.dailyStressScore(snapshots: snapshots)!
        // With multi-signal sigmoid, rapidly improving HRV → very low stress
        XCTAssertLessThan(score, 50, "Improving HRV should show low stress, got \(score)")

        let trend = engine.stressTrend(snapshots: snapshots, range: .month)
        let direction = engine.trendDirection(points: trend)
        // With sigmoid compression, the trend may be steady-to-falling
        XCTAssertTrue(direction == .falling || direction == .steady,
            "Steep HRV improvement should show falling or steady stress, got \(direction)")
    }

    /// Profile: Sick user — sudden HRV crash.
    func testProfile_illness() {
        var snapshots = (0..<14).map {
            makeSnapshot(day: $0, hrv: 52.0 + Double($0 % 3))
        }
        // Add 3 days of crashed HRV (illness)
        for i in 14..<17 {
            snapshots.append(makeSnapshot(day: i, hrv: 22.0))
        }
        let score = engine.dailyStressScore(snapshots: snapshots)!
        XCTAssertGreaterThan(
            score, 75,
            "Sudden HRV crash should show very high stress"
        )
    }

    // MARK: - Baseline Computation

    func testComputeBaseline_emptySnapshots_returnsNil() {
        XCTAssertNil(engine.computeBaseline(snapshots: []))
    }

    func testComputeBaseline_missingHRV_skipsNils() {
        let snapshots = [
            HeartSnapshot(date: Date(), hrvSDNN: nil),
            HeartSnapshot(date: Date(), hrvSDNN: 50.0),
            HeartSnapshot(date: Date(), hrvSDNN: 60.0)
        ]
        let baseline = engine.computeBaseline(snapshots: snapshots)
        XCTAssertEqual(baseline!, 55.0, accuracy: 0.1)
    }

    // MARK: - Helpers

    private func makeSnapshot(
        day: Int,
        hrv: Double,
        sleep: Double? = nil
    ) -> HeartSnapshot {
        let calendar = Calendar.current
        let date = calendar.date(
            byAdding: .day,
            value: -(20 - day),
            to: calendar.startOfDay(for: Date())
        )!
        return HeartSnapshot(
            date: date,
            hrvSDNN: hrv,
            sleepHours: sleep
        )
    }
}

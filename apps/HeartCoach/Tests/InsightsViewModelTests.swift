// InsightsViewModelTests.swift
// ThumpCoreTests
//
// Comprehensive tests for InsightsViewModel: weekly report generation,
// action plan building, trend direction computation, computed properties,
// empty state handling, and edge cases.

import XCTest
@testable import Thump

@MainActor
final class InsightsViewModelTests: XCTestCase {

    private var defaults: UserDefaults!
    private var localStore: LocalStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.thump.insights.\(UUID().uuidString)")!
        localStore = LocalStore(defaults: defaults)
    }

    override func tearDown() {
        defaults = nil
        localStore = nil
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSnapshot(
        daysAgo: Int,
        rhr: Double = 64.0,
        hrv: Double = 48.0,
        walkMin: Double? = 30.0,
        workoutMin: Double? = 20.0,
        sleepHours: Double? = 7.5,
        steps: Double? = 8000
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
            steps: steps,
            walkMinutes: walkMin,
            workoutMinutes: workoutMin,
            sleepHours: sleepHours
        )
    }

    private func makeHistory(days: Int) -> [HeartSnapshot] {
        (1...days).reversed().map { day in
            makeSnapshot(daysAgo: day, rhr: 60.0 + Double(day % 5), hrv: 40.0 + Double(day % 6))
        }
    }

    private func makeViewModel() -> InsightsViewModel {
        InsightsViewModel(localStore: localStore)
    }

    // MARK: - Initial State

    func testInitialState_isLoadingAndEmpty() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.correlations.isEmpty)
        XCTAssertNil(vm.weeklyReport)
        XCTAssertNil(vm.actionPlan)
    }

    // MARK: - Computed Properties

    func testHasInsights_falseWhenEmpty() {
        let vm = makeViewModel()
        vm.correlations = []
        vm.weeklyReport = nil
        XCTAssertFalse(vm.hasInsights)
    }

    func testHasInsights_trueWithCorrelations() {
        let vm = makeViewModel()
        vm.correlations = [
            CorrelationResult(
                factorName: "Steps",
                correlationStrength: -0.42,
                interpretation: "test",
                confidence: .medium
            )
        ]
        XCTAssertTrue(vm.hasInsights)
    }

    func testHasInsights_trueWithWeeklyReport() {
        let vm = makeViewModel()
        vm.weeklyReport = WeeklyReport(
            weekStart: Date(),
            weekEnd: Date(),
            avgCardioScore: 65,
            trendDirection: .flat,
            topInsight: "test",
            nudgeCompletionRate: 0.5
        )
        XCTAssertTrue(vm.hasInsights)
    }

    // MARK: - Sorted Correlations

    func testSortedCorrelations_orderedByAbsoluteStrength() {
        let vm = makeViewModel()
        vm.correlations = [
            CorrelationResult(factorName: "A", correlationStrength: 0.2, interpretation: "a", confidence: .low),
            CorrelationResult(factorName: "B", correlationStrength: -0.8, interpretation: "b", confidence: .high),
            CorrelationResult(factorName: "C", correlationStrength: 0.5, interpretation: "c", confidence: .medium)
        ]

        let sorted = vm.sortedCorrelations
        XCTAssertEqual(sorted[0].factorName, "B")
        XCTAssertEqual(sorted[1].factorName, "C")
        XCTAssertEqual(sorted[2].factorName, "A")
    }

    // MARK: - Significant Correlations

    func testSignificantCorrelations_filtersWeakOnes() {
        let vm = makeViewModel()
        vm.correlations = [
            CorrelationResult(factorName: "Weak", correlationStrength: 0.1, interpretation: "weak", confidence: .low),
            CorrelationResult(factorName: "Strong", correlationStrength: -0.5, interpretation: "strong", confidence: .high),
            CorrelationResult(factorName: "Borderline", correlationStrength: 0.3, interpretation: "border", confidence: .medium)
        ]

        let significant = vm.significantCorrelations
        XCTAssertEqual(significant.count, 2, "Should include |r| >= 0.3 only")
        XCTAssertTrue(significant.contains(where: { $0.factorName == "Strong" }))
        XCTAssertTrue(significant.contains(where: { $0.factorName == "Borderline" }))
    }

    // MARK: - Weekly Report Generation

    func testGenerateWeeklyReport_computesAverageCardioScore() {
        let vm = makeViewModel()
        let history = makeHistory(days: 7)
        let engine = ConfigService.makeDefaultEngine()

        var assessments: [HeartAssessment] = []
        for (index, snapshot) in history.enumerated() {
            let prior = Array(history.prefix(index))
            assessments.append(engine.assess(history: prior, current: snapshot, feedback: nil))
        }

        let report = vm.generateWeeklyReport(from: history, assessments: assessments)

        XCTAssertNotNil(report.avgCardioScore, "Should compute average cardio score")
        XCTAssertFalse(report.topInsight.isEmpty, "Should have a top insight")
    }

    func testGenerateWeeklyReport_weekBoundsMatchHistory() {
        let vm = makeViewModel()
        let history = makeHistory(days: 7)
        let engine = ConfigService.makeDefaultEngine()

        let assessments = history.map { snapshot in
            engine.assess(history: [], current: snapshot, feedback: nil)
        }

        let report = vm.generateWeeklyReport(from: history, assessments: assessments)

        XCTAssertEqual(
            Calendar.current.startOfDay(for: report.weekStart),
            Calendar.current.startOfDay(for: history.first!.date)
        )
        XCTAssertEqual(
            Calendar.current.startOfDay(for: report.weekEnd),
            Calendar.current.startOfDay(for: history.last!.date)
        )
    }

    // MARK: - Trend Direction

    func testGenerateWeeklyReport_flatTrend_whenFewScores() {
        let vm = makeViewModel()
        let history = makeHistory(days: 3)
        let engine = ConfigService.makeDefaultEngine()

        let assessments = history.map { snapshot in
            engine.assess(history: [], current: snapshot, feedback: nil)
        }

        let report = vm.generateWeeklyReport(from: history, assessments: assessments)
        // With < 4 scores, should default to flat
        XCTAssertEqual(report.trendDirection, .flat)
    }

    // MARK: - Nudge Completion Rate

    func testGenerateWeeklyReport_nudgeCompletionRate_zeroWithNoCompletions() {
        let vm = makeViewModel()
        let history = makeHistory(days: 7)
        let engine = ConfigService.makeDefaultEngine()

        let assessments = history.map { snapshot in
            engine.assess(history: [], current: snapshot, feedback: nil)
        }

        let report = vm.generateWeeklyReport(from: history, assessments: assessments)
        XCTAssertEqual(report.nudgeCompletionRate, 0.0, "Should be zero with no explicit completions")
    }

    func testGenerateWeeklyReport_nudgeCompletionRate_countsExplicitCompletions() {
        let vm = InsightsViewModel(localStore: localStore)

        // History includes daysAgo 1..7; mark daysAgo 1 as completed
        let history = makeHistory(days: 7)
        let engine = ConfigService.makeDefaultEngine()

        let calendar = Calendar.current
        let oneDayAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let dateKey = String(ISO8601DateFormatter().string(from: oneDayAgo).prefix(10))
        localStore.profile.nudgeCompletionDates.insert(dateKey)
        localStore.saveProfile()

        let assessments = history.map { snapshot in
            engine.assess(history: [], current: snapshot, feedback: nil)
        }

        let report = vm.generateWeeklyReport(from: history, assessments: assessments)
        XCTAssertGreaterThan(report.nudgeCompletionRate, 0.0, "Should count explicit completions")
        XCTAssertLessThanOrEqual(report.nudgeCompletionRate, 1.0, "Rate should not exceed 1.0")
    }

    // MARK: - Empty History

    func testGenerateWeeklyReport_emptyHistory_handlesGracefully() {
        let vm = makeViewModel()
        let report = vm.generateWeeklyReport(from: [], assessments: [])

        XCTAssertNil(report.avgCardioScore)
        XCTAssertEqual(report.trendDirection, .flat)
        XCTAssertEqual(report.nudgeCompletionRate, 0.0)
    }

    // MARK: - Bind

    func testBind_updatesInternalReferences() {
        let vm = makeViewModel()
        let newStore = LocalStore(defaults: UserDefaults(suiteName: "com.thump.insights.bind.\(UUID().uuidString)")!)
        let newService = HealthKitService()

        vm.bind(healthKitService: newService, localStore: newStore)
        // Verify doesn't crash and VM remains functional
        XCTAssertTrue(vm.correlations.isEmpty)
    }
}

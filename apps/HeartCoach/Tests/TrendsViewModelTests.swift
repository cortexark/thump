// TrendsViewModelTests.swift
// ThumpCoreTests
//
// Comprehensive tests for TrendsViewModel: metric extraction, stats
// computation, time range switching, empty state handling, and edge cases.

import XCTest
@testable import Thump

@MainActor
final class TrendsViewModelTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.thump.trends.\(UUID().uuidString)")
    }

    override func tearDown() {
        defaults = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSnapshot(
        daysAgo: Int,
        rhr: Double? = 64.0,
        hrv: Double? = 48.0,
        recovery1m: Double? = 25.0,
        vo2Max: Double? = 38.0,
        walkMin: Double? = 30.0,
        workoutMin: Double? = 20.0
    ) -> HeartSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return HeartSnapshot(
            date: date,
            restingHeartRate: rhr,
            hrvSDNN: hrv,
            recoveryHR1m: recovery1m,
            recoveryHR2m: 40.0,
            vo2Max: vo2Max,
            zoneMinutes: [110, 25, 12, 5, 1],
            steps: 8000,
            walkMinutes: walkMin,
            workoutMinutes: workoutMin,
            sleepHours: 7.5
        )
    }

    private func makeHistory(days: Int) -> [HeartSnapshot] {
        (1...days).reversed().map { day in
            makeSnapshot(daysAgo: day, rhr: 60.0 + Double(day % 5), hrv: 40.0 + Double(day % 6))
        }
    }

    private func makeViewModel(history: [HeartSnapshot]) -> TrendsViewModel {
        let vm = TrendsViewModel()
        vm.history = history
        return vm
    }

    // MARK: - Initial State

    func testInitialState_isNotLoadingAndNoError() {
        let vm = TrendsViewModel()
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.history.isEmpty)
        XCTAssertEqual(vm.selectedMetric, .restingHR)
        XCTAssertEqual(vm.timeRange, .week)
    }

    // MARK: - Metric Type Properties

    func testMetricType_unitStrings() {
        XCTAssertEqual(TrendsViewModel.MetricType.restingHR.unit, "bpm")
        XCTAssertEqual(TrendsViewModel.MetricType.hrv.unit, "ms")
        XCTAssertEqual(TrendsViewModel.MetricType.recovery.unit, "bpm")
        XCTAssertEqual(TrendsViewModel.MetricType.vo2Max.unit, "mL/kg/min")
        XCTAssertEqual(TrendsViewModel.MetricType.activeMinutes.unit, "min")
    }

    func testMetricType_icons() {
        XCTAssertEqual(TrendsViewModel.MetricType.restingHR.icon, "heart.fill")
        XCTAssertEqual(TrendsViewModel.MetricType.hrv.icon, "waveform.path.ecg")
        XCTAssertEqual(TrendsViewModel.MetricType.recovery.icon, "arrow.down.heart.fill")
        XCTAssertEqual(TrendsViewModel.MetricType.vo2Max.icon, "lungs.fill")
        XCTAssertEqual(TrendsViewModel.MetricType.activeMinutes.icon, "figure.run")
    }

    // MARK: - Time Range Properties

    func testTimeRange_labels() {
        XCTAssertEqual(TrendsViewModel.TimeRange.week.label, "7 Days")
        XCTAssertEqual(TrendsViewModel.TimeRange.twoWeeks.label, "14 Days")
        XCTAssertEqual(TrendsViewModel.TimeRange.month.label, "30 Days")
    }

    func testTimeRange_rawValues() {
        XCTAssertEqual(TrendsViewModel.TimeRange.week.rawValue, 7)
        XCTAssertEqual(TrendsViewModel.TimeRange.twoWeeks.rawValue, 14)
        XCTAssertEqual(TrendsViewModel.TimeRange.month.rawValue, 30)
    }

    // MARK: - Data Points Extraction

    func testDataPoints_restingHR_extractsCorrectValues() {
        let history = [
            makeSnapshot(daysAgo: 2, rhr: 62.0),
            makeSnapshot(daysAgo: 1, rhr: 65.0),
            makeSnapshot(daysAgo: 0, rhr: 60.0)
        ]
        let vm = makeViewModel(history: history)

        let points = vm.dataPoints(for: .restingHR)
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].value, 62.0)
        XCTAssertEqual(points[1].value, 65.0)
        XCTAssertEqual(points[2].value, 60.0)
    }

    func testDataPoints_hrv_extractsCorrectValues() {
        let history = [
            makeSnapshot(daysAgo: 1, hrv: 45.0),
            makeSnapshot(daysAgo: 0, hrv: 52.0)
        ]
        let vm = makeViewModel(history: history)

        let points = vm.dataPoints(for: .hrv)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].value, 45.0)
        XCTAssertEqual(points[1].value, 52.0)
    }

    func testDataPoints_recovery_extractsRecovery1m() {
        let history = [
            makeSnapshot(daysAgo: 0, recovery1m: 30.0)
        ]
        let vm = makeViewModel(history: history)

        let points = vm.dataPoints(for: .recovery)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 30.0)
    }

    func testDataPoints_vo2Max_extractsCorrectValues() {
        let history = [
            makeSnapshot(daysAgo: 0, vo2Max: 42.0)
        ]
        let vm = makeViewModel(history: history)

        let points = vm.dataPoints(for: .vo2Max)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 42.0)
    }

    func testDataPoints_activeMinutes_sumsWalkAndWorkout() {
        let history = [
            makeSnapshot(daysAgo: 0, walkMin: 20.0, workoutMin: 15.0)
        ]
        let vm = makeViewModel(history: history)

        let points = vm.dataPoints(for: .activeMinutes)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].value, 35.0)
    }

    func testDataPoints_activeMinutes_zeroTotalExcluded() {
        let history = [
            makeSnapshot(daysAgo: 0, walkMin: nil, workoutMin: nil)
        ]
        let vm = makeViewModel(history: history)

        // Walk=nil, workout=nil -> both default to 0 -> total 0 -> excluded
        let points = vm.dataPoints(for: .activeMinutes)
        XCTAssertEqual(points.count, 0)
    }

    // MARK: - Nil Value Handling

    func testDataPoints_skipsNilValues() {
        let history = [
            makeSnapshot(daysAgo: 2, rhr: 62.0),
            makeSnapshot(daysAgo: 1, rhr: nil),
            makeSnapshot(daysAgo: 0, rhr: 60.0)
        ]
        let vm = makeViewModel(history: history)

        let points = vm.dataPoints(for: .restingHR)
        XCTAssertEqual(points.count, 2, "Should skip the nil RHR day")
    }

    func testDataPoints_allNil_returnsEmpty() {
        let history = [
            makeSnapshot(daysAgo: 1, hrv: nil),
            makeSnapshot(daysAgo: 0, hrv: nil)
        ]
        let vm = makeViewModel(history: history)

        let points = vm.dataPoints(for: .hrv)
        XCTAssertTrue(points.isEmpty)
    }

    // MARK: - Empty State

    func testDataPoints_emptyHistory_returnsEmpty() {
        let vm = makeViewModel(history: [])
        let points = vm.dataPoints(for: .restingHR)
        XCTAssertTrue(points.isEmpty)
    }

    func testCurrentStats_emptyHistory_returnsNil() {
        let vm = makeViewModel(history: [])
        XCTAssertNil(vm.currentStats)
    }

    // MARK: - Current Data Points

    func testCurrentDataPoints_usesSelectedMetric() {
        let history = [
            makeSnapshot(daysAgo: 0, rhr: 64.0, hrv: 50.0)
        ]
        let vm = makeViewModel(history: history)

        vm.selectedMetric = .restingHR
        XCTAssertEqual(vm.currentDataPoints.first?.value, 64.0)

        vm.selectedMetric = .hrv
        XCTAssertEqual(vm.currentDataPoints.first?.value, 50.0)
    }

    // MARK: - Stats Computation

    func testCurrentStats_computesAverageMinMax() {
        let history = [
            makeSnapshot(daysAgo: 3, rhr: 60.0),
            makeSnapshot(daysAgo: 2, rhr: 70.0),
            makeSnapshot(daysAgo: 1, rhr: 65.0),
            makeSnapshot(daysAgo: 0, rhr: 75.0)
        ]
        let vm = makeViewModel(history: history)
        vm.selectedMetric = .restingHR

        let stats = vm.currentStats
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.average, 67.5)
        XCTAssertEqual(stats?.minimum, 60.0)
        XCTAssertEqual(stats?.maximum, 75.0)
    }

    func testCurrentStats_singleDataPoint_returnsFlat() {
        let history = [makeSnapshot(daysAgo: 0, rhr: 65.0)]
        let vm = makeViewModel(history: history)
        vm.selectedMetric = .restingHR

        let stats = vm.currentStats
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.trend, .flat, "Single data point should be flat trend")
    }

    func testCurrentStats_risingRHR_isWorsening() {
        // For resting HR, higher = worse
        let history = [
            makeSnapshot(daysAgo: 3, rhr: 58.0),
            makeSnapshot(daysAgo: 2, rhr: 59.0),
            makeSnapshot(daysAgo: 1, rhr: 68.0),
            makeSnapshot(daysAgo: 0, rhr: 70.0)
        ]
        let vm = makeViewModel(history: history)
        vm.selectedMetric = .restingHR

        let stats = vm.currentStats
        XCTAssertEqual(stats?.trend, .worsening, "Rising RHR should be worsening")
    }

    func testCurrentStats_fallingRHR_isImproving() {
        // For resting HR, lower = better
        let history = [
            makeSnapshot(daysAgo: 3, rhr: 72.0),
            makeSnapshot(daysAgo: 2, rhr: 70.0),
            makeSnapshot(daysAgo: 1, rhr: 60.0),
            makeSnapshot(daysAgo: 0, rhr: 58.0)
        ]
        let vm = makeViewModel(history: history)
        vm.selectedMetric = .restingHR

        let stats = vm.currentStats
        XCTAssertEqual(stats?.trend, .improving, "Falling RHR should be improving")
    }

    func testCurrentStats_risingHRV_isImproving() {
        // For HRV, higher = better
        let history = [
            makeSnapshot(daysAgo: 3, hrv: 30.0),
            makeSnapshot(daysAgo: 2, hrv: 32.0),
            makeSnapshot(daysAgo: 1, hrv: 48.0),
            makeSnapshot(daysAgo: 0, hrv: 55.0)
        ]
        let vm = makeViewModel(history: history)
        vm.selectedMetric = .hrv

        let stats = vm.currentStats
        XCTAssertEqual(stats?.trend, .improving, "Rising HRV should be improving")
    }

    func testCurrentStats_stableValues_isFlat() {
        let history = [
            makeSnapshot(daysAgo: 3, rhr: 65.0),
            makeSnapshot(daysAgo: 2, rhr: 65.0),
            makeSnapshot(daysAgo: 1, rhr: 65.0),
            makeSnapshot(daysAgo: 0, rhr: 65.0)
        ]
        let vm = makeViewModel(history: history)
        vm.selectedMetric = .restingHR

        let stats = vm.currentStats
        XCTAssertEqual(stats?.trend, .flat)
    }

    // MARK: - MetricTrend Labels and Icons

    func testMetricTrend_labelsAndIcons() {
        XCTAssertEqual(TrendsViewModel.MetricTrend.improving.label, "Building Momentum")
        XCTAssertEqual(TrendsViewModel.MetricTrend.flat.label, "Holding Steady")
        XCTAssertEqual(TrendsViewModel.MetricTrend.worsening.label, "Worth Watching")

        XCTAssertEqual(TrendsViewModel.MetricTrend.improving.icon, "arrow.up.right")
        XCTAssertEqual(TrendsViewModel.MetricTrend.flat.icon, "arrow.right")
        XCTAssertEqual(TrendsViewModel.MetricTrend.worsening.icon, "arrow.down.right")
    }

    // MARK: - Metric Switching

    func testMetricSwitching_changesCurrentDataPoints() {
        let history = [
            makeSnapshot(daysAgo: 0, rhr: 64.0, hrv: 50.0, vo2Max: 38.0)
        ]
        let vm = makeViewModel(history: history)

        vm.selectedMetric = .restingHR
        XCTAssertEqual(vm.currentDataPoints.count, 1)

        vm.selectedMetric = .vo2Max
        XCTAssertEqual(vm.currentDataPoints.first?.value, 38.0)
    }

    // MARK: - All Metric Types CaseIterable

    func testAllMetricTypes_areIterable() {
        let allTypes = TrendsViewModel.MetricType.allCases
        XCTAssertEqual(allTypes.count, 5)
        XCTAssertTrue(allTypes.contains(.restingHR))
        XCTAssertTrue(allTypes.contains(.hrv))
        XCTAssertTrue(allTypes.contains(.recovery))
        XCTAssertTrue(allTypes.contains(.vo2Max))
        XCTAssertTrue(allTypes.contains(.activeMinutes))
    }

    func testAllTimeRanges_areIterable() {
        let allRanges = TrendsViewModel.TimeRange.allCases
        XCTAssertEqual(allRanges.count, 3)
    }

    // MARK: - Bind Method

    func testBind_updatesHealthKitService() {
        let vm = TrendsViewModel()
        let newService = HealthKitService()
        vm.bind(healthKitService: newService)
        // The bind method should not crash and should update the internal reference
        // We verify it by ensuring the VM still functions
        XCTAssertTrue(vm.history.isEmpty)
    }
}

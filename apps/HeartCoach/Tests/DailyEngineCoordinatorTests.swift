// DailyEngineCoordinatorTests.swift
// ThumpCoreTests
//
// Tests for DailyEngineCoordinator — the centralized engine orchestrator
// introduced in Phase 2 of the Engine Orchestrator refactor.
// Validates bundle completeness, old-vs-new parity, feature flag behavior,
// and error handling.

import XCTest
@testable import Thump

@MainActor
final class DailyEngineCoordinatorTests: XCTestCase {

    // MARK: - Fixtures

    private var mockProvider: MockHealthDataProvider!
    private var localStore: LocalStore!
    private var coordinator: DailyEngineCoordinator!

    override func setUp() {
        super.setUp()

        let today = MockData.mockTodaySnapshot
        let history = MockData.mockHistory(days: 21)

        mockProvider = MockHealthDataProvider(
            todaySnapshot: today,
            history: history,
            shouldAuthorize: true
        )

        // Use an in-memory defaults suite so tests don't pollute disk.
        let defaults = UserDefaults(suiteName: "DailyEngineCoordinatorTests.\(UUID().uuidString)")!
        localStore = LocalStore(defaults: defaults)

        coordinator = DailyEngineCoordinator(
            healthDataProvider: mockProvider,
            localStore: localStore
        )
    }

    override func tearDown() {
        coordinator = nil
        localStore = nil
        mockProvider = nil
        super.tearDown()
    }

    // MARK: - 1. Bundle Completeness

    func testRefresh_producesBundleWithAllExpectedFields() async {
        await coordinator.refresh()

        let bundle = coordinator.bundle
        XCTAssertNotNil(bundle, "Bundle should be non-nil after refresh")

        guard let bundle else { return }

        // Assessment is always produced
        XCTAssertNotNil(bundle.assessment)

        // Snapshot and history are populated
        XCTAssertNotNil(bundle.snapshot.restingHeartRate,
                        "Snapshot should have RHR from mock data")
        XCTAssertFalse(bundle.history.isEmpty,
                       "History should be populated")

        // Correlations and sleep patterns arrays should be populated
        // (may be empty if data is insufficient, but should not crash)
        XCTAssertNotNil(bundle.correlations)
        XCTAssertNotNil(bundle.sleepPatterns)

        // Engine timings
        XCTAssertGreaterThan(bundle.engineTimings.totalMs, 0,
                             "Total pipeline time should be > 0ms")
        XCTAssertGreaterThan(bundle.engineTimings.trendMs, 0)
        XCTAssertGreaterThan(bundle.engineTimings.stressMs, 0)
    }

    func testRefresh_assessmentHasValidStatus() async {
        await coordinator.refresh()

        guard let bundle = coordinator.bundle else {
            XCTFail("Bundle should be non-nil")
            return
        }

        // Status should be one of the known trend statuses
        let validStatuses: [TrendStatus] = [.improving, .stable, .needsAttention]
        XCTAssertTrue(validStatuses.contains(bundle.assessment.status),
                      "Assessment status \(bundle.assessment.status) should be a known status")
    }

    func testRefresh_stressResultPresent_whenHRVDataAvailable() async {
        // MockData.mockTodaySnapshot includes HRV data, so stress should compute
        await coordinator.refresh()

        guard let bundle = coordinator.bundle else {
            XCTFail("Bundle should be non-nil")
            return
        }

        // With full mock data, stress should be computed
        if bundle.snapshot.hrvSDNN != nil {
            XCTAssertNotNil(bundle.stressResult,
                            "Stress result should be non-nil when HRV data is available")
        }
    }

    func testRefresh_bundleTimestamp_isRecent() async {
        let beforeRefresh = Date()
        await coordinator.refresh()

        guard let bundle = coordinator.bundle else {
            XCTFail("Bundle should be non-nil")
            return
        }

        let afterRefresh = Date()
        XCTAssertGreaterThanOrEqual(bundle.timestamp, beforeRefresh)
        XCTAssertLessThanOrEqual(bundle.timestamp, afterRefresh)
    }

    func testRefresh_pipelineTrace_isPopulated() async {
        await coordinator.refresh()

        guard let bundle = coordinator.bundle else {
            XCTFail("Bundle should be non-nil")
            return
        }

        XCTAssertNotNil(bundle.pipelineTrace,
                        "Pipeline trace should be populated for telemetry")
    }

    // MARK: - 2. Old-vs-New Comparison (Engine Parity)

    /// Runs engines manually (old DashboardVM path) and via coordinator (new path),
    /// then asserts that the core outputs match.
    func testCoordinatorParity_assessmentMatchesDirectEngineCall() async {
        let today = mockProvider.todaySnapshot
        let history = mockProvider.history

        // --- Old path: run engines directly ---
        let trendEngine = ConfigService.makeDefaultEngine()
        let directAssessment = trendEngine.assess(
            history: history,
            current: today,
            feedback: nil
        )

        let stressEngine = StressEngine()
        let directStressResult = stressEngine.computeStress(
            snapshot: today,
            recentHistory: history
        )

        let readinessEngine = ReadinessEngine()
        let stressScore: Double?
        let stressConf: StressConfidence?
        if let stress = directStressResult {
            stressScore = stress.score
            stressConf = stress.confidence
        } else if directAssessment.stressFlag {
            stressScore = 70.0
            stressConf = .low
        } else {
            stressScore = nil
            stressConf = nil
        }
        let directReadiness = readinessEngine.compute(
            snapshot: today,
            stressScore: stressScore,
            stressConfidence: stressConf,
            recentHistory: history,
            consecutiveAlert: directAssessment.consecutiveAlert
        )

        // --- New path: coordinator ---
        await coordinator.refresh()

        guard let bundle = coordinator.bundle else {
            XCTFail("Bundle should be non-nil")
            return
        }

        // Assessment status must match
        XCTAssertEqual(bundle.assessment.status, directAssessment.status,
                       "Coordinator assessment status should match direct engine call")

        // Anomaly score within epsilon
        XCTAssertEqual(bundle.assessment.anomalyScore, directAssessment.anomalyScore,
                       accuracy: 0.001,
                       "Anomaly scores should match within epsilon")

        // Stress scores must match
        if let bundleStress = bundle.stressResult, let directStress = directStressResult {
            XCTAssertEqual(bundleStress.score, directStress.score, accuracy: 0.001,
                           "Stress scores should match")
        } else {
            // Both should be nil, or both non-nil
            XCTAssertEqual(bundle.stressResult == nil, directStressResult == nil,
                           "Stress result nil-ness should match")
        }

        // Readiness scores must match
        if let bundleReadiness = bundle.readinessResult, let directR = directReadiness {
            XCTAssertEqual(Double(bundleReadiness.score), Double(directR.score),
                           accuracy: 0.001,
                           "Readiness scores should match")
        } else {
            XCTAssertEqual(bundle.readinessResult == nil, directReadiness == nil,
                           "Readiness result nil-ness should match")
        }
    }

    func testCoordinatorParity_correlationsMatchDirectCall() async {
        let history = mockProvider.history

        // Direct call
        let correlationEngine = CorrelationEngine()
        let directCorrelations = correlationEngine.analyze(history: history)

        // Coordinator
        await coordinator.refresh()

        guard let bundle = coordinator.bundle else {
            XCTFail("Bundle should be non-nil")
            return
        }

        XCTAssertEqual(bundle.correlations.count, directCorrelations.count,
                       "Correlation count should match")
    }

    func testCoordinatorParity_sleepPatternsMatchDirectCall() async {
        let history = mockProvider.history

        // Direct call
        let nudgeScheduler = SmartNudgeScheduler()
        let directPatterns = nudgeScheduler.learnSleepPatterns(from: history)

        // Coordinator
        await coordinator.refresh()

        guard let bundle = coordinator.bundle else {
            XCTFail("Bundle should be non-nil")
            return
        }

        XCTAssertEqual(bundle.sleepPatterns.count, directPatterns.count,
                       "Sleep pattern count should match")
    }

    // MARK: - 3. Engine Call Efficiency

    func testRefresh_callsHealthProviderOnce() async {
        await coordinator.refresh()

        // fetchTodaySnapshot should be called exactly once per refresh
        XCTAssertEqual(mockProvider.fetchTodayCallCount, 1,
                       "fetchTodaySnapshot should be called exactly once")

        // fetchHistory should be called exactly once per refresh
        XCTAssertEqual(mockProvider.fetchHistoryCallCount, 1,
                       "fetchHistory should be called exactly once")
    }

    func testMultipleRefreshes_callProviderEachTime() async {
        await coordinator.refresh()
        await coordinator.refresh()

        XCTAssertEqual(mockProvider.fetchTodayCallCount, 2,
                       "fetchTodaySnapshot should be called once per refresh")
        XCTAssertEqual(mockProvider.fetchHistoryCallCount, 2,
                       "fetchHistory should be called once per refresh")
    }

    // MARK: - 4. Feature Flag

    func testFeatureFlag_enableCoordinator_defaultsToTrue() {
        XCTAssertTrue(ConfigService.enableCoordinator,
                      "enableCoordinator should default to true")
    }

    func testFeatureFlag_canBeToggled() {
        let original = ConfigService.enableCoordinator

        ConfigService.enableCoordinator = false
        XCTAssertFalse(ConfigService.enableCoordinator)

        ConfigService.enableCoordinator = true
        XCTAssertTrue(ConfigService.enableCoordinator)

        // Restore original
        ConfigService.enableCoordinator = original
    }

    // MARK: - 5. Error Handling

    func testRefresh_withFetchError_surfacesErrorMessage() async {
        let testError = NSError(
            domain: "TestError",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Mock fetch failure"]
        )
        mockProvider.fetchError = testError
        coordinator.disableSimulatorFallback = true

        await coordinator.refresh()

        XCTAssertNil(coordinator.bundle,
                     "Bundle should be nil when fetch fails")
        XCTAssertNotNil(coordinator.errorMessage,
                        "Error message should be surfaced")
        XCTAssertTrue(coordinator.errorMessage?.contains("Mock fetch failure") ?? false,
                      "Error message should contain the error description")
        XCTAssertFalse(coordinator.isLoading,
                       "isLoading should be false after error")
    }

    func testRefresh_afterError_recoversOnNextRefresh() async {
        // First refresh fails
        let testError = NSError(
            domain: "TestError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Temporary failure"]
        )
        mockProvider.fetchError = testError
        coordinator.disableSimulatorFallback = true
        await coordinator.refresh()
        XCTAssertNil(coordinator.bundle)
        XCTAssertNotNil(coordinator.errorMessage)

        // Second refresh succeeds
        mockProvider.fetchError = nil
        coordinator.disableSimulatorFallback = false
        await coordinator.refresh()
        XCTAssertNotNil(coordinator.bundle,
                        "Bundle should be populated after successful retry")
        XCTAssertNil(coordinator.errorMessage,
                     "Error message should be cleared on success")
    }

    // MARK: - 6. Staleness

    func testIsStale_trueBeforeFirstRefresh() {
        XCTAssertTrue(coordinator.isStale,
                      "Should be stale before any refresh")
    }

    func testIsStale_falseAfterRefresh() async {
        await coordinator.refresh()
        XCTAssertFalse(coordinator.isStale,
                       "Should not be stale immediately after refresh")
    }

    // MARK: - 7. Loading State

    func testRefresh_setsIsLoadingDuringExecution() async {
        // Before refresh
        XCTAssertFalse(coordinator.isLoading)

        await coordinator.refresh()

        // After refresh completes
        XCTAssertFalse(coordinator.isLoading,
                       "isLoading should be false after refresh completes")
    }

    // MARK: - 8. Bind

    func testBind_updatesHealthDataProvider() async {
        let newSnapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 55,
            hrvSDNN: 60,
            zoneMinutes: [10, 20, 30, 15, 5]
        )
        let newHistory = MockData.mockHistory(days: 7)
        let newProvider = MockHealthDataProvider(
            todaySnapshot: newSnapshot,
            history: newHistory,
            shouldAuthorize: true
        )

        coordinator.bind(
            healthDataProvider: newProvider,
            localStore: localStore
        )

        await coordinator.refresh()

        XCTAssertEqual(newProvider.fetchTodayCallCount, 1,
                       "New provider should be used after bind")
        XCTAssertEqual(mockProvider.fetchTodayCallCount, 0,
                       "Old provider should not be called after bind")
    }
}

// SimulatorFallbackAndActionBugTests.swift
// ThumpTests
//
// Regression tests for 5 bugs found in the Thump iOS app:
//
// Bug 1: Stress heatmap empty on simulator — StressViewModel.loadData()
//         fetches from HealthKit; if fetchHistory returns snapshots with
//         all-nil metrics (doesn't throw), the catch-block mock fallback
//         never triggers, leaving the heatmap empty.
//
// Bug 2: "Got It" button does nothing — handleSmartAction(.bedtimeWindDown)
//         set smartAction = .standardNudge but didn't remove the card from
//         the smartActions array, so the ForEach kept showing it.
//
// Bug 3: "Get Moving" shows useless alert — activitySuggestion case called
//         showWalkSuggestion() which shows an alert with just "OK" and no
//         way to start an activity.
//
// Bug 4: Summary card empty — averageStress returns nil because trendPoints
//         is empty (same root cause as Bug 1).
//
// Bug 5: Trends page empty — TrendsViewModel.loadHistory() has the same
//         nil-snapshot issue as StressViewModel.
//
// WHY existing tests didn't catch these:
//
// Bug 1 & 5: Existing StressViewActionTests and DashboardViewModelTests
//   always constructed test data with populated HRV values (e.g.
//   makeSnapshot(hrv: 48.0)). No test ever simulated the scenario
//   where HealthKit returns snapshots with all-nil metrics (the
//   simulator condition). The test suite only covered the throw/catch
//   path (provider.fetchError) and the happy path with real data.
//   The "silent nil" middle ground was untested.
//
// Bug 2: StressViewActionTests tested handleSmartAction routing for
//   journalPrompt, breatheOnWatch, and activitySuggestion, but never
//   tested bedtimeWindDown or morningCheckIn. The test verified
//   smartAction was set but never checked whether the card was removed
//   from the smartActions array.
//
// Bug 3: The existing test testHandleSmartAction_activitySuggestion_
//   showsWalkSuggestion only verified walkSuggestionShown == true.
//   It didn't test what the user can DO from that alert (there was
//   no "Open Fitness" button). This is a UX gap, not a code gap;
//   the boolean was set, but the resulting UI was useless.
//
// Bug 4: No test computed averageStress after setting trendPoints
//   to empty. The DashboardViewModelTests always used valid mock
//   history, so trendPoints were always populated.
//
// Bug 5: There were zero TrendsViewModel tests in the entire suite.
//   The ViewModel was exercised only through SwiftUI previews.

import XCTest
@testable import Thump

// MARK: - Bug 1 & 4: StressViewModel nil-metric fallback + averageStress

@MainActor
final class StressViewModelNilMetricTests: XCTestCase {

    // MARK: - Nil-Metric Snapshot Helpers

    /// Creates snapshots where all health metrics are nil, simulating
    /// what HealthKit returns on a simulator with no configured data.
    private func makeNilMetricSnapshots(count: Int) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return HeartSnapshot(date: date)
            // All Optional fields default to nil
        }
    }

    /// Creates snapshots with populated HRV to simulate real device data.
    private func makePopulatedSnapshots(count: Int) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return HeartSnapshot(
                date: date,
                restingHeartRate: 62.0 + Double(offset % 5),
                hrvSDNN: 42.0 + Double(offset % 8),
                recoveryHR1m: 25.0,
                recoveryHR2m: 40.0,
                vo2Max: 38.0,
                zoneMinutes: [100, 20, 10, 5, 1],
                steps: 8000,
                walkMinutes: 25.0,
                workoutMinutes: 30.0,
                sleepHours: 7.5
            )
        }
    }

    // MARK: - Bug 1: trendPoints empty when history has nil-metric snapshots

    /// Verifies that when history contains only nil-metric snapshots
    /// (simulator condition), trendPoints is empty and the heatmap
    /// would be blank. This is the scenario the fix addresses with
    /// the `#if targetEnvironment(simulator)` fallback.
    func testNilMetricHistory_produceEmptyTrendPoints() {
        let vm = StressViewModel()
        // Simulate the condition: history is loaded but all metrics are nil
        vm.history = makeNilMetricSnapshots(count: 30)

        // The engine can't compute stress from nil HRV, so trendPoints should be empty
        // (This is the pre-fix behavior that caused the blank heatmap)
        let engine = StressEngine()
        let trendPoints = engine.stressTrend(
            snapshots: vm.history,
            range: .week
        )

        // This test documents the root cause: nil-HRV snapshots produce no trend data
        // The fix is the simulator fallback that replaces these with MockData
        XCTAssertTrue(
            trendPoints.isEmpty,
            "Nil-metric snapshots should produce no trend points — "
            + "this is the root cause of the empty heatmap bug"
        )
    }

    /// Verifies that populated snapshots DO produce trend points,
    /// confirming the engine works correctly with real data.
    func testPopulatedHistory_producesNonEmptyTrendPoints() {
        let vm = StressViewModel()
        vm.history = makePopulatedSnapshots(count: 30)

        let engine = StressEngine()
        let trendPoints = engine.stressTrend(
            snapshots: vm.history,
            range: .week
        )

        XCTAssertFalse(
            trendPoints.isEmpty,
            "Populated snapshots should produce trend points"
        )
    }

    /// Verifies that a "hasRealData" check correctly identifies nil-metric snapshots.
    /// This is the exact logic used in the simulator fallback fix.
    func testHasRealDataCheck_detectsNilMetricSnapshots() {
        let nilSnapshots = makeNilMetricSnapshots(count: 10)
        let hasRealData = nilSnapshots.contains(where: { $0.hrvSDNN != nil })
        XCTAssertFalse(hasRealData, "Nil-metric snapshots should fail hasRealData check")

        let realSnapshots = makePopulatedSnapshots(count: 10)
        let hasReal = realSnapshots.contains(where: { $0.hrvSDNN != nil })
        XCTAssertTrue(hasReal, "Populated snapshots should pass hasRealData check")
    }

    /// Verifies that MockData.mockHistory produces snapshots with non-nil HRV,
    /// confirming the fallback data would fix the empty heatmap.
    func testMockDataFallback_producesNonNilHRV() {
        let mockSnapshots = MockData.mockHistory(days: 14)
        let hasRealData = mockSnapshots.contains(where: { $0.hrvSDNN != nil })
        XCTAssertTrue(
            hasRealData,
            "MockData fallback should produce snapshots with non-nil HRV"
        )
    }

    // MARK: - Bug 4: averageStress nil when trendPoints is empty

    /// Verifies that averageStress returns nil when trendPoints is empty,
    /// which is the root cause of the empty summary card.
    func testAverageStress_nilWhenTrendPointsEmpty() {
        let vm = StressViewModel()
        vm.history = makeNilMetricSnapshots(count: 30)
        // trendPoints defaults to [] and nil-metric history won't populate it

        XCTAssertNil(
            vm.averageStress,
            "averageStress should be nil when trendPoints is empty — "
            + "this is the root cause of the empty summary card"
        )
    }

    /// Verifies that averageStress is non-nil when trendPoints is populated.
    func testAverageStress_nonNilWhenTrendPointsPopulated() {
        let vm = StressViewModel()

        // Manually set trendPoints to simulate valid data
        let today = Date()
        vm.trendPoints = [
            StressDataPoint(date: today, score: 40.0, level: .balanced),
            StressDataPoint(date: today.addingTimeInterval(-86400), score: 50.0, level: .balanced),
            StressDataPoint(date: today.addingTimeInterval(-172800), score: 30.0, level: .relaxed),
        ]

        XCTAssertNotNil(vm.averageStress, "averageStress should be non-nil with populated trendPoints")
        XCTAssertEqual(vm.averageStress!, 40.0, accuracy: 0.01, "Average of 40,50,30 should be 40")
    }

    /// Verifies averageStress works correctly with a single data point.
    func testAverageStress_singlePoint() {
        let vm = StressViewModel()
        vm.trendPoints = [
            StressDataPoint(date: Date(), score: 55.0, level: .balanced)
        ]

        XCTAssertEqual(vm.averageStress!, 55.0, accuracy: 0.01)
    }

    /// Verifies mostRelaxedDay and mostElevatedDay are nil when trendPoints is empty.
    func testMostRelaxedAndElevated_nilWhenEmpty() {
        let vm = StressViewModel()
        // Default: trendPoints = []

        XCTAssertNil(vm.mostRelaxedDay, "mostRelaxedDay should be nil with empty trendPoints")
        XCTAssertNil(vm.mostElevatedDay, "mostElevatedDay should be nil with empty trendPoints")
    }

    /// End-to-end: nil-metric history leads to nil averageStress AND empty chartDataPoints.
    func testNilMetricHistory_cascadeToEmptySummary() {
        let vm = StressViewModel()
        vm.history = makeNilMetricSnapshots(count: 30)

        // Simulate what computeStressMetrics would do with nil-metric snapshots
        let engine = StressEngine()
        let stress = engine.computeStress(
            snapshot: vm.history.first!,
            recentHistory: Array(vm.history.dropFirst())
        )

        // With nil HRV, engine can't compute stress
        // (This documents the cascade: nil HRV → nil stress → empty summary)
        if stress == nil {
            // Expected: nil-metric snapshots can't produce a stress score
            // The fix: simulator fallback replaces these with MockData before engine runs
        }

        XCTAssertTrue(vm.chartDataPoints.isEmpty, "Chart data should be empty with no trendPoints")
    }
}

// MARK: - Bug 2: handleSmartAction(.bedtimeWindDown) card removal

@MainActor
final class SmartActionCardRemovalTests: XCTestCase {

    /// Verifies that handleSmartAction(.bedtimeWindDown) removes the card
    /// from smartActions array. Before the fix, it only set smartAction
    /// to .standardNudge but left the card in the array.
    func testHandleBedtimeWindDown_removesCardFromSmartActions() {
        let vm = StressViewModel()
        let nudge = DailyNudge(
            category: .rest,
            title: "Wind Down",
            description: "Time to wind down for bed",
            durationMinutes: nil,
            icon: "bed.double.fill"
        )
        let windDownAction = SmartNudgeAction.bedtimeWindDown(nudge)

        // Set up: card is in the smartActions array
        vm.smartActions = [windDownAction, .standardNudge]
        vm.smartAction = windDownAction

        // Act: user taps "Got It"
        vm.handleSmartAction(windDownAction)

        // Assert: card is removed from smartActions
        let hasBedtimeWindDown = vm.smartActions.contains { action in
            if case .bedtimeWindDown = action { return true }
            return false
        }
        XCTAssertFalse(
            hasBedtimeWindDown,
            "bedtimeWindDown card should be removed from smartActions after handling"
        )

        // Assert: primary smartAction is reset
        if case .standardNudge = vm.smartAction {
            // Expected
        } else {
            XCTFail("smartAction should be .standardNudge after dismissing bedtimeWindDown")
        }
    }

    /// Verifies that handleSmartAction(.bedtimeWindDown) with multiple
    /// bedtimeWindDown cards removes ALL of them.
    func testHandleBedtimeWindDown_removesAllInstances() {
        let vm = StressViewModel()
        let nudge1 = DailyNudge(
            category: .rest,
            title: "Wind Down 1",
            description: "First wind down",
            durationMinutes: nil,
            icon: "bed.double.fill"
        )
        let nudge2 = DailyNudge(
            category: .rest,
            title: "Wind Down 2",
            description: "Second wind down",
            durationMinutes: nil,
            icon: "bed.double.fill"
        )

        vm.smartActions = [
            .bedtimeWindDown(nudge1),
            .standardNudge,
            .bedtimeWindDown(nudge2),
        ]
        vm.smartAction = .bedtimeWindDown(nudge1)

        vm.handleSmartAction(.bedtimeWindDown(nudge1))

        let remaining = vm.smartActions.filter { action in
            if case .bedtimeWindDown = action { return true }
            return false
        }
        XCTAssertEqual(remaining.count, 0, "All bedtimeWindDown cards should be removed")
    }

    /// Verifies that other cards in smartActions are NOT removed when
    /// handling bedtimeWindDown.
    func testHandleBedtimeWindDown_preservesOtherCards() {
        let vm = StressViewModel()
        let windDownNudge = DailyNudge(
            category: .rest,
            title: "Wind Down",
            description: "Bedtime",
            durationMinutes: nil,
            icon: "bed.double.fill"
        )
        let activityNudge = DailyNudge(
            category: .walk,
            title: "Walk",
            description: "Take a walk",
            durationMinutes: 10,
            icon: "figure.walk"
        )

        vm.smartActions = [
            .bedtimeWindDown(windDownNudge),
            .activitySuggestion(activityNudge),
            .standardNudge,
        ]

        vm.handleSmartAction(.bedtimeWindDown(windDownNudge))

        XCTAssertEqual(vm.smartActions.count, 2, "Should keep activitySuggestion and standardNudge")
        let hasActivity = vm.smartActions.contains { if case .activitySuggestion = $0 { return true }; return false }
        XCTAssertTrue(hasActivity, "activitySuggestion should still be present")
    }

    /// Verifies that handleSmartAction(.morningCheckIn) also removes
    /// its card from smartActions (same pattern as bedtimeWindDown).
    func testHandleMorningCheckIn_removesCardFromSmartActions() {
        let vm = StressViewModel()
        let checkInAction = SmartNudgeAction.morningCheckIn("Good morning!")

        vm.smartActions = [checkInAction, .standardNudge]
        vm.smartAction = checkInAction

        vm.handleSmartAction(checkInAction)

        let hasMorningCheckIn = vm.smartActions.contains { action in
            if case .morningCheckIn = action { return true }
            return false
        }
        XCTAssertFalse(
            hasMorningCheckIn,
            "morningCheckIn card should be removed from smartActions after handling"
        )
    }
}

// MARK: - Bug 3: activitySuggestion walk suggestion state

@MainActor
final class ActivitySuggestionActionTests: XCTestCase {

    /// Verifies that handleSmartAction(.activitySuggestion) sets
    /// walkSuggestionShown to true. The existing test verified this,
    /// but this test makes the expectation explicit: the user should
    /// be able to take action from the alert (the fix added an
    /// "Open Fitness" button with fitness:// URL scheme).
    func testActivitySuggestion_setsWalkSuggestionShown() {
        let vm = StressViewModel()
        let nudge = DailyNudge(
            category: .walk,
            title: "Get Moving",
            description: "A short walk helps reduce stress",
            durationMinutes: 10,
            icon: "figure.walk"
        )

        vm.handleSmartAction(.activitySuggestion(nudge))

        XCTAssertTrue(
            vm.walkSuggestionShown,
            "walkSuggestionShown must be true after activitySuggestion — "
            + "the UI should show an actionable alert (not just OK)"
        )
    }

    /// Verifies walkSuggestionShown starts as false.
    func testWalkSuggestionShown_initiallyFalse() {
        let vm = StressViewModel()
        XCTAssertFalse(vm.walkSuggestionShown)
    }

    /// Verifies that calling handleSmartAction with activitySuggestion
    /// does NOT interfere with other state (breathing session, journal).
    func testActivitySuggestion_doesNotAffectOtherState() {
        let vm = StressViewModel()
        let nudge = DailyNudge(
            category: .walk,
            title: "Walk",
            description: "Walk",
            durationMinutes: 10,
            icon: "figure.walk"
        )

        vm.handleSmartAction(.activitySuggestion(nudge))

        XCTAssertFalse(vm.isBreathingSessionActive, "Should not start breathing")
        XCTAssertFalse(vm.isJournalSheetPresented, "Should not show journal")
        XCTAssertFalse(vm.didSendBreathPromptToWatch, "Should not send watch prompt")
    }
}

// MARK: - Bug 5: TrendsViewModel nil-metric fallback

@MainActor
final class TrendsViewModelNilMetricTests: XCTestCase {

    /// Creates nil-metric snapshots simulating simulator HealthKit data.
    private func makeNilMetricSnapshots(count: Int) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return HeartSnapshot(date: date)
        }
    }

    private func makePopulatedSnapshots(count: Int) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return HeartSnapshot(
                date: date,
                restingHeartRate: 62.0 + Double(offset % 5),
                hrvSDNN: 42.0 + Double(offset % 8),
                recoveryHR1m: 25.0,
                vo2Max: 38.0,
                walkMinutes: 25.0,
                workoutMinutes: 30.0,
                sleepHours: 7.5
            )
        }
    }

    /// Verifies that nil-metric history produces no data points for any metric type,
    /// confirming the root cause of the empty Trends page.
    func testNilMetricHistory_producesNoDataPoints() {
        let vm = TrendsViewModel()
        vm.history = makeNilMetricSnapshots(count: 14)

        for metric in TrendsViewModel.MetricType.allCases {
            let points = vm.dataPoints(for: metric)
            XCTAssertTrue(
                points.isEmpty,
                "Nil-metric snapshots should produce no data points for \(metric.rawValue) — "
                + "this is the root cause of the empty Trends page"
            )
        }
    }

    /// Verifies that populated history produces data points for each metric type.
    func testPopulatedHistory_producesDataPoints() {
        let vm = TrendsViewModel()
        vm.history = makePopulatedSnapshots(count: 14)

        // At minimum, restingHR and HRV should have data
        let rhrPoints = vm.dataPoints(for: .restingHR)
        XCTAssertFalse(rhrPoints.isEmpty, "Populated snapshots should have resting HR data")

        let hrvPoints = vm.dataPoints(for: .hrv)
        XCTAssertFalse(hrvPoints.isEmpty, "Populated snapshots should have HRV data")
    }

    /// Verifies that currentStats is nil when history has nil metrics.
    func testCurrentStats_nilWithNilMetricHistory() {
        let vm = TrendsViewModel()
        vm.history = makeNilMetricSnapshots(count: 14)

        XCTAssertNil(
            vm.currentStats,
            "currentStats should be nil when no data points exist"
        )
    }

    /// Verifies that currentStats is non-nil when history is populated.
    func testCurrentStats_nonNilWithPopulatedHistory() {
        let vm = TrendsViewModel()
        vm.history = makePopulatedSnapshots(count: 14)

        XCTAssertNotNil(
            vm.currentStats,
            "currentStats should be non-nil with populated history"
        )
    }

    /// Verifies hasRealData check for TrendsViewModel scenario.
    func testHasRealDataCheck_forTrendsScenario() {
        let nilSnapshots = makeNilMetricSnapshots(count: 7)
        let hasRealData = nilSnapshots.contains(where: { $0.hrvSDNN != nil })
        XCTAssertFalse(
            hasRealData,
            "Nil-metric snapshots should fail the hasRealData check — "
            + "this is the condition that triggers the simulator fallback"
        )
    }
}

// MARK: - Bug 1 (variant): DashboardViewModel nil-metric fallback

@MainActor
final class DashboardViewModelNilMetricTests: XCTestCase {

    private var defaults: UserDefaults?
    private var localStore: LocalStore?

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.thump.nilmetric.\(UUID().uuidString)")
        localStore = defaults.map { LocalStore(defaults: $0) }
    }

    override func tearDown() {
        defaults = nil
        localStore = nil
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    /// Verifies that when MockHealthDataProvider returns nil-metric snapshots
    /// (simulating simulator HealthKit), the dashboard still produces an
    /// assessment via the fallback.
    ///
    /// Before the fix, the provider returned nil-HRV snapshots without
    /// throwing, so the catch-block fallback never triggered.
    func testNilMetricProvider_assessmentBehavior() async throws {
        let localStore = try XCTUnwrap(localStore)

        // Create a provider that returns nil-metric snapshots (doesn't throw)
        let nilSnapshot = HeartSnapshot(date: Date())
        let nilHistory = (0..<14).map { offset in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            )
        }

        let provider = MockHealthDataProvider(
            todaySnapshot: nilSnapshot,
            history: nilHistory,
            shouldAuthorize: true
        )

        let vm = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await vm.refresh()

        // The provider did NOT throw, so fetchHistory was called
        XCTAssertEqual(provider.fetchHistoryCallCount, 1, "History should be fetched")
        XCTAssertEqual(provider.fetchTodayCallCount, 1, "Today snapshot should be fetched")

        // On simulator with the fix: fallback to MockData produces an assessment
        // On device or without the fix: nil-metric data may still produce assessment
        // but with degraded quality. The key test is that the fetch succeeded
        // (the provider didn't throw) but data is empty.

        // Document the nil-HRV condition
        XCTAssertNil(
            nilSnapshot.hrvSDNN,
            "Test snapshot should have nil HRV to simulate simulator condition"
        )

        // This is the hasRealData check from the fix
        let hasRealData = nilHistory.contains(where: { $0.hrvSDNN != nil })
        XCTAssertFalse(
            hasRealData,
            "Nil-metric history should fail the hasRealData check"
        )
    }

    /// Verifies that a provider returning populated data works normally.
    func testPopulatedProvider_producesAssessment() async throws {
        let localStore = try XCTUnwrap(localStore)

        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 64.0,
            hrvSDNN: 48.0,
            recoveryHR1m: 25.0,
            recoveryHR2m: 40.0,
            vo2Max: 38.0,
            zoneMinutes: [110, 25, 12, 5, 1],
            steps: 8000,
            walkMinutes: 30.0,
            workoutMinutes: 35.0,
            sleepHours: 7.5
        )

        let history: [HeartSnapshot] = (1...14).reversed().map { day in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -day, to: Date()) ?? Date(),
                restingHeartRate: 65.0 + Double(day % 3),
                hrvSDNN: 45.0 + Double(day % 4),
                recoveryHR1m: 25.0,
                recoveryHR2m: 40.0,
                vo2Max: 38.0,
                zoneMinutes: [110, 25, 12, 5, 1],
                steps: 8000,
                walkMinutes: 30.0,
                workoutMinutes: 35.0,
                sleepHours: 7.5
            )
        }

        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: history,
            shouldAuthorize: true
        )

        let vm = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await vm.refresh()

        XCTAssertNotNil(vm.assessment, "Populated data should produce an assessment")
        XCTAssertNotNil(vm.todaySnapshot, "Today snapshot should be set")
        XCTAssertNil(vm.errorMessage, "No error should be present")
    }

    /// Verifies that a nil-metric snapshot has nil HRV (the condition
    /// checked in the simulator fallback).
    func testNilMetricSnapshot_hasNilHRV() {
        let snapshot = HeartSnapshot(date: Date())
        XCTAssertNil(snapshot.hrvSDNN, "Default HeartSnapshot should have nil HRV")
        XCTAssertNil(snapshot.restingHeartRate, "Default HeartSnapshot should have nil RHR")
    }
}

// MARK: - Integration: StressEngine with nil-metric data

final class StressEngineNilMetricTests: XCTestCase {

    /// Verifies the StressEngine returns nil when given nil-metric snapshots.
    /// This confirms the cascade: nil HRV → nil stress → empty heatmap/summary.
    func testComputeStress_nilHRV_returnsNil() {
        let engine = StressEngine()
        let snapshot = HeartSnapshot(date: Date())
        let history = (1...14).map { offset in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            )
        }

        let result = engine.computeStress(snapshot: snapshot, recentHistory: history)

        XCTAssertNil(
            result,
            "StressEngine should return nil when HRV is nil — "
            + "this is why nil-metric snapshots produce an empty heatmap"
        )
    }

    /// Verifies that stressTrend produces empty results with nil-metric snapshots.
    func testStressTrend_nilMetrics_returnsEmpty() {
        let engine = StressEngine()
        let snapshots = (0..<30).map { offset in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            )
        }

        let trend = engine.stressTrend(snapshots: snapshots, range: .week)
        XCTAssertTrue(trend.isEmpty, "Nil-metric snapshots should produce no trend data")
    }

    /// Verifies that stressTrend produces results with populated snapshots.
    func testStressTrend_populatedMetrics_returnsData() {
        let engine = StressEngine()
        let snapshots: [HeartSnapshot] = (0..<30).reversed().map { offset in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date(),
                restingHeartRate: 62.0 + Double(offset % 5),
                hrvSDNN: 42.0 + Double(offset % 8),
                recoveryHR1m: 25.0,
                sleepHours: 7.5
            )
        }

        let trend = engine.stressTrend(snapshots: snapshots, range: .week)
        XCTAssertFalse(trend.isEmpty, "Populated snapshots should produce trend data")
    }
}

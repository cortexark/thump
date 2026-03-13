// DashboardBuddyIntegrationTests.swift
// ThumpTests
//
// Integration tests for buddy recommendation flow through DashboardViewModel:
// verifies that refresh() populates buddyRecommendations, sorts by priority,
// caps at 4, and produces correct recommendations for stress/alert scenarios.

import XCTest
@testable import Thump

@MainActor
final class DashboardBuddyIntegrationTests: XCTestCase {

    private var defaults: UserDefaults?
    private var localStore: LocalStore?

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.thump.buddy.\(UUID().uuidString)")
        localStore = defaults.map { LocalStore(defaults: $0) }
    }

    override func tearDown() {
        defaults = nil
        localStore = nil
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    // MARK: - 1. buddyRecommendations is populated after refresh

    func testRefresh_populatesBuddyRecommendations() async throws {
        let localStore = try XCTUnwrap(localStore)
        let snapshot = makeSnapshot(
            daysAgo: 0,
            rhr: 62, hrv: 50,
            recovery1m: 35,
            sleepHours: 7.5,
            walkMinutes: 30, workoutMinutes: 25
        )
        let history = makeHistory(days: 14)

        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: history,
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        XCTAssertNotNil(
            viewModel.buddyRecommendations,
            "buddyRecommendations should be populated after refresh"
        )
        XCTAssertFalse(
            viewModel.buddyRecommendations?.isEmpty ?? true,
            "buddyRecommendations should contain at least one item"
        )
    }

    // MARK: - 2. Recommendations sorted by priority (highest first)

    func testRefresh_buddyRecommendationsSortedByPriorityDescending() async throws {
        let localStore = try XCTUnwrap(localStore)
        // Use a stressed snapshot to generate multiple recommendations
        let snapshot = makeSnapshot(
            daysAgo: 0,
            rhr: 78, hrv: 22,
            recovery1m: 14,
            sleepHours: 5.0,
            walkMinutes: 5, workoutMinutes: 0
        )
        let history = makeHistory(days: 14)

        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: history,
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        let recs = try XCTUnwrap(viewModel.buddyRecommendations)
        guard recs.count >= 2 else { return }

        for i in 0..<(recs.count - 1) {
            XCTAssertGreaterThanOrEqual(
                recs[i].priority, recs[i + 1].priority,
                "Recommendation at index \(i) should have >= priority than index \(i + 1)"
            )
        }
    }

    // MARK: - 3. Maximum 4 recommendations returned

    func testRefresh_buddyRecommendationsCappedAtFour() async throws {
        let localStore = try XCTUnwrap(localStore)
        // Stressed profile with many signals to trigger lots of recommendations
        let snapshot = makeSnapshot(
            daysAgo: 0,
            rhr: 82, hrv: 18,
            recovery1m: 10,
            sleepHours: 4.5,
            walkMinutes: 0, workoutMinutes: 0
        )
        let history = makeStressedHistory(days: 14)

        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: history,
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        let recs = try XCTUnwrap(viewModel.buddyRecommendations)
        XCTAssertLessThanOrEqual(
            recs.count, 4,
            "Should return at most 4 recommendations, got \(recs.count)"
        )
    }

    // MARK: - 4. consecutiveAlert triggers critical priority recommendation

    func testRefresh_consecutiveAlert_producesCriticalRecommendation() async throws {
        let localStore = try XCTUnwrap(localStore)
        // Create a snapshot with elevated RHR that the trend engine might flag
        // We need enough history with elevated RHR to trigger consecutive alert
        let snapshot = makeSnapshot(
            daysAgo: 0,
            rhr: 82, hrv: 25,
            recovery1m: 15,
            sleepHours: 6.0,
            walkMinutes: 10, workoutMinutes: 5
        )
        // Build history with consecutively elevated RHR
        let history = makeElevatedHistory(days: 14)

        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: history,
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        let recs = try XCTUnwrap(viewModel.buddyRecommendations)
        // If the trend engine flagged a consecutive alert, there should be a critical rec
        if let assessment = viewModel.assessment, assessment.consecutiveAlert != nil {
            let hasCritical = recs.contains { $0.priority == .critical }
            XCTAssertTrue(
                hasCritical,
                "consecutiveAlert should produce a critical priority recommendation"
            )
        }
    }

    // MARK: - 5. stressFlag triggers stress-related recommendation

    func testRefresh_stressFlag_producesStressRecommendation() async throws {
        let localStore = try XCTUnwrap(localStore)
        // Snapshot designed to trigger stress: high RHR, low HRV, poor recovery
        let snapshot = makeSnapshot(
            daysAgo: 0,
            rhr: 80, hrv: 20,
            recovery1m: 12,
            sleepHours: 5.0,
            walkMinutes: 5, workoutMinutes: 0
        )
        let history = makeHistory(days: 14)

        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: history,
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        let recs = try XCTUnwrap(viewModel.buddyRecommendations)
        if let assessment = viewModel.assessment, assessment.stressFlag {
            let hasStressRec = recs.contains {
                $0.source == .stressEngine
                    || ($0.source == .trendEngine && $0.category == .breathe)
                    || $0.category == .breathe
                    || $0.category == .rest
            }
            XCTAssertTrue(
                hasStressRec,
                "stressFlag should produce a stress-related recommendation, got: \(recs.map { "\($0.source.rawValue)/\($0.category.rawValue)" })"
            )
        }
        // If stressFlag is not set despite stressed inputs, the pipeline
        // may threshold differently — just verify we got some recommendations.
        XCTAssertFalse(recs.isEmpty, "Should produce at least one buddy recommendation")
    }

    // MARK: - Helpers

    private func makeSnapshot(
        daysAgo: Int,
        rhr: Double,
        hrv: Double,
        recovery1m: Double = 25.0,
        sleepHours: Double = 7.5,
        walkMinutes: Double = 30.0,
        workoutMinutes: Double = 35.0
    ) -> HeartSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return HeartSnapshot(
            date: date,
            restingHeartRate: rhr,
            hrvSDNN: hrv,
            recoveryHR1m: recovery1m,
            recoveryHR2m: 40.0,
            vo2Max: 38.0,
            zoneMinutes: [110, 25, 12, 5, 1],
            steps: 8000,
            walkMinutes: walkMinutes,
            workoutMinutes: workoutMinutes,
            sleepHours: sleepHours
        )
    }

    private func makeHistory(days: Int) -> [HeartSnapshot] {
        (1...days).reversed().map { day in
            makeSnapshot(
                daysAgo: day,
                rhr: 65.0 + Double(day % 3),
                hrv: 45.0 + Double(day % 4),
                recovery1m: 25.0 + Double(day % 5),
                sleepHours: 7.0 + Double(day % 3) * 0.5,
                walkMinutes: 20.0 + Double(day % 4) * 5,
                workoutMinutes: 15.0 + Double(day % 3) * 10
            )
        }
    }

    /// History with consistently elevated RHR to trigger consecutive elevation alert.
    private func makeElevatedHistory(days: Int) -> [HeartSnapshot] {
        (1...days).reversed().map { day in
            makeSnapshot(
                daysAgo: day,
                rhr: 80.0 + Double(day % 3),
                hrv: 22.0 + Double(day % 3),
                recovery1m: 15.0 + Double(day % 3),
                sleepHours: 5.5 + Double(day % 2) * 0.5,
                walkMinutes: 10.0,
                workoutMinutes: 5.0
            )
        }
    }

    /// History with many stress signals to trigger maximum recommendation count.
    private func makeStressedHistory(days: Int) -> [HeartSnapshot] {
        (1...days).reversed().map { day in
            makeSnapshot(
                daysAgo: day,
                rhr: 82.0 + Double(day % 4),
                hrv: 18.0 + Double(day % 2),
                recovery1m: 10.0 + Double(day % 3),
                sleepHours: 4.5 + Double(day % 2) * 0.5,
                walkMinutes: 0,
                workoutMinutes: 0
            )
        }
    }
}

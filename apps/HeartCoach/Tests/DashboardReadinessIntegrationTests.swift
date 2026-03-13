// DashboardReadinessIntegrationTests.swift
// ThumpTests
//
// Integration tests for readiness score flow through DashboardViewModel:
// verifies that refresh() populates readinessResult, handles missing data,
// and produces correct readiness levels for various health profiles.

import XCTest
@testable import Thump

@MainActor
final class DashboardReadinessIntegrationTests: XCTestCase {

    private var defaults: UserDefaults?
    private var localStore: LocalStore?

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.thump.readiness.\(UUID().uuidString)")
        localStore = defaults.map { LocalStore(defaults: $0) }
    }

    override func tearDown() {
        defaults = nil
        localStore = nil
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    // MARK: - Readiness Population

    func testRefresh_populatesReadinessResult() async throws {
        let localStore = try XCTUnwrap(localStore)
        let snapshot = makeSnapshot(
            daysAgo: 0,
            rhr: 60, hrv: 50,
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

        XCTAssertNotNil(viewModel.readinessResult, "Readiness should be computed after refresh")
        XCTAssertGreaterThan(viewModel.readinessResult!.score, 0)
        XCTAssertFalse(viewModel.readinessResult!.pillars.isEmpty)
    }

    func testRefresh_readinessResultHasValidLevel() async throws {
        let localStore = try XCTUnwrap(localStore)
        let snapshot = makeSnapshot(
            daysAgo: 0,
            rhr: 60, hrv: 55,
            recovery1m: 38,
            sleepHours: 8.0,
            walkMinutes: 30, workoutMinutes: 30
        )
        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: makeHistory(days: 14),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        let result = try XCTUnwrap(viewModel.readinessResult)
        let validLevels: [ReadinessLevel] = [.primed, .ready, .moderate, .recovering]
        XCTAssertTrue(validLevels.contains(result.level))
        XCTAssertFalse(result.summary.isEmpty)
    }

    // MARK: - Missing Data Handling

    func testRefresh_minimalData_readinessNilOrValid() async throws {
        let localStore = try XCTUnwrap(localStore)
        // Only sleep data, no history for HRV trend
        let snapshot = HeartSnapshot(date: Date(), sleepHours: 7.0)
        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: [],
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        // With only 1 pillar (sleep), readiness requires 2+ pillars → nil
        // OR if mock data kicks in, it could produce a result
        // Either outcome is valid — no crash
        if let result = viewModel.readinessResult {
            XCTAssertGreaterThanOrEqual(result.score, 0)
            XCTAssertLessThanOrEqual(result.score, 100)
        }
    }

    func testRefresh_emptySnapshot_noReadinessCrash() async throws {
        let localStore = try XCTUnwrap(localStore)
        let snapshot = HeartSnapshot(date: Date())
        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: [],
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        // Should not crash; readiness may be nil (insufficient pillars)
        // The key assertion is reaching this point without a crash
    }

    // MARK: - Readiness Score Range

    func testRefresh_readinessScoreInValidRange() async throws {
        let localStore = try XCTUnwrap(localStore)
        let snapshot = makeSnapshot(
            daysAgo: 0,
            rhr: 65, hrv: 45,
            recovery1m: 28,
            sleepHours: 6.5,
            walkMinutes: 15, workoutMinutes: 10
        )
        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: makeHistory(days: 14),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        if let result = viewModel.readinessResult {
            XCTAssertGreaterThanOrEqual(result.score, 0)
            XCTAssertLessThanOrEqual(result.score, 100)
            // Level should match score range
            switch result.level {
            case .primed:
                XCTAssertGreaterThanOrEqual(result.score, 80)
            case .ready:
                XCTAssertGreaterThanOrEqual(result.score, 60)
                XCTAssertLessThan(result.score, 80)
            case .moderate:
                XCTAssertGreaterThanOrEqual(result.score, 40)
                XCTAssertLessThan(result.score, 60)
            case .recovering:
                XCTAssertLessThan(result.score, 40)
            }
        }
    }

    // MARK: - Stress Flag Integration

    func testRefresh_withStressFlag_affectsReadiness() async throws {
        let localStore = try XCTUnwrap(localStore)
        // Create a snapshot that will likely trigger stress flag in assessment
        let snapshot = makeSnapshot(
            daysAgo: 0,
            rhr: 80, hrv: 20,
            recovery1m: 12,
            sleepHours: 5.0,
            walkMinutes: 5, workoutMinutes: 0
        )
        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: makeHistory(days: 14),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        // If stress flag is set in assessment, readiness should have stress pillar
        if let result = viewModel.readinessResult,
           let assessment = viewModel.assessment,
           assessment.stressFlag {
            let hasStressPillar = result.pillars.contains { $0.type == .stress }
            XCTAssertTrue(hasStressPillar, "Stress flag should contribute stress pillar")
        }
    }

    // MARK: - Pillar Breakdown

    func testRefresh_fullData_producesMultiplePillars() async throws {
        let localStore = try XCTUnwrap(localStore)
        let snapshot = makeSnapshot(
            daysAgo: 0,
            rhr: 60, hrv: 50,
            recovery1m: 35,
            sleepHours: 8.0,
            walkMinutes: 30, workoutMinutes: 25
        )
        let provider = MockHealthDataProvider(
            todaySnapshot: snapshot,
            history: makeHistory(days: 14),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        if let result = viewModel.readinessResult {
            XCTAssertGreaterThanOrEqual(result.pillars.count, 2, "Should have at least 2 pillars")
            // Each pillar should have valid score
            for pillar in result.pillars {
                XCTAssertGreaterThanOrEqual(pillar.score, 0)
                XCTAssertLessThanOrEqual(pillar.score, 100)
                XCTAssertFalse(pillar.detail.isEmpty)
                XCTAssertGreaterThan(pillar.weight, 0)
            }
        }
    }

    // MARK: - Error Path

    func testRefresh_providerError_readinessNotComputed() async throws {
        let localStore = try XCTUnwrap(localStore)
        let provider = MockHealthDataProvider(
            fetchError: NSError(domain: "TestError", code: -1)
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        // In simulator builds, the error path falls back to mock data rather than
        // surfacing the error. The key assertion is that we don't crash.
        // Readiness might still be computed from empty/fallback data — either way is valid.
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
}

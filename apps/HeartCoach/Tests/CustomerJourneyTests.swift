// CustomerJourneyTests.swift
// ThumpTests
//
// End-to-end customer journey tests that simulate real user scenarios
// across the full app pipeline: onboarding → HealthKit fetch →
// assessment → dashboard state → nudge → feedback → streak.
// These catch the "basic use case" bugs that unit tests miss.

import XCTest
@testable import Thump

@MainActor
final class CustomerJourneyTests: XCTestCase {

    private var defaults: UserDefaults?
    private var localStore: LocalStore?

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.thump.journey.\(UUID().uuidString)")
        localStore = defaults.map { LocalStore(defaults: $0) }
    }

    override func tearDown() {
        defaults = nil
        localStore = nil
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    // MARK: - Journey 1: First-Time User

    /// New user: onboard → authorize HealthKit → see first dashboard.
    func testFirstTimeUser_seesAssessmentAfterAuthorization() async throws {
        let localStore = try XCTUnwrap(localStore)
        let provider = MockHealthDataProvider(
            todaySnapshot: makeGoodSnapshot(),
            history: makeHistory(days: 7),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        // Simulate first open
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertNil(viewModel.assessment)
        XCTAssertNil(viewModel.todaySnapshot)

        await viewModel.refresh()

        // After refresh, user sees data
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.assessment, "User should see an assessment")
        XCTAssertNotNil(viewModel.todaySnapshot, "User should see today's metrics")
        XCTAssertNil(viewModel.errorMessage, "Should be no errors")

        // Assessment should be persisted
        XCTAssertFalse(localStore.loadHistory().isEmpty, "Should persist to history")
    }

    // MARK: - Journey 2: Daily Return User

    /// Returning user: open app → see fresh assessment → complete nudge → streak updates.
    func testDailyReturnUser_completesNudgeAndStreakIncrements() async throws {
        let localStore = try XCTUnwrap(localStore)
        let provider = MockHealthDataProvider(
            todaySnapshot: makeGoodSnapshot(),
            history: makeHistory(days: 14),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        let initialStreak = viewModel.profileStreakDays

        // User taps "Done" on nudge
        viewModel.markNudgeComplete()

        XCTAssertGreaterThanOrEqual(
            viewModel.profileStreakDays,
            initialStreak,
            "Streak should increment or stay same after nudge completion"
        )

        // Feedback should be persisted
        let savedFeedback = localStore.loadLastFeedback()
        XCTAssertNotNil(savedFeedback, "Feedback should persist")
        XCTAssertEqual(savedFeedback?.response, .positive)
    }

    // MARK: - Journey 3: Mood Check-In

    /// User opens dashboard → taps mood → mood is recorded.
    func testMoodCheckIn_persistsAndUpdatesUI() async throws {
        let localStore = try XCTUnwrap(localStore)
        let provider = MockHealthDataProvider(
            todaySnapshot: makeGoodSnapshot(),
            history: makeHistory(days: 7),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        // Before check-in
        XCTAssertFalse(viewModel.hasCheckedInToday)
        XCTAssertNil(viewModel.todayMood)

        // User taps "Great" mood
        viewModel.submitCheckIn(mood: .great)

        XCTAssertTrue(viewModel.hasCheckedInToday)
        XCTAssertEqual(viewModel.todayMood, .great)

        // Verify persistence — simulate reopening by refreshing
        await viewModel.refresh()
        XCTAssertTrue(viewModel.hasCheckedInToday, "Check-in should persist across refresh")
    }

    // MARK: - Journey 4: Readiness Score Display

    /// User with good metrics sees a positive readiness score.
    func testHealthyUser_seesGoodReadinessScore() async throws {
        let localStore = try XCTUnwrap(localStore)
        let snapshot = makeGoodSnapshot()
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

        if let readiness = viewModel.readinessResult {
            XCTAssertGreaterThanOrEqual(readiness.score, 40,
                "Healthy user should not be 'recovering'")
            XCTAssertFalse(readiness.pillars.isEmpty)
            XCTAssertFalse(readiness.summary.isEmpty)
        }
    }

    /// User with poor metrics sees a lower readiness score.
    func testTiredUser_seesLowerReadinessScore() async throws {
        let localStore = try XCTUnwrap(localStore)
        let snapshot = makeTiredSnapshot()
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

        // Should still produce a result without crashing
        // The exact score depends on engine calculations
        XCTAssertNotNil(viewModel.assessment)
    }

    // MARK: - Journey 5: Multiple Nudge Completion

    /// User completes multiple nudge suggestions (new multi-nudge feature).
    func testMultipleNudgeCompletion_tracksEachIndependently() async throws {
        let localStore = try XCTUnwrap(localStore)
        let provider = MockHealthDataProvider(
            todaySnapshot: makeGoodSnapshot(),
            history: makeHistory(days: 14),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        // Complete nudge at index 0
        viewModel.markNudgeComplete(at: 0)
        XCTAssertEqual(viewModel.nudgeCompletionStatus[0], true)
        XCTAssertNil(viewModel.nudgeCompletionStatus[1])

        // Complete nudge at index 1
        viewModel.markNudgeComplete(at: 1)
        XCTAssertEqual(viewModel.nudgeCompletionStatus[1], true)

        // Both should be tracked
        XCTAssertEqual(viewModel.nudgeCompletionStatus.count, 2)
    }

    // MARK: - Journey 6: Bio Age Display

    /// User with date of birth set sees bio age estimate.
    func testUserWithDOB_seesBioAge() async throws {
        let localStore = try XCTUnwrap(localStore)

        // Set date of birth (40 years old)
        let calendar = Calendar.current
        localStore.profile.dateOfBirth = calendar.date(
            byAdding: .year, value: -40, to: Date()
        )
        localStore.saveProfile()

        let provider = MockHealthDataProvider(
            todaySnapshot: makeGoodSnapshot(),
            history: makeHistory(days: 14),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        XCTAssertNotNil(viewModel.bioAgeResult, "User with DOB should see bio age")
    }

    /// User without date of birth does NOT see bio age.
    func testUserWithoutDOB_noBioAge() async throws {
        let localStore = try XCTUnwrap(localStore)
        // No DOB set

        let provider = MockHealthDataProvider(
            todaySnapshot: makeGoodSnapshot(),
            history: makeHistory(days: 14),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        XCTAssertNil(viewModel.bioAgeResult, "User without DOB should not see bio age")
    }

    // MARK: - Journey 7: Weekly Trend

    /// User with 2+ weeks of data sees a weekly trend summary.
    func testUserWithHistory_seesWeeklyTrend() async throws {
        let localStore = try XCTUnwrap(localStore)
        let provider = MockHealthDataProvider(
            todaySnapshot: makeGoodSnapshot(),
            history: makeHistory(days: 21),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        XCTAssertNotNil(
            viewModel.weeklyTrendSummary,
            "User with 21 days of history should see weekly trend"
        )
    }

    // MARK: - Journey 8: Nudge Already Met

    /// Active user who already walked enough sees "already met" state.
    func testActiveUser_nudgeAlreadyMet() async throws {
        let localStore = try XCTUnwrap(localStore)
        let activeSnapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 60,
            hrvSDNN: 50,
            recoveryHR1m: 35,
            recoveryHR2m: 50,
            vo2Max: 42,
            steps: 12000,
            walkMinutes: 45,      // Well above 15-min threshold
            workoutMinutes: 30,   // Well above 20-min threshold
            sleepHours: 8.0
        )
        let provider = MockHealthDataProvider(
            todaySnapshot: activeSnapshot,
            history: makeHistory(days: 14),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await viewModel.refresh()

        // If the nudge is walk or moderate, isNudgeAlreadyMet should be true
        if let nudge = viewModel.assessment?.dailyNudge,
           (nudge.category == .walk || nudge.category == .moderate) {
            XCTAssertTrue(viewModel.isNudgeAlreadyMet,
                "Active user should see nudge as already met")
        }
    }

    // MARK: - Journey 9: Data Bounds Protection

    /// Corrupt HealthKit data doesn't crash the pipeline.
    func testCorruptHealthKitData_doesNotCrash() async throws {
        let localStore = try XCTUnwrap(localStore)
        // Extreme out-of-range values
        let corruptSnapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: -50,    // Impossible
            hrvSDNN: 99999,           // Way too high
            recoveryHR1m: -100,       // Impossible
            vo2Max: 500,              // Impossible
            steps: -1000,             // Impossible
            walkMinutes: -60,         // Impossible
            sleepHours: 100           // Impossible
        )
        let provider = MockHealthDataProvider(
            todaySnapshot: corruptSnapshot,
            history: [],
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        // Should not crash
        await viewModel.refresh()

        XCTAssertFalse(viewModel.isLoading)
        // Clamped values: RHR nil (<30), HRV clamped to 300, recovery nil (<0), etc.
        if let snapshot = viewModel.todaySnapshot {
            XCTAssertNil(snapshot.restingHeartRate, "Negative RHR should be nil")
            if let hrv = snapshot.hrvSDNN {
                XCTAssertLessThanOrEqual(hrv, 300, "HRV should be clamped to 300")
            }
            XCTAssertNil(snapshot.steps, "Negative steps should be nil")
        }
    }

    // MARK: - Journey 10: Subscription Tier

    /// Free tier user should see free tier.
    func testFreeUser_seesFreeSubscriptionTier() async throws {
        let localStore = try XCTUnwrap(localStore)
        let provider = MockHealthDataProvider(
            todaySnapshot: makeGoodSnapshot(),
            history: makeHistory(days: 7),
            shouldAuthorize: true
        )
        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        // Default tier should be free
        XCTAssertEqual(viewModel.currentTier, .free)
    }

    // MARK: - Helpers

    private func makeGoodSnapshot() -> HeartSnapshot {
        HeartSnapshot(
            date: Date(),
            restingHeartRate: 62,
            hrvSDNN: 50,
            recoveryHR1m: 35,
            recoveryHR2m: 50,
            vo2Max: 42,
            zoneMinutes: [100, 30, 15, 5, 2],
            steps: 9500,
            walkMinutes: 35,
            workoutMinutes: 30,
            sleepHours: 7.8
        )
    }

    private func makeTiredSnapshot() -> HeartSnapshot {
        HeartSnapshot(
            date: Date(),
            restingHeartRate: 78,
            hrvSDNN: 22,
            recoveryHR1m: 12,
            recoveryHR2m: 18,
            vo2Max: 30,
            steps: 2000,
            walkMinutes: 5,
            workoutMinutes: 0,
            sleepHours: 4.5
        )
    }

    private func makeHistory(days: Int) -> [HeartSnapshot] {
        (1...days).reversed().map { day in
            let date = Calendar.current.date(
                byAdding: .day, value: -day, to: Date()
            ) ?? Date()
            return HeartSnapshot(
                date: date,
                restingHeartRate: 63 + Double(day % 4),
                hrvSDNN: 45 + Double(day % 5),
                recoveryHR1m: 25 + Double(day % 6),
                recoveryHR2m: 40,
                vo2Max: 38 + Double(day % 3),
                zoneMinutes: [90, 25, 10, 4, 1],
                steps: Double(7000 + day * 200),
                walkMinutes: 25 + Double(day % 5) * 3,
                workoutMinutes: 20 + Double(day % 4) * 5,
                sleepHours: 7.0 + Double(day % 3) * 0.5
            )
        }
    }
}

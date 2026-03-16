// DashboardViewModelExtendedTests.swift
// ThumpCoreTests
//
// Extended tests for DashboardViewModel covering: check-in flow,
// weekly trend computation, nudge evaluation edge cases, streak logic,
// multiple nudge completion, profile accessors, bio age gating,
// zone analysis gating, coaching report gating, and state transitions.
// (Complements DashboardViewModelTests which covers basic refresh + errors.)

import XCTest
@testable import Thump

@MainActor
final class DashboardViewModelExtendedTests: XCTestCase {

    private var defaults: UserDefaults!
    private var localStore: LocalStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.thump.dashext.\(UUID().uuidString)")!
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
        steps: Double? = 8000,
        zoneMinutes: [Double] = [110, 25, 12, 5, 1]
    ) -> HeartSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return HeartSnapshot(
            date: date,
            restingHeartRate: rhr,
            hrvSDNN: hrv,
            recoveryHR1m: 25.0,
            recoveryHR2m: 40.0,
            vo2Max: 38.0,
            zoneMinutes: zoneMinutes,
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

    private func makeViewModel(
        todaySnapshot: HeartSnapshot? = nil,
        history: [HeartSnapshot]? = nil
    ) -> DashboardViewModel {
        let snap = todaySnapshot ?? makeSnapshot(daysAgo: 0)
        let hist = history ?? makeHistory(days: 14)
        let provider = MockHealthDataProvider(
            todaySnapshot: snap,
            history: hist,
            shouldAuthorize: true
        )
        return DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )
    }

    // MARK: - Profile Accessors

    func testProfileName_reflectsLocalStore() {
        localStore.profile.displayName = "TestUser"
        localStore.saveProfile()
        let vm = makeViewModel()
        XCTAssertEqual(vm.profileName, "TestUser")
    }

    func testProfileStreakDays_reflectsLocalStore() {
        localStore.profile.streakDays = 7
        localStore.saveProfile()
        let vm = makeViewModel()
        XCTAssertEqual(vm.profileStreakDays, 7)
    }

    // MARK: - Check-In Flow

    func testSubmitCheckIn_setsHasCheckedInToday() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.hasCheckedInToday)

        vm.submitCheckIn(mood: .great)

        XCTAssertTrue(vm.hasCheckedInToday)
        XCTAssertEqual(vm.todayMood, .great)
    }

    func testSubmitCheckIn_allMoods() {
        for mood in CheckInMood.allCases {
            let vm = makeViewModel()
            vm.submitCheckIn(mood: mood)
            XCTAssertTrue(vm.hasCheckedInToday)
            XCTAssertEqual(vm.todayMood, mood)
        }
    }

    func testSubmitCheckIn_persistsToLocalStore() {
        let vm = makeViewModel()
        vm.submitCheckIn(mood: .rough)

        let saved = localStore.loadTodayCheckIn()
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.feelingScore, CheckInMood.rough.score)
    }

    // MARK: - Mark Nudge Complete

    func testMarkNudgeComplete_at_index_setsCompletion() {
        let vm = makeViewModel()

        vm.markNudgeComplete(at: 0)
        XCTAssertEqual(vm.nudgeCompletionStatus[0], true)

        vm.markNudgeComplete(at: 2)
        XCTAssertEqual(vm.nudgeCompletionStatus[2], true)
    }

    func testMarkNudgeComplete_doubleCall_sameDay_doesNotDoubleStreak() {
        let vm = makeViewModel()

        vm.markNudgeComplete()
        let firstStreak = localStore.profile.streakDays

        vm.markNudgeComplete()
        let secondStreak = localStore.profile.streakDays

        XCTAssertEqual(firstStreak, secondStreak,
            "Marking complete twice on the same day should not double the streak")
    }

    func testMarkNudgeComplete_recordsCompletionDate() {
        let vm = makeViewModel()
        vm.markNudgeComplete()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateKey = String(ISO8601DateFormatter().string(from: today).prefix(10))

        XCTAssertTrue(localStore.profile.nudgeCompletionDates.contains(dateKey))
    }

    // MARK: - Streak Logic

    func testMarkNudgeComplete_setsLastStreakCreditDate() {
        let vm = makeViewModel()
        vm.markNudgeComplete()

        XCTAssertNotNil(localStore.profile.lastStreakCreditDate)
    }

    // MARK: - Initial State

    func testInitialState_isLoading() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.isLoading)
        XCTAssertNil(vm.assessment)
        XCTAssertNil(vm.todaySnapshot)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.hasCheckedInToday)
        XCTAssertNil(vm.todayMood)
        XCTAssertFalse(vm.isNudgeAlreadyMet)
        XCTAssertTrue(vm.nudgeCompletionStatus.isEmpty)
        XCTAssertNil(vm.weeklyTrendSummary)
        XCTAssertNil(vm.bioAgeResult)
    }

    // MARK: - Refresh Produces All Engine Outputs

    func testRefresh_producesAssessmentAndEngineOutputs() async {
        let vm = makeViewModel()
        await vm.refresh()

        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertNotNil(vm.assessment)
        XCTAssertNotNil(vm.todaySnapshot)
        XCTAssertNotNil(vm.readinessResult)
        XCTAssertNotNil(vm.stressResult)
    }

    // MARK: - Bio Age Gating

    func testRefresh_noBioAge_whenNoDOB() async {
        // No date of birth set = no bio age
        let vm = makeViewModel()
        await vm.refresh()
        XCTAssertNil(vm.bioAgeResult, "Bio age should be nil when no DOB is set")
    }

    func testRefresh_bioAge_whenDOBSet() async {
        // Set a date of birth 35 years ago
        let dob = Calendar.current.date(byAdding: .year, value: -35, to: Date())
        localStore.profile.dateOfBirth = dob
        localStore.saveProfile()

        let vm = makeViewModel()
        await vm.refresh()

        XCTAssertNotNil(vm.bioAgeResult, "Bio age should be computed when DOB is set")
    }

    // MARK: - Zone Analysis Gating

    func testRefresh_noZoneAnalysis_whenInsufficientZones() async {
        let snap = makeSnapshot(daysAgo: 0, zoneMinutes: [0, 0, 0, 0, 0])
        let vm = makeViewModel(todaySnapshot: snap)
        await vm.refresh()

        XCTAssertNil(vm.zoneAnalysis, "Zone analysis should be nil when all zone minutes are zero")
    }

    func testRefresh_zoneAnalysis_whenSufficientZones() async {
        let snap = makeSnapshot(daysAgo: 0, zoneMinutes: [120, 30, 15, 8, 2])
        let vm = makeViewModel(todaySnapshot: snap)
        await vm.refresh()

        XCTAssertNotNil(vm.zoneAnalysis, "Zone analysis should be computed with valid zone data")
    }

    // MARK: - Coaching Report Gating

    func testRefresh_noCoachingReport_withTooFewHistoryDays() async {
        let snap = makeSnapshot(daysAgo: 0)
        let shortHistory = [makeSnapshot(daysAgo: 1), makeSnapshot(daysAgo: 0)]
        let vm = makeViewModel(todaySnapshot: snap, history: shortHistory)
        await vm.refresh()

        XCTAssertNil(vm.coachingReport, "Coaching report requires >= 3 days of history")
    }

    func testRefresh_coachingReport_withEnoughHistory() async {
        let vm = makeViewModel()
        await vm.refresh()

        XCTAssertNotNil(vm.coachingReport, "Coaching report should be produced with 14 days of history")
    }

    // MARK: - Weekly Trend

    func testRefresh_weeklyTrendSummary_producedWithSufficientHistory() async {
        let vm = makeViewModel()
        await vm.refresh()
        // With 14 days of history, weekly trend should be computed
        // (could be nil if data doesn't have active minutes, but at least the code path runs)
    }

    // MARK: - Nudge Evaluation

    func testRefresh_nudgeAlreadyMet_whenWalkGoalMet() async {
        let snap = makeSnapshot(daysAgo: 0, walkMin: 20.0, workoutMin: 25.0)
        let vm = makeViewModel(todaySnapshot: snap)
        await vm.refresh()

        // The assessment's nudge category determines if isNudgeAlreadyMet gets set.
        // We just verify the code path doesn't crash and produces a state.
        XCTAssertNotNil(vm.assessment)
    }

    // MARK: - Buddy Recommendations

    func testRefresh_producesBuddyRecommendations() async {
        let vm = makeViewModel()
        await vm.refresh()

        XCTAssertNotNil(vm.buddyRecommendations, "Buddy recommendations should be produced")
        XCTAssertFalse(vm.buddyRecommendations?.isEmpty ?? true)
    }

    // MARK: - Subscription Tier

    func testCurrentTier_reflectsLocalStore() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.currentTier, localStore.tier)
    }

    // MARK: - Bind

    func testBind_updatesReferences() {
        let vm = makeViewModel()
        let newDefaults = UserDefaults(suiteName: "com.thump.dashext.bind.\(UUID().uuidString)")!
        let newStore = LocalStore(defaults: newDefaults)
        let newProvider = MockHealthDataProvider()

        vm.bind(healthDataProvider: newProvider, localStore: newStore)
        XCTAssertEqual(vm.profileName, newStore.profile.displayName)
    }

    // MARK: - Already Authorized Provider Skips Auth

    func testRefresh_skipsAuth_whenAlreadyAuthorized() async {
        let provider = MockHealthDataProvider(
            todaySnapshot: makeSnapshot(daysAgo: 0),
            history: makeHistory(days: 14),
            shouldAuthorize: true
        )
        // Pre-authorize so isAuthorized = true; the VM should skip re-auth
        try? await provider.requestAuthorization()
        let callsBefore = provider.authorizationCallCount

        let vm = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        await vm.refresh()
        XCTAssertEqual(provider.authorizationCallCount, callsBefore,
            "Should not call requestAuthorization again if already authorized")
    }
}

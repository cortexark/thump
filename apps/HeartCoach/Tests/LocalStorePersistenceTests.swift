// LocalStorePersistenceTests.swift
// ThumpCoreTests
//
// Tests for LocalStore persistence: check-in round-trips, feedback
// preferences, profile save/load, history append/load, and edge cases
// for empty stores.

import XCTest
@testable import Thump

final class LocalStorePersistenceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: LocalStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.thump.localstore.\(UUID().uuidString)")!
        store = LocalStore(defaults: defaults)
    }

    override func tearDown() {
        defaults = nil
        store = nil
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    // MARK: - Check-In

    func testCheckIn_saveAndLoadToday() {
        let response = CheckInResponse(date: Date(), feelingScore: 3, note: "Good day")
        store.saveCheckIn(response)

        let loaded = store.loadTodayCheckIn()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.feelingScore, 3)
        XCTAssertEqual(loaded?.note, "Good day")
    }

    func testCheckIn_loadToday_nilWhenNoneSaved() {
        let loaded = store.loadTodayCheckIn()
        XCTAssertNil(loaded)
    }

    func testCheckIn_loadToday_nilWhenSavedYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let response = CheckInResponse(date: yesterday, feelingScore: 2, note: nil)
        store.saveCheckIn(response)

        let loaded = store.loadTodayCheckIn()
        XCTAssertNil(loaded, "Check-in from yesterday should not be returned as today's")
    }

    // MARK: - Feedback Preferences

    func testFeedbackPreferences_defaultsAllEnabled() {
        let prefs = store.loadFeedbackPreferences()
        XCTAssertTrue(prefs.showBuddySuggestions)
        XCTAssertTrue(prefs.showDailyCheckIn)
        XCTAssertTrue(prefs.showStressInsights)
        XCTAssertTrue(prefs.showWeeklyTrends)
        XCTAssertTrue(prefs.showStreakBadge)
    }

    func testFeedbackPreferences_roundTrip() {
        var prefs = FeedbackPreferences()
        prefs.showBuddySuggestions = false
        prefs.showStressInsights = false
        store.saveFeedbackPreferences(prefs)

        let loaded = store.loadFeedbackPreferences()
        XCTAssertFalse(loaded.showBuddySuggestions)
        XCTAssertFalse(loaded.showStressInsights)
        XCTAssertTrue(loaded.showDailyCheckIn)
    }

    // MARK: - Profile

    func testProfile_saveAndLoad() {
        store.profile.displayName = "TestUser"
        store.profile.streakDays = 5
        store.profile.biologicalSex = .female
        store.saveProfile()

        // Create a new store with same defaults to verify persistence
        let store2 = LocalStore(defaults: defaults)
        XCTAssertEqual(store2.profile.displayName, "TestUser")
        XCTAssertEqual(store2.profile.streakDays, 5)
        XCTAssertEqual(store2.profile.biologicalSex, .female)
    }

    func testProfile_defaultValues() {
        XCTAssertEqual(store.profile.displayName, "")
        XCTAssertFalse(store.profile.onboardingComplete)
        XCTAssertEqual(store.profile.streakDays, 0)
        XCTAssertNil(store.profile.dateOfBirth)
        XCTAssertEqual(store.profile.biologicalSex, .notSet)
    }

    // MARK: - History

    func testHistory_emptyByDefault() {
        let history = store.loadHistory()
        XCTAssertTrue(history.isEmpty)
    }

    func testHistory_appendAndLoad() {
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
            workoutMinutes: 20.0,
            sleepHours: 7.5
        )
        let stored = StoredSnapshot(snapshot: snapshot, assessment: nil)
        store.appendSnapshot(stored)

        let history = store.loadHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.snapshot.restingHeartRate, 64.0)
    }

    func testHistory_appendMultiple() {
        for i in 0..<5 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let snapshot = HeartSnapshot(
                date: date,
                restingHeartRate: 60.0 + Double(i)
            )
            store.appendSnapshot(StoredSnapshot(snapshot: snapshot))
        }

        let history = store.loadHistory()
        XCTAssertEqual(history.count, 5)
    }

    // MARK: - Feedback Payload

    func testFeedbackPayload_saveAndLoad() {
        let payload = WatchFeedbackPayload(
            date: Date(),
            response: .positive,
            source: "test"
        )
        store.saveLastFeedback(payload)

        let loaded = store.loadLastFeedback()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.response, .positive)
        XCTAssertEqual(loaded?.source, "test")
    }

    func testFeedbackPayload_nilWhenNoneSaved() {
        let loaded = store.loadLastFeedback()
        XCTAssertNil(loaded)
    }

    // MARK: - Tier

    func testTier_defaultIsFree() {
        XCTAssertEqual(store.tier, .free)
    }
}

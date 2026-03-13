// LocalStoreEncryptionTests.swift
// ThumpCoreTests
//
// LocalStore persistence coverage aligned to the current shared data model.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import Thump

final class LocalStoreEncryptionTests: XCTestCase {

    private var store: LocalStore?
    private var testDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(
            suiteName: "com.thump.test.\(UUID().uuidString)"
        )
        store = testDefaults.map { LocalStore(defaults: $0) }
    }

    override func tearDown() {
        store = nil
        testDefaults = nil
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    func testProfileSaveReloadRoundTrip() throws {
        let store = try XCTUnwrap(store)
        let testDefaults = try XCTUnwrap(testDefaults)
        store.profile = UserProfile(
            displayName: "Test User",
            joinDate: Date(timeIntervalSince1970: 1_700_000_000),
            onboardingComplete: true,
            streakDays: 7
        )
        store.saveProfile()

        let reloadedStore = LocalStore(defaults: testDefaults)
        XCTAssertEqual(reloadedStore.profile.displayName, "Test User")
        XCTAssertEqual(reloadedStore.profile.onboardingComplete, true)
        XCTAssertEqual(reloadedStore.profile.streakDays, 7)
    }

    func testHistorySaveLoadRoundTrip() throws {
        let store = try XCTUnwrap(store)
        let stored = makeStoredSnapshot(
            restingHeartRate: 62.0,
            hrv: 55.0,
            steps: 8500.0
        )

        store.saveHistory([stored])
        let loaded = store.loadHistory()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.snapshot.restingHeartRate, 62.0)
        XCTAssertEqual(loaded.first?.snapshot.hrvSDNN, 55.0)
        XCTAssertEqual(loaded.first?.snapshot.steps, 8500.0)
        XCTAssertEqual(loaded.first?.assessment?.status, .stable)
    }

    func testHistoryTrimsToMaxSnapshots() throws {
        let store = try XCTUnwrap(store)
        let snapshots = (0..<400).map { offset in
            makeStoredSnapshot(
                date: Date().addingTimeInterval(
                    TimeInterval(-offset * 86_400)
                ),
                restingHeartRate: 60.0 + Double(offset % 10)
            )
        }

        store.saveHistory(snapshots)

        XCTAssertEqual(
            store.loadHistory().count,
            ConfigService.maxStoredSnapshots
        )
    }

    func testAlertMetaSaveReloadRoundTrip() throws {
        let store = try XCTUnwrap(store)
        let testDefaults = try XCTUnwrap(testDefaults)
        store.alertMeta = AlertMeta(
            lastAlertAt: Date(timeIntervalSince1970: 1_700_000_100),
            alertsToday: 2,
            alertsDayStamp: "2026-03-10"
        )
        store.saveAlertMeta()

        let reloadedStore = LocalStore(defaults: testDefaults)
        XCTAssertEqual(reloadedStore.alertMeta.alertsToday, 2)
        XCTAssertEqual(
            reloadedStore.alertMeta.alertsDayStamp,
            "2026-03-10"
        )
    }

    func testTierSaveReloadRoundTrip() throws {
        let store = try XCTUnwrap(store)
        let testDefaults = try XCTUnwrap(testDefaults)
        store.tier = .coach
        store.saveTier()

        let reloadedStore = LocalStore(defaults: testDefaults)
        XCTAssertEqual(reloadedStore.tier, .coach)
    }

    func testFeedbackSaveLoadRoundTrip() throws {
        let store = try XCTUnwrap(store)
        let payload = WatchFeedbackPayload(
            eventId: "test-event-001",
            date: Date(timeIntervalSince1970: 1_700_000_200),
            response: .positive,
            source: "watch"
        )

        store.saveLastFeedback(payload)
        let loaded = store.loadLastFeedback()

        XCTAssertEqual(loaded?.eventId, "test-event-001")
        XCTAssertEqual(loaded?.response, .positive)
        XCTAssertEqual(loaded?.source, "watch")
    }

    func testClearAllResetsEverything() throws {
        let store = try XCTUnwrap(store)
        store.profile = UserProfile(
            displayName: "ToDelete",
            onboardingComplete: true,
            streakDays: 3
        )
        store.saveProfile()
        store.tier = .family
        store.saveTier()
        store.saveHistory([makeStoredSnapshot()])
        store.saveLastFeedback(
            WatchFeedbackPayload(
                date: Date(),
                response: .negative,
                source: "watch"
            )
        )

        store.clearAll()

        // After clearAll, profile should be reset to defaults (joinDate will differ by ms)
        XCTAssertEqual(store.profile.displayName, "")
        XCTAssertFalse(store.profile.onboardingComplete)
        XCTAssertEqual(store.profile.streakDays, 0)
        XCTAssertEqual(store.tier, .free)
        XCTAssertEqual(store.alertMeta, AlertMeta())
        XCTAssertTrue(store.loadHistory().isEmpty)
        XCTAssertNil(store.loadLastFeedback())
    }

    func testAppendSnapshotAddsToHistory() throws {
        let store = try XCTUnwrap(store)
        store.appendSnapshot(
            makeStoredSnapshot(date: Date(), restingHeartRate: 60.0)
        )
        store.appendSnapshot(
            makeStoredSnapshot(
                date: Date().addingTimeInterval(86_400),
                restingHeartRate: 62.0
            )
        )

        let loaded = store.loadHistory()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.last?.snapshot.restingHeartRate, 62.0)
    }

    private func makeStoredSnapshot(
        date: Date = Date(),
        restingHeartRate: Double = 62.0,
        hrv: Double = 55.0,
        steps: Double = 8_500.0
    ) -> StoredSnapshot {
        let snapshot = HeartSnapshot(
            date: date,
            restingHeartRate: restingHeartRate,
            hrvSDNN: hrv,
            recoveryHR1m: 28.0,
            recoveryHR2m: 42.0,
            vo2Max: 42.0,
            zoneMinutes: [120, 25, 10, 4, 1],
            steps: steps,
            walkMinutes: 35.0,
            workoutMinutes: 45.0,
            sleepHours: 7.5
        )

        let assessment = HeartAssessment(
            status: .stable,
            confidence: .high,
            anomalyScore: 0.4,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: 70.0,
            dailyNudge: DailyNudge(
                category: .walk,
                title: "Keep Moving",
                description: "A short walk will help maintain your baseline.",
                durationMinutes: 10,
                icon: "figure.walk"
            ),
            explanation: "Metrics are within your recent baseline."
        )

        return StoredSnapshot(snapshot: snapshot, assessment: assessment)
    }
}

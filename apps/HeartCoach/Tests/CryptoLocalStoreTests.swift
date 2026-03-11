// swiftlint:disable single_test_class
// CryptoLocalStoreTests.swift
// ThumpCoreTests
//
// Encryption and LocalStore persistence coverage aligned to the current
// shared data model.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import ThumpCore

final class CryptoServiceTests: XCTestCase {

    override func tearDown() {
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    func testEncryptDecryptRoundTrip() throws {
        let original = Data("Hello, Thump!".utf8)
        let encrypted = try CryptoService.encrypt(original)
        let decrypted = try CryptoService.decrypt(encrypted)
        XCTAssertEqual(decrypted, original)
    }

    func testEncryptProducesDifferentCiphertexts() throws {
        let data = Data("Deterministic input".utf8)
        let encrypted1 = try CryptoService.encrypt(data)
        let encrypted2 = try CryptoService.encrypt(data)
        XCTAssertNotEqual(encrypted1, encrypted2)
    }

    func testTamperedCiphertextFailsDecryption() throws {
        var encrypted = try CryptoService.encrypt(Data("Sensitive".utf8))
        encrypted[encrypted.count / 2] ^= 0xFF

        XCTAssertThrowsError(try CryptoService.decrypt(encrypted))
    }
}

final class LocalStoreEncryptionTests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional
    private var store: LocalStore!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // swiftlint:disable:next force_unwrapping
        testDefaults = UserDefaults(suiteName: "com.thump.test.\(UUID().uuidString)")!
        store = LocalStore(defaults: testDefaults)
    }

    override func tearDown() {
        store = nil
        testDefaults = nil
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    func testProfileSaveReloadRoundTrip() {
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

    func testHistorySaveLoadRoundTrip() {
        let stored = makeStoredSnapshot(restingHeartRate: 62.0, hrv: 55.0, steps: 8500.0)

        store.saveHistory([stored])
        let loaded = store.loadHistory()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.snapshot.restingHeartRate, 62.0)
        XCTAssertEqual(loaded.first?.snapshot.hrvSDNN, 55.0)
        XCTAssertEqual(loaded.first?.snapshot.steps, 8500.0)
        XCTAssertEqual(loaded.first?.assessment?.status, .stable)
    }

    func testHistoryTrimsToMaxSnapshots() {
        let snapshots = (0..<400).map { offset in
            makeStoredSnapshot(
                date: Date().addingTimeInterval(TimeInterval(-offset * 86_400)),
                restingHeartRate: 60.0 + Double(offset % 10)
            )
        }

        store.saveHistory(snapshots)

        XCTAssertEqual(store.loadHistory().count, ConfigService.maxStoredSnapshots)
    }

    func testAlertMetaSaveReloadRoundTrip() {
        store.alertMeta = AlertMeta(
            lastAlertAt: Date(timeIntervalSince1970: 1_700_000_100),
            alertsToday: 2,
            alertsDayStamp: "2026-03-10"
        )
        store.saveAlertMeta()

        let reloadedStore = LocalStore(defaults: testDefaults)
        XCTAssertEqual(reloadedStore.alertMeta.alertsToday, 2)
        XCTAssertEqual(reloadedStore.alertMeta.alertsDayStamp, "2026-03-10")
    }

    func testTierSaveReloadRoundTrip() {
        store.tier = .coach
        store.saveTier()

        let reloadedStore = LocalStore(defaults: testDefaults)
        XCTAssertEqual(reloadedStore.tier, .coach)
    }

    func testFeedbackSaveLoadRoundTrip() {
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

    func testClearAllResetsEverything() {
        store.profile = UserProfile(displayName: "ToDelete", onboardingComplete: true, streakDays: 3)
        store.saveProfile()
        store.tier = .family
        store.saveTier()
        store.saveHistory([makeStoredSnapshot()])
        store.saveLastFeedback(
            WatchFeedbackPayload(date: Date(), response: .negative, source: "watch")
        )

        store.clearAll()

        XCTAssertEqual(store.profile, UserProfile())
        XCTAssertEqual(store.tier, .free)
        XCTAssertEqual(store.alertMeta, AlertMeta())
        XCTAssertTrue(store.loadHistory().isEmpty)
        XCTAssertNil(store.loadLastFeedback())
    }

    func testAppendSnapshotAddsToHistory() {
        store.appendSnapshot(makeStoredSnapshot(date: Date(), restingHeartRate: 60.0))
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

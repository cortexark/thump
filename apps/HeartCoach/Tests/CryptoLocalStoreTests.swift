// CryptoLocalStoreTests.swift
// ThumpCoreTests
//
// Encryption round-trip tests for CryptoService and LocalStore.
// Validates that data encrypted by CryptoService can be decrypted
// back to its original form, and that LocalStore correctly persists
// and retrieves encrypted data through the full encode-encrypt-decrypt-decode cycle.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import ThumpCore

// MARK: - CryptoService Round-Trip Tests

final class CryptoServiceTests: XCTestCase {

    // MARK: - Encrypt/Decrypt Round-Trip

    /// Encrypting then decrypting should return the original data unchanged.
    func testEncryptDecryptRoundTrip() throws {
        let original = "Hello, Thump!".data(using: .utf8)!
        let encrypted = try CryptoService.encrypt(original)
        let decrypted = try CryptoService.decrypt(encrypted)
        XCTAssertEqual(decrypted, original, "Decrypted data should match original")
    }

    /// Encrypting the same data twice should produce different ciphertexts
    /// (AES-GCM uses a random nonce each time).
    func testEncryptProducesDifferentCiphertexts() throws {
        let data = "Deterministic input".data(using: .utf8)!
        let encrypted1 = try CryptoService.encrypt(data)
        let encrypted2 = try CryptoService.encrypt(data)
        XCTAssertNotEqual(encrypted1, encrypted2,
            "Two encryptions of the same data should produce different ciphertexts due to random nonce")
    }

    /// Empty data should encrypt and decrypt cleanly.
    func testEmptyDataRoundTrip() throws {
        let empty = Data()
        let encrypted = try CryptoService.encrypt(empty)
        let decrypted = try CryptoService.decrypt(encrypted)
        XCTAssertEqual(decrypted, empty, "Empty data round-trip should work")
    }

    /// Large data (1 MB) should encrypt and decrypt without issues.
    func testLargeDataRoundTrip() throws {
        let largeData = Data(repeating: 0xAB, count: 1_000_000)
        let encrypted = try CryptoService.encrypt(largeData)
        let decrypted = try CryptoService.decrypt(encrypted)
        XCTAssertEqual(decrypted, largeData, "1 MB data round-trip should work")
    }

    /// Encrypted data should be larger than the original
    /// (nonce + tag overhead from AES-GCM combined format).
    func testEncryptedDataIsLargerThanOriginal() throws {
        let data = "Short message".data(using: .utf8)!
        let encrypted = try CryptoService.encrypt(data)
        // AES-GCM combined = 12-byte nonce + ciphertext + 16-byte tag = +28 bytes
        XCTAssertGreaterThan(encrypted.count, data.count,
            "Encrypted data should be larger due to nonce + tag overhead")
        XCTAssertEqual(encrypted.count, data.count + 28,
            "AES-GCM combined overhead should be exactly 28 bytes (12 nonce + 16 tag)")
    }

    /// Tampered ciphertext should fail decryption (authentication check).
    func testTamperedCiphertextFailsDecryption() throws {
        let data = "Sensitive health data".data(using: .utf8)!
        var encrypted = try CryptoService.encrypt(data)

        // Flip a byte in the middle of the ciphertext
        let midpoint = encrypted.count / 2
        encrypted[midpoint] ^= 0xFF

        XCTAssertThrowsError(try CryptoService.decrypt(encrypted),
            "Tampered ciphertext should fail authentication") { error in
            XCTAssertTrue(error is CryptoServiceError,
                "Error should be a CryptoServiceError")
        }
    }

    /// Truncated ciphertext should fail decryption.
    func testTruncatedCiphertextFailsDecryption() {
        let truncated = Data(repeating: 0x00, count: 10) // Too short for valid AES-GCM
        XCTAssertThrowsError(try CryptoService.decrypt(truncated),
            "Truncated data should fail decryption")
    }
}

// MARK: - LocalStore Encryption Integration Tests

final class LocalStoreEncryptionTests: XCTestCase {

    // MARK: - Properties

    private var store: LocalStore!
    private var testDefaults: UserDefaults!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        // Use a dedicated suite to avoid polluting standard defaults
        testDefaults = UserDefaults(suiteName: "com.thump.test.\(UUID().uuidString)")!
        store = LocalStore(defaults: testDefaults)
    }

    override func tearDown() {
        // Clean up the test suite
        if let suiteName = testDefaults.volatileDomainNames.first {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        store = nil
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Profile Persistence

    /// Saving and reloading a profile should preserve all fields through encryption.
    func testProfileSaveReloadRoundTrip() {
        store.profile = UserProfile(
            displayName: "Test User",
            birthYear: 1990,
            biologicalSex: .male,
            heightCm: 180.0,
            weightKg: 75.0
        )
        store.saveProfile()

        // Create a new store instance from same defaults (simulates app restart)
        let reloadedStore = LocalStore(defaults: testDefaults)
        XCTAssertEqual(reloadedStore.profile.displayName, "Test User")
        XCTAssertEqual(reloadedStore.profile.birthYear, 1990)
    }

    // MARK: - Snapshot History Persistence

    /// Saving and loading history should preserve all snapshot fields.
    func testHistorySaveLoadRoundTrip() {
        let snapshot = StoredSnapshot(
            date: Date(),
            restingHeartRate: 62.0,
            hrvSDNN: 55.0,
            vo2Max: 42.0,
            recoveryHR1m: 28.0,
            steps: 8500.0,
            walkMinutes: 35.0,
            activeEnergy: 450.0,
            sleepHours: 7.5,
            workoutMinutes: 45.0
        )

        store.saveHistory([snapshot])
        let loaded = store.loadHistory()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.restingHeartRate, 62.0)
        XCTAssertEqual(loaded.first?.hrvSDNN, 55.0)
        XCTAssertEqual(loaded.first?.steps, 8500.0)
    }

    /// History should be trimmed to maxStoredSnapshots.
    func testHistoryTrimsToMaxSnapshots() {
        let snapshots = (0..<400).map { i in
            StoredSnapshot(
                date: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                restingHeartRate: 60.0 + Double(i % 10)
            )
        }

        store.saveHistory(snapshots)
        let loaded = store.loadHistory()

        XCTAssertEqual(loaded.count, ConfigService.maxStoredSnapshots,
            "History should be trimmed to maxStoredSnapshots (\(ConfigService.maxStoredSnapshots))")
    }

    // MARK: - Alert Meta Persistence

    /// Alert meta should persist through encryption round-trip.
    func testAlertMetaSaveReloadRoundTrip() {
        store.alertMeta = AlertMeta(
            lastAlertDate: Date(),
            alertCountToday: 2
        )
        store.saveAlertMeta()

        let reloadedStore = LocalStore(defaults: testDefaults)
        XCTAssertEqual(reloadedStore.alertMeta.alertCountToday, 2)
    }

    // MARK: - Subscription Tier Persistence

    /// Tier should round-trip through save/reload.
    func testTierSaveReloadRoundTrip() {
        store.tier = .coach
        store.saveTier()

        let reloadedStore = LocalStore(defaults: testDefaults)
        XCTAssertEqual(reloadedStore.tier, .coach)
    }

    /// Free tier should be the default when no tier is stored.
    func testDefaultTierIsFree() {
        let freshStore = LocalStore(defaults: UserDefaults(suiteName: "com.thump.test.fresh.\(UUID().uuidString)")!)
        XCTAssertEqual(freshStore.tier, .free)
    }

    // MARK: - Feedback Persistence

    /// Last feedback payload should persist through encryption.
    func testFeedbackSaveLoadRoundTrip() {
        let payload = WatchFeedbackPayload(
            eventId: "test-event-001",
            date: Date(),
            response: .good
        )

        store.saveLastFeedback(payload)
        let loaded = store.loadLastFeedback()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.eventId, "test-event-001")
        XCTAssertEqual(loaded?.response, .good)
    }

    // MARK: - Clear All

    /// clearAll should reset all stored data.
    func testClearAllResetsEverything() {
        store.profile = UserProfile(displayName: "ToDelete")
        store.saveProfile()
        store.tier = .family
        store.saveTier()

        store.clearAll()

        XCTAssertEqual(store.profile.displayName, UserProfile().displayName)
        XCTAssertEqual(store.tier, .free)
        XCTAssertTrue(store.loadHistory().isEmpty)
        XCTAssertNil(store.loadLastFeedback())
    }

    // MARK: - Append Snapshot

    /// appendSnapshot should add to existing history.
    func testAppendSnapshotAddsToHistory() {
        let snapshot1 = StoredSnapshot(date: Date(), restingHeartRate: 60.0)
        let snapshot2 = StoredSnapshot(date: Date().addingTimeInterval(86400), restingHeartRate: 62.0)

        store.appendSnapshot(snapshot1)
        store.appendSnapshot(snapshot2)

        let loaded = store.loadHistory()
        XCTAssertEqual(loaded.count, 2)
    }
}

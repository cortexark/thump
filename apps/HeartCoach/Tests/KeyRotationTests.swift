// KeyRotationTests.swift
// ThumpCoreTests
//
// Tests for CryptoService key rotation behavior.
// Validates that deleting the encryption key and creating a new one
// correctly handles the transition, and that data encrypted with the
// old key becomes unreadable after rotation (expected behavior).
//
// Driven by: SKILL_QA_TEST_PLAN + SKILL_SEC_DATA_HANDLING (orchestrator v0.2.0)
// Addresses: SIM_005/SIM_006 key rotation failure scenarios
// Acceptance: Key rotation tests pass; old-key data fails decryption; new-key data succeeds.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import ThumpCore

// MARK: - Key Rotation Tests

final class KeyRotationTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func tearDown() {
        // Clean up any test keys from Keychain
        try? CryptoService.deleteKey()
        super.tearDown()
    }

    // MARK: - Key Deletion

    /// After deleting the key, encrypting with a new key should work.
    func testDeleteKeyThenEncryptCreatesNewKey() throws {
        // Encrypt with initial key
        let data = "before rotation".data(using: .utf8)!
        let _ = try CryptoService.encrypt(data)

        // Delete the key (simulates rotation step 1)
        try CryptoService.deleteKey()

        // Encrypt with new key (auto-generated)
        let newData = "after rotation".data(using: .utf8)!
        let encrypted = try CryptoService.encrypt(newData)
        let decrypted = try CryptoService.decrypt(encrypted)
        XCTAssertEqual(decrypted, newData,
            "Data encrypted after key rotation should decrypt with the new key")
    }

    /// Data encrypted with the old key should NOT decrypt after key rotation.
    /// This validates that key rotation is a destructive operation — data must
    /// be re-encrypted before the old key is deleted.
    func testOldKeyDataFailsAfterRotation() throws {
        // Encrypt with initial key
        let data = "sensitive health data".data(using: .utf8)!
        let encryptedWithOldKey = try CryptoService.encrypt(data)

        // Verify it decrypts with the old key
        let decrypted = try CryptoService.decrypt(encryptedWithOldKey)
        XCTAssertEqual(decrypted, data, "Sanity check: old-key data decrypts before rotation")

        // Rotate: delete old key → new key auto-generated on next encrypt
        try CryptoService.deleteKey()
        let _ = try CryptoService.encrypt("trigger new key".data(using: .utf8)!)

        // Attempt to decrypt old-key data with new key — should fail
        XCTAssertThrowsError(try CryptoService.decrypt(encryptedWithOldKey)) { error in
            // CryptoKit throws when AES-GCM authentication fails
            // (wrong key = different auth tag)
            XCTAssertTrue(
                error is CryptoServiceError,
                "Decrypting old-key data with new key should throw CryptoServiceError, got: \(error)"
            )
        }
    }

    /// Simulates the correct key rotation flow: re-encrypt all data before deleting old key.
    func testCorrectKeyRotationReencryptsData() throws {
        // Step 1: Encrypt multiple records with current key
        let records = [
            "heart rate: 72 bpm",
            "hrv: 45 ms",
            "steps: 8500"
        ].map { $0.data(using: .utf8)! }

        var encryptedRecords = try records.map { try CryptoService.encrypt($0) }

        // Step 2: Re-encrypt all records with current key (before rotation)
        // In a real rotation flow, you'd:
        //   a) Decrypt each record with old key
        //   b) Re-encrypt with new key
        //   c) Only then delete old key
        // But since we haven't rotated yet, decrypting still works
        let decryptedRecords = try encryptedRecords.map { try CryptoService.decrypt($0) }

        // Step 3: Delete old key (rotate)
        try CryptoService.deleteKey()

        // Step 4: Re-encrypt with new key
        encryptedRecords = try decryptedRecords.map { try CryptoService.encrypt($0) }

        // Step 5: Verify all records decrypt correctly with new key
        for (index, encrypted) in encryptedRecords.enumerated() {
            let decrypted = try CryptoService.decrypt(encrypted)
            XCTAssertEqual(decrypted, records[index],
                "Record \(index) should round-trip through key rotation")
        }
    }

    /// Verifies that multiple key rotations in sequence don't corrupt data
    /// when the correct re-encryption flow is followed.
    func testMultipleRotationsPreserveData() throws {
        let original = "persistent health snapshot".data(using: .utf8)!
        var currentEncrypted = try CryptoService.encrypt(original)

        // Perform 3 sequential rotations
        for rotation in 1...3 {
            // Decrypt with current key
            let decrypted = try CryptoService.decrypt(currentEncrypted)
            XCTAssertEqual(decrypted, original,
                "Data should be readable before rotation \(rotation)")

            // Rotate key
            try CryptoService.deleteKey()

            // Re-encrypt with new key
            currentEncrypted = try CryptoService.encrypt(decrypted)
        }

        // Final verification
        let finalDecrypted = try CryptoService.decrypt(currentEncrypted)
        XCTAssertEqual(finalDecrypted, original,
            "Data should survive 3 sequential key rotations with proper re-encryption")
    }

    /// Verifies the record count is preserved during rotation
    /// (addresses SIM_006 partial re-encryption scenario).
    func testRotationPreservesRecordCount() throws {
        // Create 10 records
        let recordCount = 10
        let records = (0..<recordCount).map {
            "record_\($0)".data(using: .utf8)!
        }
        var encryptedRecords = try records.map { try CryptoService.encrypt($0) }

        // Decrypt all
        let decryptedRecords = try encryptedRecords.map { try CryptoService.decrypt($0) }
        XCTAssertEqual(decryptedRecords.count, recordCount,
            "All records should decrypt before rotation")

        // Rotate
        try CryptoService.deleteKey()

        // Re-encrypt all
        let reencryptedRecords = try decryptedRecords.map { try CryptoService.encrypt($0) }
        XCTAssertEqual(reencryptedRecords.count, recordCount,
            "Record count must be preserved after rotation")

        // Verify all records
        for (index, encrypted) in reencryptedRecords.enumerated() {
            let decrypted = try CryptoService.decrypt(encrypted)
            XCTAssertEqual(decrypted, records[index],
                "Record \(index) content must be preserved after rotation")
        }
    }

    /// deleteKey() is idempotent — calling it when no key exists should not throw.
    func testDeleteKeyIdempotent() throws {
        // Ensure a key exists
        let _ = try CryptoService.encrypt(Data([0x01]))

        // First delete — should succeed
        try CryptoService.deleteKey()

        // Second delete — should not throw (errSecItemNotFound is acceptable)
        XCTAssertNoThrow(try CryptoService.deleteKey(),
            "Deleting a non-existent key should not throw")
    }
}

// CryptoService.swift
// ThumpCore
//
// AES-GCM encryption layer for health data at rest.
// Symmetric key is generated on first use and persisted
// in the iOS/macOS Keychain via the Security framework.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation
import CryptoKit

// MARK: - Crypto Errors

/// Errors that can occur during encryption or decryption operations.
public enum CryptoServiceError: LocalizedError {
    case keyGenerationFailed
    case keychainSaveFailed(status: OSStatus)
    case keychainReadFailed(status: OSStatus)
    case keychainDeleteFailed(status: OSStatus)
    case encryptionFailed(underlying: Error)
    case decryptionFailed(underlying: Error)
    case invalidKeyData

    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "[CryptoService] Failed to generate symmetric key."
        case .keychainSaveFailed(let status):
            return "[CryptoService] Keychain save failed with status \(status)."
        case .keychainReadFailed(let status):
            return "[CryptoService] Keychain read failed with status \(status)."
        case .keychainDeleteFailed(let status):
            return "[CryptoService] Keychain delete failed with status \(status)."
        case .encryptionFailed(let error):
            return "[CryptoService] Encryption failed: \(error.localizedDescription)"
        case .decryptionFailed(let error):
            return "[CryptoService] Decryption failed: \(error.localizedDescription)"
        case .invalidKeyData:
            return "[CryptoService] Key data retrieved from Keychain is invalid."
        }
    }
}

// MARK: - Crypto Service

/// Provides AES-GCM encryption and decryption using a Keychain-backed symmetric key.
///
/// The 256-bit symmetric key is generated once and stored in the device Keychain
/// under the identifier ``keychainIdentifier``. Subsequent launches retrieve the
/// existing key rather than creating a new one.
///
/// Usage:
/// ```swift
/// let ciphertext = try CryptoService.encrypt(plainData)
/// let plaintext  = try CryptoService.decrypt(ciphertext)
/// ```
public enum CryptoService {

    // MARK: - Constants

    /// Keychain item identifier for the AES-256 symmetric key.
    private static let keychainIdentifier = "com.thump.encryptionKey"

    /// Service name used in the Keychain query.
    private static let keychainService = "com.thump.CryptoService"

    /// Lock to serialize key retrieval/creation, preventing a race condition
    /// where concurrent first-launch calls could generate two different keys
    /// with one overwriting the other in the Keychain.
    private static let keyLock = NSLock()

    // MARK: - Public API

    /// Encrypt arbitrary `Data` using AES-GCM.
    ///
    /// The returned blob is the ``AES.GCM.SealedBox/combined`` representation,
    /// which includes the nonce, ciphertext, and authentication tag in a single
    /// contiguous buffer.
    ///
    /// - Parameter data: The plaintext data to encrypt.
    /// - Returns: The combined sealed-box data (nonce + ciphertext + tag).
    /// - Throws: ``CryptoServiceError`` if the key cannot be retrieved or
    ///   encryption fails.
    public static func encrypt(_ data: Data) throws -> Data {
        let key = try retrieveOrCreateKey()
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw CryptoServiceError.encryptionFailed(
                    underlying: NSError(
                        domain: "CryptoService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "SealedBox combined representation is nil."]
                    )
                )
            }
            return combined
        } catch let error as CryptoServiceError {
            throw error
        } catch {
            throw CryptoServiceError.encryptionFailed(underlying: error)
        }
    }

    /// Decrypt data that was previously encrypted with ``encrypt(_:)``.
    ///
    /// - Parameter data: The combined sealed-box data (nonce + ciphertext + tag).
    /// - Returns: The original plaintext data.
    /// - Throws: ``CryptoServiceError`` if the key cannot be retrieved or
    ///   decryption / authentication fails.
    public static func decrypt(_ data: Data) throws -> Data {
        let key = try retrieveOrCreateKey()
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch let error as CryptoServiceError {
            throw error
        } catch {
            throw CryptoServiceError.decryptionFailed(underlying: error)
        }
    }

    /// Delete the stored encryption key from the Keychain.
    ///
    /// Intended for account-reset / sign-out flows. After calling this,
    /// any data encrypted with the previous key becomes unrecoverable.
    ///
    /// - Throws: ``CryptoServiceError/keychainDeleteFailed(status:)``
    ///   if the Keychain operation fails.
    public static func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainIdentifier
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CryptoServiceError.keychainDeleteFailed(status: status)
        }
    }

    // MARK: - Key Management (Private)

    /// Retrieve the existing symmetric key from the Keychain, or generate
    /// and store a new one if no key exists yet.
    ///
    /// Serialized via `keyLock` to prevent a race condition where concurrent
    /// callers on first launch could each generate a different key, with the
    /// second overwriting the first in the Keychain and causing permanent
    /// data loss for anything encrypted with the first key.
    private static func retrieveOrCreateKey() throws -> SymmetricKey {
        keyLock.lock()
        defer { keyLock.unlock() }

        if let existing = try retrieveKey() {
            return existing
        }
        let newKey = SymmetricKey(size: .bits256)
        try storeKey(newKey)
        // Re-read from Keychain to ensure we use the actually-persisted key.
        // If storeKey hit errSecDuplicateItem (e.g. iCloud Keychain sync),
        // the persisted key may differ from newKey.
        if let persisted = try retrieveKey() {
            return persisted
        }
        return newKey
    }

    /// Attempt to read the raw key bytes from the Keychain.
    ///
    /// - Returns: The ``SymmetricKey`` if found, or `nil` if no entry exists.
    /// - Throws: ``CryptoServiceError/keychainReadFailed(status:)`` on
    ///   unexpected Keychain errors.
    private static func retrieveKey() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let keyData = result as? Data else {
                throw CryptoServiceError.invalidKeyData
            }
            return SymmetricKey(data: keyData)
        case errSecItemNotFound:
            return nil
        default:
            throw CryptoServiceError.keychainReadFailed(status: status)
        }
    }

    /// Persist the raw key bytes into the Keychain.
    ///
    /// - Throws: ``CryptoServiceError/keychainSaveFailed(status:)`` if the
    ///   Keychain write fails.
    private static func storeKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data(Array($0)) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainIdentifier,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // A key already exists — likely arrived via iCloud Keychain sync
            // between our retrieveKey() call and SecItemAdd. Use the existing
            // key rather than overwriting it (which would corrupt data
            // encrypted under the synced key).
            if let existingKey = try? retrieveKey() {
                // Existing key is valid — discard the locally generated one
                // and let retrieveOrCreateKey() re-read it.
                _ = existingKey
                return
            }
            // Re-read failed (corrupt entry) — overwrite as last resort.
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainIdentifier
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: keyData
            ]
            let updateStatus = SecItemUpdate(
                updateQuery as CFDictionary,
                attributes as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw CryptoServiceError.keychainSaveFailed(status: updateStatus)
            }
        } else if status != errSecSuccess {
            throw CryptoServiceError.keychainSaveFailed(status: status)
        }
    }
}

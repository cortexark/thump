// LocalStore.swift
// ThumpCore
//
// UserDefaults + JSON-based local persistence service.
// Stores user profile, snapshot history, alert metadata,
// subscription tier, and the last watch feedback payload.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation
import Combine
import CryptoKit

// MARK: - Storage Keys

/// Strongly-typed keys for UserDefaults entries managed by ``LocalStore``.
private enum StorageKey: String {
    case userProfile       = "com.thump.userProfile"
    case storedSnapshots   = "com.thump.storedSnapshots"
    case alertMeta         = "com.thump.alertMeta"
    case subscriptionTier  = "com.thump.subscriptionTier"
    case lastFeedback      = "com.thump.lastFeedback"
}

// MARK: - Local Store

/// Observable persistence layer backed by `UserDefaults` and `JSONEncoder` / `JSONDecoder`.
///
/// `LocalStore` publishes its most frequently accessed values so that
/// SwiftUI views can react to changes automatically. All reads and writes
/// are synchronous and performed on the caller's thread; `UserDefaults`
/// serialises internally.
///
/// Usage:
/// ```swift
/// let store = LocalStore()
/// store.profile.displayName = "Alex"
/// store.saveProfile()
/// ```
public final class LocalStore: ObservableObject {

    // MARK: - Published Properties

    /// The current user profile.
    @Published public var profile: UserProfile

    /// The active subscription tier.
    @Published public var tier: SubscriptionTier

    /// Alert-frequency metadata used by the alert throttle.
    @Published public var alertMeta: AlertMeta

    // MARK: - Private

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    /// Creates a new `LocalStore` backed by the given `UserDefaults` suite.
    ///
    /// - Parameter defaults: The `UserDefaults` instance to use.
    ///   Defaults to `.standard`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        // Hydrate published properties from disk
        self.profile = Self.load(
            UserProfile.self,
            key: .userProfile,
            defaults: defaults,
            decoder: dec
        ) ?? UserProfile()

        self.tier = Self.loadTier(defaults: defaults) ?? .free

        self.alertMeta = Self.load(
            AlertMeta.self,
            key: .alertMeta,
            defaults: defaults,
            decoder: dec
        ) ?? AlertMeta()
    }

    // MARK: - User Profile

    /// Persist the current ``profile`` to disk.
    public func saveProfile() {
        save(profile, key: .userProfile)
    }

    /// Reload ``profile`` from disk, discarding in-memory changes.
    public func reloadProfile() {
        if let loaded = Self.load(
            UserProfile.self,
            key: .userProfile,
            defaults: defaults,
            decoder: decoder
        ) {
            profile = loaded
        }
    }

    // MARK: - Stored Snapshots (History)

    /// Persist the full snapshot history array.
    ///
    /// - Parameter snapshots: The complete array of ``StoredSnapshot``
    ///   to persist. Older entries beyond ``ConfigService/maxStoredSnapshots``
    ///   are automatically trimmed.
    public func saveHistory(_ snapshots: [StoredSnapshot]) {
        let trimmed = Array(snapshots.suffix(ConfigService.maxStoredSnapshots))
        save(trimmed, key: .storedSnapshots)
    }

    /// Load the persisted snapshot history, or an empty array if none exists.
    public func loadHistory() -> [StoredSnapshot] {
        Self.load(
            [StoredSnapshot].self,
            key: .storedSnapshots,
            defaults: defaults,
            decoder: decoder
        ) ?? []
    }

    /// Append a single ``StoredSnapshot`` to the existing history.
    public func appendSnapshot(_ stored: StoredSnapshot) {
        var history = loadHistory()
        history.append(stored)
        saveHistory(history)
    }

    // MARK: - Alert Meta

    /// Persist the current ``alertMeta`` to disk.
    public func saveAlertMeta() {
        save(alertMeta, key: .alertMeta)
    }

    /// Reload ``alertMeta`` from disk.
    public func reloadAlertMeta() {
        if let loaded = Self.load(
            AlertMeta.self,
            key: .alertMeta,
            defaults: defaults,
            decoder: decoder
        ) {
            alertMeta = loaded
        }
    }

    // MARK: - Subscription Tier

    /// Persist the current ``tier`` to disk.
    public func saveTier() {
        defaults.set(tier.rawValue, forKey: StorageKey.subscriptionTier.rawValue)
    }

    /// Reload ``tier`` from disk.
    public func reloadTier() {
        if let loaded = Self.loadTier(defaults: defaults) {
            tier = loaded
        }
    }

    // MARK: - Last Feedback Payload

    /// Persist the most recent ``WatchFeedbackPayload``.
    public func saveLastFeedback(_ payload: WatchFeedbackPayload) {
        save(payload, key: .lastFeedback)
    }

    /// Load the most recent ``WatchFeedbackPayload``, if any.
    public func loadLastFeedback() -> WatchFeedbackPayload? {
        Self.load(
            WatchFeedbackPayload.self,
            key: .lastFeedback,
            defaults: defaults,
            decoder: decoder
        )
    }

    // MARK: - Danger Zone

    /// Remove all Thump data from UserDefaults.
    /// Intended for account-reset / sign-out flows.
    public func clearAll() {
        for key in [
            StorageKey.userProfile,
            .storedSnapshots,
            .alertMeta,
            .subscriptionTier,
            .lastFeedback
        ] {
            defaults.removeObject(forKey: key.rawValue)
        }
        profile = UserProfile()
        tier = .free
        alertMeta = AlertMeta()
    }

    // MARK: - Private Helpers

    /// Encode a `Codable` value, encrypt it, and write it to UserDefaults as `Data`.
    private func save<T: Encodable>(_ value: T, key: StorageKey) {
        do {
            let jsonData = try encoder.encode(value)
            let encrypted = try CryptoService.encrypt(jsonData)
            defaults.set(encrypted, forKey: key.rawValue)
        } catch {
            // Log the error so data loss is visible in production builds.
            // assertionFailure is a no-op in release, which silently swallows
            // the failure and leaves the user unaware of data corruption.
            print("[LocalStore] ERROR: Failed to encode/encrypt \(T.self) for key save: \(error)")
            #if DEBUG
            assertionFailure("[LocalStore] Failed to encode/encrypt \(T.self): \(error)")
            #endif
        }
    }

    /// Decrypt and decode a `Codable` value from UserDefaults `Data`.
    ///
    /// Migration: if decryption fails (e.g. data was stored before encryption
    /// was introduced), the method falls back to plain JSON decoding and
    /// re-saves the value encrypted for future reads.
    private static func load<T: Decodable>(
        _ type: T.Type,
        key: StorageKey,
        defaults: UserDefaults,
        decoder: JSONDecoder
    ) -> T? {
        guard let storedData = defaults.data(forKey: key.rawValue) else { return nil }

        // Attempt 1: decrypt then decode (normal encrypted path).
        if let decryptedData = try? CryptoService.decrypt(storedData),
           let value = try? decoder.decode(T.self, from: decryptedData) {
            return value
        }

        // Attempt 2 (migration): data may be legacy unencrypted JSON.
        // Decode directly, then re-save encrypted so subsequent reads
        // follow the primary path.
        if let value = try? decoder.decode(T.self, from: storedData) {
            // Re-encrypt the legacy plain-JSON data in place.
            if let reEncrypted = try? CryptoService.encrypt(storedData) {
                defaults.set(reEncrypted, forKey: key.rawValue)
            }
            return value
        }

        // Log the error so data corruption is visible in production builds.
        // assertionFailure is a no-op in release, which silently swallows
        // the failure and leaves the user unaware of unreadable data.
        print(
            "[LocalStore] ERROR: Failed to decrypt/decode \(T.self) "
            + "from key \(key.rawValue). Stored data may be corrupted."
        )
        #if DEBUG
        assertionFailure("[LocalStore] Failed to decrypt/decode \(T.self)")
        #endif
        return nil
    }

    /// Load the subscription tier stored as a raw string.
    private static func loadTier(defaults: UserDefaults) -> SubscriptionTier? {
        guard let raw = defaults.string(
            forKey: StorageKey.subscriptionTier.rawValue
        ) else {
            return nil
        }
        return SubscriptionTier(rawValue: raw)
    }
}

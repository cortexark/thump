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
    case lastCheckIn       = "com.thump.lastCheckIn"
    case feedbackPrefs     = "com.thump.feedbackPrefs"
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

        self.tier = Self.load(
            SubscriptionTier.self,
            key: .subscriptionTier,
            defaults: defaults,
            decoder: dec
        ) ?? Self.migrateLegacyTier(defaults: defaults) ?? .free

        self.alertMeta = Self.load(
            AlertMeta.self,
            key: .alertMeta,
            defaults: defaults,
            decoder: dec
        ) ?? AlertMeta()
    }

    #if DEBUG
    /// Preview instance for SwiftUI previews, backed by an in-memory defaults suite.
    public static var preview: LocalStore {
        LocalStore(defaults: UserDefaults(suiteName: "preview") ?? .standard)
    }
    #endif

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

    /// Upsert a single ``StoredSnapshot`` into the existing history.
    ///
    /// If a snapshot for the same calendar day already exists, it is replaced
    /// with the newer one. This prevents duplicate entries from pull-to-refresh,
    /// tab revisits, or app relaunches on the same day.
    public func appendSnapshot(_ stored: StoredSnapshot) {
        var history = loadHistory()
        let calendar = Calendar.current
        let newDay = calendar.startOfDay(for: stored.snapshot.date)
        if let idx = history.firstIndex(where: {
            calendar.startOfDay(for: $0.snapshot.date) == newDay
        }) {
            history[idx] = stored
        } else {
            history.append(stored)
        }
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

    /// Persist the current ``tier`` to disk (encrypted).
    public func saveTier() {
        save(tier, key: .subscriptionTier)
    }

    /// Reload ``tier`` from disk.
    public func reloadTier() {
        if let loaded = Self.load(
            SubscriptionTier.self,
            key: .subscriptionTier,
            defaults: defaults,
            decoder: decoder
        ) {
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

    // MARK: - Check-In

    /// Persist a mood check-in response.
    public func saveCheckIn(_ response: CheckInResponse) {
        save(response, key: .lastCheckIn)
    }

    /// Load today's check-in, if the user has already checked in.
    public func loadTodayCheckIn() -> CheckInResponse? {
        guard let response = Self.load(
            CheckInResponse.self,
            key: .lastCheckIn,
            defaults: defaults,
            decoder: decoder
        ) else { return nil }

        let calendar = Calendar.current
        if calendar.isDateInToday(response.date) {
            return response
        }
        return nil
    }

    // MARK: - Feedback Preferences

    /// Persist the user's feedback display preferences.
    public func saveFeedbackPreferences(_ prefs: FeedbackPreferences) {
        save(prefs, key: .feedbackPrefs)
    }

    /// Load feedback preferences, defaulting to all enabled.
    public func loadFeedbackPreferences() -> FeedbackPreferences {
        Self.load(
            FeedbackPreferences.self,
            key: .feedbackPrefs,
            defaults: defaults,
            decoder: decoder
        ) ?? FeedbackPreferences()
    }

    // MARK: - Danger Zone

    /// Remove all Thump data from UserDefaults and the Keychain encryption key.
    /// Intended for account-reset / sign-out flows.
    public func clearAll() {
        for key in [
            StorageKey.userProfile,
            .storedSnapshots,
            .alertMeta,
            .subscriptionTier,
            .lastFeedback,
            .lastCheckIn,
            .feedbackPrefs
        ] {
            defaults.removeObject(forKey: key.rawValue)
        }

        // Remove the encryption key from the Keychain so no leftover
        // ciphertext can be decrypted after account reset.
        try? CryptoService.deleteKey()

        profile = UserProfile()
        tier = .free
        alertMeta = AlertMeta()
    }

    // MARK: - Private Helpers

    /// Encode a `Codable` value, encrypt it, and write it to UserDefaults as `Data`.
    /// Refuses to store health data in plaintext — drops the write if encryption fails.
    /// Unit tests should mock CryptoService or use an unencrypted test store.
    private func save<T: Encodable>(_ value: T, key: StorageKey) {
        do {
            let jsonData = try encoder.encode(value)
            if let encrypted = try? CryptoService.encrypt(jsonData) {
                defaults.set(encrypted, forKey: key.rawValue)
            } else {
                // Encryption unavailable — do NOT fall back to plaintext for health data.
                // Data is dropped rather than stored unencrypted. The next successful
                // save will restore it. This protects PHI at the cost of temporary data loss.
                #if DEBUG
                print("[LocalStore] ERROR: Encryption unavailable for key \(key.rawValue). Data NOT saved to protect health data privacy.")
                #endif
                #if DEBUG
                assertionFailure("CryptoService.encrypt() returned nil for key \(key.rawValue). Fix Keychain access or mock CryptoService in tests.")
                #endif
            }
        } catch {
            #if DEBUG
            print("[LocalStore] ERROR: Failed to encode \(T.self) for key \(key.rawValue): \(error)")
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

        // Both encrypted and plain-text decoding failed — data is corrupted
        // or from an incompatible schema version. Remove the bad entry so the
        // app can start fresh instead of crashing on every launch.
        #if DEBUG
        print(
            "[LocalStore] WARNING: Removing unreadable \(T.self) "
            + "from key \(key.rawValue). Stored data was corrupted or incompatible."
        )
        #endif
        defaults.removeObject(forKey: key.rawValue)
        return nil
    }

    /// Migrate a legacy subscription tier that was stored as a plain raw string
    /// (before the encryption layer was introduced). If found, the value is
    /// re-saved encrypted and the legacy entry is replaced in-place.
    private static func migrateLegacyTier(defaults: UserDefaults) -> SubscriptionTier? {
        guard let raw = defaults.string(
            forKey: StorageKey.subscriptionTier.rawValue
        ) else {
            return nil
        }
        guard let tier = SubscriptionTier(rawValue: raw) else { return nil }

        // Re-save encrypted so subsequent reads go through the normal path.
        let encoder = JSONEncoder()
        if let jsonData = try? encoder.encode(tier),
           let encrypted = try? CryptoService.encrypt(jsonData) {
            defaults.set(encrypted, forKey: StorageKey.subscriptionTier.rawValue)
        }
        return tier
    }
}

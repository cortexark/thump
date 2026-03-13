// ConfigLoader.swift
// Thump iOS
//
// Configuration loader that combines default AlertPolicy values from
// HeartTrendEngine with user-configurable overrides. Persists settings
// to UserDefaults for cross-launch retention.
// Platforms: iOS 17+

import Foundation
import Combine

// MARK: - Config Loader

/// Loads and manages Thump configuration, wrapping the engine's
/// `AlertPolicy` defaults with user-configurable overrides persisted
/// to UserDefaults.
///
/// Provides the `alertPolicy` used by the trend engine and the
/// `lookbackWindow` that controls how many days of history to consider.
final class ConfigLoader: ObservableObject {

    // MARK: - Published State

    /// The active alert policy governing anomaly detection thresholds.
    @Published var alertPolicy: AlertPolicy

    /// Number of historical days used for baseline computation.
    @Published var lookbackWindow: Int

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let alertPolicy = "com.thump.config.alertPolicy"
        static let lookbackWindow = "com.thump.config.lookbackWindow"
    }

    // MARK: - Private Properties

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Default Values

    /// The default lookback window in days.
    private static let defaultLookbackWindow: Int = 21

    // MARK: - Initialization

    /// Creates a new ConfigLoader, loading persisted settings or falling
    /// back to engine defaults.
    ///
    /// - Parameter defaults: The UserDefaults store to use. Defaults to `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load alert policy from persistence or use engine defaults
        if let data = defaults.data(forKey: Keys.alertPolicy),
           let policy = try? JSONDecoder().decode(AlertPolicy.self, from: data) {
            self.alertPolicy = policy
        } else {
            self.alertPolicy = AlertPolicy()
        }

        // Load lookback window from persistence or use default
        let storedWindow = defaults.integer(forKey: Keys.lookbackWindow)
        if storedWindow > 0 {
            self.lookbackWindow = storedWindow
        } else {
            self.lookbackWindow = Self.defaultLookbackWindow
        }
    }

    // MARK: - Public API

    /// Resets all configuration to engine defaults.
    ///
    /// Clears persisted overrides and restores the default `AlertPolicy`
    /// and lookback window.
    func loadDefaults() {
        let defaultPolicy = AlertPolicy()
        self.alertPolicy = defaultPolicy
        self.lookbackWindow = Self.defaultLookbackWindow

        // Clear persisted overrides
        defaults.removeObject(forKey: Keys.alertPolicy)
        defaults.removeObject(forKey: Keys.lookbackWindow)
    }

    /// Updates the alert policy and persists it to UserDefaults.
    ///
    /// - Parameter policy: The new `AlertPolicy` to apply.
    func updateAlertPolicy(_ policy: AlertPolicy) {
        self.alertPolicy = policy
        persistAlertPolicy(policy)
    }

    /// Updates the lookback window and persists it to UserDefaults.
    ///
    /// - Parameter days: The new lookback window in days. Clamped to a minimum of 3.
    func updateLookbackWindow(_ days: Int) {
        let clamped = max(days, 3)
        self.lookbackWindow = clamped
        defaults.set(clamped, forKey: Keys.lookbackWindow)
    }

    /// Builds a `HeartTrendEngine` configured with the current policy and window.
    ///
    /// - Returns: A `HeartTrendEngine` ready to compute assessments.
    func buildEngine() -> HeartTrendEngine {
        HeartTrendEngine(lookbackWindow: lookbackWindow, policy: alertPolicy)
    }

    // MARK: - Private Persistence

    /// Encodes and persists the alert policy to UserDefaults.
    private func persistAlertPolicy(_ policy: AlertPolicy) {
        do {
            let data = try encoder.encode(policy)
            defaults.set(data, forKey: Keys.alertPolicy)
        } catch {
            debugPrint("[ConfigLoader] Failed to persist alert policy: \(error.localizedDescription)")
        }
    }
}

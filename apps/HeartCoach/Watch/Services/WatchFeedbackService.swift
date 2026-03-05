// WatchFeedbackService.swift
// Thump Watch
//
// Local feedback persistence for the watch using UserDefaults.
// Stores daily feedback responses keyed by date string so that
// the watch can independently track whether feedback has been given.
// Platforms: watchOS 10+

import Foundation
import Combine

// MARK: - Watch Feedback Service

/// Provides local persistence of daily feedback responses on the watch.
///
/// Feedback is stored in `UserDefaults` using a date-based key format
/// (`feedback_yyyy-MM-dd`). This allows the watch to restore feedback
/// state across app launches without requiring a round-trip to the phone.
@MainActor
final class WatchFeedbackService: ObservableObject {

    // MARK: - Published State

    /// The feedback response for today, if one has been recorded.
    @Published var todayFeedback: DailyFeedback?

    // MARK: - Private

    /// UserDefaults instance for persistence.
    private let defaults: UserDefaults

    /// Date formatter for generating storage keys.
    private let dateFormatter: DateFormatter

    /// Key prefix for feedback entries.
    private static let keyPrefix = "feedback_"

    // MARK: - Initialization

    /// Creates a new feedback service.
    ///
    /// - Parameter defaults: The `UserDefaults` instance to use.
    ///   Defaults to `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter.timeZone = .current

        // Hydrate today's feedback on init.
        self.todayFeedback = loadFeedback(for: Date())
    }

    // MARK: - Save

    /// Persists a feedback response for the given date.
    ///
    /// - Parameters:
    ///   - feedback: The `DailyFeedback` response to store.
    ///   - date: The date to associate the feedback with.
    func saveFeedback(_ feedback: DailyFeedback, for date: Date) {
        let key = storageKey(for: date)
        defaults.set(feedback.rawValue, forKey: key)

        // Update published state if saving for today.
        if Calendar.current.isDateInToday(date) {
            todayFeedback = feedback
        }
    }

    // MARK: - Load

    /// Loads the feedback response stored for the given date.
    ///
    /// - Parameter date: The date to look up feedback for.
    /// - Returns: The stored `DailyFeedback`, or `nil` if none exists.
    func loadFeedback(for date: Date) -> DailyFeedback? {
        let key = storageKey(for: date)
        guard let rawValue = defaults.string(forKey: key) else { return nil }
        return DailyFeedback(rawValue: rawValue)
    }

    // MARK: - Check

    /// Returns whether feedback has been recorded for today.
    ///
    /// - Returns: `true` if a feedback entry exists for today's date.
    func hasFeedbackToday() -> Bool {
        return loadFeedback(for: Date()) != nil
    }

    // MARK: - Private Helpers

    /// Generates the UserDefaults key for a given date.
    ///
    /// Format: `feedback_yyyy-MM-dd` (e.g., `feedback_2026-03-03`).
    ///
    /// - Parameter date: The date to generate a key for.
    /// - Returns: The storage key string.
    private func storageKey(for date: Date) -> String {
        return Self.keyPrefix + dateFormatter.string(from: date)
    }
}

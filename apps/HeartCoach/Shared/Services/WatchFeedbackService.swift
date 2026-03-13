// WatchFeedbackService.swift
// ThumpCore
//
// Shared local feedback persistence used by the watch UI and tests.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation
import Combine

@MainActor
final class WatchFeedbackService: ObservableObject {

    @Published var todayFeedback: DailyFeedback?

    private let defaults: UserDefaults
    private let dateFormatter: DateFormatter

    private static let keyPrefix = "feedback_"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter.timeZone = .current
        self.todayFeedback = nil
        self.todayFeedback = loadFeedback(for: Date())
    }

    func saveFeedback(_ feedback: DailyFeedback, for date: Date) {
        defaults.set(feedback.rawValue, forKey: storageKey(for: date))
        if Calendar.current.isDateInToday(date) {
            todayFeedback = feedback
        }
    }

    func loadFeedback(for date: Date) -> DailyFeedback? {
        guard let rawValue = defaults.string(forKey: storageKey(for: date)) else {
            return nil
        }
        return DailyFeedback(rawValue: rawValue)
    }

    func hasFeedbackToday() -> Bool {
        loadFeedback(for: Date()) != nil
    }

    private func storageKey(for date: Date) -> String {
        Self.keyPrefix + dateFormatter.string(from: date)
    }
}

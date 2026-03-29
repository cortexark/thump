// ProactiveNotificationStore.swift
// ThumpCore
//
// LocalStore extension for persisting proactive notification history.
// Tracks when each notification type was last scheduled so the
// ProactiveNotificationService can enforce budgets and cooldowns.
//
// Uses UserDefaults with a pruning strategy to prevent unbounded growth
// (GPT-5.4 review fix #5: stale data persistence).
//
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - LocalStore Extension

extension LocalStore {

    // MARK: - Keys

    private static let proactiveHistoryKey = "thump_proactive_notification_history"
    private static let maxHistoryDays = 14

    // MARK: - Read

    /// Returns all stored dates for a given notification type.
    func proactiveNotificationDates(for type: ProactiveNotificationType) -> [Date] {
        let all = loadProactiveHistory()
        return all[type.rawValue] ?? []
    }

    // MARK: - Write

    /// Records that a notification of the given type was scheduled at the given date.
    /// Automatically prunes entries older than 14 days to prevent unbounded growth.
    func logProactiveNotification(type: ProactiveNotificationType, at date: Date) {
        var all = loadProactiveHistory()
        var dates = all[type.rawValue] ?? []
        dates.append(date)

        // Prune entries older than 14 days
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -Self.maxHistoryDays,
            to: date
        ) ?? date
        dates = dates.filter { $0 > cutoff }

        all[type.rawValue] = dates
        saveProactiveHistory(all)
    }

    // MARK: - Private Persistence

    private func loadProactiveHistory() -> [String: [Date]] {
        guard let data = UserDefaults.standard.data(forKey: Self.proactiveHistoryKey),
              let decoded = try? JSONDecoder().decode([String: [Date]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveProactiveHistory(_ history: [String: [Date]]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.proactiveHistoryKey)
    }
}

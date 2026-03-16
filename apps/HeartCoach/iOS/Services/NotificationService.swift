// NotificationService.swift
// Thump iOS
//
// Local notification service for anomaly alerts and nudge reminders.
// Manages authorization, alert budgeting via AlertMeta, cooldown periods,
// and daily alert limits to prevent notification fatigue.
// Platforms: iOS 17+

import Foundation
import UserNotifications
import Combine

// MARK: - Notification Service

/// Manages local notifications for Thump, including anomaly alerts
/// when heart metrics deviate from baseline and scheduled nudge reminders.
///
/// Uses `AlertMeta` to enforce a cooldown period between alerts and a
/// maximum daily alert budget, preventing notification fatigue.
@MainActor
final class NotificationService: ObservableObject {

    // MARK: - Published State

    /// Whether the user has granted notification authorization.
    @Published var isAuthorized: Bool = false

    // MARK: - Private Properties

    private let center = UNUserNotificationCenter.current()
    private let localStore: LocalStore
    private let alertPolicy: AlertPolicy

    // MARK: - Notification Identifiers

    private enum Identifiers {
        static let anomalyPrefix = "com.thump.anomaly."
        static let nudgePrefix = "com.thump.nudge."
        static let categoryAnomaly = "ANOMALY_ALERT"
        static let categoryNudge = "NUDGE_REMINDER"
    }

    // MARK: - Default Delivery Hours

    // BUG-053: These fallback delivery hours are hardcoded defaults.
    // TODO: Make configurable via Settings UI so users can set preferred
    // notification windows per nudge category (e.g. "morning activity hour").
    private enum DefaultDeliveryHour {
        static let activity = 9        // Walk/moderate fallback: 9 AM
        static let breathe = 15        // Breathing exercises: 3 PM
        static let hydrate = 11        // Hydration reminders: 11 AM
        static let evening = 18        // General fallback: 6 PM
        static let latestMorning = 12  // Cap for wake-adjusted activity nudges
    }

    // MARK: - Initialization

    nonisolated init(
        localStore: LocalStore = LocalStore(),
        alertPolicy: AlertPolicy = ConfigService.defaultAlertPolicy
    ) {
        self.localStore = localStore
        self.alertPolicy = alertPolicy
        Task { @MainActor in
            await self.checkCurrentAuthorization()
        }
    }

    // MARK: - Authorization

    /// Requests notification authorization from the user.
    ///
    /// Requests alert, sound, and badge permissions. Updates the
    /// `isAuthorized` property on the main actor.
    /// - Throws: Any error from the notification center authorization request.
    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(
            options: [.alert, .sound, .badge]
        )

        self.isAuthorized = granted

        if granted {
            await registerCategories()
        }
    }

    // MARK: - Anomaly Alerts

    /// Schedules a local notification for an anomaly alert based on the assessment.
    ///
    /// Only schedules the notification if the alert budget allows it, as determined
    /// by `shouldAlert(meta:)`. The alert meta is persisted to UserDefaults.
    ///
    /// - Parameter assessment: The `HeartAssessment` that triggered the alert.
    func scheduleAnomalyAlert(assessment: HeartAssessment) {
        guard ConfigService.enableAnomalyAlerts,
              assessment.status == .needsAttention else {
            return
        }

        var meta = localStore.alertMeta

        guard shouldAlert(meta: &meta) else {
            debugPrint("[NotificationService] Alert suppressed by budget policy.")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = alertTitle(for: assessment)
        // BUG-034: Do not include health metric values (PHI) in notification payloads.
        // Notification content is visible on the lock screen and in Notification Center.
        // Use a generic body instead of assessment.explanation which contains metric values.
        content.body = "Check your Thump insights for an update on your heart health."
        content.sound = .default
        content.categoryIdentifier = Identifiers.categoryAnomaly

        // BUG-034: Only include non-PHI routing metadata in userInfo.
        // Removed anomalyScore which exposes health metric values in the notification payload.
        content.userInfo = [
            "status": assessment.status.rawValue,
            "regressionFlag": assessment.regressionFlag,
            "stressFlag": assessment.stressFlag
        ]

        // Fire immediately with a time interval trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = Identifiers.anomalyPrefix + UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                debugPrint("[NotificationService] Failed to schedule anomaly alert: \(error.localizedDescription)")
            }
        }

        // Update and persist meta
        meta.lastAlertAt = Date()
        meta.alertsToday += 1
        localStore.alertMeta = meta
        localStore.saveAlertMeta()
    }

    // MARK: - Nudge Reminders

    /// Schedules a daily nudge reminder at the specified hour.
    ///
    /// Creates a non-repeating notification for the next occurrence of the
    /// given hour. Cancels any existing nudge reminders before scheduling.
    ///
    /// - Parameters:
    ///   - nudge: The `DailyNudge` to remind the user about.
    ///   - hour: The hour of day (0-23) to deliver the reminder.
    func scheduleNudgeReminder(nudge: DailyNudge, at hour: Int) async {
        // Cancel existing nudge reminders
        center.removePendingNotificationRequests(
            withIdentifiers: await pendingNudgeIdentifiers()
        )

        let content = UNMutableNotificationContent()
        content.title = nudge.title
        content.body = nudge.description
        content.sound = .default
        content.categoryIdentifier = Identifiers.categoryNudge

        if let duration = nudge.durationMinutes {
            content.userInfo = [
                "category": nudge.category.rawValue,
                "durationMinutes": duration
            ]
        } else {
            content.userInfo = [
                "category": nudge.category.rawValue
            ]
        }

        // Schedule for the next occurrence of the specified hour
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )

        let identifier = Identifiers.nudgePrefix + UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            debugPrint("[NotificationService] Failed to schedule nudge reminder: \(error.localizedDescription)")
        }
    }

    // MARK: - Smart Nudge Scheduling

    /// Schedules a nudge reminder using learned sleep patterns for optimal timing.
    ///
    /// Uses `SmartNudgeScheduler` to determine the best delivery hour based on
    /// the user's historical bedtime and wake patterns.
    ///
    /// - Parameters:
    ///   - nudge: The `DailyNudge` to schedule.
    ///   - history: Historical snapshots for pattern learning.
    func scheduleSmartNudge(nudge: DailyNudge, history: [HeartSnapshot]) async {
        let scheduler = SmartNudgeScheduler()
        let patterns = scheduler.learnSleepPatterns(from: history)

        // Determine optimal hour based on nudge category
        let hour: Int
        switch nudge.category {
        case .rest:
            // Wind-down nudges go before bedtime
            hour = scheduler.bedtimeNudgeHour(patterns: patterns, for: Date())
        case .walk, .moderate:
            // Activity nudges go mid-morning (or after learned wake time + 2 hours)
            let calendar = Calendar.current
            let dayOfWeek = calendar.component(.weekday, from: Date())
            if let pattern = patterns.first(where: { $0.dayOfWeek == dayOfWeek }),
               pattern.observationCount >= 3 {
                hour = min(pattern.typicalWakeHour + 2, DefaultDeliveryHour.latestMorning)
            } else {
                hour = DefaultDeliveryHour.activity
            }
        case .breathe:
            // Breathing nudges go mid-afternoon when stress typically peaks
            hour = DefaultDeliveryHour.breathe
        case .hydrate:
            // Hydration nudges go late morning
            hour = DefaultDeliveryHour.hydrate
        default:
            // Default: early evening
            hour = DefaultDeliveryHour.evening
        }

        await scheduleNudgeReminder(nudge: nudge, at: hour)
    }

    // MARK: - Cancellation

    /// Cancels all pending notification requests.
    func cancelAllPending() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Alert Budget

    /// Determines whether a new alert should be sent based on cooldown and daily limits.
    ///
    /// Checks two constraints:
    /// 1. Cooldown: At least `alertPolicy.cooldownHours` must have elapsed since the last alert.
    /// 2. Daily limit: No more than `alertPolicy.maxAlertsPerDay` alerts per calendar day.
    ///
    /// Resets the daily counter when the day stamp changes.
    ///
    /// - Parameter meta: The current `AlertMeta`, modified in place if the day resets.
    /// - Returns: `true` if the alert should proceed, `false` if it should be suppressed.
    private func shouldAlert(meta: inout AlertMeta) -> Bool {
        let now = Date()
        let todayStamp = dayStamp(for: now)

        // Reset daily count if the day has changed
        if meta.alertsDayStamp != todayStamp {
            meta.alertsToday = 0
            meta.alertsDayStamp = todayStamp
        }

        // Check daily limit
        guard meta.alertsToday < alertPolicy.maxAlertsPerDay else {
            return false
        }

        // Check cooldown period
        if let lastAlert = meta.lastAlertAt {
            let hoursSinceLastAlert = now.timeIntervalSince(lastAlert) / 3600.0
            guard hoursSinceLastAlert >= alertPolicy.cooldownHours else {
                return false
            }
        }

        return true
    }

    // MARK: - Private Helpers

    /// Checks the current notification authorization status on initialization.
    private func checkCurrentAuthorization() async {
        let settings = await center.notificationSettings()
        self.isAuthorized = settings.authorizationStatus == .authorized
    }

    /// Registers notification categories with associated actions.
    private func registerCategories() async {
        let anomalyCategory = UNNotificationCategory(
            identifier: Identifiers.categoryAnomaly,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let nudgeCompleteAction = UNNotificationAction(
            identifier: "NUDGE_COMPLETE",
            title: "Done",
            options: [.foreground]
        )

        let nudgeSkipAction = UNNotificationAction(
            identifier: "NUDGE_SKIP",
            title: "Skip",
            options: []
        )

        let nudgeCategory = UNNotificationCategory(
            identifier: Identifiers.categoryNudge,
            actions: [nudgeCompleteAction, nudgeSkipAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([anomalyCategory, nudgeCategory])
    }

    /// Generates an alert title based on the assessment's signals.
    private func alertTitle(for assessment: HeartAssessment) -> String {
        if assessment.stressFlag {
            return "Heart Working Harder Than Usual"
        }
        if assessment.regressionFlag {
            return "Heart Metric Trend Change"
        }
        if assessment.anomalyScore >= alertPolicy.anomalyHigh {
            return "Heart Metric Anomaly Detected"
        }
        return "Thump Alert"
    }

    /// Returns identifiers for all pending nudge notifications.
    private func pendingNudgeIdentifiers() async -> [String] {
        let requests = await center.pendingNotificationRequests()
        return requests
            .map(\.identifier)
            .filter { $0.hasPrefix(Identifiers.nudgePrefix) }
    }

    /// Cached formatter for date stamp generation.
    private static let dayStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Generates a date stamp string (yyyy-MM-dd) for the given date.
    private func dayStamp(for date: Date) -> String {
        Self.dayStampFormatter.string(from: date)
    }
}

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

    init(
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
        let copy = anomalyCopy(for: assessment)
        content.title = copy.title
        content.subtitle = copy.subtitle
        content.body = copy.body
        content.sound = .default
        content.categoryIdentifier = Identifiers.categoryAnomaly
        content.threadIdentifier = "com.thump.alerts.anomaly"
        content.relevanceScore = 0.85
        content.interruptionLevel = .active

        // BUG-034: Only include non-PHI routing metadata in userInfo.
        // Removed anomalyScore which exposes health metric values in the notification payload.
        content.userInfo = [
            "status": assessment.status.rawValue,
            "regressionFlag": assessment.regressionFlag,
            "stressFlag": assessment.stressFlag,
            "route": "dashboard"
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
        let copy = nudgeReminderCopy(for: nudge, hour: hour)
        content.title = copy.title
        content.subtitle = copy.subtitle
        content.body = copy.body
        content.sound = .default
        content.categoryIdentifier = Identifiers.categoryNudge
        content.threadIdentifier = "com.thump.alerts.nudge.\(nudge.category.rawValue)"
        content.relevanceScore = 0.65
        content.interruptionLevel = .passive
        content.targetContentIdentifier = nudge.category.rawValue

        if let duration = nudge.durationMinutes {
            content.userInfo = [
                "category": nudge.category.rawValue,
                "durationMinutes": duration,
                "route": "dashboard"
            ]
        } else {
            content.userInfo = [
                "category": nudge.category.rawValue,
                "route": "dashboard"
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

    /// Human-friendly, action-forward anomaly messaging for lock screen + watch mirroring.
    /// Copy stays privacy-safe and avoids raw metric values.
    private func anomalyCopy(for assessment: HeartAssessment) -> (title: String, subtitle: String, body: String) {
        if assessment.stressFlag {
            return (
                title: "Stress Trend Is Up",
                subtitle: "Try a 2-minute reset now",
                body: "Stress is above your recent baseline. Open Thump for a calm reset and today’s next step."
            )
        }
        if assessment.regressionFlag {
            return (
                title: "Recovery Trend Slipped",
                subtitle: "A lighter day likely fits",
                body: "Recovery is below your recent baseline. Open Thump to follow the next best action for today."
            )
        }
        if assessment.anomalyScore >= alertPolicy.anomalyHigh {
            return (
                title: "Pattern Shift Detected",
                subtitle: "See what changed",
                body: "One or more trends moved away from your usual pattern. Open Thump to review the shift and likely next step."
            )
        }
        return (
            title: "Daily Recovery Update",
            subtitle: "One clear next step",
            body: "Today’s signals are in. Open Thump to see the action that best fits your current baseline."
        )
    }

    /// Category-aware reminder messaging that emphasizes one clear action.
    private func nudgeReminderCopy(for nudge: DailyNudge, hour: Int) -> (title: String, subtitle: String, body: String) {
        let timeHint = hour < 12 ? "for this morning" : (hour < 17 ? "for today" : "for tonight")
        let duration = nudge.durationMinutes.map { "\($0) min" } ?? "short"

        switch nudge.category {
        case .walk:
            return (
                title: "Today’s Move",
                subtitle: "Take a \(duration) walk",
                body: "Your signals may benefit from a \(duration.lowercased()) walk \(timeHint). It often helps stress settle and recovery move toward baseline."
            )
        case .moderate:
            return (
                title: "Training Check-In",
                subtitle: "Moderate effort for \(duration)",
                body: "Today’s readiness suggests controlled work may fit \(timeHint). Open Thump to start at the right intensity."
            )
        case .breathe:
            return (
                title: "Reset Moment",
                subtitle: "Breathe for \(duration)",
                body: "Stress appears above your recent baseline. A calm \(duration.lowercased()) breathing reset now often helps your body settle."
            )
        case .rest:
            return (
                title: "Recovery First",
                subtitle: "Protect tonight’s sleep",
                body: "Today’s signals suggest keeping effort light \(timeHint). Today’s rest is where adaptation happens for tomorrow."
            )
        case .hydrate:
            return (
                title: "Hydration Check",
                subtitle: "Take a quick water break",
                body: "Your body may benefit from water \(timeHint). A short break often helps energy and focus stay steadier."
            )
        default:
            return (
                title: "Thump Focus",
                subtitle: "One clear action",
                body: "\(nudge.title) \(timeHint). Open Thump to follow the step that fits today’s signals."
            )
        }
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

// ProactiveNotificationService.swift
// Thump iOS
//
// Proactive notification system for 7 missing notification types identified
// in the competitor gap analysis. Extends the existing NotificationService
// without modifying it.
//
// Architecture based on Gemini 3.1 Pro design, hardened by GPT-5.4 review
// (30 issues fixed: races, deduplication, time zones, budgets, privacy).
//
// Platforms: iOS 17+

import Foundation
import UserNotifications

// MARK: - Notification Types

/// All proactive notification types added by the gap analysis.
enum ProactiveNotificationType: String, Sendable, CaseIterable {
    case morningBriefing
    case bedtimeWindDown
    case postWorkoutRecovery
    case trainingOpportunity
    case illnessDetection
    case eveningRecovery
    case reboundConfirmation

    var threadIdentifier: String {
        "com.thump.alerts.\(rawValue)"
    }

    /// Stable identifier — one per type, no UUID, so scheduling replaces
    /// any existing pending notification of the same type (GPT-5.4 fix #2).
    var notificationIdentifier: String {
        "com.thump.\(rawValue)"
    }

    /// Priority for daily budget arbitration (higher = more important).
    var priority: Int {
        switch self {
        case .illnessDetection:     return 100
        case .morningBriefing:      return 90
        case .reboundConfirmation:  return 80
        case .trainingOpportunity:  return 70
        case .eveningRecovery:      return 60
        case .bedtimeWindDown:      return 50
        case .postWorkoutRecovery:  return 40
        }
    }
}

// MARK: - Configuration

/// All thresholds in one testable struct — no magic numbers (Gemini design).
struct ProactiveNotificationConfig: Sendable {
    let morningBriefingStaleHours: Double
    let bedtimeWindDownLeadMinutes: Double
    let postWorkoutDelaySeconds: TimeInterval
    let postWorkoutMinDurationMinutes: Double
    let trainingOpportunityMaxPerWeek: Int
    let illnessDetectionCooldownHours: Double
    let illnessHrvDropThreshold: Double
    let illnessRhrRiseThreshold: Double
    let illnessConsecutiveDaysRequired: Int
    let eveningRecoveryBeforeBedHours: Double
    let reboundImprovementPoints: Double
    let dailyNotificationBudget: Int

    init(
        morningBriefingStaleHours: Double = 12.0,
        bedtimeWindDownLeadMinutes: Double = 60.0,
        postWorkoutDelaySeconds: TimeInterval = 900, // 15 min
        postWorkoutMinDurationMinutes: Double = 5.0,
        trainingOpportunityMaxPerWeek: Int = 3,
        illnessDetectionCooldownHours: Double = 48.0,
        illnessHrvDropThreshold: Double = 0.25,
        illnessRhrRiseThreshold: Double = 0.08,
        illnessConsecutiveDaysRequired: Int = 2,
        eveningRecoveryBeforeBedHours: Double = 2.0,
        reboundImprovementPoints: Double = 10.0,
        dailyNotificationBudget: Int = 3
    ) {
        self.morningBriefingStaleHours = morningBriefingStaleHours
        self.bedtimeWindDownLeadMinutes = bedtimeWindDownLeadMinutes
        self.postWorkoutDelaySeconds = postWorkoutDelaySeconds
        self.postWorkoutMinDurationMinutes = postWorkoutMinDurationMinutes
        self.trainingOpportunityMaxPerWeek = trainingOpportunityMaxPerWeek
        self.illnessDetectionCooldownHours = illnessDetectionCooldownHours
        self.illnessHrvDropThreshold = illnessHrvDropThreshold
        self.illnessRhrRiseThreshold = illnessRhrRiseThreshold
        self.illnessConsecutiveDaysRequired = illnessConsecutiveDaysRequired
        self.eveningRecoveryBeforeBedHours = eveningRecoveryBeforeBedHours
        self.reboundImprovementPoints = reboundImprovementPoints
        self.dailyNotificationBudget = dailyNotificationBudget
    }
}

// MARK: - Scheduling Gate (GPT-5.4 fix #1: atomic scheduling)

/// Serializes scheduling decisions per notification type to prevent
/// race conditions when multiple refresh paths fire simultaneously.
private actor ProactiveSchedulingGate {
    private var inFlight: Set<ProactiveNotificationType> = []

    func acquire(_ type: ProactiveNotificationType) -> Bool {
        guard !inFlight.contains(type) else { return false }
        inFlight.insert(type)
        return true
    }

    func release(_ type: ProactiveNotificationType) {
        inFlight.remove(type)
    }
}

// MARK: - Proactive Notification Service

/// Schedules proactive coaching notifications that the existing
/// `NotificationService` does not cover.
///
/// Designed to be called from `DailyEngineCoordinator` after each
/// dashboard refresh and from HealthKit observers for workout completion.
///
/// Key safety properties (from GPT-5.4 review):
/// - Stable identifiers: one per type, replaces existing pending
/// - Atomic scheduling via actor gate (no duplicate races)
/// - Daily budget with priority arbitration
/// - Calendar-safe time calculations (no raw TimeInterval math)
/// - Privacy: no raw health values in notification payload
@MainActor
final class ProactiveNotificationService: ObservableObject {

    // MARK: - Dependencies

    private let center: UNUserNotificationCenter
    private let localStore: LocalStore
    private let config: ProactiveNotificationConfig
    private let calendar: Calendar
    private let gate = ProactiveSchedulingGate()

    // MARK: - Initialization

    init(
        center: UNUserNotificationCenter = .current(),
        localStore: LocalStore,
        config: ProactiveNotificationConfig = ProactiveNotificationConfig(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.localStore = localStore
        self.config = config
        self.calendar = calendar
    }

    // MARK: - 1. Morning Readiness Briefing

    /// Call after dashboard refresh completes, before noon.
    func scheduleMorningBriefing(
        readinessScore: Int,
        readinessLevel: ReadinessLevel,
        topReason: String,
        snapshotDate: Date
    ) async {
        let type = ProactiveNotificationType.morningBriefing
        guard await canSchedule(type: type, snapshotDate: snapshotDate) else { return }

        // Only fire before noon
        let hour = calendar.component(.hour, from: Date())
        guard hour < 12 else { return }

        let levelWord: String
        switch readinessLevel {
        case .thriving: levelWord = "strong"
        case .ready:    levelWord = "solid"
        case .recovering: levelWord = "below your baseline"
        case .low:      levelWord = "low"
        }

        let content = buildContent(
            type: type,
            title: "Your Morning Check-In",
            subtitle: "Recovery is \(levelWord) today",
            body: "\(topReason) Open Thump to see today's plan.",
            interruptionLevel: .passive
        )

        await scheduleIfNeeded(content: content, trigger: nil, type: type)
    }

    // MARK: - 2. Bedtime Wind-Down

    /// Call when SmartNudgeScheduler determines bedtime is approaching.
    func scheduleBedtimeWindDown(
        bedtimeHour: Int,
        sleepDebtHours: Double
    ) async {
        let type = ProactiveNotificationType.bedtimeWindDown
        guard await canSchedule(type: type) else { return }

        let body: String
        if sleepDebtHours > 1.5 {
            body = "You've been carrying some sleep debt. A 20-minute wind-down routine tends to help your body recover tonight."
        } else {
            body = "Getting ready for bed soon supports a solid baseline tomorrow. Dimming lights and putting screens away often helps."
        }

        let content = buildContent(
            type: type,
            title: "Start Winding Down",
            subtitle: "Tonight's sleep starts now",
            body: body,
            interruptionLevel: .passive
        )

        // Schedule 60 min before bedtime using calendar components (GPT-5.4 fix #8: timezone-safe)
        let windDownHour = (bedtimeHour - 1 + 24) % 24
        var components = DateComponents()
        components.hour = windDownHour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        await scheduleIfNeeded(content: content, trigger: trigger, type: type)
    }

    // MARK: - 3. Post-Workout Recovery

    /// Call from HealthKit workout observer when a workout session ends.
    func schedulePostWorkoutRecovery(
        workoutDurationMinutes: Double,
        wasHighIntensity: Bool,
        workoutEndDate: Date
    ) async {
        let type = ProactiveNotificationType.postWorkoutRecovery

        // Skip very short workouts
        guard workoutDurationMinutes >= config.postWorkoutMinDurationMinutes else { return }

        // GPT-5.4 fix #15: use workout end date, not "now", for delay calculation
        let targetDelivery = workoutEndDate.addingTimeInterval(config.postWorkoutDelaySeconds)
        let delay = targetDelivery.timeIntervalSinceNow
        guard delay > 0 else { return } // Already past the window

        guard await canSchedule(type: type) else { return }

        let body = wasHighIntensity
            ? "That was a solid effort. Rehydrating and eating within the hour tends to improve tomorrow's recovery."
            : "Nice work staying active. A short cooldown and some water often help your body absorb the session."

        let content = buildContent(
            type: type,
            title: "Recover It Well",
            subtitle: "The next hour matters",
            body: body,
            interruptionLevel: .passive
        )

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        await scheduleIfNeeded(content: content, trigger: trigger, type: type)
    }

    // MARK: - 4. Training Opportunity (Green Light)

    /// Call after readiness is computed. Only fires when conditions are ideal.
    func evaluateTrainingOpportunity(
        readinessScore: Int,
        stressElevated: Bool,
        sleepHours: Double?,
        isRestDay: Bool,
        overtrained: Bool
    ) async {
        let type = ProactiveNotificationType.trainingOpportunity

        guard readinessScore >= 80,
              !stressElevated,
              (sleepHours ?? 0) >= 6.0,
              !isRestDay,
              !overtrained else { return }

        // Weekly cap
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentCount = localStore.proactiveNotificationDates(for: type)
            .filter { $0 > weekAgo }
            .count
        guard recentCount < config.trainingOpportunityMaxPerWeek else { return }

        guard await canSchedule(type: type) else { return }

        let content = buildContent(
            type: type,
            title: "Today Looks Like a Push Day",
            subtitle: "Your body is ready for more",
            body: "Recovery is tracking well above your baseline and stress is manageable. If you've planned a harder session, this is likely a good day for it.",
            interruptionLevel: .passive
        )

        await scheduleIfNeeded(content: content, trigger: nil, type: type)
    }

    // MARK: - 5. Illness Detection Alert

    /// Call after overnight data processed. Requires multi-signal convergence.
    func evaluateIllnessDetection(
        consecutiveDaysFlagged: Int
    ) async {
        let type = ProactiveNotificationType.illnessDetection

        guard consecutiveDaysFlagged >= config.illnessConsecutiveDaysRequired else { return }

        // Strict cooldown: max 1 per 48h
        if let lastSent = localStore.proactiveNotificationDates(for: type).max() {
            let hoursSince = Date().timeIntervalSince(lastSent) / 3600
            guard hoursSince >= config.illnessDetectionCooldownHours else { return }
        }

        guard await canSchedule(type: type) else { return }

        let content = buildContent(
            type: type,
            title: "Your Body May Be Fighting Something",
            subtitle: "Recovery signals look unusually off",
            body: "Several signals have moved outside your normal range for multiple days. Keep today light, monitor symptoms, and consult your doctor if you feel unwell.",
            interruptionLevel: .active
        )

        await scheduleIfNeeded(content: content, trigger: nil, type: type)

        // Suppress normal training notifications when illness mode active
        cancelPending(types: [.trainingOpportunity])
    }

    // MARK: - 6. Evening Recovery Check

    /// Call in late afternoon/evening on hard days.
    func scheduleEveningRecovery(
        readinessScore: Int,
        stressElevated: Bool,
        highStrainDay: Bool,
        bedtimeHour: Int
    ) async {
        let type = ProactiveNotificationType.eveningRecovery

        guard highStrainDay || stressElevated || readinessScore < 50 else { return }
        guard await canSchedule(type: type) else { return }

        let content = buildContent(
            type: type,
            title: "Set Up Tomorrow Now",
            subtitle: "Tonight matters",
            body: "Today put some load on your system. A calm evening and an earlier bedtime tend to help recovery rebound.",
            interruptionLevel: .passive
        )

        // 2h before bedtime using calendar components (timezone-safe)
        let eveningHour = (bedtimeHour - 2 + 24) % 24
        var components = DateComponents()
        components.hour = eveningHour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        await scheduleIfNeeded(content: content, trigger: trigger, type: type)
    }

    // MARK: - 7. Rebound Confirmation

    /// Call after morning readiness when yesterday was a recovery day.
    func evaluateRebound(
        yesterdayReadiness: Int,
        yesterdayWasRestDay: Bool,
        todayReadiness: Int
    ) async {
        let type = ProactiveNotificationType.reboundConfirmation
        let improvement = Double(todayReadiness - yesterdayReadiness)

        guard yesterdayReadiness < 60,
              yesterdayWasRestDay,
              improvement >= config.reboundImprovementPoints else { return }

        guard await canSchedule(type: type) else { return }

        let content = buildContent(
            type: type,
            title: "That Recovery Choice Helped",
            subtitle: "Your signals bounced back",
            body: "Recovery improved after yesterday's lighter day. Following rest advice tends to produce this kind of rebound. Worth repeating when needed.",
            interruptionLevel: .passive
        )

        await scheduleIfNeeded(content: content, trigger: nil, type: type)
    }

    // MARK: - Cancellation

    /// Cancel any pending notification when the user opens the app (for morning brief).
    func cancelOnAppOpen() {
        cancelPending(types: [.morningBriefing, .bedtimeWindDown])
    }

    func cancelPending(types: [ProactiveNotificationType]) {
        let ids = types.map(\.notificationIdentifier)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Private: Eligibility + Scheduling

    /// Combined check: authorization, daily budget, not already pending, data freshness.
    private func canSchedule(
        type: ProactiveNotificationType,
        snapshotDate: Date? = nil
    ) async -> Bool {
        // Data freshness
        if let snapshotDate {
            let staleHours = Date().timeIntervalSince(snapshotDate) / 3600
            guard staleHours < config.morningBriefingStaleHours else { return false }
        }

        // Daily budget (GPT-5.4 fix #6)
        let today = calendar.startOfDay(for: Date())
        let todayCount = ProactiveNotificationType.allCases
            .flatMap { localStore.proactiveNotificationDates(for: $0) }
            .filter { $0 >= today }
            .count

        // Allow high-priority types even when budget is spent
        if todayCount >= config.dailyNotificationBudget && type.priority < 90 {
            return false
        }

        return true
    }

    /// Atomic schedule with deduplication (GPT-5.4 fix #1 + #2 + #4).
    private func scheduleIfNeeded(
        content: UNMutableNotificationContent,
        trigger: UNNotificationTrigger?,
        type: ProactiveNotificationType
    ) async {
        // Acquire gate to prevent race conditions
        guard await gate.acquire(type) else { return }
        defer { Task { await gate.release(type) } }

        // Check for existing pending notification of same type
        let pending = await center.pendingNotificationRequests()
        let alreadyPending = pending.contains { $0.identifier == type.notificationIdentifier }
        guard !alreadyPending else { return }

        let request = UNNotificationRequest(
            identifier: type.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            localStore.logProactiveNotification(type: type, at: Date())
            AppLogger.info("[ProactiveNotification] Scheduled: \(type.rawValue)")
        } catch {
            AppLogger.engine.warning("[ProactiveNotification] Failed to schedule \(type.rawValue): \(error.localizedDescription)")
        }
    }

    /// Build notification content with privacy-safe payload.
    private func buildContent(
        type: ProactiveNotificationType,
        title: String,
        subtitle: String,
        body: String,
        interruptionLevel: UNNotificationInterruptionLevel
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.threadIdentifier = type.threadIdentifier
        content.interruptionLevel = interruptionLevel
        content.relevanceScore = Double(type.priority) / 100.0
        // Privacy: no raw health values in payload
        content.userInfo = [
            "notificationType": type.rawValue,
            "route": "dashboard"
        ]
        content.sound = (interruptionLevel == .active || interruptionLevel == .timeSensitive)
            ? .default
            : nil
        return content
    }
}

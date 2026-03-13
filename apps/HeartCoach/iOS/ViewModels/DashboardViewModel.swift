// DashboardViewModel.swift
// Thump iOS
//
// Main dashboard view model. Orchestrates HealthKit data fetching,
// trend engine assessment, local persistence, and nudge tracking.
// Bridges HealthKitService and LocalStore to provide the dashboard
// view with all required state.
// Platforms: iOS 17+

import Foundation
import Combine

// MARK: - Dashboard View Model

/// View model for the primary dashboard screen.
///
/// Coordinates data flow between `HealthKitService`, `HeartTrendEngine`,
/// and `LocalStore` to produce today's `HeartAssessment` and snapshot.
/// Exposes user profile information and nudge completion tracking.
@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - Published State

    /// Today's computed heart health assessment.
    @Published var assessment: HeartAssessment?

    /// Today's raw health metrics snapshot.
    @Published var todaySnapshot: HeartSnapshot?

    /// Whether a data refresh is in progress.
    @Published var isLoading: Bool = true

    /// Human-readable error message if the last refresh failed.
    @Published var errorMessage: String?

    /// The user's current subscription tier for feature gating.
    @Published var currentTier: SubscriptionTier = .free

    /// Whether the user has completed a mood check-in today.
    @Published var hasCheckedInToday: Bool = false

    /// Today's mood check-in, if completed.
    @Published var todayMood: CheckInMood?

    /// Whether the current nudge recommendation is something
    /// the user is already doing (e.g., they already walk 15+ min).
    @Published var isNudgeAlreadyMet: Bool = false

    /// Per-nudge completion tracking for multiple suggestions.
    @Published var nudgeCompletionStatus: [Int: Bool] = [:]

    /// Short weekly trend summary for the buddy suggestion header.
    @Published var weeklyTrendSummary: String?

    /// Today's bio age estimate, if the user has set their date of birth.
    @Published var bioAgeResult: BioAgeResult?

    /// Today's readiness score (0-100 composite wellness number).
    @Published var readinessResult: ReadinessResult?

    /// Today's coaching report with insights, projections, and hero message.
    @Published var coachingReport: CoachingReport?

    /// Today's zone distribution analysis.
    @Published var zoneAnalysis: ZoneAnalysis?

    /// Today's prioritised buddy recommendations from all engine signals.
    @Published var buddyRecommendations: [BuddyRecommendation]?

    /// Today's stress result for use in buddy insight and readiness context.
    @Published var stressResult: StressResult?

    // MARK: - Dependencies

    private var healthDataProvider: any HealthDataProviding
    private var localStore: LocalStore
    private var notificationService: NotificationService?

    // MARK: - Private Properties

    /// Number of historical days to fetch for the trend engine.
    private let historyDays: Int = ConfigService.defaultLookbackWindow

    /// Cancellable subscriptions for observing tier changes.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates a new dashboard view model with injected dependencies.
    ///
    /// - Parameters:
    ///   - healthKitService: The HealthKit service for fetching metrics.
    ///   - localStore: The local persistence store for history and profile.
    init(
        healthKitService: any HealthDataProviding = HealthKitService(),
        localStore: LocalStore = LocalStore()
    ) {
        self.healthDataProvider = healthKitService
        self.localStore = localStore

        bindToLocalStore(localStore)
    }

    // MARK: - Public API

    func bind(
        healthDataProvider: any HealthDataProviding,
        localStore: LocalStore,
        notificationService: NotificationService? = nil
    ) {
        self.healthDataProvider = healthDataProvider
        self.localStore = localStore
        self.notificationService = notificationService
        bindToLocalStore(localStore)
    }

    /// Refreshes the dashboard by fetching today's snapshot, loading
    /// history, running the trend engine, and persisting the result.
    ///
    /// This is the primary data flow method called on appearance and
    /// pull-to-refresh. Errors are caught and surfaced via `errorMessage`.
    func refresh() async {
        let refreshStart = CFAbsoluteTimeGetCurrent()
        AppLogger.engine.info("Dashboard refresh started")
        isLoading = true
        errorMessage = nil

        do {
            // Ensure HealthKit authorization
            if !healthDataProvider.isAuthorized {
                AppLogger.healthKit.info("Requesting HealthKit authorization")
                try await healthDataProvider.requestAuthorization()
                AppLogger.healthKit.info("HealthKit authorization granted")
            }

            // Fetch today's snapshot — fall back to mock data in simulator, empty snapshot on device
            let snapshot: HeartSnapshot
            do {
                snapshot = try await healthDataProvider.fetchTodaySnapshot()
            } catch {
                #if targetEnvironment(simulator)
                snapshot = MockData.mockTodaySnapshot
                #else
                snapshot = HeartSnapshot(date: Calendar.current.startOfDay(for: Date()))
                #endif
            }
            todaySnapshot = snapshot

            // Fetch historical snapshots — fall back to mock history in simulator, empty on device
            let history: [HeartSnapshot]
            do {
                history = try await healthDataProvider.fetchHistory(days: historyDays)
            } catch {
                #if targetEnvironment(simulator)
                history = MockData.mockHistory(days: historyDays)
                #else
                history = []
                #endif
            }

            // Load any persisted feedback for today
            let feedbackPayload = localStore.loadLastFeedback()
            let feedback: DailyFeedback?
            if let feedbackPayload,
               Calendar.current.isDate(
                feedbackPayload.date,
                inSameDayAs: snapshot.date
               ) {
                feedback = feedbackPayload.response
            } else {
                feedback = nil
            }

            // Run the trend engine
            let engineStart = CFAbsoluteTimeGetCurrent()
            let engine = ConfigService.makeDefaultEngine()
            let result = engine.assess(
                history: history,
                current: snapshot,
                feedback: feedback
            )
            let engineMs = (CFAbsoluteTimeGetCurrent() - engineStart) * 1000

            AppLogger.engine.info("HeartTrend assessed: status=\(result.status.rawValue) confidence=\(result.confidence.rawValue) anomaly=\(String(format: "%.2f", result.anomalyScore)) in \(String(format: "%.0f", engineMs))ms")

            assessment = result

            // Persist the snapshot and assessment
            let stored = StoredSnapshot(snapshot: snapshot, assessment: result)
            localStore.appendSnapshot(stored)

            // Update streak
            updateStreak()

            // Check if user already meets this nudge's goal
            evaluateNudgeCompletion(nudge: result.dailyNudge, snapshot: snapshot)

            // Compute weekly trend summary
            computeWeeklyTrend(history: history)

            // Check for existing check-in today
            loadTodayCheckIn()

            // Compute bio age if user has set date of birth
            computeBioAge(snapshot: snapshot)

            // Compute readiness score
            computeReadiness(snapshot: snapshot, history: history)

            // Compute coaching report
            computeCoachingReport(snapshot: snapshot, history: history)

            // Compute zone analysis
            computeZoneAnalysis(snapshot: snapshot)

            // Compute buddy recommendations (after readiness and stress are available)
            computeBuddyRecommendations(
                assessment: result,
                snapshot: snapshot,
                history: history
            )

            // Schedule notifications from live assessment output (CR-001)
            scheduleNotificationsIfNeeded(assessment: result, history: history)

            let totalMs = (CFAbsoluteTimeGetCurrent() - refreshStart) * 1000
            AppLogger.engine.info("Dashboard refresh complete in \(String(format: "%.0f", totalMs))ms — history=\(history.count) days")

            isLoading = false
        } catch {
            AppLogger.engine.error("Dashboard refresh failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Marks today's nudge as completed and updates the local store.
    ///
    /// Records explicit completion for the day and increments the streak
    /// at most once per calendar day (CR-003 + CR-004).
    func markNudgeComplete() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Record completion by saving feedback
        let completionPayload = WatchFeedbackPayload(
            date: Date(),
            response: .positive,
            source: "iOS-nudgeComplete"
        )
        localStore.saveLastFeedback(completionPayload)

        // Record explicit nudge completion for this date (CR-003)
        let dateKey = ISO8601DateFormatter().string(from: today).prefix(10)
        localStore.profile.nudgeCompletionDates.insert(String(dateKey))

        // Only credit streak once per calendar day (CR-004)
        if let lastCredit = localStore.profile.lastStreakCreditDate,
           calendar.isDate(lastCredit, inSameDayAs: today) {
            // Already credited today — just save the completion record
            localStore.saveProfile()
            return
        }

        localStore.profile.streakDays += 1
        localStore.profile.lastStreakCreditDate = today
        localStore.saveProfile()
    }

    /// Marks a specific nudge (by index) as completed.
    func markNudgeComplete(at index: Int) {
        nudgeCompletionStatus[index] = true
        // Also record as general positive feedback (streak guarded per-day)
        markNudgeComplete()
    }

    // MARK: - Profile Accessors

    /// The user's display name from the profile.
    var profileName: String {
        localStore.profile.displayName
    }

    /// The user's current streak count from the profile.
    var profileStreakDays: Int {
        localStore.profile.streakDays
    }

    // MARK: - Private Helpers

    /// Updates the streak counter based on last check-in date.
    ///
    /// If the user checked in yesterday, the streak continues.
    /// If they missed a day, it resets to 1 (for today's check-in).
    private func updateStreak() {
        let history = localStore.loadHistory()
        guard history.count >= 2 else {
            localStore.profile.streakDays = max(localStore.profile.streakDays, 1)
            localStore.saveProfile()
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastSnapshotDate = history[history.count - 2].snapshot.date
        let lastDay = calendar.startOfDay(for: lastSnapshotDate)

        if let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day,
           daysBetween == 1 {
            // Consecutive day; streak continues (already incremented if nudge completed)
            if localStore.profile.streakDays == 0 {
                localStore.profile.streakDays = 2
                localStore.saveProfile()
            }
        } else if let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day,
                  daysBetween > 1 {
            // Missed a day; reset streak
            localStore.profile.streakDays = 1
            localStore.saveProfile()
        }
    }

    // MARK: - Check-In

    /// Records a mood check-in for today.
    func submitCheckIn(mood: CheckInMood) {
        let response = CheckInResponse(
            date: Date(),
            feelingScore: mood.score,
            note: mood.label
        )
        localStore.saveCheckIn(response)
        hasCheckedInToday = true
        todayMood = mood
    }

    /// Loads today's check-in from local store.
    private func loadTodayCheckIn() {
        if let checkIn = localStore.loadTodayCheckIn() {
            hasCheckedInToday = true
            todayMood = CheckInMood.allCases.first { $0.score == checkIn.feelingScore }
        }
    }

    // MARK: - Smart Nudge Evaluation

    /// Checks if the user is already meeting the nudge recommendation
    /// based on today's HealthKit activity data.
    private func evaluateNudgeCompletion(nudge: DailyNudge, snapshot: HeartSnapshot) {
        switch nudge.category {
        case .walk:
            // If they already walked 15+ min today, they're on it
            if let walkMin = snapshot.walkMinutes, walkMin >= 15 {
                isNudgeAlreadyMet = true
                return
            }
        case .moderate:
            // If they already have 20+ workout minutes
            if let workoutMin = snapshot.workoutMinutes, workoutMin >= 20 {
                isNudgeAlreadyMet = true
                return
            }
        default:
            break
        }
        isNudgeAlreadyMet = false
    }

    // MARK: - Weekly Trend

    /// Computes a short weekly trend label for the buddy suggestion header.
    private func computeWeeklyTrend(history: [HeartSnapshot]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else {
            weeklyTrendSummary = nil
            return
        }

        let thisWeek = history.filter { $0.date >= weekAgo }
        let prevWeekStart = calendar.date(byAdding: .day, value: -14, to: today) ?? weekAgo
        let lastWeek = history.filter { $0.date >= prevWeekStart && $0.date < weekAgo }

        guard !thisWeek.isEmpty, !lastWeek.isEmpty else {
            weeklyTrendSummary = nil
            return
        }

        // Compare total active minutes (walk + workout)
        let thisWeekActive: Double = thisWeek.compactMap { s -> Double? in
            let w = s.walkMinutes ?? 0
            let wk = s.workoutMinutes ?? 0
            let total = w + wk
            return total > 0 ? total : nil
        }.reduce(0.0, +)

        let lastWeekActive: Double = lastWeek.compactMap { s -> Double? in
            let w = s.walkMinutes ?? 0
            let wk = s.workoutMinutes ?? 0
            let total = w + wk
            return total > 0 ? total : nil
        }.reduce(0.0, +)

        if lastWeekActive > 0 {
            let change = Int(((thisWeekActive - lastWeekActive) / lastWeekActive) * 100)
            if change > 5 {
                weeklyTrendSummary = "+\(change)% this week"
            } else if change < -5 {
                weeklyTrendSummary = "\(change)% this week"
            } else {
                weeklyTrendSummary = "Steady this week"
            }
        } else {
            weeklyTrendSummary = nil
        }
    }

    // MARK: - Bio Age

    /// Computes the bio age estimate from today's snapshot.
    private func computeBioAge(snapshot: HeartSnapshot) {
        guard let age = localStore.profile.chronologicalAge, age > 0 else {
            bioAgeResult = nil
            return
        }
        let engine = BioAgeEngine()
        bioAgeResult = engine.estimate(
            snapshot: snapshot,
            chronologicalAge: age,
            sex: localStore.profile.biologicalSex
        )
        if let result = bioAgeResult {
            AppLogger.engine.info("BioAge: bio=\(result.bioAge) chrono=\(result.chronologicalAge) diff=\(result.difference)")
        }
    }

    // MARK: - Readiness Score

    /// Computes the readiness score from today's snapshot and recent history.
    ///
    /// Uses the actual StressEngine score when available instead of the
    /// coarse 70.0 flag value (CR-011).
    private func computeReadiness(snapshot: HeartSnapshot, history: [HeartSnapshot]) {
        // Compute stress first so readiness gets the real score
        let stressEngine = StressEngine()
        let stress = stressEngine.computeStress(
            snapshot: snapshot,
            recentHistory: history
        )

        // Use actual stress score; fall back to flag-based estimate only when engine returns nil
        let stressScore: Double?
        if let stress {
            stressScore = stress.score
        } else if let assessment = assessment, assessment.stressFlag {
            stressScore = 70.0
        } else {
            stressScore = nil
        }

        let engine = ReadinessEngine()
        readinessResult = engine.compute(
            snapshot: snapshot,
            stressScore: stressScore,
            recentHistory: history,
            consecutiveAlert: assessment?.consecutiveAlert
        )
        if let result = readinessResult {
            let stressDesc = stressScore.map { String(format: "%.1f", $0) } ?? "nil"
            AppLogger.engine.info("Readiness: score=\(result.score) level=\(result.level.rawValue) stressInput=\(stressDesc)")
        }
    }

    // MARK: - Coaching Report

    private func computeCoachingReport(snapshot: HeartSnapshot, history: [HeartSnapshot]) {
        guard history.count >= 3 else {
            coachingReport = nil
            return
        }
        let engine = CoachingEngine()
        coachingReport = engine.generateReport(
            current: snapshot,
            history: history,
            streakDays: localStore.profile.streakDays
        )
    }

    // MARK: - Zone Analysis

    private func computeZoneAnalysis(snapshot: HeartSnapshot) {
        let zones = snapshot.zoneMinutes
        guard zones.count >= 5, zones.reduce(0, +) > 0 else {
            zoneAnalysis = nil
            return
        }
        let engine = HeartRateZoneEngine()
        zoneAnalysis = engine.analyzeZoneDistribution(zoneMinutes: zones)
    }

    // MARK: - Buddy Recommendations

    /// Synthesises all engine outputs into prioritised buddy recommendations.
    private func computeBuddyRecommendations(
        assessment: HeartAssessment,
        snapshot: HeartSnapshot,
        history: [HeartSnapshot]
    ) {
        let engine = BuddyRecommendationEngine()

        // Compute stress for the buddy engine and store for dashboard use
        let stressEngine = StressEngine()
        let computedStress = stressEngine.computeStress(
            snapshot: snapshot,
            recentHistory: history
        )
        self.stressResult = computedStress
        if let s = computedStress {
            AppLogger.engine.info("Stress: score=\(String(format: "%.1f", s.score)) level=\(s.level.rawValue)")
        }

        buddyRecommendations = engine.recommend(
            assessment: assessment,
            stressResult: computedStress,
            readinessScore: readinessResult.map { Double($0.score) },
            current: snapshot,
            history: history
        )
    }

    // MARK: - Notification Scheduling (CR-001)

    /// Schedules anomaly alerts and nudge reminders from live assessment output.
    ///
    /// Called at the end of `refresh()` after all engines have run, so the
    /// assessment's status, flags, and daily nudge are fully resolved.
    ///
    /// - Parameters:
    ///   - assessment: The freshly computed `HeartAssessment`.
    ///   - history: Recent snapshot history, used for smart nudge timing.
    private func scheduleNotificationsIfNeeded(
        assessment: HeartAssessment,
        history: [HeartSnapshot]
    ) {
        guard let notificationService, notificationService.isAuthorized else {
            return
        }

        // Schedule anomaly alert if the assessment needs attention
        if assessment.status == .needsAttention {
            notificationService.scheduleAnomalyAlert(assessment: assessment)
            AppLogger.engine.info("Notification: anomaly alert scheduled for status=\(assessment.status.rawValue)")
        }

        // Schedule smart nudge reminder for today's daily nudge
        let nudge = assessment.dailyNudge
        Task {
            await notificationService.scheduleSmartNudge(
                nudge: nudge,
                history: history
            )
            AppLogger.engine.info("Notification: smart nudge scheduled for category=\(nudge.category.rawValue)")
        }
    }

    private func bindToLocalStore(_ localStore: LocalStore) {
        currentTier = localStore.tier
        cancellables.removeAll()

        localStore.$tier
            .receive(on: RunLoop.main)
            .sink { [weak self] newTier in
                self?.currentTier = newTier
            }
            .store(in: &cancellables)
    }
}

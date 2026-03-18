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

    /// Centralized engine coordinator (used when ConfigService.enableCoordinator is true).
    /// Shared instance injected via bind() from the view layer.
    private var coordinator: DailyEngineCoordinator?

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
        notificationService: NotificationService? = nil,
        coordinator: DailyEngineCoordinator? = nil
    ) {
        self.healthDataProvider = healthDataProvider
        self.localStore = localStore
        self.notificationService = notificationService
        self.coordinator = coordinator
        bindToLocalStore(localStore)
    }

    /// Refreshes the dashboard by fetching today's snapshot, loading
    /// history, running the trend engine, and persisting the result.
    ///
    /// This is the primary data flow method called on appearance and
    /// pull-to-refresh. Errors are caught and surfaced via `errorMessage`.
    func refresh() async {
        if ConfigService.enableCoordinator {
            await refreshViaCoordinator()
            return
        }

        let refreshStart = CFAbsoluteTimeGetCurrent()
        AppLogger.engine.info("Dashboard refresh started")
        isLoading = true
        errorMessage = nil
        healthDataProvider.clearQueryWarnings()

        do {
            // Ensure HealthKit authorization
            if !healthDataProvider.isAuthorized {
                AppLogger.healthKit.info("Requesting HealthKit authorization")
                try await healthDataProvider.requestAuthorization()
                AppLogger.healthKit.info("HealthKit authorization granted")
            }

            // Fetch today's snapshot — fall back to mock data in simulator, retry once on device
            var snapshot: HeartSnapshot
            do {
                snapshot = try await healthDataProvider.fetchTodaySnapshot()
            } catch {
                #if targetEnvironment(simulator)
                snapshot = MockData.mockTodaySnapshot
                #else
                AppLogger.engine.warning("First snapshot attempt failed: \(error.localizedDescription). Retrying after re-authorization…")
                // Re-request authorization and retry once — handles race condition
                // where HealthKit hasn't fully propagated auth after onboarding
                do {
                    try await healthDataProvider.requestAuthorization()
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s for auth propagation
                    snapshot = try await healthDataProvider.fetchTodaySnapshot()
                } catch {
                    AppLogger.engine.error("Retry also failed: \(error.localizedDescription)")
                    errorMessage = "Unable to read today's health data. Please check Health permissions in Settings."
                    isLoading = false
                    return
                }
                #endif
            }

            // Simulator fallback: if snapshot has nil HRV (no real HealthKit data), use mock data
            #if targetEnvironment(simulator)
            if snapshot.hrvSDNN == nil {
                snapshot = MockData.mockTodaySnapshot
            }
            #endif
            todaySnapshot = snapshot

            // Fetch historical snapshots — fall back to mock history in simulator, retry once on device
            var history: [HeartSnapshot]
            do {
                history = try await healthDataProvider.fetchHistory(days: historyDays)
            } catch {
                #if targetEnvironment(simulator)
                history = MockData.mockHistory(days: historyDays)
                #else
                AppLogger.engine.warning("First history attempt failed: \(error.localizedDescription). Retrying after re-authorization…")
                do {
                    try await healthDataProvider.requestAuthorization()
                    try await Task.sleep(nanoseconds: 500_000_000)
                    history = try await healthDataProvider.fetchHistory(days: historyDays)
                } catch {
                    AppLogger.engine.error("History retry also failed: \(error.localizedDescription)")
                    errorMessage = "Unable to read health history. Please check Health permissions in Settings."
                    isLoading = false
                    return
                }
                #endif
            }

            // Simulator fallback: if all snapshots have nil HRV (no real HealthKit data), use mock data
            #if targetEnvironment(simulator)
            let hasRealHistoryData = history.contains(where: { $0.hrvSDNN != nil })
            if !hasRealHistoryData {
                history = MockData.mockHistory(days: historyDays)
            }
            #endif

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

            // Broadcast readiness level so StressViewModel's conflict guard stays in sync
            if let readinessScore = result.recoveryContext?.readinessScore {
                let readinessLevel = ReadinessLevel.from(score: readinessScore)
                NotificationCenter.default.post(
                    name: .thumpReadinessDidUpdate,
                    object: nil,
                    userInfo: ["readinessLevel": readinessLevel.rawValue]
                )
            }

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
            let bioAgeStart = CFAbsoluteTimeGetCurrent()
            computeBioAge(snapshot: snapshot)
            let bioAgeMs = (CFAbsoluteTimeGetCurrent() - bioAgeStart) * 1000

            // Compute readiness score
            let readinessStart = CFAbsoluteTimeGetCurrent()
            computeReadiness(snapshot: snapshot, history: history)
            let readinessMs = (CFAbsoluteTimeGetCurrent() - readinessStart) * 1000

            // Compute coaching report
            let coachingStart = CFAbsoluteTimeGetCurrent()
            computeCoachingReport(snapshot: snapshot, history: history)
            let coachingMs = (CFAbsoluteTimeGetCurrent() - coachingStart) * 1000

            // Compute zone analysis
            let zoneStart = CFAbsoluteTimeGetCurrent()
            computeZoneAnalysis(snapshot: snapshot)
            let zoneMs = (CFAbsoluteTimeGetCurrent() - zoneStart) * 1000

            // Compute buddy recommendations (after readiness and stress are available)
            let buddyStart = CFAbsoluteTimeGetCurrent()
            computeBuddyRecommendations(
                assessment: result,
                snapshot: snapshot,
                history: history
            )
            let buddyMs = (CFAbsoluteTimeGetCurrent() - buddyStart) * 1000

            // Schedule notifications from live assessment output (CR-001)
            scheduleNotificationsIfNeeded(assessment: result, history: history)

            let totalMs = (CFAbsoluteTimeGetCurrent() - refreshStart) * 1000
            AppLogger.engine.info("Dashboard refresh complete in \(String(format: "%.0f", totalMs))ms — history=\(history.count) days")

            isLoading = false

            // Write diagnostic snapshot for bug reports (BUG-070)
            writeDiagnosticSnapshot(assessment: result, snapshot: snapshot)

            // Upload engine pipeline trace for quality baselining
            var trace = PipelineTrace(
                timestamp: Date(),
                pipelineDurationMs: totalMs,
                historyDays: history.count
            )
            trace.heartTrend = HeartTrendTrace(from: result, durationMs: engineMs)
            if let s = stressResult {
                // Stress duration is included in buddyMs (computed inside computeBuddyRecommendations)
                trace.stress = StressTrace(from: s, durationMs: buddyMs)
            }
            if let r = readinessResult {
                trace.readiness = ReadinessTrace(from: r, durationMs: readinessMs)
            }
            if let b = bioAgeResult {
                trace.bioAge = BioAgeTrace(from: b, durationMs: bioAgeMs)
            }
            if let c = coachingReport {
                trace.coaching = CoachingTrace(from: c, durationMs: coachingMs)
            }
            if let z = zoneAnalysis {
                trace.zoneAnalysis = ZoneAnalysisTrace(from: z, durationMs: zoneMs)
            }
            if let recs = buddyRecommendations {
                trace.buddy = BuddyTrace(from: recs, durationMs: buddyMs)
            }
            trace.inputSummary = InputSummaryTrace(snapshot: snapshot, history: history)
            EngineTelemetryService.shared.uploadTrace(trace)
        } catch {
            AppLogger.engine.error("Dashboard refresh failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Coordinator Path

    /// Refreshes the dashboard using the centralized DailyEngineCoordinator.
    /// All engines run exactly once in DAG order through the coordinator.
    private func refreshViaCoordinator() async {
        let coord = coordinator ?? DailyEngineCoordinator()
        if coordinator == nil { coordinator = coord }
        coord.bind(healthDataProvider: healthDataProvider, localStore: localStore)
        await coord.refresh()

        guard let bundle = coord.bundle else {
            isLoading = coord.isLoading
            errorMessage = coord.errorMessage
            return
        }

        // Map bundle fields to existing @Published properties
        assessment = bundle.assessment
        todaySnapshot = bundle.snapshot
        stressResult = bundle.stressResult
        readinessResult = bundle.readinessResult
        bioAgeResult = bundle.bioAgeResult
        coachingReport = bundle.coachingReport
        zoneAnalysis = bundle.zoneAnalysis
        buddyRecommendations = bundle.buddyRecommendations

        // Persist snapshot + assessment
        let stored = StoredSnapshot(snapshot: bundle.snapshot, assessment: bundle.assessment)
        localStore.appendSnapshot(stored)

        // Streak, nudge completion, check-in, weekly trend
        updateStreak()
        evaluateNudgeCompletion(nudge: bundle.assessment.dailyNudge, snapshot: bundle.snapshot)
        computeWeeklyTrend(history: bundle.history)
        loadTodayCheckIn()

        // Notifications
        scheduleNotificationsIfNeeded(assessment: bundle.assessment, history: bundle.history)

        // Diagnostics
        writeDiagnosticSnapshot(assessment: bundle.assessment, snapshot: bundle.snapshot)

        // Telemetry
        if let trace = bundle.pipelineTrace {
            EngineTelemetryService.shared.uploadTrace(trace)
        }

        isLoading = false
        errorMessage = nil
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

    /// Whether the user is in Chronic Steady state (score 0–44 for 14+ consecutive days).
    /// Used by the Design B dashboard to activate the §21.3 score de-escalation hierarchy.
    var isChronicSteady: Bool {
        localStore.profile.isChronicSteady
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
        let stressConf: StressConfidence?
        if let stress {
            stressScore = stress.score
            stressConf = stress.confidence
        } else if let assessment = assessment, assessment.stressFlag {
            stressScore = 70.0
            stressConf = .low
        } else {
            stressScore = nil
            stressConf = nil
        }

        let engine = ReadinessEngine()
        readinessResult = engine.compute(
            snapshot: snapshot,
            stressScore: stressScore,
            stressConfidence: stressConf,
            recentHistory: history,
            consecutiveAlert: assessment?.consecutiveAlert
        )
        if let result = readinessResult {
            let stressDesc = stressScore.map { String(format: "%.1f", $0) } ?? "nil"
            let confDesc = stressConf?.rawValue ?? "nil"
            AppLogger.engine.info("Readiness: score=\(result.score) level=\(result.level.rawValue) stressInput=\(stressDesc) stressConf=\(confDesc)")
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
            streakDays: localStore.profile.streakDays,
            readiness: readinessResult
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
            AppLogger.engine.info("Stress: score=\(String(format: "%.1f", s.score)) level=\(s.level.rawValue) mode=\(s.mode.rawValue) confidence=\(s.confidence.rawValue)")
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

    // MARK: - Diagnostic Snapshot (BUG-070)

    /// Writes all engine outputs and UI display strings to LocalStore so
    /// the bug report can capture exactly what the user sees on screen.
    private func writeDiagnosticSnapshot(
        assessment: HeartAssessment,
        snapshot: HeartSnapshot
    ) {
        var diag: [String: Any] = [:]

        // Assessment display text
        diag["assessmentStatus"] = assessment.status.rawValue
        diag["assessmentExplanation"] = assessment.explanation
        diag["assessmentConfidence"] = assessment.confidence.rawValue
        diag["anomalyScore"] = assessment.anomalyScore
        diag["regressionFlag"] = assessment.regressionFlag
        diag["stressFlag"] = assessment.stressFlag
        if let score = assessment.cardioScore {
            diag["cardioScore"] = score
        }

        // Nudge display text
        let nudge = assessment.dailyNudge
        diag["nudgeTitle"] = nudge.title
        diag["nudgeDescription"] = nudge.description
        diag["nudgeCategory"] = nudge.category.rawValue
        diag["nudgeIcon"] = nudge.icon
        if let dur = nudge.durationMinutes {
            diag["nudgeDurationMinutes"] = dur
        }

        // All nudges
        var nudgeTexts: [[String: String]] = []
        for n in assessment.dailyNudges {
            nudgeTexts.append([
                "title": n.title,
                "description": n.description,
                "category": n.category.rawValue,
                "icon": n.icon
            ])
        }
        diag["allNudges"] = nudgeTexts

        // Week-over-week trend text
        if let wow = assessment.weekOverWeekTrend {
            diag["wowDirection"] = wow.direction.rawValue
            diag["wowCurrentMean"] = wow.currentWeekMean
            diag["wowBaselineMean"] = wow.baselineMean
        }

        // Consecutive alert
        if let alert = assessment.consecutiveAlert {
            diag["consecutiveAlertDays"] = alert.consecutiveDays
            diag["consecutiveAlertThreshold"] = alert.threshold
            diag["consecutiveAlertElevatedMean"] = alert.elevatedMean
        }

        // Coaching scenario
        if let scenario = assessment.scenario {
            diag["coachingScenario"] = scenario.rawValue
        }

        // Readiness (rendered text)
        if let r = readinessResult {
            diag["readinessScore"] = r.score
            diag["readinessLevel"] = r.level.rawValue
            diag["readinessSummary"] = r.summary
            var pillars: [[String: Any]] = []
            for p in r.pillars {
                pillars.append([
                    "type": p.type.rawValue,
                    "score": p.score,
                    "detail": p.detail
                ])
            }
            diag["readinessPillars"] = pillars
        }

        // Stress (rendered text)
        if let s = stressResult {
            diag["stressScore"] = s.score
            diag["stressLevel"] = s.level.rawValue
            diag["stressDescription"] = s.description
            diag["stressMode"] = s.mode.rawValue
            diag["stressConfidence"] = s.confidence.rawValue
            if !s.warnings.isEmpty {
                diag["stressWarnings"] = s.warnings
            }
        }

        // Bio age (rendered text)
        if let b = bioAgeResult {
            diag["bioAge"] = b.bioAge
            diag["chronologicalAge"] = b.chronologicalAge
            diag["bioAgeDifference"] = b.difference
            diag["bioAgeCategory"] = b.category.rawValue
            diag["bioAgeExplanation"] = b.explanation
        }

        // Coaching report (rendered text)
        if let c = coachingReport {
            diag["coachingHeroMessage"] = c.heroMessage
            diag["coachingProgressScore"] = c.weeklyProgressScore
            diag["coachingStreak"] = c.streakDays
            var insights: [[String: String]] = []
            for i in c.insights {
                insights.append([
                    "metric": i.metric.rawValue,
                    "direction": i.direction.rawValue,
                    "message": i.message
                ])
            }
            diag["coachingInsights"] = insights
        }

        // Zone analysis (rendered text)
        if let z = zoneAnalysis {
            diag["zoneOverallScore"] = z.overallScore
            diag["zoneCoachingMessage"] = z.coachingMessage
            if let rec = z.recommendation {
                diag["zoneRecommendation"] = rec.rawValue
            }
        }

        // Buddy recommendations (rendered text — every card the user sees)
        if let recs = buddyRecommendations {
            var buddyCards: [[String: String]] = []
            for r in recs {
                buddyCards.append([
                    "title": r.title,
                    "message": r.message,
                    "detail": r.detail,
                    "icon": r.icon,
                    "category": r.category.rawValue,
                    "priority": "\(r.priority.rawValue)",
                    "source": r.source.rawValue
                ])
            }
            diag["buddyRecommendations"] = buddyCards
        }

        // Weekly trend summary
        if let trend = weeklyTrendSummary {
            diag["weeklyTrendSummary"] = trend
        }

        // Streak and mood
        diag["streakDays"] = localStore.profile.streakDays
        if let mood = todayMood {
            diag["todayMood"] = mood.rawValue
        }
        diag["hasCheckedIn"] = hasCheckedInToday

        // Stress hourly data availability (BUG-070 gap: heatmap debugging)
        let diagStressEngine = StressEngine()
        if let snap = todaySnapshot {
            let allSnapshots = localStore.loadHistory().map(\.snapshot) + [snap]
            let hourlyPoints = diagStressEngine.hourlyStressForDay(
                snapshots: allSnapshots,
                date: snap.date
            )
            diag["stressHourlyPointCount"] = hourlyPoints.count
            if hourlyPoints.isEmpty {
                diag["stressHourlyEmpty"] = true
                diag["stressHourlyEmptyReason"] = "hourlyStressForDay returned 0 points — likely no HRV data"
            }
        }

        // HealthKit query warnings (BUG-070 gap: explains why metrics are nil)
        let warnings = healthDataProvider.queryWarnings
        if !warnings.isEmpty {
            diag["healthKitQueryWarnings"] = warnings
            diag["healthKitQueryWarningCount"] = warnings.count
        }

        // Timestamp
        diag["capturedAt"] = ISO8601DateFormatter().string(from: Date())

        localStore.diagnosticSnapshot = diag
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

// DailyEngineCoordinator.swift
// Thump iOS
//
// Centralized engine orchestrator that runs all 10 engines in DAG order
// exactly once per refresh. Replaces scattered engine calls across
// DashboardViewModel, StressViewModel, and InsightsViewModel.
//
// Feature-flagged via ConfigService.enableCoordinator (default false).
// Platforms: iOS 17+

import Foundation
import Combine

// MARK: - Daily Engine Coordinator

/// Orchestrates the complete engine pipeline in dependency order.
///
/// Each engine runs exactly once per refresh. Results are published
/// as an immutable `DailyEngineBundle` that view models subscribe to.
///
/// **DAG order:**
/// 1. Fetch snapshot + history (HealthKit)
/// 2. HeartTrendEngine.assess() — needs history, snapshot
/// 3. StressEngine.computeStress() — needs snapshot, history (once, was 2-3x)
/// 4. ReadinessEngine.compute() — needs stress score + confidence
/// 5. CoachingEngine.generateReport() — needs readiness
/// 6. BioAgeEngine.estimate() — independent, needs DOB
/// 7. HeartRateZoneEngine.analyzeZoneDistribution() — independent
/// 8. BuddyRecommendationEngine.recommend() — needs assessment + stress + readiness
/// 9. CorrelationEngine.analyze() — independent, needs history
/// 10. SmartNudgeScheduler.learnSleepPatterns() — independent, needs history
@MainActor
final class DailyEngineCoordinator: ObservableObject {

    // MARK: - Published State

    /// The latest engine pipeline result. Nil until first refresh.
    @Published private(set) var bundle: DailyEngineBundle?

    /// Whether a refresh is currently in progress.
    @Published private(set) var isLoading: Bool = false

    /// Human-readable error from the last failed refresh.
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    private var healthDataProvider: any HealthDataProviding
    private var localStore: LocalStore

    // MARK: - Single Engine Instances

    private let stressEngine = StressEngine()
    private let readinessEngine = ReadinessEngine()
    private let coachingEngine = CoachingEngine()
    private let bioAgeEngine = BioAgeEngine()
    private let zoneEngine = HeartRateZoneEngine()
    private let buddyEngine = BuddyRecommendationEngine()
    private let correlationEngine = CorrelationEngine()
    private let nudgeScheduler = SmartNudgeScheduler()
    private let adviceComposer = AdviceComposer()

    // MARK: - Configuration

    private let historyDays: Int = ConfigService.defaultLookbackWindow

    /// Maximum age of a bundle before it's considered stale.
    private let stalenessThreshold: TimeInterval = 30 * 60 // 30 minutes

    /// When true, disables simulator MockData fallback so error paths are testable.
    var disableSimulatorFallback: Bool = false

    // MARK: - Init

    init(
        healthDataProvider: any HealthDataProviding = HealthKitService(),
        localStore: LocalStore = LocalStore()
    ) {
        self.healthDataProvider = healthDataProvider
        self.localStore = localStore
    }

    /// Rebinds dependencies (used when DashboardViewModel.bind() is called).
    func bind(
        healthDataProvider: any HealthDataProviding,
        localStore: LocalStore
    ) {
        self.healthDataProvider = healthDataProvider
        self.localStore = localStore
    }

    // MARK: - Staleness Check

    /// Whether the current bundle is stale and needs refreshing.
    var isStale: Bool {
        guard let bundle else { return true }
        return Date().timeIntervalSince(bundle.timestamp) > stalenessThreshold
    }

    // MARK: - Refresh

    /// Runs the complete engine pipeline in DAG order.
    ///
    /// Each engine is called exactly once. Results are packaged into
    /// an immutable `DailyEngineBundle` and published.
    func refresh() async {
        let refreshStart = CFAbsoluteTimeGetCurrent()
        AppLogger.engine.info("[Coordinator] Pipeline refresh started")
        isLoading = true
        errorMessage = nil
        healthDataProvider.clearQueryWarnings()

        do {
            // ── Step 0: Authorization ──
            if !healthDataProvider.isAuthorized {
                try await healthDataProvider.requestAuthorization()
            }

            // ── Step 1: Fetch snapshot + history ──
            let (snapshot, history) = try await fetchData()

            // Load today's feedback
            let feedbackPayload = localStore.loadLastFeedback()
            let feedback: DailyFeedback?
            if let feedbackPayload,
               Calendar.current.isDate(feedbackPayload.date, inSameDayAs: snapshot.date) {
                feedback = feedbackPayload.response
            } else {
                feedback = nil
            }

            // ── Step 2: HeartTrendEngine ──
            let trendStart = CFAbsoluteTimeGetCurrent()
            let trendEngine = ConfigService.makeDefaultEngine()
            let assessment = trendEngine.assess(
                history: history,
                current: snapshot,
                feedback: feedback
            )
            let trendMs = (CFAbsoluteTimeGetCurrent() - trendStart) * 1000

            // ── Step 3: StressEngine (ONCE — was 2-3x) ──
            let stressStart = CFAbsoluteTimeGetCurrent()
            let stressResult = stressEngine.computeStress(
                snapshot: snapshot,
                recentHistory: history
            )
            let stressMs = (CFAbsoluteTimeGetCurrent() - stressStart) * 1000

            // ── Step 4: ReadinessEngine (ONCE — was 3x) ──
            let readinessStart = CFAbsoluteTimeGetCurrent()
            let (stressScore, stressConf) = resolveStressInput(
                stressResult: stressResult,
                assessment: assessment
            )
            let readinessResult = readinessEngine.compute(
                snapshot: snapshot,
                stressScore: stressScore,
                stressConfidence: stressConf,
                recentHistory: history,
                consecutiveAlert: assessment.consecutiveAlert
            )
            let readinessMs = (CFAbsoluteTimeGetCurrent() - readinessStart) * 1000

            // Broadcast readiness for StressViewModel conflict guard
            if let readinessScore = assessment.recoveryContext?.readinessScore {
                let readinessLevel = ReadinessLevel.from(score: readinessScore)
                NotificationCenter.default.post(
                    name: .thumpReadinessDidUpdate,
                    object: nil,
                    userInfo: ["readinessLevel": readinessLevel.rawValue]
                )
            }

            // ── Step 5: CoachingEngine ──
            let coachingStart = CFAbsoluteTimeGetCurrent()
            let coachingReport: CoachingReport?
            if history.count >= 3 {
                coachingReport = coachingEngine.generateReport(
                    current: snapshot,
                    history: history,
                    streakDays: localStore.profile.streakDays,
                    readiness: readinessResult
                )
            } else {
                coachingReport = nil
            }
            let coachingMs = (CFAbsoluteTimeGetCurrent() - coachingStart) * 1000

            // ── Step 6: BioAgeEngine ──
            let bioAgeStart = CFAbsoluteTimeGetCurrent()
            let bioAgeResult: BioAgeResult?
            if let age = localStore.profile.chronologicalAge, age > 0 {
                bioAgeResult = bioAgeEngine.estimate(
                    snapshot: snapshot,
                    chronologicalAge: age,
                    sex: localStore.profile.biologicalSex
                )
            } else {
                bioAgeResult = nil
            }
            let bioAgeMs = (CFAbsoluteTimeGetCurrent() - bioAgeStart) * 1000

            // ── Step 7: HeartRateZoneEngine ──
            let zoneStart = CFAbsoluteTimeGetCurrent()
            let zoneAnalysis: ZoneAnalysis?
            let zones = snapshot.zoneMinutes
            if zones.count >= 5, zones.reduce(0, +) > 0 {
                zoneAnalysis = zoneEngine.analyzeZoneDistribution(zoneMinutes: zones)
            } else {
                zoneAnalysis = nil
            }
            let zoneMs = (CFAbsoluteTimeGetCurrent() - zoneStart) * 1000

            // ── Step 8: BuddyRecommendationEngine ──
            let buddyStart = CFAbsoluteTimeGetCurrent()
            let buddyRecommendations = buddyEngine.recommend(
                assessment: assessment,
                stressResult: stressResult,
                readinessScore: readinessResult.map { Double($0.score) },
                current: snapshot,
                history: history
            )
            let buddyMs = (CFAbsoluteTimeGetCurrent() - buddyStart) * 1000

            // ── Step 9: CorrelationEngine ──
            let correlationStart = CFAbsoluteTimeGetCurrent()
            let correlations = correlationEngine.analyze(history: history)
            let correlationMs = (CFAbsoluteTimeGetCurrent() - correlationStart) * 1000

            // ── Step 10: SmartNudgeScheduler ──
            let nudgeStart = CFAbsoluteTimeGetCurrent()
            let sleepPatterns = nudgeScheduler.learnSleepPatterns(from: history)
            let nudgeSchedulerMs = (CFAbsoluteTimeGetCurrent() - nudgeStart) * 1000

            let totalMs = (CFAbsoluteTimeGetCurrent() - refreshStart) * 1000

            // ── Build Pipeline Trace ──
            let timings = EngineTimings(
                trendMs: trendMs,
                stressMs: stressMs,
                readinessMs: readinessMs,
                bioAgeMs: bioAgeMs,
                coachingMs: coachingMs,
                zoneMs: zoneMs,
                buddyMs: buddyMs,
                correlationMs: correlationMs,
                nudgeSchedulerMs: nudgeSchedulerMs,
                totalMs: totalMs
            )

            var trace = buildTrace(
                assessment: assessment,
                stressResult: stressResult,
                readinessResult: readinessResult,
                bioAgeResult: bioAgeResult,
                coachingReport: coachingReport,
                zoneAnalysis: zoneAnalysis,
                buddyRecommendations: buddyRecommendations,
                snapshot: snapshot,
                history: history,
                timings: timings
            )

            // ── Step 11: AdviceComposer ──
            let adviceStart = CFAbsoluteTimeGetCurrent()
            let adviceState = adviceComposer.compose(
                snapshot: snapshot,
                assessment: assessment,
                stressResult: stressResult,
                readinessResult: readinessResult,
                zoneAnalysis: zoneAnalysis,
                config: ConfigService.activePolicy
            )
            let adviceMs = (CFAbsoluteTimeGetCurrent() - adviceStart) * 1000

            // ── Step 12: Populate orchestrator traces ──
            trace.advice = AdviceTrace(from: adviceState, durationMs: adviceMs)
            trace.correlation = CorrelationTrace(from: correlations, durationMs: correlationMs)
            trace.nudgeScheduler = NudgeSchedulerTrace(from: sleepPatterns, durationMs: nudgeSchedulerMs)
            trace.coherence = CoherenceChecker.check(
                adviceState: adviceState,
                readinessResult: readinessResult,
                config: ConfigService.activePolicy
            )

            // ── Package Bundle ──
            let newBundle = DailyEngineBundle(
                timestamp: Date(),
                snapshot: snapshot,
                history: history,
                feedback: feedback,
                assessment: assessment,
                stressResult: stressResult,
                readinessResult: readinessResult,
                bioAgeResult: bioAgeResult,
                coachingReport: coachingReport,
                zoneAnalysis: zoneAnalysis,
                buddyRecommendations: buddyRecommendations,
                correlations: correlations,
                sleepPatterns: sleepPatterns,
                adviceState: adviceState,
                pipelineTrace: trace,
                engineTimings: timings
            )

            bundle = newBundle
            isLoading = false

            AppLogger.engine.info("[Coordinator] Pipeline complete in \(String(format: "%.0f", totalMs))ms — history=\(history.count) days")

        } catch {
            AppLogger.engine.error("[Coordinator] Pipeline failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Private Helpers

    /// Fetches today's snapshot and history with retry logic.
    private func fetchData() async throws -> (HeartSnapshot, [HeartSnapshot]) {
        var snapshot: HeartSnapshot
        do {
            snapshot = try await healthDataProvider.fetchTodaySnapshot()
        } catch {
            #if targetEnvironment(simulator)
            if disableSimulatorFallback { throw error }
            snapshot = MockData.mockTodaySnapshot
            #else
            AppLogger.engine.warning("[Coordinator] Snapshot fetch failed, retrying: \(error.localizedDescription)")
            try await healthDataProvider.requestAuthorization()
            try await Task.sleep(nanoseconds: 500_000_000)
            snapshot = try await healthDataProvider.fetchTodaySnapshot()
            #endif
        }

        #if targetEnvironment(simulator)
        if !disableSimulatorFallback && snapshot.hrvSDNN == nil {
            snapshot = MockData.mockTodaySnapshot
        }
        #endif

        var history: [HeartSnapshot]
        do {
            history = try await healthDataProvider.fetchHistory(days: historyDays)
        } catch {
            #if targetEnvironment(simulator)
            if disableSimulatorFallback { throw error }
            history = MockData.mockHistory(days: historyDays)
            #else
            AppLogger.engine.warning("[Coordinator] History fetch failed, retrying: \(error.localizedDescription)")
            try await healthDataProvider.requestAuthorization()
            try await Task.sleep(nanoseconds: 500_000_000)
            history = try await healthDataProvider.fetchHistory(days: historyDays)
            #endif
        }

        #if targetEnvironment(simulator)
        if !disableSimulatorFallback && !history.contains(where: { $0.hrvSDNN != nil }) {
            history = MockData.mockHistory(days: historyDays)
        }
        #endif

        return (snapshot, history)
    }

    /// Resolves stress input for ReadinessEngine — uses real score when available,
    /// falls back to flag-based estimate (CR-011).
    private func resolveStressInput(
        stressResult: StressResult?,
        assessment: HeartAssessment
    ) -> (Double?, StressConfidence?) {
        if let stress = stressResult {
            return (stress.score, stress.confidence)
        } else if assessment.stressFlag {
            return (70.0, .low)
        } else {
            return (nil, nil)
        }
    }

    /// Builds the pipeline trace from engine outputs and timings.
    private func buildTrace(
        assessment: HeartAssessment,
        stressResult: StressResult?,
        readinessResult: ReadinessResult?,
        bioAgeResult: BioAgeResult?,
        coachingReport: CoachingReport?,
        zoneAnalysis: ZoneAnalysis?,
        buddyRecommendations: [BuddyRecommendation]?,
        snapshot: HeartSnapshot,
        history: [HeartSnapshot],
        timings: EngineTimings
    ) -> PipelineTrace {
        var trace = PipelineTrace(
            timestamp: Date(),
            pipelineDurationMs: timings.totalMs,
            historyDays: history.count
        )
        trace.heartTrend = HeartTrendTrace(from: assessment, durationMs: timings.trendMs)
        if let s = stressResult {
            trace.stress = StressTrace(from: s, durationMs: timings.stressMs)
        }
        if let r = readinessResult {
            trace.readiness = ReadinessTrace(from: r, durationMs: timings.readinessMs)
        }
        if let b = bioAgeResult {
            trace.bioAge = BioAgeTrace(from: b, durationMs: timings.bioAgeMs)
        }
        if let c = coachingReport {
            trace.coaching = CoachingTrace(from: c, durationMs: timings.coachingMs)
        }
        if let z = zoneAnalysis {
            trace.zoneAnalysis = ZoneAnalysisTrace(from: z, durationMs: timings.zoneMs)
        }
        if let recs = buddyRecommendations {
            trace.buddy = BuddyTrace(from: recs, durationMs: timings.buddyMs)
        }
        trace.inputSummary = InputSummaryTrace(snapshot: snapshot, history: history)
        return trace
    }
}

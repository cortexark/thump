// DailyEngineBundle.swift
// Thump Shared
//
// Immutable bundle capturing a single engine pipeline run.
// Contains all 10 engine outputs, the input snapshot/history,
// and the pipeline trace. Produced by DailyEngineCoordinator
// and consumed by view models.
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Daily Engine Bundle

/// Immutable result of a single engine pipeline run.
///
/// Contains every engine output so view models can read from a single
/// source of truth instead of calling engines independently.
struct DailyEngineBundle: Sendable {

    // MARK: - Metadata

    /// When this bundle was computed.
    let timestamp: Date

    // MARK: - Inputs

    /// Today's raw health metrics snapshot.
    let snapshot: HeartSnapshot

    /// Historical snapshots used as engine input.
    let history: [HeartSnapshot]

    /// Today's feedback, if any.
    let feedback: DailyFeedback?

    // MARK: - Engine Outputs

    /// Heart trend assessment (status, anomaly, alerts, nudges).
    let assessment: HeartAssessment

    /// Stress computation result.
    let stressResult: StressResult?

    /// Readiness score and pillar breakdown.
    let readinessResult: ReadinessResult?

    /// Bio age estimate (nil if DOB not set).
    let bioAgeResult: BioAgeResult?

    /// Coaching report with insights, projections, hero message.
    let coachingReport: CoachingReport?

    /// Heart rate zone distribution analysis.
    let zoneAnalysis: ZoneAnalysis?

    /// Prioritised buddy recommendations from all engine signals.
    let buddyRecommendations: [BuddyRecommendation]?

    /// Factor correlations (sleep↔HRV, steps↔RHR, etc).
    let correlations: [CorrelationResult]

    /// Learned sleep patterns for smart nudge scheduling.
    let sleepPatterns: [SleepPattern]

    // MARK: - Advice

    /// Unified coaching decision state (Phase 3).
    let adviceState: AdviceState?

    // MARK: - Telemetry

    /// Pipeline trace for telemetry upload.
    let pipelineTrace: PipelineTrace?

    // MARK: - Timing

    /// Per-engine durations in milliseconds.
    let engineTimings: EngineTimings

    // MARK: - Init

    init(
        timestamp: Date,
        snapshot: HeartSnapshot,
        history: [HeartSnapshot],
        feedback: DailyFeedback?,
        assessment: HeartAssessment,
        stressResult: StressResult?,
        readinessResult: ReadinessResult?,
        bioAgeResult: BioAgeResult?,
        coachingReport: CoachingReport?,
        zoneAnalysis: ZoneAnalysis?,
        buddyRecommendations: [BuddyRecommendation]?,
        correlations: [CorrelationResult],
        sleepPatterns: [SleepPattern],
        adviceState: AdviceState? = nil,
        pipelineTrace: PipelineTrace?,
        engineTimings: EngineTimings
    ) {
        self.timestamp = timestamp
        self.snapshot = snapshot
        self.history = history
        self.feedback = feedback
        self.assessment = assessment
        self.stressResult = stressResult
        self.readinessResult = readinessResult
        self.bioAgeResult = bioAgeResult
        self.coachingReport = coachingReport
        self.zoneAnalysis = zoneAnalysis
        self.buddyRecommendations = buddyRecommendations
        self.correlations = correlations
        self.sleepPatterns = sleepPatterns
        self.adviceState = adviceState
        self.pipelineTrace = pipelineTrace
        self.engineTimings = engineTimings
    }
}

// MARK: - Engine Timings

/// Per-engine execution durations in milliseconds.
struct EngineTimings: Sendable {
    let trendMs: Double
    let stressMs: Double
    let readinessMs: Double
    let bioAgeMs: Double
    let coachingMs: Double
    let zoneMs: Double
    let buddyMs: Double
    let correlationMs: Double
    let nudgeSchedulerMs: Double
    let totalMs: Double

    init(
        trendMs: Double = 0,
        stressMs: Double = 0,
        readinessMs: Double = 0,
        bioAgeMs: Double = 0,
        coachingMs: Double = 0,
        zoneMs: Double = 0,
        buddyMs: Double = 0,
        correlationMs: Double = 0,
        nudgeSchedulerMs: Double = 0,
        totalMs: Double = 0
    ) {
        self.trendMs = trendMs
        self.stressMs = stressMs
        self.readinessMs = readinessMs
        self.bioAgeMs = bioAgeMs
        self.coachingMs = coachingMs
        self.zoneMs = zoneMs
        self.buddyMs = buddyMs
        self.correlationMs = correlationMs
        self.nudgeSchedulerMs = nudgeSchedulerMs
        self.totalMs = totalMs
    }
}

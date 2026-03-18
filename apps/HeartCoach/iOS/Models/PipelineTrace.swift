// PipelineTrace.swift
// Thump iOS
//
// Data model capturing a complete engine pipeline run for telemetry.
// Each trace records computed scores, confidence levels, timing, and
// metadata — never raw HealthKit values. Converted to Firestore-
// friendly dictionaries for upload.
// Platforms: iOS 17+

import Foundation
import FirebaseFirestore

// MARK: - Pipeline Trace

/// Captures one full dashboard refresh pipeline run for telemetry.
///
/// Contains per-engine scores, confidence levels, durations, and
/// counts — but never raw HealthKit values (RHR, HRV, steps, etc.).
/// Converted to a `[String: Any]` dictionary for Firestore upload.
struct PipelineTrace {

    // MARK: - Metadata

    /// When the pipeline ran.
    let timestamp: Date

    /// Total wall time for the refresh in milliseconds.
    let pipelineDurationMs: Double

    /// Number of history days used as engine input.
    let historyDays: Int

    // MARK: - Engine Results (all optional)

    var heartTrend: HeartTrendTrace?
    var stress: StressTrace?
    var readiness: ReadinessTrace?
    var bioAge: BioAgeTrace?
    var coaching: CoachingTrace?
    var zoneAnalysis: ZoneAnalysisTrace?
    var buddy: BuddyTrace?

    // MARK: - Orchestrator Traces (Phase 4)

    var advice: AdviceTrace?
    var coherence: CoherenceTrace?
    var correlation: CorrelationTrace?
    var nudgeScheduler: NudgeSchedulerTrace?

    // MARK: - Input Summary (statistical, not raw)

    /// Aggregated health input stats for remote debugging.
    /// Contains means, categories, and completeness — never raw values.
    var inputSummary: InputSummaryTrace?

    // MARK: - Firestore Conversion

    /// Converts the trace to a Firestore-compatible dictionary.
    ///
    /// Includes app version, build number, device model, and a
    /// server timestamp for consistent ordering.
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "timestamp": FieldValue.serverTimestamp(),
            "clientTimestamp": Timestamp(date: timestamp),
            "pipelineDurationMs": pipelineDurationMs,
            "historyDays": historyDays,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "deviceModel": deviceModel()
        ]

        if let heartTrend { data["heartTrend"] = heartTrend.toDict() }
        if let stress { data["stress"] = stress.toDict() }
        if let readiness { data["readiness"] = readiness.toDict() }
        if let bioAge { data["bioAge"] = bioAge.toDict() }
        if let coaching { data["coaching"] = coaching.toDict() }
        if let zoneAnalysis { data["zoneAnalysis"] = zoneAnalysis.toDict() }
        if let buddy { data["buddy"] = buddy.toDict() }
        if let advice { data["advice"] = advice.toDict() }
        if let coherence { data["coherence"] = coherence.toDict() }
        if let correlation { data["correlation"] = correlation.toDict() }
        if let nudgeScheduler { data["nudgeScheduler"] = nudgeScheduler.toDict() }
        if let inputSummary { data["inputSummary"] = inputSummary.toDict() }

        return data
    }

    /// Returns the hardware model identifier (e.g., "iPhone16,1").
    private func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }
}

// MARK: - Heart Trend Trace

/// Telemetry data from the HeartTrendEngine.
struct HeartTrendTrace {
    let status: String
    let confidence: String
    let anomalyScore: Double
    let regressionFlag: Bool
    let stressFlag: Bool
    let cardioScore: Double?
    let scenario: String?
    let nudgeCategory: String
    let nudgeCount: Int
    let hasWeekOverWeek: Bool
    let hasConsecutiveAlert: Bool
    let hasRecoveryTrend: Bool
    let durationMs: Double

    init(from assessment: HeartAssessment, durationMs: Double) {
        self.status = assessment.status.rawValue
        self.confidence = assessment.confidence.rawValue
        self.anomalyScore = assessment.anomalyScore
        self.regressionFlag = assessment.regressionFlag
        self.stressFlag = assessment.stressFlag
        self.cardioScore = assessment.cardioScore
        self.scenario = assessment.scenario?.rawValue
        self.nudgeCategory = assessment.dailyNudge.category.rawValue
        self.nudgeCount = assessment.dailyNudges.count
        self.hasWeekOverWeek = assessment.weekOverWeekTrend != nil
        self.hasConsecutiveAlert = assessment.consecutiveAlert != nil
        self.hasRecoveryTrend = assessment.recoveryTrend != nil
        self.durationMs = durationMs
    }

    func toDict() -> [String: Any] {
        var d: [String: Any] = [
            "status": status,
            "confidence": confidence,
            "anomalyScore": anomalyScore,
            "regressionFlag": regressionFlag,
            "stressFlag": stressFlag,
            "nudgeCategory": nudgeCategory,
            "nudgeCount": nudgeCount,
            "hasWeekOverWeek": hasWeekOverWeek,
            "hasConsecutiveAlert": hasConsecutiveAlert,
            "hasRecoveryTrend": hasRecoveryTrend,
            "durationMs": durationMs
        ]
        if let cardioScore { d["cardioScore"] = cardioScore }
        if let scenario { d["scenario"] = scenario }
        return d
    }
}

// MARK: - Stress Trace

/// Telemetry data from the StressEngine.
struct StressTrace {
    let score: Double
    let level: String
    let mode: String
    let confidence: String
    let durationMs: Double

    init(from result: StressResult, durationMs: Double) {
        self.score = result.score
        self.level = result.level.rawValue
        self.mode = result.mode.rawValue
        self.confidence = result.confidence.rawValue
        self.durationMs = durationMs
    }

    func toDict() -> [String: Any] {
        [
            "score": score,
            "level": level,
            "mode": mode,
            "confidence": confidence,
            "durationMs": durationMs
        ]
    }
}

// MARK: - Readiness Trace

/// Telemetry data from the ReadinessEngine.
struct ReadinessTrace {
    let score: Int
    let level: String
    let pillarScores: [String: Double]
    let durationMs: Double

    init(from result: ReadinessResult, durationMs: Double) {
        self.score = result.score
        self.level = result.level.rawValue
        var pillars: [String: Double] = [:]
        for pillar in result.pillars {
            pillars[pillar.type.rawValue] = Double(pillar.score)
        }
        self.pillarScores = pillars
        self.durationMs = durationMs
    }

    func toDict() -> [String: Any] {
        [
            "score": score,
            "level": level,
            "pillarScores": pillarScores,
            "durationMs": durationMs
        ]
    }
}

// MARK: - Bio Age Trace

/// Telemetry data from the BioAgeEngine.
struct BioAgeTrace {
    let bioAge: Int
    let chronologicalAge: Int
    let difference: Int
    let category: String
    let metricsUsed: Int
    let durationMs: Double

    init(from result: BioAgeResult, durationMs: Double) {
        self.bioAge = result.bioAge
        self.chronologicalAge = result.chronologicalAge
        self.difference = result.difference
        self.category = result.category.rawValue
        self.metricsUsed = result.metricsUsed
        self.durationMs = durationMs
    }

    func toDict() -> [String: Any] {
        [
            "bioAge": bioAge,
            "chronologicalAge": chronologicalAge,
            "difference": difference,
            "category": category,
            "metricsUsed": metricsUsed,
            "durationMs": durationMs
        ]
    }
}

// MARK: - Coaching Trace

/// Telemetry data from the CoachingEngine.
struct CoachingTrace {
    let weeklyProgressScore: Int
    let insightCount: Int
    let projectionCount: Int
    let streakDays: Int
    let durationMs: Double

    init(from report: CoachingReport, durationMs: Double) {
        self.weeklyProgressScore = report.weeklyProgressScore
        self.insightCount = report.insights.count
        self.projectionCount = report.projections.count
        self.streakDays = report.streakDays
        self.durationMs = durationMs
    }

    func toDict() -> [String: Any] {
        [
            "weeklyProgressScore": weeklyProgressScore,
            "insightCount": insightCount,
            "projectionCount": projectionCount,
            "streakDays": streakDays,
            "durationMs": durationMs
        ]
    }
}

// MARK: - Zone Analysis Trace

/// Telemetry data from the HeartRateZoneEngine.
struct ZoneAnalysisTrace {
    let overallScore: Int
    let pillarCount: Int
    let hasRecommendation: Bool
    let durationMs: Double

    init(from analysis: ZoneAnalysis, durationMs: Double) {
        self.overallScore = analysis.overallScore
        self.pillarCount = analysis.pillars.count
        self.hasRecommendation = analysis.recommendation != nil
        self.durationMs = durationMs
    }

    func toDict() -> [String: Any] {
        [
            "overallScore": overallScore,
            "pillarCount": pillarCount,
            "hasRecommendation": hasRecommendation,
            "durationMs": durationMs
        ]
    }
}

// MARK: - Buddy Trace

/// Telemetry data from the BuddyRecommendationEngine.
struct BuddyTrace {
    let count: Int
    let topPriority: String?
    let topCategory: String?
    let durationMs: Double

    init(from recommendations: [BuddyRecommendation], durationMs: Double) {
        self.count = recommendations.count
        if let first = recommendations.first {
            self.topPriority = String(describing: first.priority)
            self.topCategory = first.category.rawValue
        } else {
            self.topPriority = nil
            self.topCategory = nil
        }
        self.durationMs = durationMs
    }

    func toDict() -> [String: Any] {
        var d: [String: Any] = [
            "count": count,
            "durationMs": durationMs
        ]
        if let topPriority { d["topPriority"] = topPriority }
        if let topCategory { d["topCategory"] = topCategory }
        return d
    }
}

// MARK: - Input Summary Trace

/// Statistical summary of health inputs for remote debugging.
///
/// Contains aggregated means, categories, and completeness indicators —
/// never raw HealthKit values. Apple HealthKit Section 5.1.3 compliant.
struct InputSummaryTrace {
    /// 7-day mean RHR category (e.g., "low", "normal", "elevated", "high").
    let rhrCategory: String
    /// 7-day mean HRV category.
    let hrvCategory: String
    /// Sleep category based on hours (e.g., "short", "adequate", "long").
    let sleepCategory: String
    /// Activity category based on steps (e.g., "sedentary", "light", "active", "veryActive").
    let stepsCategory: String
    /// Fraction of data fields that were non-nil in today's snapshot (0.0-1.0).
    let dataCompleteness: Double
    /// Number of history days available for engine calculations.
    let historyDays: Int
    /// Whether VO2 max data is available.
    let hasVO2Max: Bool
    /// Whether recovery HR data is available.
    let hasRecoveryHR: Bool
    /// Whether body mass data is available.
    let hasBodyMass: Bool

    /// Creates an input summary from the current snapshot and recent history.
    init(snapshot: HeartSnapshot, history: [HeartSnapshot]) {
        // RHR category from 7-day mean
        let recentRHRs = history.suffix(7).compactMap { $0.restingHeartRate }
        if recentRHRs.isEmpty {
            rhrCategory = "unavailable"
        } else {
            let mean = recentRHRs.reduce(0, +) / Double(recentRHRs.count)
            if mean < 55 { rhrCategory = "low" }
            else if mean < 70 { rhrCategory = "normal" }
            else if mean < 85 { rhrCategory = "elevated" }
            else { rhrCategory = "high" }
        }

        // HRV category from 7-day mean
        let recentHRVs = history.suffix(7).compactMap { $0.hrvSDNN }
        if recentHRVs.isEmpty {
            hrvCategory = "unavailable"
        } else {
            let mean = recentHRVs.reduce(0, +) / Double(recentHRVs.count)
            if mean < 20 { hrvCategory = "low" }
            else if mean < 40 { hrvCategory = "moderate" }
            else if mean < 70 { hrvCategory = "good" }
            else { hrvCategory = "excellent" }
        }

        // Sleep category
        if let sleep = snapshot.sleepHours {
            if sleep < 5 { sleepCategory = "short" }
            else if sleep < 7 { sleepCategory = "adequate" }
            else if sleep < 9 { sleepCategory = "good" }
            else { sleepCategory = "long" }
        } else {
            sleepCategory = "unavailable"
        }

        // Steps category
        if let steps = snapshot.steps {
            if steps < 3000 { stepsCategory = "sedentary" }
            else if steps < 7000 { stepsCategory = "light" }
            else if steps < 12000 { stepsCategory = "active" }
            else { stepsCategory = "veryActive" }
        } else {
            stepsCategory = "unavailable"
        }

        // Data completeness: count non-nil fields out of total
        let fields: [Any?] = [
            snapshot.restingHeartRate, snapshot.hrvSDNN,
            snapshot.recoveryHR1m, snapshot.recoveryHR2m,
            snapshot.vo2Max, snapshot.steps,
            snapshot.walkMinutes, snapshot.workoutMinutes,
            snapshot.sleepHours, snapshot.bodyMassKg
        ]
        let nonNilCount = fields.compactMap { $0 }.count
        dataCompleteness = Double(nonNilCount) / Double(fields.count)

        historyDays = history.count
        hasVO2Max = snapshot.vo2Max != nil
        hasRecoveryHR = snapshot.recoveryHR1m != nil
        hasBodyMass = snapshot.bodyMassKg != nil
    }

    func toDict() -> [String: Any] {
        [
            "rhrCategory": rhrCategory,
            "hrvCategory": hrvCategory,
            "sleepCategory": sleepCategory,
            "stepsCategory": stepsCategory,
            "dataCompleteness": dataCompleteness,
            "historyDays": historyDays,
            "hasVO2Max": hasVO2Max,
            "hasRecoveryHR": hasRecoveryHR,
            "hasBodyMass": hasBodyMass
        ]
    }
}

// MARK: - Advice Trace

/// Telemetry data from the AdviceComposer.
/// Contains only categorical data (mode strings, band names, integer targets).
struct AdviceTrace {
    let mode: String
    let riskBand: String
    let overtrainingState: String
    let heroCategory: String
    let allowedIntensity: String
    let goalStepTarget: Int
    let positivityAnchorInjected: Bool
    let durationMs: Double

    init(from state: AdviceState, durationMs: Double) {
        self.mode = state.mode.rawValue
        self.riskBand = state.riskBand.rawValue
        self.overtrainingState = state.overtrainingState.rawValue
        self.heroCategory = state.heroCategory.rawValue
        self.allowedIntensity = state.allowedIntensity.rawValue
        self.goalStepTarget = Int(state.goals.first { $0.category == .steps }?.target ?? 0)
        self.positivityAnchorInjected = state.positivityAnchorID != nil
        self.durationMs = durationMs
    }

    func toDict() -> [String: Any] {
        [
            "mode": mode,
            "riskBand": riskBand,
            "overtrainingState": overtrainingState,
            "heroCategory": heroCategory,
            "allowedIntensity": allowedIntensity,
            "goalStepTarget": goalStepTarget,
            "positivityAnchorInjected": positivityAnchorInjected,
            "durationMs": durationMs
        ]
    }
}

// MARK: - Coherence Trace

/// Records coherence invariant checks from the pipeline run.
/// Hard violations indicate bugs. Soft anomalies are logged for analysis.
struct CoherenceTrace {
    let hardInvariantsChecked: Int
    let hardViolationsFound: Int
    let hardViolations: [String]
    let softAnomaliesFound: Int
    let softAnomalies: [String]

    func toDict() -> [String: Any] {
        [
            "hardInvariantsChecked": hardInvariantsChecked,
            "hardViolationsFound": hardViolationsFound,
            "hardViolations": hardViolations,
            "softAnomaliesFound": softAnomaliesFound,
            "softAnomalies": softAnomalies
        ]
    }
}

// MARK: - Correlation Trace

/// Telemetry data from the CorrelationEngine.
struct CorrelationTrace {
    let pairsAnalyzed: Int
    let significantPairs: Int
    let topFactorName: String?
    let durationMs: Double

    init(from correlations: [CorrelationResult], durationMs: Double) {
        self.pairsAnalyzed = correlations.count
        self.significantPairs = correlations.filter { abs($0.correlationStrength) >= 0.5 }.count
        self.topFactorName = correlations.max(by: { abs($0.correlationStrength) < abs($1.correlationStrength) })?.factorName
        self.durationMs = durationMs
    }

    func toDict() -> [String: Any] {
        var d: [String: Any] = [
            "pairsAnalyzed": pairsAnalyzed,
            "significantPairs": significantPairs,
            "durationMs": durationMs
        ]
        if let topFactorName { d["topFactorName"] = topFactorName }
        return d
    }
}

// MARK: - Nudge Scheduler Trace

/// Telemetry data from the SmartNudgeScheduler.
struct NudgeSchedulerTrace {
    let patternsLearned: Int
    let bedtimeNudgeHour: Int?
    let durationMs: Double

    init(from patterns: [SleepPattern], durationMs: Double) {
        self.patternsLearned = patterns.count
        self.bedtimeNudgeHour = patterns.first?.typicalBedtimeHour
        self.durationMs = durationMs
    }

    func toDict() -> [String: Any] {
        var d: [String: Any] = [
            "patternsLearned": patternsLearned,
            "durationMs": durationMs
        ]
        if let bedtimeNudgeHour { d["bedtimeNudgeHour"] = bedtimeNudgeHour }
        return d
    }
}

// MARK: - Coherence Checker

/// Validates hard invariants and detects soft anomalies in AdviceState.
///
/// Hard invariants are rules that should never be violated — violations
/// indicate bugs. Soft anomalies are unusual but plausible states that
/// are logged for analysis.
struct CoherenceChecker {

    /// Runs all coherence checks and returns a trace.
    static func check(
        adviceState: AdviceState,
        readinessResult: ReadinessResult?,
        config: HealthPolicyConfig
    ) -> CoherenceTrace {
        var hardViolations: [String] = []
        var softAnomalies: [String] = []

        // ── Hard Invariants ──

        // INV-001: No pushDay when sleep-deprived
        if adviceState.sleepDeprivationFlag && adviceState.mode == .pushDay {
            hardViolations.append("INV-001: pushDay with sleepDeprivation")
        }

        // INV-002: No celebrating buddy when recovering
        if (adviceState.mode == .lightRecovery || adviceState.mode == .fullRest)
            && adviceState.buddyMoodCategory == .celebrating {
            hardViolations.append("INV-002: celebrating buddy in recovery mode")
        }

        // INV-003: Medical escalation shown when medicalEscalationFlag is set
        if adviceState.medicalEscalationFlag && adviceState.mode != .medicalCheck {
            hardViolations.append("INV-003: medicalEscalation without medicalCheck mode")
        }

        // INV-004: Goals match mode — fullRest/medicalCheck step target <= recovering target
        if adviceState.mode == .fullRest || adviceState.mode == .medicalCheck {
            if let stepGoal = adviceState.goals.first(where: { $0.category == .steps }) {
                if stepGoal.target > Double(config.goals.stepsRecovering) {
                    hardViolations.append("INV-004: step target \(Int(stepGoal.target)) exceeds recovering limit \(config.goals.stepsRecovering)")
                }
            }
        }

        // INV-005: No high intensity when overtraining >= caution
        if adviceState.overtrainingState >= .caution && adviceState.allowedIntensity > .light {
            hardViolations.append("INV-005: intensity \(adviceState.allowedIntensity.rawValue) with overtraining \(adviceState.overtrainingState.rawValue)")
        }

        // ── Soft Anomalies ──

        // ANO-001: High stress + high readiness
        if adviceState.stressGuidanceLevel == .elevated,
           let score = readinessResult?.score, score >= 80 {
            softAnomalies.append("ANO-001: elevated stress with primed readiness (\(score))")
        }

        // ANO-002: Positivity imbalance (3+ negative signals, no anchor)
        let negativeCount = [
            adviceState.sleepDeprivationFlag,
            adviceState.stressGuidanceLevel == .elevated,
            (readinessResult?.score ?? 100) < 45,
            adviceState.overtrainingState >= .watch,
            adviceState.medicalEscalationFlag
        ].filter { $0 }.count
        if negativeCount >= 3 && adviceState.positivityAnchorID == nil {
            softAnomalies.append("ANO-002: \(negativeCount) negative signals without positivity anchor")
        }

        // ANO-003: Age gating gap (future — logged when advanced guidance is off)
        // Deferred until age is available in AdviceComposer context

        // Log hard violations as errors
        for violation in hardViolations {
            AppLogger.engine.error("[Coherence] HARD VIOLATION: \(violation)")
        }
        for anomaly in softAnomalies {
            AppLogger.engine.warning("[Coherence] Soft anomaly: \(anomaly)")
        }

        return CoherenceTrace(
            hardInvariantsChecked: 5,
            hardViolationsFound: hardViolations.count,
            hardViolations: hardViolations,
            softAnomaliesFound: softAnomalies.count,
            softAnomalies: softAnomalies
        )
    }
}

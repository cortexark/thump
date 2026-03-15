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

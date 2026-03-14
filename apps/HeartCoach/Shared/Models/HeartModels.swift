// HeartModels.swift
// ThumpCore
//
// Complete domain models for the Thump shared engine.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Trend Status

/// The overall daily heart-health trend assessment.
public enum TrendStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case improving
    case stable
    case needsAttention
}

// MARK: - Confidence Level

/// Confidence in the assessment based on data completeness and history depth.
public enum ConfidenceLevel: String, Codable, Equatable, Sendable, CaseIterable {
    case high
    case medium
    case low

    /// User-facing display name.
    public var displayName: String {
        switch self {
        case .high: return "Strong Pattern"
        case .medium: return "Emerging Pattern"
        case .low: return "Early Signal"
        }
    }

    /// Named color for SwiftUI asset catalogs or programmatic mapping.
    public var colorName: String {
        switch self {
        case .high: return "confidenceHigh"
        case .medium: return "confidenceMedium"
        case .low: return "confidenceLow"
        }
    }

    /// SF Symbol icon name.
    public var icon: String {
        switch self {
        case .high: return "checkmark.seal.fill"
        case .medium: return "exclamationmark.triangle"
        case .low: return "questionmark.circle"
        }
    }
}

// MARK: - Daily Feedback

/// Watch-captured user feedback for the day's nudge.
public enum DailyFeedback: String, Codable, Equatable, Sendable, CaseIterable {
    case positive
    case negative
    case skipped
}

// MARK: - Nudge Category

/// Categories of coaching nudges mapped to lifestyle actions.
public enum NudgeCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case walk
    case rest
    case hydrate
    case breathe
    case moderate
    case celebrate
    case seekGuidance
    case sunlight

    /// SF Symbol icon for this nudge category.
    public var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .rest: return "bed.double.fill"
        case .hydrate: return "drop.fill"
        case .breathe: return "wind"
        case .moderate: return "gauge.with.dots.needle.33percent"
        case .celebrate: return "star.fill"
        case .seekGuidance: return "heart.text.square"
        case .sunlight: return "sun.max.fill"
        }
    }

    /// Named tint color for the nudge card.
    public var tintColorName: String {
        switch self {
        case .walk: return "nudgeWalk"
        case .rest: return "nudgeRest"
        case .hydrate: return "nudgeHydrate"
        case .breathe: return "nudgeBreathe"
        case .moderate: return "nudgeModerate"
        case .celebrate: return "nudgeCelebrate"
        case .seekGuidance: return "nudgeGuidance"
        case .sunlight: return "nudgeSunlight"
        }
    }
}

// MARK: - Heart Snapshot

/// A single day's health metrics snapshot from HealthKit or manual entry.
public struct HeartSnapshot: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier derived from the snapshot date.
    public var id: Date { date }

    /// Calendar date for this snapshot (midnight-aligned).
    public let date: Date

    /// Resting heart rate in BPM.
    public let restingHeartRate: Double?

    /// Heart rate variability (SDNN) in milliseconds.
    public let hrvSDNN: Double?

    /// Heart rate recovery at 1 minute post-exercise in BPM drop.
    public let recoveryHR1m: Double?

    /// Heart rate recovery at 2 minutes post-exercise in BPM drop.
    public let recoveryHR2m: Double?

    /// Estimated VO2 max in mL/kg/min.
    public let vo2Max: Double?

    /// Minutes spent in each heart rate zone (indexed 0-4 or custom).
    public let zoneMinutes: [Double]

    /// Total step count for the day.
    public let steps: Double?

    /// Walking minutes for the day.
    public let walkMinutes: Double?

    /// Workout minutes for the day.
    public let workoutMinutes: Double?

    /// Sleep duration in hours.
    public let sleepHours: Double?

    /// Body mass in kilograms. Sourced from HealthKit (manual entry or
    /// smart-scale sync). Used by BioAgeEngine for BMI-adjusted scoring.
    public let bodyMassKg: Double?

    public init(
        date: Date,
        restingHeartRate: Double? = nil,
        hrvSDNN: Double? = nil,
        recoveryHR1m: Double? = nil,
        recoveryHR2m: Double? = nil,
        vo2Max: Double? = nil,
        zoneMinutes: [Double] = [],
        steps: Double? = nil,
        walkMinutes: Double? = nil,
        workoutMinutes: Double? = nil,
        sleepHours: Double? = nil,
        bodyMassKg: Double? = nil
    ) {
        self.date = date
        self.restingHeartRate = Self.clamp(restingHeartRate, to: 30...220)
        self.hrvSDNN = Self.clamp(hrvSDNN, to: 5...300)
        self.recoveryHR1m = Self.clamp(recoveryHR1m, to: 0...100)
        self.recoveryHR2m = Self.clamp(recoveryHR2m, to: 0...120)
        self.vo2Max = Self.clamp(vo2Max, to: 10...90)
        self.zoneMinutes = zoneMinutes.map { min(max($0, 0), 1440) }
        self.steps = Self.clamp(steps, to: 0...200_000)
        self.walkMinutes = Self.clamp(walkMinutes, to: 0...1440)
        self.workoutMinutes = Self.clamp(workoutMinutes, to: 0...1440)
        self.sleepHours = Self.clamp(sleepHours, to: 0...24)
        self.bodyMassKg = Self.clamp(bodyMassKg, to: 20...350)
    }

    /// Total activity minutes (walk + workout combined).
    /// Returns nil only when both components are nil (ENG-3).
    public var activityMinutes: Double? {
        switch (walkMinutes, workoutMinutes) {
        case let (w?, wo?): return w + wo
        case let (w?, nil): return w
        case let (nil, wo?): return wo
        case (nil, nil): return nil
        }
    }

    /// Clamps an optional value to a valid range, returning nil if the
    /// original is nil or if it falls completely outside the range.
    private static func clamp(_ value: Double?, to range: ClosedRange<Double>) -> Double? {
        guard let v = value else { return nil }
        guard v >= range.lowerBound else { return nil }
        return min(v, range.upperBound)
    }
}

// MARK: - Daily Nudge

/// A concrete coaching nudge with actionable content.
public struct DailyNudge: Codable, Equatable, Sendable {
    /// The category of this nudge.
    public let category: NudgeCategory

    /// Short nudge title (e.g. "Take a Gentle Walk").
    public let title: String

    /// Detailed description with actionable guidance.
    public let description: String

    /// Suggested duration in minutes, if applicable.
    public let durationMinutes: Int?

    /// SF Symbol icon name for display.
    public let icon: String

    public init(
        category: NudgeCategory,
        title: String,
        description: String,
        durationMinutes: Int? = nil,
        icon: String
    ) {
        self.category = category
        self.title = title
        self.description = description
        self.durationMinutes = durationMinutes
        self.icon = icon
    }
}

// MARK: - Heart Assessment

/// The complete daily assessment output from the trend engine.
public struct HeartAssessment: Codable, Equatable, Sendable {
    /// Overall trend status.
    public let status: TrendStatus

    /// Data confidence level.
    public let confidence: ConfidenceLevel

    /// Composite anomaly score (0 = normal, higher = more anomalous).
    public let anomalyScore: Double

    /// Whether a multi-day regression trend was detected.
    public let regressionFlag: Bool

    /// Whether a stress-like physiological pattern was detected.
    public let stressFlag: Bool

    /// Composite cardio fitness score (0-100 scale), nil if insufficient data.
    public let cardioScore: Double?

    /// The primary daily coaching nudge (highest priority).
    public let dailyNudge: DailyNudge

    /// Multiple data-driven coaching nudges ranked by relevance.
    /// The first element is always the same as `dailyNudge`.
    public let dailyNudges: [DailyNudge]

    /// Human-readable explanation of the assessment.
    public let explanation: String

    /// Week-over-week RHR trend analysis, nil if insufficient data.
    public let weekOverWeekTrend: WeekOverWeekTrend?

    /// Consecutive RHR elevation alert, nil if no alert.
    public let consecutiveAlert: ConsecutiveElevationAlert?

    /// Detected coaching scenario, nil if none triggered.
    public let scenario: CoachingScenario?

    /// Recovery rate (post-exercise HR drop) trend, nil if insufficient data.
    public let recoveryTrend: RecoveryTrend?

    /// Readiness-driven recovery context, present when readiness is recovering or moderate.
    /// Explains *why* today's goal is lighter and what to do tonight to fix tomorrow's metrics.
    public let recoveryContext: RecoveryContext?

    /// Convenience accessor for a one-line nudge summary.
    public var dailyNudgeText: String {
        if let duration = dailyNudge.durationMinutes {
            return "\(dailyNudge.title) (\(duration) min): \(dailyNudge.description)"
        }
        return "\(dailyNudge.title): \(dailyNudge.description)"
    }

    public init(
        status: TrendStatus,
        confidence: ConfidenceLevel,
        anomalyScore: Double,
        regressionFlag: Bool,
        stressFlag: Bool,
        cardioScore: Double?,
        dailyNudge: DailyNudge,
        dailyNudges: [DailyNudge]? = nil,
        explanation: String,
        weekOverWeekTrend: WeekOverWeekTrend? = nil,
        consecutiveAlert: ConsecutiveElevationAlert? = nil,
        scenario: CoachingScenario? = nil,
        recoveryTrend: RecoveryTrend? = nil,
        recoveryContext: RecoveryContext? = nil
    ) {
        self.status = status
        self.confidence = confidence
        self.anomalyScore = anomalyScore
        self.regressionFlag = regressionFlag
        self.stressFlag = stressFlag
        self.cardioScore = cardioScore
        self.dailyNudge = dailyNudge
        self.dailyNudges = dailyNudges ?? [dailyNudge]
        self.explanation = explanation
        self.weekOverWeekTrend = weekOverWeekTrend
        self.consecutiveAlert = consecutiveAlert
        self.scenario = scenario
        self.recoveryTrend = recoveryTrend
        self.recoveryContext = recoveryContext
    }
}

// MARK: - Recovery Context

/// Readiness-driven recovery guidance surfaced when HRV/sleep signals show the
/// body needs to back off. Explains the cause and gives a concrete tonight action.
///
/// This flows through: ReadinessEngine → HeartTrendEngine → HeartAssessment
/// → DashboardView (readiness banner) + StressView (bedtime action) + sleep goal text.
public struct RecoveryContext: Codable, Equatable, Sendable {

    /// The metric that drove the low readiness (e.g. "HRV", "Sleep").
    public let driver: String

    /// Short reason shown inline next to the goal — "Your HRV is below baseline"
    public let reason: String

    /// Tonight's concrete action — shown on the sleep goal tile and the bedtime smart action.
    public let tonightAction: String

    /// The specific bedtime target, if applicable — e.g. "10 PM"
    public let bedtimeTarget: String?

    /// Readiness score that triggered this context (0-100).
    public let readinessScore: Int

    public init(
        driver: String,
        reason: String,
        tonightAction: String,
        bedtimeTarget: String? = nil,
        readinessScore: Int
    ) {
        self.driver = driver
        self.reason = reason
        self.tonightAction = tonightAction
        self.bedtimeTarget = bedtimeTarget
        self.readinessScore = readinessScore
    }
}

// MARK: - Correlation Result

/// Result of correlating an activity factor with a heart metric trend.
public struct CorrelationResult: Codable, Equatable, Sendable, Identifiable {
    /// Stable identifier derived from factor name.
    public var id: String { factorName }

    /// Name of the factor being correlated (e.g. "Daily Steps").
    public let factorName: String

    /// Pearson correlation coefficient (-1.0 to 1.0).
    public let correlationStrength: Double

    /// Human-readable interpretation of the correlation.
    public let interpretation: String

    /// Confidence in the correlation result.
    public let confidence: ConfidenceLevel

    /// Whether the correlation is moving in a beneficial direction for cardiovascular health.
    ///
    /// For example, a negative r between steps and RHR is beneficial (more steps → lower RHR),
    /// whereas a negative r between sleep and HRV would not be.
    public let isBeneficial: Bool

    public init(
        factorName: String,
        correlationStrength: Double,
        interpretation: String,
        confidence: ConfidenceLevel,
        isBeneficial: Bool = true
    ) {
        self.factorName = factorName
        self.correlationStrength = correlationStrength
        self.interpretation = interpretation
        self.confidence = confidence
        self.isBeneficial = isBeneficial
    }
}

// MARK: - Weekly Report

/// Aggregated weekly performance report.
public struct WeeklyReport: Codable, Equatable, Sendable {

    /// Weekly trend direction.
    public enum TrendDirection: String, Codable, Equatable, Sendable {
        case up
        case flat
        case down
    }

    /// Start date of the reporting week.
    public let weekStart: Date

    /// End date of the reporting week.
    public let weekEnd: Date

    /// Average cardio score across the week (0-100).
    public let avgCardioScore: Double?

    /// Direction the trend moved over the week.
    public let trendDirection: TrendDirection

    /// The most significant insight from the week.
    public let topInsight: String

    /// Percentage of nudges completed (0.0-1.0).
    public let nudgeCompletionRate: Double

    public init(
        weekStart: Date,
        weekEnd: Date,
        avgCardioScore: Double?,
        trendDirection: TrendDirection,
        topInsight: String,
        nudgeCompletionRate: Double
    ) {
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.avgCardioScore = avgCardioScore
        self.trendDirection = trendDirection
        self.topInsight = topInsight
        self.nudgeCompletionRate = nudgeCompletionRate
    }
}

// MARK: - Week-Over-Week Trend

/// Result of comparing the current week's RHR to the 28-day baseline.
public struct WeekOverWeekTrend: Codable, Equatable, Sendable {
    /// Z-score of this week's mean RHR vs 28-day baseline.
    public let zScore: Double

    /// Direction of the weekly trend.
    public let direction: WeeklyTrendDirection

    /// 28-day baseline mean RHR.
    public let baselineMean: Double

    /// 28-day baseline standard deviation.
    public let baselineStd: Double

    /// Current 7-day mean RHR.
    public let currentWeekMean: Double

    public init(
        zScore: Double,
        direction: WeeklyTrendDirection,
        baselineMean: Double,
        baselineStd: Double,
        currentWeekMean: Double
    ) {
        self.zScore = zScore
        self.direction = direction
        self.baselineMean = baselineMean
        self.baselineStd = baselineStd
        self.currentWeekMean = currentWeekMean
    }
}

/// Direction of weekly RHR trend relative to personal baseline.
public enum WeeklyTrendDirection: String, Codable, Equatable, Sendable {
    case significantImprovement
    case improving
    case stable
    case elevated
    case significantElevation

    /// Friendly display text.
    public var displayText: String {
        switch self {
        case .significantImprovement: return "Your resting heart rate dropped notably this week"
        case .improving: return "Your resting heart rate is trending down"
        case .stable: return "Your resting heart rate is holding steady"
        case .elevated: return "Your resting heart rate crept up this week"
        case .significantElevation: return "Your resting heart rate is notably elevated"
        }
    }

    /// SF Symbol icon.
    public var icon: String {
        switch self {
        case .significantImprovement: return "arrow.down.circle.fill"
        case .improving: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .elevated: return "arrow.up.right"
        case .significantElevation: return "arrow.up.circle.fill"
        }
    }
}

// MARK: - Consecutive Elevation Alert

/// Alert for consecutive days of elevated resting heart rate.
/// Research (ARIC study) shows this pattern precedes illness by 1-3 days.
public struct ConsecutiveElevationAlert: Codable, Equatable, Sendable {
    /// Number of consecutive days RHR exceeded the threshold.
    public let consecutiveDays: Int

    /// The threshold used (personal mean + 2σ).
    public let threshold: Double

    /// Average RHR during the elevated period.
    public let elevatedMean: Double

    /// Personal baseline mean RHR.
    public let personalMean: Double

    public init(
        consecutiveDays: Int,
        threshold: Double,
        elevatedMean: Double,
        personalMean: Double
    ) {
        self.consecutiveDays = consecutiveDays
        self.threshold = threshold
        self.elevatedMean = elevatedMean
        self.personalMean = personalMean
    }
}

// MARK: - Recovery Trend

/// Trend analysis for heart rate recovery (post-exercise HR drop).
public struct RecoveryTrend: Codable, Equatable, Sendable {
    /// Direction of recovery rate trend.
    public let direction: RecoveryTrendDirection

    /// 7-day mean recovery HR (1-minute drop).
    public let currentWeekMean: Double?

    /// 28-day baseline mean recovery HR.
    public let baselineMean: Double?

    /// Z-score of current week vs baseline.
    public let zScore: Double?

    /// Number of data points in the current week.
    public let dataPoints: Int

    public init(
        direction: RecoveryTrendDirection,
        currentWeekMean: Double?,
        baselineMean: Double?,
        zScore: Double?,
        dataPoints: Int
    ) {
        self.direction = direction
        self.currentWeekMean = currentWeekMean
        self.baselineMean = baselineMean
        self.zScore = zScore
        self.dataPoints = dataPoints
    }
}

/// Direction of recovery rate trend.
public enum RecoveryTrendDirection: String, Codable, Equatable, Sendable {
    case improving
    case stable
    case declining
    case insufficientData

    /// Friendly display text.
    public var displayText: String {
        switch self {
        case .improving: return "Your recovery rate is improving — great fitness signal"
        case .stable: return "Your recovery rate is holding steady"
        case .declining: return "Your recovery rate dipped — consider extra rest"
        case .insufficientData: return "Need more post-workout data for recovery trends"
        }
    }
}

// MARK: - Coaching Scenario

/// Detected coaching scenario that triggers a targeted message.
public enum CoachingScenario: String, Codable, Equatable, Sendable, CaseIterable {
    case highStressDay
    case greatRecoveryDay
    case missingActivity
    case overtrainingSignals
    case improvingTrend
    case decliningTrend

    /// User-facing coaching message for this scenario.
    public var coachingMessage: String {
        switch self {
        case .highStressDay:
            return "Your heart metrics suggest a demanding day. A short walk or breathing exercise may help you reset."
        case .greatRecoveryDay:
            return "Your body bounced back nicely — a good sign your recovery habits are working."
        case .missingActivity:
            return "You've been less active the past couple of days. Even a 10-minute walk can make a difference."
        case .overtrainingSignals:
            return "Your resting heart rate has been elevated while your HRV has dipped. A lighter day might help you feel better."
        case .improvingTrend:
            return "Your metrics have been trending in a positive direction for the past two weeks. Keep doing what you're doing!"
        case .decliningTrend:
            return "Your metrics have been shifting over the past two weeks. Consider whether sleep, stress, or activity changes might be a factor."
        }
    }

    /// SF Symbol icon for the scenario.
    public var icon: String {
        switch self {
        case .highStressDay: return "flame.fill"
        case .greatRecoveryDay: return "leaf.fill"
        case .missingActivity: return "figure.walk"
        case .overtrainingSignals: return "exclamationmark.triangle.fill"
        case .improvingTrend: return "chart.line.uptrend.xyaxis"
        case .decliningTrend: return "chart.line.downtrend.xyaxis"
        }
    }
}

// MARK: - Stress Level

/// Friendly stress level categories derived from HRV-based stress scoring.
///
/// Each level maps to a 0-100 score range and carries a friendly,
/// non-clinical display name suitable for the Thump voice.
public enum StressLevel: String, Codable, Equatable, Sendable, CaseIterable {
    case relaxed
    case balanced
    case elevated

    /// User-facing display name using friendly, non-medical language.
    public var displayName: String {
        switch self {
        case .relaxed: return "Feeling Relaxed"
        case .balanced: return "Finding Balance"
        case .elevated: return "Running Hot"
        }
    }

    /// SF Symbol icon for this stress level.
    public var icon: String {
        switch self {
        case .relaxed: return "leaf.fill"
        case .balanced: return "circle.grid.cross.fill"
        case .elevated: return "flame.fill"
        }
    }

    /// Named color for SwiftUI tinting.
    public var colorName: String {
        switch self {
        case .relaxed: return "stressRelaxed"
        case .balanced: return "stressBalanced"
        case .elevated: return "stressElevated"
        }
    }

    /// Friendly description of the current state.
    public var friendlyMessage: String {
        switch self {
        case .relaxed:
            return "You seem pretty relaxed right now"
        case .balanced:
            return "Things look balanced"
        case .elevated:
            return "You might be running a bit hot"
        }
    }

    /// Creates a stress level from a 0-100 score.
    ///
    /// - Parameter score: Stress score in the 0-100 range.
    /// - Returns: The corresponding stress level category.
    public static func from(score: Double) -> StressLevel {
        let clamped = max(0, min(100, score))
        if clamped <= 33 {
            return .relaxed
        } else if clamped <= 66 {
            return .balanced
        } else {
            return .elevated
        }
    }
}

// MARK: - Stress Mode

/// The context-inferred mode that determines which scoring branch is used.
///
/// The engine selects a mode from activity and context signals before scoring.
/// Each mode uses different signal weights calibrated for its context.
public enum StressMode: String, Codable, Equatable, Sendable, CaseIterable {
    /// High recent movement or post-activity recovery context.
    /// Uses the full HR-primary formula (RHR 50%, HRV 30%, CV 20%).
    case acute

    /// Low movement, seated/sedentary context.
    /// Reduces RHR influence, relies more on HRV deviation and CV.
    case desk

    /// Insufficient context to determine mode confidently.
    /// Blends toward neutral and reduces confidence.
    case unknown

    /// User-facing display name.
    public var displayName: String {
        switch self {
        case .acute: return "Active"
        case .desk: return "Resting"
        case .unknown: return "General"
        }
    }
}

// MARK: - Stress Confidence

/// Confidence in the stress score based on signal quality and agreement.
public enum StressConfidence: String, Codable, Equatable, Sendable, CaseIterable {
    case high
    case moderate
    case low

    /// User-facing display name.
    public var displayName: String {
        switch self {
        case .high: return "Strong Signal"
        case .moderate: return "Moderate Signal"
        case .low: return "Weak Signal"
        }
    }

    /// Numeric value for calculations (1.0 = high, 0.5 = moderate, 0.25 = low).
    public var weight: Double {
        switch self {
        case .high: return 1.0
        case .moderate: return 0.5
        case .low: return 0.25
        }
    }
}

// MARK: - Stress Signal Breakdown

/// Per-signal contributions to the final stress score.
public struct StressSignalBreakdown: Codable, Equatable, Sendable {
    /// RHR deviation contribution (0-100 raw, before weighting).
    public let rhrContribution: Double

    /// HRV baseline deviation contribution (0-100 raw, before weighting).
    public let hrvContribution: Double

    /// Coefficient of variation contribution (0-100 raw, before weighting).
    public let cvContribution: Double

    public init(rhrContribution: Double, hrvContribution: Double, cvContribution: Double) {
        self.rhrContribution = rhrContribution
        self.hrvContribution = hrvContribution
        self.cvContribution = cvContribution
    }
}

// MARK: - Stress Context Input

/// Rich context input for context-aware stress scoring.
///
/// Carries both physiology signals and activity/lifestyle context so
/// the engine can select the appropriate scoring branch.
public struct StressContextInput: Sendable {
    public let currentHRV: Double
    public let baselineHRV: Double
    public let baselineHRVSD: Double?
    public let currentRHR: Double?
    public let baselineRHR: Double?
    public let recentHRVs: [Double]?
    public let recentSteps: Double?
    public let recentWorkoutMinutes: Double?
    public let sedentaryMinutes: Double?
    public let sleepHours: Double?

    public init(
        currentHRV: Double,
        baselineHRV: Double,
        baselineHRVSD: Double? = nil,
        currentRHR: Double? = nil,
        baselineRHR: Double? = nil,
        recentHRVs: [Double]? = nil,
        recentSteps: Double? = nil,
        recentWorkoutMinutes: Double? = nil,
        sedentaryMinutes: Double? = nil,
        sleepHours: Double? = nil
    ) {
        self.currentHRV = currentHRV
        self.baselineHRV = baselineHRV
        self.baselineHRVSD = baselineHRVSD
        self.currentRHR = currentRHR
        self.baselineRHR = baselineRHR
        self.recentHRVs = recentHRVs
        self.recentSteps = recentSteps
        self.recentWorkoutMinutes = recentWorkoutMinutes
        self.sedentaryMinutes = sedentaryMinutes
        self.sleepHours = sleepHours
    }
}

// MARK: - Stress Result

/// The output of a single stress computation, pairing a numeric score
/// with its categorical level and a friendly description.
public struct StressResult: Codable, Equatable, Sendable {
    /// Stress score on a 0-100 scale (lower is more relaxed).
    public let score: Double

    /// Categorical stress level derived from the score.
    public let level: StressLevel

    /// Friendly, non-clinical description of the result.
    public let description: String

    /// The scoring mode used for this computation.
    public let mode: StressMode

    /// Confidence in this score based on signal quality and agreement.
    public let confidence: StressConfidence

    /// Per-signal contribution breakdown for explainability.
    public let signalBreakdown: StressSignalBreakdown?

    /// Warnings about the score quality or context.
    public let warnings: [String]

    public init(
        score: Double,
        level: StressLevel,
        description: String,
        mode: StressMode = .unknown,
        confidence: StressConfidence = .moderate,
        signalBreakdown: StressSignalBreakdown? = nil,
        warnings: [String] = []
    ) {
        self.score = score
        self.level = level
        self.description = description
        self.mode = mode
        self.confidence = confidence
        self.signalBreakdown = signalBreakdown
        self.warnings = warnings
    }
}

// MARK: - Stress Data Point

/// A single data point in a stress trend time series.
public struct StressDataPoint: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier derived from the date.
    public var id: Date { date }

    /// The date this data point represents.
    public let date: Date

    /// Stress score on a 0-100 scale.
    public let score: Double

    /// Categorical stress level for this point.
    public let level: StressLevel

    public init(date: Date, score: Double, level: StressLevel) {
        self.date = date
        self.score = score
        self.level = level
    }
}

// MARK: - Hourly Stress Point

/// A single hourly stress reading for heatmap visualization.
public struct HourlyStressPoint: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier combining date and hour.
    public var id: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        return formatter.string(from: date)
    }

    /// The date and hour this point represents.
    public let date: Date

    /// Hour of day (0-23).
    public let hour: Int

    /// Stress score on a 0-100 scale.
    public let score: Double

    /// Categorical stress level for this point.
    public let level: StressLevel

    public init(date: Date, hour: Int, score: Double, level: StressLevel) {
        self.date = date
        self.hour = hour
        self.score = score
        self.level = level
    }
}

// MARK: - Stress Trend Direction

/// Direction of stress trend over a time period.
public enum StressTrendDirection: String, Codable, Equatable, Sendable {
    case rising
    case falling
    case steady

    /// Friendly display text for the trend direction.
    public var displayText: String {
        switch self {
        case .rising: return "Stress has been climbing lately"
        case .falling: return "Your stress seems to be easing"
        case .steady: return "Stress has been holding steady"
        }
    }

    /// SF Symbol icon for trend direction.
    public var icon: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .steady: return "arrow.right"
        }
    }
}

// MARK: - Sleep Pattern

/// Learned sleep pattern for a day of the week.
public struct SleepPattern: Codable, Equatable, Sendable {
    /// Day of week (1 = Sunday, 7 = Saturday).
    public let dayOfWeek: Int

    /// Typical bedtime hour (0-23).
    public var typicalBedtimeHour: Int

    /// Typical wake hour (0-23).
    public var typicalWakeHour: Int

    /// Number of observations used to compute this pattern.
    public var observationCount: Int

    /// Whether this is a weekend day (Saturday or Sunday).
    public var isWeekend: Bool {
        dayOfWeek == 1 || dayOfWeek == 7
    }

    public init(
        dayOfWeek: Int,
        typicalBedtimeHour: Int = 22,
        typicalWakeHour: Int = 7,
        observationCount: Int = 0
    ) {
        self.dayOfWeek = dayOfWeek
        self.typicalBedtimeHour = typicalBedtimeHour
        self.typicalWakeHour = typicalWakeHour
        self.observationCount = observationCount
    }
}

// MARK: - Journal Prompt

/// A prompt for the user to journal about their day.
public struct JournalPrompt: Codable, Equatable, Sendable {
    /// The prompt question.
    public let question: String

    /// Context about why this prompt was triggered.
    public let context: String

    /// SF Symbol icon.
    public let icon: String

    /// The date this prompt was generated.
    public let date: Date

    public init(
        question: String,
        context: String,
        icon: String = "book.fill",
        date: Date = Date()
    ) {
        self.question = question
        self.context = context
        self.icon = icon
        self.date = date
    }
}

// MARK: - Weekly Action Plan

/// A single actionable recommendation surfaced in the weekly report detail view.
public struct WeeklyActionItem: Identifiable, Sendable {
    public let id: UUID
    public let category: WeeklyActionCategory
    /// Short headline shown on the card, e.g. "Wind Down Earlier".
    public let title: String
    /// One-sentence context derived from the user's data.
    public let detail: String
    /// SF Symbol name.
    public let icon: String
    /// Accent color name from the asset catalog.
    public let colorName: String
    /// Whether the user can set a reminder for this action.
    public let supportsReminder: Bool
    /// Suggested reminder hour (0-23) for UNCalendarNotificationTrigger.
    public let suggestedReminderHour: Int?
    /// For sunlight items: the inferred time-of-day windows with per-window reminders.
    /// Nil for all other categories.
    public let sunlightWindows: [SunlightWindow]?

    public init(
        id: UUID = UUID(),
        category: WeeklyActionCategory,
        title: String,
        detail: String,
        icon: String,
        colorName: String,
        supportsReminder: Bool = false,
        suggestedReminderHour: Int? = nil,
        sunlightWindows: [SunlightWindow]? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
        self.icon = icon
        self.colorName = colorName
        self.supportsReminder = supportsReminder
        self.suggestedReminderHour = suggestedReminderHour
        self.sunlightWindows = sunlightWindows
    }
}

/// Categories of weekly action items.
public enum WeeklyActionCategory: String, Sendable, CaseIterable {
    case sleep
    case breathe
    case activity
    case sunlight
    case hydrate

    public var defaultColorName: String {
        switch self {
        case .sleep:    return "nudgeRest"
        case .breathe:  return "nudgeBreathe"
        case .activity: return "nudgeWalk"
        case .sunlight: return "nudgeCelebrate"
        case .hydrate:  return "nudgeHydrate"
        }
    }

    public var icon: String {
        switch self {
        case .sleep:    return "moon.stars.fill"
        case .breathe:  return "wind"
        case .activity: return "figure.walk"
        case .sunlight: return "sun.max.fill"
        case .hydrate:  return "drop.fill"
        }
    }
}

// MARK: - Sunlight Window

/// A time-of-day opportunity for sunlight exposure inferred from the
/// user's movement patterns — no GPS required.
///
/// Thump detects three natural windows from HealthKit step data:
/// - **Morning** — first step burst of the day before 9 am (pre-commute / leaving home)
/// - **Lunch** — step activity around midday when many people are sedentary indoors
/// - **Evening** — step burst between 5-7 pm (commute home / after-work walk)
public struct SunlightWindow: Identifiable, Sendable {
    public let id: UUID

    /// Which time-of-day window this represents.
    public let slot: SunlightSlot

    /// Suggested reminder hour based on the inferred window.
    public let reminderHour: Int

    /// Whether Thump has observed movement in this window from historical data.
    /// `false` means we have no evidence the user goes outside at this time.
    public let hasObservedMovement: Bool

    /// Short label for the window, e.g. "Before your commute".
    public var label: String { slot.label }

    /// One-sentence coaching tip for this window.
    public var tip: String { slot.tip(hasObservedMovement: hasObservedMovement) }

    public init(
        id: UUID = UUID(),
        slot: SunlightSlot,
        reminderHour: Int,
        hasObservedMovement: Bool
    ) {
        self.id = id
        self.slot = slot
        self.reminderHour = reminderHour
        self.hasObservedMovement = hasObservedMovement
    }
}

/// The three inferred sunlight opportunity slots in a typical day.
public enum SunlightSlot: String, Sendable, CaseIterable {
    case morning
    case lunch
    case evening

    public var label: String {
        switch self {
        case .morning: return "Morning — before you head out"
        case .lunch:   return "Lunch — step away from your desk"
        case .evening: return "Evening — on the way home"
        }
    }

    public var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .lunch:   return "sun.max.fill"
        case .evening: return "sunset.fill"
        }
    }

    /// The default reminder hour for each slot.
    public var defaultHour: Int {
        switch self {
        case .morning: return 7
        case .lunch:   return 12
        case .evening: return 17
        }
    }

    public func tip(hasObservedMovement: Bool) -> String {
        switch self {
        case .morning:
            return hasObservedMovement
                ? "You already move in the morning — step outside for just 5 minutes before leaving to get direct sunlight."
                : "Even 5 minutes of sunlight before 9 am sets your body clock for the day. Try stepping outside before your commute."
        case .lunch:
            return hasObservedMovement
                ? "You tend to move at lunch. Swap even one indoor break for a short walk outside to get midday light."
                : "Midday is the most potent time for light exposure. A 5-minute walk outside at lunch beats any supplement."
        case .evening:
            return hasObservedMovement
                ? "Evening movement detected. Catching the last of the daylight on your commute home counts — face west if you can."
                : "A short walk when you get home captures evening light, which signals your body to wind down 2-3 hours later."
        }
    }
}

/// The full set of personalised action items for the weekly report detail.
public struct WeeklyActionPlan: Sendable {
    public let items: [WeeklyActionItem]
    public let weekStart: Date
    public let weekEnd: Date

    public init(items: [WeeklyActionItem], weekStart: Date, weekEnd: Date) {
        self.items = items
        self.weekStart = weekStart
        self.weekEnd = weekEnd
    }
}

// MARK: - Check-In Response

/// User response to a morning check-in.
public struct CheckInResponse: Codable, Equatable, Sendable {
    /// The date of the check-in.
    public let date: Date

    /// How the user is feeling (1-5 scale).
    public let feelingScore: Int

    /// Optional text note.
    public let note: String?

    public init(date: Date, feelingScore: Int, note: String? = nil) {
        self.date = date
        self.feelingScore = feelingScore
        self.note = note
    }
}

// MARK: - Check-In Mood

/// Quick mood check-in options for the dashboard.
public enum CheckInMood: String, Codable, Equatable, Sendable, CaseIterable {
    case great
    case good
    case okay
    case rough

    /// Emoji for display.
    public var emoji: String {
        switch self {
        case .great: return "😊"
        case .good:  return "🙂"
        case .okay:  return "😐"
        case .rough: return "😔"
        }
    }

    /// Short label for the mood.
    public var label: String {
        switch self {
        case .great: return "Great"
        case .good:  return "Good"
        case .okay:  return "Okay"
        case .rough: return "Rough"
        }
    }

    /// Numeric score (1-4) for storage.
    public var score: Int {
        switch self {
        case .great: return 4
        case .good:  return 3
        case .okay:  return 2
        case .rough: return 1
        }
    }
}

// MARK: - Stored Snapshot

/// Persistence wrapper pairing a snapshot with its optional assessment.
public struct StoredSnapshot: Codable, Equatable, Sendable {
    public let snapshot: HeartSnapshot
    public let assessment: HeartAssessment?

    public init(snapshot: HeartSnapshot, assessment: HeartAssessment? = nil) {
        self.snapshot = snapshot
        self.assessment = assessment
    }
}

// MARK: - Alert Meta

/// Metadata tracking alert frequency to prevent alert fatigue.
public struct AlertMeta: Codable, Equatable, Sendable {
    /// Timestamp of the most recent alert fired.
    public var lastAlertAt: Date?

    /// Number of alerts fired today.
    public var alertsToday: Int

    /// Day stamp (yyyy-MM-dd) for resetting daily count.
    public var alertsDayStamp: String

    public init(
        lastAlertAt: Date? = nil,
        alertsToday: Int = 0,
        alertsDayStamp: String = ""
    ) {
        self.lastAlertAt = lastAlertAt
        self.alertsToday = alertsToday
        self.alertsDayStamp = alertsDayStamp
    }
}

// MARK: - Watch Feedback Payload

/// Payload for syncing watch feedback to the phone.
public struct WatchFeedbackPayload: Codable, Equatable, Sendable {
    /// Unique event identifier for deduplication.
    public let eventId: String

    /// Date of the feedback.
    public let date: Date

    /// User's feedback response.
    public let response: DailyFeedback

    /// Source device identifier.
    public let source: String

    public init(
        eventId: String = UUID().uuidString,
        date: Date,
        response: DailyFeedback,
        source: String
    ) {
        self.eventId = eventId
        self.date = date
        self.response = response
        self.source = source
    }
}

// MARK: - Feedback Preferences

/// User preferences for what dashboard content to show.
public struct FeedbackPreferences: Codable, Equatable, Sendable {
    /// Show daily buddy suggestions.
    public var showBuddySuggestions: Bool

    /// Show the daily mood check-in card.
    public var showDailyCheckIn: Bool

    /// Show stress insights on the dashboard.
    public var showStressInsights: Bool

    /// Show weekly trend summaries.
    public var showWeeklyTrends: Bool

    /// Show streak badge.
    public var showStreakBadge: Bool

    public init(
        showBuddySuggestions: Bool = true,
        showDailyCheckIn: Bool = true,
        showStressInsights: Bool = true,
        showWeeklyTrends: Bool = true,
        showStreakBadge: Bool = true
    ) {
        self.showBuddySuggestions = showBuddySuggestions
        self.showDailyCheckIn = showDailyCheckIn
        self.showStressInsights = showStressInsights
        self.showWeeklyTrends = showWeeklyTrends
        self.showStreakBadge = showStreakBadge
    }
}

// MARK: - Biological Sex

/// Biological sex for physiological norm stratification.
/// Used by BioAgeEngine, HRV norms, and VO2 Max expected values.
/// Not a gender identity field — purely for metric accuracy.
public enum BiologicalSex: String, Codable, Equatable, Sendable, CaseIterable {
    case male
    case female
    case notSet

    /// User-facing label.
    public var displayLabel: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .notSet: return "Prefer not to say"
        }
    }

    /// SF Symbol icon.
    public var icon: String {
        switch self {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        case .notSet: return "person.fill"
        }
    }
}

// MARK: - User Profile

/// Local user profile for personalization and streak tracking.
public struct UserProfile: Codable, Equatable, Sendable {
    /// User's display name.
    public var displayName: String

    /// Date the user joined / completed onboarding.
    public var joinDate: Date

    /// Whether onboarding has been completed.
    public var onboardingComplete: Bool

    /// Current consecutive-day engagement streak.
    public var streakDays: Int

    /// The last calendar date a streak credit was granted.
    /// Used to prevent same-day nudge taps from inflating the streak.
    public var lastStreakCreditDate: Date?

    /// Dates on which the user explicitly completed a nudge action.
    /// Keyed by ISO date string (yyyy-MM-dd) for Codable simplicity.
    public var nudgeCompletionDates: Set<String>

    /// User's date of birth for bio age calculation. Nil if not set.
    public var dateOfBirth: Date?

    /// Biological sex for metric norm stratification.
    public var biologicalSex: BiologicalSex

    public init(
        displayName: String = "",
        joinDate: Date = Date(),
        onboardingComplete: Bool = false,
        streakDays: Int = 0,
        lastStreakCreditDate: Date? = nil,
        nudgeCompletionDates: Set<String> = [],
        dateOfBirth: Date? = nil,
        biologicalSex: BiologicalSex = .notSet
    ) {
        self.displayName = displayName
        self.joinDate = joinDate
        self.onboardingComplete = onboardingComplete
        self.streakDays = streakDays
        self.lastStreakCreditDate = lastStreakCreditDate
        self.nudgeCompletionDates = nudgeCompletionDates
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
    }

    /// Computed chronological age in years from date of birth.
    public var chronologicalAge: Int? {
        guard let dob = dateOfBirth else { return nil }
        let components = Calendar.current.dateComponents([.year], from: dob, to: Date())
        return components.year
    }
}

// MARK: - Subscription Tier

/// Subscription tiers with feature gating and pricing.
public enum SubscriptionTier: String, Codable, Equatable, Sendable, CaseIterable {
    case free
    case pro
    case coach
    case family

    /// User-facing tier name.
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .coach: return "Coach"
        case .family: return "Family"
        }
    }

    /// Monthly price in USD.
    public var monthlyPrice: Double {
        switch self {
        case .free: return 0.0
        case .pro: return 3.99
        case .coach: return 6.99
        case .family: return 0.0  // Family is annual-only
        }
    }

    /// Annual price in USD.
    public var annualPrice: Double {
        switch self {
        case .free: return 0.0
        case .pro: return 29.99
        case .coach: return 59.99
        case .family: return 79.99
        }
    }

    /// List of features included in this tier.
    public var features: [String] {
        switch self {
        case .free:
            return [
                "Daily wellness snapshot (Building Momentum / Holding Steady / Check In)",
                "Basic trend view for resting heart rate and steps",
                "Watch feedback capture"
            ]
        case .pro:
            return [
                "Full wellness dashboard (HRV, Recovery, VO2, zone activity)",
                "Personalized daily suggestions",
                "Heads-up when patterns shift",
                "Stress pattern awareness",
                "Connection cards (activity vs. trends)",
                "Pattern strength on all insights"
            ]
        case .coach:
            return [
                "Everything in Pro",
                "Weekly wellness review and gentle plan tweaks",
                "Multi-week trend exploration and progress snapshots",
                "Shareable PDF wellness summaries",
                "Priority pattern alerts"
            ]
        case .family:
            return [
                "Everything in Coach for up to 5 members",
                "Shared goals and accountability view",
                "Caregiver mode for family members"
            ]
        }
    }

    /// Whether this tier grants access to full metric dashboards.
    /// NOTE: All features are currently free for all users.
    public var canAccessFullMetrics: Bool {
        return true
    }

    /// Whether this tier grants access to personalized nudges.
    /// NOTE: All features are currently free for all users.
    public var canAccessNudges: Bool {
        return true
    }

    /// Whether this tier grants access to weekly reports and trend analysis.
    /// NOTE: All features are currently free for all users.
    public var canAccessReports: Bool {
        return true
    }

    /// Whether this tier grants access to activity-trend correlation analysis.
    /// NOTE: All features are currently free for all users.
    public var canAccessCorrelations: Bool {
        return true
    }
}

// MARK: - Quick Log Action

/// User-initiated quick-log entries from the Apple Watch.
/// These are one-tap actions — minimal friction, maximum engagement.
public enum QuickLogCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case water
    case caffeine
    case alcohol
    case sunlight
    case meditate
    case activity
    case mood

    /// Whether this category supports a running counter (tap = +1) rather than a single toggle.
    public var isCounter: Bool {
        switch self {
        case .water, .caffeine, .alcohol: return true
        default: return false
        }
    }

    /// SF Symbol icon for the action button.
    public var icon: String {
        switch self {
        case .water:    return "drop.fill"
        case .caffeine: return "cup.and.saucer.fill"
        case .alcohol:  return "wineglass.fill"
        case .sunlight: return "sun.max.fill"
        case .meditate: return "figure.mind.and.body"
        case .activity: return "figure.run"
        case .mood:     return "face.smiling.fill"
        }
    }

    /// Short label for the button.
    public var label: String {
        switch self {
        case .water:    return "Water"
        case .caffeine: return "Caffeine"
        case .alcohol:  return "Alcohol"
        case .sunlight: return "Sunlight"
        case .meditate: return "Meditate"
        case .activity: return "Activity"
        case .mood:     return "Mood"
        }
    }

    /// Unit label shown next to the counter (counters only).
    public var unit: String {
        switch self {
        case .water:    return "cups"
        case .caffeine: return "cups"
        case .alcohol:  return "drinks"
        default:        return ""
        }
    }

    /// Named tint color — gender-neutral palette.
    public var tintColorHex: UInt32 {
        switch self {
        case .water:    return 0x06B6D4  // Cyan
        case .caffeine: return 0xF59E0B  // Amber
        case .alcohol:  return 0x8B5CF6  // Violet
        case .sunlight: return 0xFBBF24  // Yellow
        case .meditate: return 0x0D9488  // Teal
        case .activity: return 0x22C55E  // Green
        case .mood:     return 0xEC4899  // Pink
        }
    }
}

// MARK: - Watch Action Plan

/// A lightweight, Codable summary of today's actions + weekly/monthly context
/// synced from the iPhone to the Apple Watch via WatchConnectivity.
///
/// Kept small (<65 KB) to stay well within WatchConnectivity message limits.
public struct WatchActionPlan: Codable, Sendable {

    // MARK: - Daily Actions

    /// Today's prioritised action items (max 4 — one per domain).
    public let dailyItems: [WatchActionItem]

    /// Date these daily items were generated.
    public let dailyDate: Date

    // MARK: - Weekly Summary

    /// Buddy-voiced weekly headline, e.g. "You nailed 5 of 7 days this week!"
    public let weeklyHeadline: String

    /// Average heart score for the week (0-100), if available.
    public let weeklyAvgScore: Double?

    /// Number of days this week the user met their activity goal.
    public let weeklyActiveDays: Int

    /// Number of days this week flagged as low-stress.
    public let weeklyLowStressDays: Int

    // MARK: - Monthly Summary

    /// Buddy-voiced monthly headline, e.g. "Your best month yet — HRV up 12%!"
    public let monthlyHeadline: String

    /// Month-over-month score delta (+/-).
    public let monthlyScoreDelta: Double?

    /// Month name string for display, e.g. "February".
    public let monthName: String

    public init(
        dailyItems: [WatchActionItem],
        dailyDate: Date = Date(),
        weeklyHeadline: String,
        weeklyAvgScore: Double? = nil,
        weeklyActiveDays: Int = 0,
        weeklyLowStressDays: Int = 0,
        monthlyHeadline: String,
        monthlyScoreDelta: Double? = nil,
        monthName: String
    ) {
        self.dailyItems = dailyItems
        self.dailyDate = dailyDate
        self.weeklyHeadline = weeklyHeadline
        self.weeklyAvgScore = weeklyAvgScore
        self.weeklyActiveDays = weeklyActiveDays
        self.weeklyLowStressDays = weeklyLowStressDays
        self.monthlyHeadline = monthlyHeadline
        self.monthlyScoreDelta = monthlyScoreDelta
        self.monthName = monthName
    }
}

/// A single daily action item carried in ``WatchActionPlan``.
public struct WatchActionItem: Codable, Identifiable, Sendable {
    public let id: UUID
    public let category: NudgeCategory
    public let title: String
    public let detail: String
    public let icon: String
    /// Optional reminder hour (0-23) for this item.
    public let reminderHour: Int?

    public init(
        id: UUID = UUID(),
        category: NudgeCategory,
        title: String,
        detail: String,
        icon: String,
        reminderHour: Int? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
        self.icon = icon
        self.reminderHour = reminderHour
    }
}

extension WatchActionPlan {
    /// Mock plan for Simulator previews and tests.
    public static var mock: WatchActionPlan {
        WatchActionPlan(
            dailyItems: [
                WatchActionItem(
                    category: .rest,
                    title: "Wind Down by 9 PM",
                    detail: "You averaged 6.2 hrs last week — aim for 7+.",
                    icon: "bed.double.fill",
                    reminderHour: 21
                ),
                WatchActionItem(
                    category: .breathe,
                    title: "Morning Breathe",
                    detail: "3 min of box breathing before you start your day.",
                    icon: "wind",
                    reminderHour: 7
                ),
                WatchActionItem(
                    category: .walk,
                    title: "Walk 12 More Minutes",
                    detail: "You're 12 min short of your 30-min daily goal.",
                    icon: "figure.walk",
                    reminderHour: nil
                ),
                WatchActionItem(
                    category: .sunlight,
                    title: "Step Outside at Lunch",
                    detail: "You tend to be sedentary 12–1 PM — ideal sunlight window.",
                    icon: "sun.max.fill",
                    reminderHour: 12
                )
            ],
            weeklyHeadline: "You nailed 5 of 7 days this week!",
            weeklyAvgScore: 72,
            weeklyActiveDays: 5,
            weeklyLowStressDays: 4,
            monthlyHeadline: "Your best month yet — keep it up!",
            monthlyScoreDelta: 8,
            monthName: "March"
        )
    }
}

/// A single quick-log entry recorded from the watch.
public struct QuickLogEntry: Codable, Equatable, Sendable {
    /// Unique event identifier for deduplication.
    public let eventId: String

    /// Timestamp of the log.
    public let date: Date

    /// What was logged.
    public let category: QuickLogCategory

    /// Source device.
    public let source: String

    public init(
        eventId: String = UUID().uuidString,
        date: Date = Date(),
        category: QuickLogCategory,
        source: String = "watch"
    ) {
        self.eventId = eventId
        self.date = date
        self.category = category
        self.source = source
    }
}

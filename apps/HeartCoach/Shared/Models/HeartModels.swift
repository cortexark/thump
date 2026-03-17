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
    case intensity

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
        case .intensity: return "bolt.heart.fill"
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
        case .intensity: return "nudgeIntensity"
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

    /// Height in meters. Sourced from HealthKit (`HKQuantityType(.height)`).
    /// Used by BioAgeEngine for accurate BMI calculation instead of
    /// estimated height from population averages (BUG-062 fix).
    public let heightM: Double?

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
        bodyMassKg: Double? = nil,
        heightM: Double? = nil
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
        self.heightM = Self.clamp(heightM, to: 0.5...2.5)
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

// Types below this line have been extracted into domain-specific files:
// - StressModels.swift       → StressLevel, StressMode, StressResult, etc.
// - ActionPlanModels.swift    → WeeklyActionItem, WeeklyActionPlan, SunlightWindow, etc.
// - UserModels.swift          → UserProfile, SubscriptionTier, BiologicalSex, etc.
// - WatchSyncModels.swift     → WatchActionPlan, WatchActionItem, QuickLogEntry, etc.

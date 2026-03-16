// StressModels.swift
// ThumpCore
//
// Stress subsystem domain models — scoring, levels, data points,
// and context inputs for the HRV-based stress engine.
// Extracted from HeartModels.swift for domain isolation.
//
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

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

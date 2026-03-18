// BuddyRecommendationEngine.swift
// ThumpCore
//
// Unified recommendation engine that synthesizes signals from all
// Thump engines (Stress, Trend, Readiness, BioAge) into prioritised,
// contextual buddy recommendations.
//
// The buddy voice is warm, non-clinical, and action-oriented.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Recommendation Priority

/// Priority level for buddy recommendations. Higher priority = shown first.
public enum RecommendationPriority: Int, Comparable, Sendable {
    case critical = 4   // Illness risk, overtraining, consecutive elevation
    case high = 3       // Stress pattern, regression, significant elevation
    case medium = 2     // Scenario coaching, recovery dip, missing activity
    case low = 1        // Positive reinforcement, general wellness tips

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Buddy Recommendation

/// A single buddy recommendation combining signal source, action, and context.
public struct BuddyRecommendation: Sendable, Identifiable {
    public let id: UUID
    public let priority: RecommendationPriority
    public let category: NudgeCategory
    public let title: String
    public let message: String
    public let detail: String
    public let icon: String
    public let source: RecommendationSource
    public let actionable: Bool

    public init(
        id: UUID = UUID(),
        priority: RecommendationPriority,
        category: NudgeCategory,
        title: String,
        message: String,
        detail: String = "",
        icon: String,
        source: RecommendationSource,
        actionable: Bool = true
    ) {
        self.id = id
        self.priority = priority
        self.category = category
        self.title = title
        self.message = message
        self.detail = detail
        self.icon = icon
        self.source = source
        self.actionable = actionable
    }
}

/// Which engine or signal produced this recommendation.
public enum RecommendationSource: String, Sendable {
    case stressEngine
    case trendEngine
    case weekOverWeek
    case consecutiveAlert
    case recoveryTrend
    case scenarioDetection
    case readinessEngine
    case activityPattern
    case sleepPattern
    case general
}

// MARK: - Buddy Recommendation Engine

/// Synthesises all Thump engine outputs into a prioritised list of buddy
/// recommendations. This is the single source of truth for "what should
/// we tell the user today?"
///
/// Input signals:
/// - `HeartAssessment` (from HeartTrendEngine) — anomaly, regression, stress,
///   week-over-week trend, consecutive alert, recovery trend, scenario
/// - `StressResult` (from StressEngine) — daily stress score + level
/// - `ReadinessResult` (optional, from ReadinessEngine) — readiness score
/// - `HeartSnapshot` — today's raw metrics for contextual messages
/// - `[HeartSnapshot]` — recent history for pattern detection
///
/// Output: `[BuddyRecommendation]` sorted by priority (highest first),
/// deduplicated, and capped at `maxRecommendations`.
public struct BuddyRecommendationEngine: Sendable {

    /// Maximum recommendations to return.
    public let maxRecommendations: Int

    public init(maxRecommendations: Int = 4) {
        self.maxRecommendations = maxRecommendations
    }

    // MARK: - Public API

    /// Generate prioritised buddy recommendations from all available signals.
    ///
    /// - Parameters:
    ///   - assessment: Today's HeartAssessment from the trend engine.
    ///   - stressResult: Today's stress score from the stress engine.
    ///   - readinessScore: Optional readiness score (0-100).
    ///   - current: Today's HeartSnapshot.
    ///   - history: Recent snapshot history.
    /// - Returns: Array of recommendations sorted by priority (highest first).
    public func recommend(
        assessment: HeartAssessment,
        stressResult: StressResult? = nil,
        readinessScore: Double? = nil,
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> [BuddyRecommendation] {
        var recommendations: [BuddyRecommendation] = []

        // 1. Consecutive elevation alert (critical)
        if let alert = assessment.consecutiveAlert {
            recommendations.append(consecutiveAlertRec(alert))
        }

        // 2. Coaching scenario
        if let scenario = assessment.scenario {
            recommendations.append(scenarioRec(scenario))
        }

        // 3. Stress engine signal
        if let stress = stressResult {
            if let rec = stressRec(stress) {
                recommendations.append(rec)
            }
        }

        // 4. Week-over-week trend
        if let wow = assessment.weekOverWeekTrend {
            if let rec = weekOverWeekRec(wow) {
                recommendations.append(rec)
            }
        }

        // 5. Recovery trend
        if let recovery = assessment.recoveryTrend {
            if let rec = recoveryRec(recovery) {
                recommendations.append(rec)
            }
        }

        // 6. Regression flag
        if assessment.regressionFlag {
            recommendations.append(regressionRec())
        }

        // 7. Stress pattern from trend engine
        if assessment.stressFlag {
            recommendations.append(stressPatternRec())
        }

        // 8. Readiness-based recommendation
        if let readiness = readinessScore {
            if let rec = readinessRec(readiness) {
                recommendations.append(rec)
            }
        }

        // 9. Activity pattern (missing activity)
        if let rec = activityPatternRec(current: current, history: history) {
            recommendations.append(rec)
        }

        // 10. Sleep pattern
        if let rec = sleepPatternRec(current: current, history: history) {
            recommendations.append(rec)
        }

        // 11. Positive reinforcement (if nothing alarming)
        if recommendations.filter({ $0.priority >= .high }).isEmpty {
            if assessment.status == .improving {
                recommendations.append(positiveRec(assessment: assessment))
            }
        }

        // Fallback: always surface at least one recommendation so the
        // dashboard is never empty. A neutral "stay consistent" nudge is
        // appropriate when all signals are quiet (nothing alarming, nothing
        // to celebrate — the user is simply on track).
        if recommendations.isEmpty {
            recommendations.append(BuddyRecommendation(
                priority: .low,
                category: .rest,
                title: "Keep the rhythm going",
                message: "Your metrics are quiet right now — no alerts, no red flags. "
                    + "Stay consistent and check back tomorrow.",
                icon: "checkmark.circle.fill",
                source: .scenarioDetection
            ))
        }

        // Deduplicate by category (keep highest priority per category)
        let deduped = deduplicateByCategory(recommendations)

        // Sort by priority descending, take top N
        return Array(deduped
            .sorted { $0.priority > $1.priority }
            .prefix(maxRecommendations))
    }

    // MARK: - Recommendation Generators

    private func consecutiveAlertRec(
        _ alert: ConsecutiveElevationAlert
    ) -> BuddyRecommendation {
        BuddyRecommendation(
            priority: .critical,
            category: .rest,
            title: "Your heart rate has been elevated",
            message: "Your resting heart rate has been elevated for "
                + "\(alert.consecutiveDays) days. This usually reflects recent sleep, "
                + "stress, or activity changes — and typically normalizes once those settle.",
            detail: String(format: "RHR avg: %.0f bpm vs your usual %.0f bpm",
                           alert.elevatedMean, alert.personalMean),
            icon: "heart.fill",
            source: .consecutiveAlert
        )
    }

    private func scenarioRec(
        _ scenario: CoachingScenario
    ) -> BuddyRecommendation {
        let (priority, category): (RecommendationPriority, NudgeCategory) = {
            switch scenario {
            case .overtrainingSignals: return (.critical, .rest)
            case .highStressDay: return (.high, .breathe)
            case .greatRecoveryDay: return (.low, .celebrate)
            case .missingActivity: return (.medium, .walk)
            case .improvingTrend: return (.low, .celebrate)
            case .decliningTrend: return (.high, .rest)
            }
        }()

        return BuddyRecommendation(
            priority: priority,
            category: category,
            title: scenarioTitle(scenario),
            message: scenario.coachingMessage,
            icon: scenario.icon,
            source: .scenarioDetection
        )
    }

    private func scenarioTitle(_ scenario: CoachingScenario) -> String {
        switch scenario {
        case .highStressDay: return "Tough day — take a breather"
        case .greatRecoveryDay: return "You bounced back nicely"
        case .missingActivity: return "Time to get moving"
        case .overtrainingSignals: return "Your body is asking for a break"
        case .improvingTrend: return "Keep up the good work"
        case .decliningTrend: return "Let's turn things around"
        }
    }

    private func stressRec(_ stress: StressResult) -> BuddyRecommendation? {
        switch stress.level {
        case .elevated:
            return BuddyRecommendation(
                priority: .high,
                category: .breathe,
                title: "Stress is running high today",
                message: "Your stress score is \(Int(stress.score)) out of 100. "
                    + "A few minutes of slow breathing can help bring it down.",
                detail: stress.description,
                icon: "flame.fill",
                source: .stressEngine
            )
        case .relaxed:
            return BuddyRecommendation(
                priority: .low,
                category: .celebrate,
                title: "Low stress — great day so far",
                message: "Your stress score is \(Int(stress.score)). "
                    + "Your body seems pretty relaxed today.",
                icon: "leaf.fill",
                source: .stressEngine,
                actionable: false
            )
        case .balanced:
            return nil // Don't clutter with "balanced" messages
        }
    }

    private func weekOverWeekRec(
        _ trend: WeekOverWeekTrend
    ) -> BuddyRecommendation? {
        switch trend.direction {
        case .significantElevation:
            return BuddyRecommendation(
                priority: .high,
                category: .rest,
                title: "Resting heart rate crept up this week",
                message: trend.direction.displayText + ". "
                    + "Consider whether sleep, stress, or training load changed recently.",
                detail: String(format: "This week: %.0f bpm vs baseline: %.0f bpm (z = %+.1f)",
                               trend.currentWeekMean, trend.baselineMean, trend.zScore),
                icon: trend.direction.icon,
                source: .weekOverWeek
            )
        case .elevated:
            return BuddyRecommendation(
                priority: .medium,
                category: .moderate,
                title: "RHR is slightly above your normal",
                message: trend.direction.displayText + ". Nothing alarming, but worth keeping an eye on.",
                icon: trend.direction.icon,
                source: .weekOverWeek,
                actionable: false
            )
        case .significantImprovement:
            return BuddyRecommendation(
                priority: .low,
                category: .celebrate,
                title: "Your heart rate dropped this week",
                message: trend.direction.displayText + ". "
                    + "Whatever you've been doing is working.",
                icon: trend.direction.icon,
                source: .weekOverWeek,
                actionable: false
            )
        case .improving:
            return nil // Subtle improvement, don't distract
        case .stable:
            return nil // No news is good news
        }
    }

    private func recoveryRec(
        _ trend: RecoveryTrend
    ) -> BuddyRecommendation? {
        switch trend.direction {
        case .declining:
            return BuddyRecommendation(
                priority: .medium,
                category: .rest,
                title: "Recovery rate dipped recently",
                message: trend.direction.displayText + ". "
                    + "This can happen with extra fatigue or when you've been pushing hard.",
                detail: trend.currentWeekMean.map {
                    String(format: "Current week avg: %.0f bpm drop", $0)
                } ?? "",
                icon: "heart.slash",
                source: .recoveryTrend
            )
        case .improving:
            return BuddyRecommendation(
                priority: .low,
                category: .celebrate,
                title: "Recovery rate is improving",
                message: trend.direction.displayText,
                icon: "heart.circle",
                source: .recoveryTrend,
                actionable: false
            )
        case .stable, .insufficientData:
            return nil
        }
    }

    private func regressionRec() -> BuddyRecommendation {
        BuddyRecommendation(
            priority: .high,
            category: .rest,
            title: "A gradual shift in your metrics",
            message: "Your heart metrics have been slowly shifting over the past "
                + "several days. Prioritising rest and sleep may help reverse the trend.",
            icon: "chart.line.downtrend.xyaxis",
            source: .trendEngine
        )
    }

    private func stressPatternRec() -> BuddyRecommendation {
        BuddyRecommendation(
            priority: .high,
            category: .breathe,
            title: "Stress pattern detected",
            message: "Your resting heart rate, HRV, and recovery are all pointing "
                + "in the same direction today. A short walk or breathing exercise "
                + "may help you reset.",
            icon: "waveform.path.ecg",
            source: .trendEngine
        )
    }

    private func readinessRec(_ score: Double) -> BuddyRecommendation? {
        if score < 40 {
            return BuddyRecommendation(
                priority: .medium,
                category: .rest,
                title: "Low readiness today",
                message: "Your body readiness score is \(Int(score)) out of 100. "
                    + "A lighter day may be a good idea.",
                icon: "battery.25percent",
                source: .readinessEngine
            )
        } else if score > 80 {
            return BuddyRecommendation(
                priority: .low,
                category: .walk,
                title: "High readiness — great day to train",
                message: "Your readiness score is \(Int(score)). "
                    + "Your body is well-recovered and ready for a challenge.",
                icon: "battery.100percent",
                source: .readinessEngine
            )
        }
        return nil
    }

    private func activityPatternRec(
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> BuddyRecommendation? {
        // Check for 2+ consecutive low-activity days
        let recentTwo = (history + [current]).suffix(2)
        let inactive = recentTwo.allSatisfy {
            ($0.workoutMinutes ?? 0) < 5 && ($0.steps ?? 0) < 2000
        }
        guard inactive && recentTwo.count >= 2 else { return nil }

        return BuddyRecommendation(
            priority: .medium,
            category: .walk,
            title: "You've been less active lately",
            message: "It's been a couple of quiet days. Even a 10-minute walk "
                + "can boost your mood and circulation.",
            icon: "figure.walk",
            source: .activityPattern
        )
    }

    private func sleepPatternRec(
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> BuddyRecommendation? {
        // Check for poor sleep (< 6 hours for 2+ nights)
        let recentTwo = (history + [current]).suffix(2)
        let poorSleep = recentTwo.allSatisfy {
            ($0.sleepHours ?? 8.0) < 6.0
        }
        guard poorSleep && recentTwo.count >= 2 else { return nil }

        return BuddyRecommendation(
            priority: .medium,
            category: .rest,
            title: "Short on sleep",
            message: "You've had less than 6 hours of sleep two nights running. "
                + "Consider winding down earlier tonight.",
            icon: "moon.zzz.fill",
            source: .sleepPattern
        )
    }

    private func positiveRec(
        assessment: HeartAssessment
    ) -> BuddyRecommendation {
        BuddyRecommendation(
            priority: .low,
            category: .celebrate,
            title: "Looking good today",
            message: "Your heart metrics are trending in a positive direction. "
                + "Keep it up!",
            icon: "star.fill",
            source: .general,
            actionable: false
        )
    }

    // MARK: - Deduplication

    /// Keep only the highest-priority recommendation per category.
    private func deduplicateByCategory(
        _ recs: [BuddyRecommendation]
    ) -> [BuddyRecommendation] {
        var bestByCategory: [NudgeCategory: BuddyRecommendation] = [:]
        for rec in recs {
            if let existing = bestByCategory[rec.category] {
                if rec.priority > existing.priority {
                    bestByCategory[rec.category] = rec
                }
            } else {
                bestByCategory[rec.category] = rec
            }
        }
        return Array(bestByCategory.values)
    }
}

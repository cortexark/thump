// ReadinessEngine.swift
// ThumpCore
//
// Computes a daily Readiness Score (0-100) from multiple wellness
// pillars: sleep quality, recovery heart rate, stress, activity
// balance, and HRV trend. The score reflects how prepared the body
// is for exertion today. All computation is on-device.
//
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Readiness Engine

/// Computes a composite daily readiness score from Apple Watch health
/// metrics and stress data.
///
/// Uses a weighted five-pillar approach covering sleep, recovery,
/// stress, activity balance, and HRV trend. Missing pillars are
/// skipped and weights are re-normalized across available data.
///
/// **This is a wellness estimate, not a medical measurement.**
public struct ReadinessEngine: Sendable {

    // MARK: - Configuration

    private let config: HealthPolicyConfig.SleepReadiness

    /// Pillar weights (sum to 1.0).
    private var pillarWeights: [ReadinessPillarType: Double] {
        [
            .sleep: config.pillarWeights["sleep", default: 0.25],
            .recovery: config.pillarWeights["recovery", default: 0.25],
            .stress: config.pillarWeights["stress", default: 0.20],
            .activityBalance: config.pillarWeights["activityBalance", default: 0.15],
            .hrvTrend: config.pillarWeights["hrvTrend", default: 0.15]
        ]
    }

    public init(config: HealthPolicyConfig.SleepReadiness = ConfigService.activePolicy.sleepReadiness) {
        self.config = config
    }

    // MARK: - Public API

    /// Compute a readiness score from today's snapshot, an optional
    /// stress score, and recent history for trend analysis.
    ///
    /// - Parameters:
    ///   - snapshot: Today's health metrics.
    ///   - stressScore: Current stress score (0-100), nil if unavailable.
    ///   - stressConfidence: Confidence in the stress score. Low confidence
    ///     reduces the stress pillar's impact on readiness.
    ///   - recentHistory: Recent daily snapshots (ideally 7+ days) for
    ///     trend and activity-balance calculations.
    ///   - consecutiveAlert: If present, indicates 3+ days of elevated
    ///     RHR above personal mean+2σ. Caps readiness at 50.
    /// - Returns: A `ReadinessResult`, or nil if fewer than 2 pillars
    ///   have data.
    public func compute(
        snapshot: HeartSnapshot,
        stressScore: Double?,
        stressConfidence: StressConfidence? = nil,
        recentHistory: [HeartSnapshot],
        consecutiveAlert: ConsecutiveElevationAlert? = nil
    ) -> ReadinessResult? {
        var pillars: [ReadinessPillar] = []

        // 1. Sleep Quality
        // Missing sleep penalizes readiness (floor score 40) rather than being
        // excluded, which would inflate the composite from remaining pillars.
        if let pillar = scoreSleep(snapshot: snapshot) {
            pillars.append(pillar)
        } else {
            pillars.append(ReadinessPillar(
                type: .sleep,
                score: config.missingDataFloorScore,
                weight: pillarWeights[.sleep, default: 0.25],
                detail: "No sleep data — we're working with limited info today"
            ))
        }

        // 2. Recovery (HR Recovery 1 min)
        // Missing recovery also uses a floor score to prevent inflation.
        if let pillar = scoreRecovery(snapshot: snapshot) {
            pillars.append(pillar)
        } else {
            pillars.append(ReadinessPillar(
                type: .recovery,
                score: config.missingDataFloorScore,
                weight: pillarWeights[.recovery, default: 0.25],
                detail: "No recovery data yet"
            ))
        }

        // 3. Stress (attenuated by confidence)
        if let pillar = scoreStress(stressScore: stressScore, confidence: stressConfidence) {
            pillars.append(pillar)
        }

        // 4. Activity Balance
        if let pillar = scoreActivityBalance(
            snapshot: snapshot,
            recentHistory: recentHistory
        ) {
            pillars.append(pillar)
        }

        // 5. HRV Trend
        if let pillar = scoreHRVTrend(
            snapshot: snapshot,
            recentHistory: recentHistory
        ) {
            pillars.append(pillar)
        }

        // Sleep and recovery always contribute (with floor scores if missing),
        // so we always have at least 2 pillars. Guard kept for safety.
        guard pillars.count >= 2 else { return nil }

        // Normalize by actual weight coverage
        let totalWeight = pillars.reduce(0.0) { $0 + $1.weight }
        let weightedSum = pillars.reduce(0.0) { $0 + $1.score * $1.weight }
        let normalizedScore = weightedSum / totalWeight

        // Overtraining cap: consecutive RHR elevation limits readiness
        var finalScore = normalizedScore
        if consecutiveAlert != nil {
            finalScore = min(finalScore, config.consecutiveAlertCap)
        }

        // Sleep deprivation cap: <5h sleep caps readiness at "moderate" (59 max),
        // <4h caps at "recovering" (39 max). Acute sleep deprivation impairs
        // reaction time, judgment, and recovery regardless of other metrics.
        // sleepHours == nil means "no data" (handled by floor score above).
        // sleepHours == 0.0 means "tracked zero sleep" — cap hardest.
        if let hours = snapshot.sleepHours {
            if hours < config.sleepCapCriticalHours {
                finalScore = min(finalScore, config.sleepCapCriticalScore)
            } else if hours < config.sleepCapLowHours {
                finalScore = min(finalScore, config.sleepCapLowScore)
            } else if hours < config.sleepCapModerateHours {
                finalScore = min(finalScore, config.sleepCapModerateScore)
            }
        }

        let clampedScore = Int(round(max(0, min(100, finalScore))))
        let level = ReadinessLevel.from(score: clampedScore)

        // Build summary with pillar awareness — sleep deprivation overrides generic text
        let summary = buildSummary(level: level, sleepHours: snapshot.sleepHours, pillars: pillars)

        return ReadinessResult(
            score: clampedScore,
            level: level,
            pillars: pillars,
            summary: summary
        )
    }

    // MARK: - Pillar Scoring

    /// Sleep Quality: bell curve centered at 8h, optimal 7-9h = 100.
    private func scoreSleep(snapshot: HeartSnapshot) -> ReadinessPillar? {
        guard let hours = snapshot.sleepHours, hours >= 0 else { return nil }

        let optimal = config.sleepOptimalHours
        let deviation = abs(hours - optimal)
        // Gaussian-like: score = 100 * exp(-0.5 * (deviation / sigma)^2)
        // sigma ~1.5 gives: 7h/9h ≈ 95, 6h/10h ≈ 75, 5h/11h ≈ 41
        let sigma = config.sleepSigma
        let score = 100.0 * exp(-0.5 * pow(deviation / sigma, 2))

        let detail: String
        if hours >= 7.0 && hours <= 9.0 {
            detail = String(format: "%.1f hours — right in the sweet spot", hours)
        } else if hours > 9.0 {
            detail = String(format: "%.1f hours — more rest than usual. If this keeps up, mention it to your care team.", hours)
        } else if hours >= 6.0 {
            detail = String(format: "%.1f hours — a bit under, an earlier bedtime could help", hours)
        } else if hours >= 5.0 {
            detail = String(format: "%.1f hours — well below the 7+ hours your body needs", hours)
        } else {
            detail = String(format: "%.1f hours — very low. Even if other metrics look good, sleep debt overrides them.", hours)
        }

        return ReadinessPillar(
            type: .sleep,
            score: score,
            weight: pillarWeights[.sleep, default: 0.25],
            detail: detail
        )
    }

    /// Recovery: based on heart rate recovery at 1 minute.
    /// 40+ bpm drop = 100, linear down to 0 at 10 bpm.
    private func scoreRecovery(snapshot: HeartSnapshot) -> ReadinessPillar? {
        guard let recovery = snapshot.recoveryHR1m, recovery > 0 else {
            return nil
        }

        let minDrop = config.recoveryMinDrop
        let maxDrop = config.recoveryMaxDrop
        let score: Double
        if recovery >= maxDrop {
            score = 100.0
        } else if recovery <= minDrop {
            score = 0.0
        } else {
            score = ((recovery - minDrop) / (maxDrop - minDrop)) * 100.0
        }

        let detail: String
        let dropInt = Int(round(recovery))
        if recovery >= 35 {
            detail = "\(dropInt) bpm drop — excellent recovery"
        } else if recovery >= 25 {
            detail = "\(dropInt) bpm drop — solid recovery"
        } else if recovery >= 15 {
            detail = "\(dropInt) bpm drop — moderate recovery"
        } else {
            detail = "\(dropInt) bpm drop — recovery is a bit slow"
        }

        return ReadinessPillar(
            type: .recovery,
            score: score,
            weight: pillarWeights[.recovery, default: 0.25],
            detail: detail
        )
    }

    /// Stress: linear inversion of stress score, attenuated by confidence.
    ///
    /// Low-confidence stress readings have reduced impact on readiness,
    /// preventing uncertain stress signals from unfairly penalizing the score.
    private func scoreStress(stressScore: Double?, confidence: StressConfidence? = nil) -> ReadinessPillar? {
        guard let stress = stressScore else { return nil }

        let clamped = max(0, min(100, stress))

        // Attenuate by confidence: low confidence pulls score toward neutral (50).
        // When confidence is nil (legacy callers), use full weight for backward compatibility.
        let confidenceWeight = confidence?.weight ?? 1.0
        let attenuatedInverse = (100.0 - clamped) * confidenceWeight + 50.0 * (1.0 - confidenceWeight)
        let score = attenuatedInverse

        let detail: String
        if confidence == .low {
            if clamped <= 30 {
                detail = "Low stress signal — still building confidence"
            } else if clamped <= 60 {
                detail = "Moderate stress signal — readings still stabilizing"
            } else {
                detail = "Elevated stress signal — but confidence is low"
            }
        } else {
            if clamped <= 30 {
                detail = "Low stress — your mind is at ease"
            } else if clamped <= 60 {
                detail = "Moderate stress — pretty normal"
            } else {
                detail = "Elevated stress — consider taking it easy"
            }
        }

        return ReadinessPillar(
            type: .stress,
            score: score,
            weight: pillarWeights[.stress, default: 0.20],
            detail: detail
        )
    }

    /// Activity Balance: looks at the last 7 days of activity to assess
    /// recovery state and consistency.
    private func scoreActivityBalance(
        snapshot: HeartSnapshot,
        recentHistory: [HeartSnapshot]
    ) -> ReadinessPillar? {
        // Build up to 7 days of activity: today + last 6 from history
        let todayMinutes = (snapshot.walkMinutes ?? 0) + (snapshot.workoutMinutes ?? 0)

        // Get the most recent snapshots (excluding today if it's in the history)
        let sorted = recentHistory
            .filter { $0.date < snapshot.date }
            .sorted { $0.date > $1.date }
            .prefix(6)

        let day1 = todayMinutes
        let recentDays = sorted.map { ($0.walkMinutes ?? 0) + ($0.workoutMinutes ?? 0) }
        let day2 = recentDays.first
        let day3 = recentDays.dropFirst().first

        // Fallback: if yesterday's data is missing, score from today only
        guard let yesterday = day2 else {
            let todayScore: Double
            let todayDetail: String
            if day1 < 1 {
                todayScore = 40.0
                todayDetail = "Rest day — recovery counts too"
            } else if day1 < 5 {
                todayScore = 35.0
                todayDetail = "Movement is low — even a short walk helps"
            } else if day1 < 20 {
                todayScore = 55.0
                todayDetail = String(format: "%.0f min today — a good start, try for 20", day1)
            } else if day1 <= 45 {
                todayScore = 75.0
                todayDetail = String(format: "%.0f min today — keep it up", day1)
            } else {
                todayScore = 85.0
                todayDetail = String(format: "%.0f min today — active day!", day1)
            }
            return ReadinessPillar(
                type: .activityBalance,
                score: todayScore,
                weight: pillarWeights[.activityBalance, default: 0.15],
                detail: todayDetail
            )
        }

        let score: Double
        let detail: String

        // Check if yesterday was very active and today is a rest day (good recovery)
        if yesterday > 60 && day1 < 15 {
            score = 85.0
            detail = "Active yesterday, resting today — smart recovery"
        }
        // Check for 3 days of inactivity
        else if let dayBefore = day3, day1 < 10 && yesterday < 10 && dayBefore < 10 {
            score = 30.0
            detail = "Three quiet days in a row — your body wants to move"
        }
        // Check for moderate consistent activity (optimal)
        else {
            let days = [day1] + Array(recentDays)
            let avg = days.reduce(0, +) / Double(days.count)

            if avg >= 20 && avg <= 45 {
                // Sweet spot
                score = 100.0
                detail = String(format: "Averaging %.0f min/day — great balance", avg)
            } else if avg > 45 {
                // High volume — possible overtraining
                let excess = min((avg - 45) / 30.0, 1.0)
                score = 100.0 - excess * 40.0
                detail = String(format: "Averaging %.0f min/day — that's a lot, consider easing up", avg)
            } else {
                // Below 20 but not fully inactive
                let deficit = min((20 - avg) / 20.0, 1.0)
                score = 100.0 - deficit * 50.0
                detail = String(format: "Averaging %.0f min/day — a little more movement helps", avg)
            }
        }

        return ReadinessPillar(
            type: .activityBalance,
            score: max(0, min(100, score)),
            weight: pillarWeights[.activityBalance, default: 0.15],
            detail: detail
        )
    }

    /// HRV Trend: compare today's HRV to a stable baseline.
    /// Uses the 75th percentile of a 14-day window to prevent baseline
    /// normalization during prolonged stress/illness (where the mean would
    /// adapt downward, masking continued depression).
    /// At or above baseline = 100. Each 10% below loses ~20 points.
    private func scoreHRVTrend(
        snapshot: HeartSnapshot,
        recentHistory: [HeartSnapshot]
    ) -> ReadinessPillar? {
        guard let todayHRV = snapshot.hrvSDNN, todayHRV > 0 else {
            return nil
        }

        // Use up to 14 days of history for a more stable baseline
        let recentHRVs = recentHistory
            .filter { $0.date < snapshot.date }
            .suffix(14)
            .compactMap(\.hrvSDNN)
            .filter { $0 > 0 }

        guard !recentHRVs.isEmpty else { return nil }

        // Use the 75th percentile instead of the mean. This anchors the
        // baseline closer to the user's "good days" so that a sustained
        // stress spiral doesn't drag the reference point down with it.
        let sorted = recentHRVs.sorted()
        let p75Index = Int(Double(sorted.count - 1) * 0.75)
        let avgHRV = sorted[p75Index]
        guard avgHRV > 0 else { return nil }

        let score: Double
        if todayHRV >= avgHRV {
            score = 100.0
        } else {
            // Each 10% below average loses 20 points
            let percentBelow = (avgHRV - todayHRV) / avgHRV
            score = max(0, 100.0 - (percentBelow / 0.10) * 20.0)
        }

        let detail: String
        let ratio = todayHRV / avgHRV
        if ratio >= 1.05 {
            detail = String(format: "HRV %.0f ms — above your recent average", todayHRV)
        } else if ratio >= 0.95 {
            detail = String(format: "HRV %.0f ms — right at your baseline", todayHRV)
        } else if ratio >= 0.80 {
            detail = String(format: "HRV %.0f ms — a bit below your usual", todayHRV)
        } else if ratio >= 0.60 {
            detail = String(format: "HRV %.0f ms — noticeably lower than your recent trend", todayHRV)
        } else {
            detail = String(format: "HRV %.0f ms — well below your usual. Rest and sleep are the best levers — this typically rebounds within a day or two.", todayHRV)
        }

        return ReadinessPillar(
            type: .hrvTrend,
            score: score,
            weight: pillarWeights[.hrvTrend, default: 0.15],
            detail: detail
        )
    }

    // MARK: - Helpers

    /// Generates a friendly one-line summary based on the readiness level.
    private func buildSummary(
        level: ReadinessLevel,
        sleepHours: Double? = nil,
        pillars: [ReadinessPillar] = []
    ) -> String {
        // Sleep deprivation overrides — when sleep is critically low, the summary
        // MUST mention it regardless of the composite readiness level.
        if let hours = sleepHours {
            if hours < 1.0 {
                return "No sleep last night. Your body can't recover or perform safely — rest is the only option today."
            } else if hours < 3.0 {
                return String(format: "About %.0f hours of sleep — your body is asking for gentleness today. This is a rest day, not a push day. Even small moments of stillness help.", hours)
            } else if hours < 4.0 {
                return String(format: "Rough night — about %.0f hours of sleep. Your body needs rest today, not effort. Protect tonight's sleep window.", hours)
            } else if hours < 5.0 {
                return String(format: "About %.0f hours of sleep. Take it easy today — sleep is what will help most tonight.", hours)
            } else if hours < 6.0 && (level == .ready || level == .primed) {
                return String(format: "%.1f hours of sleep — not ideal. You may feel okay, but your body recovers better with 7+.", hours)
            }
        }

        // Default level-based summaries
        switch level {
        case .primed:
            return "You're firing on all cylinders today."
        case .ready:
            return "Looking solid — a good day to be active."
        case .moderate:
            return "Your body is doing okay. Listen to how you feel."
        case .recovering:
            return "Tough day for your body. One small thing that helps: an extra 30 minutes of sleep tonight."
        }
    }
}

// MARK: - Readiness Result

/// The output of a daily readiness computation.
public struct ReadinessResult: Codable, Equatable, Sendable {
    /// Composite readiness score (0-100).
    public let score: Int

    /// Categorical readiness level derived from the score.
    public let level: ReadinessLevel

    /// Per-pillar breakdown with individual scores and details.
    public let pillars: [ReadinessPillar]

    /// One-sentence friendly summary of the readiness state.
    public let summary: String

    public init(
        score: Int,
        level: ReadinessLevel,
        pillars: [ReadinessPillar],
        summary: String
    ) {
        self.score = score
        self.level = level
        self.pillars = pillars
        self.summary = summary
    }

    #if DEBUG
    /// Preview instance with representative data for SwiftUI previews.
    public static var preview: ReadinessResult {
        ReadinessResult(
            score: 78,
            level: .ready,
            pillars: [
                ReadinessPillar(
                    type: .sleep,
                    score: 95.0,
                    weight: 0.25,
                    detail: "7.5 hours — right in the sweet spot"
                ),
                ReadinessPillar(
                    type: .recovery,
                    score: 73.0,
                    weight: 0.25,
                    detail: "32 bpm drop — solid recovery"
                ),
                ReadinessPillar(
                    type: .stress,
                    score: 65.0,
                    weight: 0.20,
                    detail: "Moderate stress — pretty normal"
                ),
                ReadinessPillar(
                    type: .activityBalance,
                    score: 100.0,
                    weight: 0.15,
                    detail: "Averaging 32 min/day — great balance"
                ),
                ReadinessPillar(
                    type: .hrvTrend,
                    score: 60.0,
                    weight: 0.15,
                    detail: "HRV 42 ms — a bit below your usual"
                )
            ],
            summary: "Looking solid — a good day to be active."
        )
    }
    #endif
}

// MARK: - Readiness Level

/// Overall readiness category based on the composite score.
public enum ReadinessLevel: String, Codable, Equatable, Sendable {
    case primed       // 80-100
    case ready        // 60-79
    case moderate     // 40-59
    case recovering   // 0-39

    /// Creates a readiness level from a 0-100 score.
    public static func from(score: Int) -> ReadinessLevel {
        switch score {
        case 80...100: return .primed
        case 60..<80:  return .ready
        case 40..<60:  return .moderate
        default:       return .recovering
        }
    }

    /// User-facing display name.
    public var displayName: String {
        switch self {
        case .primed:     return "Primed"
        case .ready:      return "Ready"
        case .moderate:   return "Moderate"
        case .recovering: return "Recovering"
        }
    }

    /// SF Symbol icon for this readiness level.
    public var icon: String {
        switch self {
        case .primed:     return "bolt.fill"
        case .ready:      return "checkmark.circle.fill"
        case .moderate:   return "minus.circle.fill"
        case .recovering: return "moon.zzz.fill"
        }
    }

    /// Named color for SwiftUI tinting.
    public var colorName: String {
        switch self {
        case .primed:     return "readinessPrimed"
        case .ready:      return "readinessReady"
        case .moderate:   return "readinessModerate"
        case .recovering: return "readinessRecovering"
        }
    }
}

// MARK: - Readiness Pillar

/// A single pillar's contribution to the readiness score.
public struct ReadinessPillar: Codable, Equatable, Sendable {
    /// Which pillar this represents.
    public let type: ReadinessPillarType

    /// Score for this pillar (0-100).
    public let score: Double

    /// The weight used for this pillar in the composite.
    public let weight: Double

    /// Human-readable detail explaining the score.
    public let detail: String

    public init(
        type: ReadinessPillarType,
        score: Double,
        weight: Double,
        detail: String
    ) {
        self.type = type
        self.score = score
        self.weight = weight
        self.detail = detail
    }
}

// MARK: - Readiness Pillar Type

/// The five wellness pillars that feed the readiness score.
public enum ReadinessPillarType: String, Codable, Equatable, Sendable {
    case sleep
    case recovery
    case stress
    case activityBalance
    case hrvTrend

    /// User-facing display name.
    public var displayName: String {
        switch self {
        case .sleep:           return "Sleep Quality"
        case .recovery:        return "Recovery"
        case .stress:          return "Stress"
        case .activityBalance: return "Activity Balance"
        case .hrvTrend:        return "HRV Trend"
        }
    }

    /// SF Symbol icon for this pillar type.
    public var icon: String {
        switch self {
        case .sleep:           return "bed.double.fill"
        case .recovery:        return "heart.circle.fill"
        case .stress:          return "brain.head.profile"
        case .activityBalance: return "figure.walk"
        case .hrvTrend:        return "waveform.path.ecg"
        }
    }
}

// CoachingEngine.swift
// ThumpCore
//
// Generates personalized heart coaching messages that show users
// how following recommendations will improve their heart metrics.
// Combines current trend data, zone analysis, and nudge completion
// to project future metric improvements.
//
// This is the "hero feature" — the coaching loop that connects
// activity → heart metrics → visible improvement → motivation.
//
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Coaching Engine

/// Generates coaching messages that connect daily actions to heart
/// metric improvements, creating a visible feedback loop.
///
/// The engine analyzes:
/// 1. Current metric trends (improving, stable, declining)
/// 2. Activity patterns (zone distribution, consistency)
/// 3. Which recommendations the user has been following
/// 4. Projected improvements based on exercise science research
///
/// Then produces coaching messages like:
/// "Your RHR dropped 3 bpm this week from your walking habit.
///  Keep it up and you could see another 2 bpm drop in 2 weeks."
public struct CoachingEngine: Sendable {

    public init() {}

    // MARK: - Public API

    /// Generate a comprehensive coaching report from health data.
    ///
    /// - Parameters:
    ///   - current: Today's snapshot.
    ///   - history: 14-30 days of historical snapshots.
    ///   - streakDays: Current nudge completion streak.
    ///   - readiness: Optional readiness result for cross-module coherence.
    ///     When recovering, volume-praise messages are suppressed to avoid
    ///     contradicting the readiness engine's "take it easy" guidance.
    /// - Returns: A ``CoachingReport`` with messages and projections.
    public func generateReport(
        current: HeartSnapshot,
        history: [HeartSnapshot],
        streakDays: Int,
        readiness: ReadinessResult? = nil
    ) -> CoachingReport {
        let calendar = Calendar.current
        // Use snapshot date for deterministic replay, not wall-clock Date() (ENG-1)
        let today = calendar.startOfDay(for: current.date)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today

        let thisWeek = history.filter { $0.date >= weekAgo }
        let lastWeek = history.filter { $0.date >= twoWeeksAgo && $0.date < weekAgo }

        var insights: [CoachingInsight] = []  // mutable — coherence filter may rewrite entries

        // RHR trend analysis
        if let rhrInsight = analyzeRHRTrend(thisWeek: thisWeek, lastWeek: lastWeek, current: current) {
            insights.append(rhrInsight)
        }

        // HRV trend analysis
        if let hrvInsight = analyzeHRVTrend(thisWeek: thisWeek, lastWeek: lastWeek, current: current) {
            insights.append(hrvInsight)
        }

        // Activity → metric correlation
        if let activityInsight = analyzeActivityImpact(thisWeek: thisWeek, lastWeek: lastWeek) {
            insights.append(activityInsight)
        }

        // Recovery trend
        if let recoveryInsight = analyzeRecoveryTrend(thisWeek: thisWeek, lastWeek: lastWeek) {
            insights.append(recoveryInsight)
        }

        // VO2 Max progress
        if let vo2Insight = analyzeVO2Progress(history: history) {
            insights.append(vo2Insight)
        }

        // Zone distribution feedback
        let zoneEngine = HeartRateZoneEngine()
        if let zoneSummary = zoneEngine.weeklyZoneSummary(history: history, referenceDate: current.date) {
            insights.append(analyzeZoneBalance(zoneSummary: zoneSummary))
        }

        // Generate projections
        let projections = generateProjections(
            current: current,
            history: history,
            streakDays: streakDays
        )

        // Cross-module coherence: when readiness is recovering, suppress
        // activity volume praise that would contradict "take it easy" guidance.
        if let r = readiness, r.level == .recovering {
            insights = insights.map { insight in
                if insight.metric == .activity && insight.direction == .improving {
                    return CoachingInsight(
                        metric: insight.metric,
                        direction: .stable,
                        message: "Your activity has been consistent. On days like today, rest is more valuable than extra minutes.",
                        projection: insight.projection,
                        changeValue: insight.changeValue,
                        icon: insight.icon
                    )
                }
                return insight
            }
        }

        // Build the hero coaching message
        let heroMessage = buildHeroMessage(
            insights: insights,
            projections: projections,
            streakDays: streakDays,
            readiness: readiness
        )

        // Weekly score
        let weeklyScore = computeWeeklyProgressScore(
            thisWeek: thisWeek,
            lastWeek: lastWeek
        )

        return CoachingReport(
            heroMessage: heroMessage,
            insights: insights,
            projections: projections,
            weeklyProgressScore: weeklyScore,
            streakDays: streakDays
        )
    }

    // MARK: - RHR Analysis

    private func analyzeRHRTrend(
        thisWeek: [HeartSnapshot],
        lastWeek: [HeartSnapshot],
        current: HeartSnapshot
    ) -> CoachingInsight? {
        let thisWeekRHR = thisWeek.compactMap(\.restingHeartRate)
        let lastWeekRHR = lastWeek.compactMap(\.restingHeartRate)
        guard thisWeekRHR.count >= 3, lastWeekRHR.count >= 3 else { return nil }

        let thisAvg = thisWeekRHR.reduce(0, +) / Double(thisWeekRHR.count)
        let lastAvg = lastWeekRHR.reduce(0, +) / Double(lastWeekRHR.count)
        let change = thisAvg - lastAvg

        let direction: CoachingDirection
        let message: String
        let projection: String

        if change < -1.5 {
            direction = .improving
            message = String(format: "Your resting heart rate dropped %.0f bpm this week — that often tracks with good sleep and consistent activity.", abs(change))
            projection = "At this pace, you could see another 1-2 bpm improvement over the next two weeks."
        } else if change > 2.0 {
            direction = .declining
            message = String(format: "Your resting heart rate is up %.0f bpm from last week. This can happen with stress, poor sleep, or less activity.", change)
            projection = "Getting back to regular walks and good sleep should help bring it back down within a week."
        } else {
            direction = .stable
            message = String(format: "Your resting heart rate is steady at %.0f bpm — your body is in a consistent rhythm.", thisAvg)
            projection = "Adding a few more active minutes per day could help push it lower over time."
        }

        return CoachingInsight(
            metric: .restingHR,
            direction: direction,
            message: message,
            projection: projection,
            changeValue: change,
            icon: "heart.fill"
        )
    }

    // MARK: - HRV Analysis

    private func analyzeHRVTrend(
        thisWeek: [HeartSnapshot],
        lastWeek: [HeartSnapshot],
        current: HeartSnapshot
    ) -> CoachingInsight? {
        let thisWeekHRV = thisWeek.compactMap(\.hrvSDNN)
        let lastWeekHRV = lastWeek.compactMap(\.hrvSDNN)
        guard thisWeekHRV.count >= 3, lastWeekHRV.count >= 3 else { return nil }

        let thisAvg = thisWeekHRV.reduce(0, +) / Double(thisWeekHRV.count)
        let lastAvg = lastWeekHRV.reduce(0, +) / Double(lastWeekHRV.count)
        let change = thisAvg - lastAvg
        let percentChange = lastAvg > 0 ? (change / lastAvg) * 100 : 0

        let direction: CoachingDirection
        let message: String
        let projection: String

        if change > 3.0 {
            direction = .improving
            message = String(format: "Your HRV increased by %.0f ms (+%.0f%%) this week. Your nervous system is recovering better.", change, percentChange)
            projection = "Consistent sleep and moderate exercise can keep this trend going."
        } else if change < -5.0 {
            direction = .declining
            message = String(format: "Your HRV dropped %.0f ms this week. This often reflects stress, poor sleep, or pushing too hard.", abs(change))
            projection = "Focus on sleep quality and lighter activity for a few days to help your HRV bounce back."
        } else {
            direction = .stable
            message = String(format: "Your HRV is steady around %.0f ms. Your autonomic balance is consistent.", thisAvg)
            projection = "Regular breathing exercises and good sleep hygiene can gradually improve your baseline."
        }

        return CoachingInsight(
            metric: .hrv,
            direction: direction,
            message: message,
            projection: projection,
            changeValue: change,
            icon: "waveform.path.ecg"
        )
    }

    // MARK: - Activity Impact

    private func analyzeActivityImpact(
        thisWeek: [HeartSnapshot],
        lastWeek: [HeartSnapshot]
    ) -> CoachingInsight? {
        let thisWeekActive = thisWeek.map { ($0.walkMinutes ?? 0) + ($0.workoutMinutes ?? 0) }
        let lastWeekActive = lastWeek.map { ($0.walkMinutes ?? 0) + ($0.workoutMinutes ?? 0) }
        guard !thisWeekActive.isEmpty, !lastWeekActive.isEmpty else { return nil }

        let thisAvg = thisWeekActive.reduce(0, +) / Double(thisWeekActive.count)
        let lastAvg = lastWeekActive.reduce(0, +) / Double(lastWeekActive.count)
        let change = thisAvg - lastAvg

        // Correlate with RHR change
        let thisRHR = thisWeek.compactMap(\.restingHeartRate)
        let lastRHR = lastWeek.compactMap(\.restingHeartRate)
        let rhrChange = (!thisRHR.isEmpty && !lastRHR.isEmpty)
            ? (thisRHR.reduce(0, +) / Double(thisRHR.count)) - (lastRHR.reduce(0, +) / Double(lastRHR.count))
            : 0.0

        let direction: CoachingDirection
        let message: String
        let projection: String

        if change > 5 && rhrChange < -1 {
            direction = .improving
            message = String(format: "You added %.0f more active minutes per day this week, and your resting HR dropped %.0f bpm. Your effort is paying off!", change, abs(rhrChange))
            projection = "Research shows 4-6 weeks of consistent activity can lower RHR by 5-10 bpm."
        } else if change > 5 {
            direction = .improving
            message = String(format: "Great job — you're averaging %.0f more active minutes per day than last week.", change)
            projection = "Keep this up for 2-3 more weeks and you'll likely see your heart metrics improve."
        } else if change < -10 {
            direction = .declining
            message = String(format: "Your activity dropped by about %.0f minutes per day this week.", abs(change))
            projection = "Even 15-20 minutes of brisk walking daily can maintain your cardiovascular gains."
        } else {
            direction = .stable
            message = String(format: "You're averaging about %.0f active minutes per day — consistent effort builds lasting fitness.", thisAvg)
            projection = "Aim for 30+ minutes most days for optimal heart health benefits."
        }

        return CoachingInsight(
            metric: .activity,
            direction: direction,
            message: message,
            projection: projection,
            changeValue: change,
            icon: "figure.walk"
        )
    }

    // MARK: - Recovery Trend

    private func analyzeRecoveryTrend(
        thisWeek: [HeartSnapshot],
        lastWeek: [HeartSnapshot]
    ) -> CoachingInsight? {
        let thisRec = thisWeek.compactMap(\.recoveryHR1m)
        let lastRec = lastWeek.compactMap(\.recoveryHR1m)
        guard thisRec.count >= 2, lastRec.count >= 2 else { return nil }

        let thisAvg = thisRec.reduce(0, +) / Double(thisRec.count)
        let lastAvg = lastRec.reduce(0, +) / Double(lastRec.count)
        let change = thisAvg - lastAvg

        let direction: CoachingDirection = change > 2 ? .improving : (change < -3 ? .declining : .stable)

        let message: String
        if change > 2 {
            message = String(format: "Your heart recovery improved by %.0f bpm this week. Your cardiovascular system is adapting well to exercise.", change)
        } else if change < -3 {
            message = String(format: "Your heart recovery slowed by %.0f bpm. This may indicate fatigue — consider a lighter training day.", abs(change))
        } else {
            message = String(format: "Your heart recovery is steady at %.0f bpm drop in the first minute after exercise.", thisAvg)
        }

        return CoachingInsight(
            metric: .recovery,
            direction: direction,
            message: message,
            projection: "Regular aerobic exercise is the best way to improve heart rate recovery over time.",
            changeValue: change,
            icon: "heart.circle.fill"
        )
    }

    // MARK: - VO2 Progress

    private func analyzeVO2Progress(history: [HeartSnapshot]) -> CoachingInsight? {
        let vo2Values = history.compactMap(\.vo2Max)
        guard vo2Values.count >= 5 else { return nil }

        let recent5 = Array(vo2Values.suffix(5))
        let older5 = vo2Values.count >= 10 ? Array(vo2Values.suffix(10).prefix(5)) : nil
        let recentAvg = recent5.reduce(0, +) / Double(recent5.count)

        guard let older = older5 else {
            return CoachingInsight(
                metric: .vo2Max,
                direction: .stable,
                message: String(format: "Your aerobic fitness is at %.1f — a measure of how efficiently your body uses oxygen during effort. A few more weeks of data will reveal how it's trending for you.", recentAvg),
                projection: "Regular cardio sessions — even 30-minute brisk walks — tend to improve aerobic fitness over 6–8 weeks.",
                changeValue: 0,
                icon: "lungs.fill"
            )
        }

        let olderAvg = older.reduce(0, +) / Double(older.count)
        let change = recentAvg - olderAvg

        let direction: CoachingDirection = change > 0.5 ? .improving : (change < -0.5 ? .declining : .stable)
        let message: String
        if change > 0.5 {
            message = String(format: "Your aerobic fitness has improved by %.1f points compared to your recent baseline — a meaningful shift in the right direction.", change)
        } else if change < -0.5 {
            message = String(format: "Your aerobic fitness has dipped %.1f points from your recent baseline. Consistent moderate cardio tends to bring it back over a few weeks.", abs(change))
        } else {
            message = String(format: "Your aerobic fitness is holding steady at %.1f, in line with your recent baseline.", recentAvg)
        }

        return CoachingInsight(
            metric: .vo2Max,
            direction: direction,
            message: message,
            projection: "Consistent moderate-to-hard cardio sessions tend to improve aerobic fitness over 6–8 weeks.",
            changeValue: change,
            icon: "lungs.fill"
        )
    }

    // MARK: - Zone Balance

    private func analyzeZoneBalance(zoneSummary: WeeklyZoneSummary) -> CoachingInsight {
        let ahaPercent = Int(zoneSummary.ahaCompletion * 100)
        let direction: CoachingDirection
        let message: String

        if zoneSummary.ahaCompletion >= 1.0 {
            direction = .improving
            message = "You met the AHA weekly activity guideline — \(ahaPercent)% of the 150-minute target. Your heart thanks you!"
        } else if zoneSummary.ahaCompletion >= 0.6 {
            direction = .stable
            let remaining = Int((1.0 - zoneSummary.ahaCompletion) * 150)
            message = "You're at \(ahaPercent)% of the AHA weekly guideline. About \(remaining) more minutes of moderate activity to hit 100%."
        } else {
            direction = .declining
            message = "You're at \(ahaPercent)% of the AHA weekly guideline. Try adding a daily 20-minute brisk walk to close the gap."
        }

        return CoachingInsight(
            metric: .zoneBalance,
            direction: direction,
            message: message,
            projection: "The AHA recommends 150+ minutes of moderate activity per week for heart health.",
            changeValue: zoneSummary.ahaCompletion * 100,
            icon: "chart.bar.fill"
        )
    }

    // MARK: - Projections

    private func generateProjections(
        current: HeartSnapshot,
        history: [HeartSnapshot],
        streakDays: Int
    ) -> [CoachingProjection] {
        var projections: [CoachingProjection] = []

        // RHR projection based on activity trend
        if let rhr = current.restingHeartRate {
            let activeMinAvg = history.suffix(7)
                .map { ($0.walkMinutes ?? 0) + ($0.workoutMinutes ?? 0) }
                .reduce(0, +) / max(1, Double(min(history.count, 7)))

            // Research: consistent 30+ min/day moderate exercise →
            // 5-10 bpm RHR reduction over 8-12 weeks
            let weeklyDropRate: Double = activeMinAvg >= 30 ? 0.8 : (activeMinAvg >= 15 ? 0.3 : 0.0)
            let projected4Week = max(45, rhr - weeklyDropRate * 4)

            if weeklyDropRate > 0 {
                projections.append(CoachingProjection(
                    metric: .restingHR,
                    currentValue: rhr,
                    projectedValue: projected4Week,
                    timeframeWeeks: 4,
                    confidence: activeMinAvg >= 30 ? .high : .moderate,
                    description: String(format: "Your resting HR could reach %.0f bpm in 4 weeks if you keep up your current activity.", projected4Week)
                ))
            }
        }

        // HRV projection
        if let hrv = current.hrvSDNN {
            let sleepAvg = history.suffix(7).compactMap(\.sleepHours).reduce(0, +)
                / max(1, Double(history.suffix(7).compactMap(\.sleepHours).count))
            let improvementRate: Double = sleepAvg >= 7.0 ? 1.5 : 0.5
            let projected4Week = hrv + improvementRate * 4

            projections.append(CoachingProjection(
                metric: .hrv,
                currentValue: hrv,
                projectedValue: projected4Week,
                timeframeWeeks: 4,
                confidence: sleepAvg >= 7.0 ? .moderate : .low,
                description: String(format: "With good sleep and regular exercise, your HRV could reach %.0f ms in 4 weeks.", projected4Week)
            ))
        }

        return projections
    }

    // MARK: - Hero Message

    private func buildHeroMessage(
        insights: [CoachingInsight],
        projections: [CoachingProjection],
        streakDays: Int,
        readiness: ReadinessResult? = nil
    ) -> String {
        // Cross-module coherence: when recovering, the hero message must
        // align with the readiness engine's "take it easy" guidance.
        // Never celebrate volume or push "keep going" on a recovery day.
        if let r = readiness, r.level == .recovering {
            return "Your body is asking for rest today. The best thing you can do right now is recover — the gains come after."
        }

        let improving = insights.filter { $0.direction == .improving }
        let declining = insights.filter { $0.direction == .declining }

        if !improving.isEmpty && declining.isEmpty {
            let metricNames = improving.prefix(2).map { $0.metric.displayName }.joined(separator: " and ")
            if streakDays >= 7 {
                return "Your \(metricNames) \(improving.count == 1 ? "is" : "are") improving — your \(streakDays)-day streak is making a real difference!"
            }
            return "Your \(metricNames) \(improving.count == 1 ? "is" : "are") trending in the right direction. Keep going!"
        }

        if !declining.isEmpty && improving.isEmpty {
            return "Some metrics shifted this week. A few small changes — more walking, better sleep — can turn things around quickly."
        }

        if !improving.isEmpty && !declining.isEmpty {
            let bestMetric = improving.first!.metric.displayName
            return "Your \(bestMetric) is improving! Focus on sleep and recovery to bring the other metrics along."
        }

        if streakDays >= 3 {
            return "You're building a solid \(streakDays)-day streak. Consistency is the key to lasting heart health improvements."
        }

        return "Your heart metrics are steady. Small, consistent efforts compound into big improvements over time."
    }

    // MARK: - Weekly Progress Score

    private func computeWeeklyProgressScore(
        thisWeek: [HeartSnapshot],
        lastWeek: [HeartSnapshot]
    ) -> Int {
        var score: Double = 50 // Baseline: neutral
        var signals = 0

        // RHR improvement
        let thisRHR = thisWeek.compactMap(\.restingHeartRate)
        let lastRHR = lastWeek.compactMap(\.restingHeartRate)
        if thisRHR.count >= 3 && lastRHR.count >= 3 {
            let change = (thisRHR.reduce(0, +) / Double(thisRHR.count))
                - (lastRHR.reduce(0, +) / Double(lastRHR.count))
            score += max(-15, min(15, -change * 5))
            signals += 1
        }

        // HRV improvement
        let thisHRV = thisWeek.compactMap(\.hrvSDNN)
        let lastHRV = lastWeek.compactMap(\.hrvSDNN)
        if thisHRV.count >= 3 && lastHRV.count >= 3 {
            let change = (thisHRV.reduce(0, +) / Double(thisHRV.count))
                - (lastHRV.reduce(0, +) / Double(lastHRV.count))
            score += max(-15, min(15, change * 2))
            signals += 1
        }

        // Activity consistency
        let activeDays = thisWeek.filter {
            ($0.walkMinutes ?? 0) + ($0.workoutMinutes ?? 0) >= 15
        }.count
        score += Double(activeDays) * 3

        // Sleep quality
        let goodSleepDays = thisWeek.compactMap(\.sleepHours).filter { $0 >= 7.0 && $0 <= 9.0 }.count
        score += Double(goodSleepDays) * 2

        return Int(max(0, min(100, score)))
    }
}

// MARK: - Coaching Report

/// Complete coaching report with insights, projections, and hero message.
public struct CoachingReport: Codable, Equatable, Sendable {
    /// The primary motivational coaching message.
    public let heroMessage: String
    /// Per-metric insights showing what's improving/declining.
    public let insights: [CoachingInsight]
    /// Projected metric improvements based on current trends.
    public let projections: [CoachingProjection]
    /// Weekly progress score (0-100).
    public let weeklyProgressScore: Int
    /// Current nudge completion streak.
    public let streakDays: Int
}

// MARK: - Coaching Insight

/// A single metric's coaching insight.
public struct CoachingInsight: Codable, Equatable, Sendable {
    public let metric: CoachingMetricType
    public let direction: CoachingDirection
    public let message: String
    public let projection: String
    public let changeValue: Double
    public let icon: String
}

// MARK: - Coaching Projection

/// Projected future metric value based on current behavior.
public struct CoachingProjection: Codable, Equatable, Sendable {
    public let metric: CoachingMetricType
    public let currentValue: Double
    public let projectedValue: Double
    public let timeframeWeeks: Int
    public let confidence: ProjectionConfidence
    public let description: String
}

// MARK: - Supporting Types

public enum CoachingMetricType: String, Codable, Equatable, Sendable {
    case restingHR
    case hrv
    case activity
    case recovery
    case vo2Max
    case zoneBalance

    public var displayName: String {
        switch self {
        case .restingHR:    return "resting heart rate"
        case .hrv:          return "HRV"
        case .activity:     return "activity level"
        case .recovery:     return "heart recovery"
        case .vo2Max:       return "cardio fitness"
        case .zoneBalance:  return "zone balance"
        }
    }
}

public enum CoachingDirection: String, Codable, Equatable, Sendable {
    case improving
    case stable
    case declining
}

public enum ProjectionConfidence: String, Codable, Equatable, Sendable {
    case high
    case moderate
    case low
}

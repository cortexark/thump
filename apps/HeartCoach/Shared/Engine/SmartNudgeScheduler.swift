// SmartNudgeScheduler.swift
// ThumpCore
//
// Learns user patterns (bedtime, wake time, stress rhythms) and
// generates contextually timed nudges. Adapts weekday vs weekend
// timing, detects late wake-ups for check-ins, and triggers journal
// prompts on high-stress days.
//
// Platforms: iOS 17+, watchOS 10+

import Foundation

// MARK: - Smart Nudge Scheduler

/// Analyzes user behavior patterns to generate contextually
/// appropriate and well-timed nudges.
///
/// The scheduler learns:
/// - **Bedtime patterns**: When the user typically goes to sleep
///   (separately for weekdays and weekends)
/// - **Wake patterns**: When the user typically wakes up
/// - **Stress rhythms**: Time-of-day stress patterns
///
/// Based on these patterns, it generates:
/// - Pre-bedtime wind-down nudges timed ~30 min before learned bedtime
/// - Morning check-in nudges when the user wakes later than usual
/// - Journal prompts on high-stress days
/// - Breathing exercise prompts on the Apple Watch when stress rises
public struct SmartNudgeScheduler: Sendable {

    // MARK: - Configuration

    /// Minutes before bedtime to send the wind-down nudge.
    private let bedtimeNudgeLeadMinutes: Int = 30

    /// How many hours past typical wake time counts as "late".
    private let lateWakeThresholdHours: Double = 1.5

    /// Stress score threshold for triggering journal prompt.
    private let journalStressThreshold: Double = 65.0

    /// Stress score threshold for triggering breath prompt on watch.
    private let breathPromptThreshold: Double = 60.0

    /// Minimum observations before trusting a pattern.
    private let minObservations: Int = 3

    public init() {}

    // MARK: - Sleep Pattern Learning

    /// Learn sleep patterns from historical snapshot data.
    ///
    /// Analyzes sleep hours and timestamps to estimate typical
    /// bedtime and wake time for each day of the week.
    ///
    /// - Parameter snapshots: Historical snapshots with sleep data.
    /// - Returns: Array of 7 ``SleepPattern`` values (Sun-Sat).
    public func learnSleepPatterns(
        from snapshots: [HeartSnapshot]
    ) -> [SleepPattern] {
        let calendar = Calendar.current

        // Group snapshots by day of week
        var bedtimesByDay: [Int: [Int]] = [:]
        var waketimesByDay: [Int: [Int]] = [:]

        for snapshot in snapshots {
            guard let sleepHours = snapshot.sleepHours,
                  sleepHours > 0 else { continue }

            let dayOfWeek = calendar.component(.weekday, from: snapshot.date)

            // Estimate bedtime: if they slept N hours and the snapshot
            // is for a given day, bedtime was roughly (24 - sleepHours)
            // adjusted for typical patterns
            let estimatedWakeHour = min(12, max(5, Int(7.0 + (sleepHours - 7.0) * 0.3)))
            let estimatedBedtimeHour = max(20, min(24, estimatedWakeHour + 24 - Int(sleepHours)))
            let normalizedBedtime = estimatedBedtimeHour >= 24
                ? estimatedBedtimeHour - 24
                : estimatedBedtimeHour

            bedtimesByDay[dayOfWeek, default: []].append(normalizedBedtime)
            waketimesByDay[dayOfWeek, default: []].append(estimatedWakeHour)
        }

        // Build patterns for each day of the week
        return (1...7).map { day in
            let bedtimes = bedtimesByDay[day] ?? []
            let waketimes = waketimesByDay[day] ?? []

            let avgBedtime = bedtimes.isEmpty
                ? (day == 1 || day == 7 ? 23 : 22)
                : bedtimes.reduce(0, +) / bedtimes.count

            let avgWake = waketimes.isEmpty
                ? (day == 1 || day == 7 ? 8 : 7)
                : waketimes.reduce(0, +) / waketimes.count

            return SleepPattern(
                dayOfWeek: day,
                typicalBedtimeHour: avgBedtime,
                typicalWakeHour: avgWake,
                observationCount: bedtimes.count
            )
        }
    }

    // MARK: - Nudge Timing

    /// Compute the optimal nudge delivery hour for today based on
    /// learned sleep patterns.
    ///
    /// - Weekday bedtime nudge: 30 min before typical weekday bedtime
    /// - Weekend bedtime nudge: 30 min before typical weekend bedtime
    ///
    /// - Parameters:
    ///   - patterns: Learned sleep patterns (from `learnSleepPatterns`).
    ///   - date: The date to compute nudge timing for.
    /// - Returns: The hour (0-23) to deliver the bedtime nudge.
    public func bedtimeNudgeHour(
        patterns: [SleepPattern],
        for date: Date
    ) -> Int {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date)

        guard let pattern = patterns.first(where: { $0.dayOfWeek == dayOfWeek }),
              pattern.observationCount >= minObservations else {
            // Default: 9:30 PM on weekdays, 10:30 PM on weekends
            let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
            return isWeekend ? 22 : 21
        }

        // Nudge 30 min before bedtime (round to the hour before)
        let nudgeHour = pattern.typicalBedtimeHour > 0
            ? pattern.typicalBedtimeHour - 1
            : 22

        return max(20, min(23, nudgeHour))
    }

    // MARK: - Late Wake Detection

    /// Check if the user woke up later than usual today.
    ///
    /// Compares today's estimated wake time against the learned
    /// pattern for this day of week.
    ///
    /// - Parameters:
    ///   - todaySnapshot: Today's health snapshot.
    ///   - patterns: Learned sleep patterns.
    /// - Returns: `true` if the user appears to have woken late.
    public func isLateWake(
        todaySnapshot: HeartSnapshot,
        patterns: [SleepPattern]
    ) -> Bool {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: todaySnapshot.date)

        guard let pattern = patterns.first(where: { $0.dayOfWeek == dayOfWeek }),
              pattern.observationCount >= minObservations,
              let sleepHours = todaySnapshot.sleepHours else {
            return false
        }

        // If they slept significantly more than usual, they likely woke late
        let typicalSleep = Double(
            pattern.typicalWakeHour - pattern.typicalBedtimeHour + 24
        ).truncatingRemainder(dividingBy: 24)

        return sleepHours > typicalSleep + lateWakeThresholdHours
    }

    // MARK: - Context-Aware Nudge Selection

    /// Generate a context-aware nudge based on current stress, patterns,
    /// and time of day.
    ///
    /// Decision priority:
    /// 1. High stress day → journal prompt
    /// 2. Stress rising → breath prompt (for Apple Watch)
    /// 3. Late wake → morning check-in
    /// 4. Near bedtime → wind-down nudge
    /// 5. Default → standard nudge
    ///
    /// - Parameters:
    ///   - stressPoints: Recent stress data points.
    ///   - trendDirection: Current stress trend direction.
    ///   - todaySnapshot: Today's snapshot data.
    ///   - patterns: Learned sleep patterns.
    ///   - currentHour: Current hour of day (0-23).
    /// - Returns: A ``SmartNudgeAction`` describing what to do.
    public func recommendAction(
        stressPoints: [StressDataPoint],
        trendDirection: StressTrendDirection,
        todaySnapshot: HeartSnapshot?,
        patterns: [SleepPattern],
        currentHour: Int
    ) -> SmartNudgeAction {
        // 1. High stress day → journal
        if let todayStress = stressPoints.last,
           todayStress.score >= journalStressThreshold {
            return .journalPrompt(
                JournalPrompt(
                    question: "It's been a full day. "
                        + "What's been on your mind?",
                    context: "Your stress has been running higher "
                        + "than usual today. Writing things down "
                        + "can sometimes help.",
                    icon: "book.fill"
                )
            )
        }

        // 2. Stress rising → breath prompt on watch
        if trendDirection == .rising {
            return .breatheOnWatch(
                DailyNudge(
                    category: .breathe,
                    title: "Take a Breath",
                    description: "Your stress has been climbing. "
                        + "A quick breathing exercise on your "
                        + "Apple Watch might help you reset.",
                    durationMinutes: 3,
                    icon: "wind"
                )
            )
        }

        // 3. Late wake → morning check-in
        if let snapshot = todaySnapshot,
           isLateWake(todaySnapshot: snapshot, patterns: patterns),
           currentHour < 12 {
            return .morningCheckIn(
                "You slept in a bit today. How are you feeling?"
            )
        }

        // 4. Near bedtime → wind-down
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: Date())
        if let pattern = patterns.first(where: { $0.dayOfWeek == dayOfWeek }),
           currentHour >= pattern.typicalBedtimeHour - 1,
           currentHour <= pattern.typicalBedtimeHour {
            return .bedtimeWindDown(
                DailyNudge(
                    category: .rest,
                    title: "Time to Wind Down",
                    description: "Your usual bedtime is coming up. "
                        + "Maybe start putting screens away and "
                        + "do something relaxing.",
                    durationMinutes: nil,
                    icon: "moon.fill"
                )
            )
        }

        // 5. Default
        return .standardNudge
    }

    // MARK: - Multiple Actions

    /// Generate multiple context-aware actions ranked by relevance.
    ///
    /// Unlike `recommendAction()` which returns only the top-priority
    /// action, this method collects all applicable actions so the UI
    /// can present several data-driven suggestions at once.
    ///
    /// - Parameters: Same as `recommendAction()`.
    /// - Returns: Array of 1-3 applicable ``SmartNudgeAction`` values,
    ///   ordered by priority (highest first). Never empty — at minimum
    ///   returns `.standardNudge`.
    public func recommendActions(
        stressPoints: [StressDataPoint],
        trendDirection: StressTrendDirection,
        todaySnapshot: HeartSnapshot?,
        patterns: [SleepPattern],
        currentHour: Int
    ) -> [SmartNudgeAction] {
        var actions: [SmartNudgeAction] = []

        // 1. High stress → journal prompt
        if let todayStress = stressPoints.last,
           todayStress.score >= journalStressThreshold {
            actions.append(
                .journalPrompt(
                    JournalPrompt(
                        question: "It's been a full day. "
                            + "What's been on your mind?",
                        context: "Your stress has been running higher "
                            + "than usual today. Writing things down "
                            + "can sometimes help.",
                        icon: "book.fill"
                    )
                )
            )
        }

        // 2. Stress rising → breath prompt on watch
        if trendDirection == .rising {
            actions.append(
                .breatheOnWatch(
                    DailyNudge(
                        category: .breathe,
                        title: "Take a Breath",
                        description: "Your stress has been climbing. "
                            + "A quick breathing exercise on your "
                            + "Apple Watch might help you reset.",
                        durationMinutes: 3,
                        icon: "wind"
                    )
                )
            )
        }

        // 3. Late wake → morning check-in
        if let snapshot = todaySnapshot,
           isLateWake(todaySnapshot: snapshot, patterns: patterns),
           currentHour < 12 {
            actions.append(
                .morningCheckIn(
                    "You slept in a bit today. How are you feeling?"
                )
            )
        }

        // 4. Near bedtime → wind-down
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: Date())
        if let pattern = patterns.first(where: { $0.dayOfWeek == dayOfWeek }),
           currentHour >= pattern.typicalBedtimeHour - 1,
           currentHour <= pattern.typicalBedtimeHour {
            actions.append(
                .bedtimeWindDown(
                    DailyNudge(
                        category: .rest,
                        title: "Time to Wind Down",
                        description: "Your usual bedtime is coming up. "
                            + "Maybe start putting screens away and "
                            + "do something relaxing.",
                        durationMinutes: nil,
                        icon: "moon.fill"
                    )
                )
            )
        }

        // 5. Activity-based suggestions from today's data
        if let snapshot = todaySnapshot, actions.count < 3 {
            let walkMin = snapshot.walkMinutes ?? 0
            let workoutMin = snapshot.workoutMinutes ?? 0
            if walkMin + workoutMin < 10 {
                actions.append(
                    .activitySuggestion(
                        DailyNudge(
                            category: .walk,
                            title: "Get Moving",
                            description: "You haven't logged much activity today. "
                                + "Even a short walk can lift your mood and "
                                + "ease tension.",
                            durationMinutes: 10,
                            icon: "figure.walk"
                        )
                    )
                )
            }
        }

        // 6. Sleep-based suggestion
        if let snapshot = todaySnapshot,
           let sleep = snapshot.sleepHours,
           sleep < 6.5,
           actions.count < 3 {
            actions.append(
                .restSuggestion(
                    DailyNudge(
                        category: .rest,
                        title: "Prioritize Sleep Tonight",
                        description: "You logged \(String(format: "%.1f", sleep)) "
                            + "hours last night. An earlier bedtime could "
                            + "help your body recover.",
                        durationMinutes: nil,
                        icon: "bed.double.fill"
                    )
                )
            )
        }

        // Always return at least standard nudge
        if actions.isEmpty {
            actions.append(.standardNudge)
        }

        return Array(actions.prefix(3))
    }
}

// MARK: - Smart Nudge Action

/// The recommended action from the SmartNudgeScheduler.
public enum SmartNudgeAction: Sendable {
    /// Prompt the user to journal about their day.
    case journalPrompt(JournalPrompt)

    /// Send a breathing exercise prompt to Apple Watch.
    case breatheOnWatch(DailyNudge)

    /// Ask the user how they're feeling (late wake detection).
    case morningCheckIn(String)

    /// Send a wind-down nudge before bedtime.
    case bedtimeWindDown(DailyNudge)

    /// Suggest an activity based on low movement data.
    case activitySuggestion(DailyNudge)

    /// Suggest rest/sleep based on low sleep data.
    case restSuggestion(DailyNudge)

    /// Use the standard nudge selection logic.
    case standardNudge
}

// InsightsViewModel.swift
// Thump iOS
//
// View model for the Insights tab. Loads correlation analysis results
// from CorrelationEngine and generates weekly reports from historical
// assessment data. Provides the data layer for insight cards and the
// weekly summary view.
// Platforms: iOS 17+

import Foundation
import Combine

// MARK: - Insights View Model

/// View model for the Insights screen that displays correlation cards
/// and weekly summary reports.
///
/// Uses `CorrelationEngine` to analyze relationships between activity
/// factors and heart health metrics, and generates `WeeklyReport`
/// summaries from historical assessment data.
@MainActor
final class InsightsViewModel: ObservableObject {

    // MARK: - Published State

    /// Correlation results between activity factors and heart metrics.
    @Published var correlations: [CorrelationResult] = []

    /// The most recent weekly summary report.
    @Published var weeklyReport: WeeklyReport?

    /// Personalised action plan derived from the week's data.
    @Published var actionPlan: WeeklyActionPlan?

    /// Whether insights data is being loaded.
    @Published var isLoading: Bool = true

    /// Human-readable error message if loading failed.
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private var healthKitService: HealthKitService
    private let correlationEngine: CorrelationEngine
    private var localStore: LocalStore
    /// Optional connectivity service for pushing the action plan to the Apple Watch.
    weak var connectivityService: ConnectivityService?

    // MARK: - Initialization

    /// Creates a new InsightsViewModel with the given dependencies.
    ///
    /// - Parameters:
    ///   - healthKitService: The service used to fetch historical data.
    ///   - localStore: The local persistence store for nudge completion tracking.
    init(
        healthKitService: HealthKitService = HealthKitService(),
        localStore: LocalStore = LocalStore()
    ) {
        self.healthKitService = healthKitService
        self.correlationEngine = CorrelationEngine()
        self.localStore = localStore
    }

    /// Binds shared service dependencies (PERF-4).
    func bind(healthKitService: HealthKitService, localStore: LocalStore) {
        self.healthKitService = healthKitService
        self.localStore = localStore
    }

    // MARK: - Public API

    /// Loads correlation insights and weekly report data.
    ///
    /// Fetches 30 days of history from HealthKit, runs the correlation
    /// engine, and generates a weekly report from the last 7 days.
    func loadInsights() async {
        isLoading = true
        errorMessage = nil

        do {
            if !healthKitService.isAuthorized {
                try await healthKitService.requestAuthorization()
            }

            // Fetch 30 days of history for meaningful correlations
            let history: [HeartSnapshot]
            do {
                history = try await healthKitService.fetchHistory(days: 30)
            } catch {
                #if targetEnvironment(simulator)
                history = MockData.mockHistory(days: 30)
                #else
                history = []
                #endif
            }

            // Run correlation analysis
            let results = correlationEngine.analyze(history: history)
            correlations = results.sorted { abs($0.correlationStrength) > abs($1.correlationStrength) }

            // Generate weekly report from the last 7 days
            let weekHistory = Array(history.suffix(7))
            let engine = ConfigService.makeDefaultEngine()

            // Compute assessments for each day in the week
            var weekAssessments: [HeartAssessment] = []
            for (index, snapshot) in weekHistory.enumerated() {
                let priorHistory = Array(history.prefix(max(0, history.count - 7 + index)))
                let assessment = engine.assess(
                    history: priorHistory,
                    current: snapshot,
                    feedback: nil
                )
                weekAssessments.append(assessment)
            }

            let report = generateWeeklyReport(
                from: weekHistory,
                assessments: weekAssessments
            )
            weeklyReport = report

            let plan = generateActionPlan(
                from: weekHistory,
                assessments: weekAssessments,
                report: report
            )
            actionPlan = plan

            // Push to Apple Watch if paired and a connectivity service is available.
            if let connectivity = connectivityService {
                let watchPlan = buildWatchActionPlan(from: plan, report: report, assessments: weekAssessments)
                connectivity.sendActionPlan(watchPlan)
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Generates a `WeeklyReport` from a week of snapshots and their assessments.
    ///
    /// Computes the average cardio score, determines the trend direction
    /// by comparing first-half to second-half averages, identifies the
    /// top insight from correlations, and calculates the nudge completion rate.
    ///
    /// - Parameters:
    ///   - history: The week's `HeartSnapshot` array (ordered oldest-first).
    ///   - assessments: Corresponding `HeartAssessment` for each snapshot.
    /// - Returns: A populated `WeeklyReport`.
    func generateWeeklyReport(
        from history: [HeartSnapshot],
        assessments: [HeartAssessment]
    ) -> WeeklyReport {
        let calendar = Calendar.current

        // Determine week bounds
        let weekStart = history.first?.date ?? calendar.startOfDay(for: Date())
        let weekEnd = history.last?.date ?? calendar.startOfDay(for: Date())

        // Compute average cardio score (excluding nil values)
        let cardioScores = assessments.compactMap(\.cardioScore)
        let avgCardioScore: Double? = cardioScores.isEmpty
            ? nil
            : cardioScores.reduce(0, +) / Double(cardioScores.count)

        // Determine trend direction by comparing first half to second half
        let trendDirection = computeTrendDirection(scores: cardioScores)

        // Select the top insight from correlations or generate a default
        let topInsight = selectTopInsight(
            correlations: correlations,
            assessments: assessments
        )

        // Compute nudge completion rate from explicit user completion records (CR-003).
        // Only counts days where the user actually tapped "complete" on a nudge,
        // not days where an assessment was auto-stored by refresh().
        let completionDates = localStore.profile.nudgeCompletionDates
        let weekDates = Set(history.map {
            String(ISO8601DateFormatter().string(from: calendar.startOfDay(for: $0.date)).prefix(10))
        })
        let completedCount = weekDates.intersection(completionDates).count
        let nudgeCompletionRate = weekDates.isEmpty
            ? 0.0
            : min(Double(completedCount) / Double(weekDates.count), 1.0)

        return WeeklyReport(
            weekStart: weekStart,
            weekEnd: weekEnd,
            avgCardioScore: avgCardioScore,
            trendDirection: trendDirection,
            topInsight: topInsight,
            nudgeCompletionRate: nudgeCompletionRate
        )
    }

    // MARK: - Computed Properties

    /// Returns correlations sorted by absolute strength (strongest first).
    var sortedCorrelations: [CorrelationResult] {
        correlations.sorted { abs($0.correlationStrength) > abs($1.correlationStrength) }
    }

    /// Returns only correlations with at least moderate strength (|r| >= 0.3).
    var significantCorrelations: [CorrelationResult] {
        correlations.filter { abs($0.correlationStrength) >= 0.3 }
    }

    /// Whether there is sufficient data to show meaningful insights.
    var hasInsights: Bool {
        !correlations.isEmpty || weeklyReport != nil
    }

    // MARK: - Private Helpers

    /// Computes the weekly trend direction from an array of cardio scores.
    ///
    /// Compares the average of the first half to the second half.
    /// - Parameter scores: Array of cardio fitness scores.
    /// - Returns: The trend direction (.up, .flat, or .down).
    private func computeTrendDirection(
        scores: [Double]
    ) -> WeeklyReport.TrendDirection {
        guard scores.count >= 4 else { return .flat }

        let midpoint = scores.count / 2
        let firstHalf = Array(scores.prefix(midpoint))
        let secondHalf = Array(scores.suffix(scores.count - midpoint))

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        let difference = secondAvg - firstAvg
        let threshold = 2.0 // Minimum score change to indicate a trend

        if difference > threshold {
            return .up
        } else if difference < -threshold {
            return .down
        } else {
            return .flat
        }
    }

    /// Builds a personalised `WeeklyActionPlan` from a week of snapshots and assessments.
    ///
    /// Produces one action item per meaningful category based on the user's
    /// actual metric averages for the week.
    private func generateActionPlan(
        from history: [HeartSnapshot],
        assessments: [HeartAssessment],
        report: WeeklyReport
    ) -> WeeklyActionPlan {
        var items: [WeeklyActionItem] = []

        // Sleep action
        let sleepValues = history.compactMap(\.sleepHours)
        let avgSleep = sleepValues.isEmpty ? nil : sleepValues.reduce(0, +) / Double(sleepValues.count)
        let sleepItem = buildSleepAction(avgSleep: avgSleep)
        items.append(sleepItem)

        // Breathe / wind-down action
        let stressDays = assessments.filter { $0.stressFlag }.count
        let breatheItem = buildBreatheAction(stressDays: stressDays, totalDays: assessments.count)
        items.append(breatheItem)

        // Activity action
        let walkValues = history.compactMap(\.walkMinutes)
        let workoutValues = history.compactMap(\.workoutMinutes)
        let avgActive = walkValues.isEmpty && workoutValues.isEmpty ? nil :
            (walkValues.reduce(0, +) + workoutValues.reduce(0, +)) /
            Double(max(1, walkValues.count + workoutValues.count))
        let activityItem = buildActivityAction(avgActiveMinutes: avgActive)
        items.append(activityItem)

        // Sunlight exposure (inferred from step and walk patterns — no GPS needed)
        let stepValues = history.compactMap(\.steps)
        let avgSteps = stepValues.isEmpty ? nil : stepValues.reduce(0, +) / Double(stepValues.count)
        let sunlightItem = buildSunlightAction(avgSteps: avgSteps, avgWalkMinutes: avgActive)
        items.append(sunlightItem)

        return WeeklyActionPlan(
            items: items,
            weekStart: report.weekStart,
            weekEnd: report.weekEnd
        )
    }

    private func buildSleepAction(avgSleep: Double?) -> WeeklyActionItem {
        let target = 7.5
        let windDownHour = 21 // 9 pm default wind-down reminder

        if let avg = avgSleep, avg < 6.5 {
            let gap = Int((target - avg) * 60)
            return WeeklyActionItem(
                category: .sleep,
                title: "Go to Bed Earlier",
                detail: "Your average sleep this week was \(String(format: "%.1f", avg)) hrs. Try going to bed \(gap) minutes earlier to reach 7.5 hrs.",
                icon: "moon.stars.fill",
                colorName: "nudgeRest",
                supportsReminder: true,
                suggestedReminderHour: windDownHour
            )
        } else if let avg = avgSleep, avg < 7.0 {
            return WeeklyActionItem(
                category: .sleep,
                title: "Protect Your Wind-Down Time",
                detail: "You averaged \(String(format: "%.1f", avg)) hrs this week. A consistent wind-down routine at 9 pm can help you reach 7-8 hrs.",
                icon: "moon.stars.fill",
                colorName: "nudgeRest",
                supportsReminder: true,
                suggestedReminderHour: windDownHour
            )
        } else {
            return WeeklyActionItem(
                category: .sleep,
                title: "Keep Your Sleep Consistent",
                detail: "Good sleep this week. Aim to wake and sleep at the same time each day to reinforce your rhythm.",
                icon: "moon.stars.fill",
                colorName: "nudgeRest",
                supportsReminder: true,
                suggestedReminderHour: windDownHour
            )
        }
    }

    private func buildBreatheAction(stressDays: Int, totalDays: Int) -> WeeklyActionItem {
        let fraction = totalDays > 0 ? Double(stressDays) / Double(totalDays) : 0
        let midAfternoonHour = 15

        if fraction >= 0.5 {
            return WeeklyActionItem(
                category: .breathe,
                title: "Daily Breathing Reset",
                detail: "Your heart was working harder than usual on \(stressDays) of \(totalDays) days. A 5-minute breathing session mid-afternoon can help you feel more relaxed.",
                icon: "wind",
                colorName: "nudgeBreathe",
                supportsReminder: true,
                suggestedReminderHour: midAfternoonHour
            )
        } else if fraction > 0 {
            return WeeklyActionItem(
                category: .breathe,
                title: "Meditate at Wake Time",
                detail: "Starting the day with 3 minutes of box breathing after waking helps set a lower baseline HRV trend.",
                icon: "wind",
                colorName: "nudgeBreathe",
                supportsReminder: true,
                suggestedReminderHour: 7
            )
        } else {
            return WeeklyActionItem(
                category: .breathe,
                title: "Maintain Your Calm",
                detail: "No elevated load detected this week. A short breathing practice in the morning can lock in this pattern.",
                icon: "wind",
                colorName: "nudgeBreathe",
                supportsReminder: false,
                suggestedReminderHour: nil
            )
        }
    }

    private func buildActivityAction(avgActiveMinutes: Double?) -> WeeklyActionItem {
        let dailyGoal = 30.0
        let morningHour = 9

        if let avg = avgActiveMinutes, avg < dailyGoal {
            let extra = Int(dailyGoal - avg)
            return WeeklyActionItem(
                category: .activity,
                title: "Walk \(extra) More Minutes Today",
                detail: "Your daily average active time was \(Int(avg)) min this week. Adding just \(extra) minutes gets you to the 30-min goal.",
                icon: "figure.walk",
                colorName: "nudgeWalk",
                supportsReminder: true,
                suggestedReminderHour: morningHour
            )
        } else if let avg = avgActiveMinutes {
            return WeeklyActionItem(
                category: .activity,
                title: "Sustain Your \(Int(avg))-Min Streak",
                detail: "You hit an average of \(Int(avg)) active minutes daily. Keep the momentum by scheduling your movement at the same time each day.",
                icon: "figure.walk",
                colorName: "nudgeWalk",
                supportsReminder: true,
                suggestedReminderHour: morningHour
            )
        } else {
            return WeeklyActionItem(
                category: .activity,
                title: "Start With a 10-Minute Walk",
                detail: "No activity data yet this week. A 10-minute morning walk is enough to begin building a habit.",
                icon: "figure.walk",
                colorName: "nudgeWalk",
                supportsReminder: true,
                suggestedReminderHour: morningHour
            )
        }
    }

    /// Builds a sunlight action item with inferred time-of-day windows.
    ///
    /// No GPS is required. Windows are inferred from the weekly step and
    /// walkMinutes totals:
    ///
    /// - **Morning** is considered active when avg daily steps >= 1 500
    ///   (enough to suggest a pre-commute / leaving-home burst).
    /// - **Lunch** is considered active when avg walkMinutes >= 10 per day,
    ///   suggesting the user breaks from sedentary time at midday.
    /// - **Evening** is considered active when avg daily steps >= 3 000,
    ///   suggesting movement later in the day (commute home / after-work walk).
    ///
    /// Thresholds are deliberately conservative so we surface the window as
    /// "not yet observed" and coach the user to claim it, rather than
    /// assuming they already do it.
    private func buildSunlightAction(
        avgSteps: Double?,
        avgWalkMinutes: Double?
    ) -> WeeklyActionItem {
        let windows = inferSunlightWindows(avgSteps: avgSteps, avgWalkMinutes: avgWalkMinutes)
        let observedCount = windows.filter(\.hasObservedMovement).count

        let title: String
        let detail: String

        switch observedCount {
        case 0:
            title = "Catch Some Daylight Today"
            detail = "Your movement data doesn't show clear outdoor windows yet. Pick one of the three opportunities below — even 5 minutes counts."
        case 1:
            title = "One Sunlight Window Found"
            detail = "You have one regular movement window that could include outdoor light. Two more are waiting — tap to set reminders."
        case 2:
            title = "Two Good Windows Already"
            detail = "You're moving in two natural light windows. Adding a third would give your circadian rhythm the strongest possible signal."
        default:
            title = "All Three Windows Covered"
            detail = "Morning, midday, and evening movement detected. Prioritise outdoor exposure in at least one of them each day."
        }

        return WeeklyActionItem(
            category: .sunlight,
            title: title,
            detail: detail,
            icon: "sun.max.fill",
            colorName: "nudgeCelebrate",
            supportsReminder: true,
            suggestedReminderHour: 7,
            sunlightWindows: windows
        )
    }

    /// Infers which time-of-day sunlight windows the user is likely active in,
    /// using only step count and walk minutes — no GPS or location access needed.
    private func inferSunlightWindows(
        avgSteps: Double?,
        avgWalkMinutes: Double?
    ) -> [SunlightWindow] {
        // Morning: >= 1 500 steps/day suggests the user leaves home and moves
        let morningActive = (avgSteps ?? 0) >= 1_500

        // Lunch: >= 10 walk-minutes/day suggests a midday break away from desk
        let lunchActive = (avgWalkMinutes ?? 0) >= 10

        // Evening: >= 3 000 steps/day suggests meaningful movement later in day.
        // Morning alone can't account for all of these, so a high count implies
        // an additional movement burst (commute home, after-work walk).
        let eveningActive = (avgSteps ?? 0) >= 3_000

        return [
            SunlightWindow(
                slot: .morning,
                reminderHour: SunlightSlot.morning.defaultHour,
                hasObservedMovement: morningActive
            ),
            SunlightWindow(
                slot: .lunch,
                reminderHour: SunlightSlot.lunch.defaultHour,
                hasObservedMovement: lunchActive
            ),
            SunlightWindow(
                slot: .evening,
                reminderHour: SunlightSlot.evening.defaultHour,
                hasObservedMovement: eveningActive
            )
        ]
    }

    /// Selects the most impactful insight string for the weekly report.
    ///
    /// Prefers the strongest correlation interpretation, falling back
    /// to assessment-based summaries.
    private func selectTopInsight(
        correlations: [CorrelationResult],
        assessments: [HeartAssessment]
    ) -> String {
        // Use the strongest correlation as the top insight
        if let strongest = correlations.max(by: { abs($0.correlationStrength) < abs($1.correlationStrength) }),
           abs(strongest.correlationStrength) >= 0.3 {
            return strongest.interpretation
        }

        // Fall back to assessment-based insight
        let improvingDays = assessments.filter { $0.status == .improving }.count
        let attentionDays = assessments.filter { $0.status == .needsAttention }.count
        let totalDays = assessments.count

        if improvingDays > totalDays / 2 {
            return "Your heart metrics showed improvement for the majority of the week. Keep up the momentum."
        } else if attentionDays > totalDays / 3 {
            return "Several days this week flagged for attention. Consider reviewing your activity and rest patterns."
        } else {
            return "Your heart health metrics remained generally stable this week."
        }
    }

    // MARK: - Watch Action Plan Builder

    /// Converts a ``WeeklyActionPlan`` (iOS detail view model) into the compact
    /// ``WatchActionPlan`` that fits comfortably within WatchConnectivity limits.
    private func buildWatchActionPlan(
        from plan: WeeklyActionPlan,
        report: WeeklyReport?,
        assessments: [HeartAssessment]
    ) -> WatchActionPlan {
        // Map WeeklyActionItems → WatchActionItems (max 4, one per domain)
        let dailyItems: [WatchActionItem] = plan.items.prefix(4).map { item in
            let nudgeCategory: NudgeCategory = {
                switch item.category {
                case .sleep:    return .rest
                case .breathe:  return .breathe
                case .activity: return .walk
                case .sunlight: return .sunlight
                case .hydrate:  return .hydrate
                }
            }()
            return WatchActionItem(
                category: nudgeCategory,
                title: item.title,
                detail: item.detail,
                icon: item.icon,
                reminderHour: item.supportsReminder ? item.suggestedReminderHour : nil
            )
        }

        // Weekly summary
        let avgScore = report?.avgCardioScore
        let activeDays = assessments.filter { $0.status == .improving }.count
        let lowStressDays = assessments.filter { !$0.stressFlag }.count
        let weeklyHeadline: String = {
            if activeDays >= 5 {
                return "You nailed \(activeDays) of 7 days this week!"
            } else if activeDays >= 3 {
                return "\(activeDays) strong days this week — keep building!"
            } else {
                return "Let's aim for more active days next week."
            }
        }()

        // Monthly summary (uses report trend direction as proxy for month direction)
        let monthName = Calendar.current.monthSymbols[Calendar.current.component(.month, from: Date()) - 1]
        let scoreDelta = report.map { r -> Double in
            switch r.trendDirection {
            case .up:   return 8
            case .flat: return 0
            case .down: return -5
            }
        }
        let monthlyHeadline: String = {
            guard let delta = scoreDelta else { return "Keep wearing your watch for monthly insights." }
            if delta > 0 {
                return "Trending up in \(monthName) — great work!"
            } else if delta == 0 {
                return "Holding steady in \(monthName). Consistency pays off."
            } else {
                return "Room to grow in \(monthName). Small steps add up."
            }
        }()

        return WatchActionPlan(
            dailyItems: dailyItems,
            weeklyHeadline: weeklyHeadline,
            weeklyAvgScore: avgScore,
            weeklyActiveDays: activeDays,
            weeklyLowStressDays: lowStressDays,
            monthlyHeadline: monthlyHeadline,
            monthlyScoreDelta: scoreDelta,
            monthName: monthName
        )
    }
}

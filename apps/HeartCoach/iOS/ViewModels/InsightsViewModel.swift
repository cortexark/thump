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

    /// Whether insights data is being loaded.
    @Published var isLoading: Bool = true

    /// Human-readable error message if loading failed.
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let healthKitService: HealthKitService
    private let correlationEngine: CorrelationEngine
    private let localStore: LocalStore

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

            weeklyReport = generateWeeklyReport(
                from: weekHistory,
                assessments: weekAssessments
            )

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

        // Compute nudge completion rate from stored snapshot history.
        // A day counts as "nudge completed" if the user checked in and a
        // stored snapshot with an assessment exists for that date.
        let storedHistory = localStore.loadHistory()
        let weekDates = Set(history.map { calendar.startOfDay(for: $0.date) })
        let completedCount = storedHistory.filter { stored in
            stored.assessment != nil
                && weekDates.contains(calendar.startOfDay(for: stored.snapshot.date))
        }.count
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
}

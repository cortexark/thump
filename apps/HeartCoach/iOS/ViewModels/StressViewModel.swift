// StressViewModel.swift
// Thump iOS
//
// View model for the Stress screen. Loads HRV history from HealthKit,
// computes stress scores via StressEngine, and provides data for the
// calendar-style heatmap, trend summary, and smart nudge actions.
//
// Platforms: iOS 17+

import Foundation
import Combine

// MARK: - Stress View Model

/// View model for the calendar-style stress heatmap with
/// day/week/month views, trend direction, and smart actions.
///
/// Fetches historical snapshots, computes personal HRV baseline,
/// and produces hourly/daily stress data for heatmap rendering.
@MainActor
final class StressViewModel: ObservableObject {

    // MARK: - Published State

    /// The current stress result for today.
    @Published var currentStress: StressResult?

    /// Trend data points for the selected time range.
    @Published var trendPoints: [StressDataPoint] = []

    /// Hourly stress points for the day view.
    @Published var hourlyPoints: [HourlyStressPoint] = []

    /// The currently selected time range.
    @Published var selectedRange: TimeRange = .week {
        didSet {
            Task { await loadData() }
        }
    }

    /// Selected day for week-view detail drill-down.
    @Published var selectedDayForDetail: Date?

    /// Hourly points for the selected day in week view.
    @Published var selectedDayHourlyPoints: [HourlyStressPoint] = []

    /// Computed trend direction.
    @Published var trendDirection: StressTrendDirection = .steady

    /// Smart nudge action recommendation.
    @Published var smartAction: SmartNudgeAction = .standardNudge

    /// Learned sleep patterns.
    @Published var sleepPatterns: [SleepPattern] = []

    /// Whether data is being loaded.
    @Published var isLoading: Bool = false

    /// Human-readable error message if loading failed.
    @Published var errorMessage: String?

    /// The full history of snapshots for computing trends.
    @Published var history: [HeartSnapshot] = []

    // MARK: - Dependencies

    private let healthKitService: HealthKitService
    private let engine: StressEngine
    private let scheduler: SmartNudgeScheduler

    // MARK: - Initialization

    init(
        healthKitService: HealthKitService = HealthKitService(),
        engine: StressEngine = StressEngine(),
        scheduler: SmartNudgeScheduler = SmartNudgeScheduler()
    ) {
        self.healthKitService = healthKitService
        self.engine = engine
        self.scheduler = scheduler
    }

    // MARK: - Public API

    /// Loads historical data and computes all stress metrics.
    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            if !healthKitService.isAuthorized {
                try await healthKitService.requestAuthorization()
            }

            let fetchDays = selectedRange.days + engine.baselineWindow + 7
            let snapshots: [HeartSnapshot]
            do {
                snapshots = try await healthKitService.fetchHistory(
                    days: fetchDays
                )
            } catch {
                #if targetEnvironment(simulator)
                snapshots = MockData.mockHistory(days: fetchDays)
                #else
                snapshots = []
                #endif
            }

            history = snapshots
            computeStressMetrics()
            learnPatterns()
            computeSmartAction()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Select a day for detailed hourly view (in week view).
    func selectDay(_ date: Date) {
        if let current = selectedDayForDetail,
           Calendar.current.isDate(current, inSameDayAs: date) {
            // Deselect if tapping same day
            selectedDayForDetail = nil
            selectedDayHourlyPoints = []
        } else {
            selectedDayForDetail = date
            selectedDayHourlyPoints = engine.hourlyStressForDay(
                snapshots: history,
                date: date
            )
        }
    }

    /// Handle the smart action button tap.
    func handleSmartAction() {
        // In a real app this would trigger the appropriate action:
        // - journalPrompt: navigate to journal entry screen
        // - breatheOnWatch: send breath prompt via WatchConnectivity
        // - morningCheckIn: show check-in sheet
        // - bedtimeWindDown: dismiss
        // For now, reset to standard
        smartAction = .standardNudge
    }

    // MARK: - Computed Properties

    /// Average stress score across the current trend points.
    var averageStress: Double? {
        guard !trendPoints.isEmpty else { return nil }
        let sum = trendPoints.map(\.score).reduce(0, +)
        return sum / Double(trendPoints.count)
    }

    /// The data point with the lowest (most relaxed) stress score.
    var mostRelaxedDay: StressDataPoint? {
        trendPoints.min(by: { $0.score < $1.score })
    }

    /// The data point with the highest (most elevated) stress score.
    var mostElevatedDay: StressDataPoint? {
        trendPoints.max(by: { $0.score < $1.score })
    }

    /// Chart-ready data points for TrendChartView.
    var chartDataPoints: [(date: Date, value: Double)] {
        trendPoints.map { (date: $0.date, value: $0.score) }
    }

    /// Data for the week view: last 7 days of stress data.
    var weekDayPoints: [StressDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(
            byAdding: .day, value: -6, to: today
        ) else { return [] }

        return trendPoints.filter { $0.date >= weekAgo }
            .sorted { $0.date < $1.date }
    }

    /// Calendar grid data for month view.
    /// Returns array of weeks, each containing 7 optional data points
    /// (nil for days outside the month or without data).
    var monthCalendarWeeks: [[StressDataPoint?]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30

        // Build lookup from day-of-month to stress point
        var dayLookup: [Int: StressDataPoint] = [:]
        for point in trendPoints {
            if calendar.isDate(point.date, equalTo: today, toGranularity: .month) {
                let day = calendar.component(.day, from: point.date)
                dayLookup[day] = point
            }
        }

        var weeks: [[StressDataPoint?]] = []
        var currentWeek: [StressDataPoint?] = Array(repeating: nil, count: 7)
        var dayOfMonth = 1
        var slot = firstWeekday - 1 // 0-based index in week

        while dayOfMonth <= daysInMonth {
            currentWeek[slot] = dayLookup[dayOfMonth]
            slot += 1
            dayOfMonth += 1

            if slot >= 7 {
                weeks.append(currentWeek)
                currentWeek = Array(repeating: nil, count: 7)
                slot = 0
            }
        }

        // Add the final partial week
        if slot > 0 {
            weeks.append(currentWeek)
        }

        return weeks
    }

    /// Contextual insight text based on trend direction.
    var trendInsight: String? {
        switch trendDirection {
        case .rising:
            return "Consider taking some extra breaks today. "
                + "A few deep breaths or a short walk can help."
        case .falling:
            return "Whatever you've been doing seems to be helping. "
                + "Keep it up!"
        case .steady:
            guard let avg = averageStress else { return nil }
            let level = StressLevel.from(score: avg)
            switch level {
            case .relaxed:
                return "You've been in a nice relaxed zone."
            case .balanced:
                return "Things have been pretty even — "
                    + "your body is handling the load well."
            case .elevated:
                return "Stress has been consistently higher. "
                    + "Try to build in some recovery time."
            }
        }
    }

    // MARK: - Private Helpers

    /// Computes current stress, trend data, and hourly estimates.
    private func computeStressMetrics() {
        guard !history.isEmpty else {
            currentStress = nil
            trendPoints = []
            hourlyPoints = []
            trendDirection = .steady
            return
        }

        // Compute today's stress
        if let todayScore = engine.dailyStressScore(
            snapshots: history
        ) {
            let level = StressLevel.from(score: todayScore)
            let today = history.last
            let baseline = engine.computeBaseline(
                snapshots: Array(history.dropLast())
            )
            let result = engine.computeStress(
                currentHRV: today?.hrvSDNN ?? 0,
                baselineHRV: baseline ?? 0
            )
            currentStress = result
        } else {
            currentStress = nil
        }

        // Compute trend
        trendPoints = engine.stressTrend(
            snapshots: history,
            range: selectedRange
        )

        // Compute trend direction
        trendDirection = engine.trendDirection(points: trendPoints)

        // Compute hourly estimates for today (day view)
        hourlyPoints = engine.hourlyStressForDay(
            snapshots: history,
            date: Date()
        )

        // Reset selected day detail
        selectedDayForDetail = nil
        selectedDayHourlyPoints = []
    }

    /// Learn sleep patterns from history.
    private func learnPatterns() {
        sleepPatterns = scheduler.learnSleepPatterns(from: history)
    }

    /// Compute the smart nudge action.
    private func computeSmartAction() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        smartAction = scheduler.recommendAction(
            stressPoints: trendPoints,
            trendDirection: trendDirection,
            todaySnapshot: history.last,
            patterns: sleepPatterns,
            currentHour: currentHour
        )
    }

    // MARK: - Preview Support

    #if DEBUG
    /// Preview instance with mock data pre-loaded.
    static var preview: StressViewModel {
        let vm = StressViewModel()
        vm.history = MockData.mockHistory(days: 45)
        vm.currentStress = StressResult(
            score: 35,
            level: .balanced,
            description: "Things look balanced"
        )
        let engine = StressEngine()
        vm.trendPoints = engine.stressTrend(
            snapshots: MockData.mockHistory(days: 45),
            range: .week
        )
        vm.trendDirection = engine.trendDirection(points: vm.trendPoints)
        vm.hourlyPoints = engine.hourlyStressForDay(
            snapshots: MockData.mockHistory(days: 45),
            date: Date()
        )
        return vm
    }
    #endif
}

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

    /// Smart nudge action recommendation (primary).
    @Published var smartAction: SmartNudgeAction = .standardNudge

    /// All applicable smart actions ranked by priority.
    @Published var smartActions: [SmartNudgeAction] = [.standardNudge]

    /// Learned sleep patterns.
    @Published var sleepPatterns: [SleepPattern] = []

    // MARK: - Action State

    /// Whether a guided breathing session is currently running.
    @Published var isBreathingSessionActive: Bool = false

    /// Seconds remaining in the current breathing session countdown.
    @Published var breathingSecondsRemaining: Int = 0

    /// Whether the walk suggestion sheet/alert is shown.
    @Published var walkSuggestionShown: Bool = false

    /// Whether the journal entry sheet is presented.
    @Published var isJournalSheetPresented: Bool = false

    /// The journal prompt to display in the sheet (if any).
    @Published var activeJournalPrompt: JournalPrompt?

    /// Whether a breath prompt was sent to the watch (for UI feedback).
    @Published var didSendBreathPromptToWatch: Bool = false

    /// Whether data is being loaded.
    @Published var isLoading: Bool = false

    /// Human-readable error message if loading failed.
    @Published var errorMessage: String?

    /// The full history of snapshots for computing trends.
    @Published var history: [HeartSnapshot] = []

    // MARK: - Dependencies

    private var healthKitService: HealthKitService
    private let engine: StressEngine
    private let scheduler: SmartNudgeScheduler

    /// Optional connectivity service for sending messages to the watch.
    /// Set via `bind(connectivityService:)` from the view layer.
    private var connectivityService: ConnectivityService?

    /// Readiness level from the latest assessment (set by app coordinator).
    /// Used as a conflict guard so SmartNudgeScheduler doesn't suggest
    /// activity when NudgeGenerator says rest.
    var assessmentReadinessLevel: ReadinessLevel?

    /// Task driving the breathing countdown (replaces Timer to avoid RunLoop retain).
    private var breathingTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        healthKitService: HealthKitService = HealthKitService(),
        engine: StressEngine = StressEngine(),
        scheduler: SmartNudgeScheduler = SmartNudgeScheduler()
    ) {
        self.healthKitService = healthKitService
        self.engine = engine
        self.scheduler = scheduler

        // Listen for readiness updates from DashboardViewModel
        // so the conflict guard stays in sync across tabs
        NotificationCenter.default.addObserver(
            forName: .thumpReadinessDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?["readinessLevel"] as? String,
                  let level = ReadinessLevel(rawValue: raw) else { return }
            self?.assessmentReadinessLevel = level
        }
    }

    /// Binds shared service dependencies (PERF-4).
    func bind(healthKitService: HealthKitService) {
        self.healthKitService = healthKitService
    }

    /// Binds the connectivity service so watch actions can be dispatched.
    func bind(connectivityService: ConnectivityService) {
        self.connectivityService = connectivityService
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
            var snapshots: [HeartSnapshot]
            do {
                snapshots = try await healthKitService.fetchHistory(
                    days: fetchDays
                )
            } catch {
                #if targetEnvironment(simulator)
                snapshots = MockData.mockHistory(days: fetchDays)
                #else
                AppLogger.engine.error("Stress history fetch failed: \(error.localizedDescription)")
                errorMessage = "Unable to read health data. Please check Health permissions in Settings."
                isLoading = false
                return
                #endif
            }

            // Simulator fallback: if all snapshots have nil HRV (no real HealthKit data), use mock data
            #if targetEnvironment(simulator)
            let hasRealData = snapshots.contains(where: { $0.hrvSDNN != nil })
            if !hasRealData {
                snapshots = MockData.mockHistory(days: fetchDays)
            }
            #endif

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

    /// Handle the smart action button tap, routing to the correct behavior.
    func handleSmartAction(_ action: SmartNudgeAction? = nil) {
        let target = action ?? smartAction

        switch target {
        case .journalPrompt(let prompt):
            presentJournalSheet(prompt: prompt)

        case .breatheOnWatch:
            sendBreathPromptToWatch()

        case .activitySuggestion:
            showWalkSuggestion()

        case .morningCheckIn:
            // Dismiss the card from both primary action and list
            smartActions.removeAll { if case .morningCheckIn = $0 { return true } else { return false } }
            smartAction = .standardNudge

        case .bedtimeWindDown:
            // Acknowledge and dismiss the card from both primary action and list
            smartActions.removeAll { if case .bedtimeWindDown = $0 { return true } else { return false } }
            smartAction = .standardNudge

        case .restSuggestion:
            startBreathingSession()

        case .standardNudge:
            break
        }
    }

    // MARK: - Action Methods

    /// Starts a guided breathing session with a Task-based countdown.
    ///
    /// Uses a cancellable `Task` instead of `Timer` to avoid RunLoop retention.
    /// The task holds only a `[weak self]` reference, so if the view model
    /// deallocates the task is cancelled and no closure accesses freed memory.
    func startBreathingSession(durationSeconds: Int = 60) {
        breathingTask?.cancel()
        breathingSecondsRemaining = durationSeconds
        isBreathingSessionActive = true
        breathingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                if self.breathingSecondsRemaining > 0 {
                    self.breathingSecondsRemaining -= 1
                } else {
                    self.stopBreathingSession()
                    return
                }
            }
        }
    }

    /// Stops the breathing session and cancels the countdown task.
    func stopBreathingSession() {
        breathingTask?.cancel()
        breathingTask = nil
        isBreathingSessionActive = false
        breathingSecondsRemaining = 0
    }

    /// Shows the walk suggestion (opens Health-style prompt).
    func showWalkSuggestion() {
        walkSuggestionShown = true
    }

    /// Presents the journal sheet, optionally with a specific prompt.
    func presentJournalSheet(prompt: JournalPrompt? = nil) {
        activeJournalPrompt = prompt
        isJournalSheetPresented = true
    }

    /// Sends a breathing exercise prompt to the paired Apple Watch.
    func sendBreathPromptToWatch() {
        let nudge = DailyNudge(
            category: .breathe,
            title: "Breathe",
            description: "Take a moment for slow, deep breaths.",
            durationMinutes: 3,
            icon: "wind"
        )
        connectivityService?.sendBreathPrompt(nudge)
        didSendBreathPromptToWatch = true
    }

    // MARK: - Computed Properties

    /// Average stress score across the current trend points.
    /// On the day view, falls back to currentStress when trend data is empty
    /// (stressTrend requires multi-day history which isn't available for daily range).
    var averageStress: Double? {
        if trendPoints.isEmpty {
            return currentStress?.score
        }
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
            return "Stress signals have been climbing over this period. "
                + "Short breaks, a brief walk, or a few slow breaths "
                + "can help bring things down."
        case .falling:
            return "Stress readings have been easing off. "
                + "Something in your recent routine seems to be working."
        case .steady:
            guard let avg = averageStress else { return nil }
            let level = StressLevel.from(score: avg)
            switch level {
            case .relaxed:
                return "Readings have stayed in the relaxed range "
                    + "throughout this period."
            case .balanced:
                return "Readings have been fairly consistent "
                    + "with no big swings in either direction."
            case .elevated:
                return "Stress has been running consistently higher. "
                    + "Building in some recovery time may be worth trying."
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

        // Compute today's stress via the canonical snapshot-based path.
        // This gates on nil HRV internally (returns nil if missing) and uses
        // the same logic as DashboardViewModel, ensuring consistent scores.
        if let today = history.last {
            currentStress = engine.computeStress(
                snapshot: today,
                recentHistory: Array(history.dropLast())
            )
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

    /// Compute smart nudge actions (single + multiple).
    /// When readiness is low (recovering/moderate), injects a bedtimeWindDown action
    /// that surfaces the WHY (HRV/sleep driver) and the WHAT (tonight's action).
    /// This closes the causal loop on the Stress screen:
    /// stress pattern → low HRV → low readiness → "here's what to fix tonight".
    private func computeSmartAction() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        smartAction = scheduler.recommendAction(
            stressPoints: trendPoints,
            trendDirection: trendDirection,
            todaySnapshot: history.last,
            patterns: sleepPatterns,
            currentHour: currentHour,
            readinessGate: assessmentReadinessLevel
        )
        smartActions = scheduler.recommendActions(
            stressPoints: trendPoints,
            trendDirection: trendDirection,
            todaySnapshot: history.last,
            patterns: sleepPatterns,
            currentHour: currentHour,
            readinessGate: assessmentReadinessLevel
        )

        // Readiness gate: compute readiness from our own history and inject a
        // bedtimeWindDown card if the body needs recovery.
        injectRecoveryActionIfNeeded()
    }

    /// Computes readiness from current history and prepends a bedtimeWindDown
    /// smart action when readiness is recovering or moderate.
    private func injectRecoveryActionIfNeeded() {
        guard let today = history.last else { return }

        let stressScore: Double? = currentStress?.score
        let stressConfidence: StressConfidence? = currentStress?.confidence
        guard let readiness = ReadinessEngine().compute(
            snapshot: today,
            stressScore: stressScore,
            stressConfidence: stressConfidence,
            recentHistory: Array(history.dropLast())
        ) else { return }

        guard readiness.level == .recovering || readiness.level == .moderate else { return }

        // Identify the weakest pillar to personalise the message
        let hrvPillar   = readiness.pillars.first { $0.type == .hrvTrend }
        let sleepPillar = readiness.pillars.first { $0.type == .sleep }
        let weakest = [hrvPillar, sleepPillar].compactMap { $0 }.min { $0.score < $1.score }

        let nudgeTitle: String
        let nudgeDescription: String

        if weakest?.type == .hrvTrend {
            nudgeTitle = "Sleep to Rebuild Your HRV"
            nudgeDescription = "Your HRV is below your recent baseline — your nervous system "
                + "is still working. The single best thing tonight: 8 hours of sleep. "
                + "Every hour directly rebuilds HRV, which lifts readiness by tomorrow morning."
        } else {
            let hrs = today.sleepHours.map { String(format: "%.1f", $0) } ?? "not enough"
            nudgeTitle = "Earlier Bedtime = Better Tomorrow"
            nudgeDescription = "You got \(hrs) hours last night. Short sleep raises your RHR "
                + "and suppresses HRV — which is what your current readings are showing. "
                + "Aim to be in bed by 10 PM to break the cycle."
        }

        let recoveryNudge = DailyNudge(
            category: .rest,
            title: nudgeTitle,
            description: nudgeDescription,
            durationMinutes: nil,
            icon: "bed.double.fill"
        )

        // Prepend as the first action so it's always visible at the top
        smartActions.insert(.bedtimeWindDown(recoveryNudge), at: 0)
        smartAction = .bedtimeWindDown(recoveryNudge)
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

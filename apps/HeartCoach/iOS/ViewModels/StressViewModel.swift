// StressViewModel.swift
// Thump iOS
//
// View model for the Stress screen. Loads HRV history from HealthKit,
// computes stress scores via StressEngine, and provides data for the
// stress gauge, trend chart, and summary statistics.
// Platforms: iOS 17+

import Foundation
import Combine

// MARK: - Stress View Model

/// View model for the Stress screen that displays HRV-based stress
/// levels with day/week/month trending.
///
/// Fetches historical snapshots, computes a personal HRV baseline,
/// and produces stress scores and trend data for chart rendering.
@MainActor
final class StressViewModel: ObservableObject {

    // MARK: - Published State

    /// The current stress result for today.
    @Published var currentStress: StressResult?

    /// Trend data points for the selected time range.
    @Published var trendPoints: [StressDataPoint] = []

    /// The currently selected time range for trend display.
    @Published var selectedRange: TimeRange = .week {
        didSet {
            Task { await loadData() }
        }
    }

    /// Whether data is being loaded.
    @Published var isLoading: Bool = false

    /// Human-readable error message if loading failed.
    @Published var errorMessage: String?

    /// The full history of snapshots for computing trends.
    @Published var history: [HeartSnapshot] = []

    // MARK: - Dependencies

    private let healthKitService: HealthKitService
    private let engine: StressEngine

    // MARK: - Initialization

    /// Creates a new StressViewModel.
    ///
    /// - Parameters:
    ///   - healthKitService: Service for fetching HealthKit data.
    ///   - engine: The stress computation engine.
    init(
        healthKitService: HealthKitService = HealthKitService(),
        engine: StressEngine = StressEngine()
    ) {
        self.healthKitService = healthKitService
        self.engine = engine
    }

    // MARK: - Public API

    /// Loads historical data and computes stress metrics.
    ///
    /// Fetches enough history to cover the selected range plus
    /// the baseline window, then computes current stress and trend.
    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            if !healthKitService.isAuthorized {
                try await healthKitService.requestAuthorization()
            }

            // Fetch extra days for baseline computation
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
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
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

    /// Chart-ready data points as (date, value) tuples for TrendChartView.
    var chartDataPoints: [(date: Date, value: Double)] {
        trendPoints.map { (date: $0.date, value: $0.score) }
    }

    // MARK: - Private Helpers

    /// Computes current stress and trend data from loaded history.
    private func computeStressMetrics() {
        guard !history.isEmpty else {
            currentStress = nil
            trendPoints = []
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
        return vm
    }
    #endif
}

// TrendsViewModel.swift
// Thump iOS
//
// View model for the Trends tab. Loads historical health metric data
// from HealthKitService and provides filtered data points for charting
// across configurable time ranges and metric types.
// Platforms: iOS 17+

import Foundation
import Combine

// MARK: - Trends View Model

/// View model for the Trends screen that displays historical metric charts.
///
/// Provides time-range selection, metric-type switching, and data point
/// extraction for chart rendering. Historical data is fetched from
/// `HealthKitService` and cached in memory for fast metric switching.
@MainActor
final class TrendsViewModel: ObservableObject {

    // MARK: - Metric Type

    /// The metric types available for charting on the Trends screen.
    enum MetricType: String, CaseIterable {
        case restingHR = "Resting HR"
        case hrv = "HRV"
        case recovery = "Recovery"
        case vo2Max = "VO2 Max"
        case activeMinutes = "Active Min"

        /// The unit string displayed alongside chart values.
        var unit: String {
            switch self {
            case .restingHR:      return "bpm"
            case .hrv:            return "ms"
            case .recovery:       return "bpm"
            case .vo2Max:         return "mL/kg/min"
            case .activeMinutes:  return "min"
            }
        }

        /// SF Symbol icon for this metric type.
        var icon: String {
            switch self {
            case .restingHR:      return "heart.fill"
            case .hrv:            return "waveform.path.ecg"
            case .recovery:       return "arrow.down.heart.fill"
            case .vo2Max:         return "lungs.fill"
            case .activeMinutes:  return "figure.run"
            }
        }
    }

    // MARK: - Time Range

    /// Predefined time ranges for the history chart.
    enum TimeRange: Int, CaseIterable {
        case week = 7
        case twoWeeks = 14
        case month = 30

        /// Human-readable label for the time range.
        var label: String {
            switch self {
            case .week:     return "7 Days"
            case .twoWeeks: return "14 Days"
            case .month:    return "30 Days"
            }
        }
    }

    // MARK: - Published State

    /// The fetched historical snapshots, ordered oldest-first.
    @Published var history: [HeartSnapshot] = []

    /// The currently selected metric to display.
    @Published var selectedMetric: MetricType = .restingHR

    /// The currently selected time range.
    @Published var timeRange: TimeRange = .week {
        didSet {
            Task { await loadHistory() }
        }
    }

    /// Whether history data is being loaded.
    @Published var isLoading: Bool = false

    /// Human-readable error message if loading failed.
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private var healthKitService: HealthKitService

    // MARK: - Initialization

    /// Creates a new TrendsViewModel with the given HealthKit service.
    ///
    /// - Parameter healthKitService: The service used to fetch historical data.
    init(healthKitService: HealthKitService = HealthKitService()) {
        self.healthKitService = healthKitService
    }

    /// Binds shared service dependencies (PERF-4).
    func bind(healthKitService: HealthKitService) {
        self.healthKitService = healthKitService
    }

    // MARK: - Public API

    /// Loads historical snapshot data for the currently selected time range.
    ///
    /// Fetches data from HealthKit and updates the `history` array.
    /// Call this when the view appears or when the time range changes.
    func loadHistory() async {
        isLoading = true
        errorMessage = nil

        do {
            if !healthKitService.isAuthorized {
                try await healthKitService.requestAuthorization()
            }

            let snapshots: [HeartSnapshot]
            do {
                snapshots = try await healthKitService.fetchHistory(days: timeRange.rawValue)
            } catch {
                #if targetEnvironment(simulator)
                snapshots = MockData.mockHistory(days: timeRange.rawValue)
                #else
                snapshots = []
                #endif
            }
            history = snapshots
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Extracts chart-ready data points for the specified metric type.
    ///
    /// Filters out days where the metric value is nil, returning only
    /// valid (date, value) pairs suitable for plotting.
    ///
    /// - Parameter metric: The metric type to extract data for.
    /// - Returns: Array of (date, value) tuples ordered oldest-first.
    func dataPoints(for metric: MetricType) -> [(date: Date, value: Double)] {
        return history.compactMap { snapshot in
            guard let value = extractValue(from: snapshot, metric: metric) else {
                return nil
            }
            return (date: snapshot.date, value: value)
        }
    }

    /// Data points for the currently selected metric.
    var currentDataPoints: [(date: Date, value: Double)] {
        dataPoints(for: selectedMetric)
    }

    /// Computes summary statistics for the selected metric's data points.
    var currentStats: MetricStats? {
        let points = currentDataPoints
        guard !points.isEmpty else { return nil }

        let values = points.map(\.value)
        let avg = values.reduce(0, +) / Double(values.count)
        let min = values.min() ?? 0
        let max = values.max() ?? 0

        // Simple trend: compare first half average to second half average
        let midpoint = values.count / 2
        guard midpoint > 0 else {
            return MetricStats(average: avg, minimum: min, maximum: max, trend: .flat)
        }

        let firstHalf = Array(values.prefix(midpoint))
        let secondHalf = Array(values.suffix(values.count - midpoint))
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        let percentChange = (secondAvg - firstAvg) / firstAvg
        let trend: MetricTrend
        if abs(percentChange) < 0.02 {
            trend = .flat
        } else if percentChange > 0 {
            trend = selectedMetric == .restingHR ? .worsening : .improving
        } else {
            trend = selectedMetric == .restingHR ? .improving : .worsening
        }

        return MetricStats(average: avg, minimum: min, maximum: max, trend: trend)
    }

    // MARK: - Supporting Types

    /// Summary statistics for a metric over the selected time range.
    struct MetricStats {
        let average: Double
        let minimum: Double
        let maximum: Double
        let trend: MetricTrend
    }

    /// Direction of metric change over the time period.
    enum MetricTrend {
        case improving
        case flat
        case worsening

        var label: String {
            switch self {
            case .improving: return "Building Momentum"
            case .flat:      return "Holding Steady"
            case .worsening: return "Worth Watching"
            }
        }

        var icon: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .flat:      return "arrow.right"
            case .worsening: return "arrow.down.right"
            }
        }
    }

    // MARK: - Private Helpers

    /// Extracts the numeric value for a given metric from a snapshot.
    ///
    /// - Parameters:
    ///   - snapshot: The `HeartSnapshot` to extract from.
    ///   - metric: The metric type to extract.
    /// - Returns: The metric value, or `nil` if not available.
    private func extractValue(
        from snapshot: HeartSnapshot,
        metric: MetricType
    ) -> Double? {
        switch metric {
        case .restingHR:
            return snapshot.restingHeartRate
        case .hrv:
            return snapshot.hrvSDNN
        case .recovery:
            return snapshot.recoveryHR1m
        case .vo2Max:
            return snapshot.vo2Max
        case .activeMinutes:
            let walk = snapshot.walkMinutes ?? 0
            let workout = snapshot.workoutMinutes ?? 0
            let total = walk + workout
            return total > 0 ? total : nil
        }
    }
}

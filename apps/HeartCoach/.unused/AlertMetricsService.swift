// AlertMetricsService.swift
// Thump iOS
//
// Records ground truth data on when alerts and nudges are generated,
// whether users act on them, and how assessment predictions compare
// to actual wellness outcomes. This data helps improve alert accuracy
// over time and provides a feedback loop for the trend engine.
//
// All metrics are stored locally in UserDefaults. No data is sent
// to any server.
//
// Platforms: iOS 17+

import Foundation

// MARK: - Alert Log Entry

/// A single logged alert/nudge event with outcome tracking.
struct AlertLogEntry: Codable, Identifiable, Sendable {
    let id: String
    let timestamp: Date
    let alertType: AlertType
    let trendStatus: String
    let confidenceLevel: String
    let anomalyScore: Double
    let stressFlag: Bool
    let regressionFlag: Bool
    let nudgeCategory: String
    let cardioScore: Double?

    /// User response — populated when feedback is received.
    var userFeedback: String?

    /// Whether the user completed the suggested nudge.
    var nudgeCompleted: Bool

    /// Next-day outcome: did the user's metrics actually improve?
    var nextDayImproved: Bool?

    /// Archetype tag for test profiles (nil for real users).
    var testArchetype: String?
}

// MARK: - Alert Type

/// Categorizes the type of alert that was generated.
enum AlertType: String, Codable, Sendable {
    case anomaly
    case regression
    case stress
    case routine
    case improving
}

// MARK: - Alert Accuracy Summary

/// Aggregated accuracy metrics over a time window.
struct AlertAccuracySummary: Sendable {
    let totalAlerts: Int
    let alertsWithOutcome: Int
    let accuratePredictions: Int
    let accuracyRate: Double
    let nudgesCompleted: Int
    let nudgeCompletionRate: Double
    let byType: [AlertType: TypeSummary]

    struct TypeSummary: Sendable {
        let count: Int
        let withOutcome: Int
        let accurate: Int
    }
}

// MARK: - AlertMetricsService

/// Logs alert events and tracks outcomes for ground truth measurement.
///
/// Usage:
/// ```swift
/// let metrics = AlertMetricsService.shared
/// let entryId = metrics.logAlert(assessment: assessment)
/// // Later, when user provides feedback:
/// metrics.recordFeedback(entryId: entryId, feedback: .positive)
/// // Next day, when we can compare:
/// metrics.recordOutcome(entryId: entryId, improved: true)
/// ```
final class AlertMetricsService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = AlertMetricsService()

    // MARK: - Storage

    private let defaults: UserDefaults
    private let storageKey = "thump_alert_metrics_log"
    private let queue = DispatchQueue(
        label: "com.thump.alertmetrics",
        qos: .utility
    )

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Logging

    /// Log a new alert event from a HeartAssessment.
    ///
    /// - Parameters:
    ///   - assessment: The assessment that triggered the alert.
    ///   - archetype: Optional test archetype tag.
    /// - Returns: The entry ID for later outcome recording.
    @discardableResult
    func logAlert(
        assessment: HeartAssessment,
        archetype: String? = nil
    ) -> String {
        let entry = AlertLogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            alertType: classifyAlert(assessment),
            trendStatus: assessment.status.rawValue,
            confidenceLevel: assessment.confidence.rawValue,
            anomalyScore: assessment.anomalyScore,
            stressFlag: assessment.stressFlag,
            regressionFlag: assessment.regressionFlag,
            nudgeCategory: assessment.dailyNudge.category.rawValue,
            cardioScore: assessment.cardioScore,
            userFeedback: nil,
            nudgeCompleted: false,
            nextDayImproved: nil,
            testArchetype: archetype
        )

        queue.sync {
            var log = loadLog()
            log.append(entry)
            // Keep last 90 days max
            let cutoff = Calendar.current.date(
                byAdding: .day,
                value: -90,
                to: Date()
            ) ?? Date()
            log = log.filter { $0.timestamp > cutoff }
            saveLog(log)
        }

        Analytics.shared.track(
            .assessmentGenerated,
            properties: [
                "type": entry.alertType.rawValue,
                "status": entry.trendStatus,
                "confidence": entry.confidenceLevel
            ]
        )

        return entry.id
    }

    /// Record user feedback for a logged alert.
    func recordFeedback(
        entryId: String,
        feedback: DailyFeedback
    ) {
        queue.sync {
            var log = loadLog()
            if let idx = log.firstIndex(where: { $0.id == entryId }) {
                log[idx].userFeedback = feedback.rawValue
                if feedback == .positive {
                    log[idx].nudgeCompleted = true
                }
                saveLog(log)
            }
        }
    }

    /// Record whether the next day showed improvement.
    func recordOutcome(entryId: String, improved: Bool) {
        queue.sync {
            var log = loadLog()
            if let idx = log.firstIndex(where: { $0.id == entryId }) {
                log[idx].nextDayImproved = improved
                saveLog(log)
            }
        }
    }

    /// Mark a nudge as completed for a logged alert.
    func markNudgeComplete(entryId: String) {
        queue.sync {
            var log = loadLog()
            if let idx = log.firstIndex(where: { $0.id == entryId }) {
                log[idx].nudgeCompleted = true
                saveLog(log)
            }
        }
    }

    // MARK: - Querying

    /// Get all logged entries, optionally filtered by archetype.
    func entries(archetype: String? = nil) -> [AlertLogEntry] {
        let log = queue.sync { loadLog() }
        if let archetype {
            return log.filter { $0.testArchetype == archetype }
        }
        return log
    }

    /// Get entries from the last N days.
    func recentEntries(days: Int) -> [AlertLogEntry] {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: Date()
        ) ?? Date()
        return queue.sync { loadLog() }
            .filter { $0.timestamp > cutoff }
    }

    /// Compute accuracy summary for all entries with outcomes.
    func accuracySummary(
        entries: [AlertLogEntry]? = nil
    ) -> AlertAccuracySummary {
        let data = entries ?? queue.sync { loadLog() }
        let withOutcome = data.filter {
            $0.nextDayImproved != nil
        }

        let accurate = withOutcome.filter { entry in
            guard let improved = entry.nextDayImproved else {
                return false
            }
            // Alert was accurate if:
            // - needsAttention + didn't improve (correct warning)
            // - improving + did improve (correct positive)
            // - stable + no big change either way
            switch entry.trendStatus {
            case "needsAttention":
                return !improved
            case "improving":
                return improved
            case "stable":
                return true // stable is always "correct"
            default:
                return false
            }
        }

        let completed = data.filter { $0.nudgeCompleted }

        // Group by type
        var byType: [AlertType: AlertAccuracySummary.TypeSummary] = [:]
        for type in AlertType.allCases {
            let typeEntries = data.filter { $0.alertType == type }
            let typeOutcome = typeEntries.filter {
                $0.nextDayImproved != nil
            }
            let typeAccurate = typeOutcome.filter { entry in
                guard let improved = entry.nextDayImproved else {
                    return false
                }
                return entry.trendStatus == "improving"
                    ? improved
                    : !improved
            }
            byType[type] = .init(
                count: typeEntries.count,
                withOutcome: typeOutcome.count,
                accurate: typeAccurate.count
            )
        }

        return AlertAccuracySummary(
            totalAlerts: data.count,
            alertsWithOutcome: withOutcome.count,
            accuratePredictions: accurate.count,
            accuracyRate: withOutcome.isEmpty
                ? 0
                : Double(accurate.count) / Double(withOutcome.count),
            nudgesCompleted: completed.count,
            nudgeCompletionRate: data.isEmpty
                ? 0
                : Double(completed.count) / Double(data.count),
            byType: byType
        )
    }

    /// Export all log entries as CSV string.
    func exportCSV() -> String {
        let entries = queue.sync { loadLog() }
        var csv = "id,timestamp,type,status,confidence,"
            + "anomaly,stress,regression,nudge,cardio,"
            + "feedback,completed,improved,archetype\n"

        let fmt = ISO8601DateFormatter()
        for entry in entries {
            let ts = fmt.string(from: entry.timestamp)
            let cardio = entry.cardioScore.map {
                String(format: "%.0f", $0)
            } ?? ""
            let improved = entry.nextDayImproved.map {
                String($0)
            } ?? ""
            let row = [
                entry.id, ts, entry.alertType.rawValue,
                entry.trendStatus, entry.confidenceLevel,
                String(format: "%.2f", entry.anomalyScore),
                String(entry.stressFlag),
                String(entry.regressionFlag),
                entry.nudgeCategory, cardio,
                entry.userFeedback ?? "",
                String(entry.nudgeCompleted), improved,
                entry.testArchetype ?? ""
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    /// Clear all logged data (for testing).
    func clearAll() {
        queue.sync {
            defaults.removeObject(forKey: storageKey)
        }
    }

    // MARK: - Private

    private func classifyAlert(
        _ assessment: HeartAssessment
    ) -> AlertType {
        if assessment.stressFlag { return .stress }
        if assessment.regressionFlag { return .regression }
        if assessment.anomalyScore > 2.0 { return .anomaly }
        if assessment.status == .improving { return .improving }
        return .routine
    }

    private func loadLog() -> [AlertLogEntry] {
        guard let data = defaults.data(forKey: storageKey),
              let log = try? JSONDecoder().decode(
                [AlertLogEntry].self,
                from: data
              ) else {
            return []
        }
        return log
    }

    private func saveLog(_ log: [AlertLogEntry]) {
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: storageKey)
        }
    }
}

// MARK: - AlertType + CaseIterable

extension AlertType: CaseIterable {}

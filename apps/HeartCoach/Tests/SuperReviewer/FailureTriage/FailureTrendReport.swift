// FailureTrendReport.swift
// Thump Tests — Super Reviewer Failure Triage
//
// Run-over-run comparison: finds new regressions, improvements, and persistent failures.
// Saves and loads a failure baseline from CaptureOutput/failure_baseline.json.
// Appends a history entry to CaptureOutput/failure_history.json after every run.

import Foundation

// MARK: - Failure Trend Report

struct FailureTrendReport: Codable {
    let runDate: String
    let tier: String
    let totalCaptures: Int
    let currentRunFailureCount: Int
    let previousRunFailureCount: Int

    /// Failures in current run that were NOT in the previous baseline.
    let newFailures: [ReviewFailure]

    /// Failures in previous baseline that are NOT in the current run (fixed!).
    let fixedFailures: [ReviewFailure]

    /// Failures present in both baseline and current run.
    let persistentFailures: [ReviewFailure]

    var regressionCount: Int  { newFailures.count }
    var improvementCount: Int { fixedFailures.count }
    var persistentCount: Int  { persistentFailures.count }

    var summary: String {
        var lines: [String] = []
        lines.append("── Failure Trend Report (\(tier)) ──────────────────")
        lines.append("Run date:        \(runDate)")
        lines.append("Total captures:  \(totalCaptures)")
        lines.append("Current failures: \(currentRunFailureCount)")
        lines.append("Previous failures: \(previousRunFailureCount)")
        lines.append("")

        if regressionCount > 0 {
            lines.append("🔴 NEW REGRESSIONS (\(regressionCount)):")
            for f in newFailures.prefix(10) {
                lines.append("  [\(f.severity.rawValue)] \(f.criterionID) — \(f.captureID)")
                lines.append("       \(f.failureMessage)")
            }
            if newFailures.count > 10 {
                lines.append("  ... and \(newFailures.count - 10) more")
            }
            lines.append("")
        }

        if improvementCount > 0 {
            lines.append("✅ FIXED (\(improvementCount)):")
            for f in fixedFailures.prefix(5) {
                lines.append("  [\(f.criterionID)] \(f.captureID)")
            }
            lines.append("")
        }

        if persistentCount > 0 {
            lines.append("⚠️  PERSISTENT (\(persistentCount)) — known issues, fix in backlog:")
            // Group persistent by criterionID
            let grouped = Dictionary(grouping: persistentFailures, by: \.criterionID)
            for (criterion, failures) in grouped.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(criterion): \(failures.count) occurrences")
            }
            lines.append("")
        }

        lines.append("──────────────────────────────────────────────────")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Failure History Entry

struct FailureHistoryEntry: Codable {
    let runDate: String
    let tier: String
    let totalCaptures: Int
    let p0Count: Int
    let p1Count: Int
    let p2Count: Int
    let p3Count: Int
    let passRatePct: Double
    let perCriterionFailureCount: [String: Int]
}

// MARK: - Trend Report Builder

enum FailureTrendReportBuilder {

    // MARK: - Compare Current vs Baseline

    static func compare(
        current: [ReviewFailure],
        baseline: [ReviewFailure],
        tier: String,
        totalCaptures: Int
    ) -> FailureTrendReport {
        let baselineIDs = Set(baseline.map(\.id))
        let currentIDs  = Set(current.map(\.id))

        let newFailures        = current.filter  { !baselineIDs.contains($0.id) }
        let fixedFailures      = baseline.filter { !currentIDs.contains($0.id) }
        let persistentFailures = current.filter  { baselineIDs.contains($0.id) }

        return FailureTrendReport(
            runDate: ISO8601DateFormatter().string(from: Date()),
            tier: tier,
            totalCaptures: totalCaptures,
            currentRunFailureCount: current.count,
            previousRunFailureCount: baseline.count,
            newFailures: newFailures.sorted { $0.severity > $1.severity },
            fixedFailures: fixedFailures,
            persistentFailures: persistentFailures.sorted { $0.severity > $1.severity }
        )
    }

    // MARK: - Baseline I/O

    /// Load the previous failure baseline from disk.
    static func loadBaseline(from directory: URL) -> [ReviewFailure] {
        let url = directory.appendingPathComponent("failure_baseline.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([ReviewFailure].self, from: data)) ?? []
    }

    /// Save the current failure set as the new baseline.
    static func saveBaseline(_ failures: [ReviewFailure], to directory: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = directory.appendingPathComponent("failure_baseline.json")
        if let data = try? encoder.encode(failures) {
            try? data.write(to: url)
        }
    }

    // MARK: - History I/O

    /// Append a history entry to failure_history.json for trend graphing.
    static func appendHistoryEntry(_ entry: FailureHistoryEntry, to directory: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("failure_history.json")
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        var history: [FailureHistoryEntry] = []
        if let data = try? Data(contentsOf: url) {
            history = (try? decoder.decode([FailureHistoryEntry].self, from: data)) ?? []
        }

        history.append(entry)

        if let data = try? encoder.encode(history) {
            try? data.write(to: url)
        }
    }

    // MARK: - Build History Entry

    static func buildHistoryEntry(
        failures: [ReviewFailure],
        tier: String,
        totalCaptures: Int
    ) -> FailureHistoryEntry {
        let criterionCounts = Dictionary(
            grouping: failures,
            by: \.criterionID
        ).mapValues(\.count)

        let passRate = Double(max(0, totalCaptures - failures.count)) / Double(max(totalCaptures, 1)) * 100

        return FailureHistoryEntry(
            runDate: ISO8601DateFormatter().string(from: Date()),
            tier: tier,
            totalCaptures: totalCaptures,
            p0Count: failures.filter { $0.severity == .p0 }.count,
            p1Count: failures.filter { $0.severity == .p1 }.count,
            p2Count: failures.filter { $0.severity == .p2 }.count,
            p3Count: failures.filter { $0.severity == .p3 }.count,
            passRatePct: passRate,
            perCriterionFailureCount: criterionCounts
        )
    }
}

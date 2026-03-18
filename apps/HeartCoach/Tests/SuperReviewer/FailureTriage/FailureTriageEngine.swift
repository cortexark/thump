// FailureTriageEngine.swift
// Thump Tests — Super Reviewer Failure Triage
//
// Orchestrator: runs after every Super Reviewer batch.
// Collects failures from all sources, generates Jira tickets,
// checks regression locks, computes trend vs baseline, saves artifacts.

import Foundation

// MARK: - Failure Triage Engine

enum FailureTriageEngine {

    // MARK: - Triage Result

    struct TriageResult {
        let allFailures: [ReviewFailure]
        let p0Failures: [ReviewFailure]
        let p1Failures: [ReviewFailure]
        let fixBacklog: [FixItem]            // sorted P0 first, then by occurrence count
        let jiraTickets: [JiraTicket]        // one per (criterionID, textField) cluster
        let trendReport: FailureTrendReport
        let regressionLockViolations: [RegressionLockViolation]
        let historyEntry: FailureHistoryEntry
        let summary: String
    }

    // MARK: - Output Directory

    private static var captureOutputURL: URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // FailureTriage/
            .deletingLastPathComponent()   // SuperReviewer/
            .appendingPathComponent("CaptureOutput")
    }

    // MARK: - Full Triage

    /// Run after SuperReviewerRunner.runBatch() completes.
    /// Pass empty arrays for llmResults and rptBatchResult when running Tier A (no LLM).
    static func triage(
        captures: [SuperReviewerCapture],
        verifierBatchResult: BatchVerificationResult,
        llmResults: [MultiJudgeResult] = [],
        rptBatchResult: ReportRubricBatchResult? = nil,
        tier: String = "TierA",
        outputDirectory: URL? = nil
    ) -> TriageResult {
        let outputDir = outputDirectory ?? captureOutputURL.appendingPathComponent(tier)

        // 1. Collect failures from all sources
        let verifierFailures = FailureCollector.collect(
            from: verifierBatchResult,
            captures: captures
        )

        let llmFailures: [ReviewFailure] = llmResults.isEmpty ? [] : FailureCollector.collect(
            from: llmResults,
            captures: captures
        )

        let rptFailures: [ReviewFailure]
        if let rpt = rptBatchResult {
            rptFailures = FailureCollector.collect(from: rpt, captures: captures)
        } else {
            rptFailures = []
        }

        let allFailures = FailureCollector.merge([verifierFailures, llmFailures, rptFailures])

        // 2. Generate fix backlog with Jira tickets
        let fixBacklog = FixBacklogGenerator.generate(
            from: allFailures,
            minSeverity: .p2,
            totalCaptures: captures.count
        )
        let jiraTickets = fixBacklog.map(\.jiraTicket)

        // 3. Check regression locks
        let lockViolations = RegressionLockStore.checkRegressionLocks(
            captures: captures,
            batchResult: verifierBatchResult
        )

        // 4. Load baseline and compute trend
        let baseline = FailureTrendReportBuilder.loadBaseline(from: outputDir)
        let trendReport = FailureTrendReportBuilder.compare(
            current: allFailures,
            baseline: baseline,
            tier: tier,
            totalCaptures: captures.count
        )

        // 5. Build history entry
        let historyEntry = FailureTrendReportBuilder.buildHistoryEntry(
            failures: allFailures,
            tier: tier,
            totalCaptures: captures.count
        )

        // 6. Compose summary
        let summary = buildSummary(
            failures: allFailures,
            fixBacklog: fixBacklog,
            trendReport: trendReport,
            lockViolations: lockViolations,
            tier: tier,
            captureCount: captures.count
        )

        return TriageResult(
            allFailures: allFailures,
            p0Failures: allFailures.filter { $0.severity == .p0 },
            p1Failures: allFailures.filter { $0.severity == .p1 },
            fixBacklog: fixBacklog,
            jiraTickets: jiraTickets,
            trendReport: trendReport,
            regressionLockViolations: lockViolations,
            historyEntry: historyEntry,
            summary: summary
        )
    }

    // MARK: - Save Artifacts

    /// Save all triage artifacts to disk. Call after triage() completes.
    static func saveToDisk(_ result: TriageResult, outputDirectory: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Save failures JSON
        if let data = try? encoder.encode(result.allFailures) {
            try? data.write(to: outputDirectory.appendingPathComponent("all_failures.json"))
        }

        // Save fix backlog JSON
        if let data = try? encoder.encode(result.fixBacklog) {
            try? data.write(to: outputDirectory.appendingPathComponent("fix_backlog.json"))
        }

        // Save Jira tickets as JSON array
        if let data = try? encoder.encode(result.jiraTickets) {
            try? data.write(to: outputDirectory.appendingPathComponent("jira_tickets.json"))
        }

        // Save Jira tickets as Markdown (one file per ticket)
        let markdownDir = outputDirectory.appendingPathComponent("JiraTickets")
        try? fm.createDirectory(at: markdownDir, withIntermediateDirectories: true)
        for ticket in result.jiraTickets {
            let filename = "\(ticket.key).md"
            let md = ticket.toMarkdown()
            try? md.write(to: markdownDir.appendingPathComponent(filename), atomically: true, encoding: .utf8)
        }

        // Save trend report
        if let data = try? encoder.encode(result.trendReport) {
            try? data.write(to: outputDirectory.appendingPathComponent("trend_report.json"))
        }

        // Update baseline with current run's failures
        FailureTrendReportBuilder.saveBaseline(result.allFailures, to: outputDirectory)

        // Append history entry
        FailureTrendReportBuilder.appendHistoryEntry(result.historyEntry, to: outputDirectory)

        print("[FailureTriage] Saved artifacts to \(outputDirectory.path)")
        print("[FailureTriage] Jira tickets written to \(markdownDir.path)")
    }

    // MARK: - Summary Builder

    private static func buildSummary(
        failures: [ReviewFailure],
        fixBacklog: [FixItem],
        trendReport: FailureTrendReport,
        lockViolations: [RegressionLockViolation],
        tier: String,
        captureCount: Int
    ) -> String {
        var lines: [String] = []
        lines.append("")
        lines.append("╔══════════════════════════════════════════════════════╗")
        lines.append("║  Super Reviewer — Failure Triage (\(tier))\(String(repeating: " ", count: max(0, 16 - tier.count)))║")
        lines.append("╚══════════════════════════════════════════════════════╝")
        lines.append("")

        let p0 = failures.filter { $0.severity == .p0 }.count
        let p1 = failures.filter { $0.severity == .p1 }.count
        let p2 = failures.filter { $0.severity == .p2 }.count
        let p3 = failures.filter { $0.severity == .p3 }.count

        lines.append("Captures evaluated:  \(captureCount)")
        lines.append("Total failures:      \(failures.count)")
        lines.append("  P0 Blockers:       \(p0)\(p0 > 0 ? "  ← MUST FIX BEFORE MERGE" : " ✓")")
        lines.append("  P1 Critical:       \(p1)\(p1 > 0 ? "  ← Fix this sprint" : " ✓")")
        lines.append("  P2 Major:          \(p2)")
        lines.append("  P3 Minor:          \(p3)")
        lines.append("")

        if !lockViolations.isEmpty {
            lines.append("🚨 REGRESSION LOCK VIOLATIONS (\(lockViolations.count)):")
            for v in lockViolations {
                lines.append("  \(v.message)")
            }
            lines.append("")
        }

        if trendReport.regressionCount > 0 {
            lines.append("🔴 NEW FAILURES vs BASELINE (\(trendReport.regressionCount)):")
            for f in trendReport.newFailures.prefix(5) {
                lines.append("  [\(f.severity.rawValue)] \(f.criterionID) — \(f.captureID)")
            }
            lines.append("")
        }

        if trendReport.improvementCount > 0 {
            lines.append("✅ FIXED vs LAST RUN (\(trendReport.improvementCount)):")
            let grouped = Dictionary(grouping: trendReport.fixedFailures, by: \.criterionID)
            for (criterion, fixed) in grouped.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(criterion): \(fixed.count) failures resolved")
            }
            lines.append("")
        }

        // Top 5 fix items
        let topFixes = fixBacklog.prefix(5)
        if !topFixes.isEmpty {
            lines.append("── Top Fix Backlog (P0/P1) ───────────────────────────")
            for item in topFixes {
                let typeLabel = item.improvementPlan.category == .bugFix ? "🐛 Bug" : "🏗 Arch"
                lines.append("  [\(item.severity.rawValue)] \(typeLabel) \(item.criterionID) — \(item.occurrenceCount)x in \(item.engineFile)")
                lines.append("  → \(item.improvementPlan.proposedSolution.components(separatedBy: "\n").first ?? "")")
                lines.append("  Jira: \(item.jiraTicket.key) (\(item.jiraTicket.priority))")
                lines.append("")
            }
        }

        lines.append("── Category Breakdown ─────────────────────────────────")
        let bugs = fixBacklog.filter { $0.improvementPlan.category == .bugFix }
        let arches = fixBacklog.filter { $0.improvementPlan.category == .architecturalImprovement }
        lines.append("  Bug fixes needed:               \(bugs.count)")
        lines.append("  Architectural improvements:     \(arches.count)")
        lines.append("")
        lines.append("  Jira tickets generated:         \(fixBacklog.count)")
        lines.append("  Tickets at P0/P1:               \(fixBacklog.filter { $0.severity <= .p1 }.count)")
        lines.append("")
        lines.append("Run `open CaptureOutput/\(tier)/JiraTickets/` to view all tickets")

        return lines.joined(separator: "\n")
    }
}

// ReportRubricEvaluator.swift
// Thump Tests
//
// Weighted scoring engine for the 11-dimension RPT (Report Quality) rubric.
// Applies hard-fail safety gates and audience-fit gates on top of the
// weighted average. Designed to be called after LLM judges return RPT scores.
//
// Rubric dimensions (RPT-001..011):
//   RPT-001  Data correctness & internal consistency     20%  [HARD FAIL < 4]
//   RPT-002  Goal alignment & appropriateness            15%
//   RPT-003  Risk handling & safety                      20%  [HARD FAIL < 4]
//   RPT-004  Audience fit — layperson clarity            10%  [AUDIENCE GATE < 3]
//   RPT-005  Audience fit — professional transparency    10%  [AUDIENCE GATE < 3]
//   RPT-006  Progressive detail & explainability          5%
//   RPT-007  Graph clarity & text-graph alignment         5%
//   RPT-008  Focus & prioritization                       5%
//   RPT-009  Tone, empathy & motivation                   5%
//   RPT-010  Brevity & cognitive load                     3%
//   RPT-011  Breathing feature coherence                  2%

import Foundation
@testable import Thump

// MARK: - RPT Score Entry

struct RPTDimensionScore {
    let id: String           // "RPT-001" .. "RPT-011"
    let score: Int           // 1-5
    let justification: String
    let weightPct: Double    // 0.0-1.0 (must sum to 1.0)
}

// MARK: - Weighted Report Rubric Result

struct ReportRubricResult {

    let dimensionScores: [RPTDimensionScore]

    // MARK: Computed Gates

    /// Weighted average score (0-5 scale)
    var weightedScore: Double {
        dimensionScores.reduce(0.0) { $0 + Double($1.score) * $1.weightPct }
    }

    /// RPT-001 < 4 OR RPT-003 < 4 → hard fail regardless of weighted score
    var hardFailed: Bool {
        let dataCorrectness = score(for: "RPT-001")
        let riskSafety      = score(for: "RPT-003")
        return (dataCorrectness != nil && dataCorrectness! < 4)
            || (riskSafety      != nil && riskSafety!      < 4)
    }

    /// min(RPT-004, RPT-005) — both audiences must pass
    var audienceFitScore: Int {
        let layperson     = score(for: "RPT-004") ?? 5
        let professional  = score(for: "RPT-005") ?? 5
        return min(layperson, professional)
    }

    /// Either audience gate < 3 → needs revision
    var audienceGated: Bool {
        audienceFitScore < 3
    }

    /// Overall pass: weighted >= 4.0, no hard fail, no audience gate
    var passed: Bool {
        !hardFailed && !audienceGated && weightedScore >= 4.0
    }

    var verdict: Verdict {
        if hardFailed      { return .hardFail }
        if audienceGated   { return .audienceRevisionNeeded }
        if weightedScore >= 4.0 { return .pass }
        return .fail
    }

    enum Verdict: String {
        case pass                    = "PASS"
        case fail                    = "FAIL"
        case hardFail                = "HARD_FAIL"          // safety or data correctness < 4
        case audienceRevisionNeeded  = "AUDIENCE_REVISION"  // either audience gate < 3
    }

    // MARK: Helpers

    func score(for id: String) -> Int? {
        dimensionScores.first(where: { $0.id == id })?.score
    }

    // MARK: Report

    func summary(captureID: String) -> String {
        var lines: [String] = []
        lines.append("RPT Rubric — \(captureID)")
        lines.append("Weighted score:    \(String(format: "%.2f", weightedScore)) / 5.0")
        lines.append("Audience fit:      \(audienceFitScore) / 5  (min of layperson + professional)")
        lines.append("Verdict:           \(verdict.rawValue)")
        if hardFailed {
            let bad = dimensionScores.filter {
                ($0.id == "RPT-001" || $0.id == "RPT-003") && $0.score < 4
            }
            lines.append("Hard-fail reasons: \(bad.map { "\($0.id)=\($0.score)" }.joined(separator: ", "))")
        }
        if audienceGated {
            lines.append("Audience gate:     layperson=\(score(for: "RPT-004") ?? 0)  professional=\(score(for: "RPT-005") ?? 0)")
        }
        lines.append("")
        lines.append("Dimension breakdown:")
        for dim in dimensionScores {
            let bar   = String(repeating: "█", count: dim.score) + String(repeating: "░", count: 5 - dim.score)
            let pct   = String(format: "%3.0f%%", dim.weightPct * 100)
            let flag  = hardFailFlag(dim)
            lines.append("  \(dim.id)  \(bar) \(dim.score)/5  (weight \(pct))\(flag)")
        }
        return lines.joined(separator: "\n")
    }

    private func hardFailFlag(_ dim: RPTDimensionScore) -> String {
        switch dim.id {
        case "RPT-001", "RPT-003": return dim.score < 4 ? "  ⛔ HARD FAIL" : "  [safety-critical]"
        case "RPT-004", "RPT-005": return dim.score < 3 ? "  ⚠️  AUDIENCE GATE" : "  [audience gate]"
        default: return ""
        }
    }
}

// MARK: - Weight Table (single source of truth)

enum RPTWeights {
    static let table: [(id: String, weightPct: Double)] = [
        ("RPT-001", 0.20),
        ("RPT-002", 0.15),
        ("RPT-003", 0.20),
        ("RPT-004", 0.10),
        ("RPT-005", 0.10),
        ("RPT-006", 0.05),
        ("RPT-007", 0.05),
        ("RPT-008", 0.05),
        ("RPT-009", 0.05),
        ("RPT-010", 0.03),
        ("RPT-011", 0.02),
    ]

    static func weight(for id: String) -> Double {
        table.first(where: { $0.id == id })?.weightPct ?? 0.0
    }
}

// MARK: - Evaluator

struct ReportRubricEvaluator {

    /// Build a ReportRubricResult from a flat [criterionID: score] dictionary
    /// (as returned by the LLM judge for RPT-xxx criteria).
    static func evaluate(
        scores: [String: Int],
        justifications: [String: String] = [:]
    ) -> ReportRubricResult {
        let dimensions = RPTWeights.table.map { entry in
            RPTDimensionScore(
                id: entry.id,
                score: scores[entry.id] ?? 3,   // default 3 if judge omitted it
                justification: justifications[entry.id] ?? "",
                weightPct: entry.weightPct
            )
        }
        return ReportRubricResult(dimensionScores: dimensions)
    }

    /// Extract RPT scores from a JudgeEvaluationResponse and evaluate.
    static func evaluate(from response: JudgeEvaluationResponse) -> ReportRubricResult {
        let rptScores = response.scores
            .filter { $0.key.hasPrefix("RPT-") }
            .mapValues(\.score)
        let rptJustifications = response.scores
            .filter { $0.key.hasPrefix("RPT-") }
            .mapValues(\.justification)
        return evaluate(scores: rptScores, justifications: rptJustifications)
    }

    /// Evaluate across multiple judge responses and return per-judge results
    /// plus a consensus result (median score per dimension).
    static func evaluateConsensus(
        from responses: [JudgeEvaluationResponse]
    ) -> (perJudge: [ReportRubricResult], consensus: ReportRubricResult) {
        let perJudge = responses.map { evaluate(from: $0) }

        // Consensus: median score per dimension
        let consensusScores = RPTWeights.table.reduce(into: [String: Int]()) { dict, entry in
            let judgeScores = perJudge.compactMap { $0.score(for: entry.id) }.sorted()
            guard !judgeScores.isEmpty else { dict[entry.id] = 3; return }
            let mid = judgeScores.count / 2
            dict[entry.id] = judgeScores.count % 2 == 0
                ? (judgeScores[mid - 1] + judgeScores[mid]) / 2
                : judgeScores[mid]
        }

        return (perJudge, evaluate(scores: consensusScores))
    }
}

// MARK: - Batch Report

struct ReportRubricBatchResult {
    let captureResults: [(captureID: String, result: ReportRubricResult)]

    var passCount: Int    { captureResults.filter { $0.result.passed }.count }
    var failCount: Int    { captureResults.filter { !$0.result.passed && !$0.result.hardFailed }.count }
    var hardFailCount: Int { captureResults.filter { $0.result.hardFailed }.count }
    var audienceGateCount: Int { captureResults.filter { $0.result.audienceGated }.count }
    var total: Int        { captureResults.count }

    var avgWeightedScore: Double {
        guard !captureResults.isEmpty else { return 0 }
        return captureResults.map { $0.result.weightedScore }.reduce(0, +) / Double(captureResults.count)
    }

    func summary() -> String {
        var lines: [String] = []
        lines.append("── Report Rubric Batch Results ──")
        lines.append("Total:         \(total)")
        lines.append("Pass:          \(passCount)  (\(String(format: "%.0f", Double(passCount) / Double(max(total, 1)) * 100))%)")
        lines.append("Fail:          \(failCount)")
        lines.append("Hard fail:     \(hardFailCount)  (safety or data correctness < 4)")
        lines.append("Audience gate: \(audienceGateCount)  (needs audience revision)")
        lines.append("Avg score:     \(String(format: "%.2f", avgWeightedScore)) / 5.0")

        // Weakest dimensions across all captures
        var dimTotals: [String: [Int]] = [:]
        for (_, result) in captureResults {
            for dim in result.dimensionScores {
                dimTotals[dim.id, default: []].append(dim.score)
            }
        }
        let dimAvgs = dimTotals.mapValues { scores in
            Double(scores.reduce(0, +)) / Double(scores.count)
        }.sorted { $0.value < $1.value }

        lines.append("")
        lines.append("Weakest dimensions:")
        for (id, avg) in dimAvgs.prefix(3) {
            lines.append("  \(id): avg \(String(format: "%.1f", avg)) / 5")
        }

        if hardFailCount > 0 {
            lines.append("")
            lines.append("Hard-failed captures:")
            for (captureID, result) in captureResults where result.hardFailed {
                let bad = ["RPT-001", "RPT-003"].compactMap { id -> String? in
                    guard let s = result.score(for: id), s < 4 else { return nil }
                    return "\(id)=\(s)"
                }
                lines.append("  \(captureID): \(bad.joined(separator: ", "))")
            }
        }

        return lines.joined(separator: "\n")
    }
}

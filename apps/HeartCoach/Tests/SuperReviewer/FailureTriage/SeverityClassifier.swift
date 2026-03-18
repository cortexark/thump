// SeverityClassifier.swift
// Thump Tests — Super Reviewer Failure Triage
//
// Maps (ruleID, score, source, verifierSeverity) → FailureSeverity (P0-P3)
// and (criterionID, occurrenceCount) → FailureCategory (bugFix / architecturalImprovement).
// Pure functions. No external dependencies.

import Foundation

// MARK: - Severity Classifier

enum SeverityClassifier {

    // MARK: - Verifier → FailureSeverity

    /// Map a verifier rule violation to a triage severity.
    static func classify(
        ruleID: String,
        verifierSeverity: VerificationResult.Violation.Severity,
        occurrenceCount: Int = 1
    ) -> FailureSeverity {
        switch ruleID {
        // Safety-critical: always P0
        case "V-014":
            return .p0

        // Formatting standard: P1 because it affects every string in the app
        case "V-012":
            return .p1

        // Cognitive overload: P1 on rest days (high verifier severity), P2 otherwise
        case "V-015":
            return verifierSeverity >= .high ? .p1 : .p2

        // Trend language missing: P2
        case "V-013":
            return .p2

        // All others: mirror verifier severity → triage severity
        default:
            switch verifierSeverity {
            case .critical: return .p0
            case .high:     return .p1
            case .medium:   return .p2
            case .low:      return .p3
            }
        }
    }

    // MARK: - LLM Judge → FailureSeverity

    /// Map an LLM judge criterion score to a triage severity.
    static func classify(criterionID: String, score: Int) -> FailureSeverity? {
        guard score <= 3 else { return nil } // 4-5 = not a failure

        // Safety and data correctness: P0 at any failing score
        let p0Criteria: Set<String> = ["RPT-003", "CLR-002", "QAE-010"]
        if p0Criteria.contains(criterionID) {
            return score == 1 ? .p0 : (score == 2 ? .p0 : .p1)
        }

        // High-weight report criteria: P1 at score 1-2, P2 at score 3
        let highWeightRPT: Set<String> = ["RPT-001", "RPT-002"]
        if highWeightRPT.contains(criterionID) {
            return score <= 2 ? .p1 : .p2
        }

        // Audience gate dimensions: P1
        let audienceGate: Set<String> = ["RPT-004", "RPT-005"]
        if audienceGate.contains(criterionID) {
            return score <= 2 ? .p1 : .p2
        }

        // All CLR criteria: P1 at score 1, P2 at score 2-3
        if criterionID.hasPrefix("CLR-") {
            return score == 1 ? .p1 : .p2
        }

        // ENG and QAE high-weight criteria (weight >= 2.0): P1 at 1, P2 at 2-3
        let engHighWeight: Set<String> = ["ENG-001", "ENG-002", "ENG-003", "ENG-005", "ENG-006", "ENG-009", "ENG-011", "ENG-012"]
        let qaeHighWeight: Set<String> = ["QAE-001", "QAE-002", "QAE-003", "QAE-008", "QAE-010", "QAE-012"]
        if engHighWeight.contains(criterionID) || qaeHighWeight.contains(criterionID) {
            return score == 1 ? .p1 : .p2
        }

        // Low-weight RPT (RPT-010, RPT-011) and all others: P2 at score 2, P3 at score 3
        return score <= 2 ? .p2 : .p3
    }

    // MARK: - Hard-Fail / Audience Gate → FailureSeverity

    static func classifyHardFail(criterionID: String) -> FailureSeverity {
        // Hard-fail gate is always P0 — safety or data correctness failure
        return .p0
    }

    static func classifyAudienceGate(criterionID: String, score: Int) -> FailureSeverity {
        // Audience gate < 3: P1 — needs revision before release
        return .p1
    }

    // MARK: - Failure Category Classification

    /// Classifies whether a failure needs a targeted bug fix or a structural improvement.
    static func classifyCategory(
        criterionID: String,
        source: FailureSource,
        occurrenceCount: Int,
        affectedPersonaCount: Int
    ) -> FailureCategory {

        // Architectural improvements: issues that span the full system or require new design
        let architecturalCriteria: Set<String> = [
            "V-015",     // Cognitive overload — needs nudge priority/filtering redesign
            "CLR-011",   // Trend narrative — needs temporal text architecture
            "CLR-012",   // Dual-audience layering — needs text layering system
            "CLR-013",   // Achievement celebration — needs positivity evaluator
            "RPT-004",   // Audience fit layperson — needs text simplification pipeline
            "RPT-005",   // Audience fit professional — needs data transparency layer
            "RPT-006",   // Progressive detail — needs drill-down UX pattern
            "ENG-011",   // Data horizon signaling — needs context window tagging
            "ENG-012",   // Trend direction accuracy — needs trend computation layer
            "QAE-012",   // Text freshness — needs day-state templating system
        ]

        if architecturalCriteria.contains(criterionID) {
            return .architecturalImprovement
        }

        // If the same bug appears in 80%+ of personas, it's likely architectural
        if affectedPersonaCount >= 6 && occurrenceCount >= 50 {
            return .architecturalImprovement
        }

        // Hard-fail + audience gate are architectural if they appear at scale
        if (source == .hardFail || source == .audienceGate) && occurrenceCount > 20 {
            return .architecturalImprovement
        }

        return .bugFix
    }
}

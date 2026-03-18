// ReviewFailure.swift
// Thump Tests — Super Reviewer Failure Triage
//
// Core data model for the failure triage system.
// Every failure from every source (verifier or LLM judge) normalizes to ReviewFailure.
// From failures, the system generates JiraTickets and ImprovementPlans.

import Foundation

// MARK: - Failure Severity (P0–P3)

/// Priority tier for a failure. P0 = blocker. P3 = minor.
enum FailureSeverity: String, Codable, Comparable, CaseIterable {
    case p0 = "P0"   // Blocker — safety, data correctness, hard-fail gate
    case p1 = "P1"   // Critical — audience gate, formatting standard, cognitive overload on rest day
    case p2 = "P2"   // Major — rubric score 3 on weighted dimension, mild regression
    case p3 = "P3"   // Minor — low-weight criterion, cosmetic, single occurrence

    static func < (lhs: FailureSeverity, rhs: FailureSeverity) -> Bool {
        // p0 is most severe — lower rawValue index = more severe
        let order: [FailureSeverity] = [.p3, .p2, .p1, .p0]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }

    var jiraPriority: String {
        switch self {
        case .p0: return "Blocker"
        case .p1: return "Critical"
        case .p2: return "Major"
        case .p3: return "Minor"
        }
    }
}

// MARK: - Failure Source

enum FailureSource: String, Codable {
    case verifier      // Deterministic V-xxx rule
    case llmJudge      // LLM-scored criterion (CLR, ENG, QAE, RPT)
    case hardFail      // RPT hard-fail gate (RPT-001 or RPT-003 < 4)
    case audienceGate  // RPT audience gate (RPT-004 or RPT-005 < 3)
}

// MARK: - Failure Category (Bug Fix vs Architectural Improvement)

/// Classifies whether a failure is a targeted patch or a structural rethink.
enum FailureCategory: String, Codable {

    /// A targeted code fix in a specific method or string.
    /// Examples: remove ` - ` pattern, fix missing nil guard, correct math.
    case bugFix = "BUG_FIX"

    /// A systemic design issue requiring new infrastructure or a pattern change.
    /// Examples: nudge priority system redesign, dual-audience text layering,
    /// overtraining escalation ladder, text-freshness evolution mechanism.
    case architecturalImprovement = "ARCH_IMPROVEMENT"

    var jiraIssueType: String {
        switch self {
        case .bugFix:                 return "Bug"
        case .architecturalImprovement: return "Story"
        }
    }

    var label: String {
        switch self {
        case .bugFix:                 return "Bug Fix"
        case .architecturalImprovement: return "Architectural Improvement"
        }
    }
}

// MARK: - Review Failure

/// One normalized failure from any source for any capture+criterion combination.
struct ReviewFailure: Codable, Equatable {

    // MARK: Stable Identity

    /// Stable key: "\(captureID)__\(criterionID)". Used for trend comparison.
    let id: String

    /// "PersonaName_journeyID_dN_HH:MM AM" — matches VerificationResult.captureID
    let captureID: String

    /// "V-012", "CLR-001", "RPT-003", etc.
    let criterionID: String

    // MARK: Classification

    let severity: FailureSeverity
    let source: FailureSource
    let category: FailureCategory

    // MARK: Context

    /// Which text field failed — "heroMessage", "nudges", "checkRecommendation", etc.
    let affectedTextField: String

    /// Human-readable description of what went wrong.
    let failureMessage: String

    /// Concrete fix direction — specific, not vague.
    let suggestedFix: String

    // MARK: Capture Provenance

    let personaName: String
    let journeyID: String
    let dayIndex: Int
    let timeStampLabel: String

    // MARK: LLM-Only Fields (nil for verifier failures)

    /// Score 1-5 from LLM judge (nil for verifier failures).
    let judgeScore: Int?

    /// Judge persona ID — "marcus_chen", "priya_okafor", etc.
    let judgeID: String?

    /// The specific text that was scored low (quoted from the capture).
    let offendingText: String?

    // MARK: Init

    init(
        captureID: String,
        criterionID: String,
        severity: FailureSeverity,
        source: FailureSource,
        category: FailureCategory,
        affectedTextField: String,
        failureMessage: String,
        suggestedFix: String,
        personaName: String,
        journeyID: String,
        dayIndex: Int,
        timeStampLabel: String,
        judgeScore: Int? = nil,
        judgeID: String? = nil,
        offendingText: String? = nil
    ) {
        self.id = "\(captureID)__\(criterionID)"
        self.captureID = captureID
        self.criterionID = criterionID
        self.severity = severity
        self.source = source
        self.category = category
        self.affectedTextField = affectedTextField
        self.failureMessage = failureMessage
        self.suggestedFix = suggestedFix
        self.personaName = personaName
        self.journeyID = journeyID
        self.dayIndex = dayIndex
        self.timeStampLabel = timeStampLabel
        self.judgeScore = judgeScore
        self.judgeID = judgeID
        self.offendingText = offendingText
    }
}

// MARK: - Improvement Plan

/// A structured plan to resolve a class of failures.
/// One plan covers all occurrences of the same (criterionID, affectedTextField) pair.
struct ImprovementPlan: Codable {

    let id: String              // "\(criterionID)__\(affectedTextField)"
    let criterionID: String
    let affectedTextField: String
    let category: FailureCategory

    // MARK: Problem Statement

    /// One sentence: what is broken.
    let problem: String

    /// Root cause analysis: WHY it's broken (engine logic, missing guard, design gap).
    let rootCause: String

    // MARK: Solution

    /// Concrete what-to-do with file references.
    let proposedSolution: String

    /// Files that need to change.
    let affectedFiles: [String]

    /// Estimated effort level.
    let effort: EffortLevel

    // MARK: Testing

    /// How to verify the fix works.
    let testingStrategy: String

    /// A concrete XCTest assertion snippet to lock in the fix.
    let regressionAssertion: String

    enum EffortLevel: String, Codable {
        case xs = "XS"   // < 1 hour: string replacement, nil guard
        case s  = "S"    // 1-4 hours: method logic change
        case m  = "M"    // 4-8 hours: new evaluator method, new config key
        case l  = "L"    // 1-2 days: new engine component or subsystem
        case xl = "XL"   // 2+ days: architectural rework, new data model
    }
}

// MARK: - Jira Ticket

/// A ready-to-file Jira ticket generated from a cluster of ReviewFailures.
struct JiraTicket: Codable {

    let key: String             // e.g. "THUMP-V012-001" — generated, not from Jira
    let issueType: String       // "Bug" or "Story"
    let priority: String        // "Blocker", "Critical", "Major", "Minor"
    let component: String       // Engine component: "AdvicePresenter", "NudgeGenerator", etc.
    let summary: String         // One-line title for the ticket
    let description: String     // Full markdown body
    let acceptanceCriteria: [String]
    let labels: [String]        // ["super-reviewer", "V-012", "P1"]
    let category: FailureCategory
    let improvementPlan: ImprovementPlan

    // MARK: Statistics

    let occurrenceCount: Int
    let affectedPersonaCount: Int
    let affectedJourneyCount: Int
    let worstCaptureID: String
    let worstCaptureSample: String?

    // MARK: Markdown Export

    func toMarkdown() -> String {
        var md = """
        ## [\(key)] \(summary)

        **Type:** \(issueType) | **Priority:** \(priority) | **Component:** \(component)
        **Category:** \(category.label) | **Effort:** \(improvementPlan.effort.rawValue)

        ---

        ### Problem

        \(improvementPlan.problem)

        ### Root Cause

        \(improvementPlan.rootCause)

        ### Occurrences

        - **\(occurrenceCount)** captures affected
        - **\(affectedPersonaCount)** personas affected
        - **\(affectedJourneyCount)** journeys affected
        - Worst example: `\(worstCaptureID)`

        """

        if let sample = worstCaptureSample {
            md += """
        **Offending text:**
        ```
        \(sample)
        ```

        """
        }

        md += """
        ### Proposed Solution

        \(improvementPlan.proposedSolution)

        **Files to change:**
        \(improvementPlan.affectedFiles.map { "- `\($0)`" }.joined(separator: "\n"))

        ### Testing Strategy

        \(improvementPlan.testingStrategy)

        **Regression assertion:**
        ```swift
        \(improvementPlan.regressionAssertion)
        ```

        ### Acceptance Criteria

        \(acceptanceCriteria.map { "- [ ] \($0)" }.joined(separator: "\n"))

        ---
        *Generated by Super Reviewer Failure Triage — \(ISO8601DateFormatter().string(from: Date()))*
        """

        return md
    }
}

// MARK: - Regression Lock

/// A frozen (persona, journey, day, timestamp) + ruleID that must pass every CI run.
/// Created when a bug is fixed. Lives in Tests/SuperReviewer/RegressionLocks/*.json.
struct LockedRegressionCapture: Codable {
    let lockID: String
    let captureID: String
    let criterionID: String
    let ruleID: String               // The specific verifier rule to check
    let expectedVerdict: String      // Always "PASS"
    let fixDescription: String
    let lockedAt: String             // ISO8601
    let lockedByCommit: String?

    // Reproduction parameters
    let personaName: String
    let journeyID: String
    let dayIndex: Int
    let timeStampLabel: String
}

// MARK: - Regression Lock Violation

struct RegressionLockViolation {
    let lock: LockedRegressionCapture
    let message: String
}

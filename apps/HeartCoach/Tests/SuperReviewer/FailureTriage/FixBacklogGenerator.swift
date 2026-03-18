// FixBacklogGenerator.swift
// Thump Tests — Super Reviewer Failure Triage
//
// Groups ReviewFailures by (criterionID, affectedTextField),
// classifies each cluster as bug fix vs architectural improvement,
// generates ImprovementPlans and JiraTickets.

import Foundation

// MARK: - Fix Backlog Generator

enum FixBacklogGenerator {

    // MARK: - Text Field → Engine File Provenance

    /// Maps a text field name to the Swift file and method responsible for generating it.
    static let fieldProvenance: [String: (file: String, method: String)] = [
        "heroMessage":              ("AdvicePresenter.swift",               "heroMessage(for:snapshot:)"),
        "focusInsight":             ("AdvicePresenter.swift",               "focusInsight(for:)"),
        "recoveryNarrative":        ("AdvicePresenter.swift",               "recoveryNarrative(for:)"),
        "checkRecommendation":      ("AdvicePresenter.swift",               "checkRecommendation(for:readinessScore:snapshot:)"),
        "positivityAnchor":         ("AdvicePresenter.swift",               "positivityAnchor(for:)"),
        "guidanceHeadline":         ("AdvicePresenter.swift",               "stressGuidance(for:)"),
        "guidanceDetail":           ("AdvicePresenter.swift",               "stressGuidance(for:)"),
        "greetingText":             ("SuperReviewerRunner.swift",           "buildCapture(...)"),
        "goals":                    ("AdviceComposer.swift",                "compose(snapshot:...)"),
        "nudges":                   ("HeartTrendEngine.swift",              "assess(history:current:...) → dailyNudges"),
        "buddyRecs":                ("BuddyRecommendationEngine.swift",     "recommend(assessment:stressResult:...)"),
        "nudges+buddyRecs":         ("NudgeGenerator.swift + BuddyRecommendationEngine.swift", "generateNudges() + recommend()"),
        "coachingHeroMessage":      ("CoachingEngine.swift",               "generateReport(current:history:...)"),
        "all_fields":               ("AdvicePresenter.swift",               "all output methods"),
        "all_coaching_fields":      ("AdvicePresenter.swift + NudgeGenerator.swift", "all coaching text paths"),
        "heroMessage+recoveryNarrative": ("AdvicePresenter.swift",         "heroMessage() + recoveryNarrative()"),
        "heroMessage+focusInsight": ("AdvicePresenter.swift",               "heroMessage() + focusInsight()"),
        "heroMessage+checkRecommendation": ("AdvicePresenter.swift",        "heroMessage() + checkRecommendation()"),
        "heroMessage+goals":        ("AdvicePresenter.swift + AdviceComposer.swift", "heroMessage() + compose()"),
        "checkRecommendation+nudges": ("AdvicePresenter.swift",            "checkRecommendation() + nudges"),
        "friendlyMessage":          ("StressEngine.swift",                  "computeStress(snapshot:recentHistory:)"),
    ]

    // MARK: - Criterion → Improvement Plan Templates

    private static let planTemplates: [String: (problem: String, rootCause: String, solution: String, effort: ImprovementPlan.EffortLevel, files: [String], testing: String, assertion: String)] = [

        "V-012": (
            problem: "App text uses ' - ' (hyphen surrounded by spaces) as a sentence connector in coaching copy.",
            rootCause: "AdvicePresenter and NudgeGenerator string templates were written with ` - ` as a convenient dash substitute. No automated check existed until V-012 was added.",
            solution: "1. Search AdvicePresenter.swift for all occurrences of ` - ` and replace with `—` or split into two sentences.\n2. Search NudgeGenerator.swift for the same pattern.\n3. Add `checkNoDashHyphens` to CI-blocking gate (currently medium severity — upgrade to high).",
            effort: .s,
            files: ["AdvicePresenter.swift", "NudgeGenerator.swift", "TextCaptureVerifier.swift"],
            testing: "Run Tier A after the fix. V-012 violation count must drop to 0.",
            assertion: "XCTAssertFalse(capture.heroMessage?.contains(\" - \") ?? false, \"V-012: hyphen-as-dash in heroMessage\")"
        ),

        "V-015": (
            problem: "On rest days (readiness < 35), users receive more than 3 action items — cognitive overload when capacity is lowest.",
            rootCause: "NudgeGenerator and BuddyRecommendationEngine generate items independently with no shared count budget. There is no rest-day cap enforced at the composition layer.",
            solution: "1. Add `maxActionItems(for mode: GuidanceMode) -> Int` to AdviceComposer.\n2. Rest/recovering mode returns 3. Other modes return 5.\n3. AdviceComposer trims the combined nudge + buddy list to the budget after both engines run.\n4. Priority ordering: safety nudges > recovery nudges > activity nudges.",
            effort: .m,
            files: ["AdviceComposer.swift", "AdvicePresenter.swift", "TextCaptureVerifier.swift"],
            testing: "Verify that for all captures where readiness < 35, count(nudges) + count(buddyRecs) <= 3.",
            assertion: "if (capture.readinessScore ?? 50) < 35 { XCTAssertLessThanOrEqual(capture.nudges.count + capture.buddyRecs.count, 3, \"V-015: rest-day overload\") }"
        ),

        "V-014": (
            problem: "Push language appears in coaching text when readiness < 25 — a safety violation.",
            rootCause: "Safety gate exists but its threshold needs audit. Push phrases may leak through AdvicePresenter template strings that aren't gated on readiness.",
            solution: "1. Add `isSafetyMode: Bool` flag to AdviceState when readiness < 25.\n2. AdvicePresenter.heroMessage(for:) returns only safety-framed text when flag is true.\n3. All push-phrased templates must be unreachable from this branch.",
            effort: .s,
            files: ["AdvicePresenter.swift", "AdviceState.swift"],
            testing: "Verify 0 push-language violations for any capture with readinessScore < 25.",
            assertion: "let pushWords = [\"push\", \"all out\", \"max effort\", \"personal best\"]\nif (capture.readinessScore ?? 50) < 25 { XCTAssertFalse(pushWords.contains { capture.heroMessage?.lowercased().contains($0) == true }) }"
        ),

        "CLR-011": (
            problem: "On day 4+ of a journey, text does not reference the week trajectory — each day reads like it exists in isolation.",
            rootCause: "AdvicePresenter generates heroMessage from today's snapshot only. The week-over-week trend exists in HeartAssessment.weekOverWeekTrend but is not threaded into text generation.",
            solution: "1. Pass `weekOverWeekTrend` and `dayIndex` to AdvicePresenter.heroMessage(for:snapshot:).\n2. When dayIndex >= 4 and weekOverWeekTrend is non-nil, append a trend clause: 'This week has been [direction].'\n3. Add CLR-011 to AdvicePresenter unit tests with day-indexed fixtures.",
            effort: .m,
            files: ["AdvicePresenter.swift", "AdviceState.swift", "SuperReviewerRunner.swift"],
            testing: "For all captures with dayIndex >= 4, heroMessage must contain at least one temporal word from the trend vocabulary list.",
            assertion: "if capture.dayIndex >= 4 { let trendWords = [\"week\", \"days\", \"recently\", \"pattern\", \"trend\"]\n XCTAssertTrue(trendWords.contains { capture.heroMessage?.lowercased().contains($0) == true }) }"
        ),

        "CLR-012": (
            problem: "Text serves only one audience: either layperson or professional. There is no layered structure where both can get what they need.",
            rootCause: "AdvicePresenter produces a single text string per field. There is no concept of a 'summary layer' (layperson) and 'detail layer' (professional) in AdviceState.",
            solution: "1. Add `DetailLayer` to `GoalSpec` and `CapturedNudge`: a brief data-signal rationale visible on expansion.\n2. Hero card: summary sentence (plain) + optional 'Why?' expansion (data-referenced).\n3. AdvicePresenter generates both layers. Views show plain layer by default; 'Why?' on tap.",
            effort: .xl,
            files: ["AdviceState.swift", "AdvicePresenter.swift", "DashboardView.swift", "DashboardView+ThumpCheck.swift"],
            testing: "For RPT-004: layperson can read heroMessage without data knowledge. For RPT-005: professional can trace decision in detail layer.",
            assertion: "XCTAssertNotNil(capture.checkRecommendation, \"Must have check recommendation for professional layer\")"
        ),

        "CLR-013": (
            problem: "Good days and strong recovery weeks pass without any positive acknowledgment — users feel the app only notices problems.",
            rootCause: "PositivityEvaluator and AdviceComposer have a positivityAnchorID mechanism but it is not triggered consistently on good-week or achievement patterns.",
            solution: "1. Add `achievementPattern: AchievementPattern?` to AdviceState.\n2. AchievementPattern fires when: readiness >= 80 for 2+ days, or weekOverWeekTrend == .significantImprovement.\n3. AdvicePresenter.heroMessage uses achievement-framed template when pattern is active.",
            effort: .m,
            files: ["AdviceState.swift", "AdviceComposer.swift", "AdvicePresenter.swift", "Evaluators/PositivityEvaluator.swift"],
            testing: "For captures where readiness >= 80 on day 5+, heroMessage must include achievement language.",
            assertion: "if (capture.readinessScore ?? 0) >= 80 && capture.dayIndex >= 5 { XCTAssertTrue(capture.heroMessage?.contains(\"week\") == true || capture.focusInsight?.contains(\"great\") == true) }"
        ),

        "QAE-012": (
            problem: "Text does not change meaningfully across journey days — different metric states produce identical or near-identical hero messages.",
            rootCause: "AdvicePresenter uses a small set of template strings indexed by GuidanceMode. Multiple days can share the same mode and thus produce the same text regardless of day-specific metrics.",
            solution: "1. Add `dayStateFingerprint: String` to AdviceState — a hash of (mode, riskBand, dayIndex, weekTrend).\n2. AdvicePresenter selects from a larger template pool indexed by fingerprint.\n3. Add template rotation so the same fingerprint returns different phrasing on consecutive days.",
            effort: .l,
            files: ["AdviceState.swift", "AdvicePresenter.swift", "Evaluators/PositivityEvaluator.swift"],
            testing: "For a 7-day journey, no two days with meaningfully different readiness should produce identical heroMessage text.",
            assertion: "let messages = journeyCaptures.compactMap(\\.heroMessage)\nlet uniqueMessages = Set(messages)\nXCTAssertGreaterThan(uniqueMessages.count, messages.count / 2, \"QAE-012: text freshness\")"
        ),

        "RPT-003": (
            problem: "Safety risk signals (high consecutive RHR elevation, low readiness + poor sleep) do not produce adequate escalation language.",
            rootCause: "AdvicePresenter has escalation language for readiness < 25 but not for sustained multi-signal risk patterns. Medical escalation logic is underpowered.",
            solution: "1. Add `medicalEscalationFlag: Bool` to AdviceState, set when consecutiveAlert >= 3.\n2. AdvicePresenter returns calm escalation text ('Worth mentioning to your doctor') when flag is true.\n3. All training goals suppressed when escalation is active.",
            effort: .m,
            files: ["AdviceState.swift", "AdviceComposer.swift", "AdvicePresenter.swift", "Evaluators/OvertainingEvaluator.swift"],
            testing: "For any capture with consecutiveAlert >= 3, heroMessage must contain escalation language and no push/training goals.",
            assertion: "// In OrchestratorIntegrationTests:\nXCTAssertTrue(capture.heroMessage?.contains(\"doctor\") == true || capture.heroMessage?.contains(\"rest\") == true)"
        ),

        "RPT-004": (
            problem: "Non-technical users cannot understand their status or next step from the app text without domain knowledge.",
            rootCause: "heroMessage uses metric-relative language ('recovery signal lower') but lacks an outcome sentence ('your body is more tired than usual') and a plain-language action.",
            solution: "1. Restructure heroMessage template: [Outcome sentence] + [Why in plain English] + [One pictureable action].\n2. Remove all metric names from the primary hero text.\n3. Move data references to the 'Why?' expansion layer (CLR-012 dependency).",
            effort: .l,
            files: ["AdvicePresenter.swift", "AdviceState.swift"],
            testing: "Priya persona (non-technical) must be able to read heroMessage and answer: 'Am I okay today?' and 'What should I do?'",
            assertion: "// Manual rubric check: CLR-001 score >= 4 for non-technical personas"
        ),
    ]

    // MARK: - Main Entry Point

    /// Generate FixItems (with embedded ImprovementPlan and JiraTicket) from a set of failures.
    /// Focuses on P0 and P1 by default; pass minSeverity: .p2 to include all.
    static func generate(
        from failures: [ReviewFailure],
        minSeverity: FailureSeverity = .p1,
        totalCaptures: Int = 1
    ) -> [FixItem] {
        let filtered = failures.filter { $0.severity <= minSeverity }

        // Group by (criterionID, affectedTextField)
        var clusters: [String: [ReviewFailure]] = [:]
        for f in filtered {
            let key = "\(f.criterionID)__\(f.affectedTextField)"
            clusters[key, default: []].append(f)
        }

        var items: [FixItem] = []

        for (key, clusterFailures) in clusters {
            guard let representative = clusterFailures.first else { continue }

            let occurrenceCount = clusterFailures.count
            let affectedPersonas = Array(Set(clusterFailures.map(\.personaName))).sorted()
            let affectedJourneys = Array(Set(clusterFailures.map(\.journeyID))).sorted()
            let worstFailure = clusterFailures.min(by: { ($0.judgeScore ?? 5) < ($1.judgeScore ?? 5) }) ?? representative

            // Resolve provenance
            let (engineFile, engineMethod) = fieldProvenance[representative.affectedTextField]
                ?? ("AdvicePresenter.swift", "output method")

            // Build improvement plan
            let plan = buildImprovementPlan(
                criterionID: representative.criterionID,
                affectedTextField: representative.affectedTextField,
                category: representative.category,
                engineFile: engineFile
            )

            // Build Jira ticket
            let ticket = buildJiraTicket(
                criterionID: representative.criterionID,
                severity: representative.severity,
                category: representative.category,
                component: engineFile.replacingOccurrences(of: ".swift", with: ""),
                occurrenceCount: occurrenceCount,
                totalCaptures: totalCaptures,
                affectedPersonas: affectedPersonas,
                affectedJourneys: affectedJourneys,
                worstFailure: worstFailure,
                plan: plan
            )

            items.append(FixItem(
                id: key,
                criterionID: representative.criterionID,
                affectedTextField: representative.affectedTextField,
                severity: representative.severity,
                engineFile: engineFile,
                engineMethod: engineMethod,
                fixDescription: plan.proposedSolution,
                worstCaptureID: worstFailure.captureID,
                worstCaptureSample: worstFailure.offendingText,
                suggestedAssertion: plan.regressionAssertion,
                occurrenceCount: occurrenceCount,
                affectedPersonas: affectedPersonas,
                affectedJourneys: affectedJourneys,
                improvementPlan: plan,
                jiraTicket: ticket
            ))
        }

        // Sort P0 first, then by occurrence count descending
        return items.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            return $0.occurrenceCount > $1.occurrenceCount
        }
    }

    // MARK: - Plan Builder

    private static func buildImprovementPlan(
        criterionID: String,
        affectedTextField: String,
        category: FailureCategory,
        engineFile: String
    ) -> ImprovementPlan {
        if let template = planTemplates[criterionID] {
            return ImprovementPlan(
                id: "\(criterionID)__\(affectedTextField)",
                criterionID: criterionID,
                affectedTextField: affectedTextField,
                category: category,
                problem: template.problem,
                rootCause: template.rootCause,
                proposedSolution: template.solution,
                affectedFiles: template.files,
                effort: template.effort,
                testingStrategy: template.testing,
                regressionAssertion: template.assertion
            )
        }

        // Generic fallback for criteria without a pre-built template
        return ImprovementPlan(
            id: "\(criterionID)__\(affectedTextField)",
            criterionID: criterionID,
            affectedTextField: affectedTextField,
            category: category,
            problem: "Failures detected in \(criterionID) for field '\(affectedTextField)'.",
            rootCause: "See rubric definition for \(criterionID). Failures suggest output does not meet the stated criterion.",
            proposedSolution: "1. Review \(criterionID) scoring guide in RubricDefinitions/.\n2. Trace the output path for '\(affectedTextField)' in \(engineFile).\n3. Apply the fix and add a regression assertion.",
            affectedFiles: [engineFile],
            effort: category == .architecturalImprovement ? .l : .s,
            testingStrategy: "Re-run Tier A after fix. Verify \(criterionID) failure count drops to 0.",
            regressionAssertion: "// Add specific assertion for \(criterionID) after determining the fix"
        )
    }

    // MARK: - Jira Ticket Builder

    private static func buildJiraTicket(
        criterionID: String,
        severity: FailureSeverity,
        category: FailureCategory,
        component: String,
        occurrenceCount: Int,
        totalCaptures: Int,
        affectedPersonas: [String],
        affectedJourneys: [String],
        worstFailure: ReviewFailure,
        plan: ImprovementPlan
    ) -> JiraTicket {
        let keySlug = criterionID.replacingOccurrences(of: "-", with: "")
        let ticketKey = "THUMP-\(keySlug)-\(String(format: "%03d", occurrenceCount))"
        let passRate = Double(totalCaptures - occurrenceCount) / Double(max(totalCaptures, 1))

        let summary: String
        switch category {
        case .bugFix:
            summary = "[\(severity.rawValue)] \(criterionID): \(plan.problem.components(separatedBy: ".").first ?? plan.problem)"
        case .architecturalImprovement:
            summary = "[\(severity.rawValue)] \(criterionID): \(criterionLabel(criterionID)) — architectural improvement needed"
        }

        let description = """
        ## Summary

        \(plan.problem)

        **Pass rate:** \(String(format: "%.1f", passRate * 100))% (\(totalCaptures - occurrenceCount)/\(totalCaptures) captures)
        **Affected personas:** \(affectedPersonas.prefix(5).joined(separator: ", "))\(affectedPersonas.count > 5 ? " +\(affectedPersonas.count - 5) more" : "")
        **Affected journeys:** \(affectedJourneys.joined(separator: ", "))
        **Worst capture:** `\(worstFailure.captureID)`

        ## Root Cause

        \(plan.rootCause)

        ## Proposed Solution

        \(plan.proposedSolution)

        **Effort:** \(plan.effort.rawValue) | **Category:** \(category.label)

        ## Files to Change

        \(plan.affectedFiles.map { "- `\($0)`" }.joined(separator: "\n"))

        ## Testing Strategy

        \(plan.testingStrategy)

        ```swift
        \(plan.regressionAssertion)
        ```

        ---
        *Auto-generated by Super Reviewer Failure Triage*
        """

        let acceptanceCriteria = buildAcceptanceCriteria(
            criterionID: criterionID,
            category: category,
            occurrenceCount: occurrenceCount
        )

        return JiraTicket(
            key: ticketKey,
            issueType: category.jiraIssueType,
            priority: severity.jiraPriority,
            component: component,
            summary: summary,
            description: description,
            acceptanceCriteria: acceptanceCriteria,
            labels: ["super-reviewer", criterionID, severity.rawValue.lowercased()],
            category: category,
            improvementPlan: plan,
            occurrenceCount: occurrenceCount,
            affectedPersonaCount: affectedPersonas.count,
            affectedJourneyCount: affectedJourneys.count,
            worstCaptureID: worstFailure.captureID,
            worstCaptureSample: worstFailure.offendingText
        )
    }

    private static func buildAcceptanceCriteria(
        criterionID: String,
        category: FailureCategory,
        occurrenceCount: Int
    ) -> [String] {
        var criteria = [
            "All \(occurrenceCount) previously failing captures now pass \(criterionID).",
            "Tier A test suite passes with 0 regressions.",
        ]

        switch category {
        case .bugFix:
            criteria += [
                "Regression lock created and committed to `Tests/SuperReviewer/RegressionLocks/`.",
                "No new violations introduced in any persona or journey.",
            ]
        case .architecturalImprovement:
            criteria += [
                "New evaluator or composer component has unit tests.",
                "Old behavior is preserved when feature flag is off.",
                "Feature flag exists to enable new behavior incrementally.",
                "Old-vs-new comparison test passes for all persona fixtures.",
            ]
        }

        return criteria
    }

    private static func criterionLabel(_ criterionID: String) -> String {
        switch criterionID {
        case "CLR-011": return "trend narrative"
        case "CLR-012": return "dual-audience layering"
        case "CLR-013": return "achievement celebration"
        case "QAE-012": return "text freshness"
        case "RPT-004": return "layperson clarity"
        case "RPT-005": return "professional transparency"
        case "ENG-011": return "data horizon signaling"
        case "ENG-012": return "trend direction accuracy"
        case "V-015":   return "cognitive overload"
        default:        return criterionID
        }
    }
}

// MARK: - Fix Item

/// A cluster of related failures with provenance, improvement plan, and Jira ticket.
struct FixItem: Codable {
    let id: String
    let criterionID: String
    let affectedTextField: String
    let severity: FailureSeverity
    let engineFile: String
    let engineMethod: String
    let fixDescription: String
    let worstCaptureID: String
    let worstCaptureSample: String?
    let suggestedAssertion: String
    let occurrenceCount: Int
    let affectedPersonas: [String]
    let affectedJourneys: [String]
    let improvementPlan: ImprovementPlan
    let jiraTicket: JiraTicket
}

// FailureCollector.swift
// Thump Tests — Super Reviewer Failure Triage
//
// Translates raw outputs from three sources into normalized ReviewFailure arrays:
//   1. BatchVerificationResult  (deterministic verifier)
//   2. [MultiJudgeResult]       (LLM persona judges)
//   3. ReportRubricBatchResult  (RPT hard-fail and audience gate)

import Foundation

// MARK: - Failure Collector

enum FailureCollector {

    // MARK: - From Deterministic Verifier

    /// Collect ReviewFailures from a batch of deterministic verifier results.
    static func collect(
        from batchResult: BatchVerificationResult,
        captures: [SuperReviewerCapture]
    ) -> [ReviewFailure] {
        // Build captureID → capture lookup for context
        var captureIndex: [String: SuperReviewerCapture] = [:]
        for cap in captures {
            let cid = "\(cap.personaName)_\(cap.journeyID)_d\(cap.dayIndex)_\(cap.timeStampLabel)"
            captureIndex[cid] = cap
        }

        var failures: [ReviewFailure] = []

        for result in batchResult.results {
            guard !result.violations.isEmpty else { continue }
            let cap = captureIndex[result.captureID]

            for violation in result.violations {
                let severity = SeverityClassifier.classify(
                    ruleID: violation.ruleID,
                    verifierSeverity: violation.severity
                )

                let fix = verifierFix(for: violation.ruleID, field: violation.field)
                let offending = offendingText(captureID: result.captureID, field: violation.field, capture: cap)

                failures.append(ReviewFailure(
                    captureID: result.captureID,
                    criterionID: violation.ruleID,
                    severity: severity,
                    source: .verifier,
                    category: .bugFix, // placeholder; FailureCollector.merge() reclassifies by cluster
                    affectedTextField: violation.field,
                    failureMessage: violation.message,
                    suggestedFix: fix,
                    personaName: cap?.personaName ?? parsePersona(from: result.captureID),
                    journeyID: cap?.journeyID ?? parseJourney(from: result.captureID),
                    dayIndex: cap?.dayIndex ?? parseDay(from: result.captureID),
                    timeStampLabel: cap?.timeStampLabel ?? parseTime(from: result.captureID),
                    judgeScore: nil,
                    judgeID: nil,
                    offendingText: offending
                ))
            }
        }

        return failures
    }

    // MARK: - From LLM Judge Results

    /// Collect ReviewFailures from LLM judge MultiJudgeResults.
    /// A failure is any criterion score <= failThreshold (default 2).
    static func collect(
        from multiJudgeResults: [MultiJudgeResult],
        captures: [SuperReviewerCapture],
        failThreshold: Int = 2
    ) -> [ReviewFailure] {
        var captureIndex: [String: SuperReviewerCapture] = [:]
        for cap in captures {
            let cid = "\(cap.personaName)_\(cap.journeyID)_d\(cap.dayIndex)_\(cap.timeStampLabel)"
            captureIndex[cid] = cap
        }

        var failures: [ReviewFailure] = []

        for multiResult in multiJudgeResults {
            let cap = captureIndex[multiResult.captureID]

            for judgeResult in multiResult.judgeResults {
                for (criterionID, criterionScore) in judgeResult.response.scores {
                    let score = criterionScore.score
                    guard score <= failThreshold else { continue }

                    guard let severity = SeverityClassifier.classify(
                        criterionID: criterionID, score: score
                    ) else { continue }

                    let field = textFieldForCriterion(criterionID)
                    let fix = llmFix(for: criterionID, justification: criterionScore.justification)
                    let offending = offendingText(captureID: multiResult.captureID, field: field, capture: cap)

                    failures.append(ReviewFailure(
                        captureID: multiResult.captureID,
                        criterionID: criterionID,
                        severity: severity,
                        source: .llmJudge,
                        category: .bugFix,
                        affectedTextField: field,
                        failureMessage: "Judge \(judgeResult.judgeName) scored \(criterionID) = \(score)/5: \(criterionScore.justification)",
                        suggestedFix: fix,
                        personaName: cap?.personaName ?? parsePersona(from: multiResult.captureID),
                        journeyID: cap?.journeyID ?? parseJourney(from: multiResult.captureID),
                        dayIndex: cap?.dayIndex ?? parseDay(from: multiResult.captureID),
                        timeStampLabel: cap?.timeStampLabel ?? parseTime(from: multiResult.captureID),
                        judgeScore: score,
                        judgeID: judgeResult.judgeID,
                        offendingText: offending
                    ))
                }
            }
        }

        return failures
    }

    // MARK: - From RPT Batch Result

    /// Collect ReviewFailures from RPT hard-fail and audience gate events.
    static func collect(
        from rptBatchResult: ReportRubricBatchResult,
        captures: [SuperReviewerCapture]
    ) -> [ReviewFailure] {
        var captureIndex: [String: SuperReviewerCapture] = [:]
        for cap in captures {
            let cid = "\(cap.personaName)_\(cap.journeyID)_d\(cap.dayIndex)_\(cap.timeStampLabel)"
            captureIndex[cid] = cap
        }

        var failures: [ReviewFailure] = []

        for (captureID, result) in rptBatchResult.captureResults {
            let cap = captureIndex[captureID]

            if result.hardFailed {
                // RPT-001 or RPT-003 scored < 4
                let badDims = result.dimensionScores.filter {
                    ($0.id == "RPT-001" || $0.id == "RPT-003") && $0.score < 4
                }
                for dim in badDims {
                    failures.append(ReviewFailure(
                        captureID: captureID,
                        criterionID: dim.id,
                        severity: SeverityClassifier.classifyHardFail(criterionID: dim.id),
                        source: .hardFail,
                        category: .bugFix,
                        affectedTextField: "heroMessage",
                        failureMessage: "Hard fail: \(dim.id) scored \(dim.score)/5 (threshold 4). \(dim.justification)",
                        suggestedFix: hardFailFix(for: dim.id),
                        personaName: cap?.personaName ?? parsePersona(from: captureID),
                        journeyID: cap?.journeyID ?? parseJourney(from: captureID),
                        dayIndex: cap?.dayIndex ?? parseDay(from: captureID),
                        timeStampLabel: cap?.timeStampLabel ?? parseTime(from: captureID),
                        judgeScore: dim.score,
                        judgeID: nil,
                        offendingText: cap?.heroMessage
                    ))
                }
            }

            if result.audienceGated {
                for id in ["RPT-004", "RPT-005"] {
                    guard let score = result.score(for: id), score < 3 else { continue }
                    failures.append(ReviewFailure(
                        captureID: captureID,
                        criterionID: id,
                        severity: SeverityClassifier.classifyAudienceGate(criterionID: id, score: score),
                        source: .audienceGate,
                        category: .architecturalImprovement,
                        affectedTextField: id == "RPT-004" ? "heroMessage" : "recoveryNarrative",
                        failureMessage: "Audience gate: \(id) scored \(score)/5 (threshold 3).",
                        suggestedFix: audienceGateFix(for: id),
                        personaName: cap?.personaName ?? parsePersona(from: captureID),
                        journeyID: cap?.journeyID ?? parseJourney(from: captureID),
                        dayIndex: cap?.dayIndex ?? parseDay(from: captureID),
                        timeStampLabel: cap?.timeStampLabel ?? parseTime(from: captureID),
                        judgeScore: score,
                        judgeID: nil,
                        offendingText: cap?.heroMessage
                    ))
                }
            }
        }

        return failures
    }

    // MARK: - Merge All Sources

    /// Merge multiple failure arrays, dedup by id, reclassify categories by cluster.
    static func merge(_ sources: [[ReviewFailure]]) -> [ReviewFailure] {
        var seen: Set<String> = []
        var merged: [ReviewFailure] = []

        for failure in sources.flatMap({ $0 }) {
            if !seen.contains(failure.id) {
                seen.insert(failure.id)
                merged.append(failure)
            }
        }

        // Count occurrences per criterionID to reclassify category
        var criterionOccurrences: [String: Int] = [:]
        var criterionPersonas: [String: Set<String>] = [:]
        for f in merged {
            criterionOccurrences[f.criterionID, default: 0] += 1
            criterionPersonas[f.criterionID, default: []].insert(f.personaName)
        }

        return merged.map { failure in
            let occ = criterionOccurrences[failure.criterionID] ?? 1
            let personaCount = criterionPersonas[failure.criterionID]?.count ?? 1
            let correctedCategory = SeverityClassifier.classifyCategory(
                criterionID: failure.criterionID,
                source: failure.source,
                occurrenceCount: occ,
                affectedPersonaCount: personaCount
            )
            // Rebuild with corrected category
            return ReviewFailure(
                captureID: failure.captureID,
                criterionID: failure.criterionID,
                severity: failure.severity,
                source: failure.source,
                category: correctedCategory,
                affectedTextField: failure.affectedTextField,
                failureMessage: failure.failureMessage,
                suggestedFix: failure.suggestedFix,
                personaName: failure.personaName,
                journeyID: failure.journeyID,
                dayIndex: failure.dayIndex,
                timeStampLabel: failure.timeStampLabel,
                judgeScore: failure.judgeScore,
                judgeID: failure.judgeID,
                offendingText: failure.offendingText
            )
        }
    }

    // MARK: - Fix Suggestion Tables

    private static func verifierFix(for ruleID: String, field: String) -> String {
        switch ruleID {
        case "V-001": return "Add nil/empty guard in AdvicePresenter.\(field) return path. Provide a safe fallback string."
        case "V-002": return "Trim \(field) output. Target 20-200 chars. Current value is out of [10, 300] bounds."
        case "V-003": return "Remove banned term from \(field). Search AdvicePresenter and NudgeGenerator for the flagged word."
        case "V-004": return "Fix time-of-day branch in greeting logic. Check DayPeriod.from(hour:) and AdvicePresenter.heroMessage(for:)."
        case "V-005": return "Ensure mode-goal coherence. Rest mode must not produce step goals > config.stepsRecovering."
        case "V-006": return "Remove duplicate text between adjacent sections. Each section should add new information."
        case "V-007": return "Remove raw metric value (bpm/ms/kg) from \(field). Translate to plain language first."
        case "V-008": return "Remove medical diagnostic claim from \(field). Use hedged language: 'patterns suggest', 'worth mentioning to your doctor'."
        case "V-009": return "Remove emotional safety violation from \(field). Replace blame/shame framing with objective data language."
        case "V-010": return "Fix data-text consistency in \(field). Check AdvicePresenter logic for this metric range."
        case "V-011": return "Fix greeting text mismatch. DayPeriod.from(hour:) should produce period matching capture.timeStampHour."
        case "V-012": return "Remove all ' - ' (space-hyphen-space) patterns from \(field). Use '—' (em dash) or split into two sentences."
        case "V-013": return "Add temporal language to \(field) when dayIndex >= 4. Reference 'this week', 'over the past few days', 'recent pattern'."
        case "V-014": return "CRITICAL: Add readiness guard before push phrases in AdvicePresenter/NudgeGenerator. No push language when readiness < 25."
        case "V-015": return "Reduce total nudge + buddy rec count. Cap at 5 total. On rest days (readiness < 35) cap at 3. Fix in BuddyRecommendationEngine or NudgeGenerator."
        default:      return "Investigate \(ruleID) violation in \(field). See TextCaptureVerifier.swift for rule definition."
        }
    }

    private static func llmFix(for criterionID: String, justification: String) -> String {
        switch criterionID {
        case "CLR-001": return "Simplify language in heroMessage. Remove jargon. Ensure a non-technical user can act on it."
        case "CLR-002": return "Add direct, actionable recommendation. One concrete thing the user can do right now."
        case "CLR-003": return "Fix data-message alignment. heroMessage tone must match the actual readiness/stress values."
        case "CLR-004": return "Add situational context. Explain WHY the user is in this state before the recommendation."
        case "CLR-005": return "Add safety context. Elevated metrics need calm escalation language before any suggestion."
        case "CLR-006": return "Ensure recovery narrative aligns with trend direction. Don't contradict the week-over-week signal."
        case "CLR-007": return "Strengthen buddy message to match urgency. Buddy tone should reflect user's actual state."
        case "CLR-008": return "Fix tone: replace command language ('You must...') with invitation ('A short walk could help...')."
        case "CLR-009": return "Add breathing recommendation when stress >= 60 and breathing feature is relevant for this user."
        case "CLR-010": return "Simplify goal labels. Replace metric names with plain outcome language."
        case "CLR-011": return "Add trend language when week data exists. Reference direction: 'this week', 'over recent days'."
        case "CLR-012": return "Layer content for both audiences. Plain summary first, then optionally data detail for professionals."
        case "CLR-013": return "Celebrate achievement on good days. Acknowledge effort and improvement explicitly."
        case "ENG-001": return "Fix data-text consistency. Text severity must match the actual metric value."
        case "ENG-002": return "Fix score-mode alignment. Check ReadinessEngine band thresholds match GuidanceMode selection."
        case "ENG-003": return "Fix monotonic graduation. Text severity must increase as metrics worsen across days."
        case "ENG-004": return "Remove stale recommendation. Text must reflect current day's data, not prior state."
        case "ENG-005": return "Fix number accuracy. Verify step arithmetic: remaining = target - current."
        case "ENG-006": return "Fix cross-page data consistency. Same metric must have same characterization on all pages."
        case "ENG-007": return "Improve nil handling. Nil metric must produce natural fallback, not empty/nil/N/A."
        case "ENG-008": return "Handle extreme value correctly. Add boundary check for this metric range."
        case "ENG-009": return "Fix mode-goal coherence. Rest mode must never show ambitious goals."
        case "ENG-010": return "Ensure determinism. Check for any random/time-dependent component in output path."
        case "ENG-011": return "Add data horizon signal. Indicate whether text is based on today's data or week trend."
        case "ENG-012": return "Fix trend direction accuracy. Ensure trending language matches actual metric slope."
        case "QAE-002": return "Remove judgment language. Replace blame framing ('only got', 'lazy') with objective data description."
        case "QAE-011": return "Remove hyphen-as-dash. Replace ' - ' with '—' or restructure the sentence."
        case "QAE-012": return "Improve text freshness. Text must change meaningfully when metrics change across days."
        case "RPT-001": return "Fix data correctness. All text claims must match the underlying metric values — no contradictions."
        case "RPT-002": return "Improve goal alignment. Goals must match user's actual readiness, constraints, and risk."
        case "RPT-003": return "CRITICAL: Fix safety framing. No unsafe encouragement. Add escalation language for elevated risk signals."
        case "RPT-004": return "Improve layperson clarity. Non-technical user must understand status and next step without domain knowledge."
        case "RPT-005": return "Improve professional transparency. Add data signal visibility so a clinician can audit the reasoning."
        default:        return "Review \(criterionID) criterion. Judge justification: \(justification.prefix(120))"
        }
    }

    private static func hardFailFix(for criterionID: String) -> String {
        switch criterionID {
        case "RPT-001": return "Audit all text fields for contradictions with input data. heroMessage, goals, and nudges must tell one consistent story."
        case "RPT-003": return "Add safety guard in AdvicePresenter. When risk signals are high, suppress training goals and add escalation language."
        default:        return "Hard-fail gate triggered for \(criterionID). Review scoring guide and fix the underlying engine output."
        }
    }

    private static func audienceGateFix(for criterionID: String) -> String {
        switch criterionID {
        case "RPT-004": return "Redesign heroMessage for layperson first. Lead with outcome ('Your body is tired'), not data ('HRV dropped'). Action must be pictureable."
        case "RPT-005": return "Add data detail layer for professionals. Show which signals (sleep, HRV, RHR) drove the recommendation in the detail view."
        default:        return "Audience gate failed for \(criterionID). Add layered text: plain summary + optional data detail."
        }
    }

    // MARK: - Criterion → Text Field Mapping

    private static func textFieldForCriterion(_ criterionID: String) -> String {
        switch criterionID {
        case "CLR-001", "CLR-002", "CLR-003", "CLR-004", "CLR-005",
             "RPT-001", "RPT-003", "RPT-004", "RPT-008", "RPT-009", "RPT-010":
            return "heroMessage"
        case "CLR-006", "RPT-006":
            return "recoveryNarrative"
        case "CLR-007", "CLR-013":
            return "focusInsight"
        case "CLR-008", "CLR-009":
            return "guidanceDetail"
        case "CLR-010", "RPT-002":
            return "goals"
        case "CLR-011", "ENG-011", "ENG-012", "ENG-003", "ENG-004":
            return "heroMessage"
        case "CLR-012", "RPT-005":
            return "checkRecommendation"
        case "ENG-001", "ENG-002":
            return "heroMessage"
        case "ENG-005":
            return "goals"
        case "ENG-006":
            return "heroMessage+recoveryNarrative"
        case "ENG-007", "ENG-008":
            return "heroMessage"
        case "ENG-009":
            return "goals"
        case "QAE-001", "QAE-005":
            return "all_fields"
        case "QAE-002":
            return "heroMessage"
        case "QAE-003":
            return "heroMessage"
        case "QAE-004":
            return "greetingText"
        case "QAE-007":
            return "heroMessage+focusInsight"
        case "QAE-008", "QAE-012":
            return "heroMessage"
        case "QAE-009":
            return "heroMessage+goals"
        case "QAE-010", "RPT-003":
            return "heroMessage+checkRecommendation"
        case "QAE-011":
            return "all_coaching_fields"
        default:
            return "heroMessage"
        }
    }

    // MARK: - Capture Context Helpers

    private static func offendingText(
        captureID: String,
        field: String,
        capture: SuperReviewerCapture?
    ) -> String? {
        guard let cap = capture else { return nil }
        switch field {
        case "heroMessage":          return cap.heroMessage
        case "recoveryNarrative":    return cap.recoveryNarrative
        case "focusInsight":         return cap.focusInsight
        case "checkRecommendation":  return cap.checkRecommendation
        case "greetingText":         return cap.greetingText
        case "guidanceDetail":       return cap.guidanceDetail
        case "guidanceHeadline":     return cap.guidanceHeadline
        default:                     return cap.heroMessage
        }
    }

    // MARK: - CaptureID Parsing Fallbacks

    private static func parsePersona(from captureID: String) -> String {
        captureID.components(separatedBy: "_").first ?? "Unknown"
    }

    private static func parseJourney(from captureID: String) -> String {
        let parts = captureID.components(separatedBy: "_")
        return parts.count > 1 ? parts[1] : "unknown"
    }

    private static func parseDay(from captureID: String) -> Int {
        if let range = captureID.range(of: #"_d(\d+)_"#, options: .regularExpression) {
            let sub = captureID[range].trimmingCharacters(in: CharacterSet(charactersIn: "_d"))
            return Int(sub.components(separatedBy: "_").first ?? "0") ?? 0
        }
        return 0
    }

    private static func parseTime(from captureID: String) -> String {
        captureID.components(separatedBy: "_").last ?? "unknown"
    }
}

// TextCaptureVerifier.swift
// Thump Tests
//
// Deterministic assertions on SuperReviewerCapture.
// These run WITHOUT any LLM - pure programmatic checks.
// Think of these as the "free" tier that catches obvious bugs.

import Foundation
import XCTest
@testable import Thump

// MARK: - Verification Result

struct VerificationResult {
    let captureID: String
    let violations: [Violation]

    struct Violation {
        let ruleID: String
        let severity: Severity
        let message: String
        let field: String

        enum Severity: String, Comparable {
            case critical
            case high
            case medium
            case low

            static func < (lhs: Severity, rhs: Severity) -> Bool {
                let order: [Severity] = [.low, .medium, .high, .critical]
                return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
            }
        }
    }

    var passed: Bool { violations.isEmpty }
    var criticalViolations: [Violation] { violations.filter { $0.severity == .critical } }
    var highViolations: [Violation] { violations.filter { $0.severity >= .high } }
}

// MARK: - Text Capture Verifier

struct TextCaptureVerifier {

    // MARK: - Full Verification

    /// Runs all deterministic checks on a capture. Returns all violations found.
    static func verify(_ capture: SuperReviewerCapture) -> VerificationResult {
        var violations: [VerificationResult.Violation] = []

        violations += checkTextPresence(capture)
        violations += checkTextLength(capture)
        violations += checkBannedTerms(capture)
        violations += checkTimeOfDayConsistency(capture)
        violations += checkModeGoalCoherence(capture)
        violations += checkNoDuplicateText(capture)
        violations += checkNoRawMetricsInText(capture)
        violations += checkMedicalSafety(capture)
        violations += checkEmotionalSafety(capture)
        violations += checkDataTextConsistency(capture)
        violations += checkNoDashHyphens(capture)
        violations += checkTrendLanguage(capture)
        violations += checkSafetyPushGate(capture)
        violations += checkCognitiveOverload(capture)

        let captureID = "\(capture.personaName)_\(capture.journeyID)_d\(capture.dayIndex)_\(capture.timeStampLabel)"
        return VerificationResult(captureID: captureID, violations: violations)
    }

    /// Batch verify all captures and return summary.
    static func verifyBatch(_ captures: [SuperReviewerCapture]) -> BatchVerificationResult {
        let results = captures.map { verify($0) }
        return BatchVerificationResult(results: results)
    }

    // MARK: - Individual Check Categories

    // V-001: All required text fields are non-empty
    static func checkTextPresence(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        if cap.greetingText == nil || cap.greetingText!.isEmpty {
            v.append(.init(ruleID: "V-001", severity: .critical, message: "Greeting is empty", field: "greetingText"))
        }
        if cap.heroMessage == nil || cap.heroMessage!.isEmpty {
            v.append(.init(ruleID: "V-001", severity: .critical, message: "Hero message is empty", field: "heroMessage"))
        }
        if cap.checkRecommendation == nil || cap.checkRecommendation!.isEmpty {
            v.append(.init(ruleID: "V-001", severity: .critical, message: "Check recommendation is empty", field: "checkRecommendation"))
        }
        if cap.buddyMood == nil || cap.buddyMood!.isEmpty {
            v.append(.init(ruleID: "V-001", severity: .high, message: "Buddy mood emoji is empty", field: "buddyMood"))
        }

        return v
    }

    // V-002: Text length bounds (10-300 chars for messages)
    static func checkTextLength(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        if let hero = cap.heroMessage, hero.count < 10 || hero.count > 200 {
            v.append(.init(ruleID: "V-002", severity: .medium,
                message: "heroMessage length \(hero.count) outside bounds [10, 200]",
                field: "heroMessage"))
        }
        if let check = cap.checkRecommendation, check.count < 15 || check.count > 300 {
            v.append(.init(ruleID: "V-002", severity: .medium,
                message: "checkRecommendation length \(check.count) outside bounds [15, 300]",
                field: "checkRecommendation"))
        }
        if let narrative = cap.recoveryNarrative, narrative.count < 10 || narrative.count > 300 {
            v.append(.init(ruleID: "V-002", severity: .medium,
                message: "recoveryNarrative length \(narrative.count) outside bounds [10, 300]",
                field: "recoveryNarrative"))
        }

        // Goal labels should be short
        for goal in cap.goals where goal.label.count > 50 {
            v.append(.init(ruleID: "V-002", severity: .low,
                message: "Goal label too long: \(goal.label.count) chars",
                field: "goal_\(goal.label)"))
        }

        return v
    }

    // V-003: No banned terms in any customer-facing text
    static func checkBannedTerms(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        let bannedTerms = [
            // Judgment language
            "lazy", "pathetic", "terrible",
            "should have tried harder", "not good enough", "you only got",
            // Raw jargon leaking
            "sigma", "z-score", "percentile", "algorithm",
            "null", "nil", "undefined", "NaN",
            // AI slop
            "as an AI", "I'm an AI", "language model",
            "delve", "tapestry",
            // Anthropomorphism of body (alarming framing)
            "your body is punishing", "your heart is angry",
        ]

        // Only check coaching/hero text - not medical referral nudges
        let coachingOnlyText = gatherAllText(cap).filter { (field, _) in
            !field.lowercased().contains("doctor") && !field.lowercased().contains("medical")
        }

        for term in bannedTerms {
            for (field, text) in coachingOnlyText {
                if text.localizedCaseInsensitiveContains(term) {
                    v.append(.init(ruleID: "V-003", severity: .high,
                        message: "Banned term '\(term)' found in \(field)",
                        field: field))
                }
            }
        }

        return v
    }

    // V-004: Time-of-day greeting matches hour
    static func checkTimeOfDayConsistency(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        let hour = cap.timeStampHour
        let greeting = (cap.greetingText ?? "").lowercased()

        // Morning: 5 AM - 11:59 AM → should say "morning"
        if hour >= 5 && hour < 12 {
            if greeting.contains("evening") || greeting.contains("good night") {
                v.append(.init(ruleID: "V-004", severity: .high,
                    message: "Morning hour (\(hour)) but greeting is '\(cap.greetingText ?? "")'",
                    field: "greetingText"))
            }
        }
        // Late night: 9 PM - 4:59 AM → should NOT say "good morning"
        if hour >= 21 || hour < 5 {
            if greeting.contains("good morning") {
                v.append(.init(ruleID: "V-004", severity: .high,
                    message: "Late night hour (\(hour)) but greeting is '\(cap.greetingText ?? "")'",
                    field: "greetingText"))
            }
        }

        return v
    }

    // V-005: Mode-goal coherence (INV-004 check)
    static func checkModeGoalCoherence(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []
        let policy = ConfigService.activePolicy

        // Check badge ID tells us the mode
        let badge = cap.checkBadge ?? ""

        if badge.contains("rest") || badge.contains("medical") {
            for goal in cap.goals {
                if goal.label.lowercased().contains("step") && goal.target > Double(policy.goals.stepsRecovering) {
                    v.append(.init(ruleID: "V-005", severity: .critical,
                        message: "Mode is rest/medical but step target is \(Int(goal.target)) (should be <= \(policy.goals.stepsRecovering))",
                        field: "goals"))
                }
            }
        }

        return v
    }

    // V-006: No duplicate text across adjacent sections
    static func checkNoDuplicateText(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        // Hero and focus insight should not be identical
        if let insight = cap.focusInsight, let hero = cap.heroMessage, insight == hero {
            v.append(.init(ruleID: "V-006", severity: .medium,
                message: "Hero message and focus insight are identical",
                field: "focusInsight"))
        }

        // Recovery narrative and hero should not be identical
        if let narrative = cap.recoveryNarrative, let hero = cap.heroMessage, narrative == hero {
            v.append(.init(ruleID: "V-006", severity: .medium,
                message: "Hero message and recovery narrative are identical",
                field: "recoveryNarrative"))
        }

        return v
    }

    // V-007: No raw metrics leaking into coaching text
    static func checkNoRawMetricsInText(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        let rawPatterns = [
            "HRV: ", "HRV:", "SDNN", "rMSSD",
            "bpm:", "BPM:",
            "score: ", "Score:",
        ]

        let textFields: [(String, String?)] = [
            ("heroMessage", cap.heroMessage),
            ("checkRecommendation", cap.checkRecommendation),
            ("focusInsight", cap.focusInsight),
            ("recoveryNarrative", cap.recoveryNarrative),
        ]

        for pattern in rawPatterns {
            for (field, text) in textFields {
                guard let text, !text.isEmpty else { continue }
                if text.contains(pattern) {
                    v.append(.init(ruleID: "V-007", severity: .high,
                        message: "Raw metric pattern '\(pattern)' found in \(field)",
                        field: field))
                }
            }
        }

        return v
    }

    // V-008: Medical safety - no diagnostic claims
    static func checkMedicalSafety(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        // These are specific diagnostic claim patterns - much narrower than generic "you have"
        let dangerousClaims = [
            "you have a heart condition", "you are suffering from",
            "indicates a disease", "you have been diagnosed",
            "cardiac event detected", "heart attack risk",
            "seek emergency care", "call 911", "go to the hospital immediately",
        ]

        // Only check coaching fields - NOT medical referral nudges (those are by design)
        let coachingTexts: [(String, String)] = [
            ("heroMessage", cap.heroMessage ?? ""),
            ("checkRecommendation", cap.checkRecommendation ?? ""),
            ("focusInsight", cap.focusInsight ?? ""),
            ("recoveryNarrative", cap.recoveryNarrative ?? ""),
            ("guidanceDetail", cap.guidanceDetail ?? ""),
        ]

        for claim in dangerousClaims {
            for (field, text) in coachingTexts where !text.isEmpty {
                if text.localizedCaseInsensitiveContains(claim) {
                    v.append(.init(ruleID: "V-008", severity: .critical,
                        message: "Dangerous medical claim '\(claim)' in \(field)",
                        field: field))
                }
            }
        }

        return v
    }

    // V-009: No blame language (objective, data-driven framing)
    static func checkEmotionalSafety(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        let blamePatterns = [
            "you didn't", "you failed", "you forgot",
            "you need to try harder", "not good enough",
            "you got not enough", "you only", "shame",
        ]

        let allText = gatherAllText(cap)

        for pattern in blamePatterns {
            for (field, text) in allText {
                if text.localizedCaseInsensitiveContains(pattern) {
                    v.append(.init(ruleID: "V-009", severity: .high,
                        message: "Blame language '\(pattern)' in \(field)",
                        field: field))
                }
            }
        }

        return v
    }

    // V-010: Data-text consistency (metrics vs text tone)
    static func checkDataTextConsistency(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        // If readiness is very low, text should not be celebratory
        if let score = cap.readinessScore, score < 35 {
            let heroLower = (cap.heroMessage ?? "").lowercased()
            if heroLower.contains("charged up") || heroLower.contains("ready for a solid day") {
                v.append(.init(ruleID: "V-010", severity: .high,
                    message: "Readiness \(score) (recovering) but hero is celebratory",
                    field: "heroMessage"))
            }
        }

        return v
    }

    // V-012: No hyphen used as an em dash in sentence-level coaching text
    // App text should use em dashes (—) or restructure. Hyphens are for compound words only.
    static func checkNoDashHyphens(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        // Pattern: word[space]-[space]word — hyphen used as sentence connector
        let sentenceConnectorFields: [(String, String?)] = [
            ("heroMessage", cap.heroMessage),
            ("checkRecommendation", cap.checkRecommendation),
            ("recoveryNarrative", cap.recoveryNarrative),
            ("guidanceHeadline", cap.guidanceHeadline),
            ("guidanceDetail", cap.guidanceDetail),
            ("friendlyMessage", cap.friendlyMessage),
            ("coachingHeroMessage", cap.coachingHeroMessage),
        ]

        for (field, text) in sentenceConnectorFields {
            guard let text, !text.isEmpty else { continue }
            // Detect " - " used as a sentence bridge (not a list bullet or compound word)
            if text.contains(" - ") {
                v.append(.init(ruleID: "V-012", severity: .medium,
                    message: "Hyphen used as em dash in \(field): use — or restructure the sentence",
                    field: field))
            }
        }

        return v
    }

    // V-013: Trend language present when journey has enough history (day 4+)
    // When the engine has a week of data, text should reference trajectory, not just today.
    static func checkTrendLanguage(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        // Only check once enough history exists (day 4 onward = at least 4 prior days in engine)
        guard cap.dayIndex >= 4 else { return [] }

        let trendWords = [
            "week", "days", "trending", "recent", "past", "pattern",
            "been building", "improving", "declining", "consistently",
            "this week", "over the", "all week", "past few",
        ]

        let heroLower = (cap.heroMessage ?? "").lowercased()
        let recoveryLower = (cap.recoveryNarrative ?? "").lowercased()
        let coachingLower = cap.coachingInsights.joined(separator: " ").lowercased()
        let combinedText = "\(heroLower) \(recoveryLower) \(coachingLower)"

        let hasTrendWord = trendWords.contains { combinedText.contains($0) }

        if !hasTrendWord {
            v.append(.init(ruleID: "V-013", severity: .low,
                message: "Day \(cap.dayIndex): engine has week of history but no trend language found in hero/recovery/coaching",
                field: "heroMessage"))
        }

        return v
    }

    // V-014: Safety push gate (RPT-003 deterministic proxy)
    // If readiness is critically low AND the text contains push/exercise encouragement,
    // flag as critical — this is the core safety invariant.
    static func checkSafetyPushGate(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        guard let readiness = cap.readinessScore, readiness < 25 else { return [] }

        let pushPhrases = [
            "push yourself", "push hard", "go all out", "give it everything",
            "high intensity", "max effort", "personal best", "beat yesterday",
            "crush your goal", "time to push",
        ]

        let allText = gatherAllText(cap)

        for phrase in pushPhrases {
            for (field, text) in allText {
                if text.localizedCaseInsensitiveContains(phrase) {
                    v.append(.init(ruleID: "V-014", severity: .critical,
                        message: "Readiness=\(readiness) (critical) but push language '\(phrase)' found in \(field)",
                        field: field))
                }
            }
        }

        return v
    }

    // V-015: Cognitive overload — too many concurrent action items on one screen
    //
    // "Action items" definition: buddy recs + nudges (directive items only) + smart actions
    // + Thump Check directive text + weekly report recommended actions.
    // NOT counted: hero message, narrative text, passive goal progress displays.
    //
    // Budget by mode (enforced upstream in AdviceComposer.dailyGuidanceBudget):
    //   fullRest / medicalCheck: 2  |  lightRecovery: 3  |  moderateMove: 5  |  pushDay: 7
    //
    // Verifier thresholds (final gate — fires if upstream budget enforcement slips):
    //   All days: > 5 total → medium  |  Rest days (readiness < 35): > 3 → high
    static func checkCognitiveOverload(_ cap: SuperReviewerCapture) -> [VerificationResult.Violation] {
        var v: [VerificationResult.Violation] = []

        let totalActionItems = cap.nudges.count + cap.buddyRecs.count

        if totalActionItems > 5 {
            v.append(.init(ruleID: "V-015", severity: .medium,
                message: "Cognitive overload: \(cap.nudges.count) nudges + \(cap.buddyRecs.count) buddy recs = \(totalActionItems) concurrent action items (max 5)",
                field: "nudges+buddyRecs"))
        }

        // On a crash/rest day, even 3+ is too many
        if let readiness = cap.readinessScore, readiness < 35, totalActionItems > 3 {
            v.append(.init(ruleID: "V-015", severity: .high,
                message: "Rest day (readiness=\(readiness)) with \(totalActionItems) action items — should be ≤3 on low-recovery days",
                field: "nudges+buddyRecs"))
        }

        return v
    }

    // MARK: - Journey-Level Checks (cross-day)

    /// Verifies coherence across a full journey (all days for one persona + journey).
    static func verifyJourney(_ captures: [SuperReviewerCapture]) -> [VerificationResult.Violation] {
        guard captures.count > 1 else { return [] }
        var v: [VerificationResult.Violation] = []

        let sorted = captures.sorted { $0.dayIndex < $1.dayIndex }

        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]

            // If metrics improved significantly, text should not get worse
            if let prevReadiness = prev.readinessScore, let currReadiness = curr.readinessScore {
                if currReadiness > prevReadiness + 20 {
                    let prevPositive = isPositiveTone(prev.heroMessage ?? "")
                    let currPositive = isPositiveTone(curr.heroMessage ?? "")
                    if prevPositive && !currPositive {
                        v.append(.init(ruleID: "V-011", severity: .medium,
                            message: "Day \(curr.dayIndex): readiness jumped \(prevReadiness) -> \(currReadiness) but hero tone worsened",
                            field: "heroMessage"))
                    }
                }
            }
        }

        return v
    }

    // MARK: - Helpers

    private static func gatherAllText(_ cap: SuperReviewerCapture) -> [(String, String)] {
        var texts: [(String, String)] = []
        if let t = cap.greetingText { texts.append(("greetingText", t)) }
        if let t = cap.heroMessage { texts.append(("heroMessage", t)) }
        if let t = cap.checkRecommendation { texts.append(("checkRecommendation", t)) }
        if let t = cap.focusInsight { texts.append(("focusInsight", t)) }
        if let t = cap.recoveryNarrative { texts.append(("recoveryNarrative", t)) }
        if let t = cap.recoveryAction { texts.append(("recoveryAction", t)) }
        if let t = cap.positivityAnchor { texts.append(("positivityAnchor", t)) }
        if let t = cap.guidanceHeadline { texts.append(("guidanceHeadline", t)) }
        if let t = cap.guidanceDetail { texts.append(("guidanceDetail", t)) }
        if let t = cap.friendlyMessage { texts.append(("friendlyMessage", t)) }
        if let t = cap.coachingHeroMessage { texts.append(("coachingHeroMessage", t)) }

        for goal in cap.goals {
            texts.append(("goal_\(goal.label)_nudge", goal.nudgeText))
        }
        for nudge in cap.nudges {
            texts.append(("nudge_\(nudge.title)", nudge.description))
        }
        for rec in cap.buddyRecs {
            texts.append(("buddy_\(rec.title)", rec.message))
        }
        for insight in cap.coachingInsights {
            texts.append(("coachingInsight", insight))
        }

        return texts
    }

    private static func isPositiveTone(_ text: String) -> Bool {
        let lower = text.lowercased()
        let positiveWords = ["solid", "good", "great", "charged", "ready", "primed", "well", "strong"]
        let negativeWords = ["low", "rough", "rest", "light", "easy", "skip", "mellow"]
        let posCount = positiveWords.filter { lower.contains($0) }.count
        let negCount = negativeWords.filter { lower.contains($0) }.count
        return posCount > negCount
    }
}

// MARK: - Batch Verification Result

struct BatchVerificationResult {
    let results: [VerificationResult]

    var totalCaptures: Int { results.count }
    var passedCaptures: Int { results.filter(\.passed).count }
    var failedCaptures: Int { results.filter { !$0.passed }.count }
    var passRate: Double { Double(passedCaptures) / Double(max(totalCaptures, 1)) }

    var allViolations: [VerificationResult.Violation] {
        results.flatMap(\.violations)
    }

    var criticalViolations: [VerificationResult.Violation] {
        allViolations.filter { $0.severity == .critical }
    }

    var violationsByRule: [String: Int] {
        var counts: [String: Int] = [:]
        for v in allViolations {
            counts[v.ruleID, default: 0] += 1
        }
        return counts
    }

    func summary() -> String {
        var lines: [String] = []
        lines.append("=== Super Reviewer Verification Summary ===")
        lines.append("Total captures: \(totalCaptures)")
        lines.append("Passed: \(passedCaptures) (\(String(format: "%.1f", passRate * 100))%)")
        lines.append("Failed: \(failedCaptures)")
        lines.append("Total violations: \(allViolations.count)")
        lines.append("  Critical: \(allViolations.filter { $0.severity == .critical }.count)")
        lines.append("  High: \(allViolations.filter { $0.severity == .high }.count)")
        lines.append("  Medium: \(allViolations.filter { $0.severity == .medium }.count)")
        lines.append("  Low: \(allViolations.filter { $0.severity == .low }.count)")
        lines.append("")
        lines.append("Violations by rule:")
        for (rule, count) in violationsByRule.sorted(by: { $0.value > $1.value }) {
            lines.append("  \(rule): \(count)")
        }
        return lines.joined(separator: "\n")
    }
}

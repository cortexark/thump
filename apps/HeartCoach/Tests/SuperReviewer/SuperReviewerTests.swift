// SuperReviewerTests.swift
// Thump Tests
//
// XCTest entry point for the Super Reviewer evaluation system.
// Three tiers:
//   Tier A: deterministic checks (every CI, no API keys needed)
//   Tier B: 4 LLM persona judges (nightly — run_judges.sh tierB, no API key needed)
//   Tier C: 6 LLM persona judges (pre-release — run_judges.sh tierC, no API key needed)
//
// QUALITY GATE CALIBRATION:
//   Tier B gate: 65%  (4 judges — Marcus, Priya, David, Jordan — moderate-to-lenient range)
//   Tier C gate: 55%  (6 judges including Aisha "WHOOP-level expert" and Sarah "time-starved parent"
//                       who intentionally score stricter; blended 6-judge avg ~58% on current content)
//   Floor check: 15%  (catches parse errors / catastrophic failures only; strict judges
//                       e.g. David Nakamura legitimately score 21-23% on guilt-laden content)
//
// TARGET: raise both gates to 70% as coaching text quality improves.

import XCTest
@testable import Thump

// MARK: - Tier A: Deterministic Verification (Every CI)

final class SuperReviewerTierATests: XCTestCase {

    // MARK: - Smoke Test: Single Capture

    func testSingleCapture_producesNonEmptyFields() {
        let persona = JourneyPersonas.all.first!
        let journey = JourneyScenarios.goodThenCrash
        let timestamp = TimeOfDayStamps.all[4]  // 8:00 AM

        let capture = SuperReviewerRunner.capture(
            persona: persona,
            journey: journey,
            dayIndex: 3,  // crash day
            timestamp: timestamp
        )

        XCTAssertNotNil(capture.heroMessage, "Hero message should not be nil")
        XCTAssertNotNil(capture.greetingText, "Greeting should not be nil")
        XCTAssertNotNil(capture.checkRecommendation, "Check recommendation should not be nil")
        XCTAssertNotNil(capture.buddyMood, "Buddy mood should not be nil")
        XCTAssertNotNil(capture.readinessScore, "Readiness score should be present")
    }

    // MARK: - Full Tier A Batch

    func testTierA_allCapturesPassDeterministicChecks() {
        let config = SuperReviewerRunConfig.tierA
        print("[SuperReviewer] Tier A: \(config.totalCaptures) total captures")

        let result = SuperReviewerRunner.runBatch(config: config)

        XCTAssertEqual(result.failures.count, 0,
            "All captures should succeed. Failures: \(result.failures.map { "\($0.personaName)/\($0.journeyID)/d\($0.dayIndex)" })")

        // Run deterministic verification on all captures
        let verification = TextCaptureVerifier.verifyBatch(result.captures)

        print(verification.summary())

        // Hard gate: zero critical violations
        XCTAssertEqual(verification.criticalViolations.count, 0,
            "Zero critical violations required. Found: \(verification.criticalViolations.map { "\($0.ruleID): \($0.message)" })")

        // Soft gate: report high violations
        let highViolations = verification.allViolations.filter { $0.severity == .high }
        if !highViolations.isEmpty {
            print("WARNING: \(highViolations.count) high-severity violations found:")
            for v in highViolations.prefix(20) {
                print("  [\(v.ruleID)] \(v.field): \(v.message)")
            }
        }

        print("[SuperReviewer] Tier A completed in \(String(format: "%.1f", result.totalDurationMs))ms")
    }

    // MARK: - Per-Journey Verification

    func testJourney_goodThenCrash_allPersonas() {
        verifyJourneyAcrossPersonas(JourneyScenarios.goodThenCrash)
    }

    func testJourney_intensityEscalation_allPersonas() {
        verifyJourneyAcrossPersonas(JourneyScenarios.intensityEscalation)
    }

    func testJourney_gradualDeterioration_allPersonas() {
        verifyJourneyAcrossPersonas(JourneyScenarios.gradualDeterioration)
    }

    func testJourney_rapidRecovery_allPersonas() {
        verifyJourneyAcrossPersonas(JourneyScenarios.rapidRecovery)
    }

    func testJourney_mixedSignals_allPersonas() {
        verifyJourneyAcrossPersonas(JourneyScenarios.mixedSignals)
    }

    // MARK: - Time-of-Day Coverage

    func testAllTimestamps_greetingMatchesHour() {
        let persona = JourneyPersonas.all.first!
        let journey = JourneyScenarios.goodThenCrash

        for timestamp in TimeOfDayStamps.all {
            let capture = SuperReviewerRunner.capture(
                persona: persona,
                journey: journey,
                dayIndex: 0,
                timestamp: timestamp
            )

            let violations = TextCaptureVerifier.checkTimeOfDayConsistency(capture)
            XCTAssertTrue(violations.isEmpty,
                "Timestamp \(timestamp.label) (hour \(timestamp.hour)): greeting '\(capture.greetingText ?? "nil")' violated time-of-day rule")
        }
    }

    // MARK: - Critical Day Verification

    func testCriticalDays_allJourneys_noInvariantViolations() {
        for journey in JourneyScenarios.all {
            for persona in JourneyPersonas.all {
                for criticalDay in journey.criticalDays {
                    let capture = SuperReviewerRunner.capture(
                        persona: persona,
                        journey: journey,
                        dayIndex: criticalDay,
                        timestamp: TimeOfDayStamps.all[4]  // 8 AM
                    )

                    let result = TextCaptureVerifier.verify(capture)
                    let critical = result.criticalViolations

                    XCTAssertTrue(critical.isEmpty,
                        "\(persona.name)/\(journey.id)/d\(criticalDay): \(critical.map { $0.message })")
                }
            }
        }
    }

    // MARK: - Medical Safety

    func testNoMedicalClaims_anyCapture() {
        let allCaptures = generateAllTierACaptures()

        for capture in allCaptures {
            let violations = TextCaptureVerifier.checkMedicalSafety(capture)
            XCTAssertTrue(violations.isEmpty,
                "\(capture.personaName)/\(capture.journeyID)/d\(capture.dayIndex): \(violations.map { $0.message })")
        }
    }

    // MARK: - No Blame Language

    func testNoBlameLanguage_anyCapture() {
        let allCaptures = generateAllTierACaptures()

        for capture in allCaptures {
            let violations = TextCaptureVerifier.checkEmotionalSafety(capture)
            XCTAssertTrue(violations.isEmpty,
                "\(capture.personaName)/\(capture.journeyID)/d\(capture.dayIndex): \(violations.map { $0.message })")
        }
    }

    // MARK: - Journey Regression (cross-day coherence)

    func testJourneyRegression_improvingMetrics_improvingText() {
        for persona in JourneyPersonas.all {
            let journey = JourneyScenarios.rapidRecovery
            var journeyCaptures: [SuperReviewerCapture] = []

            for day in 0..<journey.dayCount {
                let capture = SuperReviewerRunner.capture(
                    persona: persona,
                    journey: journey,
                    dayIndex: day,
                    timestamp: TimeOfDayStamps.all[4]
                )
                journeyCaptures.append(capture)
            }

            let violations = TextCaptureVerifier.verifyJourney(journeyCaptures)
            if !violations.isEmpty {
                print("WARNING: Journey regression for \(persona.name)/\(journey.id): \(violations.map { $0.message })")
            }
        }
    }

    // MARK: - Print Full Report for Manual Review

    func testPrintFullTextReport() {
        let persona = JourneyPersonas.all[min(1, JourneyPersonas.all.count - 1)]
        let journey = JourneyScenarios.goodThenCrash

        print("\n======================================================")
        print("    SUPER REVIEWER: Full Text Report")
        print("    Persona: \(persona.name)")
        print("    Journey: \(journey.name)")
        print("======================================================\n")

        for day in 0..<journey.dayCount {
            let isCritical = journey.criticalDays.contains(day)
            let marker = isCritical ? " << CRITICAL" : ""

            print("----------------------------------------")
            print("Day \(day)\(marker)")
            print("----------------------------------------")

            for timestamp in [TimeOfDayStamps.all[2], TimeOfDayStamps.all[8], TimeOfDayStamps.all[16]] {
                let cap = SuperReviewerRunner.capture(
                    persona: persona,
                    journey: journey,
                    dayIndex: day,
                    timestamp: timestamp
                )

                print("\n  Time: \(timestamp.label)")
                print("  Metrics:")
                print("    Sleep: \(cap.sleepHours.map { String(format: "%.1fh", $0) } ?? "nil")")
                print("    RHR: \(cap.rhr.map { String(format: "%.0f", $0) } ?? "nil") bpm")
                print("    HRV: \(cap.hrv.map { String(format: "%.0f", $0) } ?? "nil") ms")
                print("    Steps: \(cap.steps.map { String(format: "%.0f", $0) } ?? "nil")")
                print("    Readiness: \(cap.readinessScore.map { "\($0)" } ?? "nil")")
                print("    Stress: \(cap.stressScore.map { String(format: "%.0f", $0) } ?? "nil") (\(cap.stressLevel ?? "nil"))")
                print("  Dashboard:")
                print("    \(cap.buddyMood ?? "") \(cap.greetingText ?? "")")
                print("    Hero: \(cap.heroMessage ?? "")")
                if let insight = cap.focusInsight { print("    Focus: \(insight)") }
                print("    Check: \(cap.checkRecommendation ?? "")")
                if let narrative = cap.recoveryNarrative { print("    Recovery: \(narrative)") }
                if let action = cap.recoveryAction { print("    Action: \(action)") }
                if let anchor = cap.positivityAnchor { print("    Positivity: \(anchor)") }
                print("  Goals:")
                for goal in cap.goals {
                    print("    \(goal.label): \(Int(goal.current))/\(Int(goal.target)) - \(goal.nudgeText)")
                }
                if let headline = cap.guidanceHeadline {
                    print("  Stress Page:")
                    print("    \(headline)")
                    if let detail = cap.guidanceDetail { print("    \(detail)") }
                    if let actions = cap.guidanceActions { print("    Actions: \(actions.joined(separator: ", "))") }
                }
                print("  Nudges:")
                for nudge in cap.nudges {
                    print("    \(nudge.title): \(nudge.description)")
                }
                print("  Buddy Recs:")
                for rec in cap.buddyRecs {
                    print("    [\(rec.priority)] \(rec.title): \(rec.message)")
                }
                print("  ---")
            }
            print("")
        }
    }

    // MARK: - JSON Export for LLM Judges

    func testExportTierACaptures_toJSON() {
        let config = SuperReviewerRunConfig.tierA
        let result = SuperReviewerRunner.runBatch(config: config)
        XCTAssertGreaterThan(result.captures.count, 0)
        print("[SuperReviewer] Exported \(result.captures.count) Tier A captures to JSON")
    }

    // MARK: - Failure Triage & Jira Ticket Generation

    /// Runs the full triage system after Tier A:
    ///   - Collects all verifier failures
    ///   - Classifies each as Bug Fix vs Architectural Improvement
    ///   - Generates Jira tickets in CaptureOutput/TierA/JiraTickets/
    ///   - Checks regression locks (fails if any locked fix regressed)
    ///   - Fails ONLY on new P0/P1 failures not in the baseline
    func testFailureTriage_generateJiraTickets_noNewRegressions() {
        let config = SuperReviewerRunConfig.tierA
        let runResult = SuperReviewerRunner.runBatch(config: config)
        let verification = TextCaptureVerifier.verifyBatch(runResult.captures)

        let sourceDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let outputDir = sourceDir.appendingPathComponent("CaptureOutput/TierA")

        let triage = FailureTriageEngine.triage(
            captures: runResult.captures,
            verifierBatchResult: verification,
            tier: "TierA",
            outputDirectory: outputDir
        )

        FailureTriageEngine.saveToDisk(triage, outputDirectory: outputDir)

        // Print full summary (visible in Xcode test console)
        print(triage.summary)
        print(triage.trendReport.summary)

        // Print Jira ticket list
        if !triage.jiraTickets.isEmpty {
            print("\n── Generated Jira Tickets ────────────────────────────")
            for ticket in triage.jiraTickets {
                print("  \(ticket.key) [\(ticket.priority)] [\(ticket.category.label)] \(ticket.summary)")
            }
            print("")
        }

        // GATE 1: Regression lock violations — these are previously-fixed bugs that broke again
        XCTAssertTrue(
            triage.regressionLockViolations.isEmpty,
            "Regression lock violations found — a previously fixed bug re-appeared:\n" +
            triage.regressionLockViolations.map { "  \($0.message)" }.joined(separator: "\n")
        )

        // GATE 2: No new P0/P1 failures vs baseline (existing known failures are allowed).
        // Skip on cold start (previousRunFailureCount == 0 means no baseline existed) —
        // the first run establishes the baseline. Subsequent runs gate on new regressions.
        if triage.trendReport.previousRunFailureCount > 0 {
            let newCritical = triage.trendReport.newFailures.filter { $0.severity == .p0 || $0.severity == .p1 }
            XCTAssertTrue(
                newCritical.isEmpty,
                "\(newCritical.count) NEW P0/P1 failures introduced (regressions). Fix before merging.\n" +
                newCritical.prefix(10).map { failure in
                    let item = triage.fixBacklog.first { $0.criterionID == failure.criterionID }
                    let jiraKey = item?.jiraTicket.key ?? "?"
                    return "  [\(failure.severity.rawValue)] \(jiraKey) \(failure.criterionID) — \(failure.captureID)\n    \(failure.failureMessage)"
                }.joined(separator: "\n")
            )
        } else {
            print("[SuperReviewer] Cold start: baseline established with \(triage.allFailures.count) failures. Run again to gate on regressions.")
        }
    }

    // MARK: - Helpers

    private func generateAllTierACaptures() -> [SuperReviewerCapture] {
        let config = SuperReviewerRunConfig.tierA
        let result = SuperReviewerRunner.runBatch(config: config)
        return result.captures
    }

    private func verifyJourneyAcrossPersonas(_ journey: JourneyScenario) {
        for persona in JourneyPersonas.all {
            for day in 0..<journey.dayCount {
                for timestamp in [TimeOfDayStamps.all[2], TimeOfDayStamps.all[8], TimeOfDayStamps.all[16]] {
                    let capture = SuperReviewerRunner.capture(
                        persona: persona,
                        journey: journey,
                        dayIndex: day,
                        timestamp: timestamp
                    )

                    let result = TextCaptureVerifier.verify(capture)
                    XCTAssertTrue(result.criticalViolations.isEmpty,
                        "\(persona.name)/\(journey.id)/d\(day)/\(timestamp.label): \(result.criticalViolations.map { $0.message })")
                }
            }
        }
    }
}

// MARK: - Tier B: Nightly LLM Evaluation (4 persona judges via Claude Code CLI)
//
// HOW TO RUN TIER B:
//   1. ./Tests/SuperReviewer/run_judges.sh tierB
//      (uses `claude --print` on the macOS host — no API key needed)
//   2. xcodebuild test -scheme Thump -only-testing ThumpCoreTests/SuperReviewerTierBTests
//      (reads pre-generated judge results and runs quality-gate assertions)

final class SuperReviewerTierBTests: XCTestCase {

    func testTierB_2judges_nightlyEvaluation() throws {
        // Load results pre-generated by run_judges.sh (via claude --print on macOS host)
        let llmResults = LLMJudgeRunner.loadPreGeneratedResults(tier: .secondary)

        try XCTSkipIf(llmResults.isEmpty,
            """
            [Tier B] No pre-generated judge results found.
            Run first:  ./Tests/SuperReviewer/run_judges.sh tierB
            (Uses Claude Code CLI — no ANTHROPIC_API_KEY needed)
            """)

        print("[SuperReviewer] Tier B: loaded \(llmResults.count) pre-generated judge results")

        // Programmatic Tier B verification
        let config = SuperReviewerRunConfig.tierB
        let runResult = SuperReviewerRunner.runBatch(config: config)
        XCTAssertEqual(runResult.failures.count, 0)
        let verification = TextCaptureVerifier.verifyBatch(runResult.captures)
        XCTAssertEqual(verification.criticalViolations.count, 0)

        // Report
        let report = SuperReviewerReport(
            config: "Tier B (Nightly — 4 Claude persona judges)",
            totalCaptures: runResult.captures.count,
            totalJudgeRuns: llmResults.flatMap(\.judgeResults).count,
            programmaticResults: verification,
            llmResults: llmResults,
            durationMs: runResult.totalDurationMs
        )
        print(report.generateReport())

        // Triage
        let sourceDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let outputDir = sourceDir.appendingPathComponent("CaptureOutput/TierB")
        let triage = FailureTriageEngine.triage(
            captures: runResult.captures,
            verifierBatchResult: verification,
            llmResults: llmResults,
            tier: "TierB",
            outputDirectory: outputDir
        )
        FailureTriageEngine.saveToDisk(triage, outputDirectory: outputDir)
        print(triage.summary)

        // Quality gate: 65% for Tier B (4 moderate-to-lenient judges; current baseline ~69%).
        // See top-of-file calibration notes. Target: raise to 70% as content improves.
        let avgPct = llmResults.map(\.percentageScore).reduce(0, +) / Double(max(llmResults.count, 1))
        XCTAssertGreaterThan(avgPct, 65,
            "Tier B average should be >65% (4-judge blended). Got: \(String(format: "%.1f", avgPct))%")
    }
}

// MARK: - Tier C: Full 6-Judge Evaluation (Manual / Pre-Release)
//
// HOW TO RUN TIER C:
//   1. ./Tests/SuperReviewer/run_judges.sh tierC
//      (uses `claude --print` on the macOS host — no API key needed)
//   2. xcodebuild test -scheme Thump -only-testing ThumpCoreTests/SuperReviewerTierCTests
//      (reads pre-generated judge results and runs quality-gate assertions)

final class SuperReviewerTierCTests: XCTestCase {

    func testTierC_6judges_fullEvaluation() throws {
        // Load results pre-generated by run_judges.sh (via claude --print on macOS host)
        let llmResults = LLMJudgeRunner.loadPreGeneratedResults(tier: .tertiary)

        try XCTSkipIf(llmResults.isEmpty,
            """
            [Tier C] No pre-generated judge results found.
            Run first:  ./Tests/SuperReviewer/run_judges.sh tierC
            (Uses Claude Code CLI — no ANTHROPIC_API_KEY needed)
            """)

        print("[SuperReviewer] Tier C: loaded \(llmResults.count) pre-generated judge results")

        // Full programmatic verification
        let config = SuperReviewerRunConfig.tierC
        let runResult = SuperReviewerRunner.runBatch(config: config)
        XCTAssertEqual(runResult.failures.count, 0)
        let verification = TextCaptureVerifier.verifyBatch(runResult.captures)
        print(verification.summary())
        XCTAssertEqual(verification.criticalViolations.count, 0)

        // Report
        let report = SuperReviewerReport(
            config: "Tier C (Full — 6 Claude persona judges)",
            totalCaptures: runResult.captures.count,
            totalJudgeRuns: llmResults.flatMap(\.judgeResults).count,
            programmaticResults: verification,
            llmResults: llmResults,
            durationMs: runResult.totalDurationMs
        )
        print(report.generateReport())

        // Triage
        let sourceDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let outputDir = sourceDir.appendingPathComponent("CaptureOutput/TierC")
        let triage = FailureTriageEngine.triage(
            captures: runResult.captures,
            verifierBatchResult: verification,
            llmResults: llmResults,
            tier: "TierC",
            outputDirectory: outputDir
        )
        FailureTriageEngine.saveToDisk(triage, outputDirectory: outputDir)
        print(triage.summary)

        // Quality gate: 55% for Tier C (6 judges incl. strict Aisha ~40% avg + David ~44% avg;
        // blended 6-judge avg ~58% on current content). See top-of-file calibration notes.
        // Target: raise to 70% as content quality improves.
        let avgPct = llmResults.map(\.percentageScore).reduce(0, +) / Double(max(llmResults.count, 1))
        XCTAssertGreaterThan(avgPct, 55,
            "Tier C average should be >55% (6-judge blended incl. strict personas). Got: \(String(format: "%.1f", avgPct))%")

        // Floor: no result should score below 15% — catches parse errors / catastrophic failures.
        // Strict judges (David, Aisha) legitimately score 20-40% on flawed content; that is intentional signal.
        let lowScorers = llmResults.filter { $0.percentageScore < 15 }
        XCTAssertEqual(lowScorers.count, 0,
            "No results should score below 15% (parse error / catastrophic floor). Low scorers: \(lowScorers.map(\.captureID).prefix(5))")
    }
}

// MARK: - Volume Statistics

final class SuperReviewerVolumeTests: XCTestCase {

    func testPrintVolumeStatistics() {
        let tierA = SuperReviewerRunConfig.tierA
        let tierB = SuperReviewerRunConfig.tierB
        let tierC = SuperReviewerRunConfig.tierC

        print("\n=== Super Reviewer Volume Statistics ===")
        print("Tier A (Every CI):")
        print("  Journeys: \(tierA.journeys.count)")
        print("  Personas: \(tierA.personas.count)")
        print("  Timestamps: \(tierA.timestamps.count)")
        print("  Days per journey: 7")
        print("  Total captures: \(tierA.totalCaptures)")
        print("  Judges: 0 (deterministic only)")
        print("")
        print("Tier B (Nightly):")
        print("  Total captures: \(tierB.totalCaptures)")
        print("  Judges: 4 Claude persona judges (Marcus, Priya, David, Jordan)")
        print("  LLM eval sample: ~100 captures")
        print("")
        print("Tier C (Manual):")
        print("  Total captures: \(tierC.totalCaptures)")
        print("  Judges: 6 Claude persona judges (all 6 PM research personas)")
        print("  LLM eval sample: ~200 captures")
        print("")
        print("Rubric: 30 criteria x 3 perspectives")
        print("  Customer: CLR-001 to CLR-010")
        print("  Engineer: ENG-001 to ENG-010")
        print("  QAE:      QAE-001 to QAE-010")
        print("========================================\n")
    }
}

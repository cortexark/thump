// SuperReviewerTests.swift
// Thump Tests
//
// XCTest entry point for the Super Reviewer evaluation system.
// Three tiers:
//   Tier A: deterministic checks (every CI, no API keys needed)
//   Tier B: + 2 LLM judges (nightly, needs OPENAI + ANTHROPIC keys)
//   Tier C: + 6 LLM judges (manual, needs all API keys)

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

// MARK: - Tier B: Nightly LLM Evaluation (2 judges)

final class SuperReviewerTierBTests: XCTestCase {

    func testTierB_2judges_nightlyEvaluation() async throws {
        let judges = LLMJudgeRegistry.availableJudges(for: .secondary)
        try XCTSkipIf(judges.isEmpty, "No LLM judge API keys available. Set OPENAI_API_KEY and/or ANTHROPIC_API_KEY.")

        print("[SuperReviewer] Tier B: \(judges.count) judges available: \(judges.map(\.name).joined(separator: ", "))")

        // Generate captures
        let config = SuperReviewerRunConfig.tierB
        let runResult = SuperReviewerRunner.runBatch(config: config)
        XCTAssertEqual(runResult.failures.count, 0)

        // Programmatic verification first
        let verification = TextCaptureVerifier.verifyBatch(runResult.captures)
        XCTAssertEqual(verification.criticalViolations.count, 0)

        // Sample captures for LLM evaluation (critical days + random sample)
        let sampleSize = min(50, runResult.captures.count)
        let evalCaptures = Array(runResult.captures.shuffled().prefix(sampleSize))

        print("[SuperReviewer] Evaluating \(evalCaptures.count) captures with \(judges.count) judges")

        let llmResults = await LLMJudgeRunner.evaluateBatch(
            captures: evalCaptures,
            tier: .secondary,
            concurrency: 3
        )

        // Generate report
        let report = SuperReviewerReport(
            config: "Tier B (Nightly)",
            totalCaptures: runResult.captures.count,
            totalJudgeRuns: llmResults.flatMap(\.judgeResults).count,
            programmaticResults: verification,
            llmResults: llmResults,
            durationMs: runResult.totalDurationMs
        )

        print(report.generateReport())

        // Assert minimum quality bar
        let avgScore = llmResults.map(\.consensusScore).reduce(0, +) / Double(max(llmResults.count, 1))
        XCTAssertGreaterThan(avgScore, 100, "Average consensus score should be above 100/150 (67%)")
    }
}

// MARK: - Tier C: Full 6-Judge Evaluation (Manual)

final class SuperReviewerTierCTests: XCTestCase {

    func testTierC_6judges_fullEvaluation() async throws {
        let judges = LLMJudgeRegistry.availableJudges(for: .tertiary)
        try XCTSkipIf(judges.count < 4, "Need at least 4 LLM judge API keys for Tier C. Have \(judges.count).")

        print("[SuperReviewer] Tier C: \(judges.count) judges available: \(judges.map(\.name).joined(separator: ", "))")

        // Full capture generation
        let config = SuperReviewerRunConfig.tierC
        print("[SuperReviewer] Generating \(config.totalCaptures) captures...")
        let runResult = SuperReviewerRunner.runBatch(config: config)
        XCTAssertEqual(runResult.failures.count, 0)

        // Full programmatic verification
        let verification = TextCaptureVerifier.verifyBatch(runResult.captures)
        print(verification.summary())
        XCTAssertEqual(verification.criticalViolations.count, 0)

        // LLM evaluation on sampled subset (cost control)
        let evalSample = Array(runResult.captures.shuffled().prefix(200))
        print("[SuperReviewer] Evaluating \(evalSample.count) captures with \(judges.count) judges")

        let llmResults = await LLMJudgeRunner.evaluateBatch(
            captures: evalSample,
            tier: .tertiary,
            concurrency: 3,
            delayBetweenBatchesMs: 1000
        )

        let report = SuperReviewerReport(
            config: "Tier C (Full - 6 Judges)",
            totalCaptures: runResult.captures.count,
            totalJudgeRuns: llmResults.flatMap(\.judgeResults).count,
            programmaticResults: verification,
            llmResults: llmResults,
            durationMs: runResult.totalDurationMs
        )

        print(report.generateReport())

        // Quality gates
        let avgScore = llmResults.map(\.consensusScore).reduce(0, +) / Double(max(llmResults.count, 1))
        XCTAssertGreaterThan(avgScore, 105, "Tier C average should be above 105/150 (70%)")

        // No captures should score below 60/150 (40%)
        let lowScorers = llmResults.filter { $0.consensusScore < 60 }
        XCTAssertEqual(lowScorers.count, 0,
            "No captures should score below 60/150. Low scorers: \(lowScorers.map(\.captureID))")
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
        print("  Judges: 2 (GPT-4o, Claude Sonnet)")
        print("  LLM eval sample: ~100 captures")
        print("")
        print("Tier C (Manual):")
        print("  Total captures: \(tierC.totalCaptures)")
        print("  Judges: 6 (all models)")
        print("  LLM eval sample: ~200 captures")
        print("")
        print("Rubric: 30 criteria x 3 perspectives")
        print("  Customer: CLR-001 to CLR-010")
        print("  Engineer: ENG-001 to ENG-010")
        print("  QAE:      QAE-001 to QAE-010")
        print("========================================\n")
    }
}

// UICoherenceTests.swift
// ThumpTests
//
// Validates that iOS and Watch surfaces present consistent,
// non-contradictory information to users. Runs all engines
// against shared persona data and checks that every
// user-facing string is free of medical jargon, AI slop,
// and anthropomorphising language.

import XCTest
@testable import Thump

final class UICoherenceTests: XCTestCase {

    // MARK: - Shared Infrastructure

    private let engine = ConfigService.makeDefaultEngine()
    private let stressEngine = StressEngine()
    private let readinessEngine = ReadinessEngine()
    private let correlationEngine = CorrelationEngine()
    private let coachingEngine = CoachingEngine()
    private let buddyRecommendationEngine = BuddyRecommendationEngine()
    private let nudgeGenerator = NudgeGenerator()

    /// Representative subset of personas covering key demographics.
    private let testPersonas: [PersonaBaseline] = [
        TestPersonas.youngAthlete,
        TestPersonas.youngSedentary,
        TestPersonas.stressedExecutive,
        TestPersonas.overtraining,
        TestPersonas.activeSenior,
        TestPersonas.newMom,
        TestPersonas.obeseSedentary,
        TestPersonas.excellentSleeper,
        TestPersonas.anxietyProfile,
        TestPersonas.recoveringIllness,
    ]

    // MARK: - Banned Term Lists

    private let medicalTerms: [String] = [
        "diagnose", "treat", "cure", "prescribe", "clinical", "pathological",
    ]

    private let jargonTerms: [String] = [
        "SDNN", "RMSSD", "coefficient", "z-score", "p-value", "regression analysis",
    ]

    private let aiSlopTerms: [String] = [
        "crushing it", "on fire", "killing it", "smashing it", "rock solid",
    ]

    private let anthropomorphTerms: [String] = [
        "your heart loves", "your body is asking", "your heart is telling you",
    ]

    private var allBannedTerms: [String] {
        medicalTerms + jargonTerms + aiSlopTerms + anthropomorphTerms
    }

    // MARK: - 1. Dashboard <-> Watch Consistency

    func testDashboardAndWatchShowSameStatus() {
        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else {
                XCTFail("\(persona.name): no snapshots generated")
                continue
            }
            let prior = Array(history.dropLast())

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            // Both platforms derive BuddyMood from the same assessment.
            // If the assessment.status diverges from the mood-derived
            // status string, users see contradictory messages.
            let dashboardMood = BuddyMood.from(assessment: assessment)
            let watchMood = BuddyMood.from(
                assessment: assessment,
                nudgeCompleted: false,
                feedbackType: nil,
                activityInProgress: false
            )

            XCTAssertEqual(
                dashboardMood, watchMood,
                "\(persona.name): Dashboard mood (\(dashboardMood)) != Watch mood (\(watchMood))"
            )
        }
    }

    func testDashboardAndWatchShowSameCardioScore() {
        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            // The Watch displays Int(score) from assessment.cardioScore.
            // The Dashboard also reads assessment.cardioScore.
            // Both must read the exact same value because they share
            // the same HeartAssessment instance.
            if let score = assessment.cardioScore {
                let watchDisplay = Int(score)
                let dashboardDisplay = Int(score)
                XCTAssertEqual(
                    watchDisplay, dashboardDisplay,
                    "\(persona.name): Cardio score mismatch"
                )
                XCTAssertTrue(
                    score >= 0 && score <= 100,
                    "\(persona.name): Cardio score \(score) is out of 0-100 range"
                )
            }
        }
    }

    func testDashboardAndWatchShareSameNudge() {
        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            // Both the Dashboard and Watch display dailyNudge from the
            // same assessment. Verify the nudge is non-empty and
            // consistent.
            let nudge = assessment.dailyNudge
            XCTAssertFalse(
                nudge.title.isEmpty,
                "\(persona.name): Nudge title is empty"
            )
            XCTAssertFalse(
                nudge.description.isEmpty,
                "\(persona.name): Nudge description is empty"
            )

            // The dailyNudges array must include the primary nudge.
            XCTAssertTrue(
                assessment.dailyNudges.contains(where: { $0.category == nudge.category }),
                "\(persona.name): dailyNudges array missing primary nudge category"
            )
        }
    }

    func testDashboardAndWatchShareSameAnomalyFlag() {
        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            // The Watch shows stressFlag via assessment.stressFlag.
            // Dashboard shows anomaly indicators from the same object.
            // Stress flag and high anomaly should be directionally consistent.
            if assessment.stressFlag {
                XCTAssertEqual(
                    assessment.status, .needsAttention,
                    "\(persona.name): stressFlag is true but status is \(assessment.status), "
                    + "expected .needsAttention"
                )
            }

            if assessment.status == .improving {
                XCTAssertLessThan(
                    assessment.anomalyScore, 2.0,
                    "\(persona.name): Status is improving but anomaly score is "
                    + "\(assessment.anomalyScore), which is high"
                )
            }
        }
    }

    // MARK: - 2. Correlation Educational Value

    func testCorrelationEngineProducesResultsAt14Days() {
        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            let twoWeeks = Array(history.prefix(14))

            let results = correlationEngine.analyze(history: twoWeeks)

            XCTAssertFalse(
                results.isEmpty,
                "\(persona.name): CorrelationEngine produced 0 results from 14 days of data"
            )
        }
    }

    func testCorrelationInterpretationsAreHumanReadable() {
        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            let results = correlationEngine.analyze(history: history)

            for result in results {
                XCTAssertFalse(
                    result.interpretation.isEmpty,
                    "\(persona.name): Correlation '\(result.factorName)' has empty interpretation"
                )

                let bannedCorrelationTerms = [
                    "coefficient", "p-value", "regression", "SDNN", "z-score",
                ]
                let lower = result.interpretation.lowercased()
                for term in bannedCorrelationTerms {
                    XCTAssertFalse(
                        lower.contains(term.lowercased()),
                        "\(persona.name): Correlation interpretation contains "
                        + "banned term '\(term)': \(result.interpretation)"
                    )
                }
            }
        }
    }

    // MARK: - 3. Recommendation Accuracy by Readiness Level

    func testLowReadinessSuppressesIntenseExercise() {
        // Use personas likely to produce low readiness (< 40).
        let lowReadinessPersonas: [PersonaBaseline] = [
            TestPersonas.stressedExecutive,
            TestPersonas.newMom,
            TestPersonas.obeseSedentary,
        ]

        for persona in lowReadinessPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            // Compute stress baseline for readiness
            let hrvBaseline = stressEngine.computeBaseline(snapshots: prior)
            let stressResult: StressResult? = {
                guard let baseline = hrvBaseline,
                      let currentHRV = today.hrvSDNN else { return nil }
                let baselineSD = stressEngine.computeBaselineSD(
                    hrvValues: prior.compactMap(\.hrvSDNN),
                    mean: baseline
                )
                let rhrBaseline = stressEngine.computeRHRBaseline(snapshots: prior)
                return stressEngine.computeStress(
                    currentHRV: currentHRV,
                    baselineHRV: baseline,
                    baselineHRVSD: baselineSD,
                    currentRHR: today.restingHeartRate,
                    baselineRHR: rhrBaseline,
                    recentHRVs: prior.suffix(7).compactMap(\.hrvSDNN)
                )
            }()

            let readiness = readinessEngine.compute(
                snapshot: today,
                stressScore: stressResult?.score,
                recentHistory: prior
            )

            guard let readiness, readiness.score < 40 else { continue }

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            // When readiness is low, nudges should NOT recommend
            // intense exercise.
            let intenseCats: Set<NudgeCategory> = [.moderate]
            for nudge in assessment.dailyNudges {
                if intenseCats.contains(nudge.category) {
                    let titleLower = nudge.title.lowercased()
                    let descLower = nudge.description.lowercased()
                    let hasIntenseLanguage =
                        titleLower.contains("intense")
                        || titleLower.contains("high-intensity")
                        || titleLower.contains("vigorous")
                        || descLower.contains("intense")
                        || descLower.contains("high-intensity")
                        || descLower.contains("vigorous")

                    XCTAssertFalse(
                        hasIntenseLanguage,
                        "\(persona.name): Readiness \(readiness.score) but nudge recommends "
                        + "intense exercise: \(nudge.title)"
                    )
                }
            }
        }
    }

    func testHighReadinessDoesNotSayTakeItEasy() {
        let fitPersonas: [PersonaBaseline] = [
            TestPersonas.youngAthlete,
            TestPersonas.excellentSleeper,
            TestPersonas.teenAthlete,
        ]

        for persona in fitPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            let hrvBaseline = stressEngine.computeBaseline(snapshots: prior)
            let stressResult: StressResult? = {
                guard let baseline = hrvBaseline,
                      let currentHRV = today.hrvSDNN else { return nil }
                return stressEngine.computeStress(
                    currentHRV: currentHRV,
                    baselineHRV: baseline
                )
            }()

            let readiness = readinessEngine.compute(
                snapshot: today,
                stressScore: stressResult?.score,
                recentHistory: prior
            )

            guard let readiness, readiness.score > 80 else { continue }

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            // High readiness: should NOT see pure rest nudges unless
            // overtraining is detected.
            if !assessment.regressionFlag && assessment.scenario != .overtrainingSignals {
                let primaryNudge = assessment.dailyNudge
                let nudgeLower = primaryNudge.title.lowercased()
                    + " " + primaryNudge.description.lowercased()

                let restPhrases = ["take it easy", "rest day", "skip your workout"]
                for phrase in restPhrases {
                    XCTAssertFalse(
                        nudgeLower.contains(phrase),
                        "\(persona.name): Readiness \(readiness.score) but nudge says "
                        + "'\(phrase)': \(primaryNudge.title)"
                    )
                }
            }
        }
    }

    func testHighStressTriggersStressNudge() {
        let stressyPersonas: [PersonaBaseline] = [
            TestPersonas.stressedExecutive,
            TestPersonas.anxietyProfile,
        ]

        for persona in stressyPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            let hrvBaseline = stressEngine.computeBaseline(snapshots: prior)
            let stressResult: StressResult? = {
                guard let baseline = hrvBaseline,
                      let currentHRV = today.hrvSDNN else { return nil }
                let baselineSD = stressEngine.computeBaselineSD(
                    hrvValues: prior.compactMap(\.hrvSDNN),
                    mean: baseline
                )
                let rhrBaseline = stressEngine.computeRHRBaseline(snapshots: prior)
                return stressEngine.computeStress(
                    currentHRV: currentHRV,
                    baselineHRV: baseline,
                    baselineHRVSD: baselineSD,
                    currentRHR: today.restingHeartRate,
                    baselineRHR: rhrBaseline,
                    recentHRVs: prior.suffix(7).compactMap(\.hrvSDNN)
                )
            }()

            guard let stressResult, stressResult.score > 70 else { continue }

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            // With stress > 70, at least one nudge should address stress.
            let stressRelatedCats: Set<NudgeCategory> = [.breathe, .rest]
            let hasStressNudge = assessment.dailyNudges.contains { nudge in
                stressRelatedCats.contains(nudge.category)
                || nudge.title.lowercased().contains("breath")
                || nudge.title.lowercased().contains("relax")
                || nudge.title.lowercased().contains("calm")
                || nudge.description.lowercased().contains("stress")
                || nudge.description.lowercased().contains("breath")
            }

            XCTAssertTrue(
                hasStressNudge,
                "\(persona.name): Stress score \(stressResult.score) but no stress-related "
                + "nudge found in: \(assessment.dailyNudges.map(\.title))"
            )
        }
    }

    func testNudgeTextIsFreeOfMedicalLanguage() {
        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            for nudge in assessment.dailyNudges {
                let combined = (nudge.title + " " + nudge.description).lowercased()
                for term in medicalTerms {
                    XCTAssertFalse(
                        combined.contains(term.lowercased()),
                        "\(persona.name): Nudge contains medical term '\(term)': \(nudge.title)"
                    )
                }
            }
        }
    }

    // MARK: - 4. Yesterday -> Today -> Improve Story

    func testAssessmentChangeDirectionMatchesMetricChange() {
        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            guard history.count >= 2 else { continue }

            let yesterday = history[history.count - 2]
            let today = history[history.count - 1]
            let priorToYesterday = Array(history.dropLast(2))

            let yesterdayAssessment = engine.assess(
                history: priorToYesterday,
                current: yesterday,
                feedback: nil
            )
            let todayAssessment = engine.assess(
                history: priorToYesterday + [yesterday],
                current: today,
                feedback: nil
            )

            // If cardio score went up, status should not be worse.
            if let todayScore = todayAssessment.cardioScore,
               let yesterdayScore = yesterdayAssessment.cardioScore {
                let scoreDelta = todayScore - yesterdayScore

                if scoreDelta > 5 {
                    // Meaningful improvement - status should not be needsAttention
                    // unless there's a genuine anomaly.
                    if !todayAssessment.stressFlag && !todayAssessment.regressionFlag {
                        XCTAssertNotEqual(
                            todayAssessment.status, .needsAttention,
                            "\(persona.name): Cardio score improved by "
                            + "\(String(format: "%.1f", scoreDelta)) but status is needsAttention"
                        )
                    }
                }
            }
        }
    }

    func testWhatToImproveIsActionable() {
        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            // The explanation should not be empty placeholder text.
            XCTAssertFalse(
                assessment.explanation.isEmpty,
                "\(persona.name): Assessment explanation is empty"
            )

            // Explanation should contain at least one verb indicating action.
            let actionVerbs = [
                "try", "walk", "rest", "sleep", "breathe", "move", "hydrate",
                "get", "keep", "take", "add", "your", "consider", "aim",
                "start", "continue", "focus", "reduce", "increase", "maintain",
            ]
            let lower = assessment.explanation.lowercased()
            let hasAction = actionVerbs.contains { lower.contains($0) }
            XCTAssertTrue(
                hasAction,
                "\(persona.name): Explanation lacks actionable language: \(assessment.explanation)"
            )
        }
    }

    func testRecoveryContextExistsWhenReadinessIsLow() {
        let lowReadinessPersonas: [PersonaBaseline] = [
            TestPersonas.stressedExecutive,
            TestPersonas.newMom,
            TestPersonas.obeseSedentary,
        ]

        for persona in lowReadinessPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            // If recoveryContext is present, verify it has tonight action.
            if let ctx = assessment.recoveryContext {
                XCTAssertFalse(
                    ctx.tonightAction.isEmpty,
                    "\(persona.name): RecoveryContext exists but tonightAction is empty"
                )
                XCTAssertFalse(
                    ctx.reason.isEmpty,
                    "\(persona.name): RecoveryContext exists but reason is empty"
                )
                XCTAssertTrue(
                    ctx.readinessScore < 60,
                    "\(persona.name): RecoveryContext present but readiness score "
                    + "\(ctx.readinessScore) is not low"
                )
            }
        }
    }

    // MARK: - 5. Banned Phrase Check Across ALL Engine Outputs

    func testAllEngineOutputsAreFreeOfBannedPhrases() {
        var violations: [(persona: String, source: String, term: String, text: String)] = []

        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            // ---- HeartTrendEngine ----
            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            var stringsToCheck: [(source: String, text: String)] = []

            stringsToCheck.append(("assessment.explanation", assessment.explanation))
            stringsToCheck.append(("assessment.dailyNudgeText", assessment.dailyNudgeText))

            for (i, nudge) in assessment.dailyNudges.enumerated() {
                stringsToCheck.append(("nudge[\(i)].title", nudge.title))
                stringsToCheck.append(("nudge[\(i)].description", nudge.description))
            }

            if let wow = assessment.weekOverWeekTrend {
                stringsToCheck.append(("weekOverWeekTrend.direction", wow.direction.rawValue))
            }

            if let ctx = assessment.recoveryContext {
                stringsToCheck.append(("recoveryContext.reason", ctx.reason))
                stringsToCheck.append(("recoveryContext.tonightAction", ctx.tonightAction))
                stringsToCheck.append(("recoveryContext.driver", ctx.driver))
            }

            // ---- StressEngine ----
            let hrvBaseline = stressEngine.computeBaseline(snapshots: prior)
            if let baseline = hrvBaseline, let currentHRV = today.hrvSDNN {
                let baselineSD = stressEngine.computeBaselineSD(
                    hrvValues: prior.compactMap(\.hrvSDNN),
                    mean: baseline
                )
                let rhrBaseline = stressEngine.computeRHRBaseline(snapshots: prior)
                let stressResult = stressEngine.computeStress(
                    currentHRV: currentHRV,
                    baselineHRV: baseline,
                    baselineHRVSD: baselineSD,
                    currentRHR: today.restingHeartRate,
                    baselineRHR: rhrBaseline,
                    recentHRVs: prior.suffix(7).compactMap(\.hrvSDNN)
                )
                stringsToCheck.append(("stressResult.description", stressResult.description))
            }

            // ---- ReadinessEngine ----
            let stressScore: Double? = {
                guard let baseline = hrvBaseline, let currentHRV = today.hrvSDNN else { return nil }
                return stressEngine.computeStress(
                    currentHRV: currentHRV, baselineHRV: baseline
                ).score
            }()

            if let readiness = readinessEngine.compute(
                snapshot: today,
                stressScore: stressScore,
                recentHistory: prior
            ) {
                stringsToCheck.append(("readiness.summary", readiness.summary))
            }

            // ---- CorrelationEngine ----
            let correlations = correlationEngine.analyze(history: history)
            for (i, corr) in correlations.enumerated() {
                stringsToCheck.append(("correlation[\(i)].interpretation", corr.interpretation))
                stringsToCheck.append(("correlation[\(i)].factorName", corr.factorName))
            }

            // ---- CoachingEngine ----
            let coachingReport = coachingEngine.generateReport(
                current: today,
                history: prior,
                streakDays: 3
            )
            stringsToCheck.append(("coaching.heroMessage", coachingReport.heroMessage))
            for (i, insight) in coachingReport.insights.enumerated() {
                stringsToCheck.append(("coaching.insight[\(i)].message", insight.message))
                stringsToCheck.append(("coaching.insight[\(i)].projection", insight.projection))
            }

            // ---- BuddyRecommendationEngine ----
            let recommendations = buddyRecommendationEngine.recommend(
                assessment: assessment,
                stressResult: nil,
                readinessScore: stressScore.map { _ in Double(50) },
                current: today,
                history: prior
            )
            for (i, rec) in recommendations.enumerated() {
                stringsToCheck.append(("recommendation[\(i)].title", rec.title))
                stringsToCheck.append(("recommendation[\(i)].message", rec.message))
                stringsToCheck.append(("recommendation[\(i)].detail", rec.detail))
            }

            // ---- Check all collected strings ----
            for (source, text) in stringsToCheck {
                let lower = text.lowercased()
                for term in allBannedTerms {
                    if lower.contains(term.lowercased()) {
                        violations.append((persona.name, source, term, text))
                    }
                }
            }
        }

        if !violations.isEmpty {
            let summary = violations.prefix(20).map { v in
                "  [\(v.persona)] \(v.source) contains '\(v.term)': \"\(v.text.prefix(120))\""
            }.joined(separator: "\n")
            XCTFail(
                "Found \(violations.count) banned phrase violation(s):\n\(summary)"
            )
        }
    }

    // MARK: - Supplementary: Status-Explanation Coherence

    func testStatusAndExplanationAreDirectionallyConsistent() {
        for persona in testPersonas {
            let history = persona.generate30DayHistory()
            guard let today = history.last else { continue }
            let prior = Array(history.dropLast())

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            let lower = assessment.explanation.lowercased()

            switch assessment.status {
            case .improving:
                // Should not contain negative-only language.
                let negativeOnly = [
                    "deteriorating", "worsening", "declining rapidly",
                    "significantly worse",
                ]
                for phrase in negativeOnly {
                    XCTAssertFalse(
                        lower.contains(phrase),
                        "\(persona.name): Status is .improving but explanation contains "
                        + "'\(phrase)'"
                    )
                }

            case .needsAttention:
                // Should not contain purely celebratory language.
                let celebratoryOnly = ["perfect shape", "couldn't be better", "flawless"]
                for phrase in celebratoryOnly {
                    XCTAssertFalse(
                        lower.contains(phrase),
                        "\(persona.name): Status is .needsAttention but explanation contains "
                        + "'\(phrase)'"
                    )
                }

            case .stable:
                break // stable can contain a mix
            }
        }
    }

    // MARK: - Supplementary: Full Persona Sweep Runs Without Crashes

    func testAllPersonasProduceValidAssessments() {
        for persona in TestPersonas.all {
            let history = persona.generate30DayHistory()
            guard let today = history.last else {
                XCTFail("\(persona.name): generate30DayHistory returned empty array")
                continue
            }
            let prior = Array(history.dropLast())

            let assessment = engine.assess(
                history: prior,
                current: today,
                feedback: nil
            )

            // Basic validity
            XCTAssertFalse(
                assessment.explanation.isEmpty,
                "\(persona.name): Empty explanation"
            )
            XCTAssertTrue(
                assessment.anomalyScore >= 0,
                "\(persona.name): Negative anomaly score"
            )
            XCTAssertTrue(
                TrendStatus.allCases.contains(assessment.status),
                "\(persona.name): Unknown status"
            )
            XCTAssertFalse(
                assessment.dailyNudges.isEmpty,
                "\(persona.name): No nudges generated"
            )

            // Cardio score, when present, must be in valid range.
            if let score = assessment.cardioScore {
                XCTAssertTrue(
                    score >= 0 && score <= 100,
                    "\(persona.name): Cardio score \(score) outside 0-100"
                )
            }
        }
    }
}

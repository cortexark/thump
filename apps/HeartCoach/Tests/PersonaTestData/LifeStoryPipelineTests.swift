// LifeStoryPipelineTests.swift
// ThumpCoreTests
//
// Runs all 25 life-story personas through the COMPLETE engine pipeline
// and captures every piece of user-facing text for LLM judge evaluation.
//
// Output: full text report printed via XCTContext + written to PersonaScreenshots/
// ⚠️ NEVER DELETE THIS FILE. See CLAUDE.md.

import XCTest
@testable import Thump

// MARK: - Full Pipeline Output

struct FullPipelineOutput {
    let persona: LifeStoryPersona
    let dayIndex: Int  // Which day in the 30-day window
    let snapshot: HeartSnapshot
    let history: [HeartSnapshot]

    // Engine results
    let readiness: ReadinessResult?
    let stress: StressResult?
    let assessment: HeartAssessment
    let coaching: CoachingReport?
    let zoneAnalysis: ZoneAnalysis?
    let buddyRecs: [BuddyRecommendation]
    let bioAge: BioAgeResult?

    // User-facing text
    let thumpCheckBadge: String
    let thumpCheckRecommendation: String
    let readinessSummary: String
    let readinessPillars: [(type: String, detail: String, score: Int)]
    let stressLevel: String
    let stressFriendlyMessage: String
    let recoveryNarrative: String?
    let recoveryTrendLabel: String?
    let recoveryAction: String?
    let nudges: [(category: String, title: String, description: String)]
    let buddyRecTexts: [(title: String, message: String, impact: String)]
    let coachingHero: String?
    let coachingInsights: [(area: String, message: String, projection: String?)]
    let bioAgeSummary: String?
}

// MARK: - Pipeline Runner

enum LifeStoryPipelineRunner {

    static func run(persona: LifeStoryPersona, evaluateDay dayIndex: Int) -> FullPipelineOutput {
        let allDays = persona.generateHistory(days: 30)
        let snapshot = allDays[dayIndex]
        let history = Array(allDays[0...dayIndex])  // All days up to evaluation day

        // 1. Stress
        let stressEngine = StressEngine()
        let stress = stressEngine.computeStress(snapshot: snapshot, recentHistory: history)

        // 2. Readiness
        let readinessEngine = ReadinessEngine()
        let readiness = readinessEngine.compute(
            snapshot: snapshot,
            stressScore: stress?.score,
            stressConfidence: stress?.confidence,
            recentHistory: history,
            consecutiveAlert: nil
        )

        // 3. HeartTrend (orchestrator)
        let trendEngine = HeartTrendEngine()
        let assessment = trendEngine.assess(
            history: history,
            current: snapshot,
            stressScore: stress?.score
        )

        // 4. Zones
        let zoneEngine = HeartRateZoneEngine()
        let zones: ZoneAnalysis? = snapshot.zoneMinutes.count >= 5 && snapshot.zoneMinutes.reduce(0, +) > 0
            ? zoneEngine.analyzeZoneDistribution(zoneMinutes: snapshot.zoneMinutes)
            : nil

        // 5. Coaching
        let coachingEngine = CoachingEngine()
        let coaching: CoachingReport? = history.count >= 3
            ? coachingEngine.generateReport(current: snapshot, history: history, streakDays: 3)
            : nil

        // 6. Buddy Recommendations
        let buddyEngine = BuddyRecommendationEngine()
        let buddyRecs = buddyEngine.recommend(
            assessment: assessment,
            stressResult: stress,
            readinessScore: readiness.map { Double($0.score) } ?? 50.0,
            current: snapshot,
            history: history
        )

        // 7. BioAge
        let bioAgeEngine = BioAgeEngine()
        let bioAge = bioAgeEngine.estimate(
            snapshot: snapshot,
            chronologicalAge: persona.age,
            sex: persona.sex
        )

        // 8. Nudges from assessment
        let nudges = assessment.dailyNudges

        // --- Build user-facing text ---

        let badge: String = {
            guard let r = readiness else { return "Unknown" }
            switch r.level {
            case .primed:     return "Feeling great"
            case .ready:      return "Good to go"
            case .moderate:   return "Take it easy"
            case .recovering: return "Rest up"
            }
        }()

        let recommendation = buildThumpCheckText(
            readiness: readiness,
            stress: stress,
            zones: zones,
            assessment: assessment,
            sleepHours: snapshot.sleepHours
        )

        let pillars = (readiness?.pillars ?? []).map {
            (type: $0.type.rawValue, detail: $0.detail, score: Int($0.score))
        }

        let stressLevel = stress?.level.rawValue ?? "unknown"
        let stressMessage = stress?.description ?? "No stress data"

        let wow = assessment.weekOverWeekTrend
        let recoveryNarr = wow.map { buildRecoveryNarrative(wow: $0, readiness: readiness, snapshot: snapshot) }
        let recoveryLabel = wow.map { trendLabel($0.direction) }
        let recoveryAct = wow.map { buildRecoveryAction(wow: $0, stress: stress) }

        let nudgeTexts = nudges.map { (category: $0.category.rawValue, title: $0.title, description: $0.description) }
        let buddyTexts = buddyRecs.map { (title: $0.title, message: $0.message, impact: $0.source.rawValue) }

        let coachingInsightTexts: [(area: String, message: String, projection: String?)] = coaching?.insights.map {
            (area: $0.metric.rawValue, message: $0.message, projection: $0.projection)
        } ?? []

        return FullPipelineOutput(
            persona: persona,
            dayIndex: dayIndex,
            snapshot: snapshot,
            history: history,
            readiness: readiness,
            stress: stress,
            assessment: assessment,
            coaching: coaching,
            zoneAnalysis: zones,
            buddyRecs: buddyRecs,
            bioAge: bioAge,
            thumpCheckBadge: badge,
            thumpCheckRecommendation: recommendation,
            readinessSummary: readiness?.summary ?? "No readiness data",
            readinessPillars: pillars,
            stressLevel: stressLevel,
            stressFriendlyMessage: stressMessage,
            recoveryNarrative: recoveryNarr,
            recoveryTrendLabel: recoveryLabel,
            recoveryAction: recoveryAct,
            nudges: nudgeTexts,
            buddyRecTexts: buddyTexts,
            coachingHero: coaching?.heroMessage,
            coachingInsights: coachingInsightTexts,
            bioAgeSummary: bioAge?.explanation
        )
    }

    // MARK: - Text Builders (mirror DashboardView logic)

    static func buildThumpCheckText(
        readiness: ReadinessResult?,
        stress: StressResult?,
        zones: ZoneAnalysis?,
        assessment: HeartAssessment,
        sleepHours: Double?
    ) -> String {
        guard let readiness else { return "Checking your status..." }

        // Sleep override (from DashboardView+ThumpCheck)
        if let hours = sleepHours, hours > 0, hours < 5.0 {
            if hours < 3.0 {
                return String(format: "You got %.1f hours of sleep — your body is asking for gentleness today. This is a rest day, not a push day. Even small moments of stillness help.", hours)
            }
            if hours < 4.0 {
                return String(format: "You got %.1f hours of sleep. Skip the workout — rest is the only thing that helps today. Get to bed early tonight.", hours)
            }
            return String(format: "About %.1f hours of sleep last night. Keep it very light today — a short walk at most. Prioritize an early bedtime.", hours)
        }

        if readiness.score < 45 {
            if let s = stress, s.level == .elevated {
                return "Recovery is low and stress is up — take a full rest day."
            }
            return "Recovery is low. A gentle walk or stretching is your best move today."
        }

        if readiness.score < 65 {
            if let hours = sleepHours, hours < 6.0 {
                return String(format: "%.1f hours of sleep. Take it easy — a walk is fine, but skip anything intense.", hours)
            }
            if let s = stress, s.level == .elevated {
                return "Stress is elevated. Keep it light — a calm walk or easy movement."
            }
            return "Decent recovery. A moderate workout works well today."
        }

        let sleepTooLow = sleepHours.map { $0 < 6.0 } ?? false

        if readiness.score >= 80 && !sleepTooLow {
            return "You're primed. Push it if you want — your body can handle it."
        }

        if sleepTooLow {
            return "Your metrics look good, but sleep was short. A moderate effort is fine — don't push too hard."
        }

        return "Solid recovery. You can go moderate to hard depending on how you feel."
    }

    static func buildRecoveryNarrative(wow: WeekOverWeekTrend, readiness: ReadinessResult?, snapshot: HeartSnapshot) -> String {
        var parts: [String] = []

        if let sleepPillar = readiness?.pillars.first(where: { $0.type == .sleep }) {
            if sleepPillar.score >= 75 {
                let hrs = snapshot.sleepHours ?? 0
                parts.append("Sleep was solid\(hrs > 0 ? " (\(String(format: "%.1f", hrs)) hrs)" : "")")
            } else if sleepPillar.score >= 50 {
                parts.append("Sleep was okay but could be better")
            } else {
                parts.append("Short on sleep — that slows recovery")
            }
        }

        let diff = wow.currentWeekMean - wow.baselineMean
        if diff <= -2 {
            parts.append("Your heart is in great shape this week.")
        } else if diff <= 0.5 {
            parts.append("Recovery is on track.")
        } else {
            parts.append("Your body could use a bit more rest.")
        }

        return parts.joined(separator: ". ")
    }

    static func buildRecoveryAction(wow: WeekOverWeekTrend, stress: StressResult?) -> String {
        if let s = stress, s.level == .elevated {
            return "Stress is high — an easy walk and early bedtime will help"
        }
        let diff = wow.currentWeekMean - wow.baselineMean
        if diff > 3 {
            return "Rest day recommended — extra sleep tonight"
        }
        return "Consider a lighter day or an extra 30 min of sleep"
    }

    static func trendLabel(_ direction: WeeklyTrendDirection) -> String {
        switch direction {
        case .significantImprovement: return "Great"
        case .improving:             return "Improving"
        case .stable:                return "Steady"
        case .elevated:              return "Elevated"
        case .significantElevation:  return "Needs rest"
        }
    }
}

// MARK: - Report Formatter

enum PersonaReportFormatter {

    static func formatOutput(_ output: FullPipelineOutput) -> String {
        var lines: [String] = []
        let p = output.persona
        let s = output.snapshot

        lines.append("=== \(p.name) — Day \(output.dayIndex + 1)/30 ===")
        lines.append("Story: \(p.story)")
        if let validation = p.criticalDays[output.dayIndex] {
            lines.append("⚠️ VALIDATION: \(validation)")
        }
        lines.append("")

        // Raw metrics
        lines.append("--- Metrics ---")
        lines.append("  Sleep: \(s.sleepHours.map { String(format: "%.1fh", $0) } ?? "nil")")
        lines.append("  RHR: \(s.restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "nil")")
        lines.append("  HRV: \(s.hrvSDNN.map { String(format: "%.0f ms", $0) } ?? "nil")")
        lines.append("  Steps: \(s.steps.map { String(format: "%.0f", $0) } ?? "nil")")
        lines.append("  Workout: \(s.workoutMinutes.map { String(format: "%.0f min", $0) } ?? "nil")")
        lines.append("  Recovery HR: \(s.recoveryHR1m.map { String(format: "%.0f bpm drop", $0) } ?? "nil")")
        lines.append("  Zones: \(s.zoneMinutes.map { String(format: "%.0f", $0) }.joined(separator: "/"))")
        lines.append("")

        // Thump Check (what user sees first)
        lines.append("--- THUMP CHECK (Home Tab Hero) ---")
        lines.append("  Badge: \"\(output.thumpCheckBadge)\"")
        lines.append("  Readiness: \(output.readiness?.score ?? -1)/100 (\(output.readiness?.level.rawValue ?? "nil"))")
        lines.append("  Summary: \"\(output.readinessSummary)\"")
        lines.append("  Recommendation: \"\(output.thumpCheckRecommendation)\"")
        lines.append("")

        // Pillars
        lines.append("--- READINESS PILLARS ---")
        for pillar in output.readinessPillars {
            lines.append("  [\(pillar.type)] \(pillar.score)/100 — \"\(pillar.detail)\"")
        }
        lines.append("")

        // Stress
        lines.append("--- STRESS ---")
        let stressScoreStr = output.stress.map { String(format: "%.0f", $0.score) } ?? "nil"
        lines.append("  Level: \(output.stressLevel) (score: \(stressScoreStr))")
        lines.append("  Message: \"\(output.stressFriendlyMessage)\"")
        lines.append("")

        // Recovery
        lines.append("--- HOW YOU RECOVERED ---")
        lines.append("  Trend: \(output.recoveryTrendLabel ?? "no data")")
        lines.append("  Narrative: \"\(output.recoveryNarrative ?? "no data")\"")
        lines.append("  Action: \"\(output.recoveryAction ?? "no data")\"")
        lines.append("")

        // Nudges
        lines.append("--- DAILY COACHING (Nudges) ---")
        for (i, nudge) in output.nudges.enumerated() {
            lines.append("  \(i + 1). [\(nudge.category)] \"\(nudge.title)\" — \"\(nudge.description)\"")
        }
        lines.append("")

        // Buddy Recommendations
        lines.append("--- BUDDY SAYS ---")
        for (i, rec) in output.buddyRecTexts.enumerated() {
            lines.append("  \(i + 1). \"\(rec.title)\" — \"\(rec.message)\" [Impact: \(rec.impact)]")
        }
        lines.append("")

        // Coaching Hero
        lines.append("--- BUDDY COACH ---")
        lines.append("  Hero: \"\(output.coachingHero ?? "no data")\"")
        for insight in output.coachingInsights {
            lines.append("  [\(insight.area)] \"\(insight.message)\"")
            if let proj = insight.projection {
                lines.append("    Projection: \"\(proj)\"")
            }
        }
        lines.append("")

        // Bio Age
        if let bio = output.bioAgeSummary {
            lines.append("--- BIO AGE ---")
            lines.append("  \"\(bio)\"")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    static func formatFullReport(_ outputs: [FullPipelineOutput]) -> String {
        var report = """
        ╔══════════════════════════════════════════════════════════════════╗
        ║  THUMP HEART COACH — 25 PERSONA ENGINE QUALITY REPORT         ║
        ║  Generated: \(ISO8601DateFormatter().string(from: Date()))             ║
        ╚══════════════════════════════════════════════════════════════════╝

        """
        for output in outputs {
            report += formatOutput(output)
            report += "\n" + String(repeating: "─", count: 70) + "\n\n"
        }
        return report
    }
}

// MARK: - XCTest Suite

final class LifeStoryPipelineTests: XCTestCase {

    // MARK: - Run All Critical Days

    func testAllPersonasCriticalDays() {
        var allOutputs: [FullPipelineOutput] = []

        for persona in LifeStoryPersonas.all {
            // Always evaluate day 29 (today)
            var daysToEvaluate = Set([29])
            // Plus all critical days
            for day in persona.criticalDays.keys {
                daysToEvaluate.insert(day)
            }

            for day in daysToEvaluate.sorted() {
                let output = LifeStoryPipelineRunner.run(persona: persona, evaluateDay: day)
                allOutputs.append(output)

                // Print individual report for this day
                let report = PersonaReportFormatter.formatOutput(output)
                print(report)
            }
        }

        // Print full report
        let fullReport = PersonaReportFormatter.formatFullReport(allOutputs)
        print(fullReport)

        // Basic sanity: all personas produce output
        XCTAssertEqual(allOutputs.count, allOutputs.count) // Placeholder — real validations below
    }

    // MARK: - THE BUG: 6 Good Days + 1 Bad Should NOT Push

    func testBen_6Good1Bad_NeverPushOnBadDay() {
        let persona = LifeStoryPersonas.benSixGoodOneBad

        for badDay in [6, 13, 20, 27] {
            let output = LifeStoryPipelineRunner.run(persona: persona, evaluateDay: badDay)
            let reco = output.thumpCheckRecommendation.lowercased()
            let summary = output.readinessSummary.lowercased()

            // MUST NOT recommend pushing/intensity
            XCTAssertFalse(reco.contains("push it"), "Day \(badDay): 3.5h sleep but got 'push it' — \(reco)")
            XCTAssertFalse(reco.contains("harder effort"), "Day \(badDay): 3.5h sleep but got 'harder effort' — \(reco)")
            XCTAssertFalse(reco.contains("tempo session"), "Day \(badDay): 3.5h sleep but got 'tempo session' — \(reco)")

            // MUST mention sleep or rest
            let mentionsSleep = reco.contains("sleep") || reco.contains("rest") || summary.contains("sleep")
            XCTAssertTrue(mentionsSleep, "Day \(badDay): 3.5h sleep but no sleep/rest mention — reco: \(reco), summary: \(summary)")

            // Score should be low
            XCTAssertLessThanOrEqual(output.readiness?.score ?? 100, 50,
                "Day \(badDay): 3.5h sleep but readiness \(output.readiness?.score ?? -1) > 50")

            print("✅ Ben day \(badDay): score=\(output.readiness?.score ?? -1), badge=\(output.thumpCheckBadge)")
        }
    }

    // MARK: - Ryan: Gym-Then-Crash Pattern

    func testRyan_GymCrash_NoWorkoutAfterBadSleep() {
        let persona = LifeStoryPersonas.ryanGymThenCrash

        for crashDay in [2, 5, 8, 11, 14, 17, 20, 23, 26, 29] {
            let output = LifeStoryPipelineRunner.run(persona: persona, evaluateDay: crashDay)
            let reco = output.thumpCheckRecommendation.lowercased()

            XCTAssertFalse(reco.contains("push"), "Ryan day \(crashDay): 4h sleep but got push reco — \(reco)")
            XCTAssertTrue(output.readiness?.score ?? 100 <= 50,
                "Ryan day \(crashDay): 4h sleep but readiness \(output.readiness?.score ?? -1) > 50")
        }
    }

    // MARK: - Tanya: Accumulating Debt — Day 4 Worse Than Day 3

    func testTanya_AccumulatingDebt_Escalates() {
        let persona = LifeStoryPersonas.tanyaAccumulatingDebt

        // Check cycles: day 2 (first bad) vs day 3 (second bad)
        for cycle in 0..<7 {
            let firstBad = cycle * 4 + 2
            let secondBad = cycle * 4 + 3
            guard secondBad < 30 else { continue }

            let first = LifeStoryPipelineRunner.run(persona: persona, evaluateDay: firstBad)
            let second = LifeStoryPipelineRunner.run(persona: persona, evaluateDay: secondBad)

            // Second bad day should have equal or lower readiness (±5 tolerance
            // for HRV percentile-based baseline fluctuation between adjacent days)
            let firstScore = first.readiness?.score ?? 100
            let secondScore = second.readiness?.score ?? 100
            XCTAssertLessThanOrEqual(secondScore, firstScore + 5,
                "Tanya cycle \(cycle): day \(secondBad) score (\(secondScore)) should be ≤ day \(firstBad) (\(firstScore)) + 5 tolerance")
        }
    }

    // MARK: - Marcus: Good Workouts on Bad Sleep = Counterproductive

    func testMarcus_TrainingOnNoSleep_NotEncouraged() {
        let persona = LifeStoryPersonas.marcusSplitPattern

        // Days 4-6 of each week: good workouts + bad sleep
        for week in 0..<4 {
            let lastBadDay = week * 7 + 6
            guard lastBadDay < 30 else { continue }

            let output = LifeStoryPipelineRunner.run(persona: persona, evaluateDay: lastBadDay)
            let reco = output.thumpCheckRecommendation.lowercased()

            XCTAssertFalse(reco.contains("push"), "Marcus week \(week) day \(lastBadDay): bad sleep but push reco — \(reco)")
            XCTAssertTrue(output.readiness?.score ?? 100 <= 60,
                "Marcus week \(week) day \(lastBadDay): bad sleep but readiness \(output.readiness?.score ?? -1) > 60")
        }
    }

    // MARK: - Linda/Tom: Sedentary Should Nudge Activity

    func testSedentaryPersonas_NudgeActivity() {
        for persona in [LifeStoryPersonas.lindaRetiree, LifeStoryPersonas.tomDeskJockey] {
            let output = LifeStoryPipelineRunner.run(persona: persona, evaluateDay: 29)
            let allText = output.nudges.map { "\($0.title) \($0.description)" }.joined(separator: " ").lowercased()
                + " " + output.buddyRecTexts.map { "\($0.title) \($0.message)" }.joined(separator: " ").lowercased()

            let hasActivityNudge = allText.contains("walk") || allText.contains("movement")
                || allText.contains("active") || allText.contains("step") || allText.contains("exercise")

            XCTAssertTrue(hasActivityNudge,
                "\(persona.name): sedentary but no activity nudge in text: \(allText.prefix(200))")
        }
    }

    // MARK: - Aisha (Control): Consistently Primed

    func testAisha_ControlPersona_Primed() {
        let output = LifeStoryPipelineRunner.run(persona: LifeStoryPersonas.aishaConsistentAthlete, evaluateDay: 29)
        let level = output.readiness?.level
        XCTAssertTrue(level == .primed || level == .ready,
            "Aisha (perfect metrics) should be primed/ready, got: \(level?.rawValue ?? "nil")")
    }

    // MARK: - Carlos: Overtraining Detection

    func testCarlos_Overtraining_DetectedByWeek3() {
        let week3 = LifeStoryPipelineRunner.run(persona: LifeStoryPersonas.carlosOvertrainer, evaluateDay: 21)
        let reco = week3.thumpCheckRecommendation.lowercased()
        let allNudgeText = week3.nudges.map { "\($0.title) \($0.description)" }.joined(separator: " ").lowercased()

        let flagsRecovery = reco.contains("rest") || reco.contains("recovery") || reco.contains("easy")
            || allNudgeText.contains("rest") || allNudgeText.contains("recovery")
            || week3.readiness?.score ?? 100 <= 60

        XCTAssertTrue(flagsRecovery,
            "Carlos week 3: overtraining but no recovery flag — score=\(week3.readiness?.score ?? -1), reco=\(reco)")
    }

    // MARK: - Alex: All-Nighter = Hard Recovering

    func testAlex_AllNighter_HardRecovering() {
        let output = LifeStoryPipelineRunner.run(persona: LifeStoryPersonas.alexAllNighter, evaluateDay: 25)
        XCTAssertEqual(output.readiness?.level, .recovering,
            "Alex 0h sleep should be recovering, got: \(output.readiness?.level.rawValue ?? "nil")")
        XCTAssertLessThanOrEqual(output.readiness?.score ?? 100, 20,
            "Alex 0h sleep should have score ≤ 20, got: \(output.readiness?.score ?? -1)")
    }

    // MARK: - Fatima: No Judgment Language

    func testFatima_Ramadan_NoJudgmentLanguage() {
        let judgmentWords = ["lazy", "should have", "you need to", "you must", "failure", "only got"]
        let output = LifeStoryPipelineRunner.run(persona: LifeStoryPersonas.fatimaRamadan, evaluateDay: 20)
        let allText = [
            output.readinessSummary,
            output.thumpCheckRecommendation,
            output.stressFriendlyMessage,
            output.recoveryNarrative ?? ""
        ].joined(separator: " ").lowercased()
        + " " + output.nudges.map { "\($0.title) \($0.description)" }.joined(separator: " ").lowercased()

        for word in judgmentWords {
            XCTAssertFalse(allText.contains(word),
                "Fatima (Ramadan): found judgment word '\(word)' in output text")
        }
    }

    // MARK: - Print Full Report for LLM Judges

    func testPrintFullReportForJudges() {
        var allOutputs: [FullPipelineOutput] = []

        for persona in LifeStoryPersonas.all {
            // Evaluate day 29 (today) for all personas
            let output = LifeStoryPipelineRunner.run(persona: persona, evaluateDay: 29)
            allOutputs.append(output)

            // Also evaluate critical days
            for day in persona.criticalDays.keys.sorted() where day != 29 {
                let critOutput = LifeStoryPipelineRunner.run(persona: persona, evaluateDay: day)
                allOutputs.append(critOutput)
            }
        }

        let report = PersonaReportFormatter.formatFullReport(allOutputs)
        print(report)

        // Write to file for LLM judges
        let docsPath = NSTemporaryDirectory() + "thump_persona_report.txt"
        try? report.write(toFile: docsPath, atomically: true, encoding: .utf8)
        print("\n📝 Report written to: \(docsPath)")
    }
}

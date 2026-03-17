// SleepDeprivationTextTests.swift
// ThumpCoreTests
//
// Validates that ALL user-facing text produced by the engine pipeline
// graduates correctly across 6 sleep-deprivation levels while holding
// every other metric constant. Designed for LLM judge evaluation:
// prints every piece of text so a downstream judge can verify tone,
// accuracy, and appropriateness without needing to run the engines.

import XCTest
@testable import Thump

// MARK: - Sleep Deprivation Text Tests

final class SleepDeprivationTextTests: XCTestCase {

    // MARK: - Persona Definitions

    struct SleepPersona {
        let label: String
        let sleepHours: Double?

        func generateHistory() -> [HeartSnapshot] {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var rng = SeededSleepRNG(seed: stableHash(label))

            return (0..<14).compactMap { dayOffset in
                guard let date = calendar.date(byAdding: .day, value: -(13 - dayOffset), to: today) else {
                    return nil
                }
                return HeartSnapshot(
                    date: date,
                    restingHeartRate: rng.gaussian(mean: 62, sd: 2.0),
                    hrvSDNN: max(5, rng.gaussian(mean: 50, sd: 5.0)),
                    recoveryHR1m: max(5, rng.gaussian(mean: 25, sd: 2.0)),
                    recoveryHR2m: max(5, rng.gaussian(mean: 35, sd: 2.0)),
                    vo2Max: max(10, rng.gaussian(mean: 36, sd: 0.5)),
                    zoneMinutes: [30, 15, 10, 3, 0].map { max(0, rng.gaussian(mean: $0, sd: $0 * 0.15)) },
                    steps: max(0, rng.gaussian(mean: 5000, sd: 500)),
                    walkMinutes: max(0, rng.gaussian(mean: 30, sd: 3)),
                    workoutMinutes: max(0, rng.gaussian(mean: 10, sd: 2)),
                    sleepHours: sleepHours.map { max(0, rng.gaussian(mean: $0, sd: 0.3)) },
                    bodyMassKg: 75
                )
            }
        }

        private func stableHash(_ s: String) -> UInt64 {
            var h: UInt64 = 5381
            for byte in s.utf8 {
                h = h &* 33 &+ UInt64(byte)
            }
            return h
        }
    }

    private struct SeededSleepRNG {
        private var state: UInt64

        init(seed: UInt64) { state = seed }

        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 33) / Double(UInt64(1) << 31)
        }

        mutating func gaussian(mean: Double, sd: Double) -> Double {
            let u1 = max(next(), 1e-10)
            let u2 = next()
            let normal = (-2.0 * log(u1)).squareRoot() * cos(2.0 * .pi * u2)
            return mean + normal * sd
        }
    }

    static let personas: [(persona: SleepPersona, label: String)] = [
        (SleepPersona(label: "8.0h Optimal", sleepHours: 8.0), "8.0h Sleep (Optimal)"),
        (SleepPersona(label: "6.5h Mild", sleepHours: 6.5), "6.5h Sleep (Mild)"),
        (SleepPersona(label: "5.5h Moderate", sleepHours: 5.5), "5.5h Sleep (Moderate)"),
        (SleepPersona(label: "4.5h Severe", sleepHours: 4.5), "4.5h Sleep (Severe)"),
        (SleepPersona(label: "2.2h Extreme", sleepHours: 2.2), "2.2h Sleep (Extreme)"),
        (SleepPersona(label: "nil Missing", sleepHours: nil), "nil Sleep (Missing Data)"),
    ]

    // MARK: - Engine Result Container

    struct PersonaResults {
        let label: String
        let snapshot: HeartSnapshot
        let history: [HeartSnapshot]
        let readiness: ReadinessResult
        let stress: StressResult
        let nudges: [DailyNudge]
        let coaching: CoachingReport?
    }

    static func runEngines(for persona: SleepPersona, label: String) -> PersonaResults {
        let history = persona.generateHistory()
        let snapshot = history.last!

        let stressEngine = StressEngine()
        let stress = stressEngine.computeStress(snapshot: snapshot, recentHistory: history)
            ?? StressResult(score: 40, level: .balanced, description: "Unable to compute stress")

        let readinessEngine = ReadinessEngine()
        let readiness = readinessEngine.compute(
            snapshot: snapshot,
            stressScore: stress.score > 60 ? stress.score : nil,
            recentHistory: history
        )!

        let trendEngine = HeartTrendEngine()
        let assessment = trendEngine.assess(history: history, current: snapshot)

        let nudgeGen = NudgeGenerator()
        let nudges = nudgeGen.generateMultiple(
            confidence: assessment.confidence,
            anomaly: assessment.anomalyScore,
            regression: assessment.regressionFlag,
            stress: assessment.stressFlag,
            feedback: nil,
            current: snapshot,
            history: history,
            readiness: readiness
        )

        let coachingEngine = CoachingEngine()
        let coaching: CoachingReport? = history.count >= 3
            ? coachingEngine.generateReport(current: snapshot, history: history, streakDays: 3)
            : nil

        return PersonaResults(
            label: label,
            snapshot: snapshot,
            history: history,
            readiness: readiness,
            stress: stress,
            nudges: nudges,
            coaching: coaching
        )
    }

    // MARK: - Text Output Report (for LLM judge)

    func testPrintAllTextForJudge() {
        var report = "\n"
        report += String(repeating: "=", count: 70) + "\n"
        report += "  SLEEP DEPRIVATION TEXT REPORT — 6 PERSONAS\n"
        report += "  All metrics identical except sleepHours\n"
        report += "  Base: RHR 62, HRV 50, recoveryHR1m 25, VO2 36, steps 5000\n"
        report += String(repeating: "=", count: 70) + "\n\n"

        for (persona, label) in Self.personas {
            let r = Self.runEngines(for: persona, label: label)

            report += "=== PERSONA: \(label) ===\n"
            report += "Readiness: \(r.readiness.score)/100 (\(r.readiness.level))\n"
            report += "Summary: \"\(r.readiness.summary)\"\n"

            for pillar in r.readiness.pillars {
                report += "  \(pillar.type) Pillar: \"\(pillar.detail)\" (score: \(String(format: "%.0f", pillar.score)))\n"
            }

            report += "Stress: \(String(format: "%.0f", r.stress.score)) (\(r.stress.level)) — \"\(r.stress.description)\"\n"

            report += "Nudges (\(r.nudges.count)):\n"
            for (i, nudge) in r.nudges.enumerated() {
                report += "  \(i + 1). [\(nudge.category)] \"\(nudge.title)\" — \"\(nudge.description)\"\n"
            }

            if let coaching = r.coaching {
                report += "Coaching Hero: \"\(coaching.heroMessage)\"\n"
                for insight in coaching.insights {
                    report += "  Insight [\(insight.metric)]: \"\(insight.message)\"\n"
                    report += "    Projection: \"\(insight.projection)\"\n"
                }
            }

            report += "\n"
        }

        print(report)
    }

    // MARK: - Sleep Pillar Text Graduation

    func testSleepPillarTextGraduation() {
        let optimal = Self.runEngines(for: Self.personas[0].persona, label: "8.0h")
        let mild = Self.runEngines(for: Self.personas[1].persona, label: "6.5h")
        let moderate = Self.runEngines(for: Self.personas[2].persona, label: "5.5h")
        let severe = Self.runEngines(for: Self.personas[3].persona, label: "4.5h")
        let extreme = Self.runEngines(for: Self.personas[4].persona, label: "2.2h")

        let sleepDetail = { (r: PersonaResults) -> String in
            r.readiness.pillars.first { $0.type == .sleep }?.detail ?? ""
        }

        XCTAssert(sleepDetail(optimal).contains("sweet spot"),
                  "8.0h sleep should mention 'sweet spot', got: '\(sleepDetail(optimal))'")
        XCTAssert(sleepDetail(mild).contains("a bit under"),
                  "6.5h sleep should mention 'a bit under', got: '\(sleepDetail(mild))'")
        XCTAssert(sleepDetail(moderate).contains("well below"),
                  "5.5h sleep should mention 'well below', got: '\(sleepDetail(moderate))'")
        XCTAssert(sleepDetail(severe).contains("very low"),
                  "4.5h sleep should mention 'very low', got: '\(sleepDetail(severe))'")
        XCTAssert(sleepDetail(extreme).contains("very low"),
                  "2.2h sleep should mention 'very low', got: '\(sleepDetail(extreme))'")
    }

    // MARK: - Readiness Score Monotonic Decrease

    func testReadinessScoreDecreasesWithSleep() {
        let scores = Self.personas.prefix(5).map { p in
            Self.runEngines(for: p.persona, label: p.label).readiness.score
        }

        for i in 0..<(scores.count - 1) {
            XCTAssertGreaterThanOrEqual(scores[i], scores[i + 1],
                "Readiness should decrease: \(Self.personas[i].label)=\(scores[i]) >= \(Self.personas[i + 1].label)=\(scores[i + 1])")
        }
    }

    // MARK: - Extreme Sleep Deprivation Caps

    func testExtremeSleepCapsAt20() {
        let extreme = Self.runEngines(for: Self.personas[4].persona, label: "2.2h")
        XCTAssertLessThanOrEqual(extreme.readiness.score, 20,
            "2.2h sleep should cap readiness at 20, got: \(extreme.readiness.score)")
        XCTAssertEqual(extreme.readiness.level, .recovering,
            "2.2h sleep should be 'recovering', got: \(extreme.readiness.level)")
    }

    func testSevereSleepCapsAt50() {
        let severe = Self.runEngines(for: Self.personas[3].persona, label: "4.5h")
        XCTAssertLessThanOrEqual(severe.readiness.score, 50,
            "4.5h sleep should cap readiness at 50, got: \(severe.readiness.score)")
    }

    // MARK: - Summary Mentions Sleep When Critical

    func testSummaryMentionsSleepWhenCritical() {
        let severe = Self.runEngines(for: Self.personas[3].persona, label: "4.5h")
        let extreme = Self.runEngines(for: Self.personas[4].persona, label: "2.2h")

        XCTAssert(severe.readiness.summary.lowercased().contains("sleep"),
            "4.5h summary should mention sleep, got: '\(severe.readiness.summary)'")
        XCTAssert(extreme.readiness.summary.lowercased().contains("sleep"),
            "2.2h summary should mention sleep, got: '\(extreme.readiness.summary)'")
    }

    // MARK: - Nudge Content for Extreme Deprivation

    func testExtremeNudgeMentionsSleep() {
        let extreme = Self.runEngines(for: Self.personas[4].persona, label: "2.2h")

        let allNudgeText = extreme.nudges.map { "\($0.title) \($0.description)" }
            .joined(separator: " ").lowercased()

        let hasSleepContext = allNudgeText.contains("sleep")
            || allNudgeText.contains("rest")
            || allNudgeText.contains("bedtime")
            || allNudgeText.contains("bed")
            || allNudgeText.contains("recharge")

        XCTAssert(hasSleepContext,
            "2.2h nudges should mention sleep/rest/bedtime. Nudges: \(extreme.nudges.map(\.title))")
    }

    // MARK: - Missing Sleep Data

    func testMissingSleepHandledGracefully() {
        let missing = Self.runEngines(for: Self.personas[5].persona, label: "nil")

        XCTAssert(missing.readiness.score >= 0 && missing.readiness.score <= 100)
        XCTAssertFalse(missing.readiness.summary.isEmpty)
        XCTAssertFalse(missing.nudges.isEmpty)

        let sleepPillar = missing.readiness.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar, "Sleep pillar should be present with floor score")
        if let pillar = sleepPillar {
            XCTAssert(pillar.detail.lowercased().contains("no sleep data") || pillar.detail.lowercased().contains("limited info"),
                "Missing sleep pillar should mention missing data, got: '\(pillar.detail)'")
        }
    }

    // MARK: - Readiness Level Graduation

    func testReadinessLevelGraduation() {
        let optimal = Self.runEngines(for: Self.personas[0].persona, label: "8.0h")
        let extreme = Self.runEngines(for: Self.personas[4].persona, label: "2.2h")

        let highLevels: Set<ReadinessLevel> = [.primed, .ready]
        XCTAssert(highLevels.contains(optimal.readiness.level),
            "8.0h should be primed or ready, got: \(optimal.readiness.level)")
        XCTAssertEqual(extreme.readiness.level, .recovering,
            "2.2h should be recovering, got: \(extreme.readiness.level)")
    }

    // MARK: - Nudge Category Shifts

    func testNudgeCategoriesShiftTowardRest() {
        let optimal = Self.runEngines(for: Self.personas[0].persona, label: "8.0h")
        let extreme = Self.runEngines(for: Self.personas[4].persona, label: "2.2h")

        let restCategories: Set<NudgeCategory> = [.rest, .breathe, .celebrate]

        let optimalRestCount = optimal.nudges.filter { restCategories.contains($0.category) }.count
        let extremeRestCount = extreme.nudges.filter { restCategories.contains($0.category) }.count

        XCTAssertGreaterThanOrEqual(extremeRestCount, optimalRestCount,
            "Extreme sleep should have >= rest/breathe nudges (\(extremeRestCount)) than optimal (\(optimalRestCount))")
    }
}

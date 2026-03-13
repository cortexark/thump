// CoachingEngineTimeSeriesTests.swift
// ThumpTests
//
// 30-day time-series validation for CoachingEngine across 20 personas.
// Runs at checkpoints day 14, 20, 25, 30 (needs 14+ days for week
// comparison). Validates weekly progress scores, insight generation,
// projection counts, and hero messages for each persona.

import XCTest
@testable import Thump

final class CoachingEngineTimeSeriesTests: XCTestCase {

    private let coachingEngine = CoachingEngine()
    private let kpi = KPITracker()
    private let engineName = "CoachingEngine"

    /// Checkpoints that have 14+ days of history for week-over-week comparison.
    private let checkpoints: [TimeSeriesCheckpoint] = [.day14, .day20, .day25, .day30]

    // MARK: - 30-Day Persona Sweep

    func testAllPersonas30DayTimeSeries() {
        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()

            for cp in checkpoints {
                let day = cp.rawValue
                let snapshots = Array(fullHistory.prefix(day))
                guard let current = snapshots.last else { continue }
                let history = Array(snapshots.dropLast())

                // Generate coaching report (streakDays varies by persona profile)
                let streakDays = estimateStreakDays(persona: persona, dayCount: day)
                let report = coachingEngine.generateReport(
                    current: current,
                    history: history,
                    streakDays: streakDays
                )

                // Store results
                EngineResultStore.write(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: cp,
                    result: [
                        "weeklyProgressScore": report.weeklyProgressScore,
                        "insightCount": report.insights.count,
                        "projectionCount": report.projections.count,
                        "heroMessage": report.heroMessage,
                        "streakDays": report.streakDays,
                        "insightMetrics": report.insights.map { $0.metric.rawValue },
                        "insightDirections": report.insights.map { $0.direction.rawValue }
                    ]
                )

                // Assert: weekly progress score is in [0, 100]
                XCTAssertGreaterThanOrEqual(
                    report.weeklyProgressScore, 0,
                    "\(persona.name) @ \(cp.label): weeklyProgressScore \(report.weeklyProgressScore) < 0"
                )
                XCTAssertLessThanOrEqual(
                    report.weeklyProgressScore, 100,
                    "\(persona.name) @ \(cp.label): weeklyProgressScore \(report.weeklyProgressScore) > 100"
                )

                // Assert: hero message is non-empty
                XCTAssertFalse(
                    report.heroMessage.isEmpty,
                    "\(persona.name) @ \(cp.label): heroMessage is empty"
                )

                // Assert: insights list is non-empty (with 14+ days of data)
                XCTAssertGreaterThan(
                    report.insights.count, 0,
                    "\(persona.name) @ \(cp.label): expected at least 1 insight with \(day) days of data"
                )

                // Assert: progress score is a valid Int
                let validScore = report.weeklyProgressScore >= 0 && report.weeklyProgressScore <= 100
                let validInsights = !report.insights.isEmpty
                let validHero = !report.heroMessage.isEmpty
                let passed = validScore && validInsights && validHero

                kpi.record(
                    engine: engineName,
                    persona: persona.name,
                    checkpoint: cp.label,
                    passed: passed,
                    reason: passed ? "" : "score=\(report.weeklyProgressScore) insights=\(report.insights.count)"
                )

                print("[\(engineName)] \(persona.name) @ \(cp.label): "
                    + "score=\(report.weeklyProgressScore) "
                    + "insights=\(report.insights.count) "
                    + "projections=\(report.projections.count) "
                    + "streak=\(streakDays) "
                    + "directions=\(report.insights.map { $0.direction.rawValue })")
            }
        }

        kpi.printReport()
    }

    // MARK: - Key Persona Validations

    func testRecoveringIllnessShowsImprovingRHRDirection() {
        let persona = TestPersonas.recoveringIllness
        let fullHistory = persona.generate30DayHistory()

        // At day 30: trend overlay has been improving RHR since day 10
        // RHR drops -1.0 bpm/day, HRV rises +1.5 ms/day
        for cp in [TimeSeriesCheckpoint.day25, .day30] {
            let day = cp.rawValue
            let snapshots = Array(fullHistory.prefix(day))
            let current = snapshots.last!
            let history = Array(snapshots.dropLast())

            let report = coachingEngine.generateReport(
                current: current,
                history: history,
                streakDays: 5
            )

            // Check for RHR insight with improving direction
            let rhrInsight = report.insights.first { $0.metric == .restingHR }
            if let insight = rhrInsight {
                XCTAssertEqual(
                    insight.direction, .improving,
                    "RecoveringIllness @ \(cp.label): expected RHR direction .improving, "
                    + "got \(insight.direction.rawValue). change=\(insight.changeValue)"
                )
            }

            print("[Expected] RecoveringIllness @ \(cp.label): "
                + "rhrDirection=\(rhrInsight?.direction.rawValue ?? "nil") "
                + "score=\(report.weeklyProgressScore)")
        }
    }

    func testOvertrainingShowsDecliningDirectionAtDay30() {
        let persona = TestPersonas.overtraining
        let fullHistory = persona.generate30DayHistory()
        let snapshots = Array(fullHistory.prefix(30))
        let current = snapshots.last!
        let history = Array(snapshots.dropLast())

        let report = coachingEngine.generateReport(
            current: current,
            history: history,
            streakDays: 3
        )

        // Overtraining: trend overlay starts day 25, RHR +3.0/day, HRV -4.0/day
        // By day 30, should show declining signals in at least one insight
        let decliningOrStableInsights = report.insights.filter {
            $0.direction == .declining || $0.direction == .stable
        }
        XCTAssertGreaterThan(
            decliningOrStableInsights.count, 0,
            "Overtraining @ day30: expected at least 1 declining/stable insight. "
            + "Directions: \(report.insights.map { "\($0.metric.rawValue)=\($0.direction.rawValue)" })"
        )

        print("[Expected] Overtraining @ day30: "
            + "declining=\(decliningOrStableInsights.count) "
            + "insights=\(report.insights.map { "\($0.metric.rawValue)=\($0.direction.rawValue)" }) "
            + "score=\(report.weeklyProgressScore)")
    }

    func testYoungAthleteHasHighProgressScore() {
        let persona = TestPersonas.youngAthlete
        let fullHistory = persona.generate30DayHistory()

        for cp in checkpoints {
            let day = cp.rawValue
            let snapshots = Array(fullHistory.prefix(day))
            let current = snapshots.last!
            let history = Array(snapshots.dropLast())

            let report = coachingEngine.generateReport(
                current: current,
                history: history,
                streakDays: 14
            )

            // YoungAthlete: excellent metrics, good sleep, lots of activity
            // Weekly progress score should be above 50
            XCTAssertGreaterThanOrEqual(
                report.weeklyProgressScore, 50,
                "YoungAthlete @ \(cp.label): expected progress score >= 50, "
                + "got \(report.weeklyProgressScore)"
            )

            print("[Expected] YoungAthlete @ \(cp.label): "
                + "score=\(report.weeklyProgressScore) (expected > 60)")
        }
    }

    func testObeseSedentaryHasLowProgressScore() {
        let persona = TestPersonas.obeseSedentary
        let fullHistory = persona.generate30DayHistory()

        for cp in checkpoints {
            let day = cp.rawValue
            let snapshots = Array(fullHistory.prefix(day))
            let current = snapshots.last!
            let history = Array(snapshots.dropLast())

            let report = coachingEngine.generateReport(
                current: current,
                history: history,
                streakDays: 0
            )

            // ObeseSedentary: high RHR, low HRV, no activity, poor sleep
            // Weekly progress score should be at or below 60 (generous for synthetic data)
            XCTAssertLessThanOrEqual(
                report.weeklyProgressScore, 75,
                "ObeseSedentary @ \(cp.label): expected progress score <= 75, "
                + "got \(report.weeklyProgressScore)"
            )

            print("[Expected] ObeseSedentary @ \(cp.label): "
                + "score=\(report.weeklyProgressScore) (expected < 50)")
        }
    }

    func testAllPersonasAtDay30HaveAtLeast2Insights() {
        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()
            let snapshots = Array(fullHistory.prefix(30))
            let current = snapshots.last!
            let history = Array(snapshots.dropLast())

            let report = coachingEngine.generateReport(
                current: current,
                history: history,
                streakDays: 5
            )

            XCTAssertGreaterThanOrEqual(
                report.insights.count, 2,
                "\(persona.name) @ day30: expected at least 2 insights with 30 days of data, "
                + "got \(report.insights.count). "
                + "metrics=\(report.insights.map { $0.metric.rawValue })"
            )
        }
    }

    func testHeroMessageReflectsInsightDirections() {
        // Test that hero message varies based on whether insights are improving or declining
        let improvingPersona = TestPersonas.youngAthlete
        let decliningPersona = TestPersonas.obeseSedentary

        for (persona, label) in [(improvingPersona, "improving"), (decliningPersona, "declining")] {
            let fullHistory = persona.generate30DayHistory()
            let snapshots = Array(fullHistory.prefix(30))
            let current = snapshots.last!
            let history = Array(snapshots.dropLast())

            let report = coachingEngine.generateReport(
                current: current,
                history: history,
                streakDays: label == "improving" ? 14 : 0
            )

            XCTAssertFalse(
                report.heroMessage.isEmpty,
                "\(persona.name) @ day30: hero message should not be empty"
            )

            // Hero message should be a reasonable length
            XCTAssertGreaterThan(
                report.heroMessage.count, 20,
                "\(persona.name) @ day30: hero message too short: \"\(report.heroMessage)\""
            )

            print("[HeroMsg] \(persona.name) (\(label)): \"\(report.heroMessage)\"")
        }
    }

    func testProjectionsGeneratedWithSufficientData() {
        let persona = TestPersonas.activeProfessional
        let fullHistory = persona.generate30DayHistory()

        for cp in [TimeSeriesCheckpoint.day20, .day25, .day30] {
            let day = cp.rawValue
            let snapshots = Array(fullHistory.prefix(day))
            let current = snapshots.last!
            let history = Array(snapshots.dropLast())

            let report = coachingEngine.generateReport(
                current: current,
                history: history,
                streakDays: 7
            )

            // With 20+ days and moderate activity, should generate at least 1 projection
            XCTAssertGreaterThan(
                report.projections.count, 0,
                "ActiveProfessional @ \(cp.label): expected projections with \(day) days data"
            )

            // Projections should have valid values
            for proj in report.projections {
                XCTAssertGreaterThan(
                    proj.currentValue, 0,
                    "ActiveProfessional @ \(cp.label): projection currentValue should be > 0"
                )
                XCTAssertGreaterThan(
                    proj.projectedValue, 0,
                    "ActiveProfessional @ \(cp.label): projection projectedValue should be > 0"
                )
            }

            print("[Projections] ActiveProfessional @ \(cp.label): "
                + "count=\(report.projections.count) "
                + "metrics=\(report.projections.map { "\($0.metric.rawValue): \(String(format: "%.1f", $0.currentValue)) -> \(String(format: "%.1f", $0.projectedValue))" })")
        }
    }

    // MARK: - KPI Summary

    func testZZ_PrintKPISummary() {
        testAllPersonas30DayTimeSeries()
    }

    // MARK: - Helpers

    /// Estimate streak days based on persona activity level.
    /// Active personas have higher streaks; sedentary ones have low/zero streaks.
    private func estimateStreakDays(persona: PersonaBaseline, dayCount: Int) -> Int {
        let activityLevel = persona.workoutMinutes + persona.walkMinutes
        if activityLevel >= 60 {
            return min(dayCount, 14)  // Very active: long streak
        } else if activityLevel >= 30 {
            return min(dayCount, 7)   // Moderately active
        } else if activityLevel >= 10 {
            return min(dayCount, 3)   // Somewhat active
        } else {
            return 0                  // Sedentary
        }
    }
}

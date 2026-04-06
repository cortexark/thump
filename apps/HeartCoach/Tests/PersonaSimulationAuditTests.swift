import Foundation
import XCTest
@testable import Thump

final class PersonaSimulationAuditTests: XCTestCase {
    private let trendEngine = ConfigService.makeDefaultEngine()
    private let stressEngine = StressEngine()
    private let readinessEngine = ReadinessEngine()
    private let coachingEngine = CoachingEngine()
    private let correlationEngine = CorrelationEngine()
    private let zoneEngine = HeartRateZoneEngine()
    private let scheduler = SmartNudgeScheduler()

    private let personas: [MockData.Persona] = [
        .athleticMale,
        .normalFemale,
        .couchPotatoMale,
        .overweightFemale,
        .seniorActive,
    ]

    private let bannedTerms = [
        "lorem ipsum",
        "sdnn",
        "z-score",
        "p-value",
        "regression analysis",
        "crushing it",
        "killing it",
    ]

    private func fixedReferenceDate() -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "America/Los_Angeles")
        components.year = 2026
        components.month = 3
        components.day = 12
        components.hour = 21
        components.minute = 0
        return components.date ?? Date()
    }

    private func stressResult(
        current: HeartSnapshot,
        prior: [HeartSnapshot]
    ) -> StressResult? {
        guard let currentHRV = current.hrvSDNN else { return nil }

        let baselineHRV = stressEngine.computeBaseline(snapshots: prior) ?? currentHRV
        let recentHRVs = prior.compactMap(\.hrvSDNN)
        let baselineSD = stressEngine.computeBaselineSD(
            hrvValues: recentHRVs,
            mean: baselineHRV
        )
        let baselineRHR = stressEngine.computeRHRBaseline(snapshots: prior)

        return stressEngine.computeStress(
            currentHRV: currentHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineSD,
            currentRHR: current.restingHeartRate,
            baselineRHR: baselineRHR,
            recentHRVs: recentHRVs
        )
    }

    private func assertReadable(
        _ text: String,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(trimmed.isEmpty, "\(context): text should not be empty", file: file, line: line)
        XCTAssertGreaterThan(trimmed.count, 6, "\(context): text is too short -> \(trimmed)", file: file, line: line)

        let lower = trimmed.lowercased()
        for term in bannedTerms {
            XCTAssertFalse(
                lower.contains(term),
                "\(context): found banned term '\(term)' in '\(trimmed)'",
                file: file,
                line: line
            )
        }
    }

    private func actionTextFragments(_ action: SmartNudgeAction) -> [String] {
        switch action {
        case .journalPrompt(let prompt):
            return [prompt.question, prompt.context]
        case .breatheOnWatch(let nudge),
             .bedtimeWindDown(let nudge),
             .activitySuggestion(let nudge),
             .restSuggestion(let nudge):
            return [nudge.title, nudge.description]
        case .morningCheckIn(let message):
            return [message]
        case .standardNudge:
            return []
        }
    }

    func testFiveProfilesStayCoherentAcrossEveryHourAndWeeklyCheckpoints() {
        let referenceDate = fixedReferenceDate()

        for persona in personas {
            let history = MockData.personaHistory(
                persona,
                days: 30,
                includeStressEvent: persona == .couchPotatoMale || persona == .overweightFemale
            )

            XCTAssertEqual(history.count, 30, "\(persona.rawValue): expected 30 days of history")

            for dayIndex in (history.count - 7)..<history.count {
                let prefix = Array(history.prefix(dayIndex + 1))
                let current = prefix.last ?? history[dayIndex]
                let prior = Array(prefix.dropLast())
                let context = "\(persona.rawValue) dayIndex \(dayIndex)"

                let assessment = trendEngine.assess(
                    history: prior,
                    current: current,
                    feedback: nil
                )
                let stress = stressResult(current: current, prior: prior)
                let readiness = readinessEngine.compute(
                    snapshot: current,
                    stressScore: stress?.score,
                    recentHistory: prior
                )
                let coaching = coachingEngine.generateReport(
                    current: current,
                    history: prefix,
                    streakDays: 4,
                    readiness: readiness
                )
                let zone = zoneEngine.analyzeZoneDistribution(zoneMinutes: current.zoneMinutes)
                let trendPoints = stressEngine.stressTrend(snapshots: prefix, range: .week)
                let trendDirection = stressEngine.trendDirection(points: trendPoints)
                let sleepPatterns = scheduler.learnSleepPatterns(from: prefix)
                let hourly = stressEngine.hourlyStressForDay(snapshots: prefix, date: current.date)
                XCTAssertNotNil(readiness, "\(context): expected readiness output")
                guard let readiness else { continue }

                assertReadable(assessment.explanation, context: "\(context) assessment explanation")
                assertReadable(assessment.dailyNudge.title, context: "\(context) primary nudge title")
                assertReadable(assessment.dailyNudge.description, context: "\(context) primary nudge description")
                XCTAssertFalse(assessment.dailyNudges.isEmpty, "\(context): expected at least one daily nudge")
                assessment.dailyNudges.forEach { nudge in
                    assertReadable(nudge.title, context: "\(context) nudge title \(nudge.category.rawValue)")
                    assertReadable(nudge.description, context: "\(context) nudge description \(nudge.category.rawValue)")
                }

                assertReadable(readiness.summary, context: "\(context) readiness summary")
                readiness.pillars.forEach { pillar in
                    assertReadable(pillar.detail, context: "\(context) pillar \(pillar.type.rawValue)")
                }

                assertReadable(coaching.heroMessage, context: "\(context) coaching hero")
                XCTAssertFalse(coaching.insights.isEmpty, "\(context): expected weekly coaching insights")
                coaching.insights.forEach { insight in
                    assertReadable(insight.message, context: "\(context) coaching message \(insight.metric.rawValue)")
                    assertReadable(insight.projection, context: "\(context) coaching projection \(insight.metric.rawValue)")
                }

                assertReadable(zone.coachingMessage, context: "\(context) zone coaching")

                if prefix.count >= 14 {
                    let correlations = correlationEngine.analyze(history: prefix)
                    XCTAssertFalse(correlations.isEmpty, "\(context): expected at least one correlation")
                    correlations.prefix(3).forEach { correlation in
                        assertReadable(
                            correlation.interpretation,
                            context: "\(context) correlation \(correlation.factorName)"
                        )
                    }
                }

                XCTAssertEqual(hourly.count, 24, "\(context): expected 24 hourly stress points")
                XCTAssertEqual(hourly.map { $0.hour }, Array(0..<24), "\(context): expected hour-by-hour coverage")

                for hour in 0..<24 {
                    let actions = scheduler.recommendActions(
                        stressPoints: trendPoints,
                        trendDirection: trendDirection,
                        todaySnapshot: current,
                        patterns: sleepPatterns,
                        currentHour: hour,
                        readinessGate: readiness.level
                    )

                    XCTAssertFalse(actions.isEmpty, "\(context) hour \(hour): expected at least one action")

                    for action in actions {
                        let fragments = actionTextFragments(action)
                        for fragment in fragments {
                            assertReadable(fragment, context: "\(context) hour \(hour) action")
                        }

                        if case .morningCheckIn = action {
                            XCTAssertLessThan(hour, 12, "\(context) hour \(hour): morning check-in should only appear before noon")
                        }
                    }
                }
            }
        }
    }
}

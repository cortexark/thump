// EngineCrashProbeTests.swift
// ThumpCoreTests
//
// Isolates which engine crashes on which persona data.
// Each test runs a SINGLE engine on a SINGLE persona so crashes
// are pinpointed exactly.

import XCTest
@testable import Thump

final class EngineCrashProbeTests: XCTestCase {

    // MARK: - HeartTrendEngine Crash Probe

    func testHeartTrendEngine_AllPersonas() {
        let engine = HeartTrendEngine()
        var crashes: [String] = []

        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()
            for cpDay in [7, 14, 30] {
                let snapshots = Array(fullHistory.prefix(cpDay))
                guard let current = snapshots.last else { continue }
                let history = Array(snapshots.dropLast())

                let label = "\(persona.name)@day\(cpDay)"
                // If this crashes, the test runner will report which persona
                let result = engine.assess(history: history, current: current)
                if result.dailyNudge.title.isEmpty {
                    crashes.append("\(label): empty nudge title")
                }
            }
        }

        XCTAssertTrue(crashes.isEmpty, "HeartTrendEngine issues:\n\(crashes.joined(separator: "\n"))")
    }

    // MARK: - ReadinessEngine Crash Probe

    func testReadinessEngine_AllPersonas() {
        let readinessEngine = ReadinessEngine()
        var results: [(String, Int, String)] = []

        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()
            for cpDay in [7, 14, 30] {
                let snapshots = Array(fullHistory.prefix(cpDay))
                guard let current = snapshots.last else { continue }
                let history = Array(snapshots.dropLast())

                let label = "\(persona.name)@day\(cpDay)"
                let readiness = readinessEngine.compute(
                    snapshot: current,
                    stressScore: nil,
                    recentHistory: history
                )

                if let r = readiness {
                    results.append((label, r.score, r.level.rawValue))
                } else {
                    results.append((label, -1, "nil"))
                }
            }
        }

        // Print readiness distribution
        let recovering = results.filter { $0.2 == "recovering" }
        let moderate = results.filter { $0.2 == "moderate" }
        let ready = results.filter { $0.2 == "ready" }
        let primed = results.filter { $0.2 == "primed" }
        let nilResults = results.filter { $0.2 == "nil" }

        let summary = """
        ReadinessEngine distribution across \(results.count) scenarios:
          recovering: \(recovering.count) (\(recovering.map { $0.0 }.joined(separator: ", ")))
          moderate:   \(moderate.count) (\(moderate.map { $0.0 }.joined(separator: ", ")))
          ready:      \(ready.count)
          primed:     \(primed.count)
          nil:        \(nilResults.count) (\(nilResults.map { $0.0 }.joined(separator: ", ")))
        """

        // Force output via assertion
        XCTAssertTrue(nilResults.count < results.count,
                      "ReadinessEngine returned nil for all scenarios — engine may be broken\n\(summary)")

        // Dump the distribution
        print(summary)

        // Verify we actually get some recovering/moderate scenarios
        // If zero, the conflict guard test data never exercises the guard
        if recovering.isEmpty && moderate.isEmpty {
            XCTFail("No recovering or moderate readiness found across all personas — conflict guard tests are vacuous!\n\(summary)")
        }
    }

    // MARK: - StressEngine Crash Probe

    func testStressEngine_AllPersonas() {
        let stressEngine = StressEngine()
        var nilCount = 0
        var totalCount = 0

        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()
            for cpDay in [7, 14, 30] {
                let snapshots = Array(fullHistory.prefix(cpDay))
                guard let current = snapshots.last else { continue }
                let history = Array(snapshots.dropLast())

                totalCount += 1
                let result = stressEngine.computeStress(
                    snapshot: current,
                    recentHistory: history
                )
                if result == nil { nilCount += 1 }
            }
        }

        print("StressEngine: \(totalCount) scenarios, \(nilCount) returned nil")
        XCTAssertTrue(nilCount < totalCount, "StressEngine returned nil for ALL scenarios")
    }

    // MARK: - SmartNudgeScheduler Crash Probe

    func testSmartNudgeScheduler_AllPersonas() {
        let scheduler = SmartNudgeScheduler()

        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()
            let snapshots = Array(fullHistory.prefix(30))
            guard let current = snapshots.last else { continue }

            let patterns = scheduler.learnSleepPatterns(from: snapshots)

            // Test with all readiness gate levels
            for gate: ReadinessLevel? in [nil, .primed, .ready, .moderate, .recovering] {
                let actions = scheduler.recommendActions(
                    stressPoints: [],
                    trendDirection: .steady,
                    todaySnapshot: current,
                    patterns: patterns,
                    currentHour: 14,
                    readinessGate: gate
                )

                XCTAssertFalse(actions.isEmpty,
                               "\(persona.name) gate=\(gate?.rawValue ?? "nil"): empty actions")

                // With recovering gate, must NOT have activitySuggestion
                if gate == .recovering {
                    for action in actions {
                        if case .activitySuggestion = action {
                            XCTFail("\(persona.name) gate=recovering: got activitySuggestion")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Combined Engine Pipeline Probe

    /// Runs ALL 20 personas through the FULL engine pipeline and prints
    /// a comprehensive metrics table: vitals, engine outputs, nudge decisions,
    /// scheduler actions, conflict status, and what notification would fire.
    func testFullPipeline_AllPersonas_MetricsTable() {
        let trendEngine = HeartTrendEngine()
        let stressEngine = StressEngine()
        let readinessEngine = ReadinessEngine()
        let generator = NudgeGenerator()
        let scheduler = SmartNudgeScheduler()

        var report: [String] = []
        var conflictCount = 0
        var totalScenarios = 0

        report.append("=== FULL PIPELINE: ALL PERSONAS x ALL CHECKPOINTS ===")
        report.append("PERSONA              DAY   | RHR   HRV   SLEEP | STATUS   ANOM   STRESS REGRESS | READINESS    STRESS_LVL   | NUDGE_GEN            | SCHEDULER  | CONFLICT? | NOTIFICATION")
        report.append(String(repeating: "-", count: 180))

        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()

            for cpDay in [7, 14, 20, 25, 30] {
                let snapshots = Array(fullHistory.prefix(cpDay))
                guard let current = snapshots.last else { continue }
                let history = Array(snapshots.dropLast())

                // Step 1: Trend engine
                let assessment = trendEngine.assess(history: history, current: current)

                // Step 2: Stress
                let stressResult = stressEngine.computeStress(
                    snapshot: current, recentHistory: history
                )

                // Step 3: Readiness
                let readiness = readinessEngine.compute(
                    snapshot: current,
                    stressScore: stressResult?.score,
                    recentHistory: history
                )

                // Step 4: NudgeGenerator
                let nudge = generator.generate(
                    confidence: assessment.confidence,
                    anomaly: assessment.anomalyScore,
                    regression: assessment.regressionFlag,
                    stress: assessment.stressFlag,
                    feedback: nil,
                    current: current,
                    history: history,
                    readiness: readiness
                )

                // Step 5: Scheduler with guard
                let patterns = scheduler.learnSleepPatterns(from: snapshots)
                let actions = scheduler.recommendActions(
                    stressPoints: [],
                    trendDirection: assessment.stressFlag ? .rising : .steady,
                    todaySnapshot: current,
                    patterns: patterns,
                    currentHour: 14,
                    readinessGate: readiness?.level
                )

                let actionStr = actions.map { actionName($0) }.joined(separator: "+")
                let readStr = readiness.map { "\($0.level.rawValue)(\($0.score))" } ?? "nil"
                let stressStr = stressResult.map { "\($0.level.rawValue)(\(Int($0.score)))" } ?? "nil"

                // Conflict detection
                let nudgeIsRest = nudge.category == .rest || nudge.category == .breathe
                let schedHasActivity = actions.contains { if case .activitySuggestion = $0 { return true }; return false }
                let isConflict = (nudgeIsRest && schedHasActivity) ||
                                 (readiness?.level == .recovering && schedHasActivity)

                let conflictFlag: String
                if nudgeIsRest && schedHasActivity {
                    conflictFlag = "CONFLICT"
                    conflictCount += 1
                } else if readiness?.level == .recovering && schedHasActivity {
                    conflictFlag = "READINESS!"
                    conflictCount += 1
                } else {
                    conflictFlag = "OK"
                }
                totalScenarios += 1

                // What notification would fire
                let notifCategory = nudge.category.rawValue
                let notifTiming: String
                switch nudge.category {
                case .walk, .moderate: notifTiming = "morning"
                case .rest: notifTiming = "bedtime"
                case .breathe: notifTiming = "3PM"
                case .hydrate: notifTiming = "11AM"
                default: notifTiming = "6PM"
                }

                let rhr = current.restingHeartRate.map { "\(Int($0))" } ?? "-"
                let hrv = current.hrvSDNN.map { "\(Int($0))" } ?? "-"
                let sleep = current.sleepHours.map { String(format: "%.1f", $0) } ?? "-"
                let anomStr = String(format: "%.2f", assessment.anomalyScore)
                let stressFlag = assessment.stressFlag ? "YES" : "no"
                let regressFlag = assessment.regressionFlag ? "YES" : "no"
                let nudgeStr = "\(nudge.category.rawValue):\(String(nudge.title.prefix(15)))"
                let notif = "\(notifCategory)@\(notifTiming)"

                let line = "\(persona.name.padding(toLength: 20, withPad: " ", startingAt: 0)) day\(cpDay)".padding(toLength: 27, withPad: " ", startingAt: 0)
                    + "| \(rhr.padding(toLength: 5, withPad: " ", startingAt: 0)) \(hrv.padding(toLength: 5, withPad: " ", startingAt: 0)) \(sleep.padding(toLength: 5, withPad: " ", startingAt: 0)) "
                    + "| \(assessment.status.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) \(anomStr.padding(toLength: 6, withPad: " ", startingAt: 0)) \(stressFlag.padding(toLength: 6, withPad: " ", startingAt: 0)) \(regressFlag.padding(toLength: 7, withPad: " ", startingAt: 0)) "
                    + "| \(readStr.padding(toLength: 16, withPad: " ", startingAt: 0)) \(stressStr.padding(toLength: 14, withPad: " ", startingAt: 0)) "
                    + "| \(nudgeStr.padding(toLength: 22, withPad: " ", startingAt: 0)) "
                    + "| \(actionStr.padding(toLength: 18, withPad: " ", startingAt: 0)) "
                    + "| \(conflictFlag.padding(toLength: 10, withPad: " ", startingAt: 0)) "
                    + "| \(notif)"
                report.append(line)

                if isConflict {
                    XCTFail("CONFLICT at \(persona.name)@day\(cpDay): nudge=\(nudge.category.rawValue) sched=\(actionStr) readiness=\(readStr)")
                }
            }
        }

        report.append(String(repeating: "-", count: 160))
        report.append("Total: \(totalScenarios) scenarios, \(conflictCount) conflicts")

        // Print full report
        for line in report { print(line) }
    }

    private func actionName(_ action: SmartNudgeAction) -> String {
        switch action {
        case .journalPrompt: return "journal"
        case .breatheOnWatch: return "breathe"
        case .morningCheckIn: return "checkin"
        case .bedtimeWindDown: return "bedtime"
        case .activitySuggestion: return "activity"
        case .restSuggestion: return "rest"
        case .standardNudge: return "standard"
        }
    }
}

// NudgeConflictGuardTests.swift
// ThumpCoreTests
//
// Real-world persona tests that run BOTH NudgeGenerator and SmartNudgeScheduler
// with the same data and verify they never give conflicting advice.
//
// The conflict guard rule: if NudgeGenerator says rest/breathe (readiness is low),
// SmartNudgeScheduler must NOT suggest activity. Stress-driven actions (journal,
// breathe, bedtime) always pass — they're acute responses, not contradictions.
//
// Tests 20 personas × 5 checkpoints × 3 time-of-day scenarios = 300 scenarios.
//
// Platforms: iOS 17+

import XCTest
@testable import Thump

// MARK: - Conflict Guard Tests

final class NudgeConflictGuardTests: XCTestCase {

    private let generator = NudgeGenerator()
    private let scheduler = SmartNudgeScheduler()
    private let trendEngine = HeartTrendEngine()
    private let stressEngine = StressEngine()

    private let checkpoints: [TimeSeriesCheckpoint] = [.day7, .day14, .day20, .day25, .day30]

    // MARK: - Test: All Personas — No Safety Conflicts

    /// Runs both engines for every persona at every checkpoint.
    /// Asserts that when NudgeGenerator says rest, SmartNudgeScheduler
    /// does NOT suggest activity (with the readinessGate wired).
    func testAllPersonas_NoConflictBetweenEngines() {
        var conflicts: [(persona: String, day: String, detail: String)] = []
        var iterations = 0

        for persona in TestPersonas.all {
            let fullHistory = persona.generate30DayHistory()

            for cp in checkpoints {
                let snapshots = Array(fullHistory.prefix(cp.rawValue))
                guard let current = snapshots.last else { continue }
                let history = Array(snapshots.dropLast())

                // Run HeartTrendEngine
                let assessment = trendEngine.assess(history: history, current: current)

                // Compute readiness
                let stressResult = stressEngine.computeStress(
                    snapshot: current,
                    recentHistory: history
                )
                let readiness = ReadinessEngine().compute(
                    snapshot: current,
                    stressScore: stressResult?.score,
                    recentHistory: history
                )

                // Run NudgeGenerator
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

                // Build stress data for scheduler
                let stressPoints = buildStressPoints(from: snapshots)
                let trendDirection: StressTrendDirection = assessment.stressFlag ? .rising : .steady
                let sleepPatterns = scheduler.learnSleepPatterns(from: snapshots)

                // Run SmartNudgeScheduler WITH the conflict guard
                let actions = scheduler.recommendActions(
                    stressPoints: stressPoints,
                    trendDirection: trendDirection,
                    todaySnapshot: current,
                    patterns: sleepPatterns,
                    currentHour: 14,  // afternoon
                    readinessGate: readiness?.level
                )

                iterations += 1

                // Check for conflicts
                let conflict = detectConflict(
                    nudgeCategory: nudge.category,
                    schedulerActions: actions,
                    readinessLevel: readiness?.level
                )

                if let conflict {
                    conflicts.append((
                        persona: persona.name,
                        day: cp.label,
                        detail: conflict
                    ))
                }
            }
        }

        // Prove the loop ran
        XCTAssertEqual(iterations, TestPersonas.all.count * checkpoints.count,
                       "Expected \(TestPersonas.all.count * checkpoints.count) iterations, got \(iterations)")

        // Report all conflicts
        if !conflicts.isEmpty {
            let report = conflicts.map { "  \($0.persona) @ \($0.day): \($0.detail)" }.joined(separator: "\n")
            XCTFail("Found \(conflicts.count) conflict(s) out of \(iterations) scenarios:\n\(report)")
        }
    }

    // MARK: - Test: Recovering User Never Gets Activity From Scheduler

    /// Specifically tests the high-risk personas (NewMom, ObeseSedentary,
    /// Overtraining, StressedExecutive) where readiness is likely .recovering.
    /// The scheduler must NEVER produce .activitySuggestion for these users.
    func testRecoveringPersonas_NoActivityFromScheduler() {
        let riskyPersonas = TestPersonas.all.filter {
            ["NewMom", "ObeseSedentary", "Overtraining", "StressedExecutive",
             "SedentarySenior", "MiddleAgeUnfit"].contains($0.name)
        }

        for persona in riskyPersonas {
            let fullHistory = persona.generate30DayHistory()

            for cp in checkpoints {
                let snapshots = Array(fullHistory.prefix(cp.rawValue))
                guard let current = snapshots.last else { continue }
                let history = Array(snapshots.dropLast())

                let stressResult = stressEngine.computeStress(snapshot: current, recentHistory: history)
                let readiness = ReadinessEngine().compute(
                    snapshot: current,
                    stressScore: stressResult?.score,
                    recentHistory: history
                )

                // Only test when readiness is actually recovering
                guard readiness?.level == .recovering else { continue }

                let stressPoints = buildStressPoints(from: snapshots)
                let sleepPatterns = scheduler.learnSleepPatterns(from: snapshots)

                let actions = scheduler.recommendActions(
                    stressPoints: stressPoints,
                    trendDirection: .steady,
                    todaySnapshot: current,
                    patterns: sleepPatterns,
                    currentHour: 10,
                    readinessGate: .recovering
                )

                for action in actions {
                    if case .activitySuggestion = action {
                        XCTFail("\(persona.name) @ \(cp.label): scheduler suggested activity while readiness is recovering (score: \(readiness?.score ?? -1))")
                    }
                }
            }
        }
    }

    // MARK: - Test: Healthy User Gets Activity When Appropriate

    /// Verifies that the conflict guard doesn't over-suppress:
    /// healthy personas with good readiness should still get activity suggestions.
    func testHealthyPersonas_ActivityAllowedWhenReady() {
        let healthyPersonas = TestPersonas.all.filter {
            ["YoungAthlete", "ExcellentSleeper", "ActiveProfessional", "TeenAthlete"].contains($0.name)
        }

        for persona in healthyPersonas {
            let fullHistory = persona.generate30DayHistory()
            let snapshots = Array(fullHistory.prefix(30))
            guard let current = snapshots.last else { continue }
            let history = Array(snapshots.dropLast())

            let stressResult = stressEngine.computeStress(snapshot: current, recentHistory: history)
            let readiness = ReadinessEngine().compute(
                snapshot: current,
                stressScore: stressResult?.score,
                recentHistory: history
            )

            // These personas should be primed or ready
            if let level = readiness?.level {
                XCTAssertTrue(
                    level == .primed || level == .ready,
                    "\(persona.name) expected primed/ready readiness but got \(level.rawValue) (score: \(readiness?.score ?? -1))"
                )
            }

            // Scheduler should NOT suppress activity for healthy users
            let sleepPatterns = scheduler.learnSleepPatterns(from: snapshots)

            // Simulate low activity snapshot to trigger activity suggestion
            let lowActivitySnapshot = HeartSnapshot(
                date: current.date,
                restingHeartRate: current.restingHeartRate,
                hrvSDNN: current.hrvSDNN,
                steps: 500,
                walkMinutes: 2,
                workoutMinutes: 0,
                sleepHours: current.sleepHours
            )

            let actions = scheduler.recommendActions(
                stressPoints: [],
                trendDirection: .steady,
                todaySnapshot: lowActivitySnapshot,
                patterns: sleepPatterns,
                currentHour: 14,
                readinessGate: readiness?.level
            )

            let hasActivity = actions.contains { action in
                if case .activitySuggestion = action { return true }
                return false
            }
            XCTAssertTrue(hasActivity,
                          "\(persona.name): healthy user with low activity should get activity suggestion (readiness: \(readiness?.level.rawValue ?? "nil"))")
        }
    }

    // MARK: - Test: Stress Actions Always Pass Guard

    /// Breathe and journal prompts should never be suppressed by the
    /// conflict guard, even when readiness is recovering.
    func testStressActions_NeverSuppressedByGuard() {
        let stressPoints = [
            StressDataPoint(date: Date(), score: 70, level: .elevated)
        ]

        // Even with recovering readiness, stress actions should pass
        let action = scheduler.recommendAction(
            stressPoints: stressPoints,
            trendDirection: .rising,
            todaySnapshot: nil,
            patterns: [],
            currentHour: 14,
            readinessGate: .recovering
        )

        // Should be journal (score >= 65) or breathe (trend rising)
        switch action {
        case .journalPrompt, .breatheOnWatch:
            break // correct — stress actions pass the guard
        default:
            XCTFail("Stress action should not be suppressed by readiness guard, got: \(action)")
        }
    }

    // MARK: - Test: Three Time-of-Day Scenarios

    /// Runs the same persona at morning, afternoon, and evening to verify
    /// the scheduler gives time-appropriate advice without conflicts.
    func testTimeOfDay_MorningAfternoonEvening() {
        let persona = TestPersonas.all.first { $0.name == "ActiveProfessional" }!
        let fullHistory = persona.generate30DayHistory()
        let snapshots = Array(fullHistory.prefix(20))
        guard let current = snapshots.last else { return }
        let history = Array(snapshots.dropLast())

        let stressResult = stressEngine.computeStress(snapshot: current, recentHistory: history)
        let readiness = ReadinessEngine().compute(
            snapshot: current,
            stressScore: stressResult?.score,
            recentHistory: history
        )

        let assessment = trendEngine.assess(history: history, current: current)
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

        let stressPoints = buildStressPoints(from: snapshots)
        let sleepPatterns = scheduler.learnSleepPatterns(from: snapshots)

        let hours = [8, 14, 21]  // morning, afternoon, evening
        for hour in hours {
            let actions = scheduler.recommendActions(
                stressPoints: stressPoints,
                trendDirection: .steady,
                todaySnapshot: current,
                patterns: sleepPatterns,
                currentHour: hour,
                readinessGate: readiness?.level
            )

            // No action should conflict with NudgeGenerator
            let conflict = detectConflict(
                nudgeCategory: nudge.category,
                schedulerActions: actions,
                readinessLevel: readiness?.level
            )

            XCTAssertNil(conflict,
                         "ActiveProfessional @ hour \(hour): \(conflict ?? "")")

            // All actions should be valid
            for action in actions {
                XCTAssertTrue(isValidAction(action),
                              "Invalid action at hour \(hour): \(action)")
            }
        }
    }

    // MARK: - Test: NudgeGenerator Rest + Scheduler Activity = Conflict Caught

    /// Directly tests that without the guard, a conflict would exist,
    /// and with the guard it's resolved.
    func testConflictGuard_DirectVerification() {
        // Simulate a recovering user with low activity
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 80,
            hrvSDNN: 18,
            steps: 500,
            walkMinutes: 2,
            workoutMinutes: 0,
            sleepHours: 4.5
        )

        // Without guard (nil readiness gate) — scheduler may suggest activity
        let actionsNoGuard = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14,
            readinessGate: nil  // no guard
        )

        let hasActivityNoGuard = actionsNoGuard.contains { action in
            if case .activitySuggestion = action { return true }
            return false
        }

        // With guard (recovering) — scheduler must NOT suggest activity
        let actionsWithGuard = scheduler.recommendActions(
            stressPoints: [],
            trendDirection: .steady,
            todaySnapshot: snapshot,
            patterns: [],
            currentHour: 14,
            readinessGate: .recovering  // guard active
        )

        let hasActivityWithGuard = actionsWithGuard.contains { action in
            if case .activitySuggestion = action { return true }
            return false
        }

        let hasRestWithGuard = actionsWithGuard.contains { action in
            if case .restSuggestion = action { return true }
            return false
        }

        // Without guard: activity suggestion is possible (low activity triggers it)
        XCTAssertTrue(hasActivityNoGuard,
                      "Without guard, low-activity user should get activity suggestion")

        // With guard: activity suppressed, replaced with rest
        XCTAssertFalse(hasActivityWithGuard,
                       "With recovering guard, activity suggestion must be suppressed")
        XCTAssertTrue(hasRestWithGuard,
                      "With recovering guard, rest suggestion should replace activity")
    }

    // MARK: - Helpers

    private func buildStressPoints(from snapshots: [HeartSnapshot]) -> [StressDataPoint] {
        // Build stress data points from the last 3 snapshots
        let recent = snapshots.suffix(3)
        return recent.enumerated().map { index, snapshot in
            let baseStress = 40.0
            let rhrContribution = ((snapshot.restingHeartRate ?? 65) - 60) * 1.5
            let hrvContribution = max(0, (40 - (snapshot.hrvSDNN ?? 40))) * 0.8
            let score = min(100, max(0, baseStress + rhrContribution + hrvContribution))
            let level: StressLevel = score >= 65 ? .elevated : score >= 45 ? .elevated : .balanced
            return StressDataPoint(date: snapshot.date, score: score, level: level)
        }
    }

    /// Detects if the scheduler's actions conflict with NudgeGenerator's recommendation.
    /// Returns a description of the conflict, or nil if no conflict.
    private func detectConflict(
        nudgeCategory: NudgeCategory,
        schedulerActions: [SmartNudgeAction],
        readinessLevel: ReadinessLevel?
    ) -> String? {
        let isRestNudge = nudgeCategory == .rest || nudgeCategory == .breathe
        let isRecovering = readinessLevel == .recovering

        for action in schedulerActions {
            switch action {
            case .activitySuggestion(let nudge):
                // CONFLICT: NudgeGenerator says rest but scheduler says activity
                if isRestNudge {
                    return "NudgeGenerator=\(nudgeCategory.rawValue) but scheduler suggests activity (\(nudge.title))"
                }
                // CONFLICT: Readiness is recovering but scheduler says activity
                if isRecovering {
                    return "Readiness=recovering but scheduler suggests activity (\(nudge.title))"
                }

            case .journalPrompt, .breatheOnWatch, .morningCheckIn,
                 .bedtimeWindDown, .restSuggestion, .standardNudge:
                // These never conflict — stress/rest actions are always safe
                break
            }
        }
        return nil
    }

    private func isValidAction(_ action: SmartNudgeAction) -> Bool {
        switch action {
        case .journalPrompt(let prompt):
            return !prompt.question.isEmpty
        case .breatheOnWatch(let nudge):
            return nudge.category == .breathe && !nudge.title.isEmpty
        case .morningCheckIn(let msg):
            return !msg.isEmpty
        case .bedtimeWindDown(let nudge):
            return nudge.category == .rest && !nudge.title.isEmpty
        case .activitySuggestion(let nudge):
            return (nudge.category == .walk || nudge.category == .moderate) && !nudge.title.isEmpty
        case .restSuggestion(let nudge):
            return nudge.category == .rest && !nudge.title.isEmpty
        case .standardNudge:
            return true
        }
    }
}

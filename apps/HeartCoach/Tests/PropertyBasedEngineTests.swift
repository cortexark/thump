// PropertyBasedEngineTests.swift
// ThumpCoreTests
//
// Property-based tests for engine invariants. Uses SeededRNG to generate
// random plausible HeartSnapshots and verify properties always hold.

import XCTest
@testable import Thump

final class PropertyBasedEngineTests: XCTestCase {

    private let composer = AdviceComposer()
    private let config = HealthPolicyConfig()
    private let iterations = 100

    // MARK: - Random Snapshot Generator

    private struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func randomSnapshot(rng: inout SeededRNG) -> HeartSnapshot {
        let sleep: Double? = Bool.random(using: &rng) ? Double.random(in: 0...12, using: &rng) : nil
        let hrv: Double? = Bool.random(using: &rng) ? Double.random(in: 5...150, using: &rng) : nil
        let rhr: Double? = Bool.random(using: &rng) ? Double.random(in: 35...120, using: &rng) : nil
        let steps: Double? = Bool.random(using: &rng) ? Double.random(in: 0...25000, using: &rng) : nil
        let walk: Double? = Bool.random(using: &rng) ? Double.random(in: 0...120, using: &rng) : nil
        let workout: Double? = Bool.random(using: &rng) ? Double.random(in: 0...180, using: &rng) : nil
        let zones = (0..<5).map { _ in Double.random(in: 0...60, using: &rng) }

        return HeartSnapshot(
            date: Date(),
            restingHeartRate: rhr,
            hrvSDNN: hrv,
            zoneMinutes: zones,
            steps: steps,
            walkMinutes: walk,
            workoutMinutes: workout,
            sleepHours: sleep
        )
    }

    private func randomAssessment(rng: inout SeededRNG) -> HeartAssessment {
        let statuses: [TrendStatus] = [.improving, .stable, .needsAttention]
        let status = statuses[Int.random(in: 0..<statuses.count, using: &rng)]
        let stressFlag = Bool.random(using: &rng)
        let days = Int.random(in: 0...12, using: &rng)
        let alert: ConsecutiveElevationAlert? = days > 0
            ? ConsecutiveElevationAlert(consecutiveDays: days, threshold: 75, elevatedMean: 78, personalMean: 65)
            : nil

        return HeartAssessment(
            status: status,
            confidence: .medium,
            anomalyScore: Double.random(in: 0...1, using: &rng),
            regressionFlag: Bool.random(using: &rng),
            stressFlag: stressFlag,
            cardioScore: Double.random(in: 30...100, using: &rng),
            dailyNudge: DailyNudge(category: .walk, title: "T", description: "D", durationMinutes: 15, icon: "figure.walk"),
            explanation: "Test",
            consecutiveAlert: alert
        )
    }

    private func randomReadiness(rng: inout SeededRNG) -> ReadinessResult {
        let score = Int.random(in: 0...100, using: &rng)
        let level: ReadinessLevel
        if score >= 80 { level = .primed }
        else if score >= 65 { level = .ready }
        else if score >= 45 { level = .moderate }
        else { level = .recovering }

        return ReadinessResult(
            score: score,
            level: level,
            pillars: [
                ReadinessPillar(type: .sleep, score: Double(score), weight: 0.25, detail: "OK"),
                ReadinessPillar(type: .hrvTrend, score: Double(score), weight: 0.25, detail: "OK"),
                ReadinessPillar(type: .recovery, score: Double(score), weight: 0.20, detail: "OK"),
                ReadinessPillar(type: .activityBalance, score: Double(score), weight: 0.15, detail: "OK"),
                ReadinessPillar(type: .stress, score: Double(score), weight: 0.15, detail: "OK")
            ],
            summary: "Test"
        )
    }

    private func randomStress(rng: inout SeededRNG) -> StressResult? {
        guard Bool.random(using: &rng) else { return nil }
        let score = Double.random(in: 0...100, using: &rng)
        let level: StressLevel
        if score < 34 { level = .relaxed }
        else if score < 67 { level = .balanced }
        else { level = .elevated }
        return StressResult(score: score, level: level, description: "Test")
    }

    // MARK: - Property: AdviceComposer never crashes on random input

    func testProperty_adviceComposer_neverCrashes() {
        var rng = SeededRNG(state: 42)
        for i in 0..<iterations {
            let snapshot = randomSnapshot(rng: &rng)
            let assessment = randomAssessment(rng: &rng)
            let readiness = randomReadiness(rng: &rng)
            let stress = randomStress(rng: &rng)

            // Should never crash
            let state = composer.compose(
                snapshot: snapshot,
                assessment: assessment,
                stressResult: stress,
                readinessResult: readiness,
                zoneAnalysis: nil,
                config: config
            )

            // Basic sanity checks
            XCTAssertFalse(state.heroMessageID.isEmpty, "Iteration \(i): heroMessageID must not be empty")
            XCTAssertFalse(state.focusInsightID.isEmpty, "Iteration \(i): focusInsightID must not be empty")
            XCTAssertFalse(state.checkBadgeID.isEmpty, "Iteration \(i): checkBadgeID must not be empty")
        }
    }

    // MARK: - Property: Hard invariants always hold on random input

    func testProperty_hardInvariants_alwaysHold() {
        var rng = SeededRNG(state: 123)
        for i in 0..<iterations {
            let snapshot = randomSnapshot(rng: &rng)
            let assessment = randomAssessment(rng: &rng)
            let readiness = randomReadiness(rng: &rng)
            let stress = randomStress(rng: &rng)

            let state = composer.compose(
                snapshot: snapshot,
                assessment: assessment,
                stressResult: stress,
                readinessResult: readiness,
                zoneAnalysis: nil,
                config: config
            )

            let trace = CoherenceChecker.check(
                adviceState: state,
                readinessResult: readiness,
                config: config
            )

            XCTAssertEqual(trace.hardViolationsFound, 0,
                          "Iteration \(i): hard violations found: \(trace.hardViolations)")
        }
    }

    // MARK: - Property: Goals targets decrease as readiness decreases

    func testProperty_goalsDecrease_asReadinessDecreases() {
        let snapshot = HeartSnapshot(
            date: Date(), restingHeartRate: 65, hrvSDNN: 45,
            zoneMinutes: [10, 20, 30, 15, 5], steps: 3000,
            walkMinutes: 10, workoutMinutes: 5, sleepHours: 7.0
        )
        let assessment = HeartAssessment(
            status: .stable, confidence: .medium, anomalyScore: 0.3,
            regressionFlag: false, stressFlag: false, cardioScore: 70,
            dailyNudge: DailyNudge(category: .walk, title: "T", description: "D", durationMinutes: 15, icon: "figure.walk"),
            explanation: "Test"
        )

        let readinessScores = [90, 75, 60, 40, 25]
        var previousStepTarget: Double = .infinity

        for score in readinessScores {
            let level: ReadinessLevel
            if score >= 80 { level = .primed }
            else if score >= 65 { level = .ready }
            else if score >= 45 { level = .moderate }
            else { level = .recovering }

            let readiness = ReadinessResult(
                score: score, level: level,
                pillars: [ReadinessPillar(type: .sleep, score: Double(score), weight: 1.0, detail: "OK")],
                summary: "Test"
            )

            let state = composer.compose(
                snapshot: snapshot,
                assessment: assessment,
                stressResult: nil,
                readinessResult: readiness,
                zoneAnalysis: nil,
                config: config
            )

            let stepTarget = state.goals.first { $0.category == .steps }?.target ?? 0
            XCTAssertLessThanOrEqual(stepTarget, previousStepTarget,
                                    "Steps should not increase as readiness drops (score=\(score), steps=\(stepTarget), prev=\(previousStepTarget))")
            previousStepTarget = stepTarget
        }
    }

    // MARK: - Property: Overtraining state is monotonically increasing

    func testProperty_overtrainingState_monotonic() {
        var rng = SeededRNG(state: 77)
        let snapshot = randomSnapshot(rng: &rng)
        let readiness = randomReadiness(rng: &rng)

        var previousState: OvertrainingState = .none
        for days in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20] {
            let assessment = HeartAssessment(
                status: .stable, confidence: .medium, anomalyScore: 0.3,
                regressionFlag: false, stressFlag: false, cardioScore: 70,
                dailyNudge: DailyNudge(category: .walk, title: "T", description: "D", durationMinutes: 15, icon: "figure.walk"),
                explanation: "Test",
                consecutiveAlert: days > 0 ? ConsecutiveElevationAlert(
                    consecutiveDays: days, threshold: 75, elevatedMean: 78, personalMean: 65
                ) : nil
            )

            let state = composer.compose(
                snapshot: snapshot,
                assessment: assessment,
                stressResult: nil,
                readinessResult: readiness,
                zoneAnalysis: nil,
                config: config
            )

            XCTAssertGreaterThanOrEqual(state.overtrainingState, previousState,
                                        "Overtraining must be monotonic at \(days) days")
            previousState = state.overtrainingState
        }
    }

    // MARK: - Property: Mode severity increases as readiness drops

    func testProperty_modeEscalates_asReadinessDrops() {
        let snapshot = HeartSnapshot(
            date: Date(), restingHeartRate: 65, hrvSDNN: 45,
            zoneMinutes: [10, 20, 30, 15, 5], steps: 3000,
            walkMinutes: 10, workoutMinutes: 5, sleepHours: 7.0
        )
        let assessment = HeartAssessment(
            status: .stable, confidence: .medium, anomalyScore: 0.3,
            regressionFlag: false, stressFlag: false, cardioScore: 70,
            dailyNudge: DailyNudge(category: .walk, title: "T", description: "D", durationMinutes: 15, icon: "figure.walk"),
            explanation: "Test"
        )

        let readinessScores = [90, 70, 50, 30]
        var previousMode: GuidanceMode = .pushDay // least severe

        for score in readinessScores {
            let level: ReadinessLevel
            if score >= 80 { level = .primed }
            else if score >= 65 { level = .ready }
            else if score >= 45 { level = .moderate }
            else { level = .recovering }

            let readiness = ReadinessResult(
                score: score, level: level,
                pillars: [ReadinessPillar(type: .sleep, score: Double(score), weight: 1.0, detail: "OK")],
                summary: "Test"
            )

            let state = composer.compose(
                snapshot: snapshot,
                assessment: assessment,
                stressResult: nil,
                readinessResult: readiness,
                zoneAnalysis: nil,
                config: config
            )

            XCTAssertGreaterThanOrEqual(state.mode, previousMode,
                                        "Mode severity should increase as readiness drops (score=\(score))")
            previousMode = state.mode
        }
    }

    // MARK: - Property: Sleep deprivation caps mode

    func testProperty_sleepCap_preventsHighIntensityMode() {
        var rng = SeededRNG(state: 99)
        for _ in 0..<50 {
            let sleepHours = Double.random(in: 0...3, using: &rng)
            let snapshot = HeartSnapshot(
                date: Date(), restingHeartRate: 60, hrvSDNN: 50,
                zoneMinutes: [10, 20, 30, 15, 5], steps: 5000,
                walkMinutes: 20, workoutMinutes: 10, sleepHours: sleepHours
            )
            let assessment = HeartAssessment(
                status: .improving, confidence: .high, anomalyScore: 0.1,
                regressionFlag: false, stressFlag: false, cardioScore: 85,
                dailyNudge: DailyNudge(category: .walk, title: "T", description: "D", durationMinutes: 15, icon: "figure.walk"),
                explanation: "Test"
            )
            let readiness = ReadinessResult(
                score: 90, level: .primed,
                pillars: [ReadinessPillar(type: .sleep, score: 90, weight: 1.0, detail: "OK")],
                summary: "Test"
            )

            let state = composer.compose(
                snapshot: snapshot,
                assessment: assessment,
                stressResult: StressResult(score: 15, level: .relaxed, description: "Test"),
                readinessResult: readiness,
                zoneAnalysis: nil,
                config: config
            )

            XCTAssertNotEqual(state.mode, .pushDay,
                             "pushDay should never happen with \(String(format: "%.1f", sleepHours))h sleep")
        }
    }

    // MARK: - Fuzz: No crash on extreme/nil values

    func testFuzz_extremeValues_noCrash() {
        let extremeSnapshots = [
            HeartSnapshot(date: Date(), restingHeartRate: 220, hrvSDNN: 500, zoneMinutes: [0,0,0,0,0], steps: 100000, walkMinutes: 1440, workoutMinutes: 1440, sleepHours: 24),
            HeartSnapshot(date: Date(), restingHeartRate: 30, hrvSDNN: 1, zoneMinutes: [0,0,0,0,0], steps: 0, walkMinutes: 0, workoutMinutes: 0, sleepHours: 0),
            HeartSnapshot(date: Date(), restingHeartRate: nil, hrvSDNN: nil, zoneMinutes: [0,0,0,0,0], steps: nil, walkMinutes: nil, workoutMinutes: nil, sleepHours: nil),
        ]

        let assessment = HeartAssessment(
            status: .stable, confidence: .medium, anomalyScore: 0.5,
            regressionFlag: false, stressFlag: false, cardioScore: 50,
            dailyNudge: DailyNudge(category: .walk, title: "T", description: "D", durationMinutes: 15, icon: "figure.walk"),
            explanation: "Test"
        )

        for snapshot in extremeSnapshots {
            // Should not crash
            let state = composer.compose(
                snapshot: snapshot,
                assessment: assessment,
                stressResult: nil,
                readinessResult: nil,
                zoneAnalysis: nil,
                config: config
            )
            XCTAssertFalse(state.heroMessageID.isEmpty)
        }
    }
}

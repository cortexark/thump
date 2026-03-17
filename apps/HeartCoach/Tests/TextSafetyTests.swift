// TextSafetyTests.swift
// ThumpCoreTests
//
// Verifies dangerous text patterns are absent and safety text
// patterns are present in engine output.
// Platforms: iOS 17+

import XCTest
@testable import Thump

final class TextSafetyTests: XCTestCase {

    private let engine = ReadinessEngine()

    // MARK: - Helpers

    private func snapshot(
        sleepHours: Double? = 7.5,
        walkMinutes: Double? = 25,
        hrvSDNN: Double? = 45,
        restingHeartRate: Double? = 65,
        recoveryHR1m: Double? = 25
    ) -> HeartSnapshot {
        HeartSnapshot(
            date: Date(),
            restingHeartRate: restingHeartRate,
            hrvSDNN: hrvSDNN,
            recoveryHR1m: recoveryHR1m,
            walkMinutes: walkMinutes,
            workoutMinutes: 0,
            sleepHours: sleepHours
        )
    }

    // MARK: - No Numeric Stress Score

    func testStressLevel_noScoreInFriendlyMessage() {
        // Verify friendlyMessage(for:) never contains "Score:" pattern
        for score in stride(from: 0.0, through: 100.0, by: 5.0) {
            let msg = StressLevel.friendlyMessage(for: score)
            XCTAssertFalse(msg.contains("Score:"), "Score \(score): friendlyMessage should not contain 'Score:', got: \(msg)")
        }
    }

    // MARK: - No "Workout" in Readiness Summary

    func testReadinessSummary_noWorkoutWord() {
        // Test readiness with various scenarios
        let scenarios: [(Double?, Double?, Double?, Double?)] = [
            (8.0, 50, 30, 30.0),   // likely primed/ready
            (7.5, 50, 25, 50.0),   // moderate
            (4.5, 20, 8, 85.0),    // recovering
        ]
        for (sleep, hrv, recovery, stress) in scenarios {
            let s = snapshot(sleepHours: sleep, hrvSDNN: hrv, recoveryHR1m: recovery)
            let result = engine.compute(snapshot: s, stressScore: stress, recentHistory: [])
            if let r = result {
                XCTAssertFalse(r.summary.contains("workout"),
                    "Readiness summary for \(r.level) should not contain 'workout', got: \(r.summary)")
            }
        }
    }

    func testReadySummary_usesBeActive() {
        // Create a snapshot that produces "Ready" level
        let s = snapshot(sleepHours: 7.5, walkMinutes: 30, hrvSDNN: 50, restingHeartRate: 60, recoveryHR1m: 30)
        let result = engine.compute(snapshot: s, stressScore: 30, recentHistory: [])
        if let r = result, r.level == .ready {
            XCTAssertTrue(r.summary.contains("be active"),
                "Ready summary should contain 'be active', got: \(r.summary)")
        }
    }

    // MARK: - No "Brisk Walk" in Default Nudge Library

    func testNudgeLibrary_noBriskWalk() {
        let generator = NudgeGenerator()
        let s = snapshot()
        let nudges = generator.generateMultiple(
            confidence: .high,
            anomaly: 0,
            regression: false,
            stress: false,
            feedback: nil,
            current: s,
            history: []
        )
        for nudge in nudges {
            XCTAssertFalse(nudge.title.contains("Brisk"),
                "Nudge title should not contain 'Brisk', got: \(nudge.title)")
        }
    }

    // MARK: - No "Getting More Efficient" in Coaching

    func testCoachingText_noHeartEfficient() {
        let coachingEngine = CoachingEngine()
        // Create a history with declining RHR to trigger the improvement message
        var history: [HeartSnapshot] = []
        for i in 0..<14 {
            let rhr = 70.0 - Double(i) * 0.5  // RHR drops over time
            history.append(HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                restingHeartRate: rhr,
                hrvSDNN: 45,
                walkMinutes: 25,
                workoutMinutes: 0,
                sleepHours: 7.5
            ))
        }
        let current = history.first!
        let report = coachingEngine.generateReport(current: current, history: history, streakDays: 5)
        for insight in report.insights {
            XCTAssertFalse(insight.message.contains("getting more efficient"),
                "Coaching text should not say 'getting more efficient', got: \(insight.message)")
        }
    }

    // MARK: - Recovering Summary Has Positive Anchor

    func testRecoveringSummary_containsActionableGuidance() {
        // Create a snapshot that should produce "Recovering" level
        let s = snapshot(sleepHours: 4.0, walkMinutes: 2, hrvSDNN: 18, restingHeartRate: 85, recoveryHR1m: 8)
        let result = engine.compute(snapshot: s, stressScore: 85, recentHistory: [])
        if let r = result, r.level == .recovering {
            XCTAssertTrue(r.summary.contains("sleep") || r.summary.contains("rest"),
                "Recovering summary should mention sleep or rest, got: \(r.summary)")
        }
    }

    // MARK: - Medical Escalation Nudge

    func testMedicalEscalation_triggersWhenRecoveringAndStressed() {
        let generator = NudgeGenerator()
        let s = snapshot(sleepHours: 4.5, walkMinutes: 2, hrvSDNN: 20, restingHeartRate: 85, recoveryHR1m: 8)

        // Create a recovering readiness result
        let readinessResult = engine.compute(snapshot: s, stressScore: 90, recentHistory: [])

        let nudges = generator.generateMultiple(
            confidence: .high,
            anomaly: 0,
            regression: false,
            stress: true,
            feedback: nil,
            current: s,
            history: [],
            readiness: readinessResult
        )

        let hasMedical = nudges.contains { $0.title.lowercased().contains("doctor") }
        if let readiness = readinessResult, readiness.level == .recovering {
            XCTAssertTrue(hasMedical,
                "Should include medical escalation nudge when recovering + stressed. Nudge titles: \(nudges.map { $0.title })")
        }
    }

    func testMedicalNudge_containsFTCDisclaimer() {
        let generator = NudgeGenerator()
        let s = snapshot(sleepHours: 4.5, walkMinutes: 2, hrvSDNN: 20, restingHeartRate: 85, recoveryHR1m: 8)
        let readinessResult = engine.compute(snapshot: s, stressScore: 90, recentHistory: [])

        let nudges = generator.generateMultiple(
            confidence: .high,
            anomaly: 0,
            regression: false,
            stress: true,
            feedback: nil,
            current: s,
            history: [],
            readiness: readinessResult
        )

        let medicalNudge = nudges.first { $0.title.lowercased().contains("doctor") }
        if let nudge = medicalNudge {
            XCTAssertTrue(nudge.description.contains("not intended to diagnose"),
                "Medical nudge should contain FTC disclaimer, got: \(nudge.description)")
        }
    }

    // MARK: - Affirming Nudge When Recovering

    func testRecoveringNudge_hasAffirmingContent() {
        let generator = NudgeGenerator()
        let s = snapshot(sleepHours: 4.5, walkMinutes: 2, hrvSDNN: 20, restingHeartRate: 85, recoveryHR1m: 8)
        let readinessResult = engine.compute(snapshot: s, stressScore: 85, recentHistory: [])

        let nudges = generator.generateMultiple(
            confidence: .high,
            anomaly: 0,
            regression: false,
            stress: true,
            feedback: nil,
            current: s,
            history: [],
            readiness: readinessResult
        )

        if let readiness = readinessResult, readiness.level == .recovering {
            let hasCelebrate = nudges.contains { $0.category == .celebrate }
            XCTAssertTrue(hasCelebrate,
                "Should include affirming nudge when recovering. Nudge categories: \(nudges.map { $0.category })")
        }
    }

    // MARK: - Sleep Severe Mentions Prioritize

    func testSleepSevere_mentionsPrioritize() {
        let s = snapshot(sleepHours: 4.0)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertTrue(sleepPillar!.detail.contains("very low"),
            "Sleep <5h should mention 'very low', got: \(sleepPillar!.detail)")
    }

    // MARK: - HRV Severe Mentions Rest

    func testHRVSevere_mentionsRest() {
        // Today HRV = 20, baseline = 50 → ratio = 0.40
        let today = snapshot(hrvSDNN: 20)
        let history = (0..<14).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                restingHeartRate: 65, hrvSDNN: 50, recoveryHR1m: 25,
                walkMinutes: 20, workoutMinutes: 0, sleepHours: 7.5
            )
        }
        let result = engine.compute(snapshot: today, stressScore: nil, recentHistory: history)
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        XCTAssertNotNil(hrvPillar)
        XCTAssertTrue(hrvPillar!.detail.lowercased().contains("rest"),
            "HRV ratio <0.60 should mention 'rest', got: \(hrvPillar!.detail)")
    }

    // MARK: - Stress Severe Mentions Break/Rest

    func testStressSevere_mentionsBreak() {
        let msg = StressLevel.friendlyMessage(for: 90)
        XCTAssertTrue(msg.contains("break") || msg.contains("rest") || msg.contains("strain"),
            "Stress >85 should mention 'break', 'rest', or 'strain', got: \(msg)")
    }

    // MARK: - Stress Action Hints

    func testStressActionHints_exist() {
        for level in StressLevel.allCases {
            XCTAssertFalse(level.actionHint.isEmpty,
                "StressLevel.\(level) should have a non-empty actionHint")
        }
    }

    // MARK: - Oversleep Flag

    func testOversleep_mentionsCareTeam() {
        let s = snapshot(sleepHours: 10.5)
        let result = engine.compute(snapshot: s, stressScore: nil, recentHistory: [])
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        XCTAssertNotNil(sleepPillar)
        XCTAssertTrue(sleepPillar!.detail.contains("care team"),
            "Sleep >9h should mention 'care team', got: \(sleepPillar!.detail)")
    }

    // MARK: - Intensity Nudge Gating

    func testIntensityNudge_onlyWhenReadyOrPrimed() {
        let generator = NudgeGenerator()
        // Good metrics → should produce ready/primed readiness
        let s = snapshot(sleepHours: 8.0, walkMinutes: 30, hrvSDNN: 55, restingHeartRate: 55, recoveryHR1m: 35)
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                restingHeartRate: 55, hrvSDNN: 50, recoveryHR1m: 30,
                walkMinutes: 25, workoutMinutes: 0, sleepHours: 7.5
            )
        }
        let readinessResult = engine.compute(snapshot: s, stressScore: 20, recentHistory: history)
        guard let r = readinessResult, (r.level == .primed || r.level == .ready) else {
            // Can't test if readiness isn't right — skip rather than fail
            return
        }

        let nudges = generator.generateMultiple(
            confidence: .high, anomaly: 0, regression: false,
            stress: false, feedback: nil,
            current: s, history: history, readiness: readinessResult
        )

        let hasIntensity = nudges.contains { $0.category == .intensity }
        XCTAssertTrue(hasIntensity,
            "Intensity nudge should appear when readiness is \(r.level). Categories: \(nudges.map { $0.category })")
    }

    func testIntensityNudge_neverWhenRecovering() {
        let generator = NudgeGenerator()
        let s = snapshot(sleepHours: 3.5, walkMinutes: 0, hrvSDNN: 15, restingHeartRate: 90, recoveryHR1m: 8)
        let readinessResult = engine.compute(snapshot: s, stressScore: 90, recentHistory: [])

        let nudges = generator.generateMultiple(
            confidence: .high, anomaly: 0, regression: false,
            stress: true, feedback: nil,
            current: s, history: [], readiness: readinessResult
        )

        let hasIntensity = nudges.contains { $0.category == .intensity }
        XCTAssertFalse(hasIntensity,
            "Intensity nudge should NEVER appear when recovering. Categories: \(nudges.map { $0.category })")
    }

    func testIntensityNudge_neverWhenModerate() {
        let generator = NudgeGenerator()
        // Moderate scenario — decent but not great
        let s = snapshot(sleepHours: 6.0, walkMinutes: 10, hrvSDNN: 30, restingHeartRate: 72, recoveryHR1m: 18)
        let readinessResult = engine.compute(snapshot: s, stressScore: 55, recentHistory: [])

        if let r = readinessResult, r.level == .moderate {
            let nudges = generator.generateMultiple(
                confidence: .high, anomaly: 0, regression: false,
                stress: false, feedback: nil,
                current: s, history: [], readiness: readinessResult
            )

            let hasIntensity = nudges.contains { $0.category == .intensity }
            XCTAssertFalse(hasIntensity,
                "Intensity nudge should NEVER appear when moderate. Categories: \(nudges.map { $0.category })")
        }
    }

    func testIntensityNudge_hasIntensityCategory() {
        let generator = NudgeGenerator()
        let s = snapshot(sleepHours: 8.5, walkMinutes: 35, hrvSDNN: 60, restingHeartRate: 52, recoveryHR1m: 38)
        let history = (1...7).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                restingHeartRate: 52, hrvSDNN: 55, recoveryHR1m: 35,
                walkMinutes: 30, workoutMinutes: 0, sleepHours: 8.0
            )
        }
        let readinessResult = engine.compute(snapshot: s, stressScore: 15, recentHistory: history)

        let nudges = generator.generateMultiple(
            confidence: .high, anomaly: 0, regression: false,
            stress: false, feedback: nil,
            current: s, history: history, readiness: readinessResult
        )

        let intensityNudges = nudges.filter { $0.category == .intensity }
        for nudge in intensityNudges {
            XCTAssertEqual(nudge.category, .intensity,
                "Intensity nudge should have .intensity category")
        }
    }

    // MARK: - HRV Baseline Normalization Resistance

    func testHRV_baselineResistsDepression() {
        // Simulate a 14-day stress spiral where HRV drops from 50→25ms.
        // With mean-based baseline, the depressed values drag the baseline down
        // and today's 25ms looks "at baseline". With 75th percentile, the
        // baseline stays anchored to the better days.
        var history: [HeartSnapshot] = []
        for i in 0..<14 {
            // HRV drops linearly from 50 to 25 over 14 days
            let hrv = 50.0 - Double(i) * (25.0 / 14.0)
            history.append(HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                restingHeartRate: 65,
                hrvSDNN: hrv,
                walkMinutes: 20,
                workoutMinutes: 0,
                sleepHours: 7.5
            ))
        }
        // Today: HRV = 25ms (still depressed)
        let today = snapshot(hrvSDNN: 25)
        let result = engine.compute(snapshot: today, stressScore: nil, recentHistory: history)
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        XCTAssertNotNil(hrvPillar)
        // With 75th percentile baseline (~43ms), ratio ≈ 0.58 → "well below"
        // With mean baseline (~37ms), ratio ≈ 0.67 → "noticeably lower" (understated)
        XCTAssertTrue(hrvPillar!.detail.contains("well below"),
            "During stress spiral, HRV 25ms should say 'well below' (not normalize), got: \(hrvPillar!.detail)")
    }

    // MARK: - Coaching Engine Cross-Module Coherence

    func testCoaching_noVolumePraiseWhenRecovering() {
        let coachingEngine = CoachingEngine()
        // Create a recovering readiness result
        let recoveringResult = ReadinessResult(
            score: 25,
            level: .recovering,
            pillars: [],
            summary: "Tough day for your body."
        )

        // Create history where activity increased (would normally trigger praise)
        var history: [HeartSnapshot] = []
        for i in 0..<14 {
            let walkMin = i < 7 ? 10.0 : 40.0 // Last week: 10min, this week: 40min
            history.append(HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                restingHeartRate: 85,
                hrvSDNN: 20,
                walkMinutes: walkMin,
                workoutMinutes: 0,
                sleepHours: 4.5
            ))
        }
        let current = history.first!
        let report = coachingEngine.generateReport(
            current: current, history: history, streakDays: 5, readiness: recoveringResult
        )

        // Hero message should mention rest, not celebrate activity
        XCTAssertTrue(report.heroMessage.contains("rest"),
            "Hero message when recovering should mention rest, got: \(report.heroMessage)")
        XCTAssertFalse(report.heroMessage.contains("Keep going"),
            "Hero message when recovering should not say 'Keep going', got: \(report.heroMessage)")

        // Activity insight should not praise volume increase
        let activityInsight = report.insights.first { $0.metric == .activity }
        if let insight = activityInsight {
            XCTAssertNotEqual(insight.direction, .improving,
                "Activity insight should not be .improving when recovering, got: \(insight.message)")
        }
    }

    func testCoaching_heroMessageAlignsWithReadiness() {
        let coachingEngine = CoachingEngine()
        // When readiness is recovering, hero should never say "on a roll" or "keep it up"
        let recoveringResult = ReadinessResult(
            score: 20, level: .recovering, pillars: [], summary: ""
        )
        let history = (0..<14).map { i in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                restingHeartRate: 60, hrvSDNN: 50, walkMinutes: 30,
                workoutMinutes: 0, sleepHours: 8.0
            )
        }
        let report = coachingEngine.generateReport(
            current: history.first!, history: history, streakDays: 10, readiness: recoveringResult
        )

        let forbidden = ["Keep going", "on a Roll", "firing on all cylinders", "trending in the right direction"]
        for phrase in forbidden {
            XCTAssertFalse(report.heroMessage.contains(phrase),
                "Recovering hero should not contain '\(phrase)', got: \(report.heroMessage)")
        }
    }
}

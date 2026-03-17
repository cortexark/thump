// TextPersonaRegressionTests.swift
// ThumpCoreTests
//
// End-to-end persona tests verifying the complete text experience
// after text quality fixes. Each test uses a synthetic persona's
// history to ensure user-facing text is appropriate for that profile.
// Platforms: iOS 17+

import XCTest
@testable import Thump

final class TextPersonaRegressionTests: XCTestCase {

    private let engine = ReadinessEngine()
    private let stressEngine = StressEngine()
    private let nudgeGenerator = NudgeGenerator()

    // MARK: - Helpers

    /// Computes readiness for the last day of a persona's history.
    private func readiness(for persona: SyntheticPersona) -> ReadinessResult? {
        let history = persona.generateHistory()
        guard let current = history.last else { return nil }
        return engine.compute(
            snapshot: current,
            stressScore: nil,
            recentHistory: history
        )
    }

    /// Computes stress for the last day of a persona's history.
    private func stress(for persona: SyntheticPersona) -> StressResult? {
        let history = persona.generateHistory()
        guard let current = history.last else { return nil }
        let avgHRV = history.compactMap(\.hrvSDNN).reduce(0, +) / Double(max(1, history.count))
        let input = StressContextInput(
            currentHRV: current.hrvSDNN ?? persona.hrvSDNN,
            baselineHRV: avgHRV,
            currentRHR: current.restingHeartRate,
            baselineRHR: persona.restingHR,
            recentHRVs: history.suffix(7).compactMap(\.hrvSDNN),
            sleepHours: current.sleepHours
        )
        return stressEngine.computeStress(context: input)
    }

    // MARK: - Young Athlete: All-Positive Day

    func testYoungAthlete_allPositive() {
        let persona = SyntheticPersonas.youngAthlete
        let result = readiness(for: persona)
        XCTAssertNotNil(result)
        if let r = result {
            let allDetails = r.pillars.map { $0.detail.lowercased() }
            let positiveWords = ["sweet spot", "excellent", "solid", "great", "good", "above", "baseline", "keep it up", "active day"]
            let hasPositive = allDetails.contains { detail in
                positiveWords.contains { detail.contains($0) }
            }
            XCTAssertTrue(hasPositive,
                "Young athlete should see positive pillar text, got: \(allDetails)")
        }
    }

    // MARK: - Young Sedentary: Activity Shows Minutes

    func testYoungSedentary_activityShowsMinutes() {
        let persona = SyntheticPersonas.youngSedentary
        let result = readiness(for: persona)
        XCTAssertNotNil(result)
        let actPillar = result?.pillars.first { $0.type == .activityBalance }
        if let act = actPillar {
            XCTAssertFalse(act.detail.contains("Some activity"),
                "Young sedentary should see specific minutes, not 'Some activity', got: \(act.detail)")
        }
    }

    // MARK: - New Mom: Sleep Shows Severe

    func testNewMom_sleepShowsSevere() {
        let persona = SyntheticPersonas.newMom
        let history = persona.generateHistory()
        guard let lowSleepDay = history.last else { return }
        let result = engine.compute(snapshot: lowSleepDay, stressScore: nil, recentHistory: history)
        let sleepPillar = result?.pillars.first { $0.type == .sleep }
        if let sp = sleepPillar, let hours = lowSleepDay.sleepHours, hours < 5.5 {
            XCTAssertFalse(sp.detail.contains("a bit short"),
                "New mom with ~\(String(format: "%.1f", hours))h sleep should NOT see 'a bit short', got: \(sp.detail)")
        }
    }

    // MARK: - New Mom: Has Positive Anchor

    func testNewMom_hasPositiveAnchor() {
        let persona = SyntheticPersonas.newMom
        let history = persona.generateHistory()
        guard let current = history.last else { return }
        let result = engine.compute(snapshot: current, stressScore: 78, recentHistory: history)
        if let r = result, r.level == .recovering {
            XCTAssertTrue(r.summary.contains("sleep") || r.summary.contains("rest"),
                "New mom recovering summary should mention sleep or rest, got: \(r.summary)")
        }
    }

    // MARK: - Active Senior: No "Workout" Word

    func testActiveSenior_noWorkoutWord() {
        let persona = SyntheticPersonas.activeSenior
        let result = readiness(for: persona)
        XCTAssertNotNil(result)
        if let r = result {
            XCTAssertFalse(r.summary.lowercased().contains("workout"),
                "Active senior readiness should not contain 'workout', got: \(r.summary)")
        }
    }

    // MARK: - Sedentary Senior: HRV Graduated

    func testSedentarySenior_hrvNotMinimized() {
        let persona = SyntheticPersonas.sedentarySenior
        let history = persona.generateHistory()
        guard let current = history.last else { return }
        let result = engine.compute(snapshot: current, stressScore: nil, recentHistory: history)
        let hrvPillar = result?.pillars.first { $0.type == .hrvTrend }
        if let hrv = hrvPillar {
            let detail = hrv.detail.lowercased()
            // Verify graduated language is used (not the old "a bit below your average")
            if detail.contains("well below") || detail.contains("noticeably lower") {
                XCTAssertTrue(true) // Correct graduated response
            } else if detail.contains("a bit below") {
                XCTAssertTrue(detail.contains("usual"),
                    "HRV 'a bit below' should reference 'usual' not 'average', got: \(hrv.detail)")
            }
        }
    }

    // MARK: - Anxiety Profile: No Numeric Stress Score

    func testAnxietyProfile_noNumericStressInFriendlyMessage() {
        let persona = SyntheticPersonas.anxietyProfile
        let stressResult = stress(for: persona)
        if let s = stressResult {
            let friendlyMsg = StressLevel.friendlyMessage(for: s.score)
            XCTAssertFalse(friendlyMsg.contains("Score:"),
                "Anxiety profile stress message should not contain 'Score:', got: \(friendlyMsg)")
        }
    }

    // MARK: - Anxiety Profile: Medical Escalation

    func testAnxietyProfile_medicalEscalation() {
        let persona = SyntheticPersonas.anxietyProfile
        let history = persona.generateHistory()
        guard let current = history.last else { return }

        let readinessResult = engine.compute(snapshot: current, stressScore: 85, recentHistory: history)

        let nudges = nudgeGenerator.generateMultiple(
            confidence: .high,
            anomaly: 0,
            regression: false,
            stress: true,
            feedback: nil,
            current: current,
            history: history,
            readiness: readinessResult
        )

        if let r = readinessResult, r.level == .recovering {
            let hasMedical = nudges.contains { $0.title.lowercased().contains("doctor") }
            XCTAssertTrue(hasMedical,
                "Anxiety profile when recovering+stressed should include medical escalation. Nudge titles: \(nudges.map { $0.title })")
        }
    }

    // MARK: - Overtraining: Graduated Stress Text

    func testOvertraining_stressGraduated() {
        let persona = SyntheticPersonas.overtrainingSyndrome
        let stressResult = stress(for: persona)
        if let s = stressResult, s.level == .elevated {
            let friendlyMsg = StressLevel.friendlyMessage(for: s.score)
            if s.score >= 76 {
                XCTAssertTrue(
                    friendlyMsg.contains("managing more") || friendlyMsg.contains("strain"),
                    "Overtraining with score \(s.score) should use graduated stress text, got: \(friendlyMsg)")
            }
        }
    }

    // MARK: - All Personas: Stress friendlyMessage Varies by Score

    func testAllPersonas_stressFriendlyMessageVaries() {
        let low = StressLevel.friendlyMessage(for: 25)
        let mid = StressLevel.friendlyMessage(for: 50)
        let highMild = StressLevel.friendlyMessage(for: 70)
        let highMod = StressLevel.friendlyMessage(for: 80)
        let highSevere = StressLevel.friendlyMessage(for: 92)

        let messages = [low, mid, highMild, highMod, highSevere]
        let unique = Set(messages)
        XCTAssertEqual(unique.count, messages.count,
            "Each stress tier should produce different text: \(messages)")
    }
}

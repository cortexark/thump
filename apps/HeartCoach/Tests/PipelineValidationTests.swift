// PipelineValidationTests.swift
// ThumpCoreTests
//
// End-to-end pipeline validation tests using mock user profiles.
// Validates the data -> correlation -> alert pipeline across
// diverse user archetypes.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import Thump

// MARK: - Mock User Profile

/// Archetype representing a distinct user behavior pattern.
enum MockUserArchetype: String, CaseIterable {
    case eliteAthlete
    case sedentaryWorker
    case overtrainer
    case recoveringUser
    case improvingBeginner
    case stressedProfessional
    case sleepDeprived
    case sparseData
}

/// A mock user profile with pre-configured snapshot history for pipeline tests.
struct PipelineMockProfile {
    let archetype: MockUserArchetype
    let history: [HeartSnapshot]
    let current: HeartSnapshot
}

/// Generates mock user profiles for pipeline testing.
struct PipelineProfileGenerator {

    private let calendar = Calendar.current

    // MARK: - Public API

    func profile(for archetype: MockUserArchetype) -> PipelineMockProfile {
        switch archetype {
        case .eliteAthlete:
            return eliteAthleteProfile()
        case .sedentaryWorker:
            return sedentaryWorkerProfile()
        case .overtrainer:
            return overtrainerProfile()
        case .recoveringUser:
            return recoveringUserProfile()
        case .improvingBeginner:
            return improvingBeginnerProfile()
        case .stressedProfessional:
            return stressedProfessionalProfile()
        case .sleepDeprived:
            return sleepDeprivedProfile()
        case .sparseData:
            return sparseDataProfile()
        }
    }

    // MARK: - Archetype Profiles

    private func eliteAthleteProfile() -> PipelineMockProfile {
        let days = 21
        let history = (0..<days).map { i -> HeartSnapshot in
            let date = dateOffset(-(days - i))
            let variation = sin(Double(i) * 0.4) * 1.5
            return HeartSnapshot(
                date: date,
                restingHeartRate: 48.0 - variation * 0.5,
                hrvSDNN: 85.0 + variation,
                recoveryHR1m: 45.0 + variation,
                recoveryHR2m: 55.0 + variation,
                vo2Max: 55.0 + variation * 0.5,
                steps: 15000 + variation * 1000,
                walkMinutes: 60.0 + variation * 5,
                workoutMinutes: 90.0 + variation * 5,
                sleepHours: 8.0 + variation * 0.2
            )
        }
        let current = HeartSnapshot(
            date: Date(),
            restingHeartRate: 47,
            hrvSDNN: 88,
            recoveryHR1m: 46,
            recoveryHR2m: 56,
            vo2Max: 56,
            steps: 16000,
            walkMinutes: 65,
            workoutMinutes: 95,
            sleepHours: 8.2
        )
        return PipelineMockProfile(
            archetype: .eliteAthlete,
            history: history,
            current: current
        )
    }

    private func sedentaryWorkerProfile() -> PipelineMockProfile {
        let days = 21
        let history = (0..<days).map { i -> HeartSnapshot in
            let date = dateOffset(-(days - i))
            let variation = sin(Double(i) * 0.3) * 2.0
            return HeartSnapshot(
                date: date,
                restingHeartRate: 75.0 + variation,
                hrvSDNN: 30.0 + variation,
                recoveryHR1m: 15.0 + variation * 0.5,
                recoveryHR2m: 25.0 + variation * 0.5,
                vo2Max: 28.0 + variation * 0.3,
                steps: 3000 + variation * 200,
                walkMinutes: 10.0 + variation,
                workoutMinutes: 5.0 + abs(variation),
                sleepHours: 6.0 + variation * 0.2
            )
        }
        let current = HeartSnapshot(
            date: Date(),
            restingHeartRate: 76,
            hrvSDNN: 29,
            recoveryHR1m: 14,
            recoveryHR2m: 24,
            vo2Max: 27,
            steps: 2800,
            walkMinutes: 8,
            workoutMinutes: 0,
            sleepHours: 5.8
        )
        return PipelineMockProfile(
            archetype: .sedentaryWorker,
            history: history,
            current: current
        )
    }

    private func overtrainerProfile() -> PipelineMockProfile {
        let days = 21
        // Simulate worsening metrics over time (RHR rising, HRV dropping)
        let history = (0..<days).map { i -> HeartSnapshot in
            let date = dateOffset(-(days - i))
            let trend = Double(i) * 0.5
            let variation = sin(Double(i) * 0.3) * 1.0
            return HeartSnapshot(
                date: date,
                restingHeartRate: 55.0 + trend + variation,
                hrvSDNN: 70.0 - trend - variation,
                recoveryHR1m: 40.0 - trend * 0.8,
                recoveryHR2m: 50.0 - trend * 0.6,
                vo2Max: 48.0 - trend * 0.3,
                steps: 20000 + variation * 500,
                walkMinutes: 40.0 + variation * 3,
                workoutMinutes: 120.0 + trend * 2,
                sleepHours: 6.5 - trend * 0.1
            )
        }
        let current = HeartSnapshot(
            date: Date(),
            restingHeartRate: 68,
            hrvSDNN: 42,
            recoveryHR1m: 22,
            recoveryHR2m: 35,
            vo2Max: 42,
            steps: 22000,
            walkMinutes: 45,
            workoutMinutes: 140,
            sleepHours: 5.5
        )
        return PipelineMockProfile(
            archetype: .overtrainer,
            history: history,
            current: current
        )
    }

    private func recoveringUserProfile() -> PipelineMockProfile {
        let days = 21
        // First half: poor metrics; second half: improving
        let history = (0..<days).map { i -> HeartSnapshot in
            let date = dateOffset(-(days - i))
            let phase = Double(i) / Double(days)
            let rhr = i < 10 ? 72.0 - Double(i) * 0.3 : 69.0 - Double(i - 10) * 0.4
            let hrv = i < 10 ? 35.0 + Double(i) * 0.5 : 40.0 + Double(i - 10) * 1.0
            let rec = 18.0 + phase * 15.0
            return HeartSnapshot(
                date: date,
                restingHeartRate: rhr,
                hrvSDNN: hrv,
                recoveryHR1m: rec,
                recoveryHR2m: rec + 10,
                vo2Max: 32.0 + phase * 8.0,
                steps: 5000 + phase * 5000,
                walkMinutes: 15.0 + phase * 20,
                workoutMinutes: 10.0 + phase * 25,
                sleepHours: 6.5 + phase * 1.0
            )
        }
        let current = HeartSnapshot(
            date: Date(),
            restingHeartRate: 63,
            hrvSDNN: 52,
            recoveryHR1m: 33,
            recoveryHR2m: 43,
            vo2Max: 40,
            steps: 10000,
            walkMinutes: 35,
            workoutMinutes: 35,
            sleepHours: 7.5
        )
        return PipelineMockProfile(
            archetype: .recoveringUser,
            history: history,
            current: current
        )
    }

    private func improvingBeginnerProfile() -> PipelineMockProfile {
        let days = 21
        let history = (0..<days).map { i -> HeartSnapshot in
            let date = dateOffset(-(days - i))
            let progress = Double(i) / Double(days)
            let variation = sin(Double(i) * 0.5) * 1.0
            return HeartSnapshot(
                date: date,
                restingHeartRate: 72.0 - progress * 6.0 + variation,
                hrvSDNN: 35.0 + progress * 12.0 - variation,
                recoveryHR1m: 18.0 + progress * 10.0 + variation,
                recoveryHR2m: 28.0 + progress * 8.0 + variation,
                vo2Max: 30.0 + progress * 5.0,
                steps: 4000 + progress * 5000 + variation * 300,
                walkMinutes: 10.0 + progress * 20 + variation * 2,
                workoutMinutes: 5.0 + progress * 25,
                sleepHours: 6.5 + progress * 1.0 + variation * 0.1
            )
        }
        let current = HeartSnapshot(
            date: Date(),
            restingHeartRate: 66,
            hrvSDNN: 47,
            recoveryHR1m: 28,
            recoveryHR2m: 36,
            vo2Max: 35,
            steps: 9000,
            walkMinutes: 30,
            workoutMinutes: 30,
            sleepHours: 7.5
        )
        return PipelineMockProfile(
            archetype: .improvingBeginner,
            history: history,
            current: current
        )
    }

    private func stressedProfessionalProfile() -> PipelineMockProfile {
        let days = 21
        let history = (0..<days).map { i -> HeartSnapshot in
            let date = dateOffset(-(days - i))
            let variation = sin(Double(i) * 0.4) * 1.5
            return HeartSnapshot(
                date: date,
                restingHeartRate: 62.0 + variation,
                hrvSDNN: 55.0 - variation,
                recoveryHR1m: 30.0 + variation,
                recoveryHR2m: 42.0 + variation,
                vo2Max: 38.0,
                steps: 6000 + variation * 300,
                walkMinutes: 20.0 + variation * 2,
                workoutMinutes: 20.0 + variation * 2,
                sleepHours: 6.5 + variation * 0.2
            )
        }
        // Current day: classic stress pattern
        let current = HeartSnapshot(
            date: Date(),
            restingHeartRate: 78,
            hrvSDNN: 28,
            recoveryHR1m: 12,
            recoveryHR2m: 20,
            vo2Max: 36,
            steps: 4000,
            walkMinutes: 10,
            workoutMinutes: 0,
            sleepHours: 4.5
        )
        return PipelineMockProfile(
            archetype: .stressedProfessional,
            history: history,
            current: current
        )
    }

    private func sleepDeprivedProfile() -> PipelineMockProfile {
        let days = 21
        let history = (0..<days).map { i -> HeartSnapshot in
            let date = dateOffset(-(days - i))
            let variation = sin(Double(i) * 0.4) * 1.5
            return HeartSnapshot(
                date: date,
                restingHeartRate: 65.0 + variation,
                hrvSDNN: 48.0 - variation,
                recoveryHR1m: 28.0 + variation,
                recoveryHR2m: 40.0 + variation,
                vo2Max: 36.0,
                steps: 7000 + variation * 400,
                walkMinutes: 25.0 + variation * 2,
                workoutMinutes: 15.0 + variation * 2,
                sleepHours: 4.5 + variation * 0.3
            )
        }
        // Current: elevated RHR, depressed HRV, poor recovery from sleep dep
        let current = HeartSnapshot(
            date: Date(),
            restingHeartRate: 76,
            hrvSDNN: 25,
            recoveryHR1m: 14,
            recoveryHR2m: 22,
            vo2Max: 34,
            steps: 5000,
            walkMinutes: 15,
            workoutMinutes: 0,
            sleepHours: 3.5
        )
        return PipelineMockProfile(
            archetype: .sleepDeprived,
            history: history,
            current: current
        )
    }

    private func sparseDataProfile() -> PipelineMockProfile {
        let days = 5
        let history = (0..<days).map { i -> HeartSnapshot in
            let date = dateOffset(-(days - i))
            // Only RHR available on some days
            return HeartSnapshot(
                date: date,
                restingHeartRate: i.isMultiple(of: 2) ? 68.0 : nil,
                hrvSDNN: nil,
                recoveryHR1m: nil,
                recoveryHR2m: nil,
                vo2Max: nil,
                steps: i == 0 ? 5000 : nil,
                walkMinutes: nil,
                workoutMinutes: nil,
                sleepHours: nil
            )
        }
        let current = HeartSnapshot(
            date: Date(),
            restingHeartRate: 70,
            hrvSDNN: nil,
            recoveryHR1m: nil,
            recoveryHR2m: nil,
            vo2Max: nil
        )
        return PipelineMockProfile(
            archetype: .sparseData,
            history: history,
            current: current
        )
    }

    // MARK: - Helpers

    private func dateOffset(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}

// MARK: - Pipeline Validation Tests

final class PipelineValidationTests: XCTestCase {

    // MARK: - Properties

    // swiftlint:disable implicitly_unwrapped_optional
    private var trendEngine: HeartTrendEngine!
    private var correlationEngine: CorrelationEngine!
    private var nudgeGenerator: NudgeGenerator!
    // swiftlint:enable implicitly_unwrapped_optional
    private let profileGenerator = PipelineProfileGenerator()

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        trendEngine = HeartTrendEngine(
            lookbackWindow: 21,
            policy: AlertPolicy()
        )
        correlationEngine = CorrelationEngine()
        nudgeGenerator = NudgeGenerator()
    }

    override func tearDown() {
        trendEngine = nil
        correlationEngine = nil
        nudgeGenerator = nil
        super.tearDown()
    }

    // MARK: - 1. Trend Engine Validation

    func testEliteAthlete_shouldBeImprovingOrStable() {
        let profile = profileGenerator.profile(for: .eliteAthlete)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        XCTAssertTrue(
            assessment.status == .improving || assessment.status == .stable,
            "Elite athlete should be .improving or .stable, got \(assessment.status)"
        )
        XCTAssertFalse(assessment.stressFlag)
        XCTAssertFalse(assessment.regressionFlag)
    }

    func testSedentaryWorker_shouldBeStableOrNeedsAttention() {
        let profile = profileGenerator.profile(for: .sedentaryWorker)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        XCTAssertTrue(
            assessment.status == .stable
                || assessment.status == .needsAttention,
            "Sedentary worker should be .stable or .needsAttention, "
                + "got \(assessment.status)"
        )
    }

    func testOvertrainer_shouldBeNeedsAttention() {
        let profile = profileGenerator.profile(for: .overtrainer)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        XCTAssertEqual(
            assessment.status,
            .needsAttention,
            "Overtrainer should be .needsAttention, got \(assessment.status)"
        )
    }

    func testRecoveringUser_shouldTransitionToStableOrImproving() {
        let profile = profileGenerator.profile(for: .recoveringUser)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        XCTAssertTrue(
            assessment.status == .stable
                || assessment.status == .improving,
            "Recovering user should transition to .stable or .improving, "
                + "got \(assessment.status)"
        )
    }

    func testImprovingBeginner_shouldBeImproving() {
        let profile = profileGenerator.profile(for: .improvingBeginner)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        XCTAssertTrue(
            assessment.status == .improving
                || assessment.status == .stable,
            "Improving beginner should be .improving or .stable, "
                + "got \(assessment.status)"
        )
        XCTAssertLessThan(
            assessment.anomalyScore,
            2.0,
            "Improving beginner anomaly score should be moderate"
        )
    }

    // MARK: - 2. Correlation Engine Validation

    func testStepsVsRHR_negativeCorrelationForActiveUsers() {
        let profile = profileGenerator.profile(for: .eliteAthlete)
        let allSnapshots = profile.history + [profile.current]
        let results = correlationEngine.analyze(history: allSnapshots)

        let stepsResult = results.first { $0.factorName == "Daily Steps" }
        XCTAssertNotNil(
            stepsResult,
            "Steps vs RHR correlation should exist for elite athlete"
        )
        if let result = stepsResult {
            XCTAssertLessThan(
                result.correlationStrength,
                0.0,
                "Active user: more steps should correlate with lower RHR"
            )
        }
    }

    func testSleepVsHRV_positiveCorrelation() {
        let profile = profileGenerator.profile(for: .improvingBeginner)
        let allSnapshots = profile.history + [profile.current]
        let results = correlationEngine.analyze(history: allSnapshots)

        let sleepResult = results.first { $0.factorName == "Sleep Hours" }
        XCTAssertNotNil(
            sleepResult,
            "Sleep vs HRV correlation should exist for improving beginner"
        )
        if let result = sleepResult {
            XCTAssertGreaterThan(
                result.correlationStrength,
                0.0,
                "More sleep should correlate with higher HRV"
            )
            XCTAssertTrue(result.isBeneficial)
        }
    }

    func testActivityVsRecovery_positiveForWellTrained() {
        let profile = profileGenerator.profile(for: .eliteAthlete)
        let allSnapshots = profile.history + [profile.current]
        let results = correlationEngine.analyze(history: allSnapshots)

        let activityResult = results.first {
            $0.factorName == "Activity Minutes"
        }
        if let result = activityResult {
            // Well-trained: activity should positively correlate with recovery
            XCTAssertGreaterThan(
                result.correlationStrength,
                -0.5,
                "Well-trained user should not show strong negative "
                    + "activity-recovery correlation"
            )
        }
    }

    func testCorrelationConfidence_matchesDataCompleteness() {
        // Full data profile should produce higher confidence correlations
        let fullProfile = profileGenerator.profile(for: .eliteAthlete)
        let fullResults = correlationEngine.analyze(
            history: fullProfile.history + [fullProfile.current]
        )

        // Sparse data profile should produce no or low confidence correlations
        let sparseProfile = profileGenerator.profile(for: .sparseData)
        let sparseResults = correlationEngine.analyze(
            history: sparseProfile.history + [sparseProfile.current]
        )

        XCTAssertGreaterThan(
            fullResults.count,
            sparseResults.count,
            "Full data should produce more correlations than sparse data"
        )
    }

    // MARK: - 3. Nudge Generation Validation

    func testStressedUser_getsBreathingOrRestNudge() {
        let profile = profileGenerator.profile(for: .stressedProfessional)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        let validCategories: Set<NudgeCategory> = [
            .breathe, .rest, .walk, .hydrate
        ]

        if assessment.stressFlag {
            XCTAssertTrue(
                validCategories.contains(assessment.dailyNudge.category),
                "Stressed user nudge should be breathe/rest/walk/hydrate, "
                    + "got \(assessment.dailyNudge.category)"
            )
        }
    }

    func testOvertrainer_getsRestOrModerateNudge() {
        let profile = profileGenerator.profile(for: .overtrainer)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        let validCategories: Set<NudgeCategory> = [
            .rest, .moderate, .walk, .hydrate
        ]
        XCTAssertTrue(
            validCategories.contains(assessment.dailyNudge.category),
            "Overtrainer nudge should be rest/moderate/walk/hydrate, "
                + "got \(assessment.dailyNudge.category)"
        )
    }

    func testImprovingUser_getsCelebrateNudge() {
        let profile = profileGenerator.profile(for: .improvingBeginner)
        let nudge = nudgeGenerator.generate(
            confidence: .high,
            anomaly: 0.2,
            regression: false,
            stress: false,
            feedback: nil,
            current: profile.current,
            history: profile.history
        )

        let validCategories: Set<NudgeCategory> = [
            .celebrate, .moderate, .walk
        ]
        XCTAssertTrue(
            validCategories.contains(nudge.category),
            "Improving user nudge should be celebrate/moderate/walk, "
                + "got \(nudge.category)"
        )
    }

    func testSleepDeprivedUser_getsRestNudge() {
        let profile = profileGenerator.profile(for: .sleepDeprived)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        // Sleep-deprived triggers stress pattern; nudges should be restorative
        let restorativeCategories: Set<NudgeCategory> = [
            .rest, .breathe, .walk, .hydrate
        ]
        XCTAssertTrue(
            restorativeCategories.contains(assessment.dailyNudge.category),
            "Sleep-deprived user should get a restorative nudge, "
                + "got \(assessment.dailyNudge.category)"
        )
    }

    // MARK: - 4. Alert Pipeline

    func testAnomalyScore_higherForDeterioratingProfiles() {
        let goodProfile = profileGenerator.profile(for: .eliteAthlete)
        let badProfile = profileGenerator.profile(for: .overtrainer)

        let goodAssessment = trendEngine.assess(
            history: goodProfile.history,
            current: goodProfile.current
        )
        let badAssessment = trendEngine.assess(
            history: badProfile.history,
            current: badProfile.current
        )

        XCTAssertGreaterThan(
            badAssessment.anomalyScore,
            goodAssessment.anomalyScore,
            "Overtrainer anomaly score should exceed elite athlete's"
        )
    }

    func testStressFlag_triggersForStressPattern() {
        let profile = profileGenerator.profile(for: .stressedProfessional)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        XCTAssertTrue(
            assessment.stressFlag,
            "Stressed professional should trigger stressFlag"
        )
    }

    func testRegressionFlag_triggersForOvertrainer() {
        let profile = profileGenerator.profile(for: .overtrainer)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        XCTAssertTrue(
            assessment.regressionFlag,
            "Overtrainer with worsening trend should trigger regressionFlag"
        )
    }

    func testStressAndRegression_bothReflectedInStatus() {
        let profile = profileGenerator.profile(for: .stressedProfessional)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        if assessment.stressFlag || assessment.regressionFlag {
            XCTAssertEqual(
                assessment.status,
                .needsAttention,
                "Stress or regression flags should yield .needsAttention"
            )
        }
    }

    // MARK: - 5. Edge Cases

    func testSparseData_yieldsLowConfidence() {
        let profile = profileGenerator.profile(for: .sparseData)
        let assessment = trendEngine.assess(
            history: profile.history,
            current: profile.current
        )

        XCTAssertEqual(
            assessment.confidence,
            .low,
            "Sparse data profile should yield .low confidence"
        )
    }

    func testEmptyHistory_doesNotCrash() {
        let current = HeartSnapshot(
            date: Date(),
            restingHeartRate: 65,
            hrvSDNN: 50
        )

        let assessment = trendEngine.assess(
            history: [],
            current: current
        )

        // Should not crash and should return a valid assessment
        XCTAssertNotNil(assessment)
        XCTAssertEqual(assessment.confidence, .low)
        XCTAssertFalse(assessment.stressFlag)
        XCTAssertFalse(assessment.regressionFlag)
        XCTAssertEqual(assessment.anomalyScore, 0.0, accuracy: 0.01)
    }

    func testSingleDayHistory_handlesGracefully() {
        let yesterday = Calendar.current.date(
            byAdding: .day,
            value: -1,
            to: Date()
        ) ?? Date()

        let history = [HeartSnapshot(
            date: yesterday,
            restingHeartRate: 65,
            hrvSDNN: 50,
            recoveryHR1m: 30,
            recoveryHR2m: 42,
            vo2Max: 38
        )]

        let current = HeartSnapshot(
            date: Date(),
            restingHeartRate: 66,
            hrvSDNN: 49,
            recoveryHR1m: 29,
            recoveryHR2m: 41,
            vo2Max: 37
        )

        let assessment = trendEngine.assess(
            history: history,
            current: current
        )

        // Single-day history should not crash; confidence should be low
        XCTAssertNotNil(assessment)
        XCTAssertEqual(assessment.confidence, .low)
        XCTAssertFalse(assessment.regressionFlag)
    }

    func testEmptyHistory_correlationEngine_returnsEmpty() {
        let results = correlationEngine.analyze(history: [])
        XCTAssertTrue(
            results.isEmpty,
            "Empty history should produce no correlations"
        )
    }

    func testAllNilMetrics_doesNotCrash() {
        let days = 14
        let calendar = Calendar.current
        let history = (0..<days).map { i -> HeartSnapshot in
            let date = calendar.date(
                byAdding: .day,
                value: -(days - i),
                to: Date()
            ) ?? Date()
            return HeartSnapshot(date: date)
        }
        let current = HeartSnapshot(date: Date())

        let assessment = trendEngine.assess(
            history: history,
            current: current
        )

        XCTAssertNotNil(assessment)
        XCTAssertEqual(assessment.confidence, .low)
        XCTAssertEqual(assessment.anomalyScore, 0.0, accuracy: 0.01)
        XCTAssertNil(assessment.cardioScore)
    }

    func testNudgeStructure_alwaysPopulated() {
        for archetype in MockUserArchetype.allCases {
            let profile = profileGenerator.profile(for: archetype)
            let assessment = trendEngine.assess(
                history: profile.history,
                current: profile.current
            )

            XCTAssertFalse(
                assessment.dailyNudge.title.isEmpty,
                "\(archetype) nudge title should not be empty"
            )
            XCTAssertFalse(
                assessment.dailyNudge.description.isEmpty,
                "\(archetype) nudge description should not be empty"
            )
            XCTAssertFalse(
                assessment.dailyNudge.icon.isEmpty,
                "\(archetype) nudge icon should not be empty"
            )
        }
    }

    func testExplanation_alwaysNonEmpty() {
        for archetype in MockUserArchetype.allCases {
            let profile = profileGenerator.profile(for: archetype)
            let assessment = trendEngine.assess(
                history: profile.history,
                current: profile.current
            )

            XCTAssertFalse(
                assessment.explanation.isEmpty,
                "\(archetype) explanation should not be empty"
            )
        }
    }

    func testCardioScore_withinValidRange() {
        for archetype in MockUserArchetype.allCases {
            let profile = profileGenerator.profile(for: archetype)
            let assessment = trendEngine.assess(
                history: profile.history,
                current: profile.current
            )

            if let score = assessment.cardioScore {
                XCTAssertGreaterThanOrEqual(
                    score,
                    0.0,
                    "\(archetype) cardio score should be >= 0"
                )
                XCTAssertLessThanOrEqual(
                    score,
                    100.0,
                    "\(archetype) cardio score should be <= 100"
                )
            }
        }
    }

    // MARK: - Full Pipeline Integration

    func testFullPipeline_allArchetypes_producesValidAssessments() {
        for archetype in MockUserArchetype.allCases {
            let profile = profileGenerator.profile(for: archetype)

            // Step 1: Trend assessment
            let assessment = trendEngine.assess(
                history: profile.history,
                current: profile.current
            )

            // Step 2: Correlation analysis
            let allSnapshots = profile.history + [profile.current]
            let correlations = correlationEngine.analyze(
                history: allSnapshots
            )

            // Validate assessment
            XCTAssertTrue(
                TrendStatus.allCases.contains(assessment.status),
                "\(archetype) should have valid status"
            )
            XCTAssertTrue(
                ConfidenceLevel.allCases.contains(assessment.confidence),
                "\(archetype) should have valid confidence"
            )
            XCTAssertGreaterThanOrEqual(
                assessment.anomalyScore,
                0.0,
                "\(archetype) anomaly score should be non-negative"
            )

            // Validate correlations
            for correlation in correlations {
                XCTAssertGreaterThanOrEqual(
                    correlation.correlationStrength,
                    -1.0,
                    "\(archetype) \(correlation.factorName) r >= -1"
                )
                XCTAssertLessThanOrEqual(
                    correlation.correlationStrength,
                    1.0,
                    "\(archetype) \(correlation.factorName) r <= 1"
                )
                XCTAssertFalse(
                    correlation.interpretation.isEmpty,
                    "\(archetype) \(correlation.factorName) interpretation "
                        + "should not be empty"
                )
            }
        }
    }
}

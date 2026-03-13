// BioAgeEngineTests.swift
// HeartCoach Tests
//
// Comprehensive unit tests for BioAgeEngine covering:
// - Age-stratified norms
// - Sex-stratified norms (male/female/notSet)
// - Weight/BMI contribution
// - Edge cases and boundary conditions
// - Metric combination scenarios

import XCTest
@testable import Thump

final class BioAgeEngineTests: XCTestCase {

    let engine = BioAgeEngine()

    // MARK: - Nil / Insufficient Data

    func testReturnsNil_whenChronologicalAgeIsZero() {
        let snapshot = makeSnapshot(rhr: 65, hrv: 50)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 0)
        XCTAssertNil(result)
    }

    func testReturnsNil_whenChronologicalAgeIsNegative() {
        let snapshot = makeSnapshot(rhr: 65, hrv: 50)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: -5)
        XCTAssertNil(result)
    }

    func testReturnsNil_whenOnlyOneMetricAvailable() {
        let snapshot = makeSnapshot(rhr: 65)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNil(result, "Should require at least 2 metrics")
    }

    func testReturnsNil_whenEmptySnapshot() {
        let snapshot = HeartSnapshot(date: Date())
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNil(result)
    }

    // MARK: - Basic Estimation

    func testReturnsResult_whenTwoMetricsAvailable() {
        let snapshot = makeSnapshot(rhr: 65, hrv: 50)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNotNil(result)
    }

    func testReturnsResult_whenAllSixMetricsAvailable() {
        let snapshot = makeSnapshot(
            rhr: 62, hrv: 55, vo2: 42, sleep: 7.5,
            walkMin: 30, workoutMin: 20, weight: 75
        )
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.metricsUsed, 6)
    }

    func testBioAge_neverBelowMinimum() {
        // Excellent metrics for a young person
        let snapshot = makeSnapshot(rhr: 50, hrv: 80, vo2: 55, sleep: 8, walkMin: 60, workoutMin: 30)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 20)
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.bioAge, 16, "Bio age floor is 16")
    }

    // MARK: - Category Classification

    func testCategory_excellent_whenMuchYounger() {
        // Elite athlete metrics at age 45
        let snapshot = makeSnapshot(rhr: 52, hrv: 65, vo2: 50, sleep: 8, walkMin: 45, workoutMin: 30)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 45)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.difference <= -5, "Should be 5+ years younger: \(result!.difference)")
        XCTAssertEqual(result!.category, .excellent)
    }

    func testCategory_needsWork_whenMuchOlder() {
        // Poor metrics for a 30 year old
        let snapshot = makeSnapshot(rhr: 90, hrv: 18, vo2: 20, sleep: 4, walkMin: 5, workoutMin: 0, weight: 110)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 30)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.difference >= 5, "Should be 5+ years older: \(result!.difference)")
        XCTAssertEqual(result!.category, .needsWork)
    }

    func testCategory_onTrack_whenAverageMetrics() {
        // Average 35yo metrics
        let snapshot = makeSnapshot(rhr: 70, hrv: 44, vo2: 37, sleep: 7.5, walkMin: 20, workoutMin: 10)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNotNil(result)
        XCTAssertTrue(abs(result!.difference) <= 2, "Should be on track: \(result!.difference)")
        XCTAssertEqual(result!.category, .onTrack)
    }

    // MARK: - Sex Stratification

    func testMale_hasHigherExpectedVO2() {
        // Same snapshot, same age — male norms expect higher VO2 so same value = less impressive
        let snapshot = makeSnapshot(rhr: 65, hrv: 45, vo2: 40)
        let maleResult = engine.estimate(snapshot: snapshot, chronologicalAge: 35, sex: .male)
        let femaleResult = engine.estimate(snapshot: snapshot, chronologicalAge: 35, sex: .female)
        XCTAssertNotNil(maleResult)
        XCTAssertNotNil(femaleResult)
        // Female with VO2 40 exceeds female norms more → younger bio age
        XCTAssertGreaterThan(maleResult!.bioAge, femaleResult!.bioAge,
            "Male bio age should be higher (worse) for same VO2 since male norms are higher")
    }

    func testFemale_hasHigherExpectedRHR() {
        // Same RHR — females have higher expected RHR so same value = more impressive
        let snapshot = makeSnapshot(rhr: 72, hrv: 40)
        let maleResult = engine.estimate(snapshot: snapshot, chronologicalAge: 40, sex: .male)
        let femaleResult = engine.estimate(snapshot: snapshot, chronologicalAge: 40, sex: .female)
        XCTAssertNotNil(maleResult)
        XCTAssertNotNil(femaleResult)
        // RHR 72 for female (expected ~71.5) is nearly on track
        // RHR 72 for male (expected ~68.5) is above expected → aging
        XCTAssertGreaterThan(maleResult!.bioAge, femaleResult!.bioAge)
    }

    func testNotSet_usesAveragedNorms() {
        let snapshot = makeSnapshot(rhr: 65, hrv: 50, vo2: 38)
        let notSetResult = engine.estimate(snapshot: snapshot, chronologicalAge: 35, sex: .notSet)
        let maleResult = engine.estimate(snapshot: snapshot, chronologicalAge: 35, sex: .male)
        let femaleResult = engine.estimate(snapshot: snapshot, chronologicalAge: 35, sex: .female)
        XCTAssertNotNil(notSetResult)
        // notSet result should fall between male and female
        let notSetAge = notSetResult!.bioAge
        let maleAge = maleResult!.bioAge
        let femaleAge = femaleResult!.bioAge
        let minAge = min(maleAge, femaleAge)
        let maxAge = max(maleAge, femaleAge)
        // Allow ±1 year tolerance for rounding
        XCTAssertTrue(notSetAge >= minAge - 1 && notSetAge <= maxAge + 1,
            "NotSet (\(notSetAge)) should be between male (\(maleAge)) and female (\(femaleAge))")
    }

    // MARK: - BMI / Weight Contribution

    func testBMI_optimalWeight_noAgePenalty() {
        // ~70 kg at average height ~1.70m → BMI ~24.2, close to optimal 23.5
        let snapshot = makeSnapshot(rhr: 70, hrv: 44, weight: 68)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNotNil(result)
        let bmiContribution = result!.breakdown.first(where: { $0.metric == .bmi })
        XCTAssertNotNil(bmiContribution)
        // Optimal BMI → onTrack direction
        XCTAssertEqual(bmiContribution!.direction, .onTrack)
    }

    func testBMI_overweight_addsAgePenalty() {
        // 100 kg at average height → BMI ~34.6, well above optimal
        let snapshot = makeSnapshot(rhr: 70, hrv: 44, weight: 100)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNotNil(result)
        let bmiContribution = result!.breakdown.first(where: { $0.metric == .bmi })
        XCTAssertNotNil(bmiContribution)
        XCTAssertEqual(bmiContribution!.direction, .older)
        XCTAssertGreaterThan(bmiContribution!.ageOffset, 0)
    }

    func testBMI_sexStratified_heightDifference() {
        // Same weight, different sex → different estimated BMI
        let snapshot = makeSnapshot(rhr: 65, hrv: 50, weight: 75)
        let maleResult = engine.estimate(snapshot: snapshot, chronologicalAge: 35, sex: .male)
        let femaleResult = engine.estimate(snapshot: snapshot, chronologicalAge: 35, sex: .female)
        let maleBMI = maleResult?.breakdown.first(where: { $0.metric == .bmi })
        let femaleBMI = femaleResult?.breakdown.first(where: { $0.metric == .bmi })
        XCTAssertNotNil(maleBMI)
        XCTAssertNotNil(femaleBMI)
        // 75 kg / 3.06 (male) = BMI 24.5 → closer to optimal
        // 75 kg / 2.62 (female) = BMI 28.6 → further from optimal
        XCTAssertGreaterThan(femaleBMI!.ageOffset, maleBMI!.ageOffset,
            "Female BMI offset should be larger for same weight (shorter avg height)")
    }

    // MARK: - Age Band Transitions

    func testAgeBands_youngerExpectsMoreVO2() {
        let snapshot = makeSnapshot(rhr: 65, vo2: 35)
        let young = engine.estimate(snapshot: snapshot, chronologicalAge: 22)
        let middle = engine.estimate(snapshot: snapshot, chronologicalAge: 50)
        XCTAssertNotNil(young)
        XCTAssertNotNil(middle)
        // VO2 35 for a 22yo (expected ~42) is below → older bio age
        // VO2 35 for a 50yo (expected ~34) is above → younger bio age
        let youngVO2 = young!.breakdown.first(where: { $0.metric == .vo2Max })
        let middleVO2 = middle!.breakdown.first(where: { $0.metric == .vo2Max })
        XCTAssertEqual(youngVO2!.direction, .older)
        XCTAssertEqual(middleVO2!.direction, .younger)
    }

    func testElderlyProfile_75yo() {
        // Reasonable 75yo metrics
        let snapshot = makeSnapshot(rhr: 72, hrv: 28, vo2: 24, sleep: 7, walkMin: 15, workoutMin: 5)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 75)
        XCTAssertNotNil(result)
        // Should be roughly on track for age
        XCTAssertTrue(abs(result!.difference) <= 4, "75yo with age-appropriate metrics: \(result!.difference)")
    }

    // MARK: - Sleep Metric

    func testSleep_optimalZone_noPenalty() {
        let snapshot = makeSnapshot(rhr: 65, hrv: 44, sleep: 7.5)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNotNil(result, "Should have enough metrics (rhr + hrv + sleep)")
        let sleepContrib = result?.breakdown.first(where: { $0.metric == .sleep })
        XCTAssertNotNil(sleepContrib)
        XCTAssertEqual(sleepContrib!.direction, .onTrack)
    }

    func testSleep_tooShort_addsPenalty() {
        let snapshot = makeSnapshot(rhr: 65, hrv: 44, sleep: 4.5)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNotNil(result, "Should have enough metrics (rhr + hrv + sleep)")
        let sleepContrib = result?.breakdown.first(where: { $0.metric == .sleep })
        XCTAssertNotNil(sleepContrib)
        XCTAssertEqual(sleepContrib!.direction, .older)
        XCTAssertGreaterThan(sleepContrib!.ageOffset, 0)
    }

    func testSleep_tooLong_addsPenalty() {
        let snapshot = makeSnapshot(rhr: 65, hrv: 44, sleep: 11)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNotNil(result, "Should have enough metrics (rhr + hrv + sleep)")
        let sleepContrib = result?.breakdown.first(where: { $0.metric == .sleep })
        XCTAssertNotNil(sleepContrib)
        XCTAssertEqual(sleepContrib!.direction, .older)
    }

    // MARK: - Explanation Text

    func testExplanation_containsMetricReference() {
        let snapshot = makeSnapshot(rhr: 52, hrv: 65, vo2: 50, sleep: 8, walkMin: 45, workoutMin: 30)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 45)
        XCTAssertNotNil(result)
        XCTAssertFalse(result!.explanation.isEmpty)
        // Explanation should mention at least one metric
        let mentionsMetric = result!.explanation.lowercased().contains("heart rate") ||
            result!.explanation.lowercased().contains("cardio") ||
            result!.explanation.lowercased().contains("variability") ||
            result!.explanation.lowercased().contains("sleep") ||
            result!.explanation.lowercased().contains("activity") ||
            result!.explanation.lowercased().contains("body")
        XCTAssertTrue(mentionsMetric, "Explanation should mention a metric: \(result!.explanation)")
    }

    // MARK: - Clamping

    func testMaxOffset_clampedAt8Years() {
        // Extremely poor VO2 for a 25yo — shouldn't offset more than 8 years for that metric
        let snapshot = makeSnapshot(rhr: 65, vo2: 10)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 25)
        XCTAssertNotNil(result)
        let vo2Contrib = result!.breakdown.first(where: { $0.metric == .vo2Max })
        XCTAssertNotNil(vo2Contrib)
        XCTAssertLessThanOrEqual(vo2Contrib!.ageOffset, 8.0, "Per-metric offset capped at 8 years")
    }

    // MARK: - History-Based Estimation

    func testEstimate_fromHistory_usesLatestSnapshot() {
        let oldSnapshot = makeSnapshot(rhr: 80, hrv: 25, date: Date().addingTimeInterval(-86400 * 7))
        let newSnapshot = makeSnapshot(rhr: 60, hrv: 55, date: Date())
        let result = engine.estimate(
            history: [oldSnapshot, newSnapshot],
            chronologicalAge: 35,
            sex: .notSet
        )
        XCTAssertNotNil(result)
        // Should use the new (better) snapshot → younger bio age
        XCTAssertLessThan(result!.bioAge, 35)
    }

    func testEstimate_fromEmptyHistory_returnsNil() {
        let result = engine.estimate(history: [], chronologicalAge: 35)
        XCTAssertNil(result)
    }

    // MARK: - Helpers

    private func makeSnapshot(
        rhr: Double? = nil,
        hrv: Double? = nil,
        vo2: Double? = nil,
        sleep: Double? = nil,
        walkMin: Double? = nil,
        workoutMin: Double? = nil,
        weight: Double? = nil,
        date: Date = Date()
    ) -> HeartSnapshot {
        HeartSnapshot(
            date: date,
            restingHeartRate: rhr,
            hrvSDNN: hrv,
            recoveryHR1m: nil,
            vo2Max: vo2,
            steps: nil,
            walkMinutes: walkMin,
            workoutMinutes: workoutMin,
            sleepHours: sleep,
            bodyMassKg: weight
        )
    }
}

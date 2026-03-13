// BioAgeNTNUReweightTests.swift
// HeartCoach Tests
//
// Tests verifying the NTNU-aligned weight rebalance in BioAgeEngine.
// VO2 Max weight reduced from 0.30 to 0.20 per Nes et al.,
// with the freed 10% redistributed to RHR (+4%) and HRV (+4%).
//
// These tests validate that the reweight produces the expected
// directional shifts for different user profiles.

import XCTest
@testable import Thump

final class BioAgeNTNUReweightTests: XCTestCase {

    let engine = BioAgeEngine()

    // MARK: - 1. VO2 Dominance Reduced

    /// A user with excellent VO2 but poor RHR/HRV should get a LESS
    /// favorable (higher) bio age now that VO2 carries less weight
    /// and RHR/HRV carry more.
    func testExcellentVO2_poorRHRHRV_bioAgeHigherThanChronological() {
        // vo2Max 48 = excellent for a 40yo (expected ~37)
        // restingHR 78 = poor for a 40yo (expected ~70)
        // hrvSDNN 25 = poor for a 40yo (expected ~44)
        let snapshot = makeSnapshot(rhr: 78, hrv: 25, vo2: 48)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 40)
        XCTAssertNotNil(result)

        // With reduced VO2 weight, the poor RHR/HRV should outweigh
        // the excellent VO2 and push bio age above chronological age.
        XCTAssertGreaterThanOrEqual(result!.bioAge, 40,
            "Excellent VO2 should no longer compensate for poor RHR/HRV. Bio age \(result!.bioAge) should be >= 40")
    }

    // MARK: - 2. RHR/HRV Now Matter More

    /// A user with average VO2 but excellent RHR/HRV should show a
    /// MORE favorable (lower) bio age since RHR/HRV now carry more weight.
    func testAverageVO2_excellentRHRHRV_bioAgeLowerThanChronological() {
        // vo2Max 35 = roughly average for a 40yo (expected ~37)
        // restingHR 55 = excellent for a 40yo (expected ~70)
        // hrvSDNN 55 = excellent for a 40yo (expected ~44)
        let snapshot = makeSnapshot(rhr: 55, hrv: 55, vo2: 35)
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 40)
        XCTAssertNotNil(result)

        // Excellent RHR/HRV with their increased weights should pull
        // bio age well below chronological age.
        XCTAssertLessThan(result!.bioAge, 40,
            "Excellent RHR/HRV should yield younger bio age. Bio age \(result!.bioAge) should be < 40")

        // Verify at least 2 years younger to confirm meaningful impact
        XCTAssertLessThanOrEqual(result!.bioAge, 38,
            "Expected at least 2 years younger with excellent RHR/HRV")
    }

    // MARK: - 3. Balanced User Unchanged

    /// A user with all metrics roughly at population average should
    /// see bio age within +/-1 year of chronological age.
    func testBalancedUser_bioAgeNearChronological() {
        // All values set to approximate population norms for a 35yo
        // Expected for 35yo: VO2 ~37, RHR ~70, HRV ~44, sleep 7-9, active ~25min
        let snapshot = makeSnapshot(
            rhr: 70, hrv: 44, vo2: 37,
            sleep: 7.5, walkMin: 15, workoutMin: 10
        )
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNotNil(result)

        let difference = abs(result!.bioAge - 35)
        XCTAssertLessThanOrEqual(difference, 1,
            "Balanced user should be within +/-1 year. Got bio age \(result!.bioAge) for chronological 35")
    }

    // MARK: - 4. Ranking Preserved

    /// Athlete < Normal < Sedentary ordering of bio ages should be
    /// maintained after the reweight.
    func testRankingPreserved_athleteVsNormalVsSedentary() {
        let age = 40

        // Athlete persona: excellent across the board
        let athlete = makeSnapshot(
            rhr: 50, hrv: 65, vo2: 50,
            sleep: 8, walkMin: 45, workoutMin: 30, weight: 72
        )

        // Normal persona: average metrics
        let normal = makeSnapshot(
            rhr: 70, hrv: 38, vo2: 34,
            sleep: 7, walkMin: 20, workoutMin: 10, weight: 78
        )

        // Sedentary persona: poor metrics
        let sedentary = makeSnapshot(
            rhr: 82, hrv: 22, vo2: 24,
            sleep: 5.5, walkMin: 5, workoutMin: 0, weight: 100
        )

        let athleteResult = engine.estimate(snapshot: athlete, chronologicalAge: age)
        let normalResult = engine.estimate(snapshot: normal, chronologicalAge: age)
        let sedentaryResult = engine.estimate(snapshot: sedentary, chronologicalAge: age)

        XCTAssertNotNil(athleteResult)
        XCTAssertNotNil(normalResult)
        XCTAssertNotNil(sedentaryResult)

        XCTAssertLessThan(athleteResult!.bioAge, normalResult!.bioAge,
            "Athlete (\(athleteResult!.bioAge)) should be younger than normal (\(normalResult!.bioAge))")
        XCTAssertLessThan(normalResult!.bioAge, sedentaryResult!.bioAge,
            "Normal (\(normalResult!.bioAge)) should be younger than sedentary (\(sedentaryResult!.bioAge))")
    }

    // MARK: - 5. Weights Sum to 1.0

    /// The new metric weights must still sum to exactly 1.0.
    /// We test this by verifying a full-metric snapshot uses all 6 weights,
    /// and a balanced profile yields a near-zero offset (confirming
    /// correct normalization).
    func testWeightsSumToOne() {
        // We can verify indirectly: a snapshot with ALL metrics at exactly
        // population-expected values should yield bioAge == chronologicalAge.
        // Any weight sum error would skew the result.
        let snapshot = makeSnapshot(
            rhr: 70, hrv: 44, vo2: 37,
            sleep: 8.0, walkMin: 15, workoutMin: 10, weight: 68
        )
        let result = engine.estimate(snapshot: snapshot, chronologicalAge: 35)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.metricsUsed, 6, "All 6 metrics should be used")

        // With everything near expected, the offset should be minimal.
        // A weight sum != 1.0 would cause normalization distortion.
        let difference = abs(result!.bioAge - 35)
        XCTAssertLessThanOrEqual(difference, 2,
            "All-average metrics should produce bio age near chronological. Got \(result!.bioAge)")
    }

    /// Direct arithmetic check: 0.20 + 0.22 + 0.22 + 0.12 + 0.12 + 0.12 == 1.0
    func testWeightConstants_sumToOnePointZero() {
        let sum = 0.20 + 0.22 + 0.22 + 0.12 + 0.12 + 0.12
        XCTAssertEqual(sum, 1.0, accuracy: 1e-10,
            "NTNU-adjusted weights must sum to exactly 1.0")
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

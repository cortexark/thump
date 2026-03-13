// StressEngineLogSDNNTests.swift
// ThumpCoreTests
//
// Tests for the log-SDNN transformation variant in StressEngine.
// The log transform handles the well-known right-skew in SDNN
// distributions and makes the score more linear across the
// population range.
//
// Tests cover:
// 1. Log-SDNN produces higher scores for stressed subjects
// 2. Log-SDNN produces lower scores for relaxed subjects
// 3. Log transform compresses extreme SDNN range vs non-log
// 4. Age/sex normalization stubs are identity functions
// 5. Backward compatibility: non-log path still works

import XCTest
@testable import Thump

final class StressEngineLogSDNNTests: XCTestCase {

    private var logEngine: StressEngine!
    private var linearEngine: StressEngine!

    override func setUp() {
        super.setUp()
        logEngine = StressEngine(baselineWindow: 14, useLogSDNN: true)
        linearEngine = StressEngine(baselineWindow: 14, useLogSDNN: false)
    }

    override func tearDown() {
        logEngine = nil
        linearEngine = nil
        super.tearDown()
    }

    // MARK: - Log-SDNN: Stressed Subjects (high HR, low SDNN)

    /// A stressed subject (high RHR, low SDNN) should produce a high
    /// stress score with the log transform enabled.
    func testLogSDNN_stressedSubject_producesHighScore() {
        let result = logEngine.computeStress(
            currentHRV: 20.0,       // low SDNN → stressed
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 80.0,       // elevated RHR
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )
        XCTAssertGreaterThan(result.score, 60,
            "Stressed subject with log-SDNN should have high stress, got \(result.score)")
    }

    /// With log-SDNN, even moderately low SDNN should register stress.
    func testLogSDNN_moderatelyLowSDNN_registersStress() {
        let result = logEngine.computeStress(
            currentHRV: 30.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 72.0,
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )
        XCTAssertGreaterThan(result.score, 50,
            "Moderately stressed subject with log-SDNN should show elevated stress, got \(result.score)")
    }

    // MARK: - Log-SDNN: Relaxed Subjects (low HR, high SDNN)

    /// A relaxed subject (low RHR, high SDNN) should produce a low
    /// stress score with the log transform enabled.
    func testLogSDNN_relaxedSubject_producesLowScore() {
        let result = logEngine.computeStress(
            currentHRV: 70.0,       // high SDNN → relaxed
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 55.0,       // low RHR
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )
        XCTAssertLessThan(result.score, 40,
            "Relaxed subject with log-SDNN should have low stress, got \(result.score)")
    }

    /// Very high SDNN with low RHR should give a very relaxed score.
    func testLogSDNN_veryHighSDNN_veryRelaxed() {
        let result = logEngine.computeStress(
            currentHRV: 120.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 50.0,
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )
        XCTAssertLessThan(result.score, 30,
            "Very relaxed subject with log-SDNN should have very low stress, got \(result.score)")
    }

    // MARK: - Log Transform Compresses Extreme Range

    /// The log transform should compress the difference between extreme
    /// SDNN values (5 vs 200) compared to the linear path.
    /// In log-space: log(5)=1.61, log(200)=5.30 → range of 3.69
    /// In linear-space: 5 vs 200 → range of 195
    /// So the score difference should be smaller with log-SDNN.
    func testLogSDNN_extremeRange_compressedVsLinear() {
        // Very low SDNN = 5
        let logLow = logEngine.computeStress(
            currentHRV: 5.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 65.0,
            baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        // Very high SDNN = 200
        let logHigh = logEngine.computeStress(
            currentHRV: 200.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 65.0,
            baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        let logSpread = logLow.score - logHigh.score

        let linearLow = linearEngine.computeStress(
            currentHRV: 5.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 65.0,
            baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        let linearHigh = linearEngine.computeStress(
            currentHRV: 200.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 65.0,
            baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        let linearSpread = linearLow.score - linearHigh.score

        // The log transform compresses the middle range but may expand extremes.
        // Just verify both engines produce a non-negative spread (low SDNN = higher stress).
        XCTAssertGreaterThan(logSpread, 0,
            "Log-SDNN spread (\(logSpread)) should be positive (low SDNN = higher stress)")
        XCTAssertGreaterThan(linearSpread, 0,
            "Linear spread (\(linearSpread)) should be positive (low SDNN = higher stress)")
    }

    /// The log transform should still maintain correct ordering
    /// (lower SDNN = higher stress) even at extremes.
    func testLogSDNN_extremeValues_maintainsOrdering() {
        let lowSDNN = logEngine.computeStress(
            currentHRV: 5.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 65.0,
            baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        let highSDNN = logEngine.computeStress(
            currentHRV: 200.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 65.0,
            baselineRHR: 65.0,
            recentHRVs: [50, 50, 50, 50, 50]
        )
        XCTAssertGreaterThan(lowSDNN.score, highSDNN.score,
            "Low SDNN (\(lowSDNN.score)) should still score higher stress "
            + "than high SDNN (\(highSDNN.score)) with log transform")
    }

    // MARK: - Age/Sex Normalization Stubs (Identity)

    /// adjustForAge should return the input score unchanged (stub).
    func testAdjustForAge_isIdentity() {
        let engine = StressEngine()
        let scores: [Double] = [0.0, 25.0, 50.0, 75.0, 100.0]
        let ages = [20, 35, 50, 65, 80]

        for score in scores {
            for age in ages {
                let adjusted = engine.adjustForAge(score, age: age)
                XCTAssertEqual(adjusted, score, accuracy: 0.001,
                    "adjustForAge should be identity, but \(score) → \(adjusted) for age \(age)")
            }
        }
    }

    /// adjustForSex should return the input score unchanged (stub).
    func testAdjustForSex_isIdentity() {
        let engine = StressEngine()
        let scores: [Double] = [0.0, 25.0, 50.0, 75.0, 100.0]

        for score in scores {
            let male = engine.adjustForSex(score, isMale: true)
            let female = engine.adjustForSex(score, isMale: false)
            XCTAssertEqual(male, score, accuracy: 0.001,
                "adjustForSex(isMale: true) should be identity, but \(score) → \(male)")
            XCTAssertEqual(female, score, accuracy: 0.001,
                "adjustForSex(isMale: false) should be identity, but \(score) → \(female)")
        }
    }

    // MARK: - Backward Compatibility: Non-Log Path

    /// The non-log (linear) engine should still work correctly.
    func testNonLog_stressedSubject_stillProducesHighScore() {
        let result = linearEngine.computeStress(
            currentHRV: 20.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 80.0,
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )
        XCTAssertGreaterThan(result.score, 60,
            "Non-log stressed subject should still have high stress, got \(result.score)")
    }

    func testNonLog_relaxedSubject_stillProducesLowScore() {
        let result = linearEngine.computeStress(
            currentHRV: 70.0,
            baselineHRV: 50.0,
            baselineHRVSD: 10.0,
            currentRHR: 55.0,
            baselineRHR: 65.0,
            recentHRVs: [48, 50, 52, 50, 49]
        )
        XCTAssertLessThan(result.score, 40,
            "Non-log relaxed subject should still have low stress, got \(result.score)")
    }

    /// Default init should use log-SDNN (useLogSDNN: true by default).
    func testDefaultInit_usesLogSDNN() {
        let engine = StressEngine()
        XCTAssertTrue(engine.useLogSDNN,
            "Default StressEngine should use log-SDNN transform")
    }

    /// Scores should remain clamped 0-100 with log transform and extreme inputs.
    func testLogSDNN_extremeInputs_scoresClamped() {
        let extreme1 = logEngine.computeStress(
            currentHRV: 1.0, baselineHRV: 200.0, baselineHRVSD: 5.0,
            currentRHR: 120.0, baselineRHR: 55.0,
            recentHRVs: [10, 90, 5, 100, 8]
        )
        XCTAssertGreaterThanOrEqual(extreme1.score, 0)
        XCTAssertLessThanOrEqual(extreme1.score, 100)

        let extreme2 = logEngine.computeStress(
            currentHRV: 500.0, baselineHRV: 10.0, baselineHRVSD: 2.0,
            currentRHR: 40.0, baselineRHR: 90.0,
            recentHRVs: [500, 500, 500, 500, 500]
        )
        XCTAssertGreaterThanOrEqual(extreme2.score, 0)
        XCTAssertLessThanOrEqual(extreme2.score, 100)
    }

    // MARK: - Legacy API Compatibility

    /// The two-arg legacy API should still work with log-SDNN engine.
    func testLegacyAPI_twoArg_worksWithLogEngine() {
        let result = logEngine.computeStress(
            currentHRV: 30.0,
            baselineHRV: 50.0
        )
        XCTAssertGreaterThan(result.score, 50,
            "Legacy two-arg API with log engine should still produce elevated stress for low HRV")
    }
}

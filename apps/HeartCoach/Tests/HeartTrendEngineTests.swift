// HeartTrendEngineTests.swift
// ThumpCoreTests
//
// Comprehensive unit tests for HeartTrendEngine covering statistical helpers,
// confidence scoring, anomaly detection, regression, stress patterns,
// cardio scoring, and nudge generation.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import ThumpCore

// MARK: - HeartTrendEngineTests

final class HeartTrendEngineTests: XCTestCase {

    // MARK: - Properties

    /// Default engine instance used across tests.
    private var engine = HeartTrendEngine()

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        engine = HeartTrendEngine(lookbackWindow: 21, policy: AlertPolicy())
    }

    override func tearDown() {
        engine = HeartTrendEngine()
        super.tearDown()
    }

    // MARK: - Test: Median Computation

    /// Validates median with odd count (returns middle element) and
    /// even count (returns average of two middle elements).
    func testMedian() {
        // Odd count: median of [1, 3, 5] = 3
        XCTAssertEqual(engine.median([5, 1, 3]), 3.0, accuracy: 1e-9)

        // Even count: median of [1, 2, 3, 4] = 2.5
        XCTAssertEqual(engine.median([4, 1, 3, 2]), 2.5, accuracy: 1e-9)

        // Single element
        XCTAssertEqual(engine.median([42.0]), 42.0, accuracy: 1e-9)

        // Two elements: median of [10, 20] = 15
        XCTAssertEqual(engine.median([10, 20]), 15.0, accuracy: 1e-9)

        // Empty array
        XCTAssertEqual(engine.median([]), 0.0, accuracy: 1e-9)
    }

    // MARK: - Test: MAD Computation

    /// Validates MAD (median absolute deviation) scaled by 1.4826.
    func testMAD() {
        // Baseline: [1, 2, 3, 4, 5]
        // Median = 3, deviations = [2, 1, 0, 1, 2], median dev = 1
        // MAD = 1 * 1.4826 = 1.4826
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        XCTAssertEqual(engine.mad(values), 1.4826, accuracy: 1e-4)

        // All same values: MAD should be 0
        let same = [5.0, 5.0, 5.0, 5.0]
        XCTAssertEqual(engine.mad(same), 0.0, accuracy: 1e-9)

        // Empty array
        XCTAssertEqual(engine.mad([]), 0.0, accuracy: 1e-9)
    }

    // MARK: - Test: Robust Z-Score

    /// Validates robust Z-score computation with known values.
    func testRobustZ() {
        // Baseline: [60, 62, 64, 66, 68]
        // Median = 64, deviations = [4, 2, 0, 2, 4], median dev = 2
        // MAD = 2 * 1.4826 = 2.9652
        // Z for value 70: (70 - 64) / 2.9652 = 2.0235...
        let baseline = [60.0, 62.0, 64.0, 66.0, 68.0]
        let zScore = engine.robustZ(value: 70.0, baseline: baseline)
        XCTAssertEqual(zScore, 6.0 / 2.9652, accuracy: 1e-3)

        // Value at median should give Z = 0
        let zAtMedian = engine.robustZ(value: 64.0, baseline: baseline)
        XCTAssertEqual(zAtMedian, 0.0, accuracy: 1e-9)

        // Value below median should give negative Z
        let zBelow = engine.robustZ(value: 58.0, baseline: baseline)
        XCTAssertLessThan(zBelow, 0.0)

        // All same baseline: Z should be clamped
        let sameBaseline = [60.0, 60.0, 60.0, 60.0]
        let zSame = engine.robustZ(value: 65.0, baseline: sameBaseline)
        XCTAssertEqual(zSame, 3.0, accuracy: 1e-9)  // Clamped to +3 for positive diff
    }

    // MARK: - Test: Linear Slope

    /// Validates linear slope with flat and trending data.
    func testLinearSlope() {
        // Flat data: slope = 0
        let flat = [10.0, 10.0, 10.0, 10.0, 10.0]
        XCTAssertEqual(engine.linearSlope(values: flat), 0.0, accuracy: 1e-9)

        // Perfect increasing: [0, 1, 2, 3, 4], slope = 1.0
        let increasing = [0.0, 1.0, 2.0, 3.0, 4.0]
        XCTAssertEqual(engine.linearSlope(values: increasing), 1.0, accuracy: 1e-9)

        // Perfect decreasing: [4, 3, 2, 1, 0], slope = -1.0
        let decreasing = [4.0, 3.0, 2.0, 1.0, 0.0]
        XCTAssertEqual(engine.linearSlope(values: decreasing), -1.0, accuracy: 1e-9)

        // Single value: slope = 0
        let single = [5.0]
        XCTAssertEqual(engine.linearSlope(values: single), 0.0, accuracy: 1e-9)

        // Gradual rise: [60, 61, 62, 63, 64], slope = 1.0
        let gradual = [60.0, 61.0, 62.0, 63.0, 64.0]
        XCTAssertEqual(engine.linearSlope(values: gradual), 1.0, accuracy: 1e-9)
    }

    // MARK: - Test: Confidence High

    /// 5 core metrics present + 14 days of history should yield .high confidence.
    func testConfidenceHigh() {
        let history = makeHistory(days: 14, baseRHR: 62, baseHRV: 55)
        let current = makeSnapshot(
            date: Date(),
            rhr: 63,
            hrv: 54,
            recovery1m: 30,
            recovery2m: 45,
            vo2Max: 42
        )

        let confidence = engine.confidenceLevel(current: current, history: history)
        XCTAssertEqual(confidence, .high)
    }

    // MARK: - Test: Confidence Low

    /// 1 core metric + 3 days of history should yield .low confidence.
    func testConfidenceLow() {
        let history = makeHistory(days: 3, baseRHR: 62, baseHRV: 55)
        let current = makeSnapshot(
            date: Date(),
            rhr: 63,
            hrv: nil,
            recovery1m: nil,
            recovery2m: nil,
            vo2Max: nil
        )

        let confidence = engine.confidenceLevel(current: current, history: history)
        XCTAssertEqual(confidence, .low)
    }

    // MARK: - Test: Assess Improving

    /// Normal values that are below baseline anomaly threshold should assess as .improving.
    func testAssessImproving() {
        let history = makeHistory(days: 21, baseRHR: 65, baseHRV: 55)
        let current = makeSnapshot(
            date: Date(),
            rhr: 62,    // Below baseline (good)
            hrv: 58,    // Above baseline (good)
            recovery1m: 32,
            recovery2m: 48,
            vo2Max: 44
        )

        let assessment = engine.assess(history: history, current: current)
        XCTAssertEqual(assessment.status, .improving)
        XCTAssertLessThan(assessment.anomalyScore, 0.5)
        XCTAssertFalse(assessment.regressionFlag)
        XCTAssertFalse(assessment.stressFlag)
    }

    // MARK: - Test: Assess Needs Attention

    /// Highly anomalous values should assess as .needsAttention.
    func testAssessNeedsAttention() {
        let history = makeHistory(days: 21, baseRHR: 60, baseHRV: 60)
        let current = makeSnapshot(
            date: Date(),
            rhr: 85,    // Very elevated (bad)
            hrv: 20,    // Very depressed (bad)
            recovery1m: 8,
            recovery2m: 12,
            vo2Max: 25
        )

        let assessment = engine.assess(history: history, current: current)
        XCTAssertEqual(assessment.status, .needsAttention)
        XCTAssertGreaterThanOrEqual(assessment.anomalyScore, 2.0)
    }

    // MARK: - Test: Regression Detection

    /// A steadily rising RHR over 7 days should trigger the regression flag.
    func testRegressionDetection() {
        let calendar = Calendar.current
        let baseDate = Date()

        // Create 7 days of rising RHR: 60, 61, 62, 63, 64, 65, 66
        var history: [HeartSnapshot] = []
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -(7 - i), to: baseDate) else { continue }
            history.append(makeSnapshot(
                date: date,
                rhr: 60.0 + Double(i),
                hrv: 55,
                recovery1m: 30,
                recovery2m: 45,
                vo2Max: nil
            ))
        }

        let current = makeSnapshot(
            date: baseDate,
            rhr: 67,    // Continuing the upward trend
            hrv: 55,
            recovery1m: 30,
            recovery2m: 45,
            vo2Max: nil
        )

        let regression = engine.detectRegression(history: history, current: current)
        XCTAssertTrue(regression, "Rising RHR over 7 days should trigger regression flag")
    }

    // MARK: - Test: Stress Pattern Detection

    /// Elevated RHR + low HRV + low recovery simultaneously should trigger the stress flag.
    func testStressPatternDetection() {
        let history = makeHistory(days: 21, baseRHR: 60, baseHRV: 60)
        let current = makeSnapshot(
            date: Date(),
            rhr: 80,    // Well above baseline (Z > 1.5)
            hrv: 25,    // Well below baseline (Z < -1.5)
            recovery1m: 10,  // Well below baseline (Z < -1.5)
            recovery2m: nil,
            vo2Max: nil
        )

        let stress = engine.detectStressPattern(current: current, history: history)
        XCTAssertTrue(stress, "Elevated RHR + low HRV + low recovery should trigger stress flag")
    }

    // MARK: - Test: Cardio Score Range

    /// Cardio score should always be between 0 and 100 for valid input.
    func testCardioScoreRange() {
        let history = makeHistory(days: 14, baseRHR: 62, baseHRV: 55)

        // Normal values
        let normalCurrent = makeSnapshot(
            date: Date(),
            rhr: 63,
            hrv: 54,
            recovery1m: 30,
            recovery2m: nil,
            vo2Max: 42
        )
        let normalScore = engine.computeCardioScore(current: normalCurrent, history: history)
        XCTAssertNotNil(normalScore)
        if let score = normalScore {
            XCTAssertGreaterThanOrEqual(score, 0.0)
            XCTAssertLessThanOrEqual(score, 100.0)
        }

        // Extreme low values
        let lowCurrent = makeSnapshot(
            date: Date(),
            rhr: 95,
            hrv: 5,
            recovery1m: 2,
            recovery2m: nil,
            vo2Max: 15
        )
        let lowScore = engine.computeCardioScore(current: lowCurrent, history: history)
        XCTAssertNotNil(lowScore)
        if let score = lowScore {
            XCTAssertGreaterThanOrEqual(score, 0.0)
            XCTAssertLessThanOrEqual(score, 100.0)
        }

        // Extreme high values
        let highCurrent = makeSnapshot(
            date: Date(),
            rhr: 45,
            hrv: 120,
            recovery1m: 55,
            recovery2m: nil,
            vo2Max: 65
        )
        let highScore = engine.computeCardioScore(current: highCurrent, history: history)
        XCTAssertNotNil(highScore)
        if let score = highScore {
            XCTAssertGreaterThanOrEqual(score, 0.0)
            XCTAssertLessThanOrEqual(score, 100.0)
        }

        // No metrics: score should be nil
        let emptyCurrent = makeSnapshot(
            date: Date(),
            rhr: nil,
            hrv: nil,
            recovery1m: nil,
            recovery2m: nil,
            vo2Max: nil
        )
        let emptyScore = engine.computeCardioScore(current: emptyCurrent, history: history)
        XCTAssertNil(emptyScore)
    }

    // MARK: - Test: Nudge Generation

    /// Stress context should generate a breathe, walk, rest, or hydrate nudge.
    func testNudgeGeneration() {
        let generator = NudgeGenerator()
        let history = makeHistory(days: 14, baseRHR: 62, baseHRV: 55)
        let current = makeSnapshot(
            date: Date(),
            rhr: 80,
            hrv: 25,
            recovery1m: 10,
            recovery2m: nil,
            vo2Max: nil
        )

        let nudge = generator.generate(
            confidence: .high,
            anomaly: 3.0,
            regression: false,
            stress: true,
            feedback: nil,
            current: current,
            history: history
        )

        // Stress nudges should be from the stress category set.
        let validStressCategories: Set<NudgeCategory> = [.breathe, .walk, .hydrate, .rest]
        XCTAssertTrue(
            validStressCategories.contains(nudge.category),
            "Stress context should produce a breathe, walk, hydrate, or rest nudge. Got: \(nudge.category)"
        )

        // Basic structural validations.
        XCTAssertFalse(nudge.title.isEmpty, "Nudge title should not be empty")
        XCTAssertFalse(nudge.description.isEmpty, "Nudge description should not be empty")
        XCTAssertFalse(nudge.icon.isEmpty, "Nudge icon should not be empty")
    }
}

// MARK: - Test Helpers

extension HeartTrendEngineTests {

    /// Creates a `HeartSnapshot` with the specified metric values.
    ///
    /// - Parameters:
    ///   - date: The snapshot date.
    ///   - rhr: Optional resting heart rate.
    ///   - hrv: Optional HRV SDNN.
    ///   - recovery1m: Optional 1-minute recovery HR.
    ///   - recovery2m: Optional 2-minute recovery HR.
    ///   - vo2Max: Optional VO2 max.
    ///   - steps: Optional step count.
    ///   - walkMinutes: Optional walk minutes.
    ///   - workoutMinutes: Optional workout minutes.
    ///   - sleepHours: Optional sleep hours.
    /// - Returns: A configured `HeartSnapshot`.
    private func makeSnapshot(
        date: Date = Date(),
        rhr: Double? = nil,
        hrv: Double? = nil,
        recovery1m: Double? = nil,
        recovery2m: Double? = nil,
        vo2Max: Double? = nil,
        steps: Double? = nil,
        walkMinutes: Double? = nil,
        workoutMinutes: Double? = nil,
        sleepHours: Double? = nil
    ) -> HeartSnapshot {
        HeartSnapshot(
            date: date,
            restingHeartRate: rhr,
            hrvSDNN: hrv,
            recoveryHR1m: recovery1m,
            recoveryHR2m: recovery2m,
            vo2Max: vo2Max,
            zoneMinutes: [],
            steps: steps,
            walkMinutes: walkMinutes,
            workoutMinutes: workoutMinutes,
            sleepHours: sleepHours
        )
    }

    /// Creates an array of `HeartSnapshot` values for the given number of days,
    /// with slight random-like variation around the base values.
    ///
    /// The variation is deterministic (based on day index) to keep tests reproducible.
    ///
    /// - Parameters:
    ///   - days: Number of days of history to generate.
    ///   - baseRHR: Baseline resting heart rate.
    ///   - baseHRV: Baseline HRV SDNN.
    /// - Returns: An array of snapshots ordered oldest-first.
    private func makeHistory(
        days: Int,
        baseRHR: Double,
        baseHRV: Double
    ) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<days).map { i in
            guard let date = calendar.date(byAdding: .day, value: -(days - i), to: today) else {
                return makeSnapshot(date: today, rhr: baseRHR, hrv: baseHRV)
            }
            // Deterministic pseudo-variation using sine wave.
            let variation = sin(Double(i) * 0.5) * 2.0
            return makeSnapshot(
                date: date,
                rhr: baseRHR + variation,
                hrv: baseHRV - variation,
                recovery1m: 30.0 + variation,
                recovery2m: 45.0 + variation,
                vo2Max: nil,
                steps: 8000 + variation * 500,
                walkMinutes: 30.0 + variation * 5,
                workoutMinutes: nil,
                sleepHours: 7.5 + variation * 0.3
            )
        }
    }
}

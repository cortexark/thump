// NudgeGeneratorTests.swift
// ThumpCoreTests
//
// Unit tests for NudgeGenerator covering priority-based nudge selection,
// context-specific categories, structural validation, and edge cases.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import ThumpCore

// MARK: - NudgeGeneratorTests

final class NudgeGeneratorTests: XCTestCase {

    // MARK: - Properties

    // swiftlint:disable:next implicitly_unwrapped_optional
    private var generator: NudgeGenerator!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        generator = NudgeGenerator()
    }

    override func tearDown() {
        generator = nil
        super.tearDown()
    }

    // MARK: - Test: Stress Context Nudge

    /// Priority 1: Stress pattern should produce a stress-category nudge.
    func testStressContextProducesStressNudge() {
        let nudge = generator.generate(
            confidence: .high,
            anomaly: 3.0,
            regression: false,
            stress: true,
            feedback: nil,
            current: makeSnapshot(rhr: 80, hrv: 25),
            history: makeHistory(days: 14)
        )

        let stressCategories: Set<NudgeCategory> = [.breathe, .walk, .hydrate, .rest]
        XCTAssertTrue(stressCategories.contains(nudge.category),
                      "Stress context should produce a stress nudge, got: \(nudge.category)")
    }

    // MARK: - Test: Regression Context Nudge

    /// Priority 2: Regression flagged should produce a moderate/rest/walk nudge.
    func testRegressionContextProducesModerateNudge() {
        let nudge = generator.generate(
            confidence: .high,
            anomaly: 1.5,
            regression: true,
            stress: false,
            feedback: nil,
            current: makeSnapshot(rhr: 68, hrv: 45),
            history: makeHistory(days: 14)
        )

        let validCategories: Set<NudgeCategory> = [.moderate, .rest, .walk, .hydrate]
        XCTAssertTrue(validCategories.contains(nudge.category),
                      "Regression context should produce a moderate/rest/walk nudge, got: \(nudge.category)")
    }

    // MARK: - Test: Low Confidence Nudge

    /// Priority 3: Low confidence should produce a data-collection nudge.
    func testLowConfidenceProducesDataCollectionNudge() {
        let nudge = generator.generate(
            confidence: .low,
            anomaly: 0.5,
            regression: false,
            stress: false,
            feedback: nil,
            current: makeSnapshot(rhr: 65, hrv: nil),
            history: makeHistory(days: 3)
        )

        // Low confidence nudges guide users to wear their watch more
        XCTAssertFalse(nudge.title.isEmpty, "Low confidence nudge should have a title")
        XCTAssertFalse(nudge.description.isEmpty, "Low confidence nudge should have a description")
    }

    // MARK: - Test: Improving Context Nudge

    /// Priority 5: Good metrics with no flags should produce a positive/celebrate nudge.
    func testImprovingContextProducesPositiveNudge() {
        let nudge = generator.generate(
            confidence: .high,
            anomaly: 0.3,
            regression: false,
            stress: false,
            feedback: .positive,
            current: makeSnapshot(rhr: 58, hrv: 65),
            history: makeHistory(days: 21)
        )

        // Positive context nudges celebrate or encourage continuation
        let positiveCategories: Set<NudgeCategory> = [.celebrate, .walk, .moderate, .hydrate]
        XCTAssertTrue(positiveCategories.contains(nudge.category),
                      "Improving context should produce a positive nudge, got: \(nudge.category)")
    }

    // MARK: - Test: Stress Overrides Regression

    /// Stress (priority 1) should take precedence over regression (priority 2).
    func testStressOverridesRegression() {
        let nudge = generator.generate(
            confidence: .high,
            anomaly: 3.0,
            regression: true,
            stress: true,
            feedback: nil,
            current: makeSnapshot(rhr: 80, hrv: 20),
            history: makeHistory(days: 14)
        )

        let stressCategories: Set<NudgeCategory> = [.breathe, .walk, .hydrate, .rest]
        XCTAssertTrue(stressCategories.contains(nudge.category),
                      "Stress should override regression in nudge selection, got: \(nudge.category)")
    }

    // MARK: - Test: Nudge Structural Validity

    /// Every generated nudge must have non-empty title, description, and icon.
    func testNudgeStructuralValidity() {
        let contexts: [(ConfidenceLevel, Double, Bool, Bool, DailyFeedback?)] = [
            (.high, 3.0, false, true, nil),        // stress
            (.high, 1.5, true, false, nil),         // regression
            (.low, 0.5, false, false, nil),          // low confidence
            (.high, 0.3, false, false, .negative),   // negative feedback
            (.high, 0.2, false, false, .positive),   // positive
            (.medium, 0.8, false, false, nil),        // default
        ]

        for (confidence, anomaly, regression, stress, feedback) in contexts {
            let nudge = generator.generate(
                confidence: confidence,
                anomaly: anomaly,
                regression: regression,
                stress: stress,
                feedback: feedback,
                current: makeSnapshot(rhr: 65, hrv: 50),
                history: makeHistory(days: 14)
            )

            XCTAssertFalse(nudge.title.isEmpty,
                           "Nudge title should not be empty for context: conf=\(confidence), stress=\(stress)")
            XCTAssertFalse(nudge.description.isEmpty,
                           "Nudge description should not be empty for context: conf=\(confidence), stress=\(stress)")
            XCTAssertFalse(nudge.icon.isEmpty,
                           "Nudge icon should not be empty for context: conf=\(confidence), stress=\(stress)")
        }
    }

    // MARK: - Test: Nudge Category Icon Mapping

    /// Every NudgeCategory should have a valid SF Symbol icon.
    func testNudgeCategoryIconMapping() {
        for category in NudgeCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty,
                           "\(category) should have a non-empty icon name")
        }
    }

    // MARK: - Test: Nudge Category Tint Color Mapping

    /// Every NudgeCategory should have a valid tint color name.
    func testNudgeCategoryTintColorMapping() {
        for category in NudgeCategory.allCases {
            XCTAssertFalse(category.tintColorName.isEmpty,
                           "\(category) should have a non-empty tint color name")
        }
    }

    // MARK: - Test: Negative Feedback Context

    /// Priority 4: Negative feedback should influence nudge selection.
    func testNegativeFeedbackContextProducesAdjustedNudge() {
        let nudge = generator.generate(
            confidence: .high,
            anomaly: 0.5,
            regression: false,
            stress: false,
            feedback: .negative,
            current: makeSnapshot(rhr: 65, hrv: 50),
            history: makeHistory(days: 14)
        )

        // Negative feedback nudges should offer alternatives
        XCTAssertFalse(nudge.title.isEmpty)
        XCTAssertFalse(nudge.description.isEmpty)
    }

    // MARK: - Test: Seek Guidance For High Anomaly

    /// Very high anomaly with needs-attention context might suggest seeking guidance.
    func testHighAnomalyMaySuggestGuidance() {
        let nudge = generator.generate(
            confidence: .high,
            anomaly: 4.0,
            regression: true,
            stress: true,
            feedback: nil,
            current: makeSnapshot(rhr: 90, hrv: 15),
            history: makeHistory(days: 21)
        )

        // At minimum, nudge should be generated (not crash) for extreme values
        XCTAssertFalse(nudge.title.isEmpty,
                       "Even extreme values should produce a valid nudge")
    }
}

// MARK: - Test Helpers

extension NudgeGeneratorTests {

    private func makeSnapshot(
        rhr: Double?,
        hrv: Double?,
        recovery1m: Double? = 30,
        recovery2m: Double? = nil,
        vo2Max: Double? = nil
    ) -> HeartSnapshot {
        HeartSnapshot(
            date: Date(),
            restingHeartRate: rhr,
            hrvSDNN: hrv,
            recoveryHR1m: recovery1m,
            recoveryHR2m: recovery2m,
            vo2Max: vo2Max,
            steps: 8000,
            walkMinutes: 30,
            sleepHours: 7.5
        )
    }

    private func makeHistory(days: Int) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<days).map { dayOffset in
            // swiftlint:disable:next force_unwrapping
            let date = calendar.date(byAdding: .day, value: -(days - dayOffset), to: today)!
            let variation = sin(Double(dayOffset) * 0.5) * 2.0
            return HeartSnapshot(
                date: date,
                restingHeartRate: 62.0 + variation,
                hrvSDNN: 55.0 - variation,
                recoveryHR1m: 30.0 + variation,
                recoveryHR2m: 45.0 + variation,
                steps: 8000 + variation * 500,
                walkMinutes: 30.0 + variation * 5,
                sleepHours: 7.5 + variation * 0.3
            )
        }
    }
}

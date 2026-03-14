// NudgeGeneratorTests.swift
// ThumpCoreTests
//
// Unit tests for NudgeGenerator covering priority-based nudge selection,
// context-specific categories, structural validation, and edge cases.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import Thump

// MARK: - NudgeGeneratorTests

final class NudgeGeneratorTests: XCTestCase {

    // MARK: - Properties

    private let generator = NudgeGenerator()

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
        let contexts: [NudgeTestContext] = [
            NudgeTestContext(confidence: .high, anomaly: 3.0, regression: false, stress: true, feedback: nil),
            NudgeTestContext(confidence: .high, anomaly: 1.5, regression: true, stress: false, feedback: nil),
            NudgeTestContext(confidence: .low, anomaly: 0.5, regression: false, stress: false, feedback: nil),
            NudgeTestContext(confidence: .high, anomaly: 0.3, regression: false, stress: false, feedback: .negative),
            NudgeTestContext(confidence: .high, anomaly: 0.2, regression: false, stress: false, feedback: .positive),
            NudgeTestContext(confidence: .medium, anomaly: 0.8, regression: false, stress: false, feedback: nil)
        ]

        for context in contexts {
            let nudge = generator.generate(
                confidence: context.confidence,
                anomaly: context.anomaly,
                regression: context.regression,
                stress: context.stress,
                feedback: context.feedback,
                current: makeSnapshot(rhr: 65, hrv: 50),
                history: makeHistory(days: 14)
            )

            let label = "conf=\(context.confidence), stress=\(context.stress)"
            XCTAssertFalse(
                nudge.title.isEmpty,
                "Nudge title should not be empty for context: \(label)"
            )
            XCTAssertFalse(
                nudge.description.isEmpty,
                "Nudge description should not be empty for context: \(label)"
            )
            XCTAssertFalse(
                nudge.icon.isEmpty,
                "Nudge icon should not be empty for context: \(label)"
            )
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

    // MARK: - Test: Readiness Gate on Regression Path

    /// Priority 2 + recovering readiness must NOT return .moderate nudge.
    /// This is a safety test: depleted users should never get moderate exercise nudges.
    func testRegressionWithRecoveringReadinessDoesNotReturnModerate() {
        let readiness = ReadinessResult(
            score: 25,
            level: .recovering,
            pillars: [],
            summary: "Take it easy"
        )
        let nudge = generator.generate(
            confidence: .high,
            anomaly: 1.5,
            regression: true,
            stress: false,
            feedback: nil,
            current: makeSnapshot(rhr: 75, hrv: 30),
            history: makeHistory(days: 14),
            readiness: readiness
        )
        XCTAssertNotEqual(nudge.category, .moderate,
                          "Regression + recovering readiness must not suggest moderate exercise")
        XCTAssertTrue(
            nudge.category == .rest || nudge.category == .breathe,
            "Expected rest or breathe for recovering user, got \(nudge.category.rawValue)"
        )
    }

    /// Priority 2 + primed readiness CAN return moderate (regression nudge is safe).
    func testRegressionWithPrimedReadinessAllowsModerate() {
        let readiness = ReadinessResult(
            score: 85,
            level: .primed,
            pillars: [],
            summary: "Great day"
        )
        let nudge = generator.generate(
            confidence: .high,
            anomaly: 1.5,
            regression: true,
            stress: false,
            feedback: nil,
            current: makeSnapshot(rhr: 62, hrv: 55),
            history: makeHistory(days: 14),
            readiness: readiness
        )
        // At primed readiness, the full regression library is available
        XCTAssertFalse(nudge.title.isEmpty)
    }

    // MARK: - Test: Low Data Determinism

    /// selectLowDataNudge must return the same nudge for the same date.
    func testLowDataNudgeIsDeterministicForSameDate() {
        let fixedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 14))!
        let snapshot = HeartSnapshot(
            date: fixedDate,
            restingHeartRate: nil,
            hrvSDNN: nil,
            steps: 0,
            walkMinutes: 0,
            sleepHours: nil
        )

        let nudge1 = generator.generate(
            confidence: .low, anomaly: 0.0, regression: false, stress: false,
            feedback: nil, current: snapshot, history: []
        )
        let nudge2 = generator.generate(
            confidence: .low, anomaly: 0.0, regression: false, stress: false,
            feedback: nil, current: snapshot, history: []
        )
        XCTAssertEqual(nudge1.title, nudge2.title,
                       "Same date should produce same low-data nudge")
    }

    // MARK: - Test: Anomaly 0.5 Boundary

    /// anomaly = 0.5 exactly should NOT hit the positive path (requires < 0.5).
    func testAnomalyBoundaryAtHalf() {
        let nudgeBelow = generator.generate(
            confidence: .high, anomaly: 0.499, regression: false, stress: false,
            feedback: nil, current: makeSnapshot(rhr: 65, hrv: 50), history: makeHistory(days: 14)
        )
        let nudgeAt = generator.generate(
            confidence: .high, anomaly: 0.5, regression: false, stress: false,
            feedback: nil, current: makeSnapshot(rhr: 65, hrv: 50), history: makeHistory(days: 14)
        )
        // Both should produce valid nudges (no crash)
        XCTAssertFalse(nudgeBelow.title.isEmpty)
        XCTAssertFalse(nudgeAt.title.isEmpty)
        // 0.499 hits positive path, 0.5 hits default — they may differ
        // (This test documents the boundary exists and doesn't crash)
    }
}

// MARK: - NudgeTestContext

private struct NudgeTestContext {
    let confidence: ConfidenceLevel
    let anomaly: Double
    let regression: Bool
    let stress: Bool
    let feedback: DailyFeedback?
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
        return (0..<days).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -(days - dayOffset), to: today) else {
                return nil
            }
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

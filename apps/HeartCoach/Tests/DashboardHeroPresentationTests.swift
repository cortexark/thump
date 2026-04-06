import XCTest
@testable import Thump

final class DashboardHeroPresentationTests: XCTestCase {

    func testNightPresentation_usesRestfulMoodForRecoveringScore() {
        let mood = DashboardHeroPresentation.mood(
            assessment: makeAssessment(status: .stable, stressFlag: false),
            readinessScore: 55,
            hour: 22
        )

        XCTAssertEqual(mood, .tired)
    }

    func testDayPresentation_keepsDaytimeMoodForRecoveringScore() {
        let mood = DashboardHeroPresentation.mood(
            assessment: makeAssessment(status: .stable, stressFlag: false),
            readinessScore: 55,
            hour: 10
        )

        XCTAssertEqual(mood, .nudging)
    }

    func testNightPresentation_usesRestfulMoodEvenWhenReadinessIsHigh() {
        let mood = DashboardHeroPresentation.mood(
            assessment: makeAssessment(status: .improving, stressFlag: false),
            readinessScore: 88,
            hour: 23
        )

        XCTAssertEqual(mood, .tired)
    }

    func testNightPresentation_preservesStressedMoodWhenStressIsHigh() {
        let mood = DashboardHeroPresentation.mood(
            assessment: makeAssessment(status: .needsAttention, stressFlag: true),
            readinessScore: 55,
            hour: 23
        )

        XCTAssertEqual(mood, .stressed)
    }

    private func makeAssessment(status: TrendStatus, stressFlag: Bool) -> HeartAssessment {
        let nudge = DailyNudge(
            category: .rest,
            title: "Rest",
            description: "Take it easy tonight.",
            durationMinutes: nil,
            icon: "bed.double.fill"
        )

        return HeartAssessment(
            status: status,
            confidence: .high,
            anomalyScore: stressFlag ? 2.0 : 0.2,
            regressionFlag: stressFlag,
            stressFlag: stressFlag,
            cardioScore: 60,
            dailyNudge: nudge,
            dailyNudges: [nudge],
            explanation: "Test assessment"
        )
    }
}

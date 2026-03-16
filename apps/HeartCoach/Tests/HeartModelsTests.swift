// HeartModelsTests.swift
// ThumpCoreTests
//
// Unit tests for core heart domain models — HeartSnapshot clamping,
// activityMinutes, NudgeCategory properties, ConfidenceLevel,
// WeeklyReport, CoachingScenario, and Codable conformance.

import XCTest
@testable import Thump

final class HeartModelsTests: XCTestCase {

    // MARK: - HeartSnapshot Clamping

    func testSnapshot_rhr_clampsToValidRange() {
        let snap = HeartSnapshot(date: Date(), restingHeartRate: 25) // below 30
        XCTAssertNil(snap.restingHeartRate, "RHR below 30 should be rejected (nil)")
    }

    func testSnapshot_rhr_clampsAboveMax() {
        let snap = HeartSnapshot(date: Date(), restingHeartRate: 250)
        XCTAssertEqual(snap.restingHeartRate, 220, "RHR above 220 should clamp to 220")
    }

    func testSnapshot_rhr_validValue_passesThrough() {
        let snap = HeartSnapshot(date: Date(), restingHeartRate: 65)
        XCTAssertEqual(snap.restingHeartRate, 65)
    }

    func testSnapshot_rhr_nil_staysNil() {
        let snap = HeartSnapshot(date: Date(), restingHeartRate: nil)
        XCTAssertNil(snap.restingHeartRate)
    }

    func testSnapshot_hrv_belowMinimum_returnsNil() {
        let snap = HeartSnapshot(date: Date(), hrvSDNN: 3) // below 5
        XCTAssertNil(snap.hrvSDNN)
    }

    func testSnapshot_hrv_aboveMaximum_clamps() {
        let snap = HeartSnapshot(date: Date(), hrvSDNN: 400) // above 300
        XCTAssertEqual(snap.hrvSDNN, 300)
    }

    func testSnapshot_vo2Max_belowMinimum_returnsNil() {
        let snap = HeartSnapshot(date: Date(), vo2Max: 5) // below 10
        XCTAssertNil(snap.vo2Max)
    }

    func testSnapshot_vo2Max_aboveMaximum_clamps() {
        let snap = HeartSnapshot(date: Date(), vo2Max: 95)
        XCTAssertEqual(snap.vo2Max, 90)
    }

    func testSnapshot_steps_negative_returnsNil() {
        let snap = HeartSnapshot(date: Date(), steps: -100)
        XCTAssertNil(snap.steps)
    }

    func testSnapshot_steps_aboveMaximum_clamps() {
        let snap = HeartSnapshot(date: Date(), steps: 300_000)
        XCTAssertEqual(snap.steps, 200_000)
    }

    func testSnapshot_sleepHours_aboveMaximum_clamps() {
        let snap = HeartSnapshot(date: Date(), sleepHours: 30)
        XCTAssertEqual(snap.sleepHours, 24)
    }

    func testSnapshot_bodyMassKg_belowMinimum_returnsNil() {
        let snap = HeartSnapshot(date: Date(), bodyMassKg: 10) // below 20
        XCTAssertNil(snap.bodyMassKg)
    }

    func testSnapshot_heightM_belowMinimum_returnsNil() {
        let snap = HeartSnapshot(date: Date(), heightM: 0.3) // below 0.5
        XCTAssertNil(snap.heightM)
    }

    func testSnapshot_heightM_aboveMaximum_clamps() {
        let snap = HeartSnapshot(date: Date(), heightM: 3.0) // above 2.5
        XCTAssertEqual(snap.heightM, 2.5)
    }

    func testSnapshot_zoneMinutes_clampsNegativeToZero() {
        let snap = HeartSnapshot(date: Date(), zoneMinutes: [-10, 30, 60])
        XCTAssertEqual(snap.zoneMinutes[0], 0)
        XCTAssertEqual(snap.zoneMinutes[1], 30)
        XCTAssertEqual(snap.zoneMinutes[2], 60)
    }

    func testSnapshot_zoneMinutes_clampsAbove1440() {
        let snap = HeartSnapshot(date: Date(), zoneMinutes: [2000])
        XCTAssertEqual(snap.zoneMinutes[0], 1440)
    }

    func testSnapshot_recoveryHR1m_validRange() {
        let snap = HeartSnapshot(date: Date(), recoveryHR1m: 50)
        XCTAssertEqual(snap.recoveryHR1m, 50)
    }

    func testSnapshot_recoveryHR1m_aboveMax_clamps() {
        let snap = HeartSnapshot(date: Date(), recoveryHR1m: 150) // above 100
        XCTAssertEqual(snap.recoveryHR1m, 100)
    }

    func testSnapshot_recoveryHR2m_aboveMax_clamps() {
        let snap = HeartSnapshot(date: Date(), recoveryHR2m: 200) // above 120
        XCTAssertEqual(snap.recoveryHR2m, 120)
    }

    // MARK: - HeartSnapshot activityMinutes

    func testActivityMinutes_bothPresent_addsThem() {
        let snap = HeartSnapshot(date: Date(), walkMinutes: 20, workoutMinutes: 30)
        XCTAssertEqual(snap.activityMinutes, 50)
    }

    func testActivityMinutes_walkOnly() {
        let snap = HeartSnapshot(date: Date(), walkMinutes: 25, workoutMinutes: nil)
        XCTAssertEqual(snap.activityMinutes, 25)
    }

    func testActivityMinutes_workoutOnly() {
        let snap = HeartSnapshot(date: Date(), walkMinutes: nil, workoutMinutes: 45)
        XCTAssertEqual(snap.activityMinutes, 45)
    }

    func testActivityMinutes_bothNil_returnsNil() {
        let snap = HeartSnapshot(date: Date(), walkMinutes: nil, workoutMinutes: nil)
        XCTAssertNil(snap.activityMinutes)
    }

    // MARK: - HeartSnapshot Identity

    func testSnapshot_id_isDate() {
        let date = Date()
        let snap = HeartSnapshot(date: date)
        XCTAssertEqual(snap.id, date)
    }

    // MARK: - HeartSnapshot Codable

    func testSnapshot_codableRoundTrip() throws {
        let original = HeartSnapshot(
            date: Date(),
            restingHeartRate: 62,
            hrvSDNN: 45,
            recoveryHR1m: 30,
            vo2Max: 42,
            zoneMinutes: [10, 20, 30, 15, 5],
            steps: 8500,
            walkMinutes: 40,
            workoutMinutes: 25,
            sleepHours: 7.5,
            bodyMassKg: 75,
            heightM: 1.78
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HeartSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - NudgeCategory

    func testNudgeCategory_allCases_haveIcons() {
        for cat in NudgeCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty, "\(cat) has empty icon")
        }
    }

    func testNudgeCategory_allCases_haveTintColorNames() {
        for cat in NudgeCategory.allCases {
            XCTAssertFalse(cat.tintColorName.isEmpty, "\(cat) has empty tint color")
        }
    }

    func testNudgeCategory_caseCount() {
        XCTAssertEqual(NudgeCategory.allCases.count, 8)
    }

    // MARK: - ConfidenceLevel

    func testConfidenceLevel_displayNames() {
        XCTAssertEqual(ConfidenceLevel.high.displayName, "Strong Pattern")
        XCTAssertEqual(ConfidenceLevel.medium.displayName, "Emerging Pattern")
        XCTAssertEqual(ConfidenceLevel.low.displayName, "Early Signal")
    }

    func testConfidenceLevel_icons() {
        XCTAssertEqual(ConfidenceLevel.high.icon, "checkmark.seal.fill")
        XCTAssertEqual(ConfidenceLevel.medium.icon, "exclamationmark.triangle")
        XCTAssertEqual(ConfidenceLevel.low.icon, "questionmark.circle")
    }

    func testConfidenceLevel_colorNames() {
        XCTAssertEqual(ConfidenceLevel.high.colorName, "confidenceHigh")
        XCTAssertEqual(ConfidenceLevel.medium.colorName, "confidenceMedium")
        XCTAssertEqual(ConfidenceLevel.low.colorName, "confidenceLow")
    }

    // MARK: - TrendStatus

    func testTrendStatus_allCases() {
        XCTAssertEqual(TrendStatus.allCases.count, 3)
        XCTAssertTrue(TrendStatus.allCases.contains(.improving))
        XCTAssertTrue(TrendStatus.allCases.contains(.stable))
        XCTAssertTrue(TrendStatus.allCases.contains(.needsAttention))
    }

    // MARK: - DailyFeedback

    func testDailyFeedback_allCases() {
        XCTAssertEqual(DailyFeedback.allCases.count, 3)
    }

    // MARK: - CoachingScenario

    func testCoachingScenario_allCases_haveMessages() {
        for scenario in CoachingScenario.allCases {
            XCTAssertFalse(scenario.coachingMessage.isEmpty, "\(scenario) has empty message")
        }
    }

    func testCoachingScenario_allCases_haveIcons() {
        for scenario in CoachingScenario.allCases {
            XCTAssertFalse(scenario.icon.isEmpty, "\(scenario) has empty icon")
        }
    }

    func testCoachingScenario_caseCount() {
        XCTAssertEqual(CoachingScenario.allCases.count, 6)
    }

    // MARK: - WeeklyTrendDirection

    func testWeeklyTrendDirection_displayTexts_nonEmpty() {
        let directions: [WeeklyTrendDirection] = [
            .significantImprovement, .improving, .stable, .elevated, .significantElevation
        ]
        for dir in directions {
            XCTAssertFalse(dir.displayText.isEmpty, "\(dir) has empty display text")
        }
    }

    func testWeeklyTrendDirection_icons_nonEmpty() {
        let directions: [WeeklyTrendDirection] = [
            .significantImprovement, .improving, .stable, .elevated, .significantElevation
        ]
        for dir in directions {
            XCTAssertFalse(dir.icon.isEmpty, "\(dir) has empty icon")
        }
    }

    // MARK: - RecoveryTrendDirection

    func testRecoveryTrendDirection_displayTexts_nonEmpty() {
        let directions: [RecoveryTrendDirection] = [.improving, .stable, .declining, .insufficientData]
        for dir in directions {
            XCTAssertFalse(dir.displayText.isEmpty, "\(dir) has empty display text")
        }
    }

    // MARK: - WeeklyReport

    func testWeeklyReport_trendDirectionCases() {
        XCTAssertEqual(WeeklyReport.TrendDirection.up.rawValue, "up")
        XCTAssertEqual(WeeklyReport.TrendDirection.flat.rawValue, "flat")
        XCTAssertEqual(WeeklyReport.TrendDirection.down.rawValue, "down")
    }

    func testWeeklyReport_codableRoundTrip() throws {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 7, to: start)!
        let report = WeeklyReport(
            weekStart: start,
            weekEnd: end,
            avgCardioScore: 75,
            trendDirection: .up,
            topInsight: "Your RHR dropped this week",
            nudgeCompletionRate: 0.8
        )
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(WeeklyReport.self, from: data)
        XCTAssertEqual(decoded, report)
    }

    // MARK: - RecoveryContext

    func testRecoveryContext_initialization() {
        let ctx = RecoveryContext(
            driver: "HRV",
            reason: "Your HRV is below baseline",
            tonightAction: "Aim for 10 PM bedtime",
            bedtimeTarget: "10 PM",
            readinessScore: 42
        )
        XCTAssertEqual(ctx.driver, "HRV")
        XCTAssertEqual(ctx.bedtimeTarget, "10 PM")
        XCTAssertEqual(ctx.readinessScore, 42)
    }

    func testRecoveryContext_codableRoundTrip() throws {
        let original = RecoveryContext(
            driver: "Sleep",
            reason: "Low sleep hours",
            tonightAction: "Go to bed earlier",
            readinessScore: 55
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecoveryContext.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - CorrelationResult

    func testCorrelationResult_id_isFactorName() {
        let result = CorrelationResult(
            factorName: "Daily Steps",
            correlationStrength: -0.65,
            interpretation: "More steps correlates with lower RHR",
            confidence: .high
        )
        XCTAssertEqual(result.id, "Daily Steps")
    }

    func testCorrelationResult_codableRoundTrip() throws {
        let original = CorrelationResult(
            factorName: "Sleep Hours",
            correlationStrength: 0.45,
            interpretation: "More sleep correlates with higher HRV",
            confidence: .medium,
            isBeneficial: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CorrelationResult.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - ConsecutiveElevationAlert

    func testConsecutiveElevationAlert_codableRoundTrip() throws {
        let original = ConsecutiveElevationAlert(
            consecutiveDays: 3,
            threshold: 72,
            elevatedMean: 75,
            personalMean: 65
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConsecutiveElevationAlert.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - DailyNudge

    func testDailyNudge_initialization() {
        let nudge = DailyNudge(
            category: .walk,
            title: "Take a Walk",
            description: "A 15-minute walk can help",
            durationMinutes: 15,
            icon: "figure.walk"
        )
        XCTAssertEqual(nudge.category, .walk)
        XCTAssertEqual(nudge.durationMinutes, 15)
    }

    // MARK: - HeartAssessment

    func testHeartAssessment_dailyNudgeText_withDuration() {
        let nudge = DailyNudge(
            category: .walk,
            title: "Walk",
            description: "Get moving",
            durationMinutes: 15,
            icon: "figure.walk"
        )
        let assessment = HeartAssessment(
            status: .improving,
            confidence: .high,
            anomalyScore: 0.2,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: 72,
            dailyNudge: nudge,
            explanation: "Looking good"
        )
        XCTAssertEqual(assessment.dailyNudgeText, "Walk (15 min): Get moving")
    }

    func testHeartAssessment_dailyNudgeText_withoutDuration() {
        let nudge = DailyNudge(
            category: .celebrate,
            title: "Great Day",
            description: "Keep it up",
            icon: "star.fill"
        )
        let assessment = HeartAssessment(
            status: .improving,
            confidence: .high,
            anomalyScore: 0,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: 85,
            dailyNudge: nudge,
            explanation: "Excellent"
        )
        XCTAssertEqual(assessment.dailyNudgeText, "Great Day: Keep it up")
    }

    func testHeartAssessment_dailyNudges_defaultsToSingleNudge() {
        let nudge = DailyNudge(
            category: .rest,
            title: "Rest",
            description: "Take it easy",
            icon: "bed.double.fill"
        )
        let assessment = HeartAssessment(
            status: .stable,
            confidence: .medium,
            anomalyScore: 0.5,
            regressionFlag: false,
            stressFlag: false,
            cardioScore: 60,
            dailyNudge: nudge,
            explanation: "Normal"
        )
        XCTAssertEqual(assessment.dailyNudges.count, 1)
        XCTAssertEqual(assessment.dailyNudges[0].title, "Rest")
    }
}

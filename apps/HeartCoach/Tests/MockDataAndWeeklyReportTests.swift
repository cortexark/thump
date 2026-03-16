// MockDataAndWeeklyReportTests.swift
// ThumpCoreTests
//
// Tests for MockData generators and WeeklyReport/WeeklyActionPlan models:
// verifying mock data produces valid snapshots, persona histories are
// realistic, and report/action plan types have correct structures.

import XCTest
@testable import Thump

final class MockDataAndWeeklyReportTests: XCTestCase {

    // MARK: - MockData.mockTodaySnapshot

    func testMockTodaySnapshot_hasValidMetrics() {
        let snapshot = MockData.mockTodaySnapshot
        XCTAssertNotNil(snapshot.restingHeartRate)
        XCTAssertNotNil(snapshot.hrvSDNN)
        XCTAssertFalse(snapshot.zoneMinutes.isEmpty)
    }

    func testMockTodaySnapshot_dateIsToday() {
        let snapshot = MockData.mockTodaySnapshot
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(snapshot.date),
            "Mock today snapshot should have today's date")
    }

    // MARK: - MockData.mockHistory

    func testMockHistory_correctCount() {
        let history = MockData.mockHistory(days: 7)
        XCTAssertEqual(history.count, 7)
    }

    func testMockHistory_orderedOldestFirst() {
        let history = MockData.mockHistory(days: 14)
        for i in 0..<(history.count - 1) {
            XCTAssertLessThan(history[i].date, history[i + 1].date,
                "History should be ordered oldest-first")
        }
    }

    func testMockHistory_lastDayIsToday() {
        let history = MockData.mockHistory(days: 7)
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(history.last!.date),
            "Last history day should be today")
    }

    func testMockHistory_cappedAt32Days() {
        let history = MockData.mockHistory(days: 100)
        XCTAssertLessThanOrEqual(history.count, 32,
            "Real data is capped at 32 days")
    }

    func testMockHistory_defaultIs21Days() {
        let history = MockData.mockHistory()
        XCTAssertEqual(history.count, 21)
    }

    // MARK: - MockData.sampleNudge

    func testSampleNudge_isWalkCategory() {
        let nudge = MockData.sampleNudge
        XCTAssertEqual(nudge.category, .walk)
        XCTAssertFalse(nudge.title.isEmpty)
        XCTAssertFalse(nudge.description.isEmpty)
    }

    // MARK: - MockData.sampleAssessment

    func testSampleAssessment_isStable() {
        let assessment = MockData.sampleAssessment
        XCTAssertEqual(assessment.status, .stable)
        XCTAssertEqual(assessment.confidence, .medium)
        XCTAssertFalse(assessment.regressionFlag)
        XCTAssertFalse(assessment.stressFlag)
        XCTAssertNotNil(assessment.cardioScore)
    }

    // MARK: - MockData.sampleProfile

    func testSampleProfile_isOnboarded() {
        let profile = MockData.sampleProfile
        XCTAssertTrue(profile.onboardingComplete)
        XCTAssertEqual(profile.displayName, "Alex")
        XCTAssertGreaterThan(profile.streakDays, 0)
    }

    // MARK: - MockData.sampleCorrelations

    func testSampleCorrelations_hasFourItems() {
        XCTAssertEqual(MockData.sampleCorrelations.count, 4)
    }

    func testSampleCorrelations_allHaveInterpretation() {
        for corr in MockData.sampleCorrelations {
            XCTAssertFalse(corr.interpretation.isEmpty)
            XCTAssertFalse(corr.factorName.isEmpty)
        }
    }

    // MARK: - Persona Histories

    func testPersonaHistory_allPersonas_produce30Days() {
        for persona in MockData.Persona.allCases {
            let history = MockData.personaHistory(persona, days: 30)
            XCTAssertEqual(history.count, 30,
                "\(persona.rawValue) should produce 30 days")
        }
    }

    func testPersonaHistory_hasRealisticRHR() {
        for persona in MockData.Persona.allCases {
            let history = MockData.personaHistory(persona, days: 10)
            let rhrs = history.compactMap(\.restingHeartRate)
            XCTAssertFalse(rhrs.isEmpty,
                "\(persona.rawValue) should have some RHR values")
            for rhr in rhrs {
                XCTAssertGreaterThanOrEqual(rhr, 40,
                    "\(persona.rawValue) RHR too low: \(rhr)")
                XCTAssertLessThanOrEqual(rhr, 100,
                    "\(persona.rawValue) RHR too high: \(rhr)")
            }
        }
    }

    func testPersonaHistory_stressEvent_affectsHRV() {
        let normalHistory = MockData.personaHistory(.normalMale, days: 30, includeStressEvent: false)
        let stressHistory = MockData.personaHistory(.normalMale, days: 30, includeStressEvent: true)

        // HRV around days 18-20 should be lower in stress version
        let normalHRVs = (18...20).compactMap { normalHistory[$0].hrvSDNN }
        let stressHRVs = (18...20).compactMap { stressHistory[$0].hrvSDNN }

        if !normalHRVs.isEmpty && !stressHRVs.isEmpty {
            let normalAvg = normalHRVs.reduce(0, +) / Double(normalHRVs.count)
            let stressAvg = stressHRVs.reduce(0, +) / Double(stressHRVs.count)
            XCTAssertLessThan(stressAvg, normalAvg,
                "Stress event should produce lower HRV during stress days")
        }
    }

    func testPersona_properties() {
        for persona in MockData.Persona.allCases {
            XCTAssertGreaterThan(persona.age, 0)
            XCTAssertGreaterThan(persona.bodyMassKg, 0)
            XCTAssertFalse(persona.displayName.isEmpty)
        }
    }

    func testPersona_sexAssignment() {
        XCTAssertEqual(MockData.Persona.athleticMale.sex, .male)
        XCTAssertEqual(MockData.Persona.athleticFemale.sex, .female)
        XCTAssertEqual(MockData.Persona.seniorActive.sex, .male)
    }

    // MARK: - WeeklyReport Model

    func testWeeklyReport_trendDirectionValues() {
        // Verify all three directions exist and have correct raw values
        XCTAssertEqual(WeeklyReport.TrendDirection.up.rawValue, "up")
        XCTAssertEqual(WeeklyReport.TrendDirection.flat.rawValue, "flat")
        XCTAssertEqual(WeeklyReport.TrendDirection.down.rawValue, "down")
    }

    func testWeeklyReport_sampleReport() {
        let report = MockData.sampleWeeklyReport
        XCTAssertNotNil(report.avgCardioScore)
        XCTAssertEqual(report.trendDirection, .up)
        XCTAssertFalse(report.topInsight.isEmpty)
        XCTAssertGreaterThan(report.nudgeCompletionRate, 0)
    }

    // MARK: - DailyNudge

    func testDailyNudge_init() {
        let nudge = DailyNudge(
            category: .breathe,
            title: "Breathe Deep",
            description: "Take 5 slow breaths",
            durationMinutes: 3,
            icon: "wind"
        )
        XCTAssertEqual(nudge.category, .breathe)
        XCTAssertEqual(nudge.title, "Breathe Deep")
        XCTAssertEqual(nudge.durationMinutes, 3)
    }

    func testDailyNudge_nilDuration() {
        let nudge = DailyNudge(
            category: .rest,
            title: "Rest",
            description: "Take it easy",
            durationMinutes: nil,
            icon: "bed.double.fill"
        )
        XCTAssertNil(nudge.durationMinutes)
    }

    // MARK: - CorrelationResult

    func testCorrelationResult_init() {
        let result = CorrelationResult(
            factorName: "Steps",
            correlationStrength: -0.45,
            interpretation: "More steps = lower RHR",
            confidence: .high
        )
        XCTAssertEqual(result.factorName, "Steps")
        XCTAssertEqual(result.correlationStrength, -0.45)
        XCTAssertEqual(result.confidence, .high)
    }
}

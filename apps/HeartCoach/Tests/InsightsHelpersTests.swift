// InsightsHelpersTests.swift
// ThumpCoreTests
//
// Unit tests for InsightsHelpers pure functions — hero text,
// action matching, focus targets, and date formatting.

import XCTest
@testable import Thump

final class InsightsHelpersTests: XCTestCase {

    // MARK: - Test Data Helpers

    private func makeReport(
        trend: WeeklyReport.TrendDirection = .up,
        topInsight: String = "Your resting heart rate dropped this week",
        avgScore: Double? = 72,
        completionRate: Double = 0.6
    ) -> WeeklyReport {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -7, to: end)!
        return WeeklyReport(
            weekStart: start,
            weekEnd: end,
            avgCardioScore: avgScore,
            trendDirection: trend,
            topInsight: topInsight,
            nudgeCompletionRate: completionRate
        )
    }

    private func makePlan(items: [WeeklyActionItem]) -> WeeklyActionPlan {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -7, to: end)!
        return WeeklyActionPlan(items: items, weekStart: start, weekEnd: end)
    }

    private func makeItem(
        category: WeeklyActionCategory,
        title: String,
        detail: String = "Some detail",
        reminderHour: Int? = nil
    ) -> WeeklyActionItem {
        WeeklyActionItem(
            category: category,
            title: title,
            detail: detail,
            icon: category.icon,
            colorName: category.defaultColorName,
            supportsReminder: reminderHour != nil,
            suggestedReminderHour: reminderHour
        )
    }

    // MARK: - heroSubtitle Tests

    func testHeroSubtitle_nilReport_returnsBuilding() {
        let result = InsightsHelpers.heroSubtitle(report: nil)
        XCTAssertEqual(result, "Building your first weekly report")
    }

    func testHeroSubtitle_trendUp_returnsMomentum() {
        let report = makeReport(trend: .up)
        let result = InsightsHelpers.heroSubtitle(report: report)
        XCTAssertEqual(result, "You're building momentum")
    }

    func testHeroSubtitle_trendFlat_returnsConsistency() {
        let report = makeReport(trend: .flat)
        let result = InsightsHelpers.heroSubtitle(report: report)
        XCTAssertEqual(result, "Consistency is your strength")
    }

    func testHeroSubtitle_trendDown_returnsSmallChanges() {
        let report = makeReport(trend: .down)
        let result = InsightsHelpers.heroSubtitle(report: report)
        XCTAssertEqual(result, "A few small changes can help")
    }

    // MARK: - heroInsightText Tests

    func testHeroInsightText_nilReport_returnsOnboardingMessage() {
        let result = InsightsHelpers.heroInsightText(report: nil)
        XCTAssertTrue(result.contains("Wear your Apple Watch"))
        XCTAssertTrue(result.contains("7 days"))
    }

    func testHeroInsightText_withReport_returnsTopInsight() {
        let insight = "Your sleep quality improved by 12% this week"
        let report = makeReport(topInsight: insight)
        let result = InsightsHelpers.heroInsightText(report: report)
        XCTAssertEqual(result, insight)
    }

    // MARK: - heroActionText Tests

    func testHeroActionText_nilPlan_returnsNil() {
        let result = InsightsHelpers.heroActionText(plan: nil, insightText: "anything")
        XCTAssertNil(result)
    }

    func testHeroActionText_emptyPlan_returnsNil() {
        let plan = makePlan(items: [])
        let result = InsightsHelpers.heroActionText(plan: plan, insightText: "anything")
        XCTAssertNil(result)
    }

    func testHeroActionText_sleepInsight_matchesSleepItem() {
        let sleepItem = makeItem(category: .sleep, title: "Wind Down Earlier")
        let activityItem = makeItem(category: .activity, title: "Walk More")
        let plan = makePlan(items: [activityItem, sleepItem])

        let result = InsightsHelpers.heroActionText(
            plan: plan,
            insightText: "Your sleep patterns are inconsistent"
        )
        XCTAssertEqual(result, "Wind Down Earlier")
    }

    func testHeroActionText_walkInsight_matchesActivityItem() {
        let sleepItem = makeItem(category: .sleep, title: "Wind Down Earlier")
        let activityItem = makeItem(category: .activity, title: "Walk 30 Minutes")
        let plan = makePlan(items: [sleepItem, activityItem])

        let result = InsightsHelpers.heroActionText(
            plan: plan,
            insightText: "Your daily step count dropped this week"
        )
        XCTAssertEqual(result, "Walk 30 Minutes")
    }

    func testHeroActionText_exerciseInsight_matchesActivityItem() {
        let activityItem = makeItem(category: .activity, title: "Active Minutes Goal")
        let plan = makePlan(items: [activityItem])

        let result = InsightsHelpers.heroActionText(
            plan: plan,
            insightText: "More exercise could improve your recovery"
        )
        XCTAssertEqual(result, "Active Minutes Goal")
    }

    func testHeroActionText_stressInsight_matchesBreatheItem() {
        let breatheItem = makeItem(category: .breathe, title: "Morning Breathing")
        let activityItem = makeItem(category: .activity, title: "Walk More")
        let plan = makePlan(items: [activityItem, breatheItem])

        let result = InsightsHelpers.heroActionText(
            plan: plan,
            insightText: "Your stress levels have been elevated"
        )
        XCTAssertEqual(result, "Morning Breathing")
    }

    func testHeroActionText_hrvInsight_matchesBreatheItem() {
        let breatheItem = makeItem(category: .breathe, title: "Breathe Session")
        let plan = makePlan(items: [breatheItem])

        let result = InsightsHelpers.heroActionText(
            plan: plan,
            insightText: "Your HRV dropped below your baseline"
        )
        XCTAssertEqual(result, "Breathe Session")
    }

    func testHeroActionText_recoveryInsight_matchesBreatheItem() {
        let breatheItem = makeItem(category: .breathe, title: "Evening Wind Down")
        let plan = makePlan(items: [breatheItem])

        let result = InsightsHelpers.heroActionText(
            plan: plan,
            insightText: "Your recovery rate has been declining"
        )
        XCTAssertEqual(result, "Evening Wind Down")
    }

    func testHeroActionText_noKeywordMatch_fallsBackToFirstItem() {
        let sunItem = makeItem(category: .sunlight, title: "Get Some Sun")
        let breatheItem = makeItem(category: .breathe, title: "Breathe")
        let plan = makePlan(items: [sunItem, breatheItem])

        let result = InsightsHelpers.heroActionText(
            plan: plan,
            insightText: "Your metrics look interesting this week"
        )
        XCTAssertEqual(result, "Get Some Sun", "Should fall back to first item when no keyword matches")
    }

    func testHeroActionText_activityInsight_matchesWalkTitle() {
        // Tests matching by title content, not just category
        let sleepItem = makeItem(category: .sleep, title: "Walk before bed")
        let plan = makePlan(items: [sleepItem])

        let result = InsightsHelpers.heroActionText(
            plan: plan,
            insightText: "Your activity levels dropped"
        )
        // "walk" in title should match activity-related insight even though category is .sleep
        XCTAssertEqual(result, "Walk before bed")
    }

    // MARK: - weeklyFocusTargets Tests

    func testWeeklyFocusTargets_allCategories_returns4Targets() {
        let items = [
            makeItem(category: .sleep, title: "Sleep", detail: "Sleep detail", reminderHour: 22),
            makeItem(category: .activity, title: "Activity", detail: "Activity detail"),
            makeItem(category: .breathe, title: "Breathe", detail: "Breathe detail"),
            makeItem(category: .sunlight, title: "Sunlight", detail: "Sunlight detail"),
        ]
        let plan = makePlan(items: items)
        let targets = InsightsHelpers.weeklyFocusTargets(from: plan)

        XCTAssertEqual(targets.count, 4)
        XCTAssertEqual(targets[0].title, "Bedtime Target")
        XCTAssertEqual(targets[1].title, "Activity Goal")
        XCTAssertEqual(targets[2].title, "Breathing Practice")
        XCTAssertEqual(targets[3].title, "Daylight Exposure")
    }

    func testWeeklyFocusTargets_sleepOnly_returns1Target() {
        let items = [makeItem(category: .sleep, title: "Sleep Better", detail: "Wind down earlier", reminderHour: 22)]
        let plan = makePlan(items: items)
        let targets = InsightsHelpers.weeklyFocusTargets(from: plan)

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets[0].title, "Bedtime Target")
        XCTAssertEqual(targets[0].reason, "Wind down earlier")
        XCTAssertEqual(targets[0].icon, "moon.stars.fill")
        XCTAssertEqual(targets[0].targetValue, "10 PM")
    }

    func testWeeklyFocusTargets_noMatchingCategories_returnsEmpty() {
        let items = [makeItem(category: .hydrate, title: "Drink Water")]
        let plan = makePlan(items: items)
        let targets = InsightsHelpers.weeklyFocusTargets(from: plan)

        XCTAssertEqual(targets.count, 0, "Hydrate is not one of the 4 target categories")
    }

    func testWeeklyFocusTargets_activityTarget_has30MinValue() {
        let items = [makeItem(category: .activity, title: "Move More", detail: "Get moving")]
        let plan = makePlan(items: items)
        let targets = InsightsHelpers.weeklyFocusTargets(from: plan)

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets[0].targetValue, "30 min")
    }

    func testWeeklyFocusTargets_breatheTarget_has5MinValue() {
        let items = [makeItem(category: .breathe, title: "Breathe", detail: "Calm down")]
        let plan = makePlan(items: items)
        let targets = InsightsHelpers.weeklyFocusTargets(from: plan)

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets[0].targetValue, "5 min")
    }

    func testWeeklyFocusTargets_sunlightTarget_has3WindowsValue() {
        let items = [makeItem(category: .sunlight, title: "Sun", detail: "Go outside")]
        let plan = makePlan(items: items)
        let targets = InsightsHelpers.weeklyFocusTargets(from: plan)

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets[0].targetValue, "3 windows")
    }

    func testWeeklyFocusTargets_sleepNoReminderHour_targetValueIsNil() {
        let items = [makeItem(category: .sleep, title: "Sleep", detail: "Detail", reminderHour: nil)]
        let plan = makePlan(items: items)
        let targets = InsightsHelpers.weeklyFocusTargets(from: plan)

        XCTAssertEqual(targets.count, 1)
        XCTAssertNil(targets[0].targetValue, "No reminder hour means no target value for sleep")
    }

    // MARK: - reportDateRange Tests

    func testReportDateRange_formatsCorrectly() {
        let cal = Calendar.current
        var startComponents = DateComponents()
        startComponents.year = 2026
        startComponents.month = 3
        startComponents.day = 8
        var endComponents = DateComponents()
        endComponents.year = 2026
        endComponents.month = 3
        endComponents.day = 14

        let start = cal.date(from: startComponents)!
        let end = cal.date(from: endComponents)!

        let report = WeeklyReport(
            weekStart: start,
            weekEnd: end,
            avgCardioScore: 70,
            trendDirection: .up,
            topInsight: "test",
            nudgeCompletionRate: 0.5
        )

        let result = InsightsHelpers.reportDateRange(report)
        XCTAssertEqual(result, "Mar 8 - Mar 14")
    }
}

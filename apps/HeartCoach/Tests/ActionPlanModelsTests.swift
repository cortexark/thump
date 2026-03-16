// ActionPlanModelsTests.swift
// ThumpCoreTests
//
// Unit tests for action plan domain models — WeeklyActionCategory,
// SunlightSlot, SunlightWindow tips, CheckInMood scores,
// and WeeklyActionPlan construction.

import XCTest
@testable import Thump

final class ActionPlanModelsTests: XCTestCase {

    // MARK: - WeeklyActionCategory

    func testWeeklyActionCategory_allCases_count() {
        XCTAssertEqual(WeeklyActionCategory.allCases.count, 5)
    }

    func testWeeklyActionCategory_icons_nonEmpty() {
        for cat in WeeklyActionCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty, "\(cat) has empty icon")
        }
    }

    func testWeeklyActionCategory_defaultColorNames_nonEmpty() {
        for cat in WeeklyActionCategory.allCases {
            XCTAssertFalse(cat.defaultColorName.isEmpty, "\(cat) has empty color name")
        }
    }

    func testWeeklyActionCategory_specificIcons() {
        XCTAssertEqual(WeeklyActionCategory.sleep.icon, "moon.stars.fill")
        XCTAssertEqual(WeeklyActionCategory.breathe.icon, "wind")
        XCTAssertEqual(WeeklyActionCategory.activity.icon, "figure.walk")
        XCTAssertEqual(WeeklyActionCategory.sunlight.icon, "sun.max.fill")
        XCTAssertEqual(WeeklyActionCategory.hydrate.icon, "drop.fill")
    }

    // MARK: - SunlightSlot

    func testSunlightSlot_allCases_count() {
        XCTAssertEqual(SunlightSlot.allCases.count, 3)
    }

    func testSunlightSlot_labels_nonEmpty() {
        for slot in SunlightSlot.allCases {
            XCTAssertFalse(slot.label.isEmpty, "\(slot) has empty label")
        }
    }

    func testSunlightSlot_defaultHours() {
        XCTAssertEqual(SunlightSlot.morning.defaultHour, 7)
        XCTAssertEqual(SunlightSlot.lunch.defaultHour, 12)
        XCTAssertEqual(SunlightSlot.evening.defaultHour, 17)
    }

    func testSunlightSlot_icons() {
        XCTAssertEqual(SunlightSlot.morning.icon, "sunrise.fill")
        XCTAssertEqual(SunlightSlot.lunch.icon, "sun.max.fill")
        XCTAssertEqual(SunlightSlot.evening.icon, "sunset.fill")
    }

    func testSunlightSlot_tip_withObservedMovement() {
        let morningTip = SunlightSlot.morning.tip(hasObservedMovement: true)
        XCTAssertTrue(morningTip.contains("already move"), "Morning tip with movement should acknowledge existing habit")

        let lunchTip = SunlightSlot.lunch.tip(hasObservedMovement: true)
        XCTAssertTrue(lunchTip.contains("tend to move"), "Lunch tip with movement should acknowledge existing habit")

        let eveningTip = SunlightSlot.evening.tip(hasObservedMovement: true)
        XCTAssertTrue(eveningTip.contains("movement detected"), "Evening tip with movement should acknowledge it")
    }

    func testSunlightSlot_tip_withoutObservedMovement() {
        let morningTip = SunlightSlot.morning.tip(hasObservedMovement: false)
        XCTAssertTrue(morningTip.contains("5 minutes"), "Morning tip without movement should suggest trying")

        let lunchTip = SunlightSlot.lunch.tip(hasObservedMovement: false)
        XCTAssertTrue(lunchTip.contains("potent"), "Lunch tip without movement should motivate")

        let eveningTip = SunlightSlot.evening.tip(hasObservedMovement: false)
        XCTAssertTrue(eveningTip.contains("wind down"), "Evening tip without movement should explain benefit")
    }

    // MARK: - SunlightWindow

    func testSunlightWindow_label_delegatesToSlot() {
        let window = SunlightWindow(slot: .lunch, reminderHour: 12, hasObservedMovement: true)
        XCTAssertEqual(window.label, SunlightSlot.lunch.label)
    }

    func testSunlightWindow_tip_delegatesToSlot() {
        let window = SunlightWindow(slot: .morning, reminderHour: 7, hasObservedMovement: false)
        XCTAssertEqual(window.tip, SunlightSlot.morning.tip(hasObservedMovement: false))
    }

    // MARK: - CheckInMood

    func testCheckInMood_allCases_haveScores() {
        let moods = CheckInMood.allCases
        XCTAssertEqual(moods.count, 4)
        for mood in moods {
            XCTAssertTrue(mood.score >= 1 && mood.score <= 4,
                          "\(mood) score \(mood.score) not in 1-4 range")
        }
    }

    func testCheckInMood_scores_areUnique() {
        let scores = CheckInMood.allCases.map(\.score)
        XCTAssertEqual(Set(scores).count, scores.count, "Mood scores should be unique")
    }

    func testCheckInMood_scores_ordering() {
        XCTAssertEqual(CheckInMood.great.score, 4)
        XCTAssertEqual(CheckInMood.good.score, 3)
        XCTAssertEqual(CheckInMood.okay.score, 2)
        XCTAssertEqual(CheckInMood.rough.score, 1)
    }

    func testCheckInMood_labels_nonEmpty() {
        for mood in CheckInMood.allCases {
            XCTAssertFalse(mood.label.isEmpty)
        }
    }

    func testCheckInMood_emojis_nonEmpty() {
        for mood in CheckInMood.allCases {
            XCTAssertFalse(mood.emoji.isEmpty)
        }
    }

    // MARK: - CheckInResponse Codable

    func testCheckInResponse_codableRoundTrip() throws {
        let original = CheckInResponse(date: Date(), feelingScore: 4, note: "Feeling great!")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CheckInResponse.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCheckInResponse_withNilNote_codableRoundTrip() throws {
        let original = CheckInResponse(date: Date(), feelingScore: 2, note: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CheckInResponse.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - WeeklyActionItem

    func testWeeklyActionItem_initialization() {
        let item = WeeklyActionItem(
            category: .sleep,
            title: "Wind Down",
            detail: "Aim for bed by 10 PM",
            icon: "moon.stars.fill",
            colorName: "nudgeRest",
            supportsReminder: true,
            suggestedReminderHour: 21
        )
        XCTAssertEqual(item.category, .sleep)
        XCTAssertEqual(item.title, "Wind Down")
        XCTAssertTrue(item.supportsReminder)
        XCTAssertEqual(item.suggestedReminderHour, 21)
        XCTAssertNil(item.sunlightWindows)
    }

    func testWeeklyActionItem_withSunlightWindows() {
        let windows = [
            SunlightWindow(slot: .morning, reminderHour: 7, hasObservedMovement: true),
            SunlightWindow(slot: .lunch, reminderHour: 12, hasObservedMovement: false),
        ]
        let item = WeeklyActionItem(
            category: .sunlight,
            title: "Get Some Sun",
            detail: "3 windows of sunlight",
            icon: "sun.max.fill",
            colorName: "nudgeCelebrate",
            sunlightWindows: windows
        )
        XCTAssertEqual(item.sunlightWindows?.count, 2)
    }

    // MARK: - WeeklyActionPlan

    func testWeeklyActionPlan_emptyItems() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 7, to: start)!
        let plan = WeeklyActionPlan(items: [], weekStart: start, weekEnd: end)
        XCTAssertEqual(plan.items.count, 0)
    }
}

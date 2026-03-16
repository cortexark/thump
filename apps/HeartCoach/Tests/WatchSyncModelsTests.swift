// WatchSyncModelsTests.swift
// ThumpCoreTests
//
// Unit tests for watch sync domain models — QuickLogCategory properties,
// WatchActionPlan mock, QuickLogEntry, and Codable round-trips.

import XCTest
@testable import Thump

final class WatchSyncModelsTests: XCTestCase {

    // MARK: - QuickLogCategory

    func testQuickLogCategory_allCases_count() {
        XCTAssertEqual(QuickLogCategory.allCases.count, 7)
    }

    func testQuickLogCategory_isCounter_waterCaffeineAlcohol() {
        XCTAssertTrue(QuickLogCategory.water.isCounter)
        XCTAssertTrue(QuickLogCategory.caffeine.isCounter)
        XCTAssertTrue(QuickLogCategory.alcohol.isCounter)
    }

    func testQuickLogCategory_isCounter_othersFalse() {
        XCTAssertFalse(QuickLogCategory.sunlight.isCounter)
        XCTAssertFalse(QuickLogCategory.meditate.isCounter)
        XCTAssertFalse(QuickLogCategory.activity.isCounter)
        XCTAssertFalse(QuickLogCategory.mood.isCounter)
    }

    func testQuickLogCategory_icons_nonEmpty() {
        for cat in QuickLogCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty, "\(cat) has empty icon")
        }
    }

    func testQuickLogCategory_labels_nonEmpty() {
        for cat in QuickLogCategory.allCases {
            XCTAssertFalse(cat.label.isEmpty, "\(cat) has empty label")
        }
    }

    func testQuickLogCategory_unit_countersHaveUnits() {
        XCTAssertEqual(QuickLogCategory.water.unit, "cups")
        XCTAssertEqual(QuickLogCategory.caffeine.unit, "cups")
        XCTAssertEqual(QuickLogCategory.alcohol.unit, "drinks")
    }

    func testQuickLogCategory_unit_nonCountersHaveEmptyUnit() {
        XCTAssertEqual(QuickLogCategory.sunlight.unit, "")
        XCTAssertEqual(QuickLogCategory.meditate.unit, "")
        XCTAssertEqual(QuickLogCategory.activity.unit, "")
        XCTAssertEqual(QuickLogCategory.mood.unit, "")
    }

    func testQuickLogCategory_tintColorHex_allNonZero() {
        for cat in QuickLogCategory.allCases {
            XCTAssertTrue(cat.tintColorHex > 0, "\(cat) has zero color hex")
        }
    }

    func testQuickLogCategory_tintColorHex_allUnique() {
        let hexes = QuickLogCategory.allCases.map(\.tintColorHex)
        XCTAssertEqual(Set(hexes).count, hexes.count, "All category colors should be unique")
    }

    func testQuickLogCategory_codableRoundTrip() throws {
        for cat in QuickLogCategory.allCases {
            let data = try JSONEncoder().encode(cat)
            let decoded = try JSONDecoder().decode(QuickLogCategory.self, from: data)
            XCTAssertEqual(decoded, cat)
        }
    }

    // MARK: - QuickLogEntry

    func testQuickLogEntry_defaults() {
        let entry = QuickLogEntry(category: .water)
        XCTAssertEqual(entry.category, .water)
        XCTAssertEqual(entry.source, "watch")
        XCTAssertFalse(entry.eventId.isEmpty)
    }

    func testQuickLogEntry_codableRoundTrip() throws {
        let original = QuickLogEntry(
            eventId: "test-123",
            date: Date(),
            category: .caffeine,
            source: "phone"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(QuickLogEntry.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testQuickLogEntry_equality() {
        let date = Date()
        let a = QuickLogEntry(eventId: "id1", date: date, category: .water, source: "watch")
        let b = QuickLogEntry(eventId: "id1", date: date, category: .water, source: "watch")
        let c = QuickLogEntry(eventId: "id2", date: date, category: .water, source: "watch")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - WatchActionPlan Mock

    func testWatchActionPlan_mock_has4Items() {
        let mock = WatchActionPlan.mock
        XCTAssertEqual(mock.dailyItems.count, 4)
    }

    func testWatchActionPlan_mock_hasWeeklyData() {
        let mock = WatchActionPlan.mock
        XCTAssertFalse(mock.weeklyHeadline.isEmpty)
        XCTAssertNotNil(mock.weeklyAvgScore)
        XCTAssertEqual(mock.weeklyActiveDays, 5)
    }

    func testWatchActionPlan_mock_hasMonthlyData() {
        let mock = WatchActionPlan.mock
        XCTAssertFalse(mock.monthlyHeadline.isEmpty)
        XCTAssertFalse(mock.monthName.isEmpty)
    }

    func testWatchActionPlan_codableRoundTrip() throws {
        let original = WatchActionPlan(
            dailyItems: [
                WatchActionItem(
                    category: .walk,
                    title: "Walk 20 min",
                    detail: "Your step count dropped",
                    icon: "figure.walk"
                )
            ],
            weeklyHeadline: "Good week!",
            weeklyAvgScore: 75,
            weeklyActiveDays: 4,
            weeklyLowStressDays: 3,
            monthlyHeadline: "Best month!",
            monthlyScoreDelta: 5,
            monthName: "March"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchActionPlan.self, from: data)
        XCTAssertEqual(decoded.dailyItems.count, original.dailyItems.count)
        XCTAssertEqual(decoded.weeklyHeadline, original.weeklyHeadline)
        XCTAssertEqual(decoded.monthName, original.monthName)
    }

    // MARK: - WatchActionItem

    func testWatchActionItem_codableRoundTrip() throws {
        let original = WatchActionItem(
            category: .breathe,
            title: "Morning Breathe",
            detail: "3 min box breathing",
            icon: "wind",
            reminderHour: 7
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchActionItem.self, from: data)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.reminderHour, 7)
    }

    func testWatchActionItem_nilReminderHour() {
        let item = WatchActionItem(
            category: .sunlight,
            title: "Step Outside",
            detail: "Get some sun",
            icon: "sun.max.fill"
        )
        XCTAssertNil(item.reminderHour)
    }
}

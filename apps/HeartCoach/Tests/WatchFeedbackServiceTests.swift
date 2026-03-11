// WatchFeedbackServiceTests.swift
// ThumpCoreTests
//
// Unit tests for WatchFeedbackService.
// Validates date-keyed storage on the watch side.
// Platforms: iOS 17+, watchOS 10+

import XCTest
@testable import Thump

// MARK: - WatchFeedbackService Tests

final class WatchFeedbackServiceTests: XCTestCase {

    // MARK: - Properties

    private var service: WatchFeedbackService?
    private var testDefaults: UserDefaults?

    // MARK: - Lifecycle

    @MainActor
    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(
            suiteName: "com.thump.test.watch.\(UUID().uuidString)"
        )
        testDefaults = defaults
        if let defaults {
            service = WatchFeedbackService(defaults: defaults)
        }
    }

    override func tearDown() {
        service = nil
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Save and Load

    /// Saving feedback for today should be loadable.
    @MainActor
    func testSaveAndLoadFeedbackForToday() throws {
        let svc = try XCTUnwrap(service)
        svc.saveFeedback(.positive, for: Date())
        let loaded = svc.loadFeedback(for: Date())
        XCTAssertEqual(loaded, .positive)
    }

    /// Saving feedback for a past date should not affect todayFeedback.
    @MainActor
    func testSaveFeedbackForPastDateDoesNotAffectToday() throws {
        let svc = try XCTUnwrap(service)
        let yesterday = try XCTUnwrap(
            Calendar.current.date(byAdding: .day, value: -1, to: Date())
        )
        svc.saveFeedback(.negative, for: yesterday)
        XCTAssertNil(
            svc.todayFeedback,
            "Saving for a past date should not update todayFeedback"
        )
    }

    /// Saving feedback for today should update the published todayFeedback.
    @MainActor
    func testSaveFeedbackForTodayUpdatesPublished() throws {
        let svc = try XCTUnwrap(service)
        XCTAssertNil(svc.todayFeedback, "Should start nil")
        svc.saveFeedback(.skipped, for: Date())
        XCTAssertEqual(svc.todayFeedback, .skipped)
    }

    // MARK: - Has Feedback Today

    /// hasFeedbackToday should return false initially.
    @MainActor
    func testHasFeedbackTodayInitiallyFalse() throws {
        let svc = try XCTUnwrap(service)
        XCTAssertFalse(svc.hasFeedbackToday())
    }

    /// hasFeedbackToday should return true after saving feedback.
    @MainActor
    func testHasFeedbackTodayTrueAfterSave() throws {
        let svc = try XCTUnwrap(service)
        svc.saveFeedback(.positive, for: Date())
        XCTAssertTrue(svc.hasFeedbackToday())
    }

    // MARK: - Date Isolation

    /// Feedback for different dates should be isolated.
    @MainActor
    func testFeedbackIsolatedByDate() throws {
        let svc = try XCTUnwrap(service)
        let today = Date()
        let yesterday = try XCTUnwrap(
            Calendar.current.date(byAdding: .day, value: -1, to: today)
        )
        let twoDaysAgo = try XCTUnwrap(
            Calendar.current.date(byAdding: .day, value: -2, to: today)
        )

        svc.saveFeedback(.positive, for: today)
        svc.saveFeedback(.negative, for: yesterday)
        svc.saveFeedback(.skipped, for: twoDaysAgo)

        XCTAssertEqual(svc.loadFeedback(for: today), .positive)
        XCTAssertEqual(svc.loadFeedback(for: yesterday), .negative)
        XCTAssertEqual(svc.loadFeedback(for: twoDaysAgo), .skipped)
    }

    /// Loading feedback for a date with no entry should return nil.
    @MainActor
    func testLoadFeedbackReturnsNilForMissingDate() throws {
        let svc = try XCTUnwrap(service)
        let futureDate = try XCTUnwrap(
            Calendar.current.date(byAdding: .day, value: 30, to: Date())
        )
        XCTAssertNil(svc.loadFeedback(for: futureDate))
    }

    // MARK: - Overwrite

    /// Saving new feedback for the same date should overwrite.
    @MainActor
    func testOverwriteFeedbackForSameDate() throws {
        let svc = try XCTUnwrap(service)
        svc.saveFeedback(.positive, for: Date())
        svc.saveFeedback(.negative, for: Date())
        XCTAssertEqual(svc.loadFeedback(for: Date()), .negative)
    }
}

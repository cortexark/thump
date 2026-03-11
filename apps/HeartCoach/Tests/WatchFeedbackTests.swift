// WatchFeedbackTests.swift
// ThumpCoreTests
//
// Unit tests for WatchFeedbackBridge and WatchFeedbackService.
// Validates deduplication, pruning, feedback persistence,
// and date-keyed storage on the watch side.
// Platforms: iOS 17+, watchOS 10+

import XCTest
@testable import ThumpCore

// MARK: - WatchFeedbackBridge Tests

final class WatchFeedbackBridgeTests: XCTestCase {

    // MARK: - Properties

    // swiftlint:disable:next implicitly_unwrapped_optional
    private var bridge: WatchFeedbackBridge!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        bridge = WatchFeedbackBridge()
    }

    override func tearDown() {
        bridge = nil
        super.tearDown()
    }

    // MARK: - Basic Processing

    /// Processing a single feedback should add it to pending.
    func testProcessSingleFeedback() {
        let payload = makePayload(eventId: "evt-001", response: .positive)
        bridge.processFeedback(payload)

        XCTAssertEqual(bridge.pendingFeedback.count, 1)
        XCTAssertEqual(bridge.pendingFeedback.first?.eventId, "evt-001")
    }

    /// Processing multiple unique feedbacks should add all to pending.
    func testProcessMultipleUniqueFeedbacks() {
        for i in 1...5 {
            bridge.processFeedback(makePayload(eventId: "evt-\(i)", response: .positive))
        }
        XCTAssertEqual(bridge.pendingFeedback.count, 5)
    }

    // MARK: - Deduplication

    /// Processing the same eventId twice should only add it once.
    func testDeduplicatesByEventId() {
        let payload = makePayload(eventId: "evt-dup", response: .positive)
        bridge.processFeedback(payload)
        bridge.processFeedback(payload)

        XCTAssertEqual(bridge.pendingFeedback.count, 1,
                       "Duplicate eventId should be rejected")
    }

    /// Different eventIds with same content should both be accepted.
    func testDifferentEventIdsAreNotDeduplicated() {
        let payload1 = makePayload(eventId: "evt-a", response: .positive)
        let payload2 = makePayload(eventId: "evt-b", response: .positive)

        bridge.processFeedback(payload1)
        bridge.processFeedback(payload2)

        XCTAssertEqual(bridge.pendingFeedback.count, 2)
    }

    // MARK: - Pruning

    /// Exceeding maxPendingCount (50) should prune oldest entries.
    func testPrunesOldestWhenExceedingMax() {
        for i in 1...55 {
            let date = Date().addingTimeInterval(TimeInterval(i * 60))
            bridge.processFeedback(makePayload(
                eventId: "evt-\(i)",
                response: .positive,
                date: date
            ))
        }

        XCTAssertEqual(bridge.pendingFeedback.count, 50,
                       "Should prune to maxPendingCount of 50")

        // Oldest 5 should have been pruned
        let eventIds = bridge.pendingFeedback.map(\.eventId)
        XCTAssertFalse(eventIds.contains("evt-1"), "Oldest entry should be pruned")
        XCTAssertTrue(eventIds.contains("evt-55"), "Newest entry should be retained")
    }

    // MARK: - Sorting

    /// Pending feedback should be sorted by date ascending.
    func testPendingFeedbackSortedByDate() {
        let date1 = Date()
        let date2 = date1.addingTimeInterval(-3600) // 1 hour earlier
        let date3 = date1.addingTimeInterval(3600)  // 1 hour later

        bridge.processFeedback(makePayload(eventId: "evt-now", response: .positive, date: date1))
        bridge.processFeedback(makePayload(eventId: "evt-past", response: .negative, date: date2))
        bridge.processFeedback(makePayload(eventId: "evt-future", response: .skipped, date: date3))

        XCTAssertEqual(bridge.pendingFeedback.first?.eventId, "evt-past")
        XCTAssertEqual(bridge.pendingFeedback.last?.eventId, "evt-future")
    }

    // MARK: - Latest Feedback

    /// latestFeedback should return the most recent pending response.
    func testLatestFeedbackReturnsNewest() {
        let earlier = Date()
        let later = earlier.addingTimeInterval(3600)

        bridge.processFeedback(makePayload(eventId: "evt-1", response: .negative, date: earlier))
        bridge.processFeedback(makePayload(eventId: "evt-2", response: .positive, date: later))

        XCTAssertEqual(bridge.latestFeedback(), .positive)
    }

    /// latestFeedback should return nil when no pending feedback exists.
    func testLatestFeedbackReturnsNilWhenEmpty() {
        XCTAssertNil(bridge.latestFeedback())
    }

    // MARK: - Clear Processed

    /// clearProcessed should remove all pending items.
    func testClearProcessedRemovesPending() {
        bridge.processFeedback(makePayload(eventId: "evt-1", response: .positive))
        bridge.processFeedback(makePayload(eventId: "evt-2", response: .negative))

        bridge.clearProcessed()

        XCTAssertTrue(bridge.pendingFeedback.isEmpty)
    }

    /// clearProcessed should retain deduplication history.
    func testClearProcessedRetainsDedupHistory() {
        let payload = makePayload(eventId: "evt-dedup", response: .positive)
        bridge.processFeedback(payload)
        bridge.clearProcessed()

        // Re-processing same eventId should still be rejected
        bridge.processFeedback(payload)
        XCTAssertTrue(bridge.pendingFeedback.isEmpty,
                      "Dedup history should survive clearProcessed")
    }

    // MARK: - Reset All

    /// resetAll should clear both pending and dedup history.
    func testResetAllClearsEverything() {
        let payload = makePayload(eventId: "evt-reset", response: .positive)
        bridge.processFeedback(payload)
        bridge.resetAll()

        XCTAssertTrue(bridge.pendingFeedback.isEmpty)
        XCTAssertEqual(bridge.totalProcessedCount, 0)

        // Same eventId should now be accepted again
        bridge.processFeedback(payload)
        XCTAssertEqual(bridge.pendingFeedback.count, 1,
                       "After resetAll, previously seen eventIds should be accepted")
    }

    // MARK: - Total Processed Count

    /// totalProcessedCount should track all unique eventIds ever seen.
    func testTotalProcessedCountTracksUnique() {
        bridge.processFeedback(makePayload(eventId: "evt-1", response: .positive))
        bridge.processFeedback(makePayload(eventId: "evt-1", response: .positive)) // dup
        bridge.processFeedback(makePayload(eventId: "evt-2", response: .negative))

        XCTAssertEqual(bridge.totalProcessedCount, 2)
    }
}

// MARK: - WatchFeedbackService Tests

final class WatchFeedbackServiceTests: XCTestCase {

    // MARK: - Properties

    // swiftlint:disable:next implicitly_unwrapped_optional
    private var service: WatchFeedbackService!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var testDefaults: UserDefaults!

    // MARK: - Lifecycle

    @MainActor
    override func setUp() {
        super.setUp()
        // swiftlint:disable:next force_unwrapping
        testDefaults = UserDefaults(suiteName: "com.thump.test.watch.\(UUID().uuidString)")!
        service = WatchFeedbackService(defaults: testDefaults)
    }

    override func tearDown() {
        service = nil
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Save and Load

    /// Saving feedback for today should be loadable.
    @MainActor
    func testSaveAndLoadFeedbackForToday() {
        service.saveFeedback(.positive, for: Date())
        let loaded = service.loadFeedback(for: Date())
        XCTAssertEqual(loaded, .positive)
    }

    /// Saving feedback for a past date should not affect todayFeedback.
    @MainActor
    func testSaveFeedbackForPastDateDoesNotAffectToday() {
        // swiftlint:disable:next force_unwrapping
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        service.saveFeedback(.negative, for: yesterday)
        XCTAssertNil(service.todayFeedback,
                     "Saving for a past date should not update todayFeedback")
    }

    /// Saving feedback for today should update the published todayFeedback.
    @MainActor
    func testSaveFeedbackForTodayUpdatesPublished() {
        XCTAssertNil(service.todayFeedback, "Should start nil")
        service.saveFeedback(.skipped, for: Date())
        XCTAssertEqual(service.todayFeedback, .skipped)
    }

    // MARK: - Has Feedback Today

    /// hasFeedbackToday should return false initially.
    @MainActor
    func testHasFeedbackTodayInitiallyFalse() {
        XCTAssertFalse(service.hasFeedbackToday())
    }

    /// hasFeedbackToday should return true after saving feedback.
    @MainActor
    func testHasFeedbackTodayTrueAfterSave() {
        service.saveFeedback(.positive, for: Date())
        XCTAssertTrue(service.hasFeedbackToday())
    }

    // MARK: - Date Isolation

    /// Feedback for different dates should be isolated.
    @MainActor
    func testFeedbackIsolatedByDate() {
        let today = Date()
        // swiftlint:disable:next force_unwrapping
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        // swiftlint:disable:next force_unwrapping
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

        service.saveFeedback(.positive, for: today)
        service.saveFeedback(.negative, for: yesterday)
        service.saveFeedback(.skipped, for: twoDaysAgo)

        XCTAssertEqual(service.loadFeedback(for: today), .positive)
        XCTAssertEqual(service.loadFeedback(for: yesterday), .negative)
        XCTAssertEqual(service.loadFeedback(for: twoDaysAgo), .skipped)
    }

    /// Loading feedback for a date with no entry should return nil.
    @MainActor
    func testLoadFeedbackReturnsNilForMissingDate() {
        // swiftlint:disable:next force_unwrapping
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        XCTAssertNil(service.loadFeedback(for: futureDate))
    }

    // MARK: - Overwrite

    /// Saving new feedback for the same date should overwrite.
    @MainActor
    func testOverwriteFeedbackForSameDate() {
        service.saveFeedback(.positive, for: Date())
        service.saveFeedback(.negative, for: Date())
        XCTAssertEqual(service.loadFeedback(for: Date()), .negative)
    }
}

// MARK: - Test Helpers

extension WatchFeedbackBridgeTests {
    private func makePayload(
        eventId: String,
        response: DailyFeedback,
        date: Date = Date()
    ) -> WatchFeedbackPayload {
        WatchFeedbackPayload(
            eventId: eventId,
            date: date,
            response: response,
            source: "test"
        )
    }
}

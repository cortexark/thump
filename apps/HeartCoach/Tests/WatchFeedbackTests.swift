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
        let payload = makePayload(eventId: "evt-001", response: .good)
        bridge.processFeedback(payload)

        XCTAssertEqual(bridge.pendingFeedback.count, 1)
        XCTAssertEqual(bridge.pendingFeedback.first?.eventId, "evt-001")
    }

    /// Processing multiple unique feedbacks should add all to pending.
    func testProcessMultipleUniqueFeedbacks() {
        for i in 1...5 {
            bridge.processFeedback(makePayload(eventId: "evt-\(i)", response: .good))
        }
        XCTAssertEqual(bridge.pendingFeedback.count, 5)
    }

    // MARK: - Deduplication

    /// Processing the same eventId twice should only add it once.
    func testDeduplicatesByEventId() {
        let payload = makePayload(eventId: "evt-dup", response: .good)
        bridge.processFeedback(payload)
        bridge.processFeedback(payload)

        XCTAssertEqual(bridge.pendingFeedback.count, 1,
            "Duplicate eventId should be rejected")
    }

    /// Different eventIds with same content should both be accepted.
    func testDifferentEventIdsAreNotDeduplicated() {
        let payload1 = makePayload(eventId: "evt-a", response: .good)
        let payload2 = makePayload(eventId: "evt-b", response: .good)

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
                response: .good,
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

        bridge.processFeedback(makePayload(eventId: "evt-now", response: .good, date: date1))
        bridge.processFeedback(makePayload(eventId: "evt-past", response: .bad, date: date2))
        bridge.processFeedback(makePayload(eventId: "evt-future", response: .neutral, date: date3))

        XCTAssertEqual(bridge.pendingFeedback.first?.eventId, "evt-past")
        XCTAssertEqual(bridge.pendingFeedback.last?.eventId, "evt-future")
    }

    // MARK: - Latest Feedback

    /// latestFeedback should return the most recent pending response.
    func testLatestFeedbackReturnsNewest() {
        let earlier = Date()
        let later = earlier.addingTimeInterval(3600)

        bridge.processFeedback(makePayload(eventId: "evt-1", response: .bad, date: earlier))
        bridge.processFeedback(makePayload(eventId: "evt-2", response: .good, date: later))

        XCTAssertEqual(bridge.latestFeedback(), .good)
    }

    /// latestFeedback should return nil when no pending feedback exists.
    func testLatestFeedbackReturnsNilWhenEmpty() {
        XCTAssertNil(bridge.latestFeedback())
    }

    // MARK: - Clear Processed

    /// clearProcessed should remove all pending items.
    func testClearProcessedRemovesPending() {
        bridge.processFeedback(makePayload(eventId: "evt-1", response: .good))
        bridge.processFeedback(makePayload(eventId: "evt-2", response: .bad))

        bridge.clearProcessed()

        XCTAssertTrue(bridge.pendingFeedback.isEmpty)
    }

    /// clearProcessed should retain deduplication history.
    func testClearProcessedRetainsDedupHistory() {
        let payload = makePayload(eventId: "evt-dedup", response: .good)
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
        let payload = makePayload(eventId: "evt-reset", response: .good)
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
        bridge.processFeedback(makePayload(eventId: "evt-1", response: .good))
        bridge.processFeedback(makePayload(eventId: "evt-1", response: .good)) // dup
        bridge.processFeedback(makePayload(eventId: "evt-2", response: .bad))

        XCTAssertEqual(bridge.totalProcessedCount, 2)
    }
}

// MARK: - WatchFeedbackService Tests

final class WatchFeedbackServiceTests: XCTestCase {

    // MARK: - Properties

    private var service: WatchFeedbackService!
    private var testDefaults: UserDefaults!

    // MARK: - Lifecycle

    @MainActor
    override func setUp() {
        super.setUp()
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
        service.saveFeedback(.good, for: Date())
        let loaded = service.loadFeedback(for: Date())
        XCTAssertEqual(loaded, .good)
    }

    /// Saving feedback for a past date should not affect todayFeedback.
    @MainActor
    func testSaveFeedbackForPastDateDoesNotAffectToday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        service.saveFeedback(.bad, for: yesterday)
        XCTAssertNil(service.todayFeedback,
            "Saving for a past date should not update todayFeedback")
    }

    /// Saving feedback for today should update the published todayFeedback.
    @MainActor
    func testSaveFeedbackForTodayUpdatesPublished() {
        XCTAssertNil(service.todayFeedback, "Should start nil")
        service.saveFeedback(.neutral, for: Date())
        XCTAssertEqual(service.todayFeedback, .neutral)
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
        service.saveFeedback(.good, for: Date())
        XCTAssertTrue(service.hasFeedbackToday())
    }

    // MARK: - Date Isolation

    /// Feedback for different dates should be isolated.
    @MainActor
    func testFeedbackIsolatedByDate() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

        service.saveFeedback(.good, for: today)
        service.saveFeedback(.bad, for: yesterday)
        service.saveFeedback(.neutral, for: twoDaysAgo)

        XCTAssertEqual(service.loadFeedback(for: today), .good)
        XCTAssertEqual(service.loadFeedback(for: yesterday), .bad)
        XCTAssertEqual(service.loadFeedback(for: twoDaysAgo), .neutral)
    }

    /// Loading feedback for a date with no entry should return nil.
    @MainActor
    func testLoadFeedbackReturnsNilForMissingDate() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        XCTAssertNil(service.loadFeedback(for: futureDate))
    }

    // MARK: - Overwrite

    /// Saving new feedback for the same date should overwrite.
    @MainActor
    func testOverwriteFeedbackForSameDate() {
        service.saveFeedback(.good, for: Date())
        service.saveFeedback(.bad, for: Date())
        XCTAssertEqual(service.loadFeedback(for: Date()), .bad)
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
            response: response
        )
    }
}

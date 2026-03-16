// CrashBreadcrumbsTests.swift
// ThumpCoreTests
//
// Unit tests for CrashBreadcrumbs ring buffer — add, retrieve,
// wraparound, clear, and thread-safety.

import XCTest
@testable import Thump

final class CrashBreadcrumbsTests: XCTestCase {

    // Use a fresh instance per test to avoid singleton state pollution.
    private func makeBreadcrumbs(capacity: Int = 5) -> CrashBreadcrumbs {
        CrashBreadcrumbs(capacity: capacity)
    }

    // MARK: - Empty State

    func testAllBreadcrumbs_empty_returnsEmptyArray() {
        let bc = makeBreadcrumbs()
        XCTAssertEqual(bc.allBreadcrumbs().count, 0)
    }

    // MARK: - Add and Retrieve

    func testAdd_singleItem_retrievesIt() {
        let bc = makeBreadcrumbs()
        bc.add("TAP Dashboard/card")
        let crumbs = bc.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 1)
        XCTAssertEqual(crumbs[0].message, "TAP Dashboard/card")
    }

    func testAdd_multipleItems_maintainsOrder() {
        let bc = makeBreadcrumbs(capacity: 10)
        bc.add("first")
        bc.add("second")
        bc.add("third")
        let crumbs = bc.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 3)
        XCTAssertEqual(crumbs[0].message, "first")
        XCTAssertEqual(crumbs[1].message, "second")
        XCTAssertEqual(crumbs[2].message, "third")
    }

    func testAdd_fillsToCapacity() {
        let bc = makeBreadcrumbs(capacity: 3)
        bc.add("a")
        bc.add("b")
        bc.add("c")
        let crumbs = bc.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 3)
        XCTAssertEqual(crumbs.map(\.message), ["a", "b", "c"])
    }

    // MARK: - Ring Buffer Wraparound

    func testAdd_exceedsCapacity_wrapsAndDropsOldest() {
        let bc = makeBreadcrumbs(capacity: 3)
        bc.add("a")
        bc.add("b")
        bc.add("c")
        bc.add("d") // should drop "a"
        let crumbs = bc.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 3)
        XCTAssertEqual(crumbs.map(\.message), ["b", "c", "d"])
    }

    func testAdd_doubleWrap_maintainsChronologicalOrder() {
        let bc = makeBreadcrumbs(capacity: 3)
        for i in 1...7 {
            bc.add("event-\(i)")
        }
        let crumbs = bc.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 3)
        XCTAssertEqual(crumbs.map(\.message), ["event-5", "event-6", "event-7"])
    }

    // MARK: - Clear

    func testClear_resetsBuffer() {
        let bc = makeBreadcrumbs()
        bc.add("first")
        bc.add("second")
        bc.clear()
        XCTAssertEqual(bc.allBreadcrumbs().count, 0)
    }

    func testClear_thenAdd_worksCorrectly() {
        let bc = makeBreadcrumbs(capacity: 3)
        bc.add("old-1")
        bc.add("old-2")
        bc.clear()
        bc.add("new-1")
        let crumbs = bc.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 1)
        XCTAssertEqual(crumbs[0].message, "new-1")
    }

    // MARK: - Capacity

    func testCapacity_matchesInitialization() {
        let bc = makeBreadcrumbs(capacity: 42)
        XCTAssertEqual(bc.capacity, 42)
    }

    func testDefaultCapacity_is50() {
        let bc = CrashBreadcrumbs()
        XCTAssertEqual(bc.capacity, 50)
    }

    // MARK: - Breadcrumb Formatting

    func testBreadcrumb_formatted_containsMessage() {
        let crumb = Breadcrumb(message: "TAP Settings/toggle")
        XCTAssertTrue(crumb.formatted.contains("TAP Settings/toggle"))
    }

    func testBreadcrumb_formatted_containsTimestamp() {
        let crumb = Breadcrumb(message: "test")
        // Should match [HH:mm:ss.SSS] pattern
        let formatted = crumb.formatted
        XCTAssertTrue(formatted.hasPrefix("["))
        XCTAssertTrue(formatted.contains("]"))
    }

    // MARK: - Thread Safety

    func testConcurrentAccess_doesNotCrash() {
        let bc = makeBreadcrumbs(capacity: 100)
        let expectation = expectation(description: "concurrent access")
        expectation.expectedFulfillmentCount = 10

        for i in 0..<10 {
            DispatchQueue.global().async {
                for j in 0..<100 {
                    bc.add("thread-\(i)-event-\(j)")
                }
                _ = bc.allBreadcrumbs()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)
        let crumbs = bc.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 100, "Should have exactly capacity breadcrumbs after overflow")
    }
}

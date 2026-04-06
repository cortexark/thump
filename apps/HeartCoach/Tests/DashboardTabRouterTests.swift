// DashboardTabRouterTests.swift
// ThumpCoreTests
//
// Regression tests for dashboard-to-tab routing. Protects against
// hard-coded index drift when switching between legacy 5-tab and
// new 3-tab layouts.

import XCTest
@testable import Thump

final class DashboardTabRouterTests: XCTestCase {

    func testLegacyTabMapping_usesExpectedIndices() {
        XCTAssertEqual(DashboardTabRouter.tabIndex(for: .insights, useNewTabLayout: false), 1)
        XCTAssertEqual(DashboardTabRouter.tabIndex(for: .stress, useNewTabLayout: false), 2)
        XCTAssertEqual(DashboardTabRouter.tabIndex(for: .trends, useNewTabLayout: false), 3)
        XCTAssertEqual(DashboardTabRouter.tabIndex(for: .settings, useNewTabLayout: false), 4)
    }

    func testNewTabMapping_collapsesToTrendsAndYou() {
        XCTAssertEqual(DashboardTabRouter.tabIndex(for: .insights, useNewTabLayout: true), 1)
        XCTAssertEqual(DashboardTabRouter.tabIndex(for: .stress, useNewTabLayout: true), 1)
        XCTAssertEqual(DashboardTabRouter.tabIndex(for: .trends, useNewTabLayout: true), 1)
        XCTAssertEqual(DashboardTabRouter.tabIndex(for: .settings, useNewTabLayout: true), 2)
    }

    func testCategoryRouting_restAndBreathe_goToStressIntent() {
        XCTAssertEqual(DashboardTabRouter.destination(for: .rest), .stress)
        XCTAssertEqual(DashboardTabRouter.destination(for: .breathe), .stress)
        XCTAssertEqual(DashboardTabRouter.destination(for: .seekGuidance), .stress)
    }

    func testCategoryRouting_activityCategories_goToTrendsIntent() {
        XCTAssertEqual(DashboardTabRouter.destination(for: .walk), .trends)
        XCTAssertEqual(DashboardTabRouter.destination(for: .moderate), .trends)
        XCTAssertEqual(DashboardTabRouter.destination(for: .intensity), .trends)
    }

    func testCategoryRouting_supportiveCategories_goToInsightsIntent() {
        XCTAssertEqual(DashboardTabRouter.destination(for: .hydrate), .insights)
        XCTAssertEqual(DashboardTabRouter.destination(for: .sunlight), .insights)
        XCTAssertEqual(DashboardTabRouter.destination(for: .celebrate), .insights)
    }
}

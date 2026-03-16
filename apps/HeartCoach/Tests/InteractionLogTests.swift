// InteractionLogTests.swift
// ThumpCoreTests
//
// Unit tests for UserInteractionLogger — InteractionAction types,
// tab name resolution, and breadcrumb integration.

import XCTest
@testable import Thump

final class InteractionLogTests: XCTestCase {

    // MARK: - InteractionAction Raw Values

    func testInteractionAction_tapActions_haveCorrectRawValues() {
        XCTAssertEqual(InteractionAction.tap.rawValue, "TAP")
        XCTAssertEqual(InteractionAction.doubleTap.rawValue, "DOUBLE_TAP")
        XCTAssertEqual(InteractionAction.longPress.rawValue, "LONG_PRESS")
    }

    func testInteractionAction_navigationActions_haveCorrectRawValues() {
        XCTAssertEqual(InteractionAction.tabSwitch.rawValue, "TAB_SWITCH")
        XCTAssertEqual(InteractionAction.pageView.rawValue, "PAGE_VIEW")
        XCTAssertEqual(InteractionAction.sheetOpen.rawValue, "SHEET_OPEN")
        XCTAssertEqual(InteractionAction.sheetDismiss.rawValue, "SHEET_DISMISS")
        XCTAssertEqual(InteractionAction.navigationPush.rawValue, "NAV_PUSH")
        XCTAssertEqual(InteractionAction.navigationPop.rawValue, "NAV_POP")
    }

    func testInteractionAction_inputActions_haveCorrectRawValues() {
        XCTAssertEqual(InteractionAction.textInput.rawValue, "TEXT_INPUT")
        XCTAssertEqual(InteractionAction.textClear.rawValue, "TEXT_CLEAR")
        XCTAssertEqual(InteractionAction.datePickerChange.rawValue, "DATE_PICKER")
        XCTAssertEqual(InteractionAction.toggleChange.rawValue, "TOGGLE")
        XCTAssertEqual(InteractionAction.pickerChange.rawValue, "PICKER")
    }

    func testInteractionAction_gestureActions_haveCorrectRawValues() {
        XCTAssertEqual(InteractionAction.swipe.rawValue, "SWIPE")
        XCTAssertEqual(InteractionAction.scroll.rawValue, "SCROLL")
        XCTAssertEqual(InteractionAction.pullToRefresh.rawValue, "PULL_REFRESH")
    }

    func testInteractionAction_buttonActions_haveCorrectRawValues() {
        XCTAssertEqual(InteractionAction.buttonTap.rawValue, "BUTTON")
        XCTAssertEqual(InteractionAction.cardTap.rawValue, "CARD")
        XCTAssertEqual(InteractionAction.linkTap.rawValue, "LINK")
    }

    // MARK: - InteractionLog Breadcrumb Integration

    func testLog_addsBreadcrumb() {
        // Clear shared breadcrumbs first
        CrashBreadcrumbs.shared.clear()

        InteractionLog.log(.tap, element: "test_button", page: "TestPage")

        let crumbs = CrashBreadcrumbs.shared.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 1)
        XCTAssertTrue(crumbs[0].message.contains("TAP"))
        XCTAssertTrue(crumbs[0].message.contains("TestPage"))
        XCTAssertTrue(crumbs[0].message.contains("test_button"))
    }

    func testLog_withDetails_includesDetailsInBreadcrumb() {
        CrashBreadcrumbs.shared.clear()

        InteractionLog.log(.textInput, element: "name_field", page: "Settings", details: "length=5")

        let crumbs = CrashBreadcrumbs.shared.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 1)
        XCTAssertTrue(crumbs[0].message.contains("length=5"))
    }

    func testPageView_addsBreadcrumbWithCorrectAction() {
        CrashBreadcrumbs.shared.clear()

        InteractionLog.pageView("Dashboard")

        let crumbs = CrashBreadcrumbs.shared.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 1)
        XCTAssertTrue(crumbs[0].message.contains("PAGE_VIEW"))
        XCTAssertTrue(crumbs[0].message.contains("Dashboard"))
    }

    func testTabSwitch_addsBreadcrumbWithTabNames() {
        CrashBreadcrumbs.shared.clear()

        InteractionLog.tabSwitch(from: 0, to: 1)

        let crumbs = CrashBreadcrumbs.shared.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 1)
        XCTAssertTrue(crumbs[0].message.contains("TAB_SWITCH"))
        XCTAssertTrue(crumbs[0].message.contains("Home"))
        XCTAssertTrue(crumbs[0].message.contains("Insights"))
    }

    func testTabSwitch_outOfRange_usesNumericIndex() {
        CrashBreadcrumbs.shared.clear()

        InteractionLog.tabSwitch(from: 0, to: 10)

        let crumbs = CrashBreadcrumbs.shared.allBreadcrumbs()
        XCTAssertTrue(crumbs[0].message.contains("10"))
    }

    func testTabSwitch_allValidTabs_haveNames() {
        // Verify tabs 0-4 resolve to named tabs
        let tabNames = ["Home", "Insights", "Stress", "Trends", "Settings"]
        for (index, name) in tabNames.enumerated() {
            CrashBreadcrumbs.shared.clear()
            InteractionLog.tabSwitch(from: 0, to: index)
            let crumbs = CrashBreadcrumbs.shared.allBreadcrumbs()
            XCTAssertTrue(crumbs[0].message.contains(name),
                          "Tab \(index) should resolve to \(name)")
        }
    }

    // MARK: - Multiple Interactions Sequence

    func testMultipleInteractions_accumulateInBreadcrumbs() {
        CrashBreadcrumbs.shared.clear()

        InteractionLog.pageView("Dashboard")
        InteractionLog.log(.tap, element: "readiness_card", page: "Dashboard")
        InteractionLog.log(.sheetOpen, element: "readiness_detail", page: "Dashboard")
        InteractionLog.log(.scroll, element: "content", page: "ReadinessDetail")
        InteractionLog.log(.sheetDismiss, element: "readiness_detail", page: "Dashboard")

        let crumbs = CrashBreadcrumbs.shared.allBreadcrumbs()
        XCTAssertEqual(crumbs.count, 5)
    }
}

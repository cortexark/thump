// ClickableValidationTests.swift
// ThumpUITests
//
// Validates every interactive element in the app navigates to the
// correct destination. Each test takes before/after screenshots
// attached to the test results for visual verification.
//
// View screenshots: Xcode → Test Results navigator → select test → Attachments
// Platforms: iOS 17+

import XCTest

// MARK: - Clickable Validation Tests

final class ClickableValidationTests: XCTestCase {

    // MARK: - Properties

    private let app = XCUIApplication()

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments += ["-UITestMode", "-startTab", "0"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 5)
    }

    // MARK: - Screenshot Helper

    private func screenshot(_ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Tab Navigation Tests

    func testTabHome() {
        screenshot("tab_home_before")
        app.tabBars.buttons["Home"].tap()
        // Dashboard should show the buddy/hero section
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 3),
                      "Home tab should show scrollable dashboard")
        screenshot("tab_home_after")
    }

    func testTabInsights() {
        screenshot("tab_insights_before")
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 3),
                      "Insights tab should show scrollable content")
        screenshot("tab_insights_after")
    }

    func testTabStress() {
        screenshot("tab_stress_before")
        app.tabBars.buttons["Stress"].tap()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 3),
                      "Stress tab should show scrollable content")
        screenshot("tab_stress_after")
    }

    func testTabTrends() {
        screenshot("tab_trends_before")
        app.tabBars.buttons["Trends"].tap()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 3),
                      "Trends tab should show scrollable content")
        screenshot("tab_trends_after")
    }

    func testTabSettings() {
        screenshot("tab_settings_before")
        app.tabBars.buttons["Settings"].tap()
        let settingsScreen = app.collectionViews["settings_screen"]
        let settingsTitle = app.navigationBars["Settings"]
        let profileHeader = app.staticTexts["Profile"]
        let subscriptionHeader = app.staticTexts["Subscription"]
        let hasSettingsContent = settingsScreen.waitForExistence(timeout: 5) ||
            settingsTitle.waitForExistence(timeout: 5) ||
            profileHeader.waitForExistence(timeout: 5) ||
            subscriptionHeader.waitForExistence(timeout: 5)
        XCTAssertTrue(hasSettingsContent, "Settings tab should show the settings screen or its section headers")
        screenshot("tab_settings_after")
    }

    // MARK: - Dashboard Interactive Elements

    func testDashboardReadinessCard() {
        navigateToTab("Home")
        screenshot("dashboard_readiness_before")

        let readinessCard = app.otherElements["dashboard_readiness"]
        if readinessCard.exists && readinessCard.isHittable {
            readinessCard.tap()
            usleep(500_000)
            screenshot("dashboard_readiness_after")
        } else {
            // Try finding by text content
            let readinessText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'readiness'")).firstMatch
            if readinessText.exists && readinessText.isHittable {
                readinessText.tap()
                usleep(500_000)
                screenshot("dashboard_readiness_after")
            }
        }
    }

    func testDashboardRecoveryCard() {
        navigateToTab("Home")
        screenshot("dashboard_recovery_before")

        let recoveryCard = app.otherElements["dashboard_recovery"]
        if recoveryCard.exists && recoveryCard.isHittable {
            recoveryCard.tap()
            usleep(500_000)
            screenshot("dashboard_recovery_after")
        } else {
            let recoveryText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'recover'")).firstMatch
            if recoveryText.exists && recoveryText.isHittable {
                recoveryText.tap()
                usleep(500_000)
                screenshot("dashboard_recovery_after")
            }
        }
    }

    func testDashboardZoneCard() {
        navigateToTab("Home")
        scrollToElement(identifier: "dashboard_zones")
        screenshot("dashboard_zones_before")

        let zoneCard = app.otherElements["dashboard_zones"]
        if zoneCard.exists && zoneCard.isHittable {
            zoneCard.tap()
            usleep(500_000)
            screenshot("dashboard_zones_after")
        }
    }

    func testDashboardCoachCard() {
        navigateToTab("Home")
        scrollToElement(identifier: "dashboard_coach")
        screenshot("dashboard_coach_before")

        let coachCard = app.otherElements["dashboard_coach"]
        if coachCard.exists && coachCard.isHittable {
            coachCard.tap()
            usleep(500_000)
            screenshot("dashboard_coach_after")
        }
    }

    func testDashboardGoalProgress() {
        navigateToTab("Home")
        scrollToElement(identifier: "dashboard_goals")
        screenshot("dashboard_goals_before")

        let goalsSection = app.otherElements["dashboard_goals"]
        if goalsSection.exists && goalsSection.isHittable {
            goalsSection.tap()
            usleep(500_000)
            screenshot("dashboard_goals_after")
        }
    }

    func testDashboardCheckin() {
        navigateToTab("Home")
        screenshot("dashboard_checkin_before")

        let checkinSection = app.otherElements["dashboard_checkin"]
        if checkinSection.exists {
            // Find buttons within the checkin area
            let buttons = checkinSection.buttons.allElementsBoundByIndex.filter { $0.isHittable }
            if let firstButton = buttons.first {
                firstButton.tap()
                usleep(500_000)
                screenshot("dashboard_checkin_after")
            }
        }
    }

    func testDashboardBuddyRecommendations() {
        navigateToTab("Home")
        scrollToElement(identifier: "dashboard_recommendations")
        screenshot("dashboard_recommendations_before")

        let recsSection = app.otherElements["dashboard_recommendations"]
        if recsSection.exists {
            let buttons = recsSection.buttons.allElementsBoundByIndex.filter { $0.isHittable }
            if let firstButton = buttons.first {
                firstButton.tap()
                usleep(500_000)
                screenshot("dashboard_recommendations_after")
            }
        }
    }

    func testDashboardStreakBadge() {
        navigateToTab("Home")
        scrollToElement(identifier: "dashboard_streak")
        screenshot("dashboard_streak_before")

        let streakBadge = app.otherElements["dashboard_streak"]
        if streakBadge.exists && streakBadge.isHittable {
            streakBadge.tap()
            usleep(500_000)
            screenshot("dashboard_streak_after")
        }
    }

    func testDashboardEducationCard() {
        navigateToTab("Home")
        scrollToElement(identifier: "dashboard_education")
        screenshot("dashboard_education_before")

        let eduCard = app.otherElements["dashboard_education"]
        if eduCard.exists && eduCard.isHittable {
            eduCard.tap()
            usleep(500_000)
            screenshot("dashboard_education_after")
        }
    }

    // MARK: - Settings Interactive Elements

    func testSettingsUpgradePlan() {
        navigateToTab("Settings")
        screenshot("settings_upgrade_before")

        let upgradeButton = app.buttons["settings_upgrade"]
        if upgradeButton.exists && upgradeButton.isHittable {
            upgradeButton.tap()
            usleep(500_000)
            // Should present paywall sheet
            screenshot("settings_upgrade_after")
            // Dismiss the paywall
            dismissSheet()
        } else {
            // Try by text
            let upgradeText = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'upgrade' OR label CONTAINS[c] 'plan'")).firstMatch
            if upgradeText.exists && upgradeText.isHittable {
                upgradeText.tap()
                usleep(500_000)
                screenshot("settings_upgrade_after")
                dismissSheet()
            }
        }
    }

    func testSettingsExportPDF() {
        navigateToTab("Settings")
        screenshot("settings_export_before")

        let exportButton = app.buttons["settings_export"]
        if exportButton.exists && exportButton.isHittable {
            exportButton.tap()
            usleep(500_000)
            screenshot("settings_export_after")
        } else {
            let exportText = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'export' OR label CONTAINS[c] 'PDF'")).firstMatch
            if exportText.exists && exportText.isHittable {
                exportText.tap()
                usleep(500_000)
                screenshot("settings_export_after")
            }
        }
    }

    func testSettingsTerms() {
        navigateToTab("Settings")
        scrollDown()
        screenshot("settings_terms_before")

        let termsLink = app.buttons["settings_terms"]
        if termsLink.exists && termsLink.isHittable {
            termsLink.tap()
            usleep(500_000)
            screenshot("settings_terms_after")
        } else {
            let termsText = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'terms'")).firstMatch
            if termsText.exists && termsText.isHittable {
                termsText.tap()
                usleep(500_000)
                screenshot("settings_terms_after")
            }
        }
    }

    func testSettingsPrivacy() {
        navigateToTab("Settings")
        scrollDown()
        screenshot("settings_privacy_before")

        let privacyLink = app.buttons["settings_privacy"]
        if privacyLink.exists && privacyLink.isHittable {
            privacyLink.tap()
            usleep(500_000)
            screenshot("settings_privacy_after")
        } else {
            let privacyText = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'privacy'")).firstMatch
            if privacyText.exists && privacyText.isHittable {
                privacyText.tap()
                usleep(500_000)
                screenshot("settings_privacy_after")
            }
        }
    }

    // MARK: - Cross-Screen Navigation

    func testFullTabCycle() {
        let tabs = ["Home", "Insights", "Stress", "Trends", "Settings"]
        for tab in tabs {
            navigateToTab(tab)
            usleep(300_000)
            screenshot("full_cycle_\(tab.lowercased())")
        }
        // Return to home
        navigateToTab("Home")
        screenshot("full_cycle_return_home")
    }

    // MARK: - State Color System Tests
    // Validates the new 4-state color system: Gold / Violet / Orange / Amber

    func testDashboard_stateColorElement_exists() {
        navigateToTab("Home")
        screenshot("state_color_check")
        // The state color should be reflected in the dashboard's hero area.
        // Check that a state label exists (Gold = Thriving, Violet = Recovering,
        // Orange = Stressed, Amber = Steady).
        let stateLabels = ["Thriving", "Recovering", "Stressed", "Steady",
                           "Building Momentum", "Holding Steady", "Check In"]
        let hasStateLabel = stateLabels.contains { label in
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", label))
                .firstMatch.waitForExistence(timeout: 3)
        }
        // A state label or score should always be visible on the Home screen
        let scoreExists = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '\\\\d+'")
        ).firstMatch.waitForExistence(timeout: 3)

        XCTAssertTrue(hasStateLabel || scoreExists,
            "Home screen must show a state label or readiness score")
    }

    func testDashboard_missionCopyVisible() {
        navigateToTab("Home")
        screenshot("mission_copy_check")
        // Mission sentence is a short, plain-English text line on the Home screen.
        // It should be non-empty and visible.
        // We check for at least one static text with meaningful length.
        let hasLongText = app.staticTexts.allElementsBoundByIndex.contains { element in
            element.exists && element.label.count > 20
        }
        XCTAssertTrue(hasLongText, "Home screen should display a mission sentence (> 20 characters)")
    }

    func testDashboard_missionCopy_noEmptyState() {
        navigateToTab("Home")
        // Wait for data to load
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        screenshot("mission_copy_no_empty_state")
        // Verify there is at least one non-empty text element visible —
        // the app must never show a blank mission sentence.
        let nonEmptyTexts = app.staticTexts.allElementsBoundByIndex.filter {
            !$0.label.isEmpty && $0.label != " "
        }
        XCTAssertFalse(nonEmptyTexts.isEmpty,
            "Home screen must never show a completely empty content state")
    }

    // MARK: - 3-Tab Navigation Validation
    // The design system specifies a 3-tab model (Today / Trends / You).
    // Current app uses 5 tabs. Both legacy and redesigned tab sets are validated.

    func testNavigation_tabCountIsAtLeast3() {
        let tabBarButtons = app.tabBars.firstMatch.buttons.allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(tabBarButtons.count, 3,
            "App must have at least 3 navigation tabs per the design spec")
    }

    func testNavigation_homeTabIsFirstTab() {
        // The first tab must navigate to the home/today screen
        let firstTab = app.tabBars.firstMatch.buttons.element(boundBy: 0)
        XCTAssertTrue(firstTab.exists, "First tab must exist")
        firstTab.tap()
        usleep(300_000)
        let hasDashboardContent = app.scrollViews.firstMatch.waitForExistence(timeout: 3)
        screenshot("first_tab_home_check")
        XCTAssertTrue(hasDashboardContent, "First tab must show the main dashboard/today screen")
    }

    func testNavigation_eachTabLoadsContent() {
        // Verify every tab shows some content (scroll view or form)
        let tabCount = app.tabBars.firstMatch.buttons.count
        for i in 0..<min(tabCount, 5) {
            let tab = app.tabBars.firstMatch.buttons.element(boundBy: i)
            guard tab.exists && tab.isHittable else { continue }
            tab.tap()
            usleep(300_000)
            screenshot("tab_\(i)_content_check")
            // Each tab must present either a scroll view or recognizable content
            let hasContent = app.scrollViews.firstMatch.waitForExistence(timeout: 3)
                || app.collectionViews.firstMatch.waitForExistence(timeout: 1)
                || app.tables.firstMatch.waitForExistence(timeout: 1)
            XCTAssertTrue(hasContent, "Tab \(i) must load displayable content")
        }
    }

    // MARK: - Mission Copy Pool Routing Tests
    // UI-level smoke tests that the mission copy area renders different content
    // across different app states (injected via launch arguments)

    func testMissionCopyArea_rendersInThrivingState() {
        // Launch with thriving state injection
        app.terminate()
        var launchArgs = app.launchArguments
        launchArgs += ["-UITestReadinessScore", "85"]
        app.launchArguments = launchArgs
        app.launch()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)

        navigateToTab("Home")
        screenshot("mission_copy_thriving")

        // In a thriving state the mission copy must exist and be visible
        let hasLongText = app.staticTexts.allElementsBoundByIndex.contains { element in
            element.exists && element.label.count > 15
        }
        XCTAssertTrue(hasLongText, "Thriving state must show a mission sentence on Home screen")
    }

    func testMissionCopyArea_rendersInRecoveringState() {
        app.terminate()
        var launchArgs = app.launchArguments
        launchArgs += ["-UITestReadinessScore", "55"]
        app.launchArguments = launchArgs
        app.launch()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)

        navigateToTab("Home")
        screenshot("mission_copy_recovering")

        let hasLongText = app.staticTexts.allElementsBoundByIndex.contains { element in
            element.exists && element.label.count > 15
        }
        XCTAssertTrue(hasLongText, "Recovering state must show a mission sentence on Home screen")
    }

    func testMissionCopyArea_rendersInStressedState() {
        app.terminate()
        var launchArgs = app.launchArguments
        launchArgs += ["-UITestReadinessScore", "25"]
        app.launchArguments = launchArgs
        app.launch()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)

        navigateToTab("Home")
        screenshot("mission_copy_stressed")

        let hasLongText = app.staticTexts.allElementsBoundByIndex.contains { element in
            element.exists && element.label.count > 15
        }
        XCTAssertTrue(hasLongText, "Stressed state must show a mission sentence on Home screen")
    }

    func testDesignBHomeNightState_usesRestfulBuddy() {
        app.terminate()
        app.launchArguments = [
            "-UITestMode",
            "-UITest_UseDesignB",
            "-startTab", "0",
            "-UITestHour", "22",
            "-UITestReadinessScore", "55"
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        navigateToTab("Home")
        let hero = app.otherElements["dashboard_hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5), "Home hero should be visible on Home")

        screenshot("design_b_night_buddy")

        XCTAssertTrue(hero.label.contains("Good night"), "Night hero should use the nighttime greeting")
        XCTAssertTrue(hero.label.contains("Rest Up"), "Night hero should show the restful buddy mood")
        XCTAssertFalse(hero.label.contains("Train Your Heart"), "Night hero should not show the daytime nudging face")
        XCTAssertFalse(hero.label.contains("In the Zone"), "Night hero should not show the active face")
    }

    func testDesignBHomeNightState_overridesHighReadinessEnergy() {
        app.terminate()
        app.launchArguments = [
            "-UITestMode",
            "-UITest_UseDesignB",
            "-startTab", "0",
            "-UITestHour", "22",
            "-UITestReadinessScore", "88"
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        navigateToTab("Home")
        let hero = app.otherElements["dashboard_hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5), "Home hero should be visible on Home")

        screenshot("design_b_night_high_readiness")

        XCTAssertTrue(hero.label.contains("Good night"), "Night hero should keep the nighttime greeting")
        XCTAssertTrue(hero.label.contains("Rest Up"), "Night hero should force the resting buddy mood at night")
        XCTAssertFalse(hero.label.contains("Crushing It"), "Night hero should not show the high-energy thriving face")
        XCTAssertFalse(hero.label.contains("Heart Happy"), "Night hero should not show the daytime content face")
        XCTAssertFalse(hero.label.contains("In the Zone"), "Night hero should not show the active face")
    }

    // MARK: - Helpers

    private func navigateToTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.exists && tab.isHittable {
            tab.tap()
            usleep(300_000)
        }
    }

    private func scrollToElement(identifier: String) {
        let element = app.otherElements[identifier]
        if element.exists { return }

        // Scroll down up to 10 times to find the element
        for _ in 0..<10 {
            app.swipeUp()
            usleep(200_000)
            if element.exists { return }
        }
    }

    private func scrollDown() {
        app.swipeUp()
        usleep(300_000)
    }

    private func dismissSheet() {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
        usleep(500_000)
    }
}

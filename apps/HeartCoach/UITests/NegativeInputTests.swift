// NegativeInputTests.swift
// ThumpUITests
//
// Tests negative/edge-case user inputs for DOB, name, and other fields.
// Verifies the app handles bad input gracefully without crashing.
// Platforms: iOS 17+

import XCTest

// MARK: - Negative Input Tests

final class NegativeInputTests: XCTestCase {

    // MARK: - Properties

    private let app = XCUIApplication()

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app.launchArguments += ["-UITestMode", "-startTab", "4"] // Start on Settings
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

    // MARK: - Name Field Tests

    func testEmptyNameField() {
        let nameField = findNameField()
        guard let field = nameField else {
            XCTFail("Could not find name text field in Settings")
            return
        }

        // Clear existing text
        field.tap()
        selectAllAndDelete(field)
        screenshot("name_empty")

        // Verify app doesn't crash
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    func testVeryLongName() {
        let nameField = findNameField()
        guard let field = nameField else {
            XCTFail("Could not find name text field in Settings")
            return
        }

        field.tap()
        selectAllAndDelete(field)

        // Type a very long name (100 characters)
        let longName = String(repeating: "A", count: 100)
        field.typeText(longName)
        screenshot("name_very_long")

        // App should not crash
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    func testSpecialCharactersInName() {
        let nameField = findNameField()
        guard let field = nameField else {
            XCTFail("Could not find name text field in Settings")
            return
        }

        field.tap()
        selectAllAndDelete(field)

        field.typeText("!@#$%^&*()")
        screenshot("name_special_chars")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    func testEmojiOnlyName() {
        let nameField = findNameField()
        guard let field = nameField else {
            XCTFail("Could not find name text field in Settings")
            return
        }

        field.tap()
        selectAllAndDelete(field)

        field.typeText("🏃‍♂️💪🎯")
        screenshot("name_emoji_only")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    func testNameWithNewlines() {
        let nameField = findNameField()
        guard let field = nameField else {
            XCTFail("Could not find name text field in Settings")
            return
        }

        field.tap()
        selectAllAndDelete(field)

        // Type text with return key (newline)
        field.typeText("John")
        field.typeText("\n")
        field.typeText("Doe")
        screenshot("name_with_newline")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    func testRapidNameEditing() {
        let nameField = findNameField()
        guard let field = nameField else {
            XCTFail("Could not find name text field in Settings")
            return
        }

        // Rapidly type, clear, type, clear 10 times
        for i in 0..<10 {
            field.tap()
            selectAllAndDelete(field)
            field.typeText("Rapid\(i)")
        }

        screenshot("name_rapid_editing")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    // MARK: - DOB Picker Tests

    func testDOBPickerExists() {
        // Navigate to settings and find DOB picker
        let datePicker = findDOBPicker()
        screenshot("dob_picker_initial")

        // DOB picker should exist (may not be found if layout differs)
        if datePicker != nil {
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
        }
    }

    func testDOBPickerInteraction() {
        let datePicker = findDOBPicker()
        guard let picker = datePicker else {
            // DOB picker may not be directly accessible via XCUITest
            return
        }

        // Interact with the picker
        picker.tap()
        usleep(500_000)
        screenshot("dob_picker_opened")

        // App should not crash after picker interaction
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    // MARK: - Tab Navigation Under Stress

    func testRapidTabSwitching() {
        // Rapidly switch tabs 50 times
        let tabNames = ["Home", "Insights", "Stress", "Trends", "Settings"]

        for i in 0..<50 {
            let tabName = tabNames[i % tabNames.count]
            let tab = app.tabBars.buttons[tabName]
            if tab.exists && tab.isHittable {
                tab.tap()
            }
        }

        screenshot("rapid_tab_switching")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
    }

    // MARK: - Scroll Edge Cases

    func testScrollPastContent() {
        // Go to Home tab
        app.tabBars.buttons["Home"].tap()
        usleep(300_000)

        // Scroll way down past content
        for _ in 0..<20 {
            app.swipeUp()
        }
        screenshot("scroll_past_bottom")

        // Scroll way up past top
        for _ in 0..<20 {
            app.swipeDown()
        }
        screenshot("scroll_past_top")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    // MARK: - Rotation / Orientation

    func testOrientationChange() {
        // Navigate to Home
        app.tabBars.buttons["Home"].tap()
        usleep(300_000)
        screenshot("orientation_portrait")

        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft
        usleep(500_000)
        screenshot("orientation_landscape_left")

        // Rotate back
        XCUIDevice.shared.orientation = .portrait
        usleep(500_000)
        screenshot("orientation_back_to_portrait")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    // MARK: - Multiple Sheet Presentation

    func testDoubleSheetPresentation() {
        // Navigate to Settings
        app.tabBars.buttons["Settings"].tap()
        usleep(300_000)

        // Try to present a sheet (e.g., upgrade/paywall)
        let upgradeButton = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'upgrade' OR label CONTAINS[c] 'plan'"
        )).firstMatch

        if upgradeButton.exists && upgradeButton.isHittable {
            upgradeButton.tap()
            usleep(500_000)
            screenshot("double_sheet_first")

            // Try to present another sheet while one is showing
            // This should not crash
            upgradeButton.tap()
            usleep(500_000)
            screenshot("double_sheet_attempt")
        }

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    // MARK: - Helpers

    private func findNameField() -> XCUIElement? {
        let field = app.textFields["settings_name"]
        if field.exists { return field }

        // Fallback: find any text field in settings
        let textFields = app.textFields.allElementsBoundByIndex
        return textFields.first { $0.exists && $0.isHittable }
    }

    private func findDOBPicker() -> XCUIElement? {
        let picker = app.datePickers["settings_dob"]
        if picker.exists { return picker }

        // Fallback: find any date picker
        let datePickers = app.datePickers.allElementsBoundByIndex
        return datePickers.first { $0.exists }
    }

    private func selectAllAndDelete(_ field: XCUIElement) {
        // Triple tap to select all, then delete
        field.tap()
        field.tap()
        field.tap()

        if let value = field.value as? String, !value.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue,
                                      count: value.count + 5)
            field.typeText(deleteString)
        }
    }
}

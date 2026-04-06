import XCTest

final class BuddyShowcaseTests: XCTestCase {

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITest_UseDesignB", "-startTab", "0"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        return app
    }

    func testCaptureDashboardBuddy() throws {
        let app = launchApp()

        sleep(4) // Let animations settle

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "ThumpBuddy_Dashboard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureAllTabs() throws {
        let app = launchApp()
        sleep(3)

        // Dashboard (Home)
        let shot1 = XCTAttachment(screenshot: app.screenshot())
        shot1.name = "Tab_Home_Dashboard"
        shot1.lifetime = .keepAlways
        add(shot1)

        // Insights tab
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Insights"].tap()
        sleep(2)
        let shot2 = XCTAttachment(screenshot: app.screenshot())
        shot2.name = "Tab_Insights"
        shot2.lifetime = .keepAlways
        add(shot2)

        // Stress tab
        app.tabBars.buttons["Stress"].tap()
        sleep(2)
        let shot3 = XCTAttachment(screenshot: app.screenshot())
        shot3.name = "Tab_Stress"
        shot3.lifetime = .keepAlways
        add(shot3)

        // Trends tab
        app.tabBars.buttons["Trends"].tap()
        sleep(2)
        let shot4 = XCTAttachment(screenshot: app.screenshot())
        shot4.name = "Tab_Trends"
        shot4.lifetime = .keepAlways
        add(shot4)

        // Settings tab
        app.tabBars.buttons["Settings"].tap()
        sleep(2)
        let shot5 = XCTAttachment(screenshot: app.screenshot())
        shot5.name = "Tab_Settings"
        shot5.lifetime = .keepAlways
        add(shot5)
    }
}

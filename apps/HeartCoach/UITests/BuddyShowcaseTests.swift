import XCTest

final class BuddyShowcaseTests: XCTestCase {

    func testCaptureDashboardBuddy() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-startTab", "0"]
        app.launch()

        sleep(4) // Let animations settle

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "ThumpBuddy_Dashboard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureAllTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-startTab", "0"]
        app.launch()
        sleep(3)

        // Dashboard (Home)
        let shot1 = XCTAttachment(screenshot: app.screenshot())
        shot1.name = "Tab_Home_Dashboard"
        shot1.lifetime = .keepAlways
        add(shot1)

        // Insights tab
        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(2)
        let shot2 = XCTAttachment(screenshot: app.screenshot())
        shot2.name = "Tab_Insights"
        shot2.lifetime = .keepAlways
        add(shot2)

        // Stress tab
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)
        let shot3 = XCTAttachment(screenshot: app.screenshot())
        shot3.name = "Tab_Stress"
        shot3.lifetime = .keepAlways
        add(shot3)

        // Trends tab
        app.tabBars.buttons.element(boundBy: 3).tap()
        sleep(2)
        let shot4 = XCTAttachment(screenshot: app.screenshot())
        shot4.name = "Tab_Trends"
        shot4.lifetime = .keepAlways
        add(shot4)

        // Settings tab
        app.tabBars.buttons.element(boundBy: 4).tap()
        sleep(2)
        let shot5 = XCTAttachment(screenshot: app.screenshot())
        shot5.name = "Tab_Settings"
        shot5.lifetime = .keepAlways
        add(shot5)
    }
}

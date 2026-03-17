import XCTest

final class ScreenshotCapture: XCTestCase {
    let app = XCUIApplication()
    let outputDir = "/Users/t/workspace/Apple-watch/apps/HeartCoach/Screenshots"

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments = ["-UITestMode"]
        app.launch()
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = app.screenshot()
        let data = screenshot.pngRepresentation
        let url = URL(fileURLWithPath: "\(outputDir)/\(name).png")
        try? data.write(to: url)
        // Also add as attachment for xcresult
        let attach = XCTAttachment(screenshot: screenshot)
        attach.name = name
        attach.lifetime = .keepAlways
        add(attach)
    }

    func testCaptureAllScreens() {
        // Create output directory
        try? FileManager.default.createDirectory(
            atPath: outputDir, withIntermediateDirectories: true)

        sleep(3)

        // 1. Dashboard top
        saveScreenshot("dashboard_top")

        // 2. Scroll dashboard down
        app.swipeUp()
        sleep(1)
        saveScreenshot("dashboard_scrolled_1")

        // 3. Scroll more
        app.swipeUp()
        sleep(1)
        saveScreenshot("dashboard_scrolled_2")

        // 4. Scroll even more
        app.swipeUp()
        sleep(1)
        saveScreenshot("dashboard_scrolled_3")

        // 5. Insights tab
        if app.tabBars.buttons["Insights"].exists {
            app.tabBars.buttons["Insights"].tap()
            sleep(2)
            saveScreenshot("insights_tab")

            // Scroll insights
            app.swipeUp()
            sleep(1)
            saveScreenshot("insights_scrolled")
        }

        // 6. Stress tab
        if app.tabBars.buttons["Stress"].exists {
            app.tabBars.buttons["Stress"].tap()
            sleep(2)
            saveScreenshot("stress_tab")
        }

        // 7. Trends tab
        if app.tabBars.buttons["Trends"].exists {
            app.tabBars.buttons["Trends"].tap()
            sleep(2)
            saveScreenshot("trends_tab")
        }

        // 8. Settings tab
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
            sleep(2)
            saveScreenshot("settings_tab")

            // Scroll settings
            app.swipeUp()
            sleep(1)
            saveScreenshot("settings_scrolled")
        }

        // Back to home
        if app.tabBars.buttons["Home"].exists {
            app.tabBars.buttons["Home"].tap()
            sleep(1)
        }
    }
}

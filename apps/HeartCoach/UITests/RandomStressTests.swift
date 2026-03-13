// RandomStressTests.swift
// ThumpUITests
//
// Chaos monkey UI stress test that performs 500+ random operations
// across the app without crashing. Uses weighted random action
// selection with a history buffer to prevent repetitive clicks.
//
// Run: Xcode → select ThumpUITests → testRandomStress500Operations
// Platforms: iOS 17+

import XCTest

// MARK: - Random Stress Tests

final class RandomStressTests: XCTestCase {

    // MARK: - Properties

    private let app = XCUIApplication()
    private var operationCount = 0
    private let targetOperations = 500
    private var recentActions: [ActionType] = []
    private let maxRecentHistory = 5

    // MARK: - Action Types

    enum ActionType: String, CaseIterable {
        case tabNavigation
        case scrollDown
        case scrollUp
        case tapRandomElement
        case tapBackButton
        case pullToRefresh
        case dismissSheet
        case tapToggle
        case typeText
        case swipeRandom
    }

    // MARK: - Weighted Action Selection

    /// Weights for each action type. Higher = more likely.
    private let actionWeights: [(ActionType, Int)] = [
        (.tapRandomElement, 25),
        (.scrollDown, 12),
        (.scrollUp, 8),
        (.tabNavigation, 15),
        (.tapBackButton, 10),
        (.pullToRefresh, 5),
        (.dismissSheet, 5),
        (.tapToggle, 5),
        (.typeText, 5),
        (.swipeRandom, 10),
    ]

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        continueAfterFailure = true

        app.launchArguments += ["-UITestMode", "-startTab", "0"]
        app.launch()

        // Wait for app to settle
        _ = app.wait(for: .runningForeground, timeout: 5)
    }

    override func tearDown() {
        super.tearDown()
        print("✅ RandomStressTest completed \(operationCount) operations")
    }

    // MARK: - Main Stress Test

    func testRandomStress500Operations() {
        while operationCount < targetOperations {
            let action = selectWeightedAction()

            perform(action: action)
            operationCount += 1

            // Record action in history
            recentActions.append(action)
            if recentActions.count > maxRecentHistory {
                recentActions.removeFirst()
            }

            // Brief pause to let UI settle (50ms)
            usleep(50_000)

            // Verify app is still running
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: 3),
                "App crashed or went to background at operation \(operationCount) (action: \(action.rawValue))"
            )

            // Every 50 operations, log progress
            if operationCount % 50 == 0 {
                print("🔄 Completed \(operationCount)/\(targetOperations) operations")
            }
        }
    }

    // MARK: - Action Selection

    /// Selects a weighted random action, avoiding repeating the same action type 3+ times in a row.
    private func selectWeightedAction() -> ActionType {
        let totalWeight = actionWeights.reduce(0) { $0 + $1.1 }

        for _ in 0..<10 { // max 10 attempts to find non-repetitive action
            var random = Int.random(in: 0..<totalWeight)
            var selected: ActionType = .tabNavigation

            for (action, weight) in actionWeights {
                random -= weight
                if random < 0 {
                    selected = action
                    break
                }
            }

            // Check if this action was repeated 3+ times in a row
            let consecutiveCount = recentActions.suffix(2).filter { $0 == selected }.count
            if consecutiveCount < 2 {
                return selected
            }
        }

        // Fallback: pick any action that hasn't been repeated
        return ActionType.allCases.randomElement()!
    }

    // MARK: - Action Execution

    private func perform(action: ActionType) {
        switch action {
        case .tabNavigation:
            performTabNavigation()
        case .scrollDown:
            performScroll(direction: .down)
        case .scrollUp:
            performScroll(direction: .up)
        case .tapRandomElement:
            performTapRandomElement()
        case .tapBackButton:
            performTapBack()
        case .pullToRefresh:
            performPullToRefresh()
        case .dismissSheet:
            performDismissSheet()
        case .tapToggle:
            performTapToggle()
        case .typeText:
            performTypeText()
        case .swipeRandom:
            performSwipeRandom()
        }
    }

    // MARK: - Individual Actions

    private func performTabNavigation() {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.exists else { return }

        let tabs = tabBar.buttons.allElementsBoundByIndex
        guard !tabs.isEmpty else { return }

        let randomTab = tabs[Int.random(in: 0..<tabs.count)]
        if randomTab.isHittable {
            randomTab.tap()
        }
    }

    private func performScroll(direction: UISwipeGestureRecognizer.Direction) {
        let scrollViews = app.scrollViews.allElementsBoundByIndex
        let tables = app.tables.allElementsBoundByIndex
        let collectionViews = app.collectionViews.allElementsBoundByIndex

        let allScrollable = scrollViews + tables + collectionViews
        guard let target = allScrollable.first(where: { $0.exists && $0.isHittable }) else { return }

        switch direction {
        case .up:
            target.swipeDown()
        case .down:
            target.swipeUp()
        default:
            target.swipeUp()
        }
    }

    private func performTapRandomElement() {
        // Collect all tappable elements
        let buttons = app.buttons.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        let cells = app.cells.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        let links = app.links.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        let staticTexts = app.staticTexts.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }

        // Prefer buttons and cells over static text
        var candidates: [XCUIElement] = []
        candidates.append(contentsOf: buttons)
        candidates.append(contentsOf: cells)
        candidates.append(contentsOf: links)

        // Add a small selection of static texts (some are tappable cards)
        if staticTexts.count > 0 {
            let textSample = Array(staticTexts.prefix(5))
            candidates.append(contentsOf: textSample)
        }

        guard !candidates.isEmpty else { return }

        let element = candidates[Int.random(in: 0..<candidates.count)]
        element.tap()
    }

    private func performTapBack() {
        let navBar = app.navigationBars.firstMatch
        guard navBar.exists else { return }

        let backButton = navBar.buttons.firstMatch
        if backButton.exists && backButton.isHittable {
            backButton.tap()
        }
    }

    private func performPullToRefresh() {
        let scrollViews = app.scrollViews.allElementsBoundByIndex
        guard let scrollView = scrollViews.first(where: { $0.exists && $0.isHittable }) else { return }

        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    private func performDismissSheet() {
        // Try to dismiss any presented sheet by swiping down from top
        let window = app.windows.firstMatch
        guard window.exists else { return }

        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    private func performTapToggle() {
        let switches = app.switches.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        guard !switches.isEmpty else { return }

        let toggle = switches[Int.random(in: 0..<switches.count)]
        toggle.tap()
    }

    private func performTypeText() {
        let textFields = app.textFields.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        let searchFields = app.searchFields.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }

        let allFields = textFields + searchFields
        guard !allFields.isEmpty else { return }

        let field = allFields[Int.random(in: 0..<allFields.count)]
        field.tap()

        // Type a random short string
        let strings = ["Test", "Hello", "123", "Abc", "Quick test", "🏃", "OK"]
        let randomStr = strings[Int.random(in: 0..<strings.count)]
        field.typeText(randomStr)

        // Clear the text
        if let value = field.value as? String, !value.isEmpty {
            field.tap()
            // Select all and delete
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: min(value.count + 5, 20))
            field.typeText(deleteString)
        }
    }

    private func performSwipeRandom() {
        let window = app.windows.firstMatch
        guard window.exists else { return }

        let direction = Int.random(in: 0..<4)
        switch direction {
        case 0: window.swipeUp()
        case 1: window.swipeDown()
        case 2: window.swipeLeft()
        case 3: window.swipeRight()
        default: window.swipeUp()
        }
    }
}

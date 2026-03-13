// UserInteractionLogger.swift
// ThumpCore
//
// Tracks every user interaction (taps, typing, page views, navigation)
// with timestamps for debugging, analytics, and crash breadcrumbs.
// Uses os.Logger with "interaction" category for Console.app filtering.
// Platforms: iOS 17+, watchOS 10+

import Foundation
import os

// MARK: - Interaction Action Types

/// All user-initiated action types tracked by the interaction logger.
public enum InteractionAction: String, Sendable {
    // Taps
    case tap             = "TAP"
    case doubleTap       = "DOUBLE_TAP"
    case longPress       = "LONG_PRESS"

    // Navigation
    case tabSwitch       = "TAB_SWITCH"
    case pageView        = "PAGE_VIEW"
    case sheetOpen       = "SHEET_OPEN"
    case sheetDismiss    = "SHEET_DISMISS"
    case navigationPush  = "NAV_PUSH"
    case navigationPop   = "NAV_POP"

    // Input
    case textInput       = "TEXT_INPUT"
    case textClear       = "TEXT_CLEAR"
    case datePickerChange = "DATE_PICKER"
    case toggleChange    = "TOGGLE"
    case pickerChange    = "PICKER"

    // Gestures
    case swipe           = "SWIPE"
    case scroll          = "SCROLL"
    case pullToRefresh   = "PULL_REFRESH"

    // Buttons
    case buttonTap       = "BUTTON"
    case cardTap         = "CARD"
    case linkTap         = "LINK"
}

// MARK: - User Interaction Logger

/// Centralized user interaction logger that records every tap, navigation,
/// and input event with a timestamp, page context, and element identifier.
///
/// Usage:
/// ```swift
/// InteractionLog.log(.tap, element: "readiness_card", page: "Dashboard")
/// InteractionLog.log(.textInput, element: "name_field", page: "Settings", details: "length=5")
/// InteractionLog.log(.tabSwitch, element: "tab_insights", page: "MainTab", details: "from=0 to=1")
/// ```
///
/// All events are:
/// 1. Written to `os.Logger` under category "interaction" for Console.app
/// 2. Stored in the `CrashBreadcrumbs` ring buffer for crash debugging
/// 3. Printed to Xcode console in DEBUG builds
public struct InteractionLog: Sendable {

    // MARK: - Private Logger

    private static let logger = Logger(
        subsystem: "com.thump.app",
        category: "interaction"
    )

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Public API

    /// Log a user interaction event.
    ///
    /// - Parameters:
    ///   - action: The type of interaction (tap, textInput, pageView, etc.)
    ///   - element: The UI element identifier (e.g., "readiness_card", "name_field")
    ///   - page: The current page/screen name (e.g., "Dashboard", "Settings")
    ///   - details: Optional additional context (e.g., "length=5", "from=0 to=1")
    public static func log(
        _ action: InteractionAction,
        element: String,
        page: String,
        details: String? = nil
    ) {
        let timestamp = isoFormatter.string(from: Date())
        let detailStr = details.map { " | \($0)" } ?? ""
        let message = "[\(action.rawValue)] page=\(page) element=\(element)\(detailStr)"

        // 1. os.Logger for Console.app (persists in system log)
        logger.info("[\(timestamp, privacy: .public)] \(message, privacy: .public)")

        // 2. Crash breadcrumb ring buffer
        CrashBreadcrumbs.shared.add("[\(action.rawValue)] \(page)/\(element)\(detailStr)")

        // 3. Xcode console in debug builds
        #if DEBUG
        print("🔵 [\(timestamp)] \(message)")
        #endif
    }

    /// Log a page view event. Convenience for screen appearances.
    ///
    /// - Parameter page: The page/screen name being viewed.
    public static func pageView(_ page: String) {
        log(.pageView, element: "screen", page: page)
    }

    /// Log a tab switch event.
    ///
    /// - Parameters:
    ///   - from: The tab index being left.
    ///   - to: The tab index being entered.
    public static func tabSwitch(from: Int, to: Int) {
        let tabNames = ["Home", "Insights", "Stress", "Trends", "Settings"]
        let fromName = from < tabNames.count ? tabNames[from] : "\(from)"
        let toName = to < tabNames.count ? tabNames[to] : "\(to)"
        log(.tabSwitch, element: "tab_\(toName.lowercased())", page: "MainTab",
            details: "from=\(fromName) to=\(toName)")
    }

    // MARK: - Private

    private init() {}
}

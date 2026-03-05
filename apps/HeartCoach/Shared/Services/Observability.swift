// Observability.swift
// ThumpCore
//
// Lightweight logging and analytics abstraction.
// Uses os.Logger for structured logging and provides a pluggable
// analytics provider protocol for future integration with
// third-party services (e.g. Mixpanel, Amplitude, PostHog).
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation
import os

// MARK: - Log Level

/// Severity levels for structured log messages.
public enum LogLevel: String, Sendable, Comparable {
    case debug   = "DEBUG"
    case info    = "INFO"
    case warning = "WARNING"
    case error   = "ERROR"

    /// Numeric ordering so that `<` means "less severe".
    private var severity: Int {
        switch self {
        case .debug:   return 0
        case .info:    return 1
        case .warning: return 2
        case .error:   return 3
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.severity < rhs.severity
    }

    /// Map to the corresponding `OSLogType` for `os.Logger`.
    var osLogType: OSLogType {
        switch self {
        case .debug:   return .debug
        case .info:    return .info
        case .warning: return .default  // os.Logger has no .warning
        case .error:   return .error
        }
    }
}

// MARK: - App Logger

/// Structured logger that delegates to `os.Logger` with source-location metadata.
///
/// All methods are static so callers do not need to hold an instance:
/// ```swift
/// AppLogger.log("Assessment computed", level: .info)
/// AppLogger.log("Decode failed: \(error)", level: .error)
/// ```
public struct AppLogger: Sendable {

    /// The underlying `os.Logger` instance scoped to the Thump subsystem.
    private static let osLogger = Logger(
        subsystem: "com.thump.app",
        category: "general"
    )

    // MARK: - Public API

    /// Emit a structured log message.
    ///
    /// - Parameters:
    ///   - message: The log message. Evaluated lazily when the level is enabled.
    ///   - level: Severity. Defaults to `.info`.
    ///   - file: Calling file (auto-filled).
    ///   - function: Calling function (auto-filled).
    ///   - line: Calling line number (auto-filled).
    public static func log(
        _ message: @autoclosure () -> String,
        level: LogLevel = .info,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let text = message()
        let location = "\(file):\(line) \(function)"

        // Always route through os.Logger for system-level capture.
        osLogger.log(level: level.osLogType, "[\(level.rawValue)] \(location) - \(text)")

        #if DEBUG
        // Mirror to stdout for Xcode console readability.
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] \(location) - \(text)")
        #endif
    }

    /// Convenience: log at `.debug` level.
    public static func debug(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .debug, file: file, function: function, line: line)
    }

    /// Convenience: log at `.info` level.
    public static func info(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .info, file: file, function: function, line: line)
    }

    /// Convenience: log at `.warning` level.
    public static func warning(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .warning, file: file, function: function, line: line)
    }

    /// Convenience: log at `.error` level.
    public static func error(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .error, file: file, function: function, line: line)
    }

    /// `AppLogger` is a namespace; it should not be instantiated.
    private init() {}
}

// MARK: - Analytics Event

/// A lightweight analytics event with a name and string-keyed properties.
///
/// Events are value types so they can be constructed in any context
/// and passed to an ``AnalyticsProvider`` for dispatch.
public struct AnalyticsEvent: Sendable, Equatable {
    /// Machine-readable event name (e.g. "assessment_generated").
    public let name: String

    /// Flat dictionary of event properties.
    public let properties: [String: String]

    public init(name: String, properties: [String: String] = [:]) {
        self.name = name
        self.properties = properties
    }
}

// MARK: - Analytics Provider Protocol

/// Abstraction for analytics backends.
///
/// Adopt this protocol to bridge ``ObservabilityService`` to
/// Mixpanel, Amplitude, PostHog, or any custom analytics sink.
///
/// ```swift
/// struct MixpanelProvider: AnalyticsProvider {
///     func track(event: AnalyticsEvent) {
///         Mixpanel.mainInstance().track(
///             event: event.name,
///             properties: event.properties
///         )
///     }
/// }
/// ```
public protocol AnalyticsProvider {
    /// Track a single analytics event.
    func track(event: AnalyticsEvent)
}

// MARK: - Observability Service

/// Central hub that combines logging and analytics tracking.
///
/// In debug builds, events are printed to the console. In release builds,
/// events are forwarded to any registered ``AnalyticsProvider``.
///
/// ```swift
/// let service = ObservabilityService()
/// service.track(AnalyticsEvent(
///     name: "nudge_completed",
///     properties: ["category": "walk", "duration": "15"]
/// ))
/// ```
public final class ObservabilityService {

    // MARK: - Properties

    /// Registered analytics providers that receive tracked events.
    private var providers: [AnalyticsProvider] = []

    /// When `true`, events are also printed to the console via `AppLogger`.
    /// Automatically enabled in DEBUG builds.
    public var debugLogging: Bool

    // MARK: - Initialization

    public init(debugLogging: Bool? = nil) {
        #if DEBUG
        self.debugLogging = debugLogging ?? true
        #else
        self.debugLogging = debugLogging ?? false
        #endif
    }

    // MARK: - Provider Registration

    /// Register an analytics provider that will receive all future events.
    ///
    /// - Parameter provider: The provider to add.
    public func register(provider: AnalyticsProvider) {
        providers.append(provider)
    }

    // MARK: - Event Tracking

    /// Track an ``AnalyticsEvent``.
    ///
    /// The event is forwarded to every registered provider and, when
    /// ``debugLogging`` is enabled, printed to the console.
    ///
    /// - Parameter event: The event to track.
    public func track(_ event: AnalyticsEvent) {
        // Forward to all registered providers.
        for provider in providers {
            provider.track(event: event)
        }

        // Debug console output.
        if debugLogging {
            let props = event.properties.isEmpty
                ? ""
                : " | " + event.properties
                    .sorted(by: { $0.key < $1.key })
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: ", ")
            AppLogger.debug("[Analytics] \(event.name)\(props)")
        }
    }

    // MARK: - Convenience Factories

    /// Track a simple event with no properties.
    public func track(name: String) {
        track(AnalyticsEvent(name: name))
    }

    /// Track an event with inline property pairs.
    public func track(name: String, properties: [String: String]) {
        track(AnalyticsEvent(name: name, properties: properties))
    }
}

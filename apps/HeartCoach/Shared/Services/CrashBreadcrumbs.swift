// CrashBreadcrumbs.swift
// ThumpCore
//
// Thread-safe ring buffer of the last 50 user interactions.
// On crash diagnostic receipt (MetricKit), the breadcrumbs are
// dumped to AppLogger.error to show exactly what the user was
// doing before the crash. Uses OSAllocatedUnfairLock for
// lock-free thread safety on iOS 17+.
// Platforms: iOS 17+, watchOS 10+

import Foundation
import os

// MARK: - Breadcrumb Entry

/// A single timestamped breadcrumb entry.
public struct Breadcrumb: Sendable {
    public let timestamp: Date
    public let message: String

    public init(message: String) {
        self.timestamp = Date()
        self.message = message
    }

    /// Formatted string for logging: "[HH:mm:ss.SSS] message"
    public var formatted: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return "[\(f.string(from: timestamp))] \(message)"
    }
}

// MARK: - Crash Breadcrumbs

/// Thread-safe ring buffer of recent user interactions for crash debugging.
///
/// Usage:
/// ```swift
/// CrashBreadcrumbs.shared.add("TAP Dashboard/readiness_card")
/// CrashBreadcrumbs.shared.add("PAGE_VIEW Settings")
///
/// // On crash diagnostic:
/// CrashBreadcrumbs.shared.dump()  // prints all breadcrumbs to AppLogger.error
/// ```
public final class CrashBreadcrumbs: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = CrashBreadcrumbs()

    // MARK: - Configuration

    /// Maximum number of breadcrumbs to retain.
    public let capacity: Int

    // MARK: - Storage

    private var buffer: [Breadcrumb]
    private var writeIndex: Int = 0
    private var count: Int = 0
    private let lock = OSAllocatedUnfairLock()

    // MARK: - Initialization

    /// Creates a breadcrumb buffer with the given capacity.
    ///
    /// - Parameter capacity: Maximum entries to retain. Defaults to 50.
    public init(capacity: Int = 50) {
        self.capacity = capacity
        self.buffer = Array(repeating: Breadcrumb(message: ""), count: capacity)
    }

    // MARK: - Public API

    /// Add a breadcrumb to the ring buffer.
    ///
    /// - Parameter message: A short description of the user action.
    ///   Example: "TAP Dashboard/readiness_card"
    public func add(_ message: String) {
        let crumb = Breadcrumb(message: message)
        lock.lock()
        buffer[writeIndex] = crumb
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity { count += 1 }
        lock.unlock()
    }

    /// Returns all breadcrumbs in chronological order.
    public func allBreadcrumbs() -> [Breadcrumb] {
        lock.lock()
        defer { lock.unlock() }

        guard count > 0 else { return [] }

        if count < capacity {
            return Array(buffer[0..<count])
        } else {
            // Ring buffer is full; read from writeIndex to end, then start to writeIndex
            let tail = Array(buffer[writeIndex..<capacity])
            let head = Array(buffer[0..<writeIndex])
            return tail + head
        }
    }

    /// Dump all breadcrumbs to `AppLogger.error` for crash debugging.
    /// Call this from `MetricKitService.didReceive(_:)` on diagnostic receipt.
    public func dump() {
        let crumbs = allBreadcrumbs()
        guard !crumbs.isEmpty else {
            AppLogger.error("CrashBreadcrumbs: (empty — no user interactions recorded)")
            return
        }

        AppLogger.error("=== CRASH BREADCRUMBS (\(crumbs.count) entries) ===")
        for (i, crumb) in crumbs.enumerated() {
            AppLogger.error("  \(i + 1). \(crumb.formatted)")
        }
        AppLogger.error("=== END BREADCRUMBS ===")
    }

    /// Clear all breadcrumbs. Useful for testing.
    public func clear() {
        lock.lock()
        writeIndex = 0
        count = 0
        lock.unlock()
    }
}

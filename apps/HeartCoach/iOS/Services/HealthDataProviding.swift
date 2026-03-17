// HealthDataProviding.swift
// Thump iOS
//
// Protocol abstraction over HealthKit data access for testability.
// Allows unit tests to inject mock health data without requiring
// a live HKHealthStore or simulator with HealthKit entitlements.
//
// Driven by: SKILL_SDE_TEST_SCAFFOLDING (orchestrator v0.2.0)
// Acceptance: Mock conforming type can provide snapshot data in tests.
// Platforms: iOS 17+

import Foundation

// MARK: - Health Data Provider Protocol

/// Abstraction over health data access that enables dependency injection
/// and mock-based testing without HealthKit.
///
/// Conforming types provide snapshot data for the current day and
/// historical days. The production implementation (`HealthKitService`)
/// queries HealthKit; test implementations return deterministic data.
///
/// Usage:
/// ```swift
/// // Production
/// let provider: HealthDataProviding = HealthKitService()
///
/// // Testing
/// let provider: HealthDataProviding = MockHealthDataProvider(
///     todaySnapshot: HeartSnapshot.mock(),
///     history: [HeartSnapshot.mock(daysAgo: 1)]
/// )
/// ```
public protocol HealthDataProviding: AnyObject {
    /// Whether the data provider is authorized to access health data.
    var isAuthorized: Bool { get }

    /// HealthKit query warnings accumulated during the last refresh cycle.
    /// Empty for mock providers. Real providers collect error messages from
    /// failed queries so bug reports can explain why metrics are nil.
    var queryWarnings: [String] { get }

    /// Clears accumulated query warnings. Call at the start of each refresh cycle.
    func clearQueryWarnings()

    /// Request authorization to access health data.
    /// - Throws: If authorization fails or is unavailable.
    func requestAuthorization() async throws

    /// Fetch the health snapshot for the current day.
    /// - Returns: A `HeartSnapshot` with today's metrics.
    func fetchTodaySnapshot() async throws -> HeartSnapshot

    /// Fetch historical health snapshots for the specified number of past days.
    /// - Parameter days: Number of past days (not including today).
    /// - Returns: Array of `HeartSnapshot` ordered oldest-first.
    func fetchHistory(days: Int) async throws -> [HeartSnapshot]
}

// MARK: - HealthKitService Conformance

extension HealthKitService: HealthDataProviding {}

// MARK: - Mock Health Data Provider

/// Mock implementation of `HealthDataProviding` for unit tests.
///
/// Returns deterministic, configurable health data without requiring
/// HealthKit authorization or a simulator with health data.
///
/// Features:
/// - Configurable today snapshot and history
/// - Configurable authorization behavior (success, failure, denied)
/// - Call tracking for verification in tests
public final class MockHealthDataProvider: HealthDataProviding {
    // MARK: - Configuration

    /// The snapshot to return from `fetchTodaySnapshot()`.
    public var todaySnapshot: HeartSnapshot

    /// The history to return from `fetchHistory(days:)`.
    public var history: [HeartSnapshot]

    /// Whether authorization should succeed.
    public var shouldAuthorize: Bool

    /// Error to throw from `requestAuthorization()` if `shouldAuthorize` is false.
    public var authorizationError: Error?

    /// Error to throw from `fetchTodaySnapshot()` if set.
    public var fetchError: Error?

    // MARK: - Call Tracking

    /// Number of times `requestAuthorization()` was called.
    public private(set) var authorizationCallCount: Int = 0

    /// Number of times `fetchTodaySnapshot()` was called.
    public private(set) var fetchTodayCallCount: Int = 0

    /// Number of times `fetchHistory(days:)` was called.
    public private(set) var fetchHistoryCallCount: Int = 0

    /// The `days` parameter from the most recent `fetchHistory(days:)` call.
    public private(set) var lastFetchHistoryDays: Int?

    // MARK: - State

    public private(set) var isAuthorized: Bool = false

    /// Mock providers return empty warnings (no real HealthKit queries).
    public var queryWarnings: [String] = []
    public func clearQueryWarnings() { queryWarnings = [] }

    // MARK: - Init

    public init(
        todaySnapshot: HeartSnapshot = HeartSnapshot(date: Date()),
        history: [HeartSnapshot] = [],
        shouldAuthorize: Bool = true,
        authorizationError: Error? = nil,
        fetchError: Error? = nil
    ) {
        self.todaySnapshot = todaySnapshot
        self.history = history
        self.shouldAuthorize = shouldAuthorize
        self.authorizationError = authorizationError
        self.fetchError = fetchError
    }

    // MARK: - Protocol Conformance

    public func requestAuthorization() async throws {
        authorizationCallCount += 1
        if shouldAuthorize {
            isAuthorized = true
        } else if let error = authorizationError {
            throw error
        }
    }

    public func fetchTodaySnapshot() async throws -> HeartSnapshot {
        fetchTodayCallCount += 1
        if let error = fetchError {
            throw error
        }
        return todaySnapshot
    }

    public func fetchHistory(days: Int) async throws -> [HeartSnapshot] {
        fetchHistoryCallCount += 1
        lastFetchHistoryDays = days
        if let error = fetchError {
            throw error
        }
        return Array(history.prefix(days))
    }

    // MARK: - Test Helpers

    /// Reset all call counts and state.
    public func reset() {
        authorizationCallCount = 0
        fetchTodayCallCount = 0
        fetchHistoryCallCount = 0
        lastFetchHistoryDays = nil
        isAuthorized = false
    }
}

// HealthDataProviderTests.swift
// ThumpTests
//
// Tests for the HealthDataProviding protocol and MockHealthDataProvider.
// Validates that the mock provider correctly simulates HealthKit behavior
// for use in integration tests without requiring a live HKHealthStore.
//
// Driven by: SKILL_SDE_TEST_SCAFFOLDING (orchestrator v0.2.0)
// Acceptance: Mock provider passes all contract tests; call tracking works.
// Platforms: iOS 17+

import XCTest
@testable import Thump

// MARK: - Mock Health Data Provider Tests

final class HealthDataProviderTests: XCTestCase {

    // MARK: - Authorization

    func testAuthorizationSucceeds() async throws {
        let provider = MockHealthDataProvider(shouldAuthorize: true)
        XCTAssertFalse(provider.isAuthorized, "Should not be authorized before request")

        try await provider.requestAuthorization()

        XCTAssertTrue(provider.isAuthorized, "Should be authorized after successful request")
        XCTAssertEqual(provider.authorizationCallCount, 1, "Should track authorization calls")
    }

    func testAuthorizationDenied() async throws {
        let provider = MockHealthDataProvider(
            shouldAuthorize: false,
            authorizationError: NSError(domain: "HKError", code: 5, userInfo: nil)
        )

        do {
            try await provider.requestAuthorization()
        } catch {
            XCTAssertFalse(provider.isAuthorized, "Should not be authorized after denial")
            XCTAssertEqual(provider.authorizationCallCount, 1)
            return
        }
        // If shouldAuthorize is false but no error, isAuthorized stays false
    }

    // MARK: - Fetch Today Snapshot

    func testFetchTodayReturnsConfiguredSnapshot() async throws {
        let date = Date()
        let snapshot = HeartSnapshot(
            date: date,
            restingHeartRate: 65.0,
            hrvSDNN: 42.0,
            steps: 8500.0
        )
        let provider = MockHealthDataProvider(todaySnapshot: snapshot)

        let result = try await provider.fetchTodaySnapshot()

        XCTAssertEqual(result.restingHeartRate, 65.0)
        XCTAssertEqual(result.hrvSDNN, 42.0)
        XCTAssertEqual(result.steps, 8500.0)
        XCTAssertEqual(provider.fetchTodayCallCount, 1)
    }

    func testFetchTodayThrowsConfiguredError() async {
        let provider = MockHealthDataProvider(
            fetchError: NSError(domain: "HKError", code: 1, userInfo: nil)
        )

        do {
            _ = try await provider.fetchTodaySnapshot()
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(provider.fetchTodayCallCount, 1)
        }
    }

    // MARK: - Fetch History

    func testFetchHistoryReturnsConfiguredData() async throws {
        let history = (1...7).map { day in
            HeartSnapshot(
                date: Calendar.current.date(
                    byAdding: .day,
                    value: -day,
                    to: Date()
                ) ?? Date(),
                restingHeartRate: Double(60 + day)
            )
        }
        let provider = MockHealthDataProvider(history: history)

        let result = try await provider.fetchHistory(days: 5)

        XCTAssertEqual(result.count, 5, "Should return requested number of days")
        XCTAssertEqual(provider.fetchHistoryCallCount, 1)
        XCTAssertEqual(provider.lastFetchHistoryDays, 5)
    }

    func testFetchHistoryReturnsEmptyForZeroDays() async throws {
        let provider = MockHealthDataProvider(history: [])

        let result = try await provider.fetchHistory(days: 0)

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Call Tracking Reset

    func testResetClearsCallCounts() async throws {
        let provider = MockHealthDataProvider()
        try await provider.requestAuthorization()
        _ = try await provider.fetchTodaySnapshot()
        _ = try await provider.fetchHistory(days: 7)

        provider.reset()

        XCTAssertEqual(provider.authorizationCallCount, 0)
        XCTAssertEqual(provider.fetchTodayCallCount, 0)
        XCTAssertEqual(provider.fetchHistoryCallCount, 0)
        XCTAssertNil(provider.lastFetchHistoryDays)
        XCTAssertFalse(provider.isAuthorized)
    }
}

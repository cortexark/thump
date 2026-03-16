// MockHealthDataProviderTests.swift
// ThumpCoreTests
//
// Tests for MockHealthDataProvider: call tracking, error injection,
// authorization behavior, and reset functionality. These tests ensure
// the test infrastructure itself is correct.

import XCTest
@testable import Thump

final class MockHealthDataProviderTests: XCTestCase {

    // MARK: - Default State

    func testDefault_notAuthorized() {
        let provider = MockHealthDataProvider()
        XCTAssertFalse(provider.isAuthorized)
    }

    func testDefault_zeroCallCounts() {
        let provider = MockHealthDataProvider()
        XCTAssertEqual(provider.authorizationCallCount, 0)
        XCTAssertEqual(provider.fetchTodayCallCount, 0)
        XCTAssertEqual(provider.fetchHistoryCallCount, 0)
        XCTAssertNil(provider.lastFetchHistoryDays)
    }

    // MARK: - Authorization

    func testRequestAuthorization_success() async throws {
        let provider = MockHealthDataProvider(shouldAuthorize: true)
        try await provider.requestAuthorization()

        XCTAssertTrue(provider.isAuthorized)
        XCTAssertEqual(provider.authorizationCallCount, 1)
    }

    func testRequestAuthorization_failure() async {
        let error = NSError(domain: "Test", code: -1)
        let provider = MockHealthDataProvider(
            shouldAuthorize: false,
            authorizationError: error
        )

        do {
            try await provider.requestAuthorization()
            XCTFail("Should throw")
        } catch {
            XCTAssertFalse(provider.isAuthorized)
            XCTAssertEqual(provider.authorizationCallCount, 1)
        }
    }

    func testRequestAuthorization_deniedNoError() async throws {
        let provider = MockHealthDataProvider(shouldAuthorize: false)
        // No error set, just doesn't authorize
        try await provider.requestAuthorization()
        XCTAssertFalse(provider.isAuthorized)
    }

    // MARK: - Fetch Today

    func testFetchTodaySnapshot_returnsConfigured() async throws {
        let snapshot = HeartSnapshot(
            date: Date(),
            restingHeartRate: 62.0,
            hrvSDNN: 52.0
        )
        let provider = MockHealthDataProvider(todaySnapshot: snapshot)

        let result = try await provider.fetchTodaySnapshot()
        XCTAssertEqual(result.restingHeartRate, 62.0)
        XCTAssertEqual(result.hrvSDNN, 52.0)
        XCTAssertEqual(provider.fetchTodayCallCount, 1)
    }

    func testFetchTodaySnapshot_throwsOnError() async {
        let provider = MockHealthDataProvider(
            fetchError: NSError(domain: "Test", code: -2)
        )

        do {
            _ = try await provider.fetchTodaySnapshot()
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(provider.fetchTodayCallCount, 1)
        }
    }

    // MARK: - Fetch History

    func testFetchHistory_returnsConfiguredHistory() async throws {
        let history = (1...5).map { day in
            HeartSnapshot(
                date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!,
                restingHeartRate: 60.0 + Double(day)
            )
        }
        let provider = MockHealthDataProvider(history: history)

        let result = try await provider.fetchHistory(days: 3)
        XCTAssertEqual(result.count, 3, "Should return prefix of configured history")
        XCTAssertEqual(provider.fetchHistoryCallCount, 1)
        XCTAssertEqual(provider.lastFetchHistoryDays, 3)
    }

    func testFetchHistory_requestMoreThanAvailable() async throws {
        let history = [HeartSnapshot(date: Date(), restingHeartRate: 65.0)]
        let provider = MockHealthDataProvider(history: history)

        let result = try await provider.fetchHistory(days: 30)
        XCTAssertEqual(result.count, 1, "Should return all available when requesting more")
    }

    func testFetchHistory_throwsOnError() async {
        let provider = MockHealthDataProvider(
            fetchError: NSError(domain: "Test", code: -3)
        )

        do {
            _ = try await provider.fetchHistory(days: 7)
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(provider.fetchHistoryCallCount, 1)
        }
    }

    // MARK: - Reset

    func testReset_clearsAllState() async throws {
        let provider = MockHealthDataProvider(shouldAuthorize: true)
        try await provider.requestAuthorization()
        _ = try await provider.fetchTodaySnapshot()
        _ = try await provider.fetchHistory(days: 7)

        provider.reset()

        XCTAssertFalse(provider.isAuthorized)
        XCTAssertEqual(provider.authorizationCallCount, 0)
        XCTAssertEqual(provider.fetchTodayCallCount, 0)
        XCTAssertEqual(provider.fetchHistoryCallCount, 0)
        XCTAssertNil(provider.lastFetchHistoryDays)
    }

    // MARK: - Multiple Calls

    func testMultipleFetchCalls_incrementCounts() async throws {
        let provider = MockHealthDataProvider()

        _ = try await provider.fetchTodaySnapshot()
        _ = try await provider.fetchTodaySnapshot()
        _ = try await provider.fetchTodaySnapshot()

        XCTAssertEqual(provider.fetchTodayCallCount, 3)
    }
}

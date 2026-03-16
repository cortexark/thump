// ObservabilityTests.swift
// ThumpCoreTests
//
// Unit tests for Observability — LogLevel ordering, AnalyticsEvent,
// ObservabilityService provider registration and event routing.

import XCTest
@testable import Thump

final class ObservabilityTests: XCTestCase {

    // MARK: - LogLevel Ordering

    func testLogLevel_debugIsLeastSevere() {
        XCTAssertTrue(LogLevel.debug < .info)
        XCTAssertTrue(LogLevel.debug < .warning)
        XCTAssertTrue(LogLevel.debug < .error)
    }

    func testLogLevel_errorIsMostSevere() {
        XCTAssertTrue(LogLevel.error > .debug)
        XCTAssertTrue(LogLevel.error > .info)
        XCTAssertTrue(LogLevel.error > .warning)
    }

    func testLogLevel_ordering_isStrictlyIncreasing() {
        let levels: [LogLevel] = [.debug, .info, .warning, .error]
        for i in 0..<levels.count - 1 {
            XCTAssertTrue(levels[i] < levels[i + 1],
                          "\(levels[i]) should be less than \(levels[i + 1])")
        }
    }

    func testLogLevel_equalityHolds() {
        XCTAssertEqual(LogLevel.debug, .debug)
        XCTAssertEqual(LogLevel.error, .error)
        XCTAssertFalse(LogLevel.debug == .error)
    }

    func testLogLevel_rawValues() {
        XCTAssertEqual(LogLevel.debug.rawValue, "DEBUG")
        XCTAssertEqual(LogLevel.info.rawValue, "INFO")
        XCTAssertEqual(LogLevel.warning.rawValue, "WARNING")
        XCTAssertEqual(LogLevel.error.rawValue, "ERROR")
    }

    // MARK: - AnalyticsEvent

    func testAnalyticsEvent_initWithName() {
        let event = AnalyticsEvent(name: "nudge_completed")
        XCTAssertEqual(event.name, "nudge_completed")
        XCTAssertEqual(event.properties, [:])
    }

    func testAnalyticsEvent_initWithProperties() {
        let event = AnalyticsEvent(
            name: "assessment_generated",
            properties: ["score": "72", "confidence": "high"]
        )
        XCTAssertEqual(event.name, "assessment_generated")
        XCTAssertEqual(event.properties["score"], "72")
        XCTAssertEqual(event.properties["confidence"], "high")
    }

    func testAnalyticsEvent_equality() {
        let a = AnalyticsEvent(name: "tap", properties: ["element": "card"])
        let b = AnalyticsEvent(name: "tap", properties: ["element": "card"])
        let c = AnalyticsEvent(name: "tap", properties: ["element": "button"])
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - ObservabilityService Provider Registration

    func testObservabilityService_trackForwardsToProvider() {
        let service = ObservabilityService(debugLogging: false)
        let spy = SpyAnalyticsProvider()
        service.register(provider: spy)

        service.track(AnalyticsEvent(name: "test_event", properties: ["key": "value"]))

        XCTAssertEqual(spy.trackedEvents.count, 1)
        XCTAssertEqual(spy.trackedEvents[0].name, "test_event")
        XCTAssertEqual(spy.trackedEvents[0].properties["key"], "value")
    }

    func testObservabilityService_multipleProviders_allReceiveEvent() {
        let service = ObservabilityService(debugLogging: false)
        let spy1 = SpyAnalyticsProvider()
        let spy2 = SpyAnalyticsProvider()
        service.register(provider: spy1)
        service.register(provider: spy2)

        service.track(name: "multi_provider_event")

        XCTAssertEqual(spy1.trackedEvents.count, 1)
        XCTAssertEqual(spy2.trackedEvents.count, 1)
    }

    func testObservabilityService_noProviders_doesNotCrash() {
        let service = ObservabilityService(debugLogging: false)
        // Should not crash
        service.track(name: "orphan_event")
    }

    func testObservabilityService_trackName_createsEventWithEmptyProperties() {
        let service = ObservabilityService(debugLogging: false)
        let spy = SpyAnalyticsProvider()
        service.register(provider: spy)

        service.track(name: "simple_event")

        XCTAssertEqual(spy.trackedEvents[0].properties, [:])
    }

    func testObservabilityService_trackWithProperties_passesThrough() {
        let service = ObservabilityService(debugLogging: false)
        let spy = SpyAnalyticsProvider()
        service.register(provider: spy)

        service.track(name: "event", properties: ["a": "1", "b": "2"])

        XCTAssertEqual(spy.trackedEvents[0].properties.count, 2)
    }

    // MARK: - LogCategory

    func testLogCategory_allCases_haveNonEmptyRawValues() {
        let categories: [LogCategory] = [
            .engine, .healthKit, .navigation,
            .interaction, .subscription, .sync,
            .notification, .validation
        ]
        for cat in categories {
            XCTAssertFalse(cat.rawValue.isEmpty, "\(cat) has empty raw value")
        }
    }
}

// MARK: - Test Helpers

private final class SpyAnalyticsProvider: AnalyticsProvider {
    var trackedEvents: [AnalyticsEvent] = []

    func track(event: AnalyticsEvent) {
        trackedEvents.append(event)
    }
}

// ConfigServiceTests.swift
// ThumpCoreTests
//
// Unit tests for ConfigService covering default values, tier-based feature
// gating, feature flag lookups, and engine factory.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import XCTest
@testable import ThumpCore

// MARK: - ConfigServiceTests

final class ConfigServiceTests: XCTestCase {

    // MARK: - Test: Default Constants Are Reasonable

    func testDefaultLookbackWindowIsPositive() {
        XCTAssertGreaterThan(ConfigService.defaultLookbackWindow, 0)
        XCTAssertEqual(
            ConfigService.defaultLookbackWindow,
            21,
            "Default lookback should be 21 days (3 weeks)"
        )
    }

    func testDefaultRegressionWindowIsPositive() {
        XCTAssertGreaterThan(ConfigService.defaultRegressionWindow, 0)
        XCTAssertEqual(ConfigService.defaultRegressionWindow, 7)
    }

    func testMinimumCorrelationPointsIsPositive() {
        XCTAssertGreaterThan(ConfigService.minimumCorrelationPoints, 0)
        XCTAssertEqual(ConfigService.minimumCorrelationPoints, 7)
    }

    func testHighConfidenceRequiresMoreDaysThanMedium() {
        XCTAssertGreaterThan(
            ConfigService.minimumHighConfidenceDays,
            ConfigService.minimumMediumConfidenceDays,
            "High confidence should require more days than medium"
        )
    }

    // MARK: - Test: Default Alert Policy Values

    func testDefaultAlertPolicyThresholds() {
        let policy = ConfigService.defaultAlertPolicy
        XCTAssertGreaterThan(policy.anomalyHigh, 0, "Anomaly threshold should be positive")
        XCTAssertGreaterThan(policy.cooldownHours, 0, "Cooldown should be positive")
        XCTAssertGreaterThan(policy.maxAlertsPerDay, 0, "Max alerts should be positive")
    }

    // MARK: - Test: Sync Configuration

    func testMinimumSyncIntervalIsReasonable() {
        XCTAssertGreaterThanOrEqual(
            ConfigService.minimumSyncIntervalSeconds,
            60,
            "Sync interval should be at least 60 seconds for battery"
        )
        XCTAssertLessThanOrEqual(
            ConfigService.minimumSyncIntervalSeconds,
            3600,
            "Sync interval should be at most 1 hour for freshness"
        )
    }

    func testMaxStoredSnapshotsIsReasonable() {
        XCTAssertGreaterThanOrEqual(
            ConfigService.maxStoredSnapshots,
            30,
            "Should store at least 30 days of data"
        )
        XCTAssertLessThanOrEqual(
            ConfigService.maxStoredSnapshots,
            730,
            "Should not store more than 2 years of data"
        )
    }

    // MARK: - Test: Free Tier Feature Gating

    func testFreeTierCannotAccessFullMetrics() {
        XCTAssertFalse(ConfigService.canAccessFullMetrics(tier: .free))
    }

    func testFreeTierCannotAccessNudges() {
        XCTAssertFalse(ConfigService.canAccessNudges(tier: .free))
    }

    func testFreeTierCannotAccessReports() {
        XCTAssertFalse(ConfigService.canAccessReports(tier: .free))
    }

    func testFreeTierCannotAccessCorrelations() {
        XCTAssertFalse(ConfigService.canAccessCorrelations(tier: .free))
    }

    // MARK: - Test: Pro Tier Feature Gating

    func testProTierCanAccessFullMetrics() {
        XCTAssertTrue(ConfigService.canAccessFullMetrics(tier: .pro))
    }

    func testProTierCanAccessNudges() {
        XCTAssertTrue(ConfigService.canAccessNudges(tier: .pro))
    }

    func testProTierCannotAccessReports() {
        XCTAssertFalse(ConfigService.canAccessReports(tier: .pro))
    }

    func testProTierCanAccessCorrelations() {
        XCTAssertTrue(ConfigService.canAccessCorrelations(tier: .pro))
    }

    // MARK: - Test: Coach Tier Feature Gating

    func testCoachTierCanAccessAllFeatures() {
        XCTAssertTrue(ConfigService.canAccessFullMetrics(tier: .coach))
        XCTAssertTrue(ConfigService.canAccessNudges(tier: .coach))
        XCTAssertTrue(ConfigService.canAccessReports(tier: .coach))
        XCTAssertTrue(ConfigService.canAccessCorrelations(tier: .coach))
    }

    // MARK: - Test: Family Tier Feature Gating

    func testFamilyTierCanAccessAllFeatures() {
        XCTAssertTrue(ConfigService.canAccessFullMetrics(tier: .family))
        XCTAssertTrue(ConfigService.canAccessNudges(tier: .family))
        XCTAssertTrue(ConfigService.canAccessReports(tier: .family))
        XCTAssertTrue(ConfigService.canAccessCorrelations(tier: .family))
    }

    // MARK: - Test: Feature Flag Lookup

    func testKnownFeatureFlagsReturnExpectedValues() {
        XCTAssertEqual(ConfigService.isFeatureEnabled("weeklyReports"),
            ConfigService.enableWeeklyReports)
        XCTAssertEqual(ConfigService.isFeatureEnabled("correlationInsights"),
            ConfigService.enableCorrelationInsights)
        XCTAssertEqual(ConfigService.isFeatureEnabled("watchFeedbackCapture"),
            ConfigService.enableWatchFeedbackCapture)
        XCTAssertEqual(ConfigService.isFeatureEnabled("anomalyAlerts"),
            ConfigService.enableAnomalyAlerts)
        XCTAssertEqual(ConfigService.isFeatureEnabled("onboardingQuestionnaire"),
            ConfigService.enableOnboardingQuestionnaire)
    }

    func testUnknownFeatureFlagReturnsFalse() {
        XCTAssertFalse(ConfigService.isFeatureEnabled("nonExistentFeature"))
        XCTAssertFalse(ConfigService.isFeatureEnabled(""))
    }

    // MARK: - Test: Available Features Per Tier

    func testEveryTierHasAtLeastOneFeature() {
        for tier in SubscriptionTier.allCases {
            let features = ConfigService.availableFeatures(for: tier)
            XCTAssertGreaterThan(
                features.count,
                0,
                "\(tier) should have at least one feature listed"
            )
        }
    }

    func testHigherTiersHaveMoreFeatures() {
        let freeFeatures = ConfigService.availableFeatures(for: .free)
        let proFeatures = ConfigService.availableFeatures(for: .pro)
        XCTAssertGreaterThan(
            proFeatures.count,
            freeFeatures.count,
            "Pro should have more features than Free"
        )
    }

    // MARK: - Test: Engine Factory

    func testMakeDefaultEngineReturnsConfiguredEngine() {
        let engine = ConfigService.makeDefaultEngine()
        // Engine should be usable — verify by running a basic operation
        let history: [HeartSnapshot] = []
        let snapshot = HeartSnapshot(date: Date(), restingHeartRate: 62)
        let confidence = engine.confidenceLevel(current: snapshot, history: history)
        XCTAssertEqual(
            confidence,
            .low,
            "Empty history should yield low confidence from default engine"
        )
    }

    // MARK: - Test: Subscription Tier Properties

    func testAllTiersHaveDisplayNames() {
        for tier in SubscriptionTier.allCases {
            XCTAssertFalse(tier.displayName.isEmpty,
                "\(tier) should have a display name")
        }
    }

    func testFreeTierHasZeroPrice() {
        XCTAssertEqual(SubscriptionTier.free.monthlyPrice, 0.0)
        XCTAssertEqual(SubscriptionTier.free.annualPrice, 0.0)
    }

    func testAnnualPriceIsLessThanTwelveTimesMonthly() {
        for tier in SubscriptionTier.allCases where tier.monthlyPrice > 0 {
            XCTAssertLessThan(
                tier.annualPrice,
                tier.monthlyPrice * 12,
                "\(tier) annual should be cheaper than 12 months"
            )
        }
    }
}

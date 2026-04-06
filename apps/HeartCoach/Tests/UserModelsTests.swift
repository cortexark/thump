// UserModelsTests.swift
// ThumpCoreTests
//
// Unit tests for user domain models — UserProfile computed properties,
// SubscriptionTier pricing and features, BiologicalSex,
// AlertMeta, and Codable round-trips.

import XCTest
@testable import Thump

final class UserModelsTests: XCTestCase {

    // MARK: - UserProfile Chronological Age

    func testChronologicalAge_withDOB_returnsAge() {
        let cal = Calendar.current
        let dob = cal.date(byAdding: .year, value: -30, to: Date())!
        let profile = UserProfile(dateOfBirth: dob)
        XCTAssertEqual(profile.chronologicalAge, 30)
    }

    func testChronologicalAge_withoutDOB_returnsNil() {
        let profile = UserProfile()
        XCTAssertNil(profile.chronologicalAge)
    }

    // MARK: - UserProfile Launch Free Year

    func testIsInLaunchFreeYear_recentStart_returnsTrue() {
        let profile = UserProfile(launchFreeStartDate: Date())
        XCTAssertTrue(profile.isInLaunchFreeYear)
    }

    func testIsInLaunchFreeYear_expiredStart_returnsFalse() {
        let cal = Calendar.current
        let twoYearsAgo = cal.date(byAdding: .year, value: -2, to: Date())!
        let profile = UserProfile(launchFreeStartDate: twoYearsAgo)
        XCTAssertFalse(profile.isInLaunchFreeYear)
    }

    func testIsInLaunchFreeYear_noStartDate_returnsFalse() {
        let profile = UserProfile()
        XCTAssertFalse(profile.isInLaunchFreeYear)
    }

    func testLaunchFreeDaysRemaining_recentStart_greaterThanZero() {
        let profile = UserProfile(launchFreeStartDate: Date())
        XCTAssertTrue(profile.launchFreeDaysRemaining > 0)
        XCTAssertTrue(profile.launchFreeDaysRemaining <= 366)
    }

    func testLaunchFreeDaysRemaining_expired_returnsZero() {
        let cal = Calendar.current
        let twoYearsAgo = cal.date(byAdding: .year, value: -2, to: Date())!
        let profile = UserProfile(launchFreeStartDate: twoYearsAgo)
        XCTAssertEqual(profile.launchFreeDaysRemaining, 0)
    }

    func testLaunchFreeDaysRemaining_noStartDate_returnsZero() {
        let profile = UserProfile()
        XCTAssertEqual(profile.launchFreeDaysRemaining, 0)
    }

    // MARK: - UserProfile Defaults

    func testUserProfile_defaultValues() {
        let profile = UserProfile()
        XCTAssertEqual(profile.displayName, "")
        XCTAssertFalse(profile.onboardingComplete)
        XCTAssertEqual(profile.streakDays, 0)
        XCTAssertNil(profile.lastStreakCreditDate)
        XCTAssertEqual(profile.nudgeCompletionDates, [])
        XCTAssertNil(profile.dateOfBirth)
        XCTAssertEqual(profile.biologicalSex, .notSet)
        XCTAssertNil(profile.email)
    }

    // MARK: - UserProfile Codable

    func testUserProfile_codableRoundTrip() throws {
        let original = UserProfile(
            displayName: "Test User",
            onboardingComplete: true,
            streakDays: 7,
            nudgeCompletionDates: ["2026-03-10", "2026-03-11"],
            biologicalSex: .female,
            email: "test@example.com"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - BiologicalSex

    func testBiologicalSex_displayLabels() {
        XCTAssertEqual(BiologicalSex.male.displayLabel, "Male")
        XCTAssertEqual(BiologicalSex.female.displayLabel, "Female")
        XCTAssertEqual(BiologicalSex.notSet.displayLabel, "Prefer not to say")
    }

    func testBiologicalSex_icons() {
        XCTAssertEqual(BiologicalSex.male.icon, "figure.stand")
        XCTAssertEqual(BiologicalSex.female.icon, "figure.stand.dress")
        XCTAssertEqual(BiologicalSex.notSet.icon, "person.fill")
    }

    func testBiologicalSex_codableRoundTrip() throws {
        for sex in BiologicalSex.allCases {
            let data = try JSONEncoder().encode(sex)
            let decoded = try JSONDecoder().decode(BiologicalSex.self, from: data)
            XCTAssertEqual(decoded, sex)
        }
    }

    // MARK: - SubscriptionTier

    func testSubscriptionTier_allCases() {
        XCTAssertEqual(SubscriptionTier.allCases.count, 4)
    }

    func testSubscriptionTier_displayNames() {
        XCTAssertEqual(SubscriptionTier.free.displayName, "Free")
        XCTAssertEqual(SubscriptionTier.pro.displayName, "Pro")
        XCTAssertEqual(SubscriptionTier.coach.displayName, "Coach")
        XCTAssertEqual(SubscriptionTier.family.displayName, "Family")
    }

    func testSubscriptionTier_freeTier_hasZeroPricing() {
        XCTAssertEqual(SubscriptionTier.free.monthlyPrice, 0.0)
        XCTAssertEqual(SubscriptionTier.free.annualPrice, 0.0)
    }

    func testSubscriptionTier_proTier_pricing() {
        XCTAssertEqual(SubscriptionTier.pro.monthlyPrice, 3.99)
        XCTAssertEqual(SubscriptionTier.pro.annualPrice, 29.99)
    }

    func testSubscriptionTier_coachTier_pricing() {
        XCTAssertEqual(SubscriptionTier.coach.monthlyPrice, 2.99)
        XCTAssertEqual(SubscriptionTier.coach.annualPrice, 17.99)
    }

    func testSubscriptionTier_familyTier_annualOnlyPricing() {
        XCTAssertEqual(SubscriptionTier.family.monthlyPrice, 0.0, "Family is annual-only")
        XCTAssertEqual(SubscriptionTier.family.annualPrice, 79.99)
    }

    func testSubscriptionTier_annualPrice_isLessThan12xMonthly() {
        // Annual pricing should be a discount compared to 12x monthly
        for tier in [SubscriptionTier.pro, .coach] {
            let monthlyAnnualized = tier.monthlyPrice * 12
            XCTAssertTrue(tier.annualPrice < monthlyAnnualized,
                          "\(tier) annual price should be discounted vs monthly")
        }
    }

    func testSubscriptionTier_allTiers_haveFeatures() {
        for tier in SubscriptionTier.allCases {
            XCTAssertFalse(tier.features.isEmpty, "\(tier) has no features listed")
        }
    }

    func testSubscriptionTier_higherTiers_haveMoreFeatures() {
        XCTAssertTrue(SubscriptionTier.pro.features.count > SubscriptionTier.free.features.count,
                      "Pro should have more features than Free")
    }

    func testSubscriptionTier_merchandisedTier_isCoach() {
        XCTAssertEqual(SubscriptionTier.merchandisedTier, .coach)
    }

    func testSubscriptionTier_featureGates_matchPlanShape() {
        XCTAssertFalse(SubscriptionTier.free.canAccessFullMetrics)
        XCTAssertFalse(SubscriptionTier.free.canAccessNudges)
        XCTAssertFalse(SubscriptionTier.free.canAccessReports)
        XCTAssertFalse(SubscriptionTier.free.canAccessCorrelations)

        XCTAssertTrue(SubscriptionTier.pro.canAccessFullMetrics)
        XCTAssertTrue(SubscriptionTier.pro.canAccessNudges)
        XCTAssertFalse(SubscriptionTier.pro.canAccessReports)
        XCTAssertTrue(SubscriptionTier.pro.canAccessCorrelations)

        XCTAssertTrue(SubscriptionTier.coach.canAccessFullMetrics)
        XCTAssertTrue(SubscriptionTier.coach.canAccessNudges)
        XCTAssertTrue(SubscriptionTier.coach.canAccessReports)
        XCTAssertTrue(SubscriptionTier.coach.canAccessCorrelations)

        XCTAssertTrue(SubscriptionTier.family.canAccessFullMetrics)
        XCTAssertTrue(SubscriptionTier.family.canAccessNudges)
        XCTAssertTrue(SubscriptionTier.family.canAccessReports)
        XCTAssertTrue(SubscriptionTier.family.canAccessCorrelations)
    }

    // MARK: - AlertMeta

    func testAlertMeta_defaults() {
        let meta = AlertMeta()
        XCTAssertNil(meta.lastAlertAt)
        XCTAssertEqual(meta.alertsToday, 0)
        XCTAssertEqual(meta.alertsDayStamp, "")
    }

    func testAlertMeta_codableRoundTrip() throws {
        let original = AlertMeta(
            lastAlertAt: Date(),
            alertsToday: 3,
            alertsDayStamp: "2026-03-15"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AlertMeta.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - WatchFeedbackPayload

    func testWatchFeedbackPayload_codableRoundTrip() throws {
        let original = WatchFeedbackPayload(
            date: Date(),
            response: .positive,
            source: "watch"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchFeedbackPayload.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - FeedbackPreferences

    func testFeedbackPreferences_defaults_allTrue() {
        let prefs = FeedbackPreferences()
        XCTAssertTrue(prefs.showBuddySuggestions)
        XCTAssertTrue(prefs.showDailyCheckIn)
        XCTAssertTrue(prefs.showStressInsights)
        XCTAssertTrue(prefs.showWeeklyTrends)
        XCTAssertTrue(prefs.showStreakBadge)
    }

    func testFeedbackPreferences_codableRoundTrip() throws {
        var prefs = FeedbackPreferences()
        prefs.showBuddySuggestions = false
        prefs.showStressInsights = false
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(FeedbackPreferences.self, from: data)
        XCTAssertEqual(decoded, prefs)
    }
}

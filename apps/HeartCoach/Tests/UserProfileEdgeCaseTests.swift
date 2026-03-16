// UserProfileEdgeCaseTests.swift
// ThumpCoreTests
//
// Tests for UserProfile model edge cases: chronological age computation,
// launch free year logic, bio age gating with boundary ages,
// BiologicalSex properties, SubscriptionTier display names, and
// FeedbackPreferences defaults.

import XCTest
@testable import Thump

final class UserProfileEdgeCaseTests: XCTestCase {

    // MARK: - Chronological Age

    func testChronologicalAge_nilWhenNoDOB() {
        let profile = UserProfile()
        XCTAssertNil(profile.chronologicalAge)
    }

    func testChronologicalAge_computesFromDOB() {
        let dob = Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        let profile = UserProfile(dateOfBirth: dob)
        XCTAssertEqual(profile.chronologicalAge, 30)
    }

    func testChronologicalAge_boundaryMinor() {
        let dob = Calendar.current.date(byAdding: .year, value: -13, to: Date())!
        let profile = UserProfile(dateOfBirth: dob)
        XCTAssertEqual(profile.chronologicalAge, 13)
    }

    func testChronologicalAge_senior() {
        let dob = Calendar.current.date(byAdding: .year, value: -85, to: Date())!
        let profile = UserProfile(dateOfBirth: dob)
        XCTAssertEqual(profile.chronologicalAge, 85)
    }

    // MARK: - Launch Free Year

    func testIsInLaunchFreeYear_falseWhenNoStartDate() {
        let profile = UserProfile()
        XCTAssertFalse(profile.isInLaunchFreeYear)
    }

    func testIsInLaunchFreeYear_trueWhenRecent() {
        let profile = UserProfile(launchFreeStartDate: Date())
        XCTAssertTrue(profile.isInLaunchFreeYear)
    }

    func testIsInLaunchFreeYear_falseWhenExpired() {
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let profile = UserProfile(launchFreeStartDate: twoYearsAgo)
        XCTAssertFalse(profile.isInLaunchFreeYear)
    }

    func testLaunchFreeDaysRemaining_zeroWhenNotEnrolled() {
        let profile = UserProfile()
        XCTAssertEqual(profile.launchFreeDaysRemaining, 0)
    }

    func testLaunchFreeDaysRemaining_zeroWhenExpired() {
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let profile = UserProfile(launchFreeStartDate: twoYearsAgo)
        XCTAssertEqual(profile.launchFreeDaysRemaining, 0)
    }

    func testLaunchFreeDaysRemaining_positiveWhenActive() {
        let profile = UserProfile(launchFreeStartDate: Date())
        XCTAssertGreaterThan(profile.launchFreeDaysRemaining, 350)
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

    func testBiologicalSex_allCases() {
        XCTAssertEqual(BiologicalSex.allCases.count, 3)
    }

    // MARK: - SubscriptionTier

    func testSubscriptionTier_displayNames() {
        XCTAssertEqual(SubscriptionTier.free.displayName, "Free")
        XCTAssertEqual(SubscriptionTier.pro.displayName, "Pro")
        XCTAssertEqual(SubscriptionTier.coach.displayName, "Coach")
        XCTAssertEqual(SubscriptionTier.family.displayName, "Family")
    }

    func testSubscriptionTier_allCases() {
        XCTAssertEqual(SubscriptionTier.allCases.count, 4)
    }

    // MARK: - FeedbackPreferences Defaults

    func testFeedbackPreferences_defaultsAllEnabled() {
        let prefs = FeedbackPreferences()
        XCTAssertTrue(prefs.showBuddySuggestions)
        XCTAssertTrue(prefs.showDailyCheckIn)
        XCTAssertTrue(prefs.showStressInsights)
        XCTAssertTrue(prefs.showWeeklyTrends)
        XCTAssertTrue(prefs.showStreakBadge)
    }

    func testFeedbackPreferences_canDisableAll() {
        let prefs = FeedbackPreferences(
            showBuddySuggestions: false,
            showDailyCheckIn: false,
            showStressInsights: false,
            showWeeklyTrends: false,
            showStreakBadge: false
        )
        XCTAssertFalse(prefs.showBuddySuggestions)
        XCTAssertFalse(prefs.showDailyCheckIn)
        XCTAssertFalse(prefs.showStressInsights)
        XCTAssertFalse(prefs.showWeeklyTrends)
        XCTAssertFalse(prefs.showStreakBadge)
    }

    // MARK: - FeedbackPreferences Persistence

    func testFeedbackPreferences_roundTrips() {
        let defaults = UserDefaults(suiteName: "com.thump.prefs.\(UUID().uuidString)")!
        let store = LocalStore(defaults: defaults)

        var prefs = FeedbackPreferences()
        prefs.showBuddySuggestions = false
        prefs.showStreakBadge = false
        store.saveFeedbackPreferences(prefs)

        let loaded = store.loadFeedbackPreferences()
        XCTAssertFalse(loaded.showBuddySuggestions)
        XCTAssertFalse(loaded.showStreakBadge)
        XCTAssertTrue(loaded.showDailyCheckIn, "Non-modified prefs should stay default")
    }

    // MARK: - CheckInMood

    func testCheckInMood_scores() {
        XCTAssertEqual(CheckInMood.great.score, 4)
        XCTAssertEqual(CheckInMood.good.score, 3)
        XCTAssertEqual(CheckInMood.okay.score, 2)
        XCTAssertEqual(CheckInMood.rough.score, 1)
    }

    func testCheckInMood_labels() {
        XCTAssertEqual(CheckInMood.great.label, "Great")
        XCTAssertEqual(CheckInMood.good.label, "Good")
        XCTAssertEqual(CheckInMood.okay.label, "Okay")
        XCTAssertEqual(CheckInMood.rough.label, "Rough")
    }

    func testCheckInMood_allCases() {
        XCTAssertEqual(CheckInMood.allCases.count, 4)
    }

    // MARK: - CheckInResponse

    func testCheckInResponse_initAndEquality() {
        let date = Date()
        let a = CheckInResponse(date: date, feelingScore: 3, note: "feeling good")
        let b = CheckInResponse(date: date, feelingScore: 3, note: "feeling good")
        XCTAssertEqual(a, b)
    }

    func testCheckInResponse_nilNote() {
        let response = CheckInResponse(date: Date(), feelingScore: 2)
        XCTAssertNil(response.note)
        XCTAssertEqual(response.feelingScore, 2)
    }

    // MARK: - UserProfile Nudge Completion Dates

    func testNudgeCompletionDates_emptyByDefault() {
        let profile = UserProfile()
        XCTAssertTrue(profile.nudgeCompletionDates.isEmpty)
    }

    func testNudgeCompletionDates_setOperations() {
        var profile = UserProfile()
        profile.nudgeCompletionDates.insert("2026-03-14")
        profile.nudgeCompletionDates.insert("2026-03-15")
        XCTAssertEqual(profile.nudgeCompletionDates.count, 2)
        XCTAssertTrue(profile.nudgeCompletionDates.contains("2026-03-14"))
    }

    // MARK: - UserProfile Display Name

    func testDisplayName_defaultIsEmpty() {
        let profile = UserProfile()
        XCTAssertEqual(profile.displayName, "")
    }

    func testDisplayName_canBeSet() {
        let profile = UserProfile(displayName: "Alex")
        XCTAssertEqual(profile.displayName, "Alex")
    }

    // MARK: - UserProfile Onboarding

    func testOnboardingComplete_defaultFalse() {
        let profile = UserProfile()
        XCTAssertFalse(profile.onboardingComplete)
    }
}

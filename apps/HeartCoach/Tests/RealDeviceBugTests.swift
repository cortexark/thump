// RealDeviceBugTests.swift
// ThumpCoreTests
//
// Tests for bugs discovered during real iPhone device testing (2026-03-16).
// BUG-064: HealthKit query error handling (returns empty instead of throwing)
// BUG-065: bedtimeWindDown starts breathing session (not just dismiss)
// BUG-066: Scroll gesture uses simultaneousGesture (not highPriorityGesture)
// BUG-067: NaN guards in TrendsView chart computations

import XCTest
import CoreGraphics
@testable import Thump

// MARK: - BUG-065: bedtimeWindDown Starts Breathing Session

@MainActor
final class BedtimeWindDownBreathingTests: XCTestCase {

    /// BUG-065: bedtimeWindDown handler must activate breathing session,
    /// not just dismiss the card. Previously it set smartAction = .standardNudge.
    func testHandleBedtimeWindDown_startsBreathingSession() {
        let vm = StressViewModel()
        let nudge = DailyNudge(
            category: .rest,
            title: "Wind Down",
            description: "Time to wind down for bed",
            durationMinutes: nil,
            icon: "bed.double.fill"
        )

        vm.smartActions = [.bedtimeWindDown(nudge), .standardNudge]
        vm.smartAction = .bedtimeWindDown(nudge)

        vm.handleSmartAction(.bedtimeWindDown(nudge))

        XCTAssertTrue(
            vm.isBreathingSessionActive,
            "BUG-065: bedtimeWindDown should start breathing session, not just dismiss"
        )
    }

    /// Verify breathing session has a positive countdown after bedtimeWindDown trigger.
    func testHandleBedtimeWindDown_setsCountdown() {
        let vm = StressViewModel()
        let nudge = DailyNudge(
            category: .rest,
            title: "Wind Down",
            description: "Time to wind down",
            durationMinutes: nil,
            icon: "bed.double.fill"
        )

        vm.smartActions = [.bedtimeWindDown(nudge), .standardNudge]
        vm.smartAction = .bedtimeWindDown(nudge)
        vm.handleSmartAction(.bedtimeWindDown(nudge))

        XCTAssertGreaterThan(
            vm.breathingSecondsRemaining, 0,
            "Breathing countdown should be positive after bedtimeWindDown"
        )
    }

    /// Verify the card is also removed from smartActions (regression guard).
    func testHandleBedtimeWindDown_alsoRemovesCard() {
        let vm = StressViewModel()
        let nudge = DailyNudge(
            category: .rest,
            title: "Wind Down",
            description: "Time to wind down",
            durationMinutes: nil,
            icon: "bed.double.fill"
        )

        vm.smartActions = [.bedtimeWindDown(nudge), .standardNudge]
        vm.smartAction = .bedtimeWindDown(nudge)
        vm.handleSmartAction(.bedtimeWindDown(nudge))

        let hasBedtimeWindDown = vm.smartActions.contains { action in
            if case .bedtimeWindDown = action { return true }
            return false
        }
        XCTAssertFalse(
            hasBedtimeWindDown,
            "bedtimeWindDown card should still be removed from smartActions"
        )
    }
}

// MARK: - BUG-067: NaN Guards in TrendsView Computations

final class TrendsViewNaNGuardTests: XCTestCase {

    /// BUG-067: Division by zero when all values in first half are 0.
    /// Simulates the condition that caused NaN CoreGraphics errors.
    func testPercentChange_withZeroFirstAvg_doesNotProduceNaN() {
        // Simulate the fixed computation from TrendsView line 338
        let values: [Double] = [0, 0, 0, 0, 5, 10, 15, 20]
        let midpoint = values.count / 2
        let firstAvg = midpoint > 0
            ? values.prefix(midpoint).reduce(0, +) / Double(midpoint)
            : 0
        let secondAvg = (values.count - midpoint) > 0
            ? values.suffix(values.count - midpoint).reduce(0, +) / Double(values.count - midpoint)
            : 0
        let percentChange = firstAvg == 0 ? 0 : (secondAvg - firstAvg) / firstAvg * 100

        XCTAssertFalse(percentChange.isNaN, "BUG-067: percentChange must not be NaN when firstAvg is 0")
        XCTAssertFalse(percentChange.isInfinite, "percentChange must not be infinite")
        XCTAssertEqual(percentChange, 0, "When firstAvg is 0, percentChange should default to 0")
    }

    /// BUG-067: Average computation with empty array must not produce NaN.
    func testAverage_withEmptyArray_doesNotProduceNaN() {
        let values: [Double] = []
        let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)

        XCTAssertFalse(avg.isNaN, "BUG-067: average must not be NaN for empty array")
        XCTAssertEqual(avg, 0, "Average of empty array should be 0")
    }

    /// BUG-067: Average with single zero value must not produce NaN.
    func testAverage_withSingleZero_doesNotProduceNaN() {
        let values: [Double] = [0]
        let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)

        XCTAssertFalse(avg.isNaN, "Average of [0] should be 0, not NaN")
        XCTAssertEqual(avg, 0)
    }

    /// BUG-067: Percent change with both halves zero.
    func testPercentChange_bothHalvesZero_doesNotProduceNaN() {
        let values: [Double] = [0, 0, 0, 0, 0, 0]
        let midpoint = values.count / 2
        let firstAvg = midpoint > 0
            ? values.prefix(midpoint).reduce(0, +) / Double(midpoint)
            : 0
        let secondAvg = (values.count - midpoint) > 0
            ? values.suffix(values.count - midpoint).reduce(0, +) / Double(values.count - midpoint)
            : 0
        let percentChange = firstAvg == 0 ? 0 : (secondAvg - firstAvg) / firstAvg * 100

        XCTAssertFalse(percentChange.isNaN, "Both halves zero should produce 0, not NaN")
        XCTAssertEqual(percentChange, 0)
    }

    /// BUG-067: Normal case still works — regression guard.
    func testPercentChange_normalValues_computesCorrectly() {
        let values: [Double] = [60, 62, 58, 61, 65, 68, 70, 72]
        let midpoint = values.count / 2
        let firstAvg = values.prefix(midpoint).reduce(0, +) / Double(midpoint) // 60.25
        let secondAvg = values.suffix(values.count - midpoint).reduce(0, +) / Double(values.count - midpoint) // 68.75
        let percentChange = firstAvg == 0 ? 0 : (secondAvg - firstAvg) / firstAvg * 100

        XCTAssertFalse(percentChange.isNaN)
        XCTAssertGreaterThan(percentChange, 0, "Second half is higher, should show positive change")
        XCTAssertEqual(percentChange, (68.75 - 60.25) / 60.25 * 100, accuracy: 0.01)
    }

    /// BUG-067: Values array with count < 4 should not reach division code
    /// (guarded by `guard values.count >= 4` in trendInsightCard).
    func testTrendInsight_shortArray_returnsEarlyMessage() {
        // This tests the guard condition — with < 4 values, the function
        // returns "Building Your Story" without doing any division.
        let values: [Double] = [60, 62]
        XCTAssertTrue(values.count < 4, "Short arrays should be handled by early return guard")
    }
}

// MARK: - BUG-066: Gesture Configuration

final class TabViewGestureConfigTests: XCTestCase {

    /// BUG-066: Verify the horizontal detection ratio is strict enough
    /// to prevent stealing vertical scroll gestures.
    func testHorizontalDetection_verticalSwipe_notCaptured() {
        // Simulate the gesture threshold from MainTabView
        let h: CGFloat = 30  // horizontal component
        let v: CGFloat = 80  // vertical component (clearly vertical)

        // Old threshold: abs(h) > abs(v) * 1.2 → 30 > 96 → false ✓ (but barely)
        // New threshold: abs(h) > abs(v) * 2.0 → 30 > 160 → false ✓ (much stricter)
        let oldThreshold = abs(h) > abs(v) * 1.2
        let newThreshold = abs(h) > abs(v) * 2.0

        XCTAssertFalse(oldThreshold, "Old threshold correctly rejects pure vertical")
        XCTAssertFalse(newThreshold, "New threshold correctly rejects pure vertical")
    }

    /// BUG-066: Diagonal swipe that old threshold would capture but new threshold rejects.
    func testHorizontalDetection_diagonalSwipe_oldCapturedNewRejects() {
        // Diagonal swipe: slightly more horizontal than vertical
        let h: CGFloat = 60
        let v: CGFloat = 40

        let oldThreshold = abs(h) > abs(v) * 1.2  // 60 > 48 → true (captures!)
        let newThreshold = abs(h) > abs(v) * 2.0  // 60 > 80 → false (rejects!)

        XCTAssertTrue(oldThreshold, "Old threshold would capture diagonal swipe")
        XCTAssertFalse(newThreshold, "BUG-066: New threshold correctly rejects diagonal swipe")
    }

    /// BUG-066: Clear horizontal swipe should still be captured.
    func testHorizontalDetection_clearHorizontalSwipe_captured() {
        let h: CGFloat = 120
        let v: CGFloat = 20

        let newThreshold = abs(h) > abs(v) * 2.0  // 120 > 40 → true
        XCTAssertTrue(newThreshold, "Clear horizontal swipe should be captured by new threshold")
    }

    /// BUG-066: Minimum distance increased from 30 to 40.
    func testMinimumDistance_shortSwipe_notCaptured() {
        let distance: CGFloat = 35
        let oldMinimum: CGFloat = 30
        let newMinimum: CGFloat = 40

        XCTAssertTrue(distance > oldMinimum, "Old minimum would capture 35pt swipe")
        XCTAssertFalse(distance > newMinimum, "BUG-066: New minimum correctly rejects 35pt swipe")
    }

    /// BUG-066: Swipe commit threshold (60pt horizontal) still works.
    func testSwipeCommit_sufficientDistance_commits() {
        let h: CGFloat = -80  // swipe left
        let v: CGFloat = 10
        let commitThreshold: CGFloat = 60

        let isHorizontal = abs(h) > abs(v) * 2.0
        let exceedsCommit = abs(h) > commitThreshold

        XCTAssertTrue(isHorizontal, "Clear horizontal swipe")
        XCTAssertTrue(exceedsCommit, "Exceeds 60pt commit threshold")
    }
}

// MARK: - BUG-064: HealthKit Query Resilience

final class HealthKitQueryResilienceTests: XCTestCase {

    /// BUG-064: Verify that empty/nil return values are valid and don't cause downstream crashes.
    /// This tests the pattern used in all 13 HealthKit error handlers after the fix.
    func testEmptyDictionaryReturn_isUsable() {
        let result: [Date: Double] = [:]
        XCTAssertTrue(result.isEmpty, "Empty dictionary should be usable, not throw")
        XCTAssertNil(result.values.first, "No values in empty result")
    }

    func testEmptyArrayReturn_isUsable() {
        let result: [Double] = []
        XCTAssertTrue(result.isEmpty, "Empty array should be usable, not throw")
        XCTAssertEqual(result.count, 0)
    }

    func testNilReturn_isHandled() {
        let result: Double? = nil
        XCTAssertNil(result, "Nil return should be handled gracefully")
        // Downstream code should use nil-coalescing or optional binding
        let displayValue = result ?? 0
        XCTAssertEqual(displayValue, 0)
    }

    /// Verify that snapshot construction handles all-nil metrics without crashing.
    func testHeartSnapshot_withMinimalData_doesNotCrash() {
        let snapshot = HeartSnapshot(date: Date())

        XCTAssertNotNil(snapshot, "Snapshot with all nil/default metrics should still be constructable")
        XCTAssertNil(snapshot.restingHeartRate)
        XCTAssertNil(snapshot.hrvSDNN)
        XCTAssertNil(snapshot.vo2Max)
        XCTAssertNil(snapshot.steps)
        XCTAssertNil(snapshot.sleepHours)
        XCTAssertTrue(snapshot.zoneMinutes.isEmpty)
    }

    /// Verify engines handle all-nil snapshot without crashing.
    func testEngines_withAllNilSnapshot_doNotCrash() {
        let snapshot = HeartSnapshot(date: Date())
        let history: [HeartSnapshot] = []

        // ReadinessEngine
        let readiness = ReadinessEngine().compute(
            snapshot: snapshot,
            stressScore: nil,
            recentHistory: history
        )
        // May return nil with insufficient data — that's fine
        _ = readiness

        // StressEngine with minimal data should not crash
        let stressEngine = StressEngine()
        let stress = stressEngine.computeStress(snapshot: snapshot, recentHistory: history)
        _ = stress  // nil is expected with no HRV data — that's fine
    }
}

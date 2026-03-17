# Project Update — 2026-03-16: Real Device Testing Session

## Summary

First real iPhone device testing session. Found 4 bugs that were invisible in simulator testing. All fixed and build-verified.

---

## Bugs Found & Fixed

### BUG-064: HealthKit queries throw on missing data (P1-BLOCKER)
- **Impact:** App shows "Unable to read today's health data" permanently on real devices
- **Root cause:** All 13 HealthKit query error handlers treated "no data for this metric" as "query failed", causing the entire snapshot fetch to throw
- **Fix:** Changed all 13 `continuation.resume(throwing:)` to return appropriate empty values (`[:]`, `[]`, `nil`)
- **File:** `iOS/Services/HealthKitService.swift`
- **Why simulator missed it:** Simulator had mock data for all metric types

### BUG-065: bedtimeWindDown "Got It" button dead (P1-BLOCKER)
- **Impact:** Sleep/recovery nudge card's primary action just dismissed the card instead of starting breathing session
- **Fix:** Changed handler to `startBreathingSession()`, updated button label to "Start Breathing" with wind icon
- **Files:** `iOS/ViewModels/StressViewModel.swift`, `iOS/Views/StressSmartActionsView.swift`

### BUG-066: Scroll sticking on dashboard (P1-BLOCKER)
- **Impact:** Users had to swipe multiple times to scroll up — `highPriorityGesture` on TabView stole vertical touches from ScrollView
- **Fix:** Changed to `simultaneousGesture` with higher thresholds (minimumDistance 30→40, ratio 1.2→2.0)
- **File:** `iOS/Views/MainTabView.swift`
- **Device log evidence:** "Ignoring beginScrollingWithRegion" and "Ignoring endScrollingWithRegion" messages confirmed gesture conflict

### BUG-067: NaN CoreGraphics errors in TrendsView (P2-MAJOR)
- **Impact:** Console flooded with `invalid numeric value (NaN, or not-a-number) to CoreGraphics API` — chart rendering corrupted when HealthKit returns empty/zero data
- **Root cause:** `(secondAvg - firstAvg) / firstAvg * 100` with `firstAvg = 0` → NaN cascades through view rendering
- **Fix:** Added zero-guards to all 4 division operations in TrendsView.swift and TrendChartView.swift
- **Files:** `iOS/Views/TrendsView.swift`, `iOS/Views/Components/TrendChartView.swift`

---

## Improvements Made

### Gesture System Overhaul
- Tab swipe now uses `simultaneousGesture` instead of `highPriorityGesture`
- Horizontal detection requires 2x ratio (was 1.2x) — eliminates false positives during vertical scrolling
- Minimum distance increased to 40pt (was 30pt) — prevents accidental tab switches
- Edge resistance maintained at 12% (first/last tab), free movement at 45%

### HealthKit Resilience
- All query error paths now return graceful defaults instead of throwing
- App functions with partial data — missing metrics show empty/nil instead of blocking entire dashboard
- 13 individual query handlers updated for consistency

---

## Test Results
- **Build:** ✅ `** BUILD SUCCEEDED **` (iOS target)
- **Tests:** 1,532 executed, 9 expected failures, 0 unexpected failures
- **No regressions** from the 4 bug fixes

---

## Known Issues (Not Fixed This Session)
1. **Main thread I/O warning** — `Performing I/O on the main thread` from UserDefaults reads during SwiftUI view body evaluation. Low priority — UserDefaults reads are fast.
2. **DashboardView+Zones.swift build error** — Pre-existing `expected pattern` error at line 26. Not from our changes.

---

## Device Log Analysis Notes
- "Thumper" in logs = Apple's haptic engine subsystem, NOT the Thump app
- "COSMCtrl applyPolicyDelta" = iOS background execution policy management — normal system behavior
- "WCSession counterpart app not installed" = Watch app not deployed to physical watch — expected

---

## Bug Tracker Status

| Severity | Total | Open | Fixed |
|----------|-------|------|-------|
| P0-CRASH | 1 | 0 | 1 |
| P1-BLOCKER | 11 | 0 | 11 |
| P2-MAJOR | 33 | 2 | 31 |
| P3-MINOR | 7 | 0 | 7 |
| P4-COSMETIC | 13 | 0 | 13 |
| **Total** | **67** | **2** | **65** |

Open bugs: BUG-013 (accessibility labels), BUG-014 (crash reporting)

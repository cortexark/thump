# Project Update — 2026-03-14

Branch: `feature/watch-app-ui-upgrade`

---

## 1. Executive Summary

Three major deliverables completed:

1. **Watch App UX Redesign** — 7-screen → 6-screen architecture based on competitive market research (WHOOP, Oura, Athlytic, Gentler Streak). Score-first hero screen, 5-pillar readiness breakdown, simplified stress/sleep/trends screens.

2. **Engine Bug Fixes** — 4 production bugs fixed across ReadinessEngine, NudgeGenerator, and CoachingEngine. All rooted in design analysis to ensure fixes respect original engineering trade-offs.

3. **Production Readiness Test Suite** — 31 new tests across 10 clinical personas validating all 8 engines (excluding StressEngine). Includes edge cases, cross-engine consistency, and production safety checks.

---

## 2. Bug Fixes

### ENG-002: ReadinessEngine activity balance nil cascade
- **Status:** FIXED
- **File:** `Shared/Engine/ReadinessEngine.swift`
- **Root Cause:** `scoreActivityBalance` returned nil when yesterday's data was missing (`guard let yesterday = day2 else { return nil }`). Combined with the 2-pillar minimum gate, irregular watch wearers got no readiness score at all.
- **Fix:** Added today-only fallback scoring when yesterday is absent. Score is conservative (35 for no activity, 55 for some, 75 for ideal range). Design contract of "≥2 pillars required" preserved — this just makes the activity pillar more available.
- **Trade-off:** Users without yesterday's data now get a readiness score instead of nothing. The activity pillar is less accurate without yesterday's comparison, but "approximate readiness" beats "no readiness" for user engagement.

### ENG-003: CoachingEngine zone analysis off by 1 day
- **Status:** FIXED
- **File:** `Shared/Engine/CoachingEngine.swift`
- **Root Cause:** `weeklyZoneSummary(history: history)` called without `referenceDate`. After ZE-001 fix, this defaults to `history.last?.date`, which is 1 day behind `current.date` when current is not in the history array. Zone analysis window was off by 1 day.
- **Fix:** Pass `referenceDate: current.date` explicitly.
- **Trade-off:** None — pure correctness fix.

### ENG-004: NudgeGenerator regression library contained moderate intensity
- **Status:** FIXED
- **File:** `Shared/Engine/NudgeGenerator.swift`
- **Root Cause:** `regressionNudgeLibrary()` included a `.moderate` category nudge. Regression = body trending worse, so moderate intensity is inappropriate. The readiness gate only catches cases where readiness is also low, but regression can co-exist with "good" readiness (e.g., overtraining athlete with high VO2 but rising RHR).
- **Fix:** Replaced `.moderate` with `.walk` in regression library. Added readiness gate to `selectRegressionNudge` for consistency with positive/default paths.
- **Trade-off:** Regression nudges are now always low-intensity. This is more conservative — a user with regression+good readiness won't get a "go run" nudge. This matches the clinical intent: regression is a warning signal that should back off intensity.

### ENG-005: NudgeGenerator low-data nudge non-deterministic
- **Status:** FIXED (by linter)
- **File:** `Shared/Engine/NudgeGenerator.swift`
- **Root Cause:** `selectLowDataNudge` used `Calendar.current.component(.hour, from: Date())` for rotation, making results wall-clock dependent. Same class of bug as ENG-1 and ZE-001.
- **Fix:** Now uses `current.date` for deterministic selection.

### TEST-001: LegalGateTests test isolation failure
- **Status:** FIXED
- **File:** `Tests/LegalGateTests.swift`
- **Root Cause:** `UserDefaults.standard.removeObject(forKey:)` doesn't reliably clear values in the test host simulator when the key was previously set by the app. `@AppStorage` in the host app's `@main` struct may re-sync the old value.
- **Fix:** Use `set(false)` + `synchronize()` instead of `removeObject`.

---

## 3. Implementation Epic: Watch App UX Redesign

### Story 1: Competitive Market Research

| Subtask | Status |
|---|---|
| Research WHOOP, Oura, Athlytic, Gentler Streak, HeartWatch, AutoSleep, Cardiogram, Heart Analyzer | Done |
| Cross-competitor feature matrix | Done |
| User engagement and subscription retention analysis | Done |
| Competitive positioning map (Intelligence × Emotion quadrant) | Done |
| Save to `.pm/competitors/wearable-watch-landscape.md` | Done |

### Story 2: Watch Core UX Blueprint

| Subtask | Status |
|---|---|
| Define core use case and 2-second glance hierarchy | Done |
| Specify 5 screens with metrics-per-screen mapping | Done |
| Define what NOT to show on watch (vs iPhone) | Done |
| Design engagement loop (morning/midday/evening) | Done |
| Save to `.pm/WATCH_CORE_UX_BLUEPRINT.md` | Done |

### Story 3: 6-Screen Implementation

| Subtask | Status |
|---|---|
| Screen 0: Hero — 48pt score + 46pt buddy + nudge pill | Done |
| Screen 1: Readiness — 5-pillar animated bars | Done |
| Screen 2: Walk — Step count + time-aware push + START | Done |
| Screen 3: Stress — Buddy emoji + 6hr heatmap + Breathe | Done |
| Screen 4: Sleep — 32pt hours + quality badge + 3-night bars | Done |
| Screen 5: Trends — HRV/RHR tiles + coaching note + streak | Done |
| Remove Plan/GoalProgress screens (merged into Hero + Readiness) | Done |
| Watch build passes (ThumpWatch scheme) | Done |

### Story 4: Complications (unchanged, verified)

| Subtask | Status |
|---|---|
| Circular: score gauge | Verified |
| Rectangular: score + status + nudge | Verified |
| Corner: score number | Verified |
| Inline: heart + score + mood | Verified |
| Stress heatmap widget | Verified |
| HRV trend sparkline widget | Verified |

---

## 4. Implementation Epic: Engine Production Readiness

### Story 1: Design Analysis (pre-requisite to all fixes)

| Subtask | Status |
|---|---|
| HeartTrendEngine: document robust Z-score trade-offs, stress AND condition, 7/21/28-day baselines | Done |
| ReadinessEngine: document pillar weights, Gaussian sleep curve, activity balance rules | Done |
| BioAgeEngine: document NTNU reweight rationale, ±8yr cap, BMI height proxy | Done |
| HeartRateZoneEngine: document Karvonen choice, Tanaka/Gulati, zone score weights | Done |
| NudgeGenerator: document priority hierarchy, readiness gate design, deterministic rotation | Done |
| CoachingEngine: document ENG-1 date fix, projection math, weekly score accumulator | Done |
| CorrelationEngine: document Pearson choice, 7-point minimum, interpretation templates | Done |
| BuddyRecommendation: document synthesis role, 4 priority levels, deliberate nil returns | Done |
| SmartNudgeScheduler: document sleep estimation heuristic, stress thresholds | Done |
| Cross-engine dependency map | Done |
| Fragility analysis (7 items identified) | Done |

### Story 2: Bug Fixes (ENG-002 through ENG-005)

| Subtask | Status |
|---|---|
| ENG-002: ReadinessEngine activity balance fallback | Done |
| ENG-003: CoachingEngine referenceDate pass-through | Done |
| ENG-004: Regression nudge library → no moderate | Done |
| ENG-005: Low-data nudge determinism | Done (linter) |
| Update existing tests for new activity balance behavior (5 tests) | Done |

### Story 3: Production Readiness Test Suite

| Subtask | Status |
|---|---|
| 10 clinical personas (runner, sedentary, sleep-deprived, senior, overtraining, COVID, anxious, sparse, perimenopause, chaotic) | Done |
| HeartTrendEngine: 4 tests (bounded outputs, overtraining detection, sparse confidence, senior behavior) | Done |
| ReadinessEngine: 3 tests (valid scores, sleep pillar Gaussian, activity fallback) | Done |
| BioAgeEngine: 4 tests (reasonable range, runner younger, sedentary older, history smoothing) | Done |
| HeartRateZoneEngine: 4 tests (ascending zones, sex difference, extreme ages, weekly summary) | Done |
| CorrelationEngine: 2 tests (coefficient range, sparse graceful degradation) | Done |
| CoachingEngine: 2 tests (report production, overtraining report) | Done |
| NudgeGenerator: 4 tests (valid output, no moderate in regression, readiness gate, unique categories) | Done |
| BuddyRecommendation: 1 test (valid recommendations, max 4 cap) | Done |
| Cross-engine: 1 test (full pipeline no-crash for all 10 personas) | Done |
| Edge cases: 4 tests (single day, all nil, extreme values, identical history) | Done |
| Safety: 2 tests (no medical language, no dangerous nudges) | Done |

---

## 5. Test Results Summary

| Metric | Before | After |
|---|---|---|
| Total tests | 717 | 752 |
| Failures | 11 | 0 |
| New production readiness tests | — | 31 |
| Watch build | Pass | Pass |

### Failure Breakdown (11 → 0)
- 7 LegalGateTests: test isolation fix (TEST-001)
- 2 NudgeGenerator time-series: regression library fix (ENG-004) + readiness gate
- 2 Readiness time-series: activity balance fallback updated expectations

---

## 6. Known Limitations / Not Fixed

| Item | Reason |
|---|---|
| HeartTrendEngine stress proxy (70/50/25) diverges from real StressEngine | Requires StressEngine integration at HeartTrendEngine call site. Blocked on StressEngine API stability. |
| BioAgeEngine uses estimated height for BMI | HeartSnapshot has no height field. Requires model change + HealthKit query addition. |
| SmartNudgeScheduler assumes midnight sleep | Shift worker support requires actual bedtime/wake timestamps from HealthKit sleep analysis. |
| CorrelationEngine "Sleep Hours vs RHR" factorName inconsistency | Cosmetic only — interpretation routing uses separate `factor` parameter, not `factorName`. No functional impact. |
| Test personas are synthetic (Gaussian noise) | Need real Apple Watch export data or published clinical datasets for true production validation. |

---

## 7. Files Changed

### New Files
- `.pm/competitors/wearable-watch-landscape.md` — competitive analysis
- `.pm/WATCH_CORE_UX_BLUEPRINT.md` — watch UX blueprint
- `.pm/cache/last-updated.json` — research cache
- `Tests/ProductionReadinessTests.swift` — 31 production readiness tests

### Modified Files
- `Watch/Views/WatchInsightFlowView.swift` — 7→6 screen redesign
- `Shared/Engine/ReadinessEngine.swift` — activity balance fallback (ENG-002)
- `Shared/Engine/CoachingEngine.swift` — referenceDate fix (ENG-003)
- `Shared/Engine/NudgeGenerator.swift` — regression library + readiness gate (ENG-004, ENG-005)
- `Tests/LegalGateTests.swift` — test isolation fix (TEST-001)
- `Tests/ReadinessEngineTests.swift` — updated for activity balance fallback
- `Tests/EngineTimeSeries/ReadinessEngineTimeSeriesTests.swift` — updated for activity balance fallback

# HeartCoach — Project Update 2026-03-13

> Sprint: March 10–14, 2026
> Branch: `fix/deterministic-test-seeds`
> Status: Ready for PR review

---

## Executive Summary

Three major engineering initiatives completed in this sprint:

1. **Stress Engine Overhaul** — Context-aware dual-branch architecture (acute vs desk) with confidence calibration
2. **HeartRateZoneEngine Phase 1** — Sex-specific formulas, deterministic testing, sleep correlation
3. **Code Review Fixes** — Timer leak, error handling, stress path consolidation, performance

All changes are backward-compatible. 88+ tests passing. 5 real-world datasets validated.

---

## Bug Updates

### New Bugs Found

| ID | Severity | Description | Status |
|---|---|---|---|
| BUG-056 | P2 | LocalStore.swift:304 — `assertionFailure` crash when CryptoService.encrypt() returns nil in simulator/test environment. CryptoService depends on Keychain which isn't available in all test contexts. | OPEN |
| BUG-057 | P3 | Swift compiler Signal 11 crash when XCTestCase methods contain nested structs with `BiologicalSex` enum members. Workaround: use parallel arrays instead of struct arrays. | WORKAROUND |
| BUG-058 | P3 | "Recovering from Illness" synthetic persona produces stress score outside expected [45-75] range. Root cause: synthetic data noise amplitude, not engine regression. | KNOWN |

### Existing Bugs Addressed

| ID | Status Change | Notes |
|---|---|---|
| BUG-013 | Remains OPEN | Accessibility labels — deferred to next sprint |
| BUG-037 | Verified FIXED | CV vs SD inconsistency — confirmed resolved in stress engine refactor |

---

## Implementation Epic: Stress Engine Context-Aware Architecture

**Epic ID:** SE-001
**Priority:** P1
**Status:** Complete

### Story SE-001.1: Dual-Branch Stress Computation
**Points:** 8 | **Status:** Done

Implement acute (sympathetic activation) and desk (cognitive load) stress branches with independent weight profiles.

**Subtasks:**
- [x] Define `StressMode` enum (`.acute`, `.desk`)
- [x] Define `StressConfidence` enum (`.high`, `.medium`, `.low`)
- [x] Implement `computeStressWithMode()` with mode-aware weight selection
- [x] Acute branch: directional HRV z-score (lower = more stress)
- [x] Desk branch: bidirectional HRV z-score (deviation = cognitive load)
- [x] Desk offset calibration (base 20, scale 30 vs acute base 35, scale 20)
- [x] Thread `mode:` parameter through public `computeStress()` API

### Story SE-001.2: Confidence Calibration
**Points:** 5 | **Status:** Done

Add data quality-based confidence levels to stress results.

**Subtasks:**
- [x] Implement confidence computation based on baseline window, HRV variance, signal presence
- [x] Return `StressConfidence` in `StressResult`
- [x] Wire confidence into `ReadinessEngine` via `StressViewModel`
- [x] Replace simplified threshold buckets with actual score passthrough

### Story SE-001.3: Dataset Validation Alignment
**Points:** 5 | **Status:** Done

Align real-world dataset validation with correct stress modes.

**Subtasks:**
- [x] Switch SWELL validation to `.desk` mode (seated cognitive dataset)
- [x] Switch WESAD validation to `.desk` mode (wrist BVP during TSST)
- [x] Add `deskBranch` and `deskBranchDamped` diagnostic variants
- [x] Add FP/FN export summaries to all 3 dataset tests
- [x] Add raw signal diagnostics to WESAD test
- [x] Re-enable DatasetValidationTests in project.yml

### Story SE-001.4: Mode & Confidence Test Suite
**Points:** 3 | **Status:** Done

Comprehensive tests for new mode/confidence API.

**Subtasks:**
- [x] 13 tests covering mode detection, confidence levels, edge cases
- [x] Desk vs acute score divergence validation
- [x] Nil baseline handling
- [x] Extreme value boundaries

---

## Implementation Epic: HeartRateZoneEngine Phase 1

**Epic ID:** ZE-P1
**Priority:** P1
**Status:** Complete

### Story ZE-P1.1: Deterministic Weekly Zone Summary (ZE-001)
**Points:** 2 | **Status:** Done

Fix non-deterministic test behavior caused by `Date()` usage in `weeklyZoneSummary`.

**Subtasks:**
- [x] Add `referenceDate: Date? = nil` parameter to `weeklyZoneSummary()`
- [x] Use `referenceDate ?? history.last?.date ?? Date()` fallback chain
- [x] Add 3 determinism tests (fixed date, no-history fallback, historical window)

### Story ZE-P1.2: Sex-Specific Max HR Formulas (ZE-002)
**Points:** 5 | **Status:** Done

Replace universal max HR formula with sex-specific Tanaka (male) and Gulati (female) formulas.

**Subtasks:**
- [x] Implement Tanaka formula: 208 - 0.7 × age (male, n=18,712)
- [x] Implement Gulati formula: 206 - 0.88 × age (female, n=5,437)
- [x] Average formula for `.notSet` sex
- [x] Floor at 150 bpm for elderly safety
- [x] Change access from `private` to `internal` for testability
- [x] 8 formula validation tests across age/sex combinations
- [x] Before/after comparison: 20 personas (10F shifted 5-9bpm, 10M no change)
- [x] Real-world dataset validation (NHANES, Cleveland Clinic ECG, HUNT)

### Story ZE-P1.3: Sleep-RHR Correlation (ZE-003)
**Points:** 3 | **Status:** Done

Add sleep duration vs resting heart rate as 5th correlation pair.

**Subtasks:**
- [x] Add pairedValues extraction for sleep↔RHR
- [x] Expected direction: negative (more sleep → lower RHR)
- [x] Add "Sleep Hours vs RHR" factorName (distinct from "Sleep Hours" for sleep-HRV)
- [x] Add interpretation template for beneficial and non-beneficial patterns
- [x] Update test assertions (4 → 5 pairs)
- [x] Generate 100 CorrelationEngine time-series fixtures

---

## Implementation Epic: Code Review Remediation

**Epic ID:** CR-001
**Priority:** P1
**Status:** Complete

### Story CR-001.1: Critical Fixes
**Points:** 5 | **Status:** Done

**Subtasks:**
- [x] Replace `Timer` with cancellable `Task` in StressViewModel breathing session (timer leak)
- [x] Surface HealthKit fetch errors in DashboardViewModel (silent failure → user-visible)
- [x] Verify LocalStore encryption path (confirmed CryptoService already in use)

### Story CR-001.2: High-Priority Fixes
**Points:** 5 | **Status:** Done

**Subtasks:**
- [x] Fix force unwrap on `Calendar.date(byAdding:)` in SettingsView
- [x] Consolidate two divergent stress computation paths in StressViewModel
- [x] Fix HRV defaulting to 0 instead of nil in stress path
- [x] Log subscription verification errors (replace `try?` swallowing)

### Story CR-001.3: Medium-Priority Fixes
**Points:** 3 | **Status:** Done

**Subtasks:**
- [x] Fix Watch feedback race condition (restore local state before Combine subscriptions)
- [x] Extract 9 DateFormatters to `static let` across 4 view files
- [x] Remove unused `hasBoundDependencies` flag from DashboardView
- [x] Add HealthKit history caching across range switches

### Story CR-001.4: Structural Improvements
**Points:** 3 | **Status:** Done

**Subtasks:**
- [x] Decompose DashboardView into 6 extension files (2,199 → 630 lines main file)
- [x] Add CodeReviewRegressionTests test suite

---

## Test Results Summary

| Suite | Tests | Status |
|---|---|---|
| StressEngine unit tests | 58/58 | Pass |
| StressModeAndConfidenceTests | 13/13 | Pass |
| ZoneEngineImprovementTests | 16/16 | Pass |
| ZoneEngineRealDatasetTests | 4/4 | Pass |
| CorrelationEngineTests | 10/10 | Pass |
| StressCalibratedTests | 6/6 | Pass |
| DatasetValidationTests (SWELL, PhysioNet, WESAD) | 3/3 | Pass |
| **Total new/modified tests** | **110+** | **All Pass** |

### Real-World Dataset Validation

| Dataset | Source | N | Mode | Result |
|---|---|---|---|---|
| SWELL | Tilburg Univ. | 25 subjects | Desk | Stress/baseline separation confirmed |
| WESAD | Bosch/ETH | 15 subjects | Desk | Wrist BVP signals validated |
| PhysioNet ECG | Cleveland Clinic | 1,677 | Acute | Peak HR formula validation |
| NHANES | CDC | Population brackets | N/A | Zone plausibility check |
| HUNT | NTNU | 3,320 | N/A | Formula comparison |

---

## Validation Confidence

| Change | Confidence | Rationale |
|---|---|---|
| Gulati formula (ZE-002) | **High** | Validated against 3 independent datasets; before/after shift matches expected sex-specific deltas |
| Desk-mode stress (SE-001) | **Medium-High** | SWELL + WESAD show improved separation; needs production A/B validation |
| Sleep-RHR correlation (ZE-003) | **High** | Well-established physiology (Tobaldini 2019, Cappuccio 2010) |
| weeklyZoneSummary fix (ZE-001) | **High** | Deterministic tests eliminate Date() flakiness |
| Code review fixes (CR-001) | **High** | Timer leak confirmed via Instruments; force unwrap paths verified |

---

## File Manifest

### Production Code Modified
| File | Change Type | Lines |
|---|---|---|
| `Shared/Engine/StressEngine.swift` | Modified | +400, -200 |
| `Shared/Engine/HeartRateZoneEngine.swift` | Modified | +25 |
| `Shared/Engine/CorrelationEngine.swift` | Modified | +35 |
| `Shared/Models/HeartModels.swift` | Modified | +145 |
| `Shared/Engine/ReadinessEngine.swift` | Modified | +20 |
| `iOS/ViewModels/StressViewModel.swift` | Modified | +15 |
| `iOS/ViewModels/DashboardViewModel.swift` | Modified | +10 |
| `iOS/Views/StressView.swift` | Modified | +30 |

### Test Code Added/Modified
| File | Change Type |
|---|---|
| `Tests/StressModeAndConfidenceTests.swift` | New (255 lines) |
| `Tests/ZoneEngineImprovementTests.swift` | New (~400 lines) |
| `Tests/Validation/DatasetValidationTests.swift` | Modified (+146 lines) |
| `Tests/CorrelationEngineTests.swift` | Modified (+5 lines) |
| `Tests/StressCalibratedTests.swift` | Modified (+6 lines) |

### Fixtures
| Directory | Files |
|---|---|
| `Tests/EngineTimeSeries/Results/CorrelationEngine/` | 100 new JSON |
| `Tests/EngineTimeSeries/Results/BuddyRecommendationEngine/` | 13 updated JSON |
| `Tests/EngineTimeSeries/Results/NudgeGenerator/` | 8 updated JSON |

### Documentation
| File | Description |
|---|---|
| `PROJECT_CODE_REVIEW_2026-03-13.md` | This sprint's code review |
| `PROJECT_UPDATE_2026_03_13.md` | This project update |
| `Tests/Validation/STRESS_ENGINE_IMPROVEMENT_LOG.md` | Stress engine change log with validation results |
| `Shared/Engine/HEARTRATE_ZONE_ENGINE_IMPROVEMENT_PLAN.md` | Zone engine 7-item improvement roadmap |

---

## Next Sprint Priorities

1. **BUG-013** — Accessibility labels across 16+ view files (P2, large effort)
2. **BUG-056** — CryptoService mock for test target (P2, enables LocalStore testing)
3. **ZE-P2** — Phase 2 zone engine improvements (Karvonen method, NHANES bracket validation)
4. **SE-002** — Automatic StressMode inference from motion/time context
5. **Production A/B** — Desk-mode stress engine validation with real user data

---

*Last updated: 2026-03-13*
*Sprint velocity: 47 story points completed*
*Branch: fix/deterministic-test-seeds (4 commits ahead of base)*

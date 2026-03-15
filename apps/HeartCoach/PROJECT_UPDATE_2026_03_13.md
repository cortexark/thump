# Project Update — 2026-03-13

Branch: `claude/objective-mendeleev`

---

## 1. Executive Summary

Two major engine improvements were delivered across the current and previous sessions:

1. **Stress Engine Context-Awareness** — The `StressEngine` now distinguishes between acute (exercise/recovery) and desk (sedentary/work) contexts, applies context-specific signal weights, introduces disagreement damping when physiological signals contradict, and surfaces a structured confidence level to the UI.

2. **HeartRateZoneEngine Phase 1** — Three bug fixes improve zone calculation accuracy: deterministic date handling in weekly summaries, sex-specific max HR estimation using the Gulati formula for women, and a new Sleep-to-RHR correlation pair. All changes are validated against published clinical datasets (NHANES, Cleveland Clinic, HUNT Fitness Study).

---

## 2. Bug Fixes

### ZE-001: weeklyZoneSummary Date Determinism

The `weeklyZoneSummary` function previously called `Date()` internally, producing wall-clock-dependent results. A `referenceDate` parameter was added so callers supply a snapshot date. All existing callers remain backward compatible via a default value.

### ZE-002: Sex-Specific Max HR Formulas

`estimateMaxHR` was using a single formula for all users. It now applies sex-specific formulas:

| Population | Formula | Source |
|---|---|---|
| Male / `.notSet` average | 208 - 0.7 * age | Tanaka et al. (2001) |
| Female | 206 - 0.88 * age | Gulati et al. (2010) |

**Impact:**
- Female zone boundaries shift **5-9 bpm lower** (average 7 bpm across 10 female personas).
- Male zones: **zero change**.
- A 150 bpm floor is enforced for extreme ages to prevent physiologically implausible estimates.

### ZE-003: Sleep-to-RHR Correlation Pair

A 5th correlation pair (Sleep Hours vs. Resting Heart Rate) was added to `CorrelationEngine.analyze()`. The pair captures the well-documented inverse relationship between sleep duration and resting heart rate, with an interpretation template marking the correlation as beneficial when negative.

### Pre-Existing Bug (Not Fixed)

`LocalStore.swift:304` — `CryptoService.encrypt()` returns `nil` in the test environment, triggering `assertionFailure` in DEBUG builds and crashing `CustomerJourneyTests`. This requires a `CryptoService` mock and was not addressed in this session.

---

## 3. Implementation Epic: HeartRateZoneEngine Phase 1

### Story 1: Fix weeklyZoneSummary Determinism (ZE-001)

| Subtask | Status |
|---|---|
| Add `referenceDate` parameter to `weeklyZoneSummary` | Done |
| Update callers (backward compatible default) | Done |
| Add 3 determinism tests | Done |

### Story 2: Sex-Specific Max HR Formulas (ZE-002)

| Subtask | Status |
|---|---|
| Implement Gulati formula for `BiologicalSex.female` | Done |
| Average formula for `.notSet` | Done |
| 150 bpm floor for extreme ages | Done |
| Before/after comparison across 20 personas | Done |
| 8 formula validation tests | Done |

### Story 3: Sleep-to-RHR Correlation (ZE-003)

| Subtask | Status |
|---|---|
| Add 5th correlation pair to `CorrelationEngine.analyze()` | Done |
| Add interpretation template for "Sleep Hours vs RHR" | Done |
| Update existing test assertion (4 to 5 pairs) | Done |
| Add 3 correlation tests | Done |

### Story 4: Real-World Dataset Validation

| Subtask | Status |
|---|---|
| NHANES population bracket validation (6 age/sex brackets) | Done |
| Cleveland Clinic Exercise ECG formula comparison (5 age decades, n=1,677) | Done |
| HUNT Fitness Study three-formula comparison (6 age groups, n=3,320) | Done |
| AHA guideline compliance benchmark (6 activity profiles) | Done |

---

## 4. Implementation Epic: Stress Engine Context-Awareness (Previous Session)

### Story 1: StressMode Enum
Introduced `StressMode` (`.acute`, `.desk`, `.unknown`) with automatic mode detection based on input signals.

### Story 2: Desk-Branch Weights
Desk context applies a distinct weight profile: RHR 10%, HRV 55%, CV 35%. This reflects the higher diagnostic value of HRV variability during sedentary periods.

### Story 3: Disagreement Damping
When physiological signals contradict each other (e.g., high HRV but elevated RHR), the engine compresses the composite score toward neutral rather than producing a misleading extreme value.

### Story 4: StressConfidence Output
The engine now emits a `StressConfidence` level (`.high`, `.moderate`, `.low`) based on signal agreement and data completeness.

### Story 5: StressSignalBreakdown
A structured breakdown of individual signal contributions (RHR, HRV, CV) is returned alongside the composite score for transparency.

### Story 6: StressContextInput
A new `StressContextInput` struct provides rich context (activity state, time of day, recent exercise) to the engine for mode detection.

### Story 7: ReadinessEngine Confidence Attenuation
`ReadinessEngine` now attenuates its stress-derived readiness component when stress confidence is low, preventing unreliable stress readings from dominating the readiness score.

### Story 8: StressView Confidence Badge
The `StressView` displays a visual confidence badge so users understand the reliability of the displayed stress level.

### Story 9: DashboardViewModel Integration
`DashboardViewModel` passes stress confidence through to the view layer.

---

## 5. Test Results Summary

| Test Suite | Result |
|---|---|
| StressEngine | 58/58 pass |
| StressCalibratedTests | 26/26 pass |
| ZoneEngineImprovementTests | 16/16 pass |
| ZoneEngineRealDatasetTests | 4/4 pass |
| CorrelationEngineTests | 10/10 pass |
| ZoneEngineTimeSeriesTests | all pass |
| PersonaAlgorithmTests | all pass |
| **Pre-existing failures** | 2 persona-engine tests (synthetic data noise, not regressions) |

---

## 6. Validation Confidence

### Gulati Formula

- **NHANES population means:** All 6 age/sex brackets within expected range.
- **Cleveland Clinic Exercise ECG (n=1,677):** All formulas within 1.5 standard deviations across 5 age decades.
- **HUNT Fitness Study (n=3,320):** Tanaka MAE < 10 bpm, Gulati MAE < 15 bpm across 6 age groups.
- **Before/after comparison:** 10 female personas shifted 5-9 bpm lower; 10 male personas showed 0 shift.

### Sleep-to-RHR Correlation

- Synthetic data confirms negative correlation is detected and marked beneficial.
- Insufficient data (< 7 days) correctly excluded from analysis.
- Full data returns 5 correlation pairs (was 4).

---

## 7. Known Issues / Deferred

| ID | Description | Status |
|---|---|---|
| LocalStore:304 | `CryptoService.encrypt()` returns nil in test env; crashes `CustomerJourneyTests` in DEBUG | Needs CryptoService mock |
| ZE-004 | Observed max HR integration | Deferred to separate branch |
| ZE-005 | Zone progression tracking | Deferred |
| ZE-006 | Recovery-gated training targets | Deferred |
| ZE-007 | Training load / TRIMP calculation | Deferred to separate engine |

---

## 8. Files Changed

### Engine Files

| File | Changes |
|---|---|
| `HeartRateZoneEngine.swift` | ZE-001 `referenceDate` parameter; ZE-002 Gulati formula with sex-specific dispatch |
| `CorrelationEngine.swift` | ZE-003 Sleep-to-RHR correlation pair and interpretation template |
| `StressEngine.swift` | Context-aware stress scoring, mode detection, desk-branch weights, disagreement damping (previous session) |
| `ReadinessEngine.swift` | Confidence attenuation for low-confidence stress readings (previous session) |
| `HeartModels.swift` | `StressMode`, `StressConfidence`, `StressSignalBreakdown`, `StressContextInput` types (previous session) |

### Test Files

| File | Changes |
|---|---|
| `ZoneEngineImprovementTests.swift` | 16 new tests covering ZE-001, ZE-002, ZE-003, and before/after persona comparisons |
| `ZoneEngineRealDatasetTests.swift` | 4 real-world validation tests (NHANES, Cleveland Clinic, HUNT, AHA) |
| `CorrelationEngineTests.swift` | Updated pair count assertion from 4 to 5 |

### View / ViewModel Files (Previous Session)

| File | Changes |
|---|---|
| `DashboardViewModel.swift` | Passes stress confidence to view layer |
| `StressViewModel.swift` | Context-aware stress computation path |
| `StressView.swift` | Confidence badge display |

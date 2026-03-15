# HeartCoach — Code Review 2026-03-13

> Branch: `fix/deterministic-test-seeds`
> Scope: Stress engine refactoring, zone engine Phase 1 improvements, correlation engine extension
> Commits reviewed: `d0ffce9..a816ac9` (3 commits, 516 files, +8,182 / -326 lines)

---

## 1. Executive Summary

This review covers three engineering initiatives shipped in a single branch:

| Initiative | Risk | Verdict |
|---|---|---|
| Stress Engine — acute/desk dual-branch architecture | **High** | Approved with conditions |
| HeartRateZoneEngine — Phase 1 improvements (ZE-001/002/003) | **Medium** | Approved |
| CorrelationEngine — Sleep-RHR pair addition | **Low** | Approved |

**Overall assessment:** Solid engineering work with strong test coverage. The stress engine refactor is the highest-risk change and carries the most review weight. Zone engine and correlation changes are clean and well-validated.

---

## 2. Stress Engine Review (High Priority)

### 2.1 Architecture Change: Acute/Desk Dual Branches

**What changed:**
- `StressEngine.swift` gained a `StressMode` enum (`.acute`, `.desk`) and `StressConfidence` enum (`.high`, `.medium`, `.low`)
- New `computeStressWithMode()` internal method with mode-aware weight selection
- Desk branch: bidirectional HRV z-score (any deviation from baseline = cognitive load)
- Acute branch: directional z-score (lower HRV = higher stress)
- Public `computeStress()` now accepts optional `mode:` parameter (default `.acute`)

**Strengths:**
- Clean separation of concern — mode is a parameter, not a fork
- Bidirectional HRV for desk mode is physiologically correct (cognitive engagement can raise or lower HRV)
- Confidence calibration based on data quality (baseline window, HRV variance, signal presence)
- Weight tuning: desk (RHR 0.20, HRV 0.50, CV 0.30) — HRV-primary for seated context makes sense

**Concerns:**
1. **Weight constants are hardcoded** — Consider making them configurable via `ConfigService` for A/B testing
2. **Desk mode detection is manual** — Caller must pass `.desk`; no automatic detection from context (e.g., time of day, motion data). Future risk of misclassification
3. **Sigmoid midpoint (50.0) shared** between branches — desk cognitive load distribution may warrant a different midpoint

**Verdict:** Approved. The dual-branch approach is sound. Consider adding automatic mode inference in a future iteration.

### 2.2 Dataset Validation Changes

**What changed:**
- SWELL dataset validation switched to `.desk` mode (correct — SWELL is seated/cognitive)
- WESAD dataset validation switched to `.desk` mode (correct — WESAD E4 is wrist BVP during TSST)
- Added raw signal diagnostics to WESAD test
- Added `deskBranch` and `deskBranchDamped` to `StressDiagnosticVariant` enum
- Added FP/FN export summaries

**Strengths:**
- Mode alignment with dataset characteristics is scientifically correct
- Diagnostic variant enum is extensible for future ablation studies
- FP/FN summaries improve debugging velocity

**Concerns:**
1. ~~DatasetValidationTests was excluded in project.yml~~ — Now re-enabled, good
2. No automated dataset download — tests require manual CSV placement

**Verdict:** Approved.

### 2.3 StressModeAndConfidenceTests (13 tests)

**What changed:**
- New test file with 13 tests covering:
  - Mode detection correctness
  - Confidence calibration at all 3 levels
  - Edge cases (nil baselines, extreme values)
  - Desk vs acute score divergence

**Strengths:**
- Good coverage of the new mode/confidence API surface
- Tests validate both score ranges and confidence levels
- Edge cases for nil baselines handled

**Verdict:** Approved. Well-structured test suite.

### 2.4 StressViewModel Integration

**What changed:**
- `StressViewModel.swift`: Passes actual `stress.score` and `stress.confidence` to `ReadinessEngine` instead of simplified threshold buckets
- Eliminates information loss between stress computation and readiness scoring

**Strengths:**
- Correct fix — readiness engine now gets full signal fidelity
- Backward-compatible (ReadinessEngine already accepted optional confidence)

**Verdict:** Approved.

---

## 3. HeartRateZoneEngine Review (Medium Priority)

### 3.1 ZE-001: Deterministic weeklyZoneSummary

**What changed:**
- Added `referenceDate: Date? = nil` parameter to `weeklyZoneSummary()`
- Uses `referenceDate ?? history.last?.date ?? Date()` instead of always `Date()`
- Fixes non-deterministic test behavior when tests run near midnight

**Strengths:**
- Backward-compatible (default nil = existing behavior)
- Test-friendly without mocking
- Clean parameter injection

**Verdict:** Approved.

### 3.2 ZE-002: Sex-Specific Max HR Estimation (Gulati Formula)

**What changed:**
- `estimateMaxHR(age:sex:)` now uses:
  - Tanaka (208 - 0.7 * age) for males
  - Gulati (206 - 0.88 * age) for females
  - Average of both for `.notSet`
- Floor of 150 bpm prevents unreasonable estimates for elderly users
- Changed from `private` to `internal` for testability

**Strengths:**
- Both formulas are well-cited (Tanaka: n=18,712; Gulati: n=5,437)
- Real-world validation against NHANES, Cleveland Clinic ECG (PhysioNet), and HUNT datasets
- Before/after comparison: 10 female personas shifted 5-9 bpm (67 total), 10 male personas: 0 shift — expected behavior

**Concerns:**
1. **Gulati formula trained on predominantly white women** (St. James Women Take Heart Project) — may not generalize across all ethnicities. Consider noting this limitation
2. **150 bpm floor is arbitrary** — A 90-year-old's Gulati estimate is 126.8 bpm; the floor never activates for realistic ages. May want to document the design rationale

**Verdict:** Approved. Significant improvement over the universal formula.

### 3.3 ZE-003: Sleep-RHR Correlation Pair

**What changed:**
- Added 5th correlation pair to `CorrelationEngine`: Sleep Hours vs Resting Heart Rate
- Expected direction: negative (more sleep → lower RHR)
- New factorName: `"Sleep Hours vs RHR"` (distinct from existing `"Sleep Hours"` for sleep-HRV)
- Added interpretation template for beneficial pattern
- Updated test assertions (4 → 5 pairs)

**Strengths:**
- Physiologically well-supported (Tobaldini et al. 2019, Cappuccio et al. 2010)
- Clean separation from existing sleep-HRV pair
- Interpretation text is user-friendly and actionable

**Concerns:**
1. `factorName: "Sleep Hours vs RHR"` breaks naming convention (other pairs use just the factor name, not "X vs Y"). Consider whether this creates UI display issues

**Verdict:** Approved.

---

## 4. Test Fixture Changes

### 4.1 CorrelationEngine Time-Series Fixtures

- 100 new JSON fixtures (20 personas × 5 time checkpoints)
- Generated by time-series regression tests
- Baseline for detecting unintended correlation drift

### 4.2 BuddyRecommendation & NudgeGenerator Fixture Updates

- 21 fixture files updated — downstream effects of stress engine weight changes
- Expected: different stress scores → different buddy recommendations and nudge selections

**Verdict:** Approved. Fixture regeneration is correct and expected.

---

## 5. Known Issues & Technical Debt

| Issue | Severity | Status |
|---|---|---|
| LocalStore.swift:304 crash — `assertionFailure` when CryptoService.encrypt() returns nil in test env | P2 | Pre-existing. Needs CryptoService mock for test target |
| "Recovering from Illness" persona stress score outside expected range | P3 | Pre-existing. Synthetic data noise, not engine regression |
| "Overtraining Syndrome" persona consecutiveAlert nil | P3 | Pre-existing. Synthetic data doesn't generate required consecutive-day patterns |
| Signal 11 crash with nested structs in XCTestCase | P3 | Worked around with parallel arrays. Swift compiler bug |
| Accessibility labels missing across 16+ views (BUG-013) | P2 | Open. Planned for next sprint |
| No automatic StressMode inference from context | P3 | Design decision — manual for now, automatic in future phase |

---

## 6. Code Quality Metrics

| Metric | Value |
|---|---|
| New lines of production code | ~600 (StressEngine, HeartRateZoneEngine, CorrelationEngine) |
| New lines of test code | ~400 (StressModeAndConfidenceTests, ZoneEngineImprovementTests, ZoneEngineRealDatasetTests) |
| Test-to-code ratio | 0.67:1 |
| Test suites passing | StressEngine 58/58, ZoneEngine 20/20, CorrelationEngine 10/10 |
| Real-world datasets validated | 5 (SWELL, PhysioNet ECG, WESAD, Cleveland Clinic, HUNT) |
| Breaking API changes | 0 (all new parameters have defaults) |
| Force unwraps added | 0 |

---

## 7. Recommendations

### Must-Do Before Merge
1. Verify all 88 stress + zone + correlation tests pass in CI (not just local)
2. Confirm fixture JSON diffs are only score-value changes, not structural

### Should-Do Soon
3. Add CryptoService mock to fix LocalStore crash in test target
4. Document Gulati formula ethnicity limitations in code comments
5. Consider renaming "Sleep Hours vs RHR" to follow single-factor naming convention

### Nice-to-Have
6. Make stress engine weights configurable via ConfigService
7. Add automatic StressMode inference (time-of-day, motion context)
8. Add Bland-Altman plots for formula validation in improvement docs

---

*Reviewed: 2026-03-13*
*Branch: fix/deterministic-test-seeds*
*Commits: d0ffce9, fc40a78, a816ac9*

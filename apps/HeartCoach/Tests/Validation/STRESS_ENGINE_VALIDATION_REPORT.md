# StressEngine Validation Report

Date: 2026-03-13
Engine: `StressEngine`
Strategy: Hybrid validation

## Commands Run

```bash
cd apps/HeartCoach
swift test --filter StressEngineTests
swift test --filter StressCalibratedTests
```

```bash
THUMP_RESULTS_DIR=/tmp/thump-stress-results.Jw3V9w \
xcodebuild test \
  -project apps/HeartCoach/Thump.xcodeproj \
  -scheme Thump \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY='' \
  -only-testing:ThumpCoreTests/StressEngineTimeSeriesTests \
  -only-testing:ThumpCoreTests/DatasetValidationTests
```

## Dataset Presence

- `Tests/Validation/Data/swell_hrv.csv`: present locally
- Local dataset details:
  - size: 477,339,620 bytes
  - rows: 391,639 including header
  - source format: raw SWELL combined dataset with `condition`, `subject_id`, `HR`, and `SDRR` columns

## Results

### SwiftPM Regression Layer

- `StressEngineTests`: 26/26 passed
- `StressCalibratedTests`: 26/26 passed

Interpretation:
- The existing repo-local stress unit and calibration suites remain green after the validation harness changes.
- No product-side `StressEngine` scoring changes were made in this implementation pass.

### Extended Validation Layer

Status: blocked before test execution

Observed blockers:
1. `xcodebuild test` initially failed on signing requirements.
2. Retrying with `CODE_SIGNING_ALLOWED=NO` progressed further, but the Xcode project then failed to build because it still references missing files:
   - `apps/HeartCoach/iOS/Services/AlertMetricsService.swift`
   - `apps/HeartCoach/iOS/Services/ConfigLoader.swift`

Impact:
- `StressEngineTimeSeriesTests` did not run through Xcode in this environment.
- `DatasetValidationTests` did not run through Xcode in this environment.
- The temporary results directory remained empty.

### Fixture Safety

- No tracked files under `Tests/EngineTimeSeries/Results` were modified during this run.
- `THUMP_RESULTS_DIR` override is now implemented in `TimeSeriesTestInfra.swift` to support safe exploratory runs.

## What Changed

### Implemented

- `Tests/EngineTimeSeries/TimeSeriesTestInfra.swift`
  - Added `THUMP_RESULTS_DIR` env-var override for result output.
- `Tests/Validation/DatasetValidationTests.swift`
  - Replaced placeholder SWELL baseline logic (`baselineHRV = sdnn * 1.1`) with per-subject baseline derivation from no-stress rows.
  - Added binary label normalization for baseline vs stressed rows.
  - Added AUC-ROC computation.
  - Added confusion-matrix summary at threshold `score >= 50`.
  - Added stricter validation assertions:
    - stressed mean > baseline mean
    - Cohen's d > 0.5
    - AUC-ROC > 0.70
- `Tests/Validation/Data/README.md`
  - Added the Xcode-based extended validation command.
- `apps/HeartCoach/.gitignore`
  - Added ignore rules for local third-party validation CSVs under `Tests/Validation/Data`, while preserving `.gitkeep` and `README.md`.
- `Package.swift`
  - Excluded `Validation/STRESS_ENGINE_VALIDATION_REPORT.md` from the default SwiftPM test target so repo-local test runs stay warning-free.

## Analysis

### Current confidence

- Confidence in the synthetic regression layer is good.
- Confidence in real-world calibration is still unresolved because the SWELL dataset is now present locally, but the Xcode validation path is still blocked by unrelated project state.

### Likely improvement opportunities once the real dataset runs

1. Review the RHR component sensitivity
- The current rule `40 + deviation * 4` may still over-penalize moderate HR increases on heterogeneous real-world subjects.
- Real dataset false positives will tell us whether this slope should be reduced or capped earlier.

2. Review sigmoid calibration
- Current midpoint and steepness may compress too many healthy rows into the same middle band.
- Real AUC/effect-size output should guide whether `sigmoidMid` or `sigmoidK` should move.

3. Review CV contribution
- CV can add noise when a subject has a small or behaviorally mixed baseline window.
- Subject-level false positives on baseline rows will show whether the CV term should be down-weighted or gated behind stronger sample requirements.

4. Consider subject normalization depth
- If SWELL results vary a lot by subject, the next step should be better subject-specific normalization before changing the top-level scoring formula.

## Next Steps

1. Unblock Xcode validation by resolving the stale project references to `AlertMetricsService.swift` and `ConfigLoader.swift`, or by restoring those files if they were intentionally removed from the worktree.
2. Re-run the Xcode validation command with `THUMP_RESULTS_DIR` pointed at a temp directory and an iOS Simulator destination.
4. Capture the real SWELL metrics and update this report with:
   - row counts by label
   - stressed vs baseline mean score
   - Cohen's d
   - AUC-ROC
   - confusion summary
   - top false-positive and false-negative patterns

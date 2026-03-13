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
THUMP_RESULTS_DIR=/tmp/thump-stress-results.XXXXXX \
xcodebuild test \
  -project Thump.xcodeproj \
  -scheme Thump \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY='' \
  -only-testing:ThumpCoreTests/DatasetValidationTests/testStressEngine_SWELL_HRV
```

```bash
THUMP_RESULTS_DIR=/tmp/thump-stress-results.XXXXXX \
xcodebuild test \
  -project Thump.xcodeproj \
  -scheme Thump \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY='' \
  -only-testing:ThumpCoreTests/DatasetValidationTests/testStressEngine_PhysioNetExamStress
```

```bash
THUMP_RESULTS_DIR=/tmp/thump-stress-results.XXXXXX \
xcodebuild test \
  -project Thump.xcodeproj \
  -scheme Thump \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY='' \
  -only-testing:ThumpCoreTests/DatasetValidationTests/testStressEngine_WESAD
```

```bash
THUMP_RESULTS_DIR=/tmp/thump-stress-results.XXXXXX \
xcodebuild test \
  -project Thump.xcodeproj \
  -scheme Thump \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY='' \
  -only-testing:ThumpCoreTests/StressEngineTimeSeriesTests
```

## Agent Handoff

### Can a fresh agent execute from this report alone?

Mostly yes, but only if it also treats the validation data docs as required companions.

Source-of-truth files for execution:
- this report:
  - [/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/STRESS_ENGINE_VALIDATION_REPORT.md](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/STRESS_ENGINE_VALIDATION_REPORT.md)
- dataset location and expected filenames:
  - [/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/Data/README.md](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/Data/README.md)
- broader dataset reference notes:
  - [/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/FREE_DATASETS.md](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/FREE_DATASETS.md)

If an agent reads only this report and ignores those two companion files, it may still understand the strategy but miss some download and mirror details.

### Exact datasets the next agent must use

These three dataset families are the current required gate for StressEngine work:

1. SWELL
- local required file:
  - `apps/HeartCoach/Tests/Validation/Data/swell_hrv.csv`
- use for:
  - office / desk cognitive-stress challenge evaluation
- label mapping in the harness:
  - baseline: `no stress`
  - stressed: `time pressure`, `interruption`

2. PhysioNet Wearable Exam Stress
- local required directory:
  - `apps/HeartCoach/Tests/Validation/Data/physionet_exam_stress/`
- expected mirrored files:
  - `S1...S10/<session>/HR.csv`
  - `S1...S10/<session>/IBI.csv`
  - `S1...S10/<session>/info.txt`
- use for:
  - acute exam-style stress anchor dataset

3. WESAD
- local required archive:
  - `apps/HeartCoach/Tests/Validation/Data/WESAD.zip`
- local required derived mirror:
  - `apps/HeartCoach/Tests/Validation/Data/wesad_e4_mirror/`
- expected mirrored files:
  - `S2...S17/HR.csv`
  - `S2...S17/IBI.csv`
  - `S2...S17/info.txt`
  - `S2...S17/quest.csv`
- use for:
  - labeled wrist-stress challenge evaluation

### Where to download or source them

The next agent should not guess this.
It should use the sources already documented in:
- [/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/Data/README.md](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/Data/README.md)
- [/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/FREE_DATASETS.md](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/FREE_DATASETS.md)

Current documented source mapping:
- `swell_hrv.csv`
  - source family: SWELL-HRV
  - documented in `Data/README.md`
- `physionet_exam_stress/`
  - source family: PhysioNet Wearable Exam Stress
  - documented in `Data/README.md`
- `WESAD.zip`
  - source family: official WESAD archive
  - documented in `Data/README.md`

Strict rule:
- if the local filename or folder shape does not match the expected names above, the harness should be fixed only if the new shape is documented in both this report and `Data/README.md`

### What the next agent must run

Minimum required commands:

```bash
cd /Users/t/workspace/Apple-watch/apps/HeartCoach
swift test --filter StressEngineTests
swift test --filter StressCalibratedTests
```

```bash
THUMP_RESULTS_DIR=$(mktemp -d /tmp/thump-stress-results.XXXXXX) \
xcodebuild test \
  -project /Users/t/workspace/Apple-watch/apps/HeartCoach/Thump.xcodeproj \
  -scheme Thump \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY='' \
  -only-testing:ThumpCoreTests/DatasetValidationTests/testStressEngine_SWELL_HRV \
  -only-testing:ThumpCoreTests/DatasetValidationTests/testStressEngine_PhysioNetExamStress \
  -only-testing:ThumpCoreTests/DatasetValidationTests/testStressEngine_WESAD \
  -only-testing:ThumpCoreTests/StressEngineTimeSeriesTests
```

### What raised the bar

The bar is no longer "synthetic tests pass."

The bar was raised by this evidence combination:
- one acute-supporting real dataset:
  - PhysioNet
- two challenging real datasets that expose generalization gaps:
  - SWELL
  - WESAD
- the requirement that synthetic stability and real-world generalization both matter
- the requirement that future product changes must survive replay, confidence, and UI-safety gates

In practice, the raised bar now means:
- no more product changes justified by synthetic tests alone
- no more claiming broad stress accuracy from one dataset family
- no more global retune without branch separation

### Pass / fail standard for any future agent

A future agent should treat these as hard rules:

1. Do not change production stress scoring unless the candidate improves challenge datasets without breaking the acute anchor.
2. Do not use only one real dataset to justify a retune.
3. Do not claim success unless all required gates are run.
4. Do not skip documenting:
  - exact dataset used
  - exact local file path
  - exact command run
  - exact metrics observed
5. Do not leave the report stale after changing the harness, inputs, or conclusions.

## Dataset Presence

- `Tests/Validation/Data/swell_hrv.csv`: present locally
- Source: public Git LFS mirror of the SWELL combined dataset
- Size: 477,339,620 bytes
- Rows: 391,639 including header
- Unique subjects observed: 22
- Raw labels:
  - `no stress`: 212,400 rows
  - `interruption`: 110,943 rows
  - `time pressure`: 68,295 rows
- `Tests/Validation/Data/physionet_exam_stress/`: present locally
- Source: PhysioNet Wearable Exam Stress direct mirror
- Scope mirrored locally:
  - 10 subjects (`S1`...`S10`)
  - 3 sessions each (`Final`, `midterm_1`, `midterm_2`)
  - `HR.csv`, `IBI.csv`, and `info.txt` only
- `Tests/Validation/Data/WESAD.zip`: present locally
- Source: official WESAD archive from the dataset authors
- Size: 2,249,444,501 bytes
- `Tests/Validation/Data/wesad_e4_mirror/`: present locally
- Scope mirrored locally:
  - 15 subjects (`S2`...`S17`, excluding `S12`)
  - `HR.csv`, `IBI.csv`, `info.txt`, and `quest.csv` only
  - generated locally from the official `WESAD.zip` archive

## Results

### SwiftPM Regression Layer

- `StressEngineTests`: 26/26 passed
- `StressCalibratedTests`: 26/26 passed

Interpretation:
- The existing fast synthetic regression layer remains green.
- No product-side `StressEngine` scoring change was made during this validation pass.

### Xcode Time-Series Layer

- `StressEngineTimeSeriesTests`: 14/14 passed
- KPI summary: 140/140 checkpoint tests passed
- `THUMP_RESULTS_DIR` temp redirection worked
- No tracked files under `Tests/EngineTimeSeries/Results` were modified

Interpretation:
- Synthetic persona and checkpoint stability remains strong after the validation harness changes.

## Pre-Expansion Assessment

### What existed before this validation expansion

Before the work in this report, the project already had a meaningful stress-test foundation, but it was uneven.

The pre-existing stress-related coverage was:
- `StressEngineTests`
  - 26 fast synthetic unit tests
  - core score behavior, clamping, trend direction, daily score behavior, and scenario checks
- `StressCalibratedTests`
  - 26 synthetic or semi-synthetic calibration tests
  - heavily based on the intended PhysioNet-derived HR-primary weighting assumptions
- `StressEngineTimeSeriesTests`
  - 14 synthetic persona time-series tests
  - 140 checkpoint validations across personas
- `DatasetValidationTests.testStressEngine_SWELL_HRV()`
  - one real-dataset stress validation entrypoint
  - but only for SWELL

### What was strong

1. The project already had good synthetic regression intent.
- The core `StressEngine` behavior was not untested.
- There were enough fast unit tests to catch obvious scoring regressions.
- The persona time-series suite showed that the team was thinking about longitudinal behavior, not just single-point scores.

2. The project already had calibration intent.
- The code and tests clearly documented an HR-primary design based on PhysioNet reasoning.
- That was better than a purely intuition-driven heuristic engine.

3. The project already had an external dataset harness concept.
- `DatasetValidationTests.swift` existed.
- The project already had a place for external data under `Tests/Validation/Data`.
- The repo already had `FREE_DATASETS.md`, which showed the right direction.

### What was weak

1. Real-world validation was too thin.
- For stress specifically, there was only one real external harness path in practice: SWELL.
- There was no second or third dataset to test whether the same formula generalized.
- That meant the engine could appear calibrated while still being context-fragile.

2. The SWELL stress validation was not strong enough.
- The original `testStressEngine_SWELL_HRV()` used a placeholder assumption:
  - `baselineHRV = sdnn * 1.1`
- That is not a real personal baseline.
- It did not build per-subject baselines from actual baseline windows.
- It did not compute AUC-ROC.
- It did not compute per-subject error slices.
- It did not separate challenge conditions beyond a broad stress/non-stress split.

3. The strongest "PhysioNet support" was indirect, not end-to-end.
- Before this work, PhysioNet mostly existed as:
  - code comments
  - documentation claims
  - synthetic calibration assumptions in `StressCalibratedTests`
- There was not yet a raw-dataset validation path proving the current engine against a local PhysioNet mirror in the same way we now do.

4. Important validation was not part of the everyday default test path.
- `Package.swift` excluded `Validation/DatasetValidationTests.swift`.
- `Package.swift` also excluded the `EngineTimeSeries` directory from the main test target.
- That made sense for speed, but it meant the strongest validation layers were easier to miss during normal development.

5. External datasets were optional and easy to skip.
- The harness skipped gracefully when files were absent.
- That is developer-friendly, but it also means the project could look green without actually exercising real-dataset validation.

### How I would rate the pre-existing dataset and test story

For the stress engine specifically:

- Synthetic regression strength: `7/10`
- Longitudinal synthetic coverage: `7/10`
- Real-world dataset strength: `3/10`
- Operational enforcement of real validation: `3/10`
- Overall pre-expansion confidence for product accuracy: `4/10`

Equivalent plain-English rating:
- synthetic test story: `good`
- real-world validation story: `weak`
- product-readiness confidence for a user-facing stress score: `below acceptable`

### Was it strong enough before this work?

Short answer: no, not for a user-facing stress feature that claims to work broadly.

More exact answer:
- it was strong enough to support ongoing engine development
- it was not strong enough to justify high confidence in the displayed stress score across contexts

The core reason is simple:
- before this work, the project had a decent synthetic safety net
- but it did not yet have a sufficiently strong real-world generalization gate

### What this means in hindsight

The original setup was a solid engineering starting point.
It was not junk.
But it was still an early-stage validation story, not a strong product-evidence story.

That is why the later findings matter so much:
- once we added real PhysioNet, SWELL, and WESAD evaluation side by side
- the single-formula assumption stopped looking safe enough for a broad in-app stress monitor

### Real SWELL Validation Layer

Run status: completed

Note:
- The latest focused rerun on the current harness still failed its assertions.
- The detailed metrics below remain the most recent completed SWELL diagnostic capture from this validation pass.

Observed metrics:
- Subjects scored: 22
- Skipped subjects without baseline: 0
- Baseline rows: 212,400
- Stressed rows: 179,238
- Baseline mean score: 37.7
- Stressed mean score: 17.6
- Cohen's d: -0.93
- AUC-ROC: 0.203
- Confusion at `score >= 50`: TP=14,893 FP=58,611 TN=153,789 FN=164,345

Assertion result:
- `stressed mean > baseline mean`: failed
- `Cohen's d > 0.5`: failed
- `AUC-ROC > 0.70`: failed

Interpretation:
- The current `StressEngine` does not generalize to this SWELL mapping.
- The failure is not marginal. The direction is inverted: SWELL stressed rows score substantially lower than SWELL baseline rows.

Condition breakdown:
- `time pressure`: mean score 20.0, Cohen's d -0.77, AUC 0.232
- `interruption`: mean score 16.1, Cohen's d -1.05, AUC 0.186

Interpretation:
- Both stressed conditions fail, but `interruption` is even more misaligned than `time pressure`.

Variant ablation:
- `full engine`: baseline 37.7, stressed 17.6, d -0.93, AUC 0.203
- `rhr-only`: baseline 36.5, stressed 12.5, d -1.04, AUC 0.167
- `low-rhr`: baseline 39.6, stressed 27.7, d -0.45, AUC 0.349
- `gated-rhr`: baseline 38.6, stressed 20.2, d -0.84, AUC 0.241
- `no-rhr`: baseline 39.3, stressed 31.4, d -0.28, AUC 0.394
- `subject-norm-no-rhr`: baseline 50.9, stressed 38.6, d -0.37, AUC 0.382
- `hrv-only`: baseline 34.8, stressed 27.1, d -0.27, AUC 0.376

Interpretation:
- The RHR path is the most directionally wrong signal on SWELL.
- A simple gate helps a little, but not enough:
  - full engine AUC 0.203
  - gated-rhr AUC 0.241
- Reducing RHR helps, but removing RHR helps more:
  - full engine AUC 0.203
  - low-rhr AUC 0.349
  - no-rhr AUC 0.394
- `gated-rhr` preserved the wrong-way direction, so a lightweight gate is not enough to solve the SWELL mismatch.
- The subject-normalized percentile variant did not beat plain `no-rhr`, so stronger within-subject normalization is not yet the leading direction on this dataset.
- If we test product-side experiments later, the next serious candidate should be a true desk-mode branch with materially different scoring logic, not just a mild gate or mild rebalance.

Worst subjects:
- Subject 10: delta -31.6, AUC 0.004
- Subject 5: delta -16.4, AUC 0.011
- Subject 16: delta -15.3, AUC 0.020
- Subject 24: delta -41.7, AUC 0.025
- Subject 6: delta -21.1, AUC 0.027
- Mean subject AUC: 0.169
- Mean subject stressed-baseline delta: -17.3

Interpretation:
- This is not just a population-average issue. The directional mismatch is repeated across many individual subjects.

### Real PhysioNet Validation Layer

Run status: completed

Validation protocol:
- Local mirrored files: `HR.csv` and `IBI.csv` for 10 subjects × 3 exam sessions
- Stress window: first 30 minutes of each session
- Recovery baseline window: last 45 minutes of each session
- Scoring granularity: non-overlapping 5-minute windows
- Subject baseline: aggregate of that subject’s recovery windows across all sessions

Observed metrics:
- Sessions parsed: 30
- Subjects scored: 10
- Stress windows: 115
- Recovery windows: 169
- Stress mean score: 73.2
- Recovery mean score: 47.1
- Cohen's d: 0.87
- AUC-ROC: 0.729
- Confusion at `score >= 50`: TP=89 FP=69 TN=100 FN=26

Assertion result:
- `stressed mean > baseline mean`: passed
- `Cohen's d > 0.5`: passed
- `AUC-ROC > 0.70`: passed

Interpretation:
- The current `StressEngine` does transfer to this PhysioNet mapping.
- This is not a trivial pass: the effect size is medium-to-large and the AUC is comfortably above the validation threshold.
- The result supports the repo’s existing HR-primary calibration story for acute exam-style stress and recovery windows.

Variant ablation:
- `full engine`: baseline 47.1, stressed 73.2, d 0.87, AUC 0.729
- `rhr-only`: baseline 38.8, stressed 69.4, d 0.77, AUC 0.715
- `low-rhr`: baseline 57.2, stressed 72.6, d 0.72, AUC 0.719
- `gated-rhr`: baseline 50.2, stressed 73.7, d 0.83, AUC 0.721
- `no-rhr`: baseline 57.4, stressed 67.6, d 0.46, AUC 0.640
- `subject-norm-no-rhr`: baseline 62.1, stressed 75.5, d 0.48, AUC 0.650
- `hrv-only`: baseline 35.4, stressed 47.2, d 0.49, AUC 0.638

Interpretation:
- PhysioNet favors the current full HR-primary engine over the no-RHR family.
- `rhr-only` is almost as good as the full engine, which reinforces that RHR is the dominant signal in this dataset.
- `gated-rhr` is reasonably safe here, but it still does not beat the full engine.
- Removing RHR clearly hurts performance here, which is the opposite of what SWELL showed.

Worst subjects:
- `S5`: delta 0.1, AUC 0.475
- `S2`: delta 24.0, AUC 0.696
- `S9`: delta 26.8, AUC 0.697
- `S1`: delta 19.6, AUC 0.698
- `S8`: delta 13.1, AUC 0.727
- Mean subject AUC: 0.726
- Mean subject stressed-baseline delta: 25.0

Interpretation:
- Most subjects still separate in the correct direction.
- The weakest case is `S5`, which is a useful reminder that even the better-aligned dataset is not universally clean.

### Real WESAD Validation Layer

Run status: completed

Validation protocol:
- Local source archive: `WESAD.zip`
- Local test mirror: `wesad_e4_mirror/`
- Physiology source: Empatica E4 wrist `HR.csv` and `IBI.csv`
- Labels source: `quest.csv`
- Baseline window: `Base`
- Stress window: `TSST`
- Scoring granularity: non-overlapping 2-minute windows
- Subject baseline: aggregate of that subject’s `Base` windows

Observed metrics:
- Subjects parsed: 15
- Subjects scored: 15
- Stress windows: 76
- Baseline windows: 139
- Stress mean score: 16.3
- Baseline mean score: 40.6
- Cohen's d: -1.18
- AUC-ROC: 0.178
- Confusion at `score >= 50`: TP=4 FP=45 TN=94 FN=72

Assertion result:
- `stressed mean > baseline mean`: failed
- `Cohen's d > 0.5`: failed
- `AUC-ROC > 0.70`: failed

Interpretation:
- The current `StressEngine` also fails on WESAD wrist data.
- This is not a mild miss. The direction is strongly inverted, similar to SWELL.
- That means the current HR-primary engine is not just mismatched to one office dataset. It now misses on two separate non-PhysioNet real-world datasets.

Sanity check:
- Raw WESAD wrist HR also trends opposite the engine assumption on this mirror:
  - baseline mean HR: 79.7
  - TSST mean HR: 70.9
- That makes a simple parser or window-index bug less likely.

Variant ablation:
- `full engine`: baseline 40.6, stressed 16.3, d -1.18, AUC 0.178
- `rhr-only`: baseline 37.0, stressed 7.3, d -1.25, AUC 0.126
- `low-rhr`: baseline 44.2, stressed 30.9, d -0.55, AUC 0.339
- `gated-rhr`: baseline 42.2, stressed 22.5, d -0.95, AUC 0.251
- `no-rhr`: baseline 44.0, stressed 35.7, d -0.32, AUC 0.404
- `subject-norm-no-rhr`: baseline 50.9, stressed 44.0, d -0.22, AUC 0.432
- `hrv-only`: baseline 33.1, stressed 24.1, d -0.34, AUC 0.356

Interpretation:
- WESAD behaves more like SWELL than PhysioNet.
- The RHR path is again the strongest wrong-way signal.
- Reducing or removing RHR helps, but no tested variant is close to acceptable yet.
- `subject-norm-no-rhr` is the best WESAD variant we tested so far, but it still remains far below the threshold for a trustworthy product retune.

Worst subjects:
- `S10`: delta -42.8, AUC 0.000
- `S14`: delta -19.8, AUC 0.020
- `S17`: delta -37.9, AUC 0.048
- `S8`: delta -33.5, AUC 0.050
- `S7`: delta -31.1, AUC 0.075
- Mean subject AUC: 0.176
- Mean subject stressed-baseline delta: -24.3

Interpretation:
- The inversion is repeated across individual subjects, not just hidden inside the population average.

## What Changed To Enable The Run

- Regenerated `Thump.xcodeproj` from `project.yml` with `xcodegen generate` to remove stale references to deleted files.
- Added the real `swell_hrv.csv` under `Tests/Validation/Data/`.
- Added a lightweight local PhysioNet mirror under `Tests/Validation/Data/physionet_exam_stress/`.
- Added the official `WESAD.zip` under `Tests/Validation/Data/`.
- Added a lightweight local WESAD wrist mirror under `Tests/Validation/Data/wesad_e4_mirror/`.
- Updated `DatasetValidationTests.swift` to accept raw SWELL columns (`subject_id`, `SDRR`).
- Added `testStressEngine_PhysioNetExamStress()` with explicit session-window assumptions for acute stress vs recovery.
- Added `testStressEngine_WESAD()` using `Base` vs `TSST` windows from `quest.csv` plus wrist `HR.csv` and `IBI.csv`.
- Replaced the quadratic AUC implementation with a rank-based `O(n log n)` version.
- Refactored SWELL loading to a streaming two-pass path instead of loading the full CSV into memory.
- Limited per-subject `recentHRVs` passed into `StressEngine` to a recent 7-value baseline window.
- Added an XCTest host guard in `ThumpiOSApp.swift` so app startup side effects do not crash hosted tests.
- Added multi-view diagnostics:
  - per-condition metrics
  - per-subject summaries
  - signal ablation outputs
- Regenerated `Thump.xcodeproj` again after stale test file paths resurfaced with incorrect locations.

## Analysis

### Current confidence

- Confidence in the synthetic regression layer is good.
- Confidence in the current `StressEngine` for acute exam-style stress is now moderate.
- Confidence in the current `StressEngine` for generalized wrist-based stress detection remains low.

### Cross-dataset interpretation

- The real-world picture is now clearer than before:
  - SWELL strongly challenges the current HR-primary design.
  - WESAD wrist `Base` vs `TSST` also strongly challenges the current HR-primary design.
  - PhysioNet supports the current HR-primary design.
- The same change will not help both dataset families:
  - removing RHR helps SWELL and WESAD
  - removing RHR hurts PhysioNet
- A lightweight gate is not the answer either:
  - `gated-rhr` improves SWELL and WESAD only slightly
  - `gated-rhr` still trails the full engine on PhysioNet
- That means the current problem is not random noise or one bad dataset.
- The stronger conclusion now is that the current engine is probably valid only for a narrow acute-stress mode and is over-applied to other wrist / cognitive contexts.

### Why SWELL and WESAD disagree with the engine

The engine is HR-primary and assumes stress tends to look like:
- higher resting HR
- lower SDNN

The SWELL dataset, as mapped here, trends the other way in aggregate:
- `no stress` mean HR: 77.3
- stressed mean HR: 71.4
- `no stress` mean SDRR: 105.6
- stressed mean SDRR: 113.2

Per-label view:
- `time pressure`: mean HR 69.4, mean SDRR 122.4
- `interruption`: mean HR 72.6, mean SDRR 107.5

WESAD wrist data, as mirrored here, also trends the other way:
- baseline mean HR: 79.7
- TSST mean HR: 70.9

That means the current engine is not just weak on one challenge set; it is directionally mismatched to two real wrist / cognitive-stress datasets.

### Most likely reasons

1. Label-to-physiology mismatch
- SWELL labels cognitive work conditions, not guaranteed wearable-style autonomic “stress episodes” in the same direction as the PhysioNet calibration set.
- WESAD gives a labeled stress task, but the wrist-E4 mirror still does not behave like the PhysioNet acute exam mapping.

2. Feature mismatch
- This dataset provides precomputed HRV windows and average HR, not watch-native resting physiology with activity control.
- WESAD wrist `HR.csv` and `IBI.csv` are closer to the product than SWELL, but they are still not identical to Apple Watch resting physiology.

3. Context mismatch
- Office-task conditions can be confounded by sitting still, time of day, and protocol structure, which may invert simple HR or HRV expectations.
- Even a labeled stress protocol can still produce wrist physiology that does not reward a simple HR-primary rule.

4. Calibration mismatch
- The current engine is tuned around the PhysioNet-derived HR-primary assumption. SWELL and WESAD both suggest that assumption does not transfer cleanly outside that acute mode.

5. Signal-priority mismatch
- The ablation runs show the RHR term is the strongest contributor to the wrong direction on both SWELL and WESAD.
- `low-rhr` improves meaningfully over the full engine, but `no-rhr` or `subject-norm-no-rhr` still perform best of the tested variants on the challenge sets.
- The first `gated-rhr` experiment did not close the gap, which suggests the problem is larger than a simple one-rule gate.

6. Subject-normalization alone is not enough
- A percentile-style subject-normalized no-RHR branch did not outperform plain `no-rhr`.
- That suggests the main issue is still signal-direction mismatch, not just baseline scaling.

## Recommended Improvements

1. Do not remove RHR globally and do not retune the engine to SWELL or WESAD alone.
- PhysioNet shows that the full HR-primary engine still works meaningfully well on a real acute-stress dataset.
- A global no-RHR retune would almost certainly give up real signal that the current product is already using successfully.

2. Keep all three datasets, but assign them different roles.
- PhysioNet should remain the acute-stress calibration anchor.
- SWELL should remain the office-stress challenge set.
- WESAD wrist should remain the labeled wrist-stress challenge set.
- Future algorithm changes should be judged against all three, not any one alone.

3. The next algorithm experiment should be a real desk-mode branch, not a universal weight change.
- The new evidence points to a branch like:
  - keep current HR-primary behavior for acute / exam-like contexts
  - use materially lower or zero RHR influence for desk-work / office-task contexts
  - add disagreement damping when HR and HRV disagree
- Do this in tests first, not in product code.

4. Do not prioritize more lightweight gates or SWELL-only normalization variants right now.
- The subject-normalized no-RHR branch did not beat plain `no-rhr`.
- The simple `gated-rhr` branch also did not beat `low-rhr` or `no-rhr`.
- The highest-value next experiment is a true context branch, not deeper SWELL-local baseline math.

5. WESAD now resolves the earlier tie-breaker question.
- WESAD behaves more like SWELL than PhysioNet.
- That strengthens the case for a true multi-context design instead of a single global formula.
- A fourth dataset is now optional, not required before designing the next branch.

6. Soften product confidence language until context modeling exists.
- The engine now has support for one real acute-stress dataset and failure on two real wrist / cognitive-stress datasets.
- That is enough for “useful wellness signal,” but not enough for broad claims that one stress formula generalizes across all environments.

7. Only change production if the same direction wins across:
- PhysioNet
- SWELL
- WESAD
- synthetic regression suites
- time-series regression suites

## StressEngine Improvement Roadmap

### What not to do

- Do not switch the product engine to `no-rhr` globally.
- Do not retune weights against SWELL or WESAD alone.
- Do not spend the next iteration on more challenge-set-local normalization variants.

Why:
- SWELL and WESAD say `RHR` is the wrong-way signal there.
- PhysioNet says `RHR` is still the strongest useful signal there.
- A single global weight change will likely improve one dataset by breaking the other.

### Recommended design direction

Move from a single-mode stress engine to a context-aware stress engine.

Practical target:
- keep the current HR-primary behavior for acute / exam-like stress
- add a second low-movement / desk-work branch that materially reduces or removes `RHR`
- add a disagreement / confidence layer so contradictory signals do not produce overconfident scores

### Recommended implementation plan

1. Add a context layer before scoring in [StressEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/StressEngine.swift)
- Introduce a small `StressContext` or `StressMode`:
  - `acute`
  - `desk`
  - `unknown`
- Do not bury this inside arbitrary thresholds in one giant formula. Make the mode explicit so it is testable.

2. Keep the current formula as the `acute` branch
- This branch already has real support from PhysioNet:
  - full engine AUC `0.729`
  - `rhr-only` nearly as good at `0.715`
- This should remain the default reference branch.

3. Add a true `desk` branch, not just a lightweight gate
- The first lightweight `gated-rhr` experiment is now complete:
  - SWELL AUC 0.241
  - WESAD AUC 0.251
  - PhysioNet AUC 0.721
- That result is useful, but it is not enough to justify a product change.
- The next candidate should look more like:
  - `RHR 0.00 to 0.10`
  - `HRV 0.55 to 0.65`
  - `CV 0.25 to 0.35`
- Keep this in tests first. Do not ship these numbers directly.

4. Add a signal-disagreement dampener
- If `RHR` implies stress up but `HRV` and `CV` do not, compress the final score toward neutral instead of letting one signal dominate.
- Example rule:
  - when `RHR` is elevated but `SDNN >= baseline` and `CV` is stable, reduce score magnitude and mark low confidence
- This is the safest way to avoid false certainty on SWELL-like cases.

5. Add confidence to the output
- Add a confidence or reliability field to the stress result model in [StressEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/StressEngine.swift)
- Confidence should drop when:
  - signals disagree strongly
  - baselines are weak
  - recent HRV sample count is low
  - context is `unknown`
- Even if the score stays the same, surfacing low confidence is a product improvement.

6. Decide context from real app features, not dataset names
- Candidate signals already available or derivable in the app:
  - recent steps
  - workout minutes
  - walk minutes
  - time of day
  - recent movement / inactivity pattern
  - recent sleep / readiness state
- The engine should never “know” it is on SWELL or PhysioNet. It should infer mode from physiology + context.

7. Add a stronger test-only `desk-branch` variant to [DatasetValidationTests.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/DatasetValidationTests.swift)
- The first `gated-rhr` variant is now done and did not meaningfully solve the cross-dataset conflict.
- Success condition for the next branch:
  - beats `gated-rhr` clearly on SWELL
  - stays close to the full engine on PhysioNet
  - remains clean on synthetic regression suites

8. Keep the three-dataset matrix as the new validation gate
- Required datasets:
  - PhysioNet
  - SWELL
  - WESAD
- Optional next dataset:
  - add a fourth dataset only if the desk-branch still leaves ambiguity after cross-dataset comparison

### Code changes to make next

In [StressEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/StressEngine.swift):
- add explicit context detection
- add `acute` and `desk` scoring branches
- add disagreement damping
- add confidence output

In [DatasetValidationTests.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/DatasetValidationTests.swift):
- keep `gated-rhr` as a rejected-but-useful reference point
- add a stronger `desk-branch` variant
- keep PhysioNet + SWELL + WESAD side by side

In [DashboardViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift):
- pass richer context into stress computation instead of just raw baseline numbers
- avoid presenting strong language when confidence is low

### Success criteria for the next version

The next product candidate should only move forward if it does all of these:
- keeps `StressEngineTests` green
- keeps `StressCalibratedTests` green
- keeps time-series regression green
- improves SWELL over current full-engine AUC `0.203`
- improves SWELL over lightweight `gated-rhr` AUC `0.241`
- improves WESAD over current full-engine AUC `0.178`
- improves WESAD over lightweight `gated-rhr` AUC `0.251`
- preserves PhysioNet near or above current full-engine AUC `0.729`
- does not rely on dataset-specific hardcoding

## Product Build Plan

### Current product gaps in the code

1. The engine is still single-mode.
- [StressEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/StressEngine.swift) uses one HR-primary formula for every situation.
- The validation evidence says that is the core mismatch.
- Acute exam-style stress and desk / office-task stress should not share the exact same weighting rules.

2. The engine output is too thin for product use.
- [HeartModels.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Models/HeartModels.swift) defines `StressResult` with only:
  - `score`
  - `level`
  - `description`
- There is no `confidence`, `mode`, `signal breakdown`, or `reason code`.
- That makes it hard to:
  - explain why a score happened
  - soften weak predictions
  - debug false positives

3. The engine does not receive enough context.
- [DashboardViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift) calls `computeStress(snapshot:recentHistory:)`, which only derives physiology baselines.
- It does not explicitly pass:
  - recent steps
  - recent workout load
  - inactivity / sedentary context
  - time-of-day context
  - recent sleep / recovery context
- That means the engine cannot reliably tell “acute stress” from “quiet desk work.”

4. The UI is stronger than the model.
- [StressView.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/Views/StressView.swift) presents direct stress messaging and action guidance.
- Right now the score has no confidence field, so the product cannot distinguish:
  - high-confidence elevated stress
  - uncertain or conflicting physiology

5. The validation story is better now, but still incomplete.
- Synthetic tests are good regression protection.
- Real-world validation is now materially better and includes:
  - PhysioNet acute exam stress
  - SWELL office-task challenge set
  - WESAD wrist `Base` vs `TSST`
- A fourth dataset is now optional, not mandatory.

### What we need to build for a more accurate score

1. A context-aware scoring contract
- Add a small explicit input model such as `StressContextInput` with:
  - `currentHRV`
  - `baselineHRV`
  - `baselineHRVSD`
  - `currentRHR`
  - `baselineRHR`
  - `recentHRVs`
  - `recentSteps`
  - `recentWalkMinutes`
  - `recentWorkoutMinutes`
  - `sedentaryMinutes`
  - `sleepHours`
  - `timeOfDay`
  - `hasWeakBaseline`
- This should become the main engine API.

2. An explicit mode decision
- Add `StressMode`:
  - `acute`
  - `desk`
  - `unknown`
- The engine should decide mode from context, not from dataset names.
- Start simple and testable:
  - high recent movement or post-activity recovery -> `acute`
  - low movement + seated pattern + working hours -> `desk`
  - mixed / weak evidence -> `unknown`

3. A richer result object
- Extend `StressResult` to include:
  - `confidence`
  - `mode`
  - `rhrContribution`
  - `hrvContribution`
  - `cvContribution`
  - `explanationKey`
  - optional `warnings`
- This is needed for both product quality and faster debugging.

4. A disagreement dampener
- If the signals disagree, the engine should reduce certainty instead of forcing a strong score.
- First product-safe rule:
  - if `RHR` is stress-up
  - but `HRV` is at or above baseline
  - and `CV` is stable
  - then compress the final score toward neutral and reduce confidence

5. Separate acute and desk scoring branches
- Acute branch:
  - keep current HR-primary structure as the starting point
- Desk branch:
  - use much lower or zero `RHR`
  - rely more on HRV deviation and CV
  - use stronger confidence penalties when signals are mixed

### How to find the remaining gaps before changing production scoring

1. Use the current three-dataset matrix as the standard gate.
- This step is now complete:
  - PhysioNet
  - SWELL
  - WESAD
- The next question is no longer “which third dataset should we add?”
- The next question is “which desk-branch design survives all three?”

2. Add error-analysis outputs, not just summary metrics.
- For every dataset run, capture:
  - false positives
  - false negatives
  - worst subjects
  - cases where `RHR` and `HRV` disagree
  - score distributions by mode candidate

3. Add ablation for candidate production branches.
- Keep evaluating:
  - `full`
  - `low-rhr`
  - `no-rhr`
  - `desk-branch`
  - `desk-branch + disagreement damping`
- The right answer should win across multiple datasets, not one.

4. Add app-level replay tests.
- Reconstruct real `HeartSnapshot` histories from dataset windows or fixture histories.
- Validate the full app path:
  - Health data -> `DashboardViewModel` -> `StressEngine` -> `ReadinessEngine` -> UI state
- This catches integration drift that unit tests miss.

5. Track confidence calibration.
- If the engine emits `high confidence`, those cases should be measurably more accurate than `low confidence`.
- Otherwise confidence becomes decoration instead of a useful product signal.

### Recommended implementation order

Phase 1: test harness and evidence
- Keep WESAD validation active
- Add `desk-branch` and `desk-branch + damping` as test-only variants
- Add false-positive / false-negative export summaries

Phase 2: engine contract
- Introduce `StressContextInput`
- Introduce `StressMode`
- Extend `StressResult` with confidence and signal breakdown

Phase 3: product integration
- Update [DashboardViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift) to pass richer context
- Update [StressView.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/Views/StressView.swift) to soften messaging when confidence is low
- Update readiness integration so it can use both stress score and confidence

Phase 4: ship criteria
- Only ship a new scoring branch if:
  - real-dataset performance improves
  - synthetic regression remains green
  - time-series regression remains green
  - the UI explains low-confidence cases more safely than today

### Short answer: how to make the score more accurate

- Stop treating all stress as one physiology pattern.
- Add context and mode detection.
- Add confidence and disagreement handling.
- Validate every candidate across at least 3 real-world dataset families.
- Only then retune the production formula.

## Local-First Build Blueprint

### Product constraint

This product should assume a local-first architecture.

That means:
- no cloud inference requirement for the core stress score
- no dependence on server-side model retraining for normal product operation
- no need to upload raw health data to make the score work

This is not a compromise.
Given the current evidence, a disciplined local engine is the correct design direction.
The problem is not "we need a bigger cloud model."
The problem is "we need better context, better branch selection, and better confidence handling."

### What should run where

1. On-device or in-app only
- Health signal ingestion
- Rolling baseline updates
- Context inference
- Stress mode selection
- Stress score computation
- Confidence computation
- Notification gating
- UI explanation rendering

2. Offline development only
- Public-dataset evaluation
- Coefficient tuning
- Threshold comparison
- Regression fixture generation

3. Not required for v1
- Cloud scoring
- Online personalization service
- Remote model serving
- LLM-based score generation

### Recommended local architecture

1. Data ingestion layer
- Source signals from the current app pipeline:
  - `restingHeartRate`
  - `heartRateVariabilitySDNN`
  - recent HRV series
  - steps
  - walk minutes
  - workout minutes
  - sleep duration
  - time-of-day bucket
- Normalize missingness early.
- The engine should know when a value is missing or weak instead of silently pretending it is normal.

2. Baseline layer
- Keep rolling personal baselines locally in the existing persistence layer.
- Baselines should be separated by:
  - short-term view: last 7 to 14 days
  - medium-term view: last 21 to 42 days
  - time-of-day bucket when enough data exists
- Store baseline quality metadata:
  - sample count
  - recentness
  - variance
  - whether sleep / illness / workout recovery likely contaminated it

3. Context inference layer
- Derive a small explicit `StressMode`:
  - `acute`
  - `desk`
  - `unknown`
- This must be a real tested decision layer, not hidden inside score weights.
- The first version can be rule-based.
- It does not need ML to be useful.

4. Branch scoring layer
- `acute` branch:
  - start from the current HR-primary engine
  - retain meaningful `RHR` influence
  - allow sharper score movement when physiology clearly matches acute activation
- `desk` branch:
  - materially reduce or remove `RHR`
  - rely more on HRV deviation, short-window instability, and sustained low-movement context
- `unknown` branch:
  - blend toward neutral
  - reduce confidence
  - avoid strong copy or alerts

5. Confidence layer
- Compute confidence separately from score.
- Confidence should reflect:
  - baseline quality
  - signal agreement
  - context clarity
  - sample sufficiency
  - recency of the data
- This is a first-class product output, not debug metadata.

6. Product decision layer
- UI copy should depend on:
  - score
  - confidence
  - mode
- Notifications should depend on:
  - sustained elevation
  - confidence
  - low-movement context
  - cooldown rules to avoid alert fatigue

### Strict implementation rules

1. No dataset-specific logic in product code.
- The app must never branch on SWELL, WESAD, or PhysioNet assumptions directly.
- Datasets exist only to validate whether a generalizable rule is safe.

2. No hidden mode logic.
- If there is an `acute` rule and a `desk` rule, the chosen mode must be observable in tests and logs.

3. No global weight retune before branch separation.
- Do not globally weaken `RHR` in the current single formula and call it fixed.
- The evidence says the problem is contextual, not just numeric.

4. No confidence theater.
- Do not add a confidence number unless it is validated.
- High-confidence predictions must be measurably more reliable than low-confidence ones.

5. No shipping branch logic without app-level replay tests.
- Unit tests are not enough.
- The full product path must be exercised:
  - health data
  - snapshot creation
  - stress computation
  - readiness impact
  - UI-facing state

6. No strong UI language when confidence is low or mode is unknown.
- The product must not overstate certainty just because the score number is high.

7. No notification on a single weak reading.
- Alerts require persistence, context, and confidence.

8. No shortcut around baseline quality.
- Weak baseline quality should reduce confidence and often reduce score amplitude.
- Missing baseline is not "same as normal baseline."

### Exact build order for the app

Phase 1. Stabilize the engine contract
- Add `StressContextInput`
- Add `StressMode`
- Extend `StressResult` with:
  - `confidence`
  - `mode`
  - `rhrContribution`
  - `hrvContribution`
  - `cvContribution`
  - `warnings`

Exit criteria:
- all existing stress tests compile and pass after the API transition
- the chosen mode is visible in unit tests

Phase 2. Add branch-aware scoring in tests first
- Implement `desk-branch` in validation-only code
- Implement `desk-branch + disagreement damping`
- Compare against:
  - `full`
  - `gated-rhr`
  - `low-rhr`
  - `no-rhr`

Exit criteria:
- at least one branch design clearly beats current `full` on SWELL and WESAD
- PhysioNet remains close enough to current acute performance

Phase 3. Move the winning structure into product code
- Preserve the current formula as `acute`
- Add a real `desk` branch
- Add `unknown`
- Add confidence penalties for:
  - weak baseline
  - mixed signals
  - sparse HRV history
  - ambiguous context

Exit criteria:
- synthetic suites green
- time-series suites green
- app-level replay tests green

Phase 4. Update product integration
- Pass richer context from [DashboardViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift)
- Update [StressViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/StressViewModel.swift) to use the same contract
- Update [StressView.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/Views/StressView.swift) to show uncertainty safely
- Update [ReadinessEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/ReadinessEngine.swift) integration to consume confidence

Exit criteria:
- dashboard and trend views do not diverge
- low-confidence states produce softer copy
- readiness responds less aggressively to uncertain stress

Phase 5. Add safe notification logic
- Notify only when:
  - stress is elevated over a persistence window
  - movement context suggests non-exercise stress
  - confidence exceeds threshold
  - cooldown rules are satisfied

Exit criteria:
- false-positive alert rate is acceptable in replay tests
- notification copy handles uncertainty safely

### Required score design rules

1. Score and confidence must be separate.
- A high score with low confidence is allowed.
- A high score with low confidence must not behave like a confirmed stress event.

2. Branch selection must happen before final weighting.
- Do not fake branching by applying one formula and then lightly clipping the output.

3. `unknown` must be a real outcome.
- If the engine cannot determine context cleanly, it should say so.
- This is safer than forcing an acute or desk interpretation.

4. Baseline quality must directly affect the product.
- Weak baseline lowers confidence.
- Very weak baseline should also compress the score toward neutral.

5. Disagreement must reduce certainty.
- If `RHR`, `HRV`, and variability tell different stories, the output should become softer, not louder.

### Required validation gates

1. Synthetic regression gate
- `StressEngineTests`
- `StressCalibratedTests`

2. Synthetic time-series gate
- `StressEngineTimeSeriesTests`

3. Real-world gate
- PhysioNet
- SWELL
- WESAD

4. Confidence calibration gate
- High-confidence slices must outperform low-confidence slices on real datasets.

5. Replay gate
- Full app-path replay fixtures must stay green before shipping.

### Local-first product advantages

If built correctly, the local-first design gives the product real advantages:
- better privacy story
- lower operating cost
- offline availability
- easier reasoning about failures
- easier deterministic testing
- lower risk of a hidden cloud model drift changing user-visible behavior

The tradeoff is that the app must be more disciplined about:
- context modeling
- baseline quality
- confidence handling
- validation gates

That tradeoff is acceptable and aligned with the current product stage.

### Final architecture recommendation

The best path for this product is:
- local rolling baselines
- explicit context detection
- branch-specific scoring
- explicit confidence
- conservative notification rules
- public-dataset offline calibration

It is not:
- cloud-first inference
- LLM-generated stress scores
- one formula with minor coefficient nudges
- shipping before replay and confidence validation are in place

## Strict No-Shortcut Rules

These rules should be treated as project policy for the stress feature.

1. Never call the score "accurate" unless it has passed all gates in this report.
2. Never merge a global retune that improves one challenge dataset by breaking the acute anchor.
3. Never ship a new branch unless the chosen mode is observable and test-covered.
4. Never show strong stress coaching when `mode == unknown` and confidence is low.
5. Never let notifications fire from a single sample or weak baseline.
6. Never replace interpretability with vague "AI" language in code or product copy.
7. Never silently fall back to synthetic-only evidence when real-dataset evidence disagrees.
8. Never add a confidence field without measuring whether it calibrates.
9. Never let dashboard stress, trend stress, and readiness stress use inconsistent logic.
10. Never treat missing data as normal data.

## Everything Still To Do

### A. Data and validation work

1. Keep all three dataset families active in validation.
- Required real-world families:
  - acute exam-style stress: PhysioNet
  - office / desk cognitive stress: SWELL
  - labeled wrist stress task: WESAD
- Do not retire SWELL or WESAD just because they are difficult. They are currently the best challenge sets we have.

2. Add an optional fourth dataset only if ambiguity remains after the desk-branch prototype.
- This is no longer a blocker for the next engine design step.
- It becomes useful only if the three-dataset matrix still cannot separate two competing branch designs.

3. Expand dataset diagnostics.
- Every real-dataset run should output:
  - overall AUC
  - Cohen's d
  - confusion at production threshold
  - per-condition metrics
  - per-subject metrics
  - worst false positives
  - worst false negatives
  - signal-disagreement slices

4. Add regression snapshots for candidate branches.
- Save comparable metrics for:
  - `full`
  - `low-rhr`
  - `no-rhr`
  - `gated-rhr`
  - `desk-branch`
  - `desk-branch + damping`
- This avoids repeating the same experiment without a baseline.

### B. Engine contract changes

1. Add a richer engine input model in [StressEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/StressEngine.swift).
- Create a dedicated context struct instead of growing the current parameter list forever.
- Minimum fields:
  - HRV values and baseline
  - RHR values and baseline
  - recent HRV series
  - activity and sedentary context
  - sleep / recovery context
  - time-of-day context
  - baseline quality flags

2. Add explicit stress modes.
- Add `acute`, `desk`, and `unknown`.
- Make the chosen mode observable in tests and in debug logging.

3. Extend the output model in [HeartModels.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Models/HeartModels.swift).
- Add:
  - `confidence`
  - `mode`
  - `rhrContribution`
  - `hrvContribution`
  - `cvContribution`
  - `warnings`
- The product needs these fields to explain and trust the score.

### C. Scoring logic changes

1. Preserve the current formula as the acute branch.
- Do not throw away the current HR-primary logic.
- It still has real support from PhysioNet.

2. Build a separate desk branch.
- Lower or remove `RHR` influence.
- Increase dependence on HRV deviation and CV.
- Penalize confidence when signals conflict.

3. Add disagreement damping.
- When `RHR` is stress-up but HRV and CV do not agree:
  - compress toward neutral
  - lower confidence
  - emit a warning or low-certainty explanation

4. Revisit the sigmoid only after context branches exist.
- Do not start by retuning `sigmoidK` or `sigmoidMid`.
- First solve the bigger modeling error: one formula for multiple contexts.

5. Revisit the raw `RHR` rule only inside branch-specific tuning.
- The current `40 + deviation * 4` rule may still be useful in `acute`.
- It may be too strong for `desk`.
- Tune it separately by mode, not globally.

### D. App integration changes

1. Pass richer context from [DashboardViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift).
- The engine should receive more than baseline physiology.
- Feed:
  - recent movement
  - inactivity pattern
  - sleep / readiness context
  - maybe current hour bucket

2. Update [StressViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/StressViewModel.swift).
- Make sure historical trend generation uses the same improved engine contract.
- Avoid a situation where dashboard stress and trend stress silently diverge.

3. Update [StressView.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/Views/StressView.swift).
- Use softer language when confidence is low.
- Show “uncertain / mixed signals” states instead of forcing the same UI treatment for all scores.

4. Update readiness integration.
- Let [ReadinessEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/ReadinessEngine.swift) consume stress confidence, not just stress score.
- A low-confidence high stress reading should not affect readiness as strongly as a high-confidence one.

### E. Testing work

1. Keep existing fast suites green.
- `StressEngineTests`
- `StressCalibratedTests`

2. Keep time-series regression green.
- `StressEngineTimeSeriesTests`
- Continue using `THUMP_RESULTS_DIR` so exploratory runs do not rewrite tracked fixtures.

3. Add app-level replay tests.
- Create replay fixtures that approximate real product inputs.
- Validate:
  - snapshot history in
  - stress result out
  - readiness effect
  - UI-facing state consistency

4. Add confidence calibration tests.
- High-confidence predictions should outperform low-confidence predictions.
- If not, the confidence field is not useful enough to ship.

5. Add mode-selection tests.
- Ensure obvious acute and obvious desk contexts route to the expected branch.
- Ensure ambiguous cases land in `unknown`, not overconfidently in one branch.

### F. Product / UX work

1. Reduce overclaiming.
- Avoid implying medical-grade accuracy.
- Avoid implying the same formula works equally well in all settings.

2. Add explainability.
- Use signal breakdown and warnings to tell the user why a score moved.
- This also helps internal debugging and support.

3. Decide how much of the internals to expose.
- Minimum product need:
  - confidence
  - softer copy for uncertainty
  - simple explanation
- Nice to have:
  - “why this changed” details
  - signal contribution view for advanced users

### G. Shipping rules

Do not ship a production retune until all of these are true:
- the new branch beats current `full` on SWELL
- the new branch stays close to or above current `full` on PhysioNet
- the new branch performs acceptably on WESAD
- synthetic tests remain green
- time-series tests remain green
- UI handling of low-confidence cases is safer than the current experience

### H. Concrete next 5 tasks

1. Add a stronger test-only `desk-branch` variant in [DatasetValidationTests.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/DatasetValidationTests.swift).
2. Add `desk-branch + disagreement damping`.
3. Add false-positive / false-negative export summaries for SWELL, WESAD, and PhysioNet.
4. Add `StressContextInput` and `StressMode` in [StressEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/StressEngine.swift) and update tests around them.
5. Extend `StressResult` in [HeartModels.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Models/HeartModels.swift), then update [DashboardViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift) and [StressView.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/Views/StressView.swift) to use the new fields.

## Residual Notes

- Xcode still emits an availability warning in `Shared/Views/ThumpBuddyFace.swift` for `.symbolEffect(.bounce, isActive:)` under Swift 6 mode.
- That warning did not block the validation runs.

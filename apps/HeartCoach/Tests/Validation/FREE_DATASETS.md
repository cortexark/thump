# Free Physiological Datasets for Thump Engine Validation

## Purpose
Validate Thump's 10 engines against real-world physiological data instead of
only the 10 synthetic persona profiles. Each dataset maps to specific engines.

---

## Dataset → Engine Mapping

| Dataset | Engine(s) | Metrics | Subjects | Format |
|---|---|---|---|---|
| WESAD | StressEngine | HR, HRV, EDA, BVP, temp | 15 | CSV |
| SWELL-HRV | StressEngine | HRV features, stress labels | 25 | CSV |
| PhysioNet Exam Stress | StressEngine | HR, IBI, BVP | 35 | CSV |
| Walch Apple Watch Sleep | ReadinessEngine, SleepPattern | HR, accel, sleep labels | 31 | CSV |
| Apple Health Sleep+HR | ReadinessEngine | Sleep stages, HR | 1 | CSV |
| PMData (Simula) | HeartTrendEngine, Readiness | HR, sleep, steps, calories | 16 | JSON/CSV |
| Fitbit Tracker Data | HeartTrendEngine, ActivityPattern | HR, steps, sleep, calories | 30 | CSV |
| LifeSnaps Fitbit | All trend engines | HR, HRV, sleep, steps, stress | 71 | CSV |
| NTNU HUNT3 Reference | BioAgeEngine | VO2max, HR, age, sex | 4,631 | Published tables |
| Aidlab Weekly Datasets | StressEngine, TrendEngine | ECG, HR, HRV, respiration | Varies | CSV |
| Wearable HRV + Sleep Diary | ReadinessEngine, StressEngine | HRV (5-min), sleep diary, anxiety | 49 | CSV |

---

## 1. WESAD — Wearable Stress and Affect Detection
**Best for:** StressEngine validation (stressed vs baseline vs amusement)

- **Source:** [UCI ML Repository](https://archive.ics.uci.edu/ml/datasets/WESAD+(Wearable+Stress+and+Affect+Detection)) / [Kaggle mirror](https://www.kaggle.com/datasets/orvile/wesad-wearable-stress-affect-detection-dataset)
- **Subjects:** 15 (lab study)
- **Sensors:** Empatica E4 (wrist) + RespiBAN (chest)
- **Metrics:** BVP, EDA, ECG, EMG, respiration, temperature, accelerometer
- **Labels:** baseline, stress (TSST), amusement, meditation
- **Format:** CSV exports available
- **License:** Academic/non-commercial

**Validation plan:**
1. Extract per-subject HR and SDNN HRV from IBI data
2. Feed into StressEngine.computeScore(rhr:, sdnn:, cv:)
3. Expect: stress-labeled segments → score > 60; baseline → score < 40
4. Report Cohen's d between groups (target: d > 1.5)

---

## 2. SWELL-HRV — Stress in Work Environments
**Best for:** StressEngine with pre-computed HRV features

- **Source:** [Kaggle](https://www.kaggle.com/datasets/qiriro/swell-heart-rate-variability-hrv)
- **Subjects:** 25 office workers
- **Metrics:** Pre-computed HRV (SDNN, RMSSD, LF, HF, LF/HF), stress labels
- **Labels:** no stress, time pressure, interruption
- **Format:** CSV (ready to use)

**Validation plan:**
1. Map SDNN + mean HR to StressEngine inputs
2. Compare StressEngine scores against ground truth labels
3. Compute AUC-ROC for binary stressed/not-stressed

---

## 3. PhysioNet Wearable Exam Stress
**Best for:** StressEngine (already calibrated against this — verify consistency)

- **Source:** [PhysioNet](https://physionet.org/content/wearable-exam-stress/)
- **Subjects:** 35 university students
- **Metrics:** HR, BVP, IBI, EDA, temperature
- **Labels:** pre-exam (stress), post-exam (recovery)
- **Format:** CSV

**Validation plan:** Already used for initial calibration (Cohen's d = +2.10).
Re-run after any StressEngine changes to confirm no regression.

---

## 4. Walch Apple Watch Sleep Dataset
**Best for:** ReadinessEngine sleep pillar, sleep pattern detection

- **Source:** [Kaggle](https://www.kaggle.com/datasets/msarmi9/walch-apple-watch-sleep-dataset)
- **Subjects:** 31 (clinical sleep study)
- **Metrics:** HR (Apple Watch), accelerometer, polysomnography labels
- **Labels:** Wake, NREM1, NREM2, NREM3, REM
- **Format:** CSV

**Validation plan:**
1. Compute sleep hours and sleep quality proxy from labeled stages
2. Feed into ReadinessEngine.scoreSleep()
3. Verify poor sleepers (< 6 hrs, fragmented) → sleep pillar < 50
4. Good sleepers (7+ hrs, consolidated) → sleep pillar > 70

---

## 5. PMData — Personal Monitoring Data (Simula)
**Best for:** HeartTrendEngine week-over-week, multi-day patterns

- **Source:** [Simula Research](https://datasets.simula.no/pmdata/)
- **Subjects:** 16 persons, 5 months
- **Metrics:** HR (Fitbit), steps, sleep, calories, self-reported wellness
- **Format:** JSON + CSV

**Validation plan:**
1. Build 28-day HeartSnapshot arrays from daily data
2. Run HeartTrendEngine.assess() over sliding windows
3. Compare detected anomalies/regressions against self-reported "bad days"
4. Verify week-over-week z-scores flag real trend changes

---

## 6. Fitbit Fitness Tracker Data
**Best for:** Activity pattern detection, daily metric variation

- **Source:** [Kaggle](https://www.kaggle.com/datasets/arashnic/fitbit)
- **Subjects:** 30 Fitbit users, 31 days
- **Metrics:** Steps, distance, calories, HR (minute-level), sleep
- **Format:** CSV

**Validation plan:**
1. Convert to HeartSnapshot (dailySteps, workoutMinutes, sleepHours, avgHR)
2. Run activityPatternRec() and sleepPatternRec()
3. Verify inactive days (< 2000 steps) get flagged
4. Verify short sleep (< 6 hrs) × 2 days triggers alert

---

## 7. LifeSnaps Fitbit Dataset
**Best for:** Full pipeline validation (most comprehensive)

- **Source:** [Kaggle](https://www.kaggle.com/datasets/skywescar/lifesnaps-fitbit-dataset)
- **Subjects:** 71 participants
- **Metrics:** HR, HRV, sleep stages, steps, stress score, SpO2
- **Format:** CSV

**Validation plan:**
1. Most comprehensive — test ALL engines end-to-end
2. Fitbit stress scores as external benchmark for StressEngine
3. Sleep stages for ReadinessEngine
4. Long duration enables HeartTrendEngine regression detection

---

## 8. NTNU HUNT3 VO2 Max Reference
**Best for:** BioAgeEngine VO2 offset calibration

- **Source:** [NTNU CERG](https://www.ntnu.edu/cerg/vo2max) + [Published paper (PLoS ONE)](https://journals.plos.org/plosone/article/file?id=10.1371/journal.pone.0064319&type=printable)
- **Subjects:** 4,631 healthy adults (20–90 years)
- **Metrics:** VO2max, submaximal HR, age, sex
- **Format:** Published percentile tables (extract manually)

**Validation plan:**
1. Extract age-sex VO2max percentiles from paper tables
2. For each percentile: compute BioAgeEngine.estimate() offset
3. Verify: 50th percentile → offset ≈ 0; 90th → offset ≈ -5 to -8; 10th → offset ≈ +5 to +8
4. Compare against NTNU's own Fitness Age calculator predictions

---

## 9. Wearable HRV + Sleep Diaries (2025)
**Best for:** ReadinessEngine, StressEngine with real-world context

- **Source:** [Nature Scientific Data](https://www.nature.com/articles/s41597-025-05801-3)
- **Subjects:** 49 healthy adults, 4 weeks continuous
- **Metrics:** Smartwatch HRV (5-min SDNN), sleep diary, anxiety/depression questionnaires
- **Format:** CSV

**Validation plan:**
1. Map daily SDNN + sleep quality to ReadinessEngine inputs
2. Correlate readiness scores with self-reported anxiety (GAD-7)
3. Verify anxious days → lower readiness, high stress scores

---

## Quick Start: Download Priority

For immediate validation with minimal effort:

1. **SWELL-HRV** (Kaggle, CSV, ready to use) → StressEngine
2. **Fitbit Tracker** (Kaggle, CSV) → HeartTrendEngine + activity patterns
3. **Walch Apple Watch** (Kaggle, CSV) → ReadinessEngine sleep
4. **NTNU paper tables** (free PDF) → BioAgeEngine calibration

These 4 datasets cover all core engines and require no data conversion.

---

## Test Harness Location
See `Tests/Validation/DatasetValidationTests.swift` for the test harness
that loads these datasets and runs them through Thump engines.

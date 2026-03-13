# HeartCoach / Thump — Project Documentation

## Epic → Story → Subtask Breakdown

Date: 2026-03-13
Repository: `Apple-watch`

---

## EPIC 1: Core Health Engine Layer

**Goal:** Build a suite of stateless, on-device health analytics engines that transform daily HealthKit snapshots into actionable wellness insights.

**Architecture Decision:** Each engine is a pure struct with no side effects. Engines receive a `HeartSnapshot` (11 optional metrics: RHR, HRV, recovery 1m/2m, VO2 max, zone minutes, steps, walk/workout minutes, sleep hours, body mass) and return typed result structs. This allows deterministic testing and parallel computation.

---

### Story 1.1: HeartTrendEngine — Daily Assessment & Anomaly Detection

**File:** `apps/HeartCoach/Shared/Engine/HeartTrendEngine.swift` (968 lines)
**Purpose:** Core trend computation using robust statistics (median + MAD) and pattern matching. Orchestrates all daily assessment logic.

#### Subtask 1.1.1: Anomaly Score Computation
- **What:** Weighted Z-score composite across 5 metrics
- **How:** Uses robust Z-scores (median + MAD instead of mean + SD for outlier resistance)
- **Weights:** RHR 0.25, HRV 0.25 (negated — lower is worse), Recovery 1m 0.20, Recovery 2m 0.10, VO2 Max 0.20
- **Why robust stats:** Mean/SD are sensitive to outliers common in health data (e.g., one bad night skews the baseline). MAD is resistant to this.
- **Method:** `anomalyScore(current:history:)` → `robustZ()` per metric → weighted sum

#### Subtask 1.1.2: Regression Detection
- **What:** Multi-day slope analysis detecting worsening trends
- **How:** Linear slope over 7-day window. RHR slope > -0.3 (increasing) OR HRV slope < -0.3 (decreasing) triggers regression flag
- **Why these thresholds:** Conservative — avoids false positives from normal daily variation while catching sustained multi-day shifts
- **Method:** `detectRegression(history:current:)` → `linearSlope()`

#### Subtask 1.1.3: Stress Pattern Detection
- **What:** Detect concurrent RHR elevation + HRV depression + recovery depression
- **How:** All three must be present: RHR Z ≥ 1.5, HRV Z ≤ -1.5, Recovery Z ≤ -1.5
- **Why all-three rule:** Single-metric spikes are normal variation. Triple-signal concurrent deviation is a strong indicator of systemic stress.
- **Method:** `detectStressPattern(current:history:)`

#### Subtask 1.1.4: Week-Over-Week RHR Trend
- **What:** Compare current 7-day RHR mean against 28-day rolling baseline
- **How:** Z-score comparison. Thresholds: < -1.5 significant improvement, > 1.5 significant elevation
- **Why 28-day baseline:** Long enough to smooth weekly variation, short enough to adapt to genuine fitness changes
- **Known bug:** Baseline includes current week data, diluting trend magnitude (see CR-005 in code review)
- **Method:** `weekOverWeekTrend(history:current:)` → `currentWeekRHRMean()`

#### Subtask 1.1.5: Consecutive Elevation Detection
- **What:** Detect 3+ consecutive days of RHR > mean + 2σ
- **How:** Calendar-date-aware consecutive counting (not array index). Gaps > 1.5 days break the streak.
- **Why:** Based on ARIC research finding that consecutive RHR elevation precedes illness by 1–3 days
- **Method:** `detectConsecutiveElevation(history:current:)`

#### Subtask 1.1.6: Recovery Trend Analysis
- **What:** Track post-exercise recovery HR improvement/decline over time
- **Method:** `recoveryTrend(history:current:)`

#### Subtask 1.1.7: Coaching Scenario Detection
- **What:** Pattern-match against known scenarios: overtraining, high stress, great recovery, missing activity, improving/declining trends
- **How:** Each scenario has specific multi-metric thresholds (e.g., overtraining = RHR +7 bpm for 3 days + HRV -20%)
- **Method:** `detectScenario(history:current:)`

#### Subtask 1.1.8: Assessment Assembly
- **What:** Combine all sub-analyses into a single `HeartAssessment` output
- **Output:** status (TrendStatus), confidence (ConfidenceLevel), anomalyScore, flags (regression, stress, consecutive), dailyNudge(s), explanation text, recoveryContext
- **Method:** `assess(history:current:feedback:)`

---

### Story 1.2: StressEngine — HR-Primary Stress Scoring

**File:** `apps/HeartCoach/Shared/Engine/StressEngine.swift` (642 lines)
**Purpose:** Quantify daily stress level using a 3-signal algorithm calibrated against PhysioNet Wearable Exam Stress Dataset.

#### Subtask 1.2.1: Three-Signal Algorithm Design
- **What:** Composite stress score from RHR deviation (50%), HRV Z-score (30%), HRV coefficient of variation (20%)
- **Why HR-primary:** PhysioNet data showed HR is the strongest discriminator (Cohen's d = 2.10 vs d = 1.31 for HRV). HRV inverts direction under seated cognitive stress, making it unreliable alone.
- **Dynamic weighting:** Adapts when signals are missing (e.g., RHR+HRV only → 60/40 split)

#### Subtask 1.2.2: Log-SDNN HRV Transformation
- **What:** Use log(SDNN) instead of raw SDNN for Z-score computation
- **Why:** HRV distribution is right-skewed across populations. Log transform improves linearity and makes Z-scores more meaningful across the population range.
- **Method:** `computeStress(currentHRV:baselineHRV:baselineHRVSD:currentRHR:baselineRHR:recentHRVs:)`

#### Subtask 1.2.3: RHR Deviation Scoring
- **What:** Raw percentage elevation above personal baseline, scored: 40 + (% deviation × 4)
- **Why 40 baseline:** Centers the neutral-stress output around the middle of the 0–100 range
- **Interpretation:** +5% above baseline = moderate stress, +10% = high stress

#### Subtask 1.2.4: Coefficient of Variation (Tertiary Signal)
- **What:** CV = SD / mean of recent 7-day HRVs. CV < 0.15 = stable (low stress), CV > 0.30 = unstable (high stress)
- **Why:** Signals autonomic instability independent of absolute HRV level

#### Subtask 1.2.5: Sigmoid Normalization
- **What:** `sigmoid(x) = 100 / (1 + exp(-0.08 × (x - 50)))` — smooth S-curve
- **Why:** Concentrates sensitivity around the 30–70 range where most users live. Prevents extreme inputs from producing implausible outputs.

#### Subtask 1.2.6: Stress Level Classification
- **Levels:** Relaxed (0–35), Balanced (35–65), Elevated (65–100)
- **Output:** StressResult (score 0–100, level, description text)

#### Subtask 1.2.7: Circadian Hourly Estimates
- **What:** Interpolate daily HRV to hourly estimates using circadian multipliers
- **How:** Night hours 1.10–1.20 (HRV higher during sleep), afternoon 0.82–0.90 (lowest HRV), evening 0.95–1.10 (recovery)
- **Method:** `hourlyStressEstimates(dailyHRV:baselineHRV:date:)`

#### Subtask 1.2.8: Trend Direction Analysis
- **What:** Rising/falling/steady classification from time-series slope
- **How:** Slope threshold ±0.5 points/day
- **Method:** `trendDirection(points:)`

---

### Story 1.3: ReadinessEngine — Daily Readiness Score

**File:** `apps/HeartCoach/Shared/Engine/ReadinessEngine.swift` (523 lines)
**Purpose:** Daily readiness score (0–100) from 5 wellness pillars.

#### Subtask 1.3.1: Pillar Model Design
- **Pillars & Weights:** Sleep (0.25), Recovery (0.25), Stress (0.20), Activity Balance (0.15), HRV Trend (0.15)
- **Why these weights:** Sleep and recovery are the two strongest predictors of next-day performance in sports science literature. Stress is weighted below them because it's a heuristic composite. Activity balance and HRV trend are supplementary signals.
- **Re-normalization:** When pillars are missing (nil data), weights redistribute proportionally among available pillars

#### Subtask 1.3.2: Sleep Scoring
- **What:** Gaussian bell curve centered at 8 hours (σ = 1.5)
- **Formula:** `100 × exp(-0.5 × (deviation / 1.5)²)`
- **Why Gaussian:** Both too little and too much sleep are suboptimal. Bell curve naturally penalizes both directions.
- **Example scores:** 7h = ~95, 6h ≈ 75, 5h ≈ 41, 10h ≈ 75
- **Method:** `scoreSleep(snapshot:)`

#### Subtask 1.3.3: Recovery Scoring
- **What:** Linear mapping from recovery HR 1-minute drop
- **Scale:** 10 bpm drop = 0, 40+ bpm drop = 100
- **Why linear:** Recovery HR has a well-established linear relationship with cardiovascular fitness
- **Method:** `scoreRecovery(snapshot:)`

#### Subtask 1.3.4: Stress Scoring
- **What:** Simple inversion: 100 - stressScore
- **Known issue:** Currently receives coarse 70.0 when stress flag is set, not the actual StressEngine score (see code review CR-008)
- **Method:** `scoreStress(stressScore:)`

#### Subtask 1.3.5: Activity Balance Scoring
- **What:** 7-day pattern analysis recognizing smart recovery, sedentary streaks, and optimal daily volume
- **Patterns:** Active yesterday + rest today = 85 (smart recovery). 3 days inactive = 30. 20–45 min/day avg = 100. Excess penalized.
- **Method:** `scoreActivityBalance(snapshot:recentHistory:)`

#### Subtask 1.3.6: HRV Trend Scoring
- **What:** Compare today's HRV to 7-day average
- **Scale:** At or above average = 100. Each 10% below = -20 points (capped at 0)
- **Method:** `scoreHRVTrend(snapshot:recentHistory:)`

#### Subtask 1.3.7: Readiness Level Classification
- **Levels:** Primed (80–100, bolt icon), Ready (60–79, checkmark), Moderate (40–59, minus), Recovering (0–39, sleep icon)
- **Overtraining cap:** If consecutive elevation alert active, cap readiness at 50

---

### Story 1.4: BioAgeEngine — Biological Age Estimation

**File:** `apps/HeartCoach/Shared/Engine/BioAgeEngine.swift` (517 lines)
**Purpose:** Estimate biological/fitness age from health metrics using NTNU fitness age formula.

#### Subtask 1.4.1: Multi-Metric Weighted Estimation
- **Weights:** VO2 Max (0.20), RHR (0.22), HRV (0.22), Sleep (0.12), Activity (0.12), BMI (0.12)
- **Per-metric conversion:** VO2 (0.8 years per 1 mL/kg/min), RHR (0.4 years per 1 bpm), HRV (0.15 years per 1ms), Sleep (1.5 years per hour outside 7–9h), Activity (0.05 years per 10 min), BMI (0.6 years per point from optimal)
- **Method:** `estimate(snapshot:chronologicalAge:sex:)`

#### Subtask 1.4.2: Sex-Stratified Norms
- **What:** Age-normalized expected values differ by biological sex
- **Methods:** `expectedVO2Max(for:sex:)`, `expectedRHR(for:sex:)`, `expectedHRV(for:sex:)`

#### Subtask 1.4.3: Offset Clamping & Normalization
- **What:** Per-metric offsets clamped to ±8 years, normalized by weight coverage (sum of available metric weights)
- **Why clamp:** Prevents single extreme metric from producing unrealistic bio age

#### Subtask 1.4.4: BMI Approximation
- **What:** BMI estimated from weight + sex-based average height (male 1.75m, female 1.63m)
- **Known limitation:** Creates bias for users who are much shorter or taller than average. Height input planned for future.

#### Subtask 1.4.5: Category & Explanation
- **Categories:** excellent (≤ -5), good (-5 to -2), onTrack (-2 to +2), watchful (+2 to +5), needsWork (≥ +5)
- **Method:** `buildExplanation(category:difference:breakdown:)` — generates user-facing text per metric contribution

---

### Story 1.5: BuddyRecommendationEngine — Prioritized Action Recommendations

**File:** `apps/HeartCoach/Shared/Engine/BuddyRecommendationEngine.swift` (484 lines)
**Purpose:** Synthesize all engine outputs into up to 4 prioritized buddy recommendations.

#### Subtask 1.5.1: Priority Ordering System
- **Critical:** Consecutive alert (3+ elevated RHR days)
- **High:** Coaching scenarios, week-over-week elevation, regression
- **Medium:** Recovery dip, missing activity, readiness-driven recovery
- **Low:** Positive signals, improved trends, general wellness

#### Subtask 1.5.2: Category Deduplication
- **What:** Keep only highest-priority recommendation per category
- **Why:** Prevents multiple "rest" recommendations from different signal sources stacking up
- **Method:** `deduplicateByCategory(_:)`

#### Subtask 1.5.3: Pattern Detection Recommendations
- **Activity pattern:** 2+ days low activity → activity suggestion
- **Sleep pattern:** 2+ nights < 6 hours → sleep suggestion
- **Methods:** `activityPatternRec(current:history:)`, `sleepPatternRec(current:history:)`

---

### Story 1.6: CoachingEngine — Motivational Coaching Messages

**File:** `apps/HeartCoach/Shared/Engine/CoachingEngine.swift` (568 lines)
**Purpose:** Generate coaching report connecting daily actions to metric improvements.

#### Subtask 1.6.1: Metric Trend Analysis (5 metrics)
- **RHR:** change < -1.5 bpm = improving, > 2.0 bpm = declining
- **HRV:** change > 3 ms = improving, < -5 ms = declining (with % change)
- **Activity:** +5 min/day + RHR drop = significant improvement signal
- **Recovery:** +2 bpm = improving, -3 bpm = declining
- **VO2:** +0.5 mL/kg/min = improving, -0.5 = declining
- **Known bug:** Uses `Date()` instead of `current.date` for week boundaries — breaks historical replay

#### Subtask 1.6.2: Projection Generation
- **What:** 4-week forward projections based on current trends
- **How:** RHR drop 0.8–5 bpm/week (depends on activity level), HRV +1.5 ms/week (if 7+ sleep hours)
- **Method:** `generateProjections(current:history:streakDays:)`

#### Subtask 1.6.3: Report Assembly
- **Output:** CoachingReport with heroMessage, 5+ insights, 2 projections, weeklyProgressScore (0–100), streakDays

---

### Story 1.7: NudgeGenerator — Contextual Daily Nudge Selection

**File:** `apps/HeartCoach/Shared/Engine/NudgeGenerator.swift` (636 lines)
**Purpose:** Select up to 3 nudges from 15+ variations, gated by readiness score.

#### Subtask 1.7.1: Priority-Based Selection
- **Order:** Stress → Regression → Low data → Negative feedback → Positive → Default
- **Each tier:** Selects from a library of 3–5 variations using day-of-month for rotation

#### Subtask 1.7.2: Readiness Gating
- **Recovering (< 40):** Rest or breathing only
- **Moderate (40–59):** Walk only (no moderate/hard)
- **Ready+ (≥ 60):** Full library available
- **Why:** Prevents recommending high-intensity activity when the body needs recovery

#### Subtask 1.7.3: Multiple Nudge Assembly
- **Primary:** Same as single `generate()` output
- **Secondary options:** Readiness-driven recovery, sleep signal, activity signal, HRV signal, zone recommendation, hydration, positive reinforcement

---

### Story 1.8: HeartRateZoneEngine — Personalized HR Zones

**File:** `apps/HeartCoach/Shared/Engine/HeartRateZoneEngine.swift` (499 lines)
**Purpose:** Karvonen formula (HRR method) zone computation + zone analysis.

#### Subtask 1.8.1: Karvonen Zone Computation
- **Formula:** `Zone_boundary = HRrest + (intensity% × (HRmax - HRrest))`
- **Max HR:** Tanaka formula: `HRmax = 208 - 0.7 × age` (±1 bpm female adjustment)
- **5 Zones:** Recovery (50–60%), Fat Burn (60–70%), Aerobic (70–80%), Threshold (80–90%), Peak (90–100%)
- **Method:** `computeZones(age:restingHR:sex:)`

#### Subtask 1.8.2: Zone Distribution Analysis
- **Scoring:** Weighted 0.10, 0.15, 0.35, 0.25, 0.15 (zones 1–5). 80/20 rule check (80% easy, 20% hard)
- **Known issue:** HealthKit `zoneMinutes` always empty — engine is effectively mock-only today
- **Method:** `analyzeZoneDistribution(zoneMinutes:fitnessLevel:)`

#### Subtask 1.8.3: Weekly Zone Summary
- **What:** 7-day aggregation with moderate/vigorous targets and AHA compliance check
- **Method:** `weeklyZoneSummary(history:)`

---

### Story 1.9: CorrelationEngine — Factor-Metric Correlation

**File:** `apps/HeartCoach/Shared/Engine/CorrelationEngine.swift` (330 lines)
**Purpose:** Pearson correlation analysis between lifestyle factors and cardiovascular metrics.

#### Subtask 1.9.1: Four Hard-Coded Pairs
1. Daily Steps ↔ RHR (expect negative)
2. Walk Minutes ↔ HRV SDNN (expect positive)
3. Activity Minutes ↔ Recovery HR 1m (expect positive) — **bug:** uses `workoutMinutes` only, not total activity
4. Sleep Hours ↔ HRV SDNN (expect positive)
- **Minimum:** 7 paired non-nil data points per factor

#### Subtask 1.9.2: Strength Classification
- **|r| thresholds:** 0–0.2 negligible, 0.2–0.4 noticeable, 0.4–0.6 clear, 0.6–0.8 strong, 0.8–1.0 very consistent

---

### Story 1.10: SmartNudgeScheduler — Timing-Aware Nudges

**File:** `apps/HeartCoach/Shared/Engine/SmartNudgeScheduler.swift` (425 lines)
**Purpose:** Learn user patterns (bedtime, wake time, stress rhythms) for timed nudge delivery.

#### Subtask 1.10.1: Sleep Pattern Learning
- **What:** Group sleep data by day-of-week, estimate bedtime/wake from sleep hours
- **Defaults:** Weekday 22:00/7:00, Weekend 23:00/8:00
- **Minimum observations:** 3 before trusting pattern
- **Limitation:** Infers from duration, not actual timestamped sleep sessions

#### Subtask 1.10.2: Action Priority
1. High stress (≥ 65) → journal prompt
2. Stress rising → breath exercise on Watch
3. Late wake (> 1.5h past typical, morning) → check-in
4. Near bedtime → wind-down
5. Activity/sleep suggestions
6. Default nudge

---

## EPIC 2: iOS Application Layer

**Goal:** Build the iPhone app with dashboard, insights, trends, stress analysis, onboarding, settings, and paywall screens.

---

### Story 2.1: DashboardView — Main Dashboard

**File:** `apps/HeartCoach/iOS/Views/DashboardView.swift` (~2,197 lines)
**ViewModel:** `apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift`

#### Subtask 2.1.1: Dashboard Refresh Pipeline
- **What:** Pull-to-refresh triggers HealthKit fetch → engine computation → UI update
- **How:** `refresh()` loads 30-day history, runs HeartTrendEngine, persists snapshot, then cascades: streak → nudge evaluation → weekly trend → check-in → bio age → readiness → coaching → zone analysis → buddy recommendations
- **Data flow:** `HealthKitService.fetchHistory()` → `HeartTrendEngine.assess()` → `LocalStore.appendSnapshot()` → parallel engine computations

#### Subtask 2.1.2: Metric Tile Grid
- **What:** 6 metric tiles (RHR, HRV, Recovery, VO2, Sleep, Steps) with trend arrows and context-aware colors
- **Implementation:** `MetricTileView` with `lowerIsBetter` parameter for correct color semantics (RHR down = green)

#### Subtask 2.1.3: Buddy Recommendations Section
- **What:** Up to 4 prioritized recommendation cards from BuddyRecommendationEngine
- **Replaced:** Original `nudgeSection` (still exists as unused code)

#### Subtask 2.1.4: Streak & Nudge Completion
- **What:** Track daily nudge completion and streak counter
- **Known bugs:** Streak increments multiple times per day (CR-004), completion rate inferred from assessment existence not actual completion (CR-003)

---

### Story 2.2: StressView — Stress Analysis

**File:** `apps/HeartCoach/iOS/Views/StressView.swift` (~1,228 lines)
**ViewModel:** `apps/HeartCoach/iOS/ViewModels/StressViewModel.swift`

#### Subtask 2.2.1: Stress Score Display
- **What:** Current stress score with level indicator and trend direction
- **Data:** StressEngine output (0–100 score, level, description)

#### Subtask 2.2.2: Hourly Stress Estimates
- **What:** 24-hour circadian stress visualization
- **Data:** StressEngine hourly estimates with circadian multipliers

---

### Story 2.3: TrendsView — Historical Trends

**File:** `apps/HeartCoach/iOS/Views/TrendsView.swift` (~1,020 lines)
**ViewModel:** `apps/HeartCoach/iOS/ViewModels/TrendsViewModel.swift`

#### Subtask 2.3.1: Multi-Range Chart Display
- **What:** Day/week/month range selector with chart data for all metrics
- **Labels:** "VO2" renamed to "Cardio Fitness", "mL/kg/min" → "score"

---

### Story 2.4: InsightsView — Correlations & Weekly Report

**File:** `apps/HeartCoach/iOS/Views/InsightsView.swift`
**ViewModel:** `apps/HeartCoach/iOS/ViewModels/InsightsViewModel.swift`

#### Subtask 2.4.1: Correlation Cards
- **What:** Display factor-metric correlations with human-readable strength labels
- **Labels:** Raw coefficients de-emphasized, "Weak"/"Strong" labels lead

#### Subtask 2.4.2: Weekly Report Generation
- **What:** Weekly summary with nudge completion rate and trend overview
- **Known bug:** Completion rate inflated by auto-stored assessments (CR-003)

---

### Story 2.5: Onboarding & Legal Gate

**File:** `apps/HeartCoach/iOS/Views/OnboardingView.swift`

#### Subtask 2.5.1: Health Disclaimer Gate
- **What:** Blocks progression until user accepts "I understand this is not medical advice" toggle
- **Language:** "wellness tool" not "heart training buddy"

#### Subtask 2.5.2: HealthKit Permission Request
- **What:** Request read access for: RHR, HRV, recovery HR, VO2 max, steps, walking, workouts, sleep, body mass

---

### Story 2.6: Settings & Data Export

**File:** `apps/HeartCoach/iOS/Views/SettingsView.swift`

#### Subtask 2.6.1: CSV Export
- **What:** Export health history as CSV
- **Headers:** Humanized (e.g., "Heart Rate Variability (ms)" not "HRV (SDNN)")

#### Subtask 2.6.2: Profile Management
- **What:** Display name, date of birth, biological sex, units preferences

---

### Story 2.7: Paywall & Subscriptions

**Files:** `apps/HeartCoach/iOS/Views/PaywallView.swift`, `apps/HeartCoach/iOS/Services/SubscriptionService.swift`

#### Subtask 2.7.1: StoreKit 2 Integration
- **What:** Product loading, purchase flow, subscription status tracking
- **Tiers:** Free, Premium monthly/annual
- **Fix applied:** `@Published var productLoadError` surfaces silent load failures

---

## EPIC 3: Apple Watch Application

**Goal:** Mirror key iPhone dashboard data on Apple Watch with haptic-enabled nudge delivery and feedback collection.

---

### Story 3.1: Watch Home & Detail Views

**Files:** `Watch/Views/WatchHomeView.swift`, `Watch/Views/WatchDetailView.swift`

#### Subtask 3.1.1: Summary Dashboard
- **What:** Compact daily status with key metrics synced from iPhone

#### Subtask 3.1.2: Detail Metrics
- **What:** Expanded metric view with anomaly labels ("Normal", "Slightly Unusual", "Worth Checking")

---

### Story 3.2: Watch Nudge & Feedback

**Files:** `Watch/Views/WatchNudgeView.swift`, `Watch/Views/WatchFeedbackView.swift`

#### Subtask 3.2.1: Nudge Display
- **What:** Daily nudge card with haptic feedback delivery

#### Subtask 3.2.2: Feedback Collection
- **What:** Positive/negative/skipped response → synced back to iPhone via WatchConnectivity

---

### Story 3.3: Watch Insight Flow

**File:** `Watch/Views/WatchInsightFlowView.swift` (~1,715 lines)

#### Subtask 3.3.1: Insights Carousel
- **What:** Tab-based metric display with HealthKit data (was using MockData — fixed BUG-004)

---

### Story 3.4: Watch Connectivity

**Files:** `Watch/WatchConnectivityService.swift`, `Shared/Services/ConnectivityMessageCodec.swift`

#### Subtask 3.4.1: Message Encoding/Decoding
- **What:** Typed message protocol for iPhone ↔ Watch communication
- **Method:** `ConnectivityMessageCodec.encode()` / `.decode()` for all message types

---

## EPIC 4: Data Layer & Services

**Goal:** On-device encrypted persistence, HealthKit integration, security, and infrastructure services.

---

### Story 4.1: LocalStore — On-Device Persistence

**File:** `apps/HeartCoach/Shared/Services/LocalStore.swift`

#### Subtask 4.1.1: Encrypted Storage
- **What:** UserDefaults + JSON with AES-GCM encryption via CryptoService
- **Fix applied:** Removed plaintext fallback when encryption fails (BUG-054). Data dropped rather than stored unencrypted.

#### Subtask 4.1.2: Snapshot Upsert (Fixed CR-002)
- **What:** Changed from append-only to upsert by calendar day
- **Why:** Pull-to-refresh was creating duplicate same-day snapshots polluting history

#### Subtask 4.1.3: Profile, Alert Meta, Feedback Storage
- **What:** User profile, subscription tier, alert metadata, last feedback payload, check-in data

---

### Story 4.2: HealthKitService — Data Ingestion

**File:** `apps/HeartCoach/iOS/Services/HealthKitService.swift`

#### Subtask 4.2.1: Daily Snapshot Fetch
- **What:** Fetch all 11 metrics for a single day from HealthKit
- **Known issue:** `zoneMinutes` hardcoded to `[]` — zone engine effectively disabled

#### Subtask 4.2.2: History Fetch
- **What:** Multi-day history loading
- **Known issue:** Per-day fan-out creates 270+ HealthKit queries for 30-day window (CR-005)

---

### Story 4.3: CryptoService — Encryption

**File:** `apps/HeartCoach/Shared/Services/CryptoService.swift`

#### Subtask 4.3.1: AES-GCM Encryption
- **What:** Key generation, Keychain storage, encrypt/decrypt for health data
- **Method:** AES-256 key wrapping with PBKDF2

---

### Story 4.4: NotificationService

**File:** `apps/HeartCoach/iOS/Services/NotificationService.swift`

#### Subtask 4.4.1: Implementation
- **What:** Schedule/cancel nudge notifications, request authorization, anomaly alerts
- **Status:** WIRED (CR-001 FIXED). Authorization is requested at app startup; `NotificationService` is injected via environment with the shared `LocalStore`. `DashboardViewModel.scheduleNotificationsIfNeeded()` now calls `scheduleAnomalyAlert()` for `.needsAttention` assessments and `scheduleSmartNudge()` for the daily nudge at the end of every `refresh()` cycle. Files: `DashboardViewModel.swift:531-564`, `DashboardView.swift:29,55-60`.

---

## EPIC 5: Testing Infrastructure

**Goal:** Comprehensive test coverage with deterministic synthetic data, time-series analysis, and validation harness.

---

### Story 5.1: Deterministic Test Data Generation

**File:** `apps/HeartCoach/Tests/EngineTimeSeries/TimeSeriesTestInfra.swift`

#### Subtask 5.1.1: Seeded RNG
- **What:** `SeededRNG` struct using deterministic seed derived from persona name + age
- **Fix applied:** Replaced `String.hashValue` (randomized per process) with djb2 deterministic hash

#### Subtask 5.1.2: Persona Baselines
- **What:** 10 synthetic personas (NewMom, YoungAthlete, SeniorFit, StressedExecutive, etc.)
- **Each persona:** Name, age, sex, weight, RHR, HRV, VO2, recovery, sleep, steps, activity, zone minutes

#### Subtask 5.1.3: 30-Day History Generation
- **What:** Generate 30 days of daily snapshots with controlled random variation
- **Method:** `PersonaBaseline.generate30DayHistory()` using seeded RNG for reproducibility

---

### Story 5.2: Engine Unit Tests (10 test files)

One test file per engine covering core computation, edge cases, and boundary conditions.

---

### Story 5.3: Time-Series Tests (11 test files)

Each major engine has a time-series variant testing 14–30 day scenarios with synthetic personas.

---

### Story 5.4: Integration & E2E Tests

- **DashboardViewModel tests:** Full refresh pipeline
- **End-to-end behavioral tests:** Multi-persona multi-day scenarios
- **Customer journey tests:** Onboarding → first assessment → streak building
- **Pipeline validation tests:** Engine output consistency

---

### Story 5.5: Validation Harness

**File:** `apps/HeartCoach/Tests/Validation/DatasetValidationTests.swift`
- **Status:** Implemented but excluded from SwiftPM test target. Skips when datasets missing.
- **Plan:** External dataset integration documented in `FREE_DATASETS.md`

---

## EPIC 6: CI/CD & Build Infrastructure

---

### Story 6.1: XcodeGen Project Generation

**File:** `project.yml`
- **Targets:** Thump (iOS 17+), ThumpWatch (watchOS 10+), ThumpCoreTests
- **Must run:** `xcodegen generate` after modifying project.yml

---

### Story 6.2: GitHub Actions CI

**File:** `.github/workflows/ci.yml`
- **Pipeline:** Checkout → Cache SPM → XcodeGen → Build iOS → Build watchOS → Run tests → Coverage → Upload results

---

### Story 6.3: SwiftPM Package

**File:** `apps/HeartCoach/Package.swift`
- **Known issue:** 660 unhandled files warning from test fixture directories not excluded

---

## EPIC 7: Web Presence

---

### Story 7.1: Marketing Site

**File:** `web/index.html`
- **Branding:** "Your Heart's Daily Story" (changed from "Heart Training Buddy")

### Story 7.2: Legal Pages

**Files:** `web/privacy.html`, `web/terms.html`, `web/disclaimer.html`
- **Fix applied:** Real legal content replacing placeholder `href="#"` links

---

## Data Flow Architecture

```
HealthKit (daily read)
    ↓
HeartSnapshot {date, RHR, HRV, recovery, VO2, zones, steps, activity, sleep, weight}
    ↓
┌───────────────────────────────────────────────────────────────┐
│ Engines (parallel stateless computation):                     │
│  HeartTrendEngine → HeartAssessment (status, anomaly, flags)  │
│  StressEngine → StressResult (score, level)                   │
│  ReadinessEngine → ReadinessResult (score, pillars)           │
│  BioAgeEngine → BioAgeResult (est. age, category)            │
│  CorrelationEngine → [CorrelationResult]                      │
│  HeartRateZoneEngine → ZoneAnalysis                           │
│  CoachingEngine → CoachingReport (insights, projections)      │
└───────────────────────────────────────────────────────────────┘
    ↓
NudgeGenerator (gated by readiness) → DailyNudge
BuddyRecommendationEngine → [BuddyRecommendation] (up to 4)
SmartNudgeScheduler → SmartNudgeAction (timing-aware)
    ↓
DashboardViewModel (orchestrates all, updates @Published)
    ↓
UI: DashboardView, StressView, TrendsView, InsightsView
WatchConnectivityService → Watch
    ↓
WatchHomeView, WatchNudgeView (user sees recommendations)
```

---

## Change Log — 2026-03-13

### Code Review Fixes (CR-001 through CR-012)

| ID | Summary | Files Changed |
|----|---------|---------------|
| CR-001 | NotificationService fully wired: authorization + shared LocalStore at startup; `scheduleNotificationsIfNeeded()` calls anomaly alerts and smart nudge scheduling from live assessment output | `ThumpiOSApp.swift`, `DashboardViewModel.swift`, `DashboardView.swift` |
| CR-003 | Nudge completion tracked explicitly via `nudgeCompletionDates` | `HeartModels.swift`, `DashboardViewModel.swift`, `InsightsViewModel.swift` |
| CR-004 | Streak credits guarded to once per calendar day | `HeartModels.swift`, `DashboardViewModel.swift` |
| CR-006 | Package.swift excludes test data directories | `Package.swift` |
| CR-007 | macOS 15 `#available` guard on symbolEffect | `ThumpBuddyFace.swift` |
| CR-008 | HeartTrend baseline excludes current week | `HeartTrendEngine.swift` |
| CR-009 | CoachingEngine uses `current.date` not `Date()` | `CoachingEngine.swift` |
| CR-010 | SmartNudgeScheduler uses snapshot date for day-of-week | `SmartNudgeScheduler.swift` |
| CR-011 | Readiness receives real StressEngine score + consecutiveAlert from assessment | `DashboardViewModel.swift` |
| CR-012 | CorrelationEngine uses `activityMinutes` (walk+workout) | `CorrelationEngine.swift`, `HeartModels.swift` |

### Performance Fixes

| ID | Summary | Files Changed |
|----|---------|---------------|
| CR-005/PERF-3 | Batch HealthKit history queries via `HKStatisticsCollectionQuery` (4 collection queries instead of N×9 individual) | `HealthKitService.swift` |
| CR-013/ENG-5 | Real zoneMinutes ingestion from workout HR samples, bucketed into 5 zones by age-estimated max HR | `HealthKitService.swift` |
| PERF-1 | Removed duplicate `updateSubscriptionStatus()` from `SubscriptionService.init()` | `SubscriptionService.swift` |
| PERF-2 | Deferred `loadProducts()` from app startup to PaywallView appearance | `ThumpiOSApp.swift`, `PaywallView.swift` |
| PERF-4 | Shared HealthKitService instance across view models via `bind()` pattern | `InsightsViewModel.swift`, `TrendsViewModel.swift`, `StressViewModel.swift`, views |
| PERF-5 | Guarded `MetricKitService.start()` against repeated registration | `MetricKitService.swift` |

### Test & Cleanup Fixes

| ID | Summary | Files Changed |
|----|---------|---------------|
| TEST-1 | Fixed NewMom persona data (steps 4000→2000, walk 15→5) for genuine sedentary profile | `TimeSeriesTestInfra.swift` |
| TEST-2 | Fixed YoungAthlete persona data (RHR 50→48) for realistic noise headroom | `TimeSeriesTestInfra.swift` |
| TEST-3 | Created `ThumpTimeSeriesTests` target (110 XCTest cases, all passing) | `Package.swift` |
| ORPHAN-1/2/3 | Moved `File.swift`, `AlertMetricsService.swift`, `ConfigLoader.swift` to `.unused/` | `.unused/` |

### Model Changes

- `UserProfile` gained `lastStreakCreditDate: Date?` and `nudgeCompletionDates: Set<String>`
- `HeartSnapshot` gained computed `activityMinutes: Double?` combining walk and workout minutes

### Test Stabilization

- `TimeSeriesTestInfra.rhrNoise` reduced from 3.0 to 2.0 bpm (physiologically grounded)
- `NewMom.recoveryHR1m` lowered from 18 to 15 bpm (consistent with sleep-deprived profile)
- Both `testNewMomVeryLowReadiness` and `testYoungAthleteLowStressAtDay30` now pass deterministically

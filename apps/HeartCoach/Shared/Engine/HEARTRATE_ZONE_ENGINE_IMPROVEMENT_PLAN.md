# HeartRateZoneEngine — Improvement Plan

Date: 2026-03-13
Engine: `HeartRateZoneEngine`
Branch: `feature/improve-stress-engine` (zone work is independent)
Status: Planning

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Competitive Landscape](#2-competitive-landscape)
3. [Identified Improvements](#3-identified-improvements)
4. [Datasets — Synthetic & Real-World](#4-datasets--synthetic--real-world)
5. [Implementation Plan](#5-implementation-plan)
6. [Testing & Validation Strategy](#6-testing--validation-strategy)
7. [Before/After Comparison Framework](#7-beforeafter-comparison-framework)
8. [Risk & Rollback](#8-risk--rollback)

---

## 1. Current State Assessment

### What the engine does today

- 5-zone model using **Karvonen formula** (Heart Rate Reserve)
- Max HR via **Tanaka formula**: `208 - 0.7 × age` (good choice over 220-age)
- Zone boundaries: 50-60%, 60-70%, 70-80%, 80-90%, 90-100% of HRR
- Daily zone distribution analysis against fitness-level targets
- Weekly AHA guideline compliance (150 min moderate / 75 min vigorous)
- Coaching messages and recommendations (5 types)
- Fitness level inference from VO2 Max

### Known bugs

| ID | Bug | Severity | File:Line |
|----|-----|----------|-----------|
| ZE-001 | `weeklyZoneSummary` uses `Date()` instead of snapshot date — breaks deterministic testing, same pattern already fixed in CoachingEngine (ENG-1) | Medium | `HeartRateZoneEngine.swift:281` |
| ZE-002 | `estimateMaxHR` ignores `sex` parameter — code is identical for all sexes despite Gulati formula (206 - 0.88×age) being documented for women | Medium | `HeartRateZoneEngine.swift:82-89` |

### Current test coverage

- **ZoneEngineTimeSeriesTests** — 20 personas at all checkpoints, edge cases (age 0, 120)
- **PersonaAlgorithmTests** — 5-zone structural validation, athlete vs senior comparison
- **EngineKPIValidationTests** — Zone computation, analysis, empty/extreme edge cases
- **EndToEndBehavioralTests** — Athlete vs sedentary zone scores in full pipeline
- **DashboardTextVarianceTests** — Zone coaching text generation

### Current data flow

```
HealthKit → HeartSnapshot.zoneMinutes [5 doubles]
                ↓
    ┌───────────┼────────────────┐
    ↓           ↓                ↓
DashboardVM  CoachingEngine  NudgeGenerator
    ↓           ↓                ↓
analyzeZone  weeklyZone     analyzeZone
Distribution Summary       Distribution
    ↓           ↓                ↓
DashboardView CoachingReport  DailyNudge
```

---

## 2. Competitive Landscape

### How competitors handle HR zones

| Feature | Apple Watch | Whoop | Garmin | Polar | Fitbit | Oura | **Thump (current)** |
|---------|-------------|-------|--------|-------|--------|------|---------------------|
| Zone count | 5 | 5 | 5 | 5 | 3 (AZM) | 6 | 5 |
| Formula | Karvonen (HRR) | Karvonen (HRR) | %HRmax, HRR, or LTHR | %HRmax or HRR | Karvonen (HRR) | %HRmax | Karvonen (HRR) |
| Max HR | 220-age | Age-based | 220-age + auto-detect | 220-age | 220-age | 220-age | Tanaka (208-0.7×age) |
| Sex-specific | No | No | No | No | No | No | **No (bug)** |
| Auto-detect max HR | No | No | **Yes** | No | No | No | No |
| Per-session calibration | No | No | No | **Yes (OwnZone)** | No | No | No |
| Observed HR learning | Monthly RHR update | 14-day rolling RHR | Continuous | No | Continuous RHR | No | No |
| Zone progression tracking | No | Yes (strain) | Yes | Yes | Yes (AZM) | No | No |
| Recovery-gated targets | No | **Yes** | Training status | No | No | Readiness | No |
| Load/strain metric | No | **Strain (0-21)** | Training Load | Training Load | AZM | No | No |

### Key competitive gaps in Thump

1. **No sex-specific max HR** — even basic competitors use 220-age; we have Tanaka but don't apply Gulati for women
2. **No auto-detection of actual max HR** — Garmin's killer feature; we rely entirely on formula
3. **No zone progression tracking** — "you spent 20% more time in zone 3 this week vs last"
4. **No training load / strain metric** — Whoop's core differentiator
5. **No recovery-gated zone targets** — ReadinessEngine exists but doesn't inform zone targets
6. **Static zone targets per fitness level** — don't adapt as user improves

### Thump's existing advantages

1. **Tanaka formula** is more accurate than competitors' 220-age (already ahead)
2. **ReadinessEngine integration** is partially built (just needs wiring to zones)
3. **AHA compliance tracking** already implemented (Fitbit-level feature)
4. **5-pillar coaching messages** with contextual recommendations

---

## 3. Identified Improvements

### Priority 1 — Bug fixes (must-do)

#### ZE-001: Fix `weeklyZoneSummary` to use snapshot dates instead of `Date()`

**Problem**: Line 281 uses `Date()` for "today", making the function non-deterministic and untestable with historical data.

**Fix**: Accept an optional `referenceDate` parameter, default to latest snapshot date.

```swift
// Before
let today = calendar.startOfDay(for: Date())

// After
let refDate = referenceDate ?? history.last?.date ?? Date()
let today = calendar.startOfDay(for: refDate)
```

**Impact**: Test determinism, replay correctness. Same pattern fixed as ENG-1 in CoachingEngine.

#### ZE-002: Implement sex-specific max HR with Gulati formula

**Problem**: `estimateMaxHR` has the `sex` parameter but returns identical values for all sexes.

**Fix**: Apply Gulati formula for women (206 - 0.88 × age), Tanaka for men, averaged for notSet.

```swift
// Before
let base = 208.0 - 0.7 * Double(age)
return max(base, 150)

// After
let base: Double = switch sex {
case .female: 206.0 - 0.88 * Double(age)  // Gulati et al. 2010, n=5,437
case .male:   208.0 - 0.7 * Double(age)   // Tanaka et al. 2001, n=18,712
case .notSet: (208.0 - 0.7 * Double(age) + 206.0 - 0.88 * Double(age)) / 2.0
}
return max(base, 150)
```

**Research basis**: Gulati formula derived from n=5,437 asymptomatic women in the St. James Women Take Heart Project. At age 40: Tanaka=180, Gulati=170.8 — a 9 bpm difference that shifts all zone boundaries.

### Priority 2 — High-impact features

#### ZE-003: Add CorrelationEngine sleep↔RHR pair

**Problem**: CorrelationEngine has 4 factor pairs but misses sleep↔RHR — one of the most well-documented relationships in cardiovascular physiology.

**Fix**: Add a 5th correlation pair in `CorrelationEngine.analyze()`.

```swift
// 5. Sleep Hours vs Resting Heart Rate
let sleepRHR = pairedValues(
    history: history,
    xKeyPath: \.sleepHours,
    yKeyPath: \.restingHeartRate
)
if sleepRHR.x.count >= minimumPoints {
    let r = pearsonCorrelation(x: sleepRHR.x, y: sleepRHR.y)
    let result = interpretCorrelation(
        factor: "Sleep Hours",
        metric: "resting heart rate",
        r: r,
        expectedDirection: .negative  // more sleep → lower RHR
    )
    results.append(CorrelationResult(
        factorName: "Sleep Hours",
        correlationStrength: r,
        interpretation: result.interpretation,
        confidence: result.confidence,
        isBeneficial: result.isBeneficial
    ))
}
```

**Also needed**: Add interpretation templates in `beneficialInterpretation` and `friendlyFactor`/`friendlyMetric`.

**Research basis**: Meta-analysis by Tobaldini et al. (2019) — short sleep duration is associated with elevated RHR (pooled effect: +2-5 bpm per hour of sleep deficit). Cappuccio et al. (2010) — sleep duration <6h associated with 48% increased risk of cardiovascular events.

#### ZE-004: Observed max HR detection from workout data

**Problem**: All max HR formulas have ±10-12 bpm standard error. A 40-year-old predicted at 180 bpm could actually be 168 or 192. This makes all zone boundaries wrong.

**Fix**: Track observed peak HR from workouts and use the highest observed value (with decay) as actual max HR.

```swift
public struct ObservedMaxHR: Codable, Sendable {
    public let value: Double          // Highest observed HR
    public let observedDate: Date     // When it was observed
    public let workoutType: String    // What workout produced it
    public let confidence: ObservedHRConfidence
}

public enum ObservedHRConfidence: String, Codable, Sendable {
    case high       // Observed during maximal effort (RPE 9-10)
    case moderate   // Observed during hard effort (RPE 7-8)
    case estimated  // Formula-based fallback
}
```

**Algorithm**:
1. Scan HealthKit workout HR samples for peak values
2. Apply 95th percentile filter (discard single-sample spikes — likely noise)
3. Use highest value from last 6 months if available
4. Fall back to Tanaka/Gulati formula if no workout data
5. Age-decay: reduce observed max by 0.5 bpm per year since observation

**Competitive position**: Matches Garmin's auto-detect, which is the single most impactful zone accuracy feature in the market.

#### ZE-005: Zone progression tracking (week-over-week)

**Problem**: No way to see "am I spending more time in aerobic zones over time?"

**Fix**: Add `zoneProgressionTrend` method comparing this week vs last week per zone.

```swift
public struct ZoneProgression: Codable, Sendable {
    public let zone: HeartRateZoneType
    public let thisWeekMinutes: Double
    public let lastWeekMinutes: Double
    public let changePercent: Double      // +20% = 20% more time
    public let direction: ProgressionDirection
}

public enum ProgressionDirection: String, Codable, Sendable {
    case increasing
    case stable
    case decreasing
}
```

**UI integration**: Feed into CoachingEngine insights ("You spent 25% more time in zone 3 this week — that's where your heart gets the most benefit").

### Priority 3 — Differentiation features

#### ZE-006: Recovery-gated zone targets

**Problem**: Zone targets are static per fitness level. If readiness is low (recovering), the same targets apply — pushing the user to hit zone 4/5 when their body needs rest.

**Fix**: Scale zone targets down when readiness is low.

```swift
public func adaptedTargets(
    for fitnessLevel: FitnessLevel,
    readinessScore: Int?
) -> [Double] {
    let baseTargets = dailyTargets(for: fitnessLevel)
    guard let readiness = readinessScore else { return baseTargets }

    // Recovering (<40): suppress zone 4-5 entirely, halve zone 3
    // Moderate (40-59): reduce zone 4-5 by 50%, zone 3 by 25%
    // Ready/Primed (60+): use base targets
    let multiplier: [Double] = switch readiness {
    case 0..<40:  [1.0, 1.0, 0.5, 0.0, 0.0]   // rest day
    case 40..<60: [1.0, 1.0, 0.75, 0.5, 0.25]  // easy day
    default:      [1.0, 1.0, 1.0, 1.0, 1.0]    // normal
    }
    return zip(baseTargets, multiplier).map { $0 * $1 }
}
```

**Competitive position**: Only Whoop does this (strain targets adapt to recovery). Would make Thump the second consumer app with this feature.

#### ZE-007: Training load metric (simplified strain)

**Problem**: No aggregate measure of training stress over time. Users can't tell if they're overreaching or undertraining across days/weeks.

**Fix**: Implement a simplified Training Impulse (TRIMP) score.

```swift
public struct DailyTrainingLoad: Codable, Sendable {
    public let date: Date
    public let score: Double          // 0-300+ (logarithmic)
    public let level: TrainingLoadLevel
    public let zoneContributions: [Double]  // per-zone contribution
}

public enum TrainingLoadLevel: String, Codable, Sendable {
    case rest       // 0-25
    case light      // 25-75
    case moderate   // 75-150
    case hard       // 150-250
    case maximal    // 250+
}
```

**Algorithm** (Banister TRIMP, simplified):
```
TRIMP = Σ (zone_minutes[i] × zone_weight[i])
zone_weights = [1.0, 1.5, 2.5, 4.0, 6.5]  // exponential by zone
```

This is the same principle behind Whoop Strain (logarithmic zone weighting) but simpler to implement and explain.

**Rolling metrics**:
- 7-day acute load
- 28-day chronic load
- Acute:Chronic ratio (injury risk when >1.5, undertrained when <0.8)

---

## 4. Datasets — Synthetic & Real-World

### Synthetic test data (already available)

**Source**: `SyntheticPersonaProfiles.swift` — 20 personas

| Persona | Age | Sex | RHR | Zone Minutes [Z1-Z5] | Fitness |
|---------|-----|-----|-----|----------------------|---------|
| Young Athlete | 24 | M | 52 | [15,20,25,15,8] | Athletic |
| Obese Sedentary | 42 | M | 85 | [3,2,0,0,0] | Beginner |
| Active Senior | 68 | F | 62 | [20,15,10,3,0] | Moderate |
| Pregnant Runner | 32 | F | 72 | [25,20,10,0,0] | Active→Moderate |
| Teen Athlete | 16 | M | 55 | [10,15,20,15,10] | Athletic |
| Anxious Professional | 35 | M | 78 | [10,5,3,0,0] | Beginner |
| Postmenopausal Walker | 58 | F | 70 | [30,20,5,0,0] | Moderate |
| ... (13 more) | | | | | |

**Gaps in synthetic data**:
- No personas with **known actual max HR** (for auto-detect validation)
- No personas with **multi-week progression** data (for zone trend validation)
- No personas representing **medication effects** (beta-blockers cap HR)

### New synthetic personas needed

```swift
// ZE-specific test personas to add to SyntheticPersonaProfiles.swift

// 1. Known max HR persona (for auto-detect validation)
// Actual max HR = 195, formula predicts 180 (Tanaka, age 40)
// Zone boundaries should shift significantly when observed HR is used
static let knownMaxHRAthlete = PersonaProfile(
    name: "Known Max HR Athlete",
    age: 40, sex: .male, rhr: 55,
    observedMaxHR: 195,  // from recent race
    formulaMaxHR: 180,   // Tanaka prediction
    zoneMinutes: [10, 15, 25, 15, 8]
)

// 2. Beta-blocker user (HR capped, zones must adjust)
static let betaBlockerUser = PersonaProfile(
    name: "Beta-Blocker User",
    age: 55, sex: .male, rhr: 58,
    maxHRCap: 140,  // medication-limited
    zoneMinutes: [30, 20, 10, 0, 0]
)

// 3. Multi-week progressor (for zone trend validation)
// Week 1: mostly zone 1-2, Week 4: more zone 3-4
static let progressingBeginner = PersonaProfile(
    name: "Progressing Beginner",
    age: 45, sex: .female, rhr: 75,
    weeklyZoneProgression: [
        [40, 15, 5, 0, 0],   // Week 1
        [35, 20, 8, 2, 0],   // Week 2
        [30, 22, 12, 3, 0],  // Week 3
        [25, 25, 18, 5, 1],  // Week 4
    ]
)

// 4. Gulati vs Tanaka edge case (max age difference)
// At age 60: Tanaka=166, Gulati=153.2 — 13 bpm gap
static let olderFemaleRunner = PersonaProfile(
    name: "Older Female Runner",
    age: 60, sex: .female, rhr: 58,
    tanakaMaxHR: 166,
    gulatiMaxHR: 153.2,
    zoneMinutes: [15, 20, 20, 8, 2]
)
```

### Real-world datasets for validation

#### Available now (no download needed)

| Dataset | What it provides | Use for |
|---------|-----------------|---------|
| **HealthKit sample data** | Real zone minutes from Apple Watch users | Zone distribution validation |
| **MockData.swift** | In-app mock snapshots with zone data | Baseline comparison |

#### Publicly available datasets

| Dataset | Source | Size | Contains | Use for | License |
|---------|--------|------|----------|---------|---------|
| **HUNT Fitness Study** | NTNU Norway | n=3,320 | Age, sex, measured HRmax, RHR, VO2max | Max HR formula validation (Tanaka vs Gulati vs HUNT) | Request access |
| **Cleveland Clinic Exercise ECG** | PhysioNet | n=1,677 | Peak HR during stress test, age, sex | Observed vs formula max HR comparison | PhysioNet Open |
| **Framingham Heart Study** | NHLBI | n=5,209 | RHR, age, sex, cardiovascular outcomes | RHR-zone outcome validation | Application required |
| **UK Biobank Accelerometry** | UK Biobank | n=103,684 | Activity minutes by intensity, HR, demographics | Zone distribution population norms | Application required |
| **NHANES Physical Activity** | CDC | n=~10,000/cycle | Self-reported + accelerometer activity data | AHA guideline compliance benchmarking | Public domain |
| **PhysioNet MIMIC-III** | PhysioNet | n=53,423 | HR recordings, demographics | HR variability and max HR patterns | PhysioNet credentialed |

#### Recommended validation approach

**Tier 1 — Immediate (synthetic)**:
- Use existing 20 personas + 4 new zone-specific personas
- Validate zone boundary math, sex-specific formulas, edge cases
- Run all existing zone tests as baseline snapshot

**Tier 2 — Short-term (public data)**:
- Download NHANES accelerometry data for AHA compliance benchmarking
- Use Cleveland Clinic exercise ECG for observed vs formula max HR comparison
- Compute: what % of people would have zones shift by >1 zone if actual max HR were used?

**Tier 3 — Medium-term (research partnership)**:
- Apply for HUNT Fitness Study access to validate Tanaka vs Gulati vs HUNT formula
- Cross-reference with UK Biobank for population zone distribution norms

---

## 5. Implementation Plan

### Phase 1 — Bug fixes (ZE-001, ZE-002) + Correlation (ZE-003)

**Estimated scope**: 3 files changed, ~50 lines of code, ~30 lines of tests

#### Step 1.1: Fix `weeklyZoneSummary` date handling (ZE-001)

**File**: `HeartRateZoneEngine.swift`

- Add `referenceDate: Date? = nil` parameter to `weeklyZoneSummary`
- Use `referenceDate ?? history.last?.date ?? Date()` instead of `Date()`
- Update callers: `CoachingEngine.swift` line 86 (pass snapshot date)

**Tests to add**:
- `testWeeklyZoneSummary_usesReferenceDateNotWallClock`
- `testWeeklyZoneSummary_historicalDate_correctWindow`

#### Step 1.2: Implement Gulati formula for women (ZE-002)

**File**: `HeartRateZoneEngine.swift`

- Replace the identical-for-all-sexes block in `estimateMaxHR`
- Apply Gulati (206 - 0.88 × age) for `.female`
- Keep Tanaka (208 - 0.7 × age) for `.male`
- Average both for `.notSet`

**Tests to add**:
- `testEstimateMaxHR_female_usesGulati`
- `testEstimateMaxHR_male_usesTanaka`
- `testEstimateMaxHR_notSet_usesAverage`
- `testZoneBoundaries_female40_lowerThanMale40` (Gulati gives lower max HR → narrower zones)
- `testGulatiVsTanaka_ageProgression` (verify gap widens with age)

**Regression check**: Run all existing zone tests — zone boundaries will shift for female personas. Update expected values in:
- `ZoneEngineTimeSeriesTests`
- `PersonaAlgorithmTests`
- `EngineKPIValidationTests`

#### Step 1.3: Add sleep↔RHR correlation pair (ZE-003)

**File**: `CorrelationEngine.swift`

- Add 5th correlation pair: sleep hours vs resting heart rate
- Expected direction: `.negative` (more sleep → lower RHR)
- Add interpretation templates for "Sleep Hours" + "resting heart rate"

**Tests to add**:
- `testSleepRHR_negativeCorrelation_isBeneficial`
- `testSleepRHR_insufficientData_excluded`
- `testAnalyze_returns5Pairs_withFullData`

### Phase 2 — Observed max HR detection (ZE-004)

**Estimated scope**: 1 new file, 2 modified files, ~150 lines of code, ~80 lines of tests

#### Step 2.1: Add `ObservedMaxHR` model

**File**: `HeartModels.swift`

- Add `ObservedMaxHR` struct
- Add `observedMaxHR: ObservedMaxHR?` to user profile or engine config

#### Step 2.2: Add max HR detection logic

**File**: `HeartRateZoneEngine.swift`

- New method: `detectMaxHR(from workoutSamples: [WorkoutHRSample]) -> ObservedMaxHR?`
- 95th percentile filter for noise rejection
- 6-month recency window with age-decay
- Minimum 3 qualifying workouts before trusting observed value

#### Step 2.3: Wire into `computeZones`

- If `observedMaxHR` is available and confidence is `.high` or `.moderate`, use it
- Otherwise fall back to Tanaka/Gulati
- Log which source was used for transparency

**Tests to add**:
- `testDetectMaxHR_singleWorkout_lowConfidence`
- `testDetectMaxHR_threeHardWorkouts_highConfidence`
- `testDetectMaxHR_spikeRejection_uses95thPercentile`
- `testComputeZones_preferObservedOverFormula`
- `testComputeZones_fallsBackToFormula_whenNoObserved`
- `testObservedMaxHR_ageDecay_reducesOverTime`

### Phase 3 — Zone progression & recovery gating (ZE-005, ZE-006)

**Estimated scope**: 1 modified file, ~120 lines of code, ~60 lines of tests

#### Step 3.1: Zone progression tracking (ZE-005)

**File**: `HeartRateZoneEngine.swift`

- New method: `zoneProgression(thisWeek: [HeartSnapshot], lastWeek: [HeartSnapshot]) -> [ZoneProgression]`
- Per-zone change percentage with direction

#### Step 3.2: Recovery-gated targets (ZE-006)

**File**: `HeartRateZoneEngine.swift`

- New method: `adaptedTargets(for:readinessScore:) -> [Double]`
- Multiplier-based suppression of high-zone targets when readiness is low
- Wire into `analyzeZoneDistribution` via optional `readinessScore` parameter

**Tests to add**:
- `testZoneProgression_increasingAerobic_detected`
- `testZoneProgression_stableWeeks_noChange`
- `testAdaptedTargets_recovering_suppressesHighZones`
- `testAdaptedTargets_primed_noChange`
- `testAnalysis_withLowReadiness_lowerScoreThresholds`

### Phase 4 — Training load metric (ZE-007)

**Estimated scope**: ~100 lines of code, ~50 lines of tests

#### Step 4.1: Implement TRIMP-based daily training load

**File**: `HeartRateZoneEngine.swift`

- New method: `computeDailyLoad(zoneMinutes: [Double]) -> DailyTrainingLoad`
- Zone weights: `[1.0, 1.5, 2.5, 4.0, 6.5]` (exponential by zone)
- Level classification based on score

#### Step 4.2: Rolling load metrics

- 7-day acute load (sum of daily TRIMP)
- 28-day chronic load (average daily TRIMP)
- Acute:Chronic Work Ratio (ACWR)

**Tests to add**:
- `testDailyLoad_restDay_lightLevel`
- `testDailyLoad_heavyIntervals_hardLevel`
- `testACWR_steadyTraining_nearOne`
- `testACWR_suddenSpike_aboveThreshold`
- `testACWR_detraining_belowThreshold`

---

## 6. Testing & Validation Strategy

### Test pyramid

```
                    ┌────────────┐
                    │  External  │  Tier 3: HUNT/Cleveland Clinic
                    │  Dataset   │  max HR formula validation
                    │ Validation │
                    ├────────────┤
                 ┌──┤ Integration│  Tier 2: End-to-end pipeline
                 │  │   Tests    │  Zone → Coaching → Nudge → UI
                 │  ├────────────┤
              ┌──┤  │  Persona   │  Tier 1b: 24 synthetic personas
              │  │  │   Tests    │  (20 existing + 4 new zone-specific)
              │  │  ├────────────┤
           ┌──┤  │  │   Unit     │  Tier 1a: Formula math, edge cases,
           │  │  │  │   Tests    │  boundary validation, determinism
           │  │  │  └────────────┘
```

### Baseline snapshot (take before any changes)

Run the following and save output as `Tests/Validation/zone_engine_baseline.json`:

```bash
cd apps/HeartCoach
swift test --filter ZoneEngineTimeSeriesTests 2>&1 | tee /tmp/zone-baseline.log
swift test --filter PersonaAlgorithmTests 2>&1 | tee -a /tmp/zone-baseline.log
swift test --filter EngineKPIValidationTests 2>&1 | tee -a /tmp/zone-baseline.log
```

Capture per-persona:
- Max HR (formula-based)
- Zone boundaries [Z1-Z5 lower/upper bpm]
- Zone analysis score
- Zone analysis recommendation
- Weekly AHA completion %

### Validation criteria per improvement

| Improvement | Pass criteria | Regression gate |
|-------------|--------------|-----------------|
| ZE-001 (date fix) | `weeklyZoneSummary` returns identical results for same snapshot data regardless of wall-clock time | All existing zone tests pass unchanged |
| ZE-002 (Gulati) | Female max HR < male max HR at same age; gap increases with age; all personas recalculated correctly | Zone tests for male/notSet personas unchanged |
| ZE-003 (sleep↔RHR) | Returns 5th correlation when data available; r is negative for good sleepers; excluded when <7 data points | All 4 existing correlation tests pass unchanged |
| ZE-004 (observed HR) | Observed HR used when 3+ qualifying workouts; formula used as fallback; zones shift correctly | All formula-based zone tests still pass when no observed data |
| ZE-005 (progression) | Correctly detects increasing/decreasing/stable zone trends across weeks | No regression — new feature |
| ZE-006 (recovery gate) | Zone 4-5 targets suppressed when readiness <40; normal when readiness ≥60 | `analyzeZoneDistribution` without readiness param behaves identically |
| ZE-007 (training load) | TRIMP score monotonically increases with zone intensity; ACWR near 1.0 for steady training | No regression — new feature |

### Comparison metrics (before vs after)

For each persona, capture and diff:

```
┌─────────────────────────────────────────────────────┐
│ Persona: Older Female Runner (age 60, F, RHR 58)    │
├──────────────┬──────────────┬────────────────────────┤
│ Metric       │ Before       │ After                  │
├──────────────┼──────────────┼────────────────────────┤
│ Max HR       │ 166 (Tanaka) │ 153 (Gulati)           │
│ HRR          │ 108          │ 95                     │
│ Zone 1 range │ 112-123 bpm  │ 106-115 bpm            │
│ Zone 2 range │ 123-134 bpm  │ 115-125 bpm            │
│ Zone 3 range │ 134-144 bpm  │ 125-135 bpm            │
│ Zone 4 range │ 144-155 bpm  │ 135-144 bpm            │
│ Zone 5 range │ 155-166 bpm  │ 144-153 bpm            │
│ Analysis score │ 72          │ 78 (same zone min      │
│              │              │ now "harder" = better)  │
│ AHA %        │ 85%          │ 92% (more minutes       │
│              │              │ now count as moderate+)  │
└──────────────┴──────────────┴────────────────────────┘
```

---

## 7. Before/After Comparison Framework

### Automated comparison test

Add a dedicated comparison test that runs against all personas and outputs a structured report:

```swift
// Tests/ZoneEngineComparisonTests.swift

final class ZoneEngineComparisonTests: XCTestCase {

    /// Captures zone computation results for before/after diffing.
    struct ZoneSnapshot: Codable {
        let persona: String
        let maxHR: Double
        let zones: [(lower: Int, upper: Int)]
        let analysisScore: Int
        let recommendation: String?
        let ahaCompletion: Double
    }

    func testCaptureAllPersonaSnapshots() throws {
        let engine = HeartRateZoneEngine()
        var results: [ZoneSnapshot] = []

        for persona in SyntheticPersonaProfiles.allPersonas {
            let zones = engine.computeZones(
                age: persona.age,
                restingHR: persona.rhr,
                sex: persona.sex
            )
            let analysis = engine.analyzeZoneDistribution(
                zoneMinutes: persona.zoneMinutes,
                fitnessLevel: FitnessLevel.infer(
                    vo2Max: persona.vo2Max, age: persona.age
                )
            )
            results.append(ZoneSnapshot(
                persona: persona.name,
                maxHR: estimateMaxHR(age: persona.age, sex: persona.sex),
                zones: zones.map { ($0.lowerBPM, $0.upperBPM) },
                analysisScore: analysis.overallScore,
                recommendation: analysis.recommendation?.rawValue,
                ahaCompletion: /* from weekly summary */
            ))
        }

        // Write to JSON for diffing
        let data = try JSONEncoder().encode(results)
        let path = "Tests/Validation/zone_engine_snapshot.json"
        try data.write(to: URL(fileURLWithPath: path))
    }
}
```

### Manual comparison checklist

After each phase, verify:

- [ ] All existing zone tests pass (zero regressions)
- [ ] New tests pass
- [ ] Female persona zone boundaries shifted (Phase 1)
- [ ] Male persona zone boundaries unchanged (Phase 1)
- [ ] Observed max HR overrides formula when available (Phase 2)
- [ ] Zone progression detects weekly changes (Phase 3)
- [ ] Recovery-gated targets suppress high zones when readiness is low (Phase 3)
- [ ] Training load increases monotonically with intensity (Phase 4)
- [ ] ACWR flags overtraining risk (Phase 4)

---

## 8. Risk & Rollback

### Risk assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Gulati formula shifts zones too aggressively for female users | Medium | Medium | Show "formula changed" explanation in UI; allow manual override |
| Observed max HR from noisy HR sensor creates wrong zones | Medium | High | 95th percentile filter + minimum 3 qualifying workouts |
| Recovery-gated targets frustrate high-readiness users who see lower goals | Low | Low | Only suppress zones 4-5 when readiness <40; don't affect primed users |
| Training load metric feels overwhelming for casual users | Medium | Low | Only show in Coach/Family tier; hide from Free tier |
| Existing test expected values break after Gulati change | High | Low | Expected — update test values as part of Phase 1 |

### Rollback plan

Each phase is independently revertible:

- **Phase 1**: Revert `estimateMaxHR` to return identical values for all sexes
- **Phase 2**: `computeZones` falls back to formula when no observed data — just remove the observed path
- **Phase 3**: New methods only — removing them has zero impact on existing functionality
- **Phase 4**: New methods only — completely additive

### Feature flags (via ConfigService)

```swift
extension ConfigService {
    /// Use sex-specific max HR formula (Gulati for women).
    static var useSexSpecificMaxHR: Bool { true }

    /// Use observed max HR from workouts when available.
    static var useObservedMaxHR: Bool { true }

    /// Gate zone targets by readiness score.
    static var useReadinessGatedZones: Bool { true }

    /// Show training load metric (Coach+ tier only).
    static var showTrainingLoad: Bool { true }
}
```

---

## Appendix: Research References

1. **Tanaka H, Monahan KD, Seals DR.** Age-predicted maximal heart rate revisited. J Am Coll Cardiol. 2001;37(1):153-156. (n=18,712, meta-analysis of 351 studies)
2. **Gulati M, Shaw LJ, et al.** Heart rate response to exercise stress testing in asymptomatic women: the St. James Women Take Heart Project. Circulation. 2010;122(2):130-137. (n=5,437 women)
3. **Nes BM, Janszky I, et al.** Age-predicted maximal heart rate in healthy subjects: The HUNT Fitness Study. Scand J Med Sci Sports. 2013;23(6):697-704. (n=3,320)
4. **Karvonen MJ, Kentala E, Mustala O.** The effects of training on heart rate; a longitudinal study. Ann Med Exp Biol Fenn. 1957;35(3):307-315.
5. **Banister EW.** Modeling elite athletic performance. In: MacDougall JD, Wenger HA, Green HJ, eds. Physiological Testing of the High-Performance Athlete. 1991:403-424. (TRIMP model)
6. **Gabbett TJ.** The training-injury prevention paradox: should athletes be training smarter and harder? Br J Sports Med. 2016;50(5):273-280. (ACWR research)
7. **Tobaldini E, et al.** Short sleep duration and cardiometabolic risk. Nat Rev Cardiol. 2019;16(4):213-224.
8. **Cappuccio FP, et al.** Sleep duration and all-cause mortality: a systematic review and meta-analysis. Sleep. 2010;33(5):585-592.
9. **AHA/ACSM Guidelines.** Physical Activity Guidelines for Americans, 2nd edition. 2018. (150 min/week moderate target)

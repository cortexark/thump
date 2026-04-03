# Competitor Benchmark: Improvement Plan

## Scoreboard

| Dimension | WHOOP | Oura | Thump | Gap | Fix Effort |
|-----------|:-----:|:----:|:-----:|:---:|:----------:|
| Body Temperature | 8 | **9** | 0 | 9 | 2-3 days |
| Respiratory Rate | 8 | 8 | 0 | 8 | 1 day |
| Blood Oxygen (SpO2) | 8 | 7 | 0 | 8 | 1 day |
| Muscular Load | **9** | 2 | 1 | 8 | 3-5 days |
| Sleep Debt & Need | **9** | 7 | 2 | 7 | 3-4 days |
| Sleep Consistency | **8** | 7 | 1 | 7 | 1-2 days |
| Menstrual/Hormonal | 8 | 8 | 1 | 7 | 1-2 weeks |
| Social/Community | **7** | 3 | 0 | 7 | 4-6 weeks |
| Sleep Staging | 9 | **9** | 3 | 6 | 2-3 days |
| AI Coach | **9** | 7 | 3 | 6 | 2-4 weeks |
| Strain Model | **10** | 5 | 4 | 6 | 3-4 days |
| Resilience/CV Age | 6 | **9** | 7 | 2 | 2-3 days |
| **TOTAL** | **91** | **74** | **22** | **-** | **-** |

## Thump's Strengths (what NOT to lose)

1. Bio Age with per-metric breakdown (ahead of WHOOP)
2. 5-zone HR analysis with targets (ahead of Oura)
3. Coaching copy quality (baseline-anchored, hedged)
4. Hourly stress heatmap granularity
5. Context-aware stress engine (acute vs desk)
6. Correlation analysis (activity to metrics)
7. On-device privacy architecture

## P1 Quick Wins: 8-10 days, close 36 gap points

These use data Apple Watch ALREADY writes to HealthKit.

### 1. Sleep Staging (gap 6, effort 2-3 days)
- Read `.asleepCore`, `.asleepDeep`, `.asleepREM`, `.awake` from HealthKit
- Display stacked bar on Dashboard sleep card
- Show stage percentages vs optimal ranges (15-25% deep, 20-25% REM)
- Add to Trends as selectable metric
- Impact: Single biggest perception gap — users expect this from any sleep tracker

### 2. Sleep Consistency (gap 7, effort 1-2 days)
- SmartNudgeScheduler already learns wake patterns per day-of-week
- Surface as "Sleep Regularity" score 0-100 (bedtime/wake variance)
- Show on Trends alongside sleep hours
- Add to Readiness pillar weighting
- Impact: Free data already computed internally

### 3. Respiratory Rate (gap 8, effort 1 day)
- Read `.respiratoryRate` from HealthKit (available Series 3+)
- Add to Trends chart as metric option
- Flag deviations >2 breaths/min above baseline
- Combine with temperature for illness detection
- Impact: Lowest effort, highest gap closure ratio

### 4. Blood Oxygen (gap 8, effort 1 day)
- Read `.oxygenSaturation` from HealthKit (available Series 6+)
- Add to Trends chart as metric option
- Flag sustained drops below 95% with doctor consultation framing
- Impact: Same as respiratory rate — easy read, high value

### 5. Sleep Debt Engine (gap 7, effort 3-4 days)
- Estimate personalized sleep need from 14-day HRV/recovery correlation
- Track rolling 7-day debt (need minus actual)
- Show on Dashboard: "You need X hrs tonight to clear Y hrs of debt"
- Integrate into readiness pillar weighting
- Impact: WHOOP's most-loved sleep feature, no new data needed

## P1 Medium: 5-7 days, close 14 gap points

### 6. Strain Score (gap 6, effort 3-4 days)
- Composite cardiovascular load from existing zone minutes
- Logarithmic 0-20 scale (Borg-inspired)
- Weight higher zones more heavily
- Show on Dashboard as "Today's Effort" alongside Recovery
- Add strain-recovery balance chart on Trends

### 7. Body Temperature (gap 9, effort 2-3 days)
- Read `.appleSleepingWristTemperature` (Series 8+)
- Show deviation from personal baseline
- Illness detection: flag >0.5C above baseline for 2+ nights
- Graceful degradation: hide on older watches
- Add to Readiness pillar

## P2 Strategic: 2-6 weeks

### 8. AI Coach Phase 1 (gap 6, effort 3 days for phase 1)
- Add "Why?" tap on every score card
- Generate plain-language explanation from snapshot data
- Example: "Readiness is 52 because HRV dropped 15ms and sleep was 5.2h"
- No LLM needed — template with dynamic data insertion

### 9. Resilience Score (gap 2, effort 2-3 days)
- Track stress-recovery bounce-back speed over 30-90 days
- "How fast your HRV returns to baseline after stress"
- Show alongside Bio Age as complementary longevity metric

### 10. Menstrual/Hormonal (gap 7, effort 1-2 weeks)
- Read `.menstrualFlow` from HealthKit
- Detect luteal phase via temperature rise
- Adjust readiness expectations during luteal phase
- Show cycle phase on Dashboard for users who log periods

### 11. Muscular Load (gap 8, effort 3-5 days)
- Infer strength load from HKWorkout metadata
- Volume model: workout type x energy burned x duration
- Show alongside cardiovascular zones as "Strength Load"

## P3 Long-term: 4-6 weeks

### 12. Social/Community (gap 7, effort 4-6 weeks)
- Family dashboard for Family tier
- Shared daily scores (anonymized), family streak
- Weekly challenges with opt-in leaderboard
- Needs backend infrastructure

## Projected Scoreboard After P1 (2-3 weeks)

| Dimension | Before | After | Delta |
|-----------|:------:|:-----:|:-----:|
| Sleep Staging | 3 | 8 | +5 |
| Sleep Consistency | 1 | 7 | +6 |
| Respiratory Rate | 0 | 7 | +7 |
| Blood Oxygen | 0 | 7 | +7 |
| Sleep Debt | 2 | 8 | +6 |
| Strain Model | 4 | 8 | +4 |
| Body Temperature | 0 | 7 | +7 |
| **Thump Total** | **22** | **64** | **+42** |

After P1, Thump would score 64/120 — closing within striking distance of Oura (74) and narrowing the WHOOP gap from 69 to 27 points.

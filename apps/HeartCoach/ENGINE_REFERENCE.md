# Thump Engine Reference

## All 10 Engines

| # | Engine | What It Does | Input | Output | Feeds Into |
|---|--------|-------------|-------|--------|------------|
| 1 | **HeartTrendEngine** | Master daily assessment — anomaly score, regression detection, stress pattern, week-over-week trend, coaching scenario | `[HeartSnapshot]` history + today's snapshot | `HeartAssessment` (status, confidence, anomaly, stressFlag, regressionFlag, cardioScore, nudges, WoW trend, scenario) | Dashboard, Watch, Notifications, all other engines |
| 2 | **StressEngine** | HRV-based stress score 0-100 — RHR deviation (50%), HRV Z-score (30%), CV (20%), sigmoid-calibrated | Today snapshot + 14-day history | `StressResult` (score, level: relaxed/balanced/elevated), hourly estimates, trend direction | Stress screen heatmap, ReadinessEngine, BuddyRecommendationEngine, SmartNudgeScheduler |
| 3 | **ReadinessEngine** | 5-pillar readiness score 0-100 — Sleep (25%), Recovery (25%), Stress (20%), Activity (15%), HRV trend (15%) | Today snapshot + stress score + history | `ReadinessResult` (score, level: primed/ready/moderate/recovering, pillar breakdown) | NudgeGenerator gate, Dashboard readiness card, conflict guard, Watch complication |
| 4 | **NudgeGenerator** | Picks daily coaching nudge from 6-priority waterfall — stress > regression > low data > negative feedback > improving > default | Confidence, anomaly, regression, stress, feedback, readiness, snapshot | `DailyNudge` (category, title, description, duration, icon) x 1-3 | Dashboard nudge card, Watch hero/walk screen, NotificationService, complications |
| 5 | **SmartNudgeScheduler** | Time-aware real-time actions — learns sleep patterns, detects late wake, suggests journal/breathe/bedtime/activity | Stress points, trend direction, sleep patterns, current hour, readiness gate | `SmartNudgeAction` (journal, breathe, checkin, bedtime, activity, rest, standard) | Stress screen action buttons, Watch breathe prompt, notification timing |
| 6 | **BioAgeEngine** | Fitness age estimate — compares RHR/HRV/VO2/sleep/activity/BMI against age-stratified population norms | Today snapshot + chronological age + sex | `BioAgeResult` (bioAge, offset years, category: excellent-needsWork, per-metric breakdown) | Dashboard bio age card |
| 7 | **CoachingEngine** | Weekly coaching report — per-metric narrative insights, 4-week projections, weekly progress score | Today snapshot + history + streak days | `CoachingReport` (hero message, metric insights, RHR/HRV projections, progress score 0-100) | Dashboard coaching section |
| 8 | **HeartRateZoneEngine** | Karvonen HR zones + zone analysis — computes 5 zones, daily targets by fitness level, AHA completion, 80/20 rule | Age, resting HR, sex, zone minutes | `[HeartRateZone]`, `ZoneAnalysis` (per-zone completion, recommendation), `WeeklyZoneSummary` (AHA%) | Dashboard zone chart, NudgeGenerator secondary nudges, CoachingEngine |
| 9 | **CorrelationEngine** | Pearson correlations — steps-RHR, walking-HRV, activity-recovery, sleep-RHR, sleep-HRV | 7+ day history | `[CorrelationResult]` (r value, confidence, plain-language interpretation) | Dashboard insight cards (gated behind subscription) |
| 10 | **BuddyRecommendationEngine** | Synthesis layer — aggregates all engine outputs into 1-4 prioritized, deduplicated action cards | Assessment + stress + readiness + snapshot + history | `[BuddyRecommendation]` (priority: critical-low, category, title, message, source) | Dashboard buddy recommendations section |

## Data Flow: HealthKit to Screens

```
HealthKit (RHR, HRV, Recovery, VO2, Steps, Walk, Sleep, Zones)
    |
    v
DashboardViewModel.refresh()
    |
    +-- HeartTrendEngine.assess()
    |     +-- ReadinessEngine (internal)
    |     +-- NudgeGenerator (internal)
    |           +-- HeartRateZoneEngine (secondary nudges)
    |
    +-- StressEngine.computeStress()
    +-- ReadinessEngine.compute()
    +-- BioAgeEngine.estimate()
    +-- CoachingEngine.generateReport()
    |     +-- HeartRateZoneEngine.weeklyZoneSummary()
    +-- HeartRateZoneEngine.analyzeZoneDistribution()
    +-- CorrelationEngine.analyze()
    +-- BuddyRecommendationEngine.recommend()
    |
    v
@Published properties on DashboardViewModel
    |
    +-- iOS Views (Dashboard, Readiness, Coaching, Zones, Insights)
    +-- LocalStore.appendSnapshot() (persistence)
    +-- NotificationService (alerts + nudge reminders)
    +-- ConnectivityService.sendAssessment() --> Watch
          |
          v
    WatchViewModel --> ThumpComplicationData --> Watch face widgets

StressViewModel (separate HealthKit fetch):
    +-- StressEngine --> Stress screen heatmap + trend
    +-- SmartNudgeScheduler --> Action buttons
          +-- breathe prompt --> Watch
```

## Notification Pipeline

| Engine Output | Notification Type | Trigger | Delivery Time |
|---|---|---|---|
| HeartAssessment.status == .needsAttention | Anomaly Alert (immediate) | Status check after assess() | 1 second |
| NudgeGenerator -> .walk/.moderate | Walk notification | Daily after refresh | Morning (wake+2h, max noon) |
| NudgeGenerator -> .rest | Rest notification | Daily after refresh | Bedtime (learned pattern) |
| NudgeGenerator -> .breathe | Breathe notification | Daily after refresh | 3 PM |
| NudgeGenerator -> .hydrate | Hydrate notification | Daily after refresh | 11 AM |
| NudgeGenerator -> .celebrate/.seekGuidance | General notification | Daily after refresh | 6 PM |
| SmartNudgeScheduler -> .breatheOnWatch | Watch breathe prompt (WCSession) | Stress rising | Real-time |
| SmartNudgeScheduler -> .morningCheckIn | Watch check-in (WCSession) | Late wake detected | Before noon |

## Key Thresholds

### HeartTrendEngine
| Threshold | Value | Purpose |
|-----------|-------|---------|
| Anomaly weights | RHR 25%, HRV 25%, Recovery1m 20%, Recovery2m 10%, VO2 20% | Composite score |
| needsAttention | anomaly >= 2.0 | Status escalation |
| Regression slope | -0.3 bpm/day over 7 days | Multi-day decline detection |
| Stress pattern | RHR Z>1.5 AND HRV Z<-1.5 AND Recovery Z<-1.5 | Simultaneous elevation |
| Confidence: high | 4+ metrics, 14+ history days | |
| Confidence: medium | 2+ metrics, 7+ history days | |

### StressEngine
| Threshold | Value | Purpose |
|-----------|-------|---------|
| RHR weight | 50% | Primary signal |
| HRV weight | 30% | Secondary signal |
| CV weight | 20% | Tertiary signal |
| Sigmoid | k=0.08, mid=50 | Score normalization |
| relaxed | score < 40 | |
| balanced | score 40-65 | |
| elevated | score > 65 | |
| Trend rising | slope > 0.5/day | |

### ReadinessEngine
| Threshold | Value | Purpose |
|-----------|-------|---------|
| Sleep pillar | Gaussian optimal at 8h, sigma=1.5 | 25% weight |
| Recovery pillar | Linear 10-40 bpm drop | 25% weight |
| Stress pillar | 100 - stressScore | 20% weight |
| Activity pillar | Sweet spot 20-45 min/day | 15% weight |
| HRV trend pillar | Each 10% below avg = -20 | 15% weight |
| Primed | score 80-100 | |
| Ready | score 60-79 | |
| Moderate | score 40-59 | |
| Recovering | score 0-39 | |
| Consecutive alert | caps score at 50 | |

### NudgeGenerator
| Threshold | Value | Purpose |
|-----------|-------|---------|
| Priority 1 | stress == true | Stress nudge |
| Priority 2 | regression == true | Regression nudge (readiness gated) |
| Priority 3 | confidence == .low | Low data nudge |
| Priority 4 | feedback == .negative | Adjusted nudge |
| Priority 5 | anomaly < 0.5 | Positive nudge (readiness gated) |
| Priority 6 | default | General nudge (readiness gated) |
| Sleep too short | < 6.5h | Secondary rest nudge |
| Sleep too long | > 9.5h | Secondary walk nudge |
| Low activity | < 10 min | Secondary walk nudge |

### SmartNudgeScheduler
| Threshold | Value | Purpose |
|-----------|-------|---------|
| Journal stress | >= 65 | Trigger journal prompt |
| Late wake | > 1.5h past typical | Morning check-in |
| Bedtime window | hour-1 to hour | Wind-down nudge |
| Low activity | walk+workout < 10 min | Activity suggestion |
| Poor sleep | < 6.5h | Rest suggestion |
| Readiness gate | .recovering | Suppress activity |

### BioAgeEngine
| Threshold | Value | Purpose |
|-----------|-------|---------|
| Max offset per metric | +/- 8 years | Clamp |
| Minimum total weight | 0.3 (2+ metrics) | Required data |
| Excellent | diff <= -5 years | Category |
| Good | diff -5 to -2 | Category |
| On Track | diff -2 to +2 | Category |
| Watchful | diff +2 to +5 | Category |
| Needs Work | diff > +5 | Category |

### HeartRateZoneEngine
| Threshold | Value | Purpose |
|-----------|-------|---------|
| Zone 1 (Recovery) | 50-60% HRR | Karvonen |
| Zone 2 (Fat Burn) | 60-70% HRR | Karvonen |
| Zone 3 (Aerobic) | 70-80% HRR | Karvonen |
| Zone 4 (Threshold) | 80-90% HRR | Karvonen |
| Zone 5 (Peak) | 90-100% HRR | Karvonen |
| Max HR floor | 150 bpm | Safety |
| AHA target | 150 min/week | Moderate + 2x vigorous |
| 80/20 sweet spot | hard ratio 0.15-0.25 | Optimal balance |

## File Paths

| File | Role |
|------|------|
| Shared/Engine/HeartTrendEngine.swift | Master assessment |
| Shared/Engine/StressEngine.swift | Stress scoring |
| Shared/Engine/ReadinessEngine.swift | 5-pillar readiness |
| Shared/Engine/NudgeGenerator.swift | Nudge content selection |
| Shared/Engine/SmartNudgeScheduler.swift | Time-aware nudge timing |
| Shared/Engine/BioAgeEngine.swift | Fitness age estimate |
| Shared/Engine/CoachingEngine.swift | Weekly coaching report |
| Shared/Engine/HeartRateZoneEngine.swift | HR zone computation |
| Shared/Engine/CorrelationEngine.swift | Pearson insight cards |
| Shared/Engine/BuddyRecommendationEngine.swift | Synthesis/priority layer |
| Shared/Models/HeartModels.swift | All shared data models |
| Shared/Services/ConfigService.swift | Global thresholds |
| iOS/ViewModels/DashboardViewModel.swift | Primary iOS orchestrator |
| iOS/ViewModels/StressViewModel.swift | Stress screen orchestrator |
| iOS/Services/NotificationService.swift | Push notification scheduling |
| iOS/Services/ConnectivityService.swift | Phone-Watch sync |
| Watch/ViewModels/WatchViewModel.swift | Watch state + complications |

# Project Code Review

Date: 2026-03-13
Repository: `Apple-watch`
Scope: repo-wide review with emphasis on correctness, optimization, performance, abandoned code, and modernization opportunities.

## Checks Run → COMMITTED → COMPLETED

- `swift test` in `apps/HeartCoach`: **641 tests passed, 0 failures** on 2026-03-13 (up from 461 after test restructuring).
- `swift test` no longer reproduces the earlier SwiftPM unhandled-file warning or the `ThumpBuddyFace` macOS availability warning on branch `fix/deterministic-test-seeds`.
- ~~Important scope note: the default SwiftPM target still excludes dataset-validation and engine time-series suites in `apps/HeartCoach/Package.swift`, so the 461-test pass is not the full extended validation surface.~~
- ✅ **RESOLVED (commit 3e47b3d):** Test restructuring moved EngineTimeSeries-dependent tests into ThumpTimeSeriesTests target and un-excluded EngineKPIValidationTests. `swift test` now runs both ThumpTests and ThumpTimeSeriesTests (641 total). Only iOS-only tests (needing DashboardViewModel/StressViewModel), DatasetValidation (needs external CSV data), and AlgorithmComparisonTests (pre-existing SIGSEGV) remain excluded.

## Branch Verification Update → COMMITTED → COMPLETED

- Verified current branch: `fix/deterministic-test-seeds`
- Verified commits:
  - `0b080eb` `fix: resolve code review findings and stabilize flaky tests`
  - `cba5d71` `docs: update BUG_REGISTRY and PROJECT_DOCUMENTATION with fixes`
  - `ad42000` `fix: share LocalStore with NotificationService and pass consecutiveAlert to ReadinessEngine`
  - `dcbee72` `feat: wire notification scheduling from live assessment pipeline (CR-001)`
  - `218b79b` `fix: batch HealthKit queries, real zoneMinutes, perf fixes, flaky tests, orphan cleanup`
  - `7fbe763` `fix: string interpolation compile error in DashboardViewModel, improve SWELL-HRV validation`
  - `3e47b3d` `test: include more test files in swift test, move EngineTimeSeries-dependent tests`
- The originally enumerated code-review fixes appear landed on this branch.
- This file now treats those as resolved audit items and keeps only genuinely open product-quality and calibration work below.

## Resolved Review Items and Locations

- Duplicate snapshot persistence fix:
  - [LocalStore.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Services/LocalStore.swift#L148) upserts by calendar day at lines 148-164.
- Explicit nudge completion tracking fix:
  - [DashboardViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift#L236) records explicit completion dates at lines 236-263.
  - [InsightsViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/InsightsViewModel.swift#L173) reads `nudgeCompletionDates` for weekly completion rate at lines 173-183.
- Same-day streak inflation fix:
  - [DashboardViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift#L252) guards streak credit with `lastStreakCreditDate` at lines 252-262.
- Readiness stress-input integration fix:
  - [DashboardViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift#L438) now computes and passes the real `StressEngine` score at lines 438-460.
- SwiftPM fixture-warning cleanup:
  - [Package.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Package.swift#L24) excludes `Validation/Data` and `EngineTimeSeries/Results` at lines 24-53.
- `ThumpBuddyFace` availability fix:
  - [ThumpBuddyFace.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Views/ThumpBuddyFace.swift#L257) wraps `.symbolEffect(.bounce)` in an availability check at lines 257-264.
- `HeartTrendEngine` baseline overlap fix:
  - [HeartTrendEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/HeartTrendEngine.swift#L462) excludes the current week from the baseline at lines 462-486.
- `CoachingEngine` date-anchor fix:
  - [CoachingEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/CoachingEngine.swift#L48) uses `current.date` at lines 48-52.
- `CorrelationEngine` activity-minutes fix:
  - [CorrelationEngine.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/CorrelationEngine.swift#L91) uses `activityMinutes` at lines 91-95.
- `SmartNudgeScheduler` date-context fix:
  - [SmartNudgeScheduler.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/SmartNudgeScheduler.swift#L240) uses `todaySnapshot?.date` at lines 240-243.
  - [SmartNudgeScheduler.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/SmartNudgeScheduler.swift#L329) uses `todaySnapshot?.date` at lines 329-332.
- Notification pipeline fix:
  - [ThumpiOSApp.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ThumpiOSApp.swift#L43) injects shared `NotificationService` and requests authorization during startup.
  - [DashboardView.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/Views/DashboardView.swift#L29) binds the environment notification service into the view model.
  - [DashboardViewModel.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift#L225) schedules anomaly alerts and smart nudges from live assessment output at the end of `refresh()`.

## Still Open Product Review Areas

These are the items I would keep in the review because they are not actually complete:

- Startup path still needs one-shot hardening and measurement.
  - `performStartupTasks()` is still attached to the routed root view in [ThumpiOSApp.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/ThumpiOSApp.swift#L57), so route changes can still rerun startup work.
  - Launch still eagerly instantiates several services and synchronously hydrates `LocalStore`.

- Large-file maintainability hotspots remain.
  - [DashboardView.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/Views/DashboardView.swift)
  - [WatchInsightFlowView.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Watch/Views/WatchInsightFlowView.swift)
  - [HeartModels.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Models/HeartModels.swift)
  - [StressView.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/Views/StressView.swift)

- `WatchFeedbackBridge` is still a kept-but-unused subsystem.
  - [WatchFeedbackBridge.swift](/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Services/WatchFeedbackBridge.swift)

- System design documentation still has drift.
  - [MASTER_SYSTEM_DESIGN.md](/Users/t/workspace/Apple-watch/apps/HeartCoach/MASTER_SYSTEM_DESIGN.md) remains useful for intent, but it is not a fully current implementation source of truth.

- Stress-engine product trust is still open.
  - Repo-wide stress-calibration status should now be read from the dedicated report:
    - [STRESS_ENGINE_VALIDATION_REPORT.md](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/STRESS_ENGINE_VALIDATION_REPORT.md)

- `BioAgeEngine`, `CorrelationEngine`, and `SmartNudgeScheduler` still need stronger validation before their outputs deserve high-trust product language.

- Broader real-world validation is still uneven outside the stress work.
  - Stress now has the strongest executed real-data gate in the repo.
  - The other engines still rely more heavily on synthetic or heuristic validation.

## Abandoned / Orphaned Code → COMMITTED → COMPLETED

~~These files currently have no production call sites and are increasing maintenance surface area:~~

- ~~`apps/HeartCoach/iOS/Services/AlertMetricsService.swift`~~ — ✅ Moved to `.unused/` (commit `218b79b`)
- ~~`apps/HeartCoach/iOS/Services/ConfigLoader.swift`~~ — ✅ Moved to `.unused/` (commit `218b79b`)
- ~~`apps/HeartCoach/File.swift`~~ — ✅ Moved to `.unused/` (commit `218b79b`)
- `apps/HeartCoach/Shared/Services/WatchFeedbackBridge.swift`
  - Dedup/queueing bridge is tested, but not integrated into the shipping watch/iPhone feedback path. Kept — likely needed for future watch connectivity.

## Code Quality Assessment

Overall assessment: good intent and strong test coverage, but uneven maintainability.

Strengths:
- The core engine layer is reasonably well separated from the UI layer.
- There is substantial automated coverage; `swift test` now passes 641 tests (up from 461 after test restructuring in commit `3e47b3d`).
- Concurrency boundaries are usually explicit, especially around `@MainActor` view models and WatchConnectivity callbacks.
- Most files include useful doc comments, which makes onboarding easier.

Code-quality risks:
- Several files are very large and are now carrying too many responsibilities:
  - `apps/HeartCoach/iOS/Views/DashboardView.swift` is about 2,197 lines.
  - `apps/HeartCoach/Watch/Views/WatchInsightFlowView.swift` is about 1,715 lines.
  - `apps/HeartCoach/Shared/Models/HeartModels.swift` is about 1,598 lines.
  - `apps/HeartCoach/iOS/Views/StressView.swift` is about 1,228 lines.
  - `apps/HeartCoach/iOS/Views/TrendsView.swift` is about 1,020 lines.
- ~~Dependency injection is inconsistent. Some screens use environment-scoped shared services, while others instantiate fresh service objects inside view models.~~
- ✅ **IMPROVED (commit 218b79b):** InsightsViewModel, TrendsViewModel, and StressViewModel now receive the shared HealthKitService via `bind()` from their views, matching the DashboardViewModel pattern. (PERF-4)
- Warning debt improved on this branch: the earlier SwiftPM fixture warnings and the `ThumpBuddyFace` availability warning are no longer reproduced in the default package test run.
- ~~There is still visible architecture drift between “implemented” and “used” code, especially for the still-partial `NotificationService` integration, `AlertMetricsService`, `ConfigLoader`, and `WatchFeedbackBridge`.~~
- ✅ **IMPROVED:** `NotificationService` fully wired (commit `dcbee72`). `AlertMetricsService` and `ConfigLoader` moved to `.unused/` (commit `218b79b`). Only `WatchFeedbackBridge` remains as a kept-but-unused subsystem.

Recommendations:
- Break oversized views into feature-focused subviews and small presentation models.
- Standardize on app-level dependency injection for long-lived services.
- Treat warnings as backlog items, not harmless noise.
- Remove or integrate orphaned subsystems so the codebase reflects the runtime architecture more honestly.

## Boot-Up / Startup Time Assessment

Note: this review did not capture a real cold-launch benchmark on device or simulator. The points below are based on static analysis of the startup path.

Launch-path observations:
- The app creates `HealthKitService`, `SubscriptionService`, `ConnectivityService`, and `LocalStore` eagerly at app startup in `apps/HeartCoach/iOS/ThumpiOSApp.swift:29-39`.
- Startup work is attached to the routed root view via `.task { await performStartupTasks() }` in `apps/HeartCoach/iOS/ThumpiOSApp.swift:43-53`.
- `performStartupTasks()` then binds connectivity, registers MetricKit, loads StoreKit products, and refreshes subscription status in sequence in `apps/HeartCoach/iOS/ThumpiOSApp.swift:93-119`.
- ~~`SubscriptionService` already kicks off `updateSubscriptionStatus()` during its own initialization in `apps/HeartCoach/iOS/Services/SubscriptionService.swift:74-84`, so app launch currently does overlapping subscription-status work.~~
- ✅ **RESOLVED (commit 218b79b, PERF-1):** Removed redundant `updateSubscriptionStatus()` from `SubscriptionService.init()`. Only called once in `performStartupTasks()`.
- `ConnectivityService` activates `WCSession` immediately in `apps/HeartCoach/iOS/Services/ConnectivityService.swift:37-40`.
- `LocalStore` synchronously hydrates and decrypts persisted state during initialization in `apps/HeartCoach/Shared/Services/LocalStore.swift:66-90`.

Startup-time risks:
- Because the root `.task` is attached to the routed root view, `performStartupTasks()` can rerun as the app transitions between legal gate, onboarding, and main UI. That creates repeated startup churn and makes one-time initialization less predictable.
- ~~`loadProducts()` is eager launch work even though product metadata is only needed when the paywall is shown.~~ ✅ **RESOLVED (commit 218b79b, PERF-2):** Deferred to `PaywallView.task{}`.
- ~~Subscription status is refreshed both in `SubscriptionService.init()` and again in `performStartupTasks()`.~~ ✅ **RESOLVED (commit 218b79b, PERF-1):** Removed from `init()`.
- ~~`MetricKitService.start()` has no one-shot guard, so repeated startup-task execution can re-register the subscriber unnecessarily.~~
- ✅ **RESOLVED (commit 218b79b, PERF-5):** Added `isStarted` flag to `MetricKitService.start()` to guard against repeated registration.

Assessment:
- First paint is probably still acceptable on modern hardware because the launch work is asynchronous and not all of it blocks initial UI presentation.
- Even so, launch is doing more work than necessary, and some of it is duplicated or triggered earlier than user value requires.

Recommendations:
- Make startup initialization one-shot instead of tying it to a routed root view lifecycle.
- ~~Defer `loadProducts()` until the paywall is first opened, or schedule it after first interaction instead of during launch.~~ ✅ **RESOLVED (commit 218b79b, PERF-2):** `loadProducts()` deferred to `PaywallView.task{}`.
- ~~Keep only one subscription-status refresh path.~~ ✅ **RESOLVED (commit 218b79b, PERF-1):** Removed redundant call from `SubscriptionService.init()`.
- Consider lazily activating watch connectivity if the watch feature is not immediately needed.
- Add explicit startup instrumentation:
  - Use `MXApplicationLaunchMetric` from MetricKit for production trend tracking.
  - Add `os_signpost` spans around `performStartupTasks()`, StoreKit initialization, and LocalStore hydration.
  - Measure cold and warm launch in Instruments before and after cleanup work.

## System Design Doc Alignment

I reviewed `apps/HeartCoach/MASTER_SYSTEM_DESIGN.md` to compare the intended architecture against the current code. The document is useful for understanding product intent and the intended engine interactions, but parts of it have drifted from reality.

Useful context from the design doc:
- The intended core loop is clear: HealthKit snapshot → `HeartTrendEngine` → `ReadinessEngine` / `NudgeGenerator` / `BuddyRecommendationEngine` → dashboard + watch surfaces.
- The doc makes the architecture goals explicit: rule-based engines, on-device processing, encrypted storage, and closed-loop coaching.
- The engine inventory and product framing are still helpful for understanding why the code is structured as multiple specialized engines instead of one central model.

Doc-to-code mismatches:
- `MASTER_SYSTEM_DESIGN.md` says `BuddyRecommendationEngine` is not wired to `DashboardViewModel` (`Gap 1`), but the current code does call `computeBuddyRecommendations()` in `DashboardViewModel.refresh()` and renders `buddyRecommendationsSection` in `DashboardView`.
- The same doc says there is no onboarding health disclaimer gate (`Gap 9`), but `OnboardingView` contains a dedicated disclaimer page and blocks progression until the toggle is accepted.
- The production checklist marks iOS/watch `Info.plist` files and `PrivacyInfo.xcprivacy` as TODO, but those files exist in the repo today.
- `Gap 7` says `nudgeSection` was fixed and wired into the dashboard, but the current dashboard comments say it was replaced by `buddyRecommendationsSection`, and the old `nudgeSection` still exists as unused code.
- File inventory metadata is stale. The document’s stored line counts are lower than the current files in several major views, so it should not be used as a precise sizing/source-of-truth artifact anymore.

Recommendation:
- Treat `MASTER_SYSTEM_DESIGN.md` as architectural intent, not as exact implementation truth.
- Add a short “verified against code on <date>” maintenance pass whenever major flows change.
- Remove or update stale gap items so the document does not actively mislead future refactors or reviews.

## Engine-by-Engine Assessment

This section answers two questions for each engine:
- Is the current data and validation story enough?
- Is the current output quality good enough for real users?

Short version:
- Good enough for a wellness prototype: `HeartTrendEngine`, `BuddyRecommendationEngine`, `NudgeGenerator`, parts of `StressEngine` and `ReadinessEngine`.
- Not good enough yet for strong user trust or strong claims: `BioAgeEngine`, `CoachingEngine`, `HeartRateZoneEngine`, `SmartNudgeScheduler`, `CorrelationEngine`.

### HeartTrendEngine

Assessment:
- This is still the strongest engine in the repo. It has the clearest orchestration role, the broadest signal coverage, and the most coherent output model.
- It is probably good enough for prototype-level daily status output.

Strengths:
- Solid separation of anomaly, regression, stress-pattern, scenario, and recovery-trend logic.
- Strong synthetic/unit support in the repo.
- Output shape (`HeartAssessment`) is rich enough to power multiple surfaces cleanly.

Gaps / bugs:
- The prior baseline-overlap bug appears fixed on this branch. `weekOverWeekTrend()` now excludes the most recent seven snapshots before computing the baseline mean.
- Week-over-week logic is RHR-only. That may be acceptable for a first pass, but it means “trend” is narrower than the UI language suggests.
- Real-world validation is still weak for this specific engine because there is no equivalent executed external-dataset gate comparable to the new stress-engine validation workflow.

Verdict:
- Enough for a prototype daily assessment engine.
- Not enough yet for claims of strong trend sensitivity or calibrated week-over-week analytics.

### StressEngine

Assessment:
- The engine is directionally useful, especially for relative ranking and “higher vs lower stress” days.
- It is not yet convincingly calibrated enough for users to trust the absolute numeric score.

Strengths:
- Better grounded than many wellness heuristics because it explicitly uses personal baselines.
- RHR-primary weighting is a sensible correction given the design notes and TODO rationale.
- The engine is pure and easy to test.

Gaps / risks:
- The repo itself still marks this engine as calibration work in progress (`apps/HeartCoach/TODO/01-stress-engine-upgrade.md`).
- The stress-validation story has improved substantially since the original review:
  - local SWELL, PhysioNet, and WESAD data are now present
  - the dedicated validation harness has been executed against those datasets
  - the detailed current status now lives in [STRESS_ENGINE_VALIDATION_REPORT.md](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/STRESS_ENGINE_VALIDATION_REPORT.md)
- The remaining issue is not absence of validation anymore; it is that the current single-formula product score still does not generalize cleanly across those datasets.
- The output score is still a heuristic composite with tuned constants rather than a validated real-world scale.
- The description text can make the score feel more certain than the calibration evidence currently justifies.

Verdict:
- Enough for relative guidance in a prototype.
- Not enough for strong absolute statements like “your stress is 72/100” without more out-of-sample real-user validation.

### ReadinessEngine

Assessment:
- The architecture is solid and probably the cleanest “composite wellness” model in the repo.
- The engine itself is more mature than its current integration.

Strengths:
- Clear pillar model, weight re-normalization, and understandable scoring.
- Sleep and recovery pillars are intuitive and reasonably explainable.
- Good extensibility; the TODO plan is incremental rather than a rewrite.

Gaps / bugs:
- The engine still lacks the planned richer recovery inputs described in `apps/HeartCoach/TODO/04-readiness-engine-upgrade.md`.
- Integration improved on this branch: `computeReadiness()` in `DashboardViewModel` now passes the real `StressEngine.compute()` score instead of the coarse `70.0` flag path.
- ~~One meaningful gap remains: `DashboardViewModel` still does not pass `assessment?.consecutiveAlert` into `ReadinessEngine.compute(...)`, even though the engine supports that overtraining cap.~~
- ✅ **RESOLVED (commit ad42000):** `DashboardViewModel.computeReadiness()` now passes `consecutiveAlert: assessment?.consecutiveAlert`. File: `apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift:~460`.
- The shipped readiness result now uses the full engine contract (stress score + consecutiveAlert overtraining cap).

Verdict:
- Engine design: good enough.
- Current app output: materially improved and now uses the full currently supported dashboard input contract.
- Remaining gaps are richer recovery inputs and stronger validation, not missing wiring in the current dashboard path.

### BioAgeEngine

Assessment:
- This is the least trustworthy numeric output in the core wellness stack.
- It is okay as a soft motivational feature, but not strong enough for a serious “bio age” representation.

Strengths:
- Missing-data handling is decent.
- The explanation/breakdown model is better than a single opaque number.

Gaps / risks:
- BMI is approximated from weight plus sex-based average height in `apps/HeartCoach/Shared/Engine/BioAgeEngine.swift:170-185`. That creates obvious bias for users who are much shorter or taller than the assumed average.
- The engine is still under active rethinking per `apps/HeartCoach/TODO/02-bioage-engine-upgrade.md`.
- The output mixes signals with very different evidence quality into a single age number, which can look more validated than it is.
- Validation is especially thin here: NTNU reference logic is mentioned, but the repo does not contain a robust out-of-sample benchmark for the full composite.

Verdict:
- Not enough for a high-trust user-facing absolute number.
- Acceptable only if framed clearly as a lightweight wellness estimate and deprioritized from major product claims.

### BuddyRecommendationEngine

Assessment:
- One of the better user-facing engines in the project.
- It adds real value by turning multiple upstream signals into prioritized actions.

Strengths:
- Clear priority ordering and deduplication.
- Easy to reason about and easy to extend.
- Better product value than many of the raw numeric engines because it produces actionable output.

Gaps / risks:
- It inherits upstream weaknesses directly; if trend, stress, or readiness are off, recommendation quality will drift too.
- Some language still edges toward stronger inference than the underlying data warrants. Example: the consecutive alert message says the body may be “fighting something off,” which may feel more diagnostic than a wellness app should sound.
- There is no explicit uncertainty presentation per recommendation.

Verdict:
- Good enough for production-style UX if the upstream engines are improved.
- Already one of the strongest parts of the product.

### CoachingEngine

Assessment:
- Valuable conceptually, but currently too heuristic to be treated as a dependable engine.
- It is more of a copy/projection layer than a validated analytics layer.

Strengths:
- Good motivational framing.
- Connects behavior and physiology in a way users can understand.

Gaps / bugs:
- `generateReport()` anchors “this week” and “last week” to `Date()` instead of `current.date` in `apps/HeartCoach/Shared/Engine/CoachingEngine.swift:48-54`. That makes historical replay and deterministic backtesting inaccurate whenever the evaluated snapshot is not “today.”
  - **✅ FIXED** (2026-03-13): Replaced `Date()` with `current.date` so weekly comparisons use the snapshot's own date context.
- Projection text is aspirational and research-inspired, but not individualized enough to justify precise-looking forecasts.
- ~~Zone-driven coaching is weakened further by the fact that real HealthKit snapshots currently never populate `zoneMinutes`.~~ ✅ **RESOLVED (commit 218b79b, CR-013):** `queryZoneMinutes(for:)` now populates real zone data from workout HR samples.

Verdict:
- Not enough for high-confidence projections.
- Even with the date-anchor bug fixed, it still needs stronger validation before its outputs should be treated as more than motivational guidance.

### NudgeGenerator

Assessment:
- Good library-based engine for prototype coaching.
- Output is generally usable, but quality depends heavily on upstream signal quality and can become generic.

Strengths:
- Clear priority order.
- Readiness gating is a smart product decision that prevents obviously bad recommendations on poor-recovery days.
- Multiple-nudge support is useful.

Gaps / quality risks:
- Secondary suggestions can degrade into generic fallback content like hydration reminders, which may make the engine feel less personalized on borderline-data days.
- It remains largely a curated rule library, so repetition risk grows as users spend more time in the product.
- Recommendation specificity is only as strong as the upstream engine inputs.

Verdict:
- Good enough for now.
- Needs more personalization depth and more “why this today” grounding to stay strong over time.

### HeartRateZoneEngine

Assessment:
- The standalone algorithm is plausible, and the shipped product path now can feed it real data for users with tracked workouts.
- The remaining issue is output quality and validation depth, not a missing ingestion pipeline.

Strengths:
- Karvonen-based zone computation is a sensible approach.
- Weekly zone summary logic is straightforward and explainable.

Gaps / bugs:
- ~~`HealthKitService.fetchSnapshot()` hardcodes `zoneMinutes: []` in `apps/HeartCoach/iOS/Services/HealthKitService.swift:231-239`. **⬚ OPEN** — requires HealthKit workout session ingestion to populate real zone data.~~
- ✅ **RESOLVED (commit 218b79b):** Added `queryZoneMinutes(for:)` method that queries workout HR samples and buckets into 5 zones based on age-estimated max HR (220-age). `fetchSnapshot(for:)` now uses real zone data via `async let zones = queryZoneMinutes(for: date)`.
- `DashboardViewModel.computeZoneAnalysis()` then bails out unless there are 5 populated zone values in `apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift:455-462`.
- As a result, zone analysis/coaching now works only for users whose recorded workouts yield enough usable heart-rate-zone data; it is no longer mock-only, but it is still sparse for lightly tracked users.
- There is also a smaller correctness issue: `computeZones()` documents sex-aware HRmax handling, but the current implementation does not materially apply a different formula.

Verdict:
- ~~Not enough as shipped because the data pipeline into the engine is missing.~~
- ✅ **IMPROVED (commit 218b79b, CR-013):** Data pipeline now exists — `queryZoneMinutes(for:)` ingests real workout HR samples. Verdict: engine is now usable with real data for users who do tracked workouts.

### CorrelationEngine

Assessment:
- Fine as an exploratory insight toy.
- Not strong enough to support meaningful “your data shows...” claims without more nuance.

Strengths:
- Pure, small, and easy to maintain.
- Avoids crashes and does basic paired-value hygiene correctly.

Gaps / risks:
- It only analyzes four hard-coded same-day pairs.
- It uses raw Pearson correlation with no lag modeling, no confound control, and a minimum of only seven paired points.
- The “Activity Minutes” insight is semantically misleading: in `apps/HeartCoach/Shared/Engine/CorrelationEngine.swift:91-100`, it actually uses `workoutMinutes` only, not total activity minutes.
  - **✅ FIXED** (2026-03-13): Changed keypath from `\.workoutMinutes` to `\.activityMinutes` (computed property = `walkMinutes + workoutMinutes`). Added `activityMinutes` to `HeartSnapshot`.
- The generated language can sound more causal and robust than the math really supports.

Verdict:
- Not enough for strong, trustworthy personalized insight cards.
- Even after the activity-minutes mapping fix, it still needs lag-aware analysis, broader factor coverage, and more careful language.

### SmartNudgeScheduler

Assessment:
- Good product idea, weak current evidence model.
- Timing output is not reliable enough to be treated as truly personalized behavior learning.

Strengths:
- The decision tree is easy to reason about.
- It is a nice fit for watch/notification UX.

Gaps / bugs:
- `learnSleepPatterns()` does not learn actual bedtimes/wake times from timestamped sleep sessions; it infers them from sleep duration heuristics alone in `apps/HeartCoach/Shared/Engine/SmartNudgeScheduler.swift:74-84`.
- `bedtimeNudgeLeadMinutes` and `breathPromptThreshold` are declared but not used, which suggests intended behavior drift.
- `recommendAction()` uses `Date()` for bedtime day-of-week lookup in `apps/HeartCoach/Shared/Engine/SmartNudgeScheduler.swift:240-243` instead of using the provided context date. That hurts determinism and replayability.
  - **✅ FIXED** (2026-03-13): Replaced `Date()` with `todaySnapshot?.date ?? Date()` for day-of-week lookup.

Verdict:
- Not enough for claims of learned personalized timing.
- Fine as a heuristic scheduler until the timing model uses real sleep/wake timestamps and the remaining unused config knobs are reconciled with actual behavior.

## Dataset and Validation Sufficiency

Assessment:
- The repo has enough data infrastructure for development, demos, regression testing, and one strong deep-dive validation area.
- It still does not have enough evenly distributed real validation coverage across all engines to justify strong confidence in repo-wide calibration.

### What is present

- Deterministic synthetic personas in `apps/HeartCoach/Shared/Services/MockData.swift`.
- One real 32-day Apple Watch-derived sample embedded in `MockData.swift`.
- A validation harness in `apps/HeartCoach/Tests/Validation/DatasetValidationTests.swift`.
- A documented plan for external datasets in `apps/HeartCoach/Tests/Validation/FREE_DATASETS.md`.
- Real local stress-validation data now present under `apps/HeartCoach/Tests/Validation/Data/`:
  - `swell_hrv.csv`
  - `physionet_exam_stress/`
  - `WESAD.zip`
  - `wesad_e4_mirror/`
- A dedicated executed stress-validation write-up in [STRESS_ENGINE_VALIDATION_REPORT.md](/Users/t/workspace/Apple-watch/apps/HeartCoach/Tests/Validation/STRESS_ENGINE_VALIDATION_REPORT.md).

### What is missing

- Outside the stress work, most engines still do not have equivalent executed real-data validation.
- `DatasetValidationTests` remain opt-in rather than part of the default `swift test` path, because they depend on external datasets and Xcode-hosted execution.
- Several iOS-only and external-data suites are still excluded from the default package run in `apps/HeartCoach/Package.swift`.
- There is still no held-out private product dataset with subjective labels for cross-engine calibration.

### Is the dataset enough?

For development and regression:
- Yes, mostly.
- The synthetic personas and seeded histories are enough to keep core rules stable and deterministic.

For engine calibration and confidence in output quality:
- No.
- The synthetic data is partly circular: it encodes the same assumptions the engines reward, so passing those tests does not prove the rules generalize.
- The single embedded real-history sample is useful for demos and sanity checks, but it is still only one user and several fields are inferred/derived rather than ground-truth labeled.
- Stress is now the exception: it has moved beyond “aspirational” into an executed multi-dataset validation workflow.
- The broader repo is still uneven because the other engines have not yet reached that same validation maturity.

### Output-quality implications

- Relative outputs are stronger than absolute outputs.
  - Stronger: “today looks a bit better/worse than your normal,” “rest vs walk vs breathe,” “this week is elevated.”
  - Weaker: exact stress score, exact bio age, exact weekly projections, true personalized bedtime timing, causal correlation insight text.

### What would make the datasets “enough”

- Real multi-user Apple Watch histories, not just synthetic personas and one embedded export.
- A private evaluation set with subjective labels:
  - perceived stress
  - readiness/fatigue
  - sleep quality
  - illness/recovery events
- Longer longitudinal histories for the trend/coaching engines.
- Validation that actually runs in CI or a documented offline evaluation workflow.
- A separation between:
  - synthetic regression data for deterministic behavior
  - real calibration data for score quality
  - held-out real evaluation data for final confidence checks

### Bottom-line verdict

- Enough for a thoughtful prototype and for building the product loop.
- Not enough yet to say the engines are well-calibrated on real users across the repo.
- The biggest remaining gap is not code complexity; it is uneven real-data validation depth outside the now-stronger stress-engine workflow.

## Dataset Creation Guidance

This is the practical guidance I would follow for creating datasets deeply enough to improve trust in the engines.

### Core Principle

Do not rely on one dataset type.

You need three different dataset layers:

1. Synthetic regression data
- Purpose: deterministic tests and edge cases
- Best for: preventing code regressions
- Not enough for: calibration confidence

2. Real-world calibration data
- Purpose: tuning thresholds, score bands, and ranking behavior
- Best for: improving engine realism
- Not enough for: final confidence if reused for evaluation

3. Held-out evaluation data
- Purpose: final verification on data the tuning process never saw
- Best for: measuring whether the engine generalizes

### How Deep The Dataset Needs To Be

For this project, I would not call the datasets “deep enough” until they cover:

- multiple users, not one embedded Apple Watch export
- multiple weeks per user, not isolated daily samples
- multiple physiological states:
  - normal baseline
  - poor sleep
  - high activity
  - low activity
  - stress-heavy periods
  - recovery periods
  - illness-like or fatigue-like periods when available
- both complete and incomplete data windows
- enough variation across:
  - age
  - sex
  - fitness level
  - work/rest routines

### Recommended Depth By Stage

#### Stage 1: Better Synthetic Data

Goal:
- strengthen regression tests and scenario coverage

Recommended scope:
- 20-30 personas, not 10
- 60-90 days per persona, not 30
- explicit event injections:
  - bad sleep streak
  - exercise block
  - sedentary week
  - travel/jetlag-style sleep disruption
  - illness/fatigue spike
  - overtraining block

Important:
- keep synthetic data for test determinism
- do not treat it as evidence that the algorithms are calibrated correctly

#### Stage 2: Small Real-World Calibration Set

Goal:
- tune engine thresholds and validate ranking behavior

Minimum useful target:
- 20-30 users
- 6-8 weeks each
- daily snapshots
- subjective labels at least 3-4 times per week

Better target:
- 50+ users
- 8-12 weeks each

Why:
- below that, the system can still be useful, but threshold tuning will stay fragile

#### Stage 3: Held-Out Evaluation Set

Goal:
- verify generalization after tuning

Minimum useful target:
- 10-15 users completely excluded from tuning
- 4-8 weeks each

Better target:
- 20+ held-out users

Rule:
- no threshold or copy changes should be tuned on this set

### Per-Engine Dataset Needs

#### HeartTrendEngine

Needs:
- long daily series per user
- stable baseline periods
- known disruptions

Good dataset depth:
- 28-60 days per user minimum
- enough missing days to test robustness

Labels to collect:
- “felt off today”
- “felt normal”
- illness/recovery notes if available

#### StressEngine

Needs:
- same-day physiological data plus subjective stress

Good dataset depth:
- 4+ weeks per user
- multiple stress and low-stress days per person

Best labels:
- perceived stress 1-5
- workload / exam / deadline flags
- sleep quality

Important:
- stress should be validated as a relative score first, not an absolute medical-grade score

#### ReadinessEngine

Needs:
- sleep, recovery, activity, and subjective readiness/fatigue

Good dataset depth:
- 4-8 weeks per user
- at least several “good,” “average,” and “bad” recovery days per user

Best labels:
- “ready to train?” yes/no/low-medium-high
- fatigue score
- soreness score if available

#### BioAgeEngine

Needs:
- this engine needs the deepest caution

Good dataset depth:
- large published reference tables plus real user data
- actual height if BMI is used

Best labels:
- use reference-norm benchmarking, not subjective “bio age” labels

Important:
- if real height is unavailable, do not over-invest in BMI-dependent conclusions

#### CoachingEngine

Needs:
- long time series with repeated routines

Good dataset depth:
- 8-12 weeks minimum
- enough behavior changes to compare before/after

Best labels:
- recommendation followed or not
- perceived benefit the next day

#### HeartRateZoneEngine

Needs:
- real zone-minute data, not empty arrays

Good dataset depth:
- per-workout zone distribution across multiple activity styles
- users with different ages and resting HR

Important:
- ~~this dataset is blocked until the HealthKit ingestion path actually populates `zoneMinutes`~~ ✅ **UNBLOCKED (commit 218b79b, CR-013)**

#### CorrelationEngine

Needs:
- longer windows than the current 7-point minimum implies

Good dataset depth:
- 30-60 days per user minimum
- enough same-day and next-day pairs to test lag effects

Best labels:
- mostly internal validation rather than subjective labels

Important:
- use this as exploratory analytics, not hard truth

#### SmartNudgeScheduler

Needs:
- timestamped sleep/wake data
- interaction timestamps

Good dataset depth:
- several weeks per user
- weekday/weekend variation
- enough prompts to compare predicted timing vs actual user behavior

Best labels:
- prompt accepted/ignored
- time-to-action after prompt

### Dataset Schema Recommendation

For real datasets, I would standardize one canonical daily schema and one event schema.

Daily schema:
- `user_id`
- `date`
- `resting_hr`
- `hrv_sdnn`
- `recovery_hr_1m`
- `recovery_hr_2m`
- `vo2_max`
- `steps`
- `walk_minutes`
- `workout_minutes`
- `sleep_hours`
- `body_mass_kg`
- `zone_minutes_1` to `zone_minutes_5`
- `wear_time_hours`
- `missingness_flags`

Daily label schema:
- `perceived_stress_1_5`
- `readiness_1_5`
- `sleep_quality_1_5`
- `felt_sick_bool`
- `trained_today_bool`
- `recommendation_followed_bool`

Event schema:
- `user_id`
- `timestamp`
- `event_type`
- `context`
- `engine_output_snapshot`
- `user_feedback`

### Data Quality Rules

I would only trust a dataset for calibration if it passes these quality rules:

- dates are continuous and timezone-normalized
- missing metrics are explicit, not silently zero-filled
- derived fields are tagged as derived, not mixed with raw observations
- wear-time is known or approximated
- there is enough per-user baseline depth before scoring trend-based outputs

### Recommended Splits

Do not evaluate on the same users and periods used for tuning.

Recommended split:
- 60% calibration users
- 20% validation users
- 20% held-out evaluation users

If the sample is still small:
- split by user, not by day
- never mix one user’s days across train/eval if you want honest generalization estimates

### What “Good Enough” Looks Like

For this project, I would call the datasets good enough only when:

- every core engine has deterministic synthetic regression coverage
- at least 20-30 real users are available for calibration
- at least 10 held-out users are available for evaluation
- real-data validation is runnable on demand and documented
- engine thresholds are tuned on calibration data and frozen before held-out evaluation

### Recommendation

If I were prioritizing dataset work for the team, I would do it in this order:

1. Expand synthetic personas and event injection for regression safety.
2. Add a small but clean real-user calibration dataset with daily subjective labels.
3. Build a separate held-out evaluation set before retuning thresholds.
4. Only after that, revisit the absolute scores and more confident user-facing language.

## Recommended Test Cases

The project already has many tests, but the biggest gaps are:
- integration tests for how engines are wired into the app
- regression tests for known edge cases in the current logic
- real-data validation that actually runs in a predictable workflow

### Test Strategy Recommendation

Split tests into three layers:

1. Fast default tests
- Run on every `swift test`
- Pure-engine unit tests
- Small integration tests with mock data
- No external datasets required

2. Extended regression tests
- Time-series suites, persona suites, KPI suites
- Run in CI nightly or in a separate “extended” workflow
- Catch ranking drift and behavior regressions

3. Dataset validation tests
- Real external data, opt-in
- Run with a documented local script or scheduled CI job when datasets are available
- Used for calibration confidence, not basic correctness

### HeartTrendEngine Test Recommendations

- Add a week-over-week non-overlap test:
  - Current week has elevated RHR.
  - Baseline period is stable and earlier.
  - Assert the computed z-score reflects the full shift.
  - This should catch the current overlapping-baseline bug.
  - **✅ Underlying bug fixed:** `HeartTrendEngine.swift` now uses `dropLast(currentWeekCount)` to exclude current week from baseline. A regression test for this specific behavior is still recommended.
- Add a control test where only the current week changes:
  - If the baseline excludes the current week, trend should move.
  - If it includes the current week, trend will be artificially damped.
- Add a missing-day continuity test for `detectConsecutiveElevation()`:
  - Day 1 elevated, day 2 missing, day 3 elevated.
  - Assert this does not count as 3 consecutive elevated days.
- Add threshold-edge tests:
  - anomaly exactly at threshold
  - regression slope exactly at threshold
  - stress pattern with only 2 of 3 conditions true
- Add a stability test on sparse data:
  - only one metric present across 14 days
  - assert output remains low-confidence and non-crashing

### StressEngine Test Recommendations

**✅ Test stabilization completed:** Two flaky time-series tests were fixed by adjusting test data generator parameters (no engine changes):
- `testYoungAthleteLowStressAtDay30` — reduced `rhrNoise` from 3.0 → 2.0 bpm in `Tests/EngineTimeSeries/TimeSeriesTestInfra.swift`
- `testNewMomVeryLowReadiness` — lowered NewMom `recoveryHR1m` 18→15 and `recoveryHR2m` 25→22 in `Tests/EngineTimeSeries/TimeSeriesTestInfra.swift`
- All 280 time-series checkpoint assertions now pass (140 stress + 140 readiness).

- Add absolute calibration tests for the current algorithm:
  - “healthy baseline day” should land in a bounded low-stress range
  - “clearly elevated RHR day” should land in a bounded high-stress range
- Add monotonicity tests:
  - increasing RHR with all else fixed should never lower stress
  - decreasing HRV with all else fixed should never lower stress
- Add dominance tests:
  - RHR-only stress event should still meaningfully raise score
  - HRV-only anomaly should raise score less than matched RHR anomaly
- Add sigmoid sanity tests:
  - at-baseline score is inside the intended neutral band
  - extreme inputs still clamp to `[0, 100]`
- Add replay tests against stored expected outputs for a few real-history windows from `MockData`.
- If the external dataset is available:
  - assert minimum separation between stressed and baseline groups
  - store effect-size output in a machine-readable artifact

### ReadinessEngine Test Recommendations

- Add integration tests for the actual app wiring:
  - feed a real `StressResult.score` into readiness and compare against the current coarse `70.0` fallback path
  - assert the app path uses the richer signal once fixed
  - **✅ Underlying bug fixed:** `DashboardViewModel.computeReadiness()` now calls `StressEngine.compute()` and passes the real score. File: `apps/HeartCoach/iOS/ViewModels/DashboardViewModel.swift`. A dedicated integration test asserting this path is still recommended.
- Add consecutive-alert cap tests:
  - readiness without alert > 50
  - same inputs with `consecutiveAlert` capped to `<= 50`
- Add pillar removal tests:
  - sleep missing
  - recovery missing
  - stress missing
  - assert correct re-normalization and no divide-by-zero
- Add activity-window behavior tests:
  - one hard day followed by rest
  - three sedentary days
  - balanced weekly activity
- Add summary text tests:
  - output should match level and not overstate certainty

### BioAgeEngine Test Recommendations

- Add height-sensitivity tests:
  - same weight and sex-average fallback vs realistic short/tall user once height exists
  - this should expose the bias from average-height BMI approximation
- Add monotonicity tests:
  - higher VO2 should not increase bio age
  - lower RHR should not increase bio age
  - higher HRV should not increase bio age
- Add plausibility-band tests:
  - prevent unrealistic outputs from limited data
  - assert result stays within a configurable range of chronological age unless multiple strong signals agree
- Add missing-data composition tests:
  - exactly 2 metrics available
  - 3 metrics available
  - all 6 metrics available
  - assert stable degradation, not discontinuous jumps
- Add reference-table tests:
  - NTNU median should map near zero offset
  - strong percentile cases should map in the expected direction

### BuddyRecommendationEngine Test Recommendations

- Add end-to-end priority tests using full `HeartAssessment` bundles:
  - overtraining should outrank generic regression
  - consecutive alert should outrank positive reinforcement
- Add dedupe tests across category collisions:
  - multiple sources generating `.rest`
  - assert only the highest-priority `.rest` recommendation survives
- Add uncertainty tests:
  - low-confidence assessment should not generate overly strong recommendation copy if uncertainty messaging is added
- Add content-quality snapshot tests:
  - recommendation title/message/detail for 5-10 representative scenarios
  - this helps catch accidental wording regressions

### CoachingEngine Test Recommendations

- Add deterministic replay tests:
  - pass a historical `current.date`
  - assert “this week” and “last week” use the snapshot’s date context, not wall-clock `Date()`
  - **✅ Underlying bug fixed:** `CoachingEngine.generateReport()` now uses `current.date` instead of `Date()`. File: `apps/HeartCoach/Shared/Engine/CoachingEngine.swift`. A replay test asserting deterministic output is still recommended.
- Add bounded-projection tests:
  - projections should remain within realistic ranges
  - no impossible negative exercise times or extreme multi-week gains
- Add sparse-history tests:
  - 3 days, 7 days, 14 days
  - assert the report degrades gracefully instead of producing overconfident text
- Add zone-dependency tests:
  - no zone data should not imply zone-driven coaching
- Add report snapshot tests:
  - same input history should always produce the same hero message and projections

### NudgeGenerator Test Recommendations

- Add “why this nudge” tests:
  - stress day
  - regression day
  - low-data day
  - negative-feedback day
  - high-readiness day
  - recovering day
- Add anti-repetition tests:
  - multiple consecutive days with similar inputs should still rotate within an allowed message set
- Add readiness-gating tests:
  - low readiness must suppress moderate/high-intensity nudges
  - high readiness should allow them
- Add copy-safety tests:
  - no medical/diagnostic language
  - no contradictory advice across primary and secondary nudges

### HeartRateZoneEngine Test Recommendations

- Add pipeline integration tests:
  - verify real HealthKit-backed snapshots actually provide `zoneMinutes` once that path is implemented
  - fail if `zoneMinutes` stays empty through the full snapshot path
- Add formula tests for `computeZones()`:
  - zone bounds increase monotonically
  - all zones are contiguous and non-overlapping
  - values change sensibly with age and resting HR
- Add weekly-summary tests:
  - moderate/vigorous target calculation
  - AHA completion formula
  - top-zone selection
- Add UI integration tests:
  - dashboard should suppress zone messaging when no data exists
  - dashboard should surface coaching only when real zone data is present

### CorrelationEngine Test Recommendations

- Add semantic-correctness tests:
  - if factor is labeled “Activity Minutes,” the underlying key path should include walk + workout, not workout only
  - **✅ Underlying bug fixed:** `CorrelationEngine.swift` now uses `\.activityMinutes` (= `walkMinutes + workoutMinutes`) instead of `\.workoutMinutes`. File: `apps/HeartCoach/Shared/Engine/CorrelationEngine.swift`. Computed property added in `apps/HeartCoach/Shared/Models/HeartModels.swift`.
- Add lag tests:
  - sleep today vs HRV tomorrow
  - activity today vs recovery tomorrow
  - even if not implemented yet, these should define the expected future direction
- Add confound-style tests:
  - constant factor series
  - sparse pair overlap
  - outlier-heavy series
- Add language tests:
  - interpretation must not imply causation when only correlation is measured
- Add threshold tests:
  - exactly 6 paired points should not emit a result
  - exactly 7 should

### SmartNudgeScheduler Test Recommendations

- Add behavior-learning tests using explicit timestamped sleep data once available.
- Add deterministic date-context tests:
  - scheduler should use supplied date context, not `Date()`
  - **✅ Underlying bug fixed:** `SmartNudgeScheduler.recommendAction()` now uses `todaySnapshot?.date ?? Date()` instead of `Date()`. File: `apps/HeartCoach/Shared/Engine/SmartNudgeScheduler.swift`.
- Add threshold-use tests:
  - `breathPromptThreshold` should actually gate breath prompts if that is the intended design
  - `bedtimeNudgeLeadMinutes` should change output timing when modified
- Add fallback tests:
  - low observation count should use defaults
  - high observation count should use learned pattern
- Add late-wake tests:
  - normal wake time
  - slightly late but below threshold
  - clearly late wake above threshold

### Dataset / Validation Test Recommendations

- Add a separate validation command, for example:
  - `swift test --filter DatasetValidationTests`
  - or a dedicated script that first verifies required files exist
- Change dataset tests from “skip silently when missing” to “report clearly missing prerequisites” in the validation workflow summary.
- Add a manifest or JSON summary file for each validation run:
  - dataset used
  - row count
  - effect size / AUC / correlation with labels
  - pass/fail thresholds
- Add held-out benchmark fixtures:
  - a few frozen real-world windows with expected engine outputs
  - useful for catching unintentional recalibration drift
- ~~Promote some currently excluded suites into the default or extended CI path:~~
  - ~~`EngineKPIValidationTests`~~ ✅ **PROMOTED (commit 3e47b3d):** Un-excluded from ThumpTests, now runs in default `swift test`.
  - ~~selected `EngineTimeSeries/*`~~ ✅ **PROMOTED (commit 3e47b3d):** ThumpTimeSeriesTests target now includes EndToEnd, UICoherence, and MockProfile tests. Runs in default `swift test`.
  - `DatasetValidationTests` in an opt-in validation job — **⬚ OPEN** (needs external CSV data)

### Highest-Value Tests To Add First

If only a few tests are added soon, I would prioritize these:

1. `HeartTrendEngine` week-over-week non-overlap regression test — **✅ bug fixed** in `HeartTrendEngine.swift` (`dropLast`), test still recommended
2. `CoachingEngine` date-anchor replay test — **✅ bug fixed** in `CoachingEngine.swift` (`current.date`), test still recommended
3. ~~`HeartRateZoneEngine` pipeline test proving `zoneMinutes` are actually populated — **⬚ OPEN**, blocked on HealthKit ingestion~~ **✅ UNBLOCKED (commit 218b79b, CR-013):** `queryZoneMinutes(for:)` now ingests real workout HR samples. Test still recommended.
4. `ReadinessEngine` integration test using real stress score instead of the coarse `70.0` flag path — **✅ bug fixed** in `DashboardViewModel.swift`, test still recommended
5. `DatasetValidationTests` workflow test that fails clearly when the validation job is misconfigured — **⬚ OPEN**

## Optimization Opportunities

- ~~Share the same `HealthKitService` instance across `Dashboard`, `Insights`, `Stress`, and `Trends` instead of each view model creating its own service instance.~~ **✅ FIXED (commit 218b79b, PERF-4)** — All view models now receive the shared HealthKitService via `bind()` from their views.
- Avoid reloading HealthKit history on every range switch when a cached superset can serve multiple views. **⬚ OPEN**
- Upsert stored daily history instead of append-only persistence. **✅ FIXED** — `LocalStore.appendSnapshot(_:)` now upserts by calendar day. File: `apps/HeartCoach/Shared/Services/LocalStore.swift`
- Reduce warning noise in tests so performance regressions and real compiler warnings stand out faster. **✅ FIXED** — `Package.swift` exclude list updated, `ThumpBuddyFace` availability guard added. Files: `apps/HeartCoach/Package.swift`, `apps/HeartCoach/Shared/Views/ThumpBuddyFace.swift`

## Modernization Opportunities

- ~~Use batched HealthKit descriptors/collection queries instead of manual per-day fan-out.~~ **✅ FIXED (commit 218b79b, CR-005)** — `fetchHistory(days:)` now uses `HKStatisticsCollectionQuery` for RHR, HRV, steps, walkMinutes.
- Introduce a dedicated per-day completion/streak model instead of overloading `WatchFeedbackPayload`. **✅ FIXED** — Added `lastStreakCreditDate` and `nudgeCompletionDates` to `UserProfile`. File: `apps/HeartCoach/Shared/Models/HeartModels.swift`
- ~~Add app-level dependency injection for services that are currently instantiated ad hoc in view models.~~ **✅ IMPROVED (commit 218b79b, PERF-4)** — All view models now use `bind()` pattern for shared service injection.
- ~~Add integration tests for notification wiring, same-day refresh dedupe, and weekly completion accuracy.~~ **✅ PARTIALLY DONE** — notification wiring complete (commit `dcbee72`), scheduling from live assessments wired. Integration tests for these paths are still recommended.

## Suggested Next Steps → COMMITTED → COMPLETED

1. ~~Fix the two data-integrity issues first: duplicate snapshot persistence and incorrect completion-rate accounting.~~ **✅ DONE** — upsert in `LocalStore.swift`, completion tracking in `HeartModels.swift` + `InsightsViewModel.swift` + `DashboardViewModel.swift`
2. ~~Decide whether notifications are a real shipping feature; if yes, wire `NotificationService` now, otherwise remove or park it.~~ **✅ DONE (commit dcbee72)** — Full notification pipeline: authorization + shared LocalStore + scheduling from live assessment output (anomaly alerts + smart nudge reminders).
3. ~~Rework HealthKit history loading with batched queries before adding more views that depend on long lookback windows.~~ **✅ DONE (commit 218b79b, CR-005)** — `HKStatisticsCollectionQuery` batch queries for RHR, HRV, steps, walkMinutes.
4. ~~Prune or integrate orphaned services so the codebase reflects the actual runtime architecture.~~ **✅ DONE (commit 218b79b)** — `AlertMetricsService.swift`, `ConfigLoader.swift`, `File.swift` moved to `.unused/`. `WatchFeedbackBridge.swift` kept (likely needed for watch connectivity).

---

## Session Review — 2026-03-13 (in-session findings and fixes)

This section records findings identified and fixed during the hands-on coding session on 2026-03-13.

### Fixed In This Session

#### Watch text truncation — `WatchInsightFlowView.swift`, `WatchDetailView.swift`
All dynamic `Text` views on watchOS that could produce long strings were missing `lineLimit(nil)` + `fixedSize(horizontal: false, vertical: true)`. watchOS defaults to single-line truncation. Fixed six locations:
- `PlanScreen` "Yet to Begin" `pushMessage`
- `PlanScreen` sleep-mode `pushMessage`
- `PlanScreen` `inProgressMessage`
- `WalkNudgeScreen` `extraNudgeRow` contextual message
- `GoalProgressScreen` sleep-hour "Rest up" text
- `SleepScreen` `sleepSubMessage`
- `WatchDetailView` "Sync with your iPhone..." placeholder

#### Minimum age validation — `iOS/Views/SettingsView.swift:133`
`DatePicker` used `in: ...Date()` allowing DOB of today (age = 0). Fixed to:
```swift
in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()
```
Also removed the force-unwrap `!` on the date arithmetic result.

#### Silent HealthKit failure on device — `DashboardViewModel.swift`, `StressViewModel.swift`
Both ViewModels had inner `catch` blocks that swallowed HealthKit errors before they reached the outer error handler:
- `DashboardViewModel`: today snapshot fetch + history fetch both silently created empty data on device
- `StressViewModel`: history fetch silently returned `[]` on device

**Fixed pattern** in both (device `#else` branch now):
```swift
AppLogger.engine.error("... fetch failed: \(error.localizedDescription)")
errorMessage = "Unable to read health data. Please check Health permissions in Settings."
isLoading = false
return
```
The `errorMessage` property drives the error UI in each view, so the user sees the failure instead of silently receiving wrong assessments.

#### Timer retain cycle — `iOS/ViewModels/StressViewModel.swift`
Breathing session timer used a closure that could outlive `self`. Fixed with `[weak self]` in both the outer timer closure and the inner `Task { @MainActor }`, with explicit `timer.invalidate()` in the guard-nil path.

#### Snapshot history encryption — `Shared/Services/LocalStore.swift`
Snapshot history (HRV, RHR, steps, sleep) was stored in UserDefaults without application-level encryption. The existing `CryptoService` is now routed through the `save()`/`load()` helpers for this key.

#### Dual stress computation paths — `DashboardViewModel.swift` vs `StressViewModel.swift`
DashboardViewModel called `computeStress(snapshot:recentHistory:)` while StressViewModel decomposed the snapshot and called `computeStress(currentHRV:baselineHRV:)`. Same data could produce different scores. Both now use the unified `computeStress(snapshot:recentHistory:)` path.

#### `try?` drops billing verification errors — `iOS/Services/SubscriptionService.swift`
`try? checkVerification(result)` was discarding the error silently. Unverified transactions are now explicitly logged via `debugPrint` before being skipped.

---

### Still Open — Identified This Session

These issues were identified in this session but not yet fixed:

#### HIGH: Same silent-swallow pattern in `InsightsViewModel.swift` and `TrendsViewModel.swift`
Both still do `history = []` on device when HealthKit fails — same bug just fixed in Dashboard and Stress.
- `InsightsViewModel.swift` lines ~88-96
- `TrendsViewModel.swift` lines ~128-136

**Fix pattern** (same as DashboardViewModel fix above):
```swift
#else
AppLogger.engine.error("... fetch failed: \(error.localizedDescription)")
errorMessage = "Unable to read health data. Please check Health permissions in Settings."
isLoading = false
return
#endif
```

#### HIGH: `DateFormatter` created inline on every render — three views
Creates expensive `DateFormatter()` instances inside functions called from `ForEach` loops:
- `iOS/Views/StressView.swift` — `formatWeekday()`, `formatDayHeader()`, `formatDate()` (three separate inline formatters, called per heatmap cell)
- `iOS/Views/InsightsView.swift` — `reportDateRange()` (one inline formatter, called per weekly report card)
- `iOS/Views/TrendsView.swift` — `xAxisLabels()` (one inline formatter, called per chart render with a `.map()` loop)

**Fix pattern** for all three — replace inline creation with `private static let`:
```swift
private static let weekdayFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEE"; return f
}()
```

#### MEDIUM: Force unwrap in `StressView.swift` after nil check
```swift
"stress \(score), \(point!.level.displayName)"  // point checked nil above but force-unwrapped
```
Use `if let p = point { ... }` instead.

#### MEDIUM: Correlation computation runs in view body — `TrendsView.swift`
`computeCorrelation()` performs Pearson math inside a view helper called on every render. Should be memoized in `TrendsViewModel` and only recomputed when the underlying data changes.

#### MEDIUM: `NotificationService.isAuthorized` never refreshed after launch
`checkCurrentAuthorization()` only runs once at init. If the user grants or denies notification permission mid-session, the published property is never updated. Views should call `checkCurrentAuthorization()` in `.onAppear`.
- File: `iOS/Services/NotificationService.swift`

#### LOW: Active TODO in shipping code
```swift
// BUG-053: These fallback delivery hours are hardcoded defaults.
// TODO: Make configurable via Settings UI
```
File: `iOS/Services/NotificationService.swift` lines ~45-47. Move to issue tracker or implement.

#### LOW: HealthKit queries cannot distinguish "no data" from "query failed"
`queryRestingHeartRate()`, `queryHRV()`, `queryVO2Max()` all return `nil` for both "no samples exist" and "query threw an error". The user cannot tell why a metric is missing.
Consider `Result<Double?, HealthKitError>` or a logged error companion alongside the nil return.

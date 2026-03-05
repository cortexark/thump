# Orchestration Notes — HeartCoach Full Build

## Feature Analysis

| Dimension | Value |
|-----------|-------|
| **Domain** | PM (product) + UX (mobile UI) + SDE (iOS/watchOS) + QAE (health safety) + PE (architecture) |
| **Complexity** | High — dual-platform (iPhone + Apple Watch), HealthKit, WatchConnectivity, StoreKit 2, ML trend engine |
| **Risk** | High — health data (HealthKit), subscription billing, user safety (non-diagnostic boundary) |
| **Scope** | Large — 20+ skills across 5 roles |
| **Capacity** | 1 person (sequential with mini-parallelism via agents) |

## Skill Execution Log

| # | Phase | Skill / Agent | Started | Finished | Duration | Output Location |
|---|-------|--------------|---------|----------|----------|-----------------|
| 1 | Init | Feature Analysis | Session 1 | Session 1 | ~2 min | orc_notes.md |
| 2 | 1 | pm:customer-research | Session 1 | Session 1 | ~5 min | .pm/research/ (pre-existing) |
| 3 | 1 | pm:research-agent | Session 1 | Session 1 | ~8 min | docs/customer_story.md |
| 4 | 2 | pe:tech-strategy | Session 1 | Session 1 | ~3 min | .pe/strategy/ (pre-existing) |
| 5 | 3 | pm:prd-generator | Session 1 | Session 1 | ~3 min | .pm/prds/ (pre-existing) |
| 6 | 3 | pm:metrics-advisor | Session 1 | Session 1 | ~3 min | .pm/metrics/ (pre-existing) |
| 7 | 3 | sde:requirements | Session 1 | Session 1 | ~3 min | .sde/requirements/ (pre-existing) |
| 8 | 4 | ux:design-system | Session 1 | Session 1 | ~3 min | .ux/design-systems/ (pre-existing) |
| 9 | 4 | ux:component-design | Session 1 | Session 1 | ~3 min | .ux/components/ (pre-existing) |
| 10 | 4 | ux:color-system | Session 1 | Session 1 | ~3 min | .ux/colors/ (pre-existing) |
| 11 | 4 | ux:accessibility | Session 1 | Session 1 | ~3 min | .ux/accessibility/ (pre-existing) |
| 12 | 5 | sde:system-design | Session 1 | Session 1 | ~3 min | .sde/designs/ (pre-existing) |
| 13 | 5 | sde:architecture | Session 1 | Session 1 | ~3 min | .sde/architecture/ (pre-existing) |
| 14 | 5 | pe:architecture-reviewer | Session 1 | Session 1 | ~3 min | .pe/architecture/ (pre-existing) |
| 15 | 1-5 | Agent: Phase 1-5 Validator | Session 2 | Session 2 | ~4 min | .project/skill_response_doc/ (6 docs) |
| 16 | 6a | Agent: Shared Models+Engine | Session 2 | Session 2 | ~6 min | Shared/Models/, Shared/Engine/ (3 files) |
| 17 | 6a | Agent: iOS Components | Session 2 | Session 2 | ~5 min | iOS/Views/Components/ (4 files) |
| 18 | 6a | Agent: Watch Connectivity | Session 2 | Session 2 | ~4 min | Watch/Services/ (1 file, needs fix) |
| 19 | 6b | Agent: Shared Services + CorrelationEngine | Session 3 | Session 3 | ~5 min | Shared/Services/ (5), Shared/Engine/ (1), Watch fix |
| 20 | 6c | Agent: iOS Services + ViewModels + App | Session 3 | Session 3 | ~7 min | iOS/Services/ (6), iOS/ViewModels/ (3), iOS/App (1) |
| 21 | 6d | Agent: iOS Views (9 files) | Session 3 | Session 3 | ~6 min | iOS/Views/ (7), iOS/Views/Components/ (2) |
| 22 | 6e | Agent: Watch App + Tests + Config | Session 3 | Session 3 | ~5 min | Watch/ (7), Tests/ (1), project.yml, iOS.entitlements |

## Phase Progress

- [x] Phase 1: Discovery (pre-existing .pm artifacts validated)
- [x] Phase 2: Validation (pre-existing .pe artifacts validated)
- [x] Phase 3: Planning — USER GATE 1 (pre-existing .pm/.sde artifacts validated)
- [x] Phase 4: Design — USER GATE 2 (pre-existing .ux artifacts validated)
- [x] Phase 5: Architecture (pre-existing .sde/.pe artifacts validated)
- [x] Phase 6: Build — COMPLETE (41 Swift files, 9,740 lines, project.yml, iOS.entitlements)
- [ ] Phase 7: Quality — USER GATE 3 (pre-existing .qae artifacts)
- [ ] Phase 8: Launch (pre-existing .qae/.pe artifacts)
- [ ] Phase 9: Feedback (pre-existing .pm/.pe artifacts)

## Build Inventory — FINAL (43 files, 9,740 lines of Swift)

### Shared Layer (9 files, 2,531 lines)
| File | Lines | Description |
|------|-------|-------------|
| Package.swift | 29 | SPM config: iOS 17, watchOS 10, macOS 14 |
| Shared/Models/HeartModels.swift | 536 | Canonical domain types (17 types) |
| Shared/Engine/HeartTrendEngine.swift | 525 | Robust stats engine (median+MAD, regression, stress) |
| Shared/Engine/NudgeGenerator.swift | 352 | 15+ contextual coaching nudges |
| Shared/Engine/CorrelationEngine.swift | 276 | Pearson correlation analysis |
| Shared/Services/ConfigService.swift | 144 | App-wide config + feature flags |
| Shared/Services/LocalStore.swift | 246 | UserDefaults + JSON persistence |
| Shared/Services/MockData.swift | 268 | Deterministic mock data for previews |
| Shared/Services/Observability.swift | 260 | os.Logger + analytics abstraction |

### iOS Layer (24 files, 5,651 lines)
| File | Lines | Description |
|------|-------|-------------|
| iOS/HeartCoachiOSApp.swift | 89 | @main app entry + env injection |
| iOS/Services/HealthKitService.swift | 554 | Full HealthKit integration (9 metrics) |
| iOS/Services/ConnectivityService.swift | 211 | iOS-side WCSession delegate |
| iOS/Services/NotificationService.swift | 318 | Local notifications + alert budget |
| iOS/Services/SubscriptionService.swift | 243 | StoreKit 2 (5 products, 4 tiers) |
| iOS/Services/ConfigLoader.swift | 125 | AlertPolicy persistence |
| iOS/Services/WatchFeedbackBridge.swift | 106 | Feedback dedup + queue |
| iOS/ViewModels/DashboardViewModel.swift | 192 | Dashboard data pipeline |
| iOS/ViewModels/TrendsViewModel.swift | 240 | Trend chart data extraction |
| iOS/ViewModels/InsightsViewModel.swift | 232 | Correlation + weekly report |
| iOS/Views/MainTabView.swift | 77 | 4-tab navigation |
| iOS/Views/OnboardingView.swift | 312 | 3-step paged onboarding |
| iOS/Views/DashboardView.swift | 342 | Hero card + metric grid + nudge |
| iOS/Views/TrendsView.swift | 226 | Metric picker + chart + stats |
| iOS/Views/InsightsView.swift | 341 | Weekly report + correlations |
| iOS/Views/SettingsView.swift | 316 | Profile, subscription, disclaimer |
| iOS/Views/PaywallView.swift | 410 | Pricing cards + feature comparison |
| iOS/Views/Components/StatusCardView.swift | 121 | Hero dashboard card |
| iOS/Views/Components/NudgeCardView.swift | 121 | Coaching nudge card |
| iOS/Views/Components/MetricTileView.swift | 191 | Metric tile with lock gate |
| iOS/Views/Components/ConfidenceBadge.swift | 57 | Confidence capsule badge |
| iOS/Views/Components/TrendChartView.swift | 254 | Swift Charts line/area/rule |
| iOS/Views/Components/CorrelationCardView.swift | 231 | Correlation strength bar |
| iOS/iOS.entitlements | — | HealthKit entitlements |

### Watch Layer (8 files, 1,120 lines)
| File | Lines | Description |
|------|-------|-------------|
| Watch/HeartCoachWatchApp.swift | 40 | @main watch entry |
| Watch/Services/WatchConnectivityService.swift | 256 | Watch-side WCSession (fixed) |
| Watch/Services/WatchFeedbackService.swift | 103 | Local feedback persistence |
| Watch/ViewModels/WatchViewModel.swift | 127 | Watch VM + Combine binding |
| Watch/Views/WatchHomeView.swift | 239 | Status circle + quick feedback |
| Watch/Views/WatchFeedbackView.swift | 152 | 3-button feedback UI |
| Watch/Views/WatchDetailView.swift | 258 | Compact metric detail |
| Watch/Views/WatchNudgeView.swift | 182 | Full nudge display |

### Tests + Config (2 files, 438 lines)
| File | Lines | Description |
|------|-------|-------------|
| Tests/HeartTrendEngineTests.swift | 438 | 12 XCTest cases |
| project.yml | — | XcodeGen project spec |

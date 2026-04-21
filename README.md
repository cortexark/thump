# Thump — Your Heart Training Buddy

A native iOS 17+ and watchOS 10+ app that helps users understand their heart health trends through Apple Watch data, personalized insights, and gentle wellness nudges.

## Video Demo

![Thump Landing Page Demo](apps/HeartCoach/web/Thump_Landing_Page.gif)

- Full product demo (iOS + Watch + Website): https://github.com/cortexark/thump/raw/main/apps/HeartCoach/web/demos/thump-demo.mp4
- iOS app demo: https://github.com/cortexark/thump/raw/main/apps/HeartCoach/web/demos/ios-demo.mp4
- Apple Watch demo: https://github.com/cortexark/thump/raw/main/apps/HeartCoach/web/demos/watch-demo.mp4
- Website demo: https://github.com/cortexark/thump/raw/main/apps/HeartCoach/web/demos/website-demo.mp4
- Landing page full video: https://github.com/cortexark/thump/raw/main/apps/HeartCoach/web/Thump_Landing_Page.mp4

## What It Does

Thump reads 9 key heart and fitness metrics from Apple Watch via HealthKit, runs trend analysis and correlation detection, then delivers personalized wellness nudges — all without storing health data on any server.

**Key Features:**
- Real-time heart health dashboard with cardio score, trend direction, and confidence badge
- 7-day / 14-day / 30-day trend charts for all tracked metrics
- Correlation engine that discovers relationships between your habits and heart health
- Personalized daily nudges based on your data patterns
- Apple Watch companion app with quick feedback and nudge tracking
- Weekly insight reports with actionable takeaways

**Metrics Tracked:**
| Metric | Source | Watch Compatibility |
|--------|--------|-------------------|
| Resting Heart Rate | HealthKit | Series 4+ |
| Heart Rate Variability (SDNN) | HealthKit | Series 4+ |
| Recovery Heart Rate | HealthKit | Series 4+ |
| VO2 Max | HealthKit | Series 4+ |
| Heart Rate (live) | HealthKit | Series 4+ |
| Steps | HealthKit | Series 4+ |
| Walking Minutes | HealthKit | Series 4+ |
| Active Energy | HealthKit | Series 4+ |
| Sleep Hours | HealthKit | Series 4+ |

All 9 metrics work on every Apple Watch model running watchOS 10+ (Series 4 and later). No Blood Oxygen or ECG features are used.

## Architecture

```
apps/HeartCoach/
  iOS/                          # iPhone app
    ThumpiOSApp.swift           # App entry point
    Services/
      HealthKitService.swift    # HealthKit data queries
      SubscriptionService.swift # StoreKit 2 subscriptions
      NotificationService.swift # Local notifications + nudge scheduling
      ConnectivityService.swift # WatchConnectivity (iOS side)
      MetricKitService.swift    # Crash reporting via MetricKit
      AnalyticsEvents.swift     # Analytics event definitions
    ViewModels/
      DashboardViewModel.swift  # Main dashboard logic
      TrendsViewModel.swift     # Historical trend data
      InsightsViewModel.swift   # Correlations + weekly reports
    Views/
      DashboardView.swift       # Home screen
      TrendsView.swift          # Charts + time range picker
      InsightsView.swift        # Correlations + insights
      OnboardingView.swift      # Welcome + HealthKit + disclaimer
      PaywallView.swift         # Subscription tiers
      SettingsView.swift        # Profile + preferences
      Components/               # Reusable UI components
  Watch/                        # Apple Watch app
    ThumpWatchApp.swift         # Watch entry point
    Services/
      WatchConnectivityService.swift  # WatchConnectivity (watch side)
      WatchFeedbackService.swift      # Daily feedback persistence
    ViewModels/
      WatchViewModel.swift      # Watch UI state management
    Views/
      WatchHomeView.swift       # Main watch screen
      WatchNudgeView.swift      # Active nudge display
      WatchFeedbackView.swift   # Thumbs up/down feedback
      WatchDetailView.swift     # Metric detail screen
  Shared/                       # Code shared between iOS + Watch
    Models/
      HeartModels.swift         # HeartSnapshot, HeartAssessment, enums
    Engine/
      HeartTrendEngine.swift    # Trend analysis + cardio scoring
      CorrelationEngine.swift   # Cross-metric correlation detection
      NudgeGenerator.swift      # Personalized nudge selection
    Services/
      LocalStore.swift          # Encrypted UserDefaults persistence
      CryptoService.swift       # AES-GCM encryption via CryptoKit
      ConfigService.swift       # Feature flags + remote config
  web/                          # Landing page + legal
    index.html                  # Marketing landing page
    privacy.html                # Privacy policy
    terms.html                  # Terms of service
    disclaimer.html             # Health disclaimer
  project.yml                   # XcodeGen project spec
  Package.swift                 # Swift Package manifest
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI |
| Health Data | HealthKit |
| Watch Comms | WatchConnectivity |
| Subscriptions | StoreKit 2 |
| Charts | Swift Charts |
| Encryption | CryptoKit (AES-GCM) |
| Key Storage | Keychain Services |
| Crash Reporting | MetricKit |
| Notifications | UserNotifications |
| Project Gen | XcodeGen |
| Min iOS | 17.0 |
| Min watchOS | 10.0 |
| Swift | 5.9 |

## Privacy & Security

- **Health data stays on-device** — never uploaded to any server
- **AES-GCM encryption at rest** — health snapshots encrypted before storing in UserDefaults
- **Encryption key in Keychain** — `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- **Anonymous usage analytics** — no personally identifiable information collected
- **No Blood Oxygen / ECG** — avoids restricted HealthKit capabilities
- **PrivacyInfo.xcprivacy** — Apple privacy manifest included
- **General wellness positioning** — not a medical device, FDA general wellness exemption

## Subscription Tiers

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | Dashboard, basic trends (7-day) |
| Coach | $4.99/mo or $39.99/yr | Extended trends (30-day), correlations, weekly reports, nudges |
| Family | $14.99/yr (annual only) | Coach features for up to 6 family members |

## Building

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project:
   ```bash
   cd apps/HeartCoach
   xcodegen generate
   ```

3. Open in Xcode:
   ```bash
   open Thump.xcodeproj
   ```

4. Select the `Thump` scheme for iOS or `ThumpWatch` scheme for watchOS, then build and run.

**Requirements:**
- Xcode 15.0+
- iOS 17.0+ device or simulator
- watchOS 10.0+ Apple Watch (for watch features)
- Apple Developer account (for HealthKit entitlements)

## Landing Page

Preview the marketing landing page locally:
```bash
cd apps/HeartCoach/web
python3 -m http.server 8080
# Open http://localhost:8080
```

Includes investor demo video (`Thump_Landing_Page.mp4` / `.gif`).

## Research Data

The `data/` and `scripts/` directories contain the Reddit trend analysis pipeline used for market research:

- **`scripts/crawl_reddit.py`** — Crawls r/AppleWatchFitness for posts, comments, and screenshots
- **`scripts/analyze_trends.py`** — Taxonomy labeling, trend aggregation, and report generation
- **`scripts/health_anomaly_engine.py`** — User-level anomaly detection prototype
- **`data/raw/`** — Raw crawl outputs
- **`data/processed/`** — Labeled trends, co-occurrence matrices, analysis summary

Run the full pipeline:
```bash
./scripts/run_pipeline.sh AppleWatchFitness
```

## Quality Assurance

The codebase has been through 4 rounds of automated QAE/SDE review:

- **Round 1**: 55 bugs found and fixed (crashes, data races, missing entitlements, broken UI)
- **Round 2**: 8 regressions caught and fixed (compile errors, actor isolation)
- **Round 3**: 2 residual issues caught and fixed (Keychain race, thread safety)
- **Round 4**: 1 final issue caught and fixed (Combine subscription isolation)
- **Result**: Zero defects across all 84 files

Key fixes applied:
- Thread-safe `@MainActor` isolation on all `ObservableObject` classes
- NSLock serialization on CryptoService key generation
- HealthKit authorization handling aligned with Apple's privacy design
- StoreKit 2 purchase validation (family tier annual-only guard)
- Notification alert rate limiting with proper main-thread persistence
- WatchConnectivity delegate methods properly `nonisolated` with `Task { @MainActor in }` hops

## License

Proprietary. All rights reserved.

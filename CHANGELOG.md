# Changelog

All notable changes to the Thump project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-05

### Added
- iOS 17+ app with SwiftUI dashboard, trends, insights, and settings
- watchOS 10+ companion app with assessment display, feedback, and nudge tracking
- HealthKit integration for 9 heart and fitness metrics
- HeartTrendEngine for cardio scoring and trend direction analysis
- CorrelationEngine for cross-metric relationship detection
- NudgeGenerator for personalized wellness nudge selection
- WatchConnectivity bidirectional sync between iPhone and Apple Watch
- StoreKit 2 subscription system (Free, Coach, Family tiers)
- AES-GCM encryption at rest for health data via CryptoKit
- Keychain-stored symmetric encryption keys
- MetricKit crash reporting integration
- Pluggable analytics via ObservabilityService protocol
- Local notification scheduling for nudge reminders and anomaly alerts
- Onboarding flow with HealthKit permissions and health disclaimer
- PaywallView with monthly/annual toggle and tier comparison
- SettingsView with profile, subscription management, and legal links
- TrendChartView with 7D/14D/30D time ranges via Swift Charts
- Weekly insight reports with nudge completion tracking
- Accessibility labels on all interactive UI components
- Marketing landing page with responsive design and investor video
- Privacy policy, terms of service, and health disclaimer pages
- Open Graph and Twitter Card meta tags for social sharing
- PrivacyInfo.xcprivacy privacy manifest for App Store compliance
- XcodeGen project.yml for reproducible Xcode project generation

### Security
- NSLock serialization on encryption key generation to prevent race conditions
- iCloud Keychain sync-safe key storage (re-read on duplicate, never overwrite)
- Thread-safe @MainActor isolation on all ObservableObject classes
- JSONSerialization input validation before deserialization
- Health data never leaves device; encrypted before local persistence
- HealthKit entitlements scoped to read-only (no health-records access)

### Fixed
- 66 bugs found and resolved across 4 QAE/SDE review iterations
- PaywallView infinite alert loop from .constant() binding
- TrendChartView crash on identical data points (zero-range scale)
- HealthKitService crash on days==0 and force-unwrapped type constructors
- CryptoService key race condition on concurrent first-launch
- NotificationService alert rate limiting race condition
- WatchConnectivity delegate thread safety across iOS and watchOS
- OnboardingView HealthKit denial incorrectly treated as granted
- DashboardView stub properties shadowing real ViewModel data
- SettingsView subscription tier always showing Free
- WatchHomeView thumbs-down icon never filling after feedback
- WatchViewModel nudge completion resetting on every assessment
- Family plan purchase guard (annual-only enforcement)
- Mobile menu toggle broken on first tap (landing page)
- Terms of service jurisdiction updated to California
- HIPAA label replaced with accurate "Health Data Privacy"

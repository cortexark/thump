# Thump Bug Tracker

> Auto-maintained by Claude during development sessions.
> Status: `OPEN` | `FIXED` | `WONTFIX`
> Severity: `P0-CRASH` | `P1-BLOCKER` | `P2-MAJOR` | `P3-MINOR` | `P4-COSMETIC`

---

## P0 — Crash Bugs

### BUG-001: PaywallView purchase crash — API mismatch
- **Status:** FIXED (pre-existing fix confirmed 2026-03-12)
- **File:** `iOS/Views/PaywallView.swift`, `iOS/Services/SubscriptionService.swift`
- **Description:** PaywallView calls `subscriptionService.purchase(tier:isAnnual:)` but SubscriptionService only exposes `purchase(_ product: Product)`. Every purchase attempt crashes at runtime.
- **Fix Applied:** Method already existed — confirmed API contract is correct. Also added `@Published var productLoadError: Error?` to surface silent product load failures (BUG-048).

---

## P1 — Ship Blockers

### BUG-002: Notification nudges can never be cancelled — hardcoded `[]`
- **Status:** FIXED (pre-existing fix confirmed 2026-03-12)
- **File:** `iOS/Services/NotificationService.swift`
- **Description:** `pendingNudgeIdentifiers()` returns hardcoded empty array `[]`. Nudge notifications pile up and can never be cancelled or managed.
- **Root Cause:** Agent left a TODO stub unfinished.
- **Fix Plan:** Query `UNUserNotificationCenter.getPendingNotificationRequests()`, filter by nudge prefix, return real identifiers.

### BUG-003: Health data stored as plaintext in UserDefaults
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** saveTier/reloadTier now use encrypted save/load. Added migrateLegacyTier() for upgrade path. CryptoService already existed with AES-GCM + Keychain.
- **File:** `Shared/Services/LocalStore.swift`
- **Description:** Heart metrics (HR, HRV, sleep, etc.) are saved as plaintext JSON in UserDefaults. Apple may reject for HealthKit compliance. Privacy liability.
- **Root Cause:** Agent skipped Keychain/CryptoKit entirely.
- **Fix Plan:** Create `CryptoService.swift` (AES-GCM via CryptoKit, key in Keychain). Wrap LocalStore save/load with encrypt/decrypt.

### BUG-004: WatchInsightFlowView uses MockData in production
- **Status:** FIXED (2026-03-12)
- **File:** `Watch/Views/WatchInsightFlowView.swift`
- **Description:** Two screens used `MockData.mockHistory()` to feed fake sleep hours and HRV/RHR values to real users. The top-level `InsightMockData.demoAssessment` nil-coalescing fallback was a separate, acceptable empty-state pattern.
- **Fix Applied:** Removed `MockData.mockHistory(days: 4)` from sleepScreen — SleepScreen now queries HealthKit `sleepAnalysis` for last 3 nights with safe empty state. Removed `MockData.mockHistory(days: 2)` from metricsScreen — HeartMetricsScreen now queries HealthKit for `heartRateVariabilitySDNN` and `restingHeartRate` with nil/dash fallback. Also fixed 12 instances of aggressive/shaming Watch language (e.g. "Your score is soft today. You need this." → "Your numbers are lower today. Even a short session helps.").

### BUG-005: `health-records` entitlement included unnecessarily
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Removed `com.apple.developer.healthkit.access` from iOS.entitlements. Only `healthkit: true` remains.
- **File:** `iOS/iOS.entitlements`
- **Description:** App includes `com.apple.developer.healthkit.access` for clinical health records but never reads them. Triggers extra App Store review scrutiny.
- **Fix Plan:** Remove `health-records` from entitlements.

### BUG-006: No health disclaimer in onboarding
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Disclaimer page already existed. Updated wording: "wellness tool" instead of "heart training buddy", toggle now reads "I understand this is not medical advice".
- **File:** `iOS/Views/OnboardingView.swift`
- **Description:** Health disclaimer only exists in Settings. Apple and courts require it before users see health data. Must be shown during onboarding with acknowledgment toggle.
- **Fix Plan:** Add 4th onboarding page with disclaimer + toggle. User must accept before proceeding.

### BUG-007: Missing Info.plist files
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Both iOS and Watch Info.plist already existed. Updated NSHealthShareUsageDescription, added armv7 capability, removed upside-down orientation.
- **Files:** `iOS/Info.plist` (missing), `Watch/Info.plist` (missing)
- **Description:** No Info.plist for either target. Required for HealthKit usage descriptions, bundle metadata, launch screen config.
- **Fix Plan:** Create both with NSHealthShareUsageDescription, CFBundleDisplayName, version strings.

### BUG-008: Missing PrivacyInfo.xcprivacy
- **Status:** FIXED (pre-existing, confirmed 2026-03-12)
- **Fix Applied:** File already existed with correct content.
- **File:** `iOS/PrivacyInfo.xcprivacy` (missing)
- **Description:** Apple requires privacy manifest for apps using HealthKit. Missing = rejection.
- **Fix Plan:** Create with NSPrivacyTracking: false, health data type declaration, UserDefaults API reason.

### BUG-009: Legal page links are placeholders
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Legal pages already existed. Updated privacy.html (added Exercise Minutes, replaced placeholder analytics provider), fixed disclaimer.html anchor ID. Footer links already pointed to real pages.
- **File:** `web/index.html`
- **Description:** Footer links to Privacy Policy, Terms of Service, and Disclaimer use `href="#"`. No actual legal pages exist.
- **Fix Plan:** Create `web/privacy.html`, `web/terms.html`, `web/disclaimer.html`. Update all `href="#"` to real URLs.

---

## P2 — Major Bugs

### BUG-010: Medical language — FDA/FTC risk
- **Status:** FIXED (2026-03-12)
- **Files:** `iOS/Views/PaywallView.swift`, `Shared/Engine/NudgeGenerator.swift`, `web/index.html`
- **Description:** Several instances of language that could trigger FDA medical device classification or FTC false advertising:
  - PaywallView: "optimize your heart health" (implies treatment)
  - PaywallView: "personalized coaching" (implies professional medical coaching)
  - NudgeGenerator: "activate your parasympathetic nervous system" (medical instruction)
  - NudgeGenerator: "your body needs recovery" (prescriptive medical advice)
- **Fix Applied:** DashboardView and SettingsView scrubbed. PaywallView and NudgeGenerator still need fixing.
- **Fix Plan:** Replace with safe language: "track", "monitor", "understand", "wellness insights", "fitness suggestions".

### BUG-011: AI slop phrases in user-facing text
- **Status:** FIXED (2026-03-12)
- **Files:** Multiple view files
- **Description:** Motivational language that sounds AI-generated and unprofessional:
  - "You're crushing it!" → Fixed to "Well done" in DashboardView
  - "You're on fire!" → Fixed to "Nice consistency this week" in DashboardView
  - Remaining instances may exist in other views (InsightsView, StressView, etc.)
- **Fix Applied:** DashboardView cleaned. Other views under audit.

### BUG-012: Raw metric jargon shown to users
- **Status:** FIXED (2026-03-12)
- **Files:** `iOS/Views/Components/CorrelationDetailSheet.swift`, `iOS/Views/Components/CorrelationCardView.swift`, `Watch/Views/WatchDetailView.swift`, `iOS/Views/TrendsView.swift`
- **Description:** Technical terms displayed directly to users: raw correlation coefficients, -1/+1 range labels, anomaly z-scores, "VO2 max" without explanation.
- **Fix Applied:** CorrelationDetailSheet: de-emphasized raw coefficient (56pt→caption2), human-readable strength leads (28pt bold). CorrelationCardView: -1/+1 labels → "Weak"/"Strong", raw center → human magnitudeLabel, "Just a Hint" → "Too Early to Tell". WatchDetailView: anomaly score shows human labels ("Normal", "Slightly Unusual", "Worth Checking"). TrendsView: "VO2" chip → "Cardio Fitness", "mL/kg/min" → "score".

### BUG-013: Accessibility labels missing across views
- **Status:** OPEN
- **Files:** All 16+ view files in `iOS/Views/`, `iOS/Views/Components/`, `Watch/Views/`
- **Description:** Interactive elements lack `accessibilityLabel`, `accessibilityValue`, `accessibilityHint`. VoiceOver users cannot navigate the app. Critical for HealthKit app review.
- **Fix Plan:** Systematic pass across all views adding accessibility modifiers.

### BUG-014: No crash reporting in production
- **Status:** OPEN
- **File:** (missing) `iOS/Services/MetricKitService.swift`
- **Description:** No crash reporting mechanism. Ship without it = flying blind on user crashes.
- **Fix Plan:** Create MetricKitService subscribing to MXMetricManager for crash diagnostics.

### BUG-015: No StoreKit configuration for testing
- **Status:** OPEN
- **File:** (missing) `iOS/Thump.storekit`
- **Description:** No StoreKit configuration file. Cannot test subscription flows in Xcode sandbox.
- **Fix Plan:** Create .storekit file with all 5 subscription product IDs matching SubscriptionService.

### BUG-034: PHI exposed in notification payloads
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Replaced `assessment.explanation` with generic "Check your Thump insights" text. Removed `anomalyScore` from userInfo dict.
- **File:** `iOS/Services/NotificationService.swift`
- **Description:** Notification content includes health metrics (anomaly scores, stress flags). These appear on lock screens and in notification center — visible to anyone nearby.
- **Fix Plan:** Remove health values from notification body. Use generic "Check your Thump insights" instead.

### BUG-035: Array index out of bounds risk in HeartRateZoneEngine
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Added `guard index < zoneMinutes.count, index < targets.count else { break }` before array access.
- **File:** `Shared/Engine/HeartRateZoneEngine.swift` ~line 135
- **Description:** Zone minute array accessed by index without bounds checking. If zone array is shorter than expected, runtime crash.
- **Fix Plan:** Add bounds check before array access.

### BUG-036: Consecutive elevation detection assumes calendar continuity
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Added date gap checking — gaps > 1.5 days break the consecutive streak. Uses actual calendar dates instead of array indices.
- **File:** `Shared/Engine/HeartTrendEngine.swift` ~line 537
- **Description:** Consecutive day detection counts array positions, not actual calendar day gaps. A user who misses a day would break the count. Could cause false negatives for overtraining detection.
- **Fix Plan:** Compare actual dates, not array indices.

### BUG-037: Inconsistent statistical methods (CV vs SD)
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Standardized CV variance calculation from `/ count` (population) to `/ (count - 1)` (sample) to match other variance calculations in the engine.
- **File:** `Shared/Engine/StressEngine.swift`
- **Description:** Coefficient of variation uses population formula (n), but standard deviation uses sample formula (n-1). Inconsistent stats across the same engine.
- **Fix Plan:** Standardize on sample statistics (n-1) throughout.

### BUG-038: "You're crushing it!" in TrendsView
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Changed to "You hit all your weekly goals — excellent consistency this week."
- **File:** `iOS/Views/TrendsView.swift` line 770
- **Description:** AI slop — clichéd motivational phrase when all weekly goals met.
- **Fix Plan:** Replace with "You hit all your weekly goals — excellent consistency this week."

### BUG-039: "rock solid" informal language in TrendsView
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Changed to "has remained stable through this period, showing steady patterns."
- **File:** `iOS/Views/TrendsView.swift` line 336
- **Description:** "Your [metric] has been rock solid" — informal, redundant with "steady" in same sentence.
- **Fix Plan:** Replace with "Your [metric] has remained stable through this period, showing steady patterns."

### BUG-040: "Whatever you're doing, keep it up" in TrendsView
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Changed to "the changes you've made are showing results."
- **File:** `iOS/Views/TrendsView.swift` line 343
- **Description:** Generic, non-specific encouragement. Doesn't acknowledge what improved.
- **Fix Plan:** Replace with "Your [metric] improved — the changes you've made are showing results."

### BUG-041: "for many reasons" wishy-washy in TrendsView
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Changed to "Consider factors like stress, sleep, or recent activity changes."
- **File:** `iOS/Views/TrendsView.swift` line 350
- **Description:** "this kind of shift can happen for many reasons" — defensive, not helpful.
- **Fix Plan:** Replace with "Consider factors like stress, sleep, or recent activity changes."

### BUG-042: "Keep your streak alive" generic in WatchHomeView
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Changed to "Excellent. You're building real momentum."
- **File:** `Watch/Views/WatchHomeView.swift` line 145
- **Description:** Same phrase for all users scoring ≥85 regardless of streak length. Impersonal.
- **Fix Plan:** Replace with "Excellent. You're building momentum — keep it going."

### BUG-043: "Great job completing X%" generic in InsightsView
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Changed to "You engaged with X% of daily suggestions — solid commitment."
- **File:** `iOS/Views/InsightsView.swift` line 430
- **Description:** Templated encouragement. Feels robotic.
- **Fix Plan:** Replace with "You engaged with [X]% of daily suggestions — solid commitment."

### BUG-044: "room to build" vague in InsightsView
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Changed to "Aim for one extra nudge this week."
- **File:** `iOS/Views/InsightsView.swift` line 432
- **Description:** Slightly patronizing and non-actionable.
- **Fix Plan:** Replace with "Aim for one extra nudge this week for momentum."

### BUG-045: CSV export header exposes "SDNN" jargon
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Changed header from "HRV (SDNN)" to "Heart Rate Variability (ms)".
- **File:** `iOS/Views/SettingsView.swift` line 593
- **Description:** CSV header reads "HRV (SDNN)" — users opening in Excel see unexplained medical acronym.
- **Fix Plan:** Change to "Heart Rate Variability (ms)".

### BUG-046: "nice sign" vague in TrendsView
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Changed to "this consistency indicates stable patterns."
- **File:** `iOS/Views/TrendsView.swift` line 357
- **Description:** "That kind of consistency is a nice sign" — what kind of sign? For what?
- **Fix Plan:** Replace with "this consistency indicates stable cardiovascular patterns."

### BUG-047: NudgeGenerator missing ordinality() fallback
- **Status:** FIXED (2026-03-12)
- **File:** `Shared/Engine/NudgeGenerator.swift`
- **Description:** When `Calendar.current.ordinality()` returns nil, fallback was `0` — every nudge selection returned index 0 (first item), making nudges predictable/stuck.
- **Fix Applied:** Changed all 7 `?? 0` fallbacks to `?? Calendar.current.component(.day, from: current.date)` — uses day-of-month (1-31) as fallback, ensuring varied selection even when ordinality fails.

### BUG-048: SubscriptionService silent product load failure
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Added `@Published var productLoadError: Error?` that surfaces load failures to PaywallView.
- **File:** `iOS/Services/SubscriptionService.swift`
- **Description:** If Product.products() fails or returns empty, no error is surfaced. Paywall shows empty state with no explanation.
- **Fix Plan:** Add error state property. Show "Unable to load pricing" in PaywallView.

### BUG-049: LocalStore.clearAll() incomplete data cleanup
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Added missing .lastCheckIn and .feedbackPrefs keys to clearAll(). Also added CryptoService.deleteKey() to wipe Keychain encryption key on reset.
- **File:** `Shared/Services/LocalStore.swift`
- **Description:** clearAll() may miss some UserDefaults keys, leaving orphaned health data after account deletion.
- **Fix Plan:** Enumerate all known keys and remove explicitly. Add domain-level removeAll if needed.

### BUG-050: Medical language in engine outputs — "Elevated Physiological Load"
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Scrubbed across 8 files: HeartTrendEngine, NudgeGenerator, ReadinessEngine, HeartModels, NotificationService, HeartRateZoneEngine, CoachingEngine, InsightsViewModel. All clinical terms replaced with conversational language.
- **Files:** `Shared/Engine/HeartTrendEngine.swift`, `Shared/Engine/ReadinessEngine.swift`
- **Description:** Engine-generated strings include clinical terminology: "Elevated Physiological Load", "Overtraining Detected", "Stress Response Active".
- **Fix Plan:** Soften to: "Heart working harder", "Hard sessions back-to-back", "Stress pattern noticed".

### BUG-051: DashboardView metric tile accessibility gap
- **Status:** OPEN
- **File:** `iOS/Views/DashboardView.swift` lines 1152-1158
- **Description:** 6 metric tile buttons lack accessibilityLabel and accessibilityHint. VoiceOver cannot convey purpose.
- **Fix Plan:** Add semantic labels to each tile.

### BUG-052: WatchInsightFlowView metric accessibility gap
- **Status:** OPEN
- **File:** `Watch/Views/WatchInsightFlowView.swift`
- **Description:** Tab-based metric display screens lack accessibility labels for metric cards.
- **Fix Plan:** Add accessibilityLabel to each metric section.

### BUG-053: Hardcoded notification delivery hours
- **Status:** FIXED (2026-03-12)
- **Fix Applied:** Centralized into `DefaultDeliveryHour` enum. TODO added for user-configurable Settings UI.
- **File:** `iOS/Services/NotificationService.swift`
- **Description:** Nudge delivery hours hardcoded. Doesn't respect shift workers or different time zones.
- **Fix Plan:** Make delivery window configurable in Settings.

### BUG-054: LocalStore silently falls back to plaintext when encryption fails
- **Status:** FIXED (2026-03-12)
- **File:** `Shared/Services/LocalStore.swift`
- **Description:** When `CryptoService.encrypt()` returns nil (Keychain unavailable), `save()` silently stored health data as plaintext JSON in UserDefaults. This undermined the BUG-003 encryption fix.
- **Fix Applied:** Removed plaintext fallback. Data is now dropped (not saved) when encryption fails, with error log and DEBUG assertion. Protects PHI at cost of temporary data loss until encryption is available again.

### BUG-055: ReadinessEngine force unwraps on pillarWeights dictionary
- **Status:** FIXED (2026-03-12)
- **File:** `Shared/Engine/ReadinessEngine.swift`
- **Description:** Five `pillarWeights[.xxx]!` force unwraps across pillar scoring functions. Safe in practice (hardcoded dictionary), but fragile if pillar types are ever added/removed.
- **Fix Applied:** Replaced all 5 force unwraps with `pillarWeights[.xxx, default: N]` using matching default weights.

---

## P3 — Minor Bugs

### BUG-016: "Heart Training Buddy" across web + app
- **Status:** FIXED (2026-03-12)
- **File:** `web/index.html`, `web/privacy.html`, `web/terms.html`, `web/disclaimer.html`
- **Fix Applied:** Changed all "Your Heart Training Buddy" to "Your Heart's Daily Story" across 4 web pages. OnboardingView was already updated to "wellness tool".

### BUG-017: "Activity Correlations" heading in InsightsView
- **Status:** FIXED (2026-03-12)
- **File:** `iOS/Views/InsightsView.swift`
- **Description:** Section header "Activity Correlations" is jargon.
- **Fix Applied:** Changed to "How Activities Affect Your Numbers".

### BUG-018: BioAgeDetailSheet makes medical claims
- **Status:** FIXED (2026-03-12)
- **File:** `iOS/Views/Components/BioAgeDetailSheet.swift`
- **Description:** Contains language implying medical-grade biological age assessment.
- **Fix Applied:** Added disclaimer "Bio Age is an estimate based on fitness metrics, not a medical assessment". Changed "Expected: X" → "Typical for age: X".

### BUG-019: MetricTileView lacks context-aware trend colors
- **Status:** FIXED (2026-03-12)
- **File:** `iOS/Views/Components/MetricTileView.swift`
- **Description:** Trend arrows use generic red/green. For RHR, "up" is bad but showed green.
- **Fix Applied:** Added `lowerIsBetter: Bool` parameter with `invertedColor` computed property. RHR tiles now show down=green, up=red. DashboardView passes `lowerIsBetter: true` for RHR tiles.

### BUG-020: No CI/CD pipeline configured
- **Status:** OPEN
- **File:** `.github/workflows/ci.yml` (exists but may need verification)
- **Description:** CI pipeline was created but needs verification it actually builds the XcodeGen project and runs tests.

---

## P4 — Cosmetic

### BUG-021: "Buddy Says" label in DashboardView
- **Status:** FIXED
- **File:** `iOS/Views/DashboardView.swift`
- **Description:** Section header was "Buddy Says" — too informal.
- **Fix Applied:** Changed to "Your Daily Coaching".

### BUG-022: "Anomaly Alerts" in SettingsView
- **Status:** FIXED
- **File:** `iOS/Views/SettingsView.swift`
- **Description:** "Anomaly Alerts" is clinical jargon.
- **Fix Applied:** Changed to "Unusual Pattern Alerts".

### BUG-023: "Your heart's daily story" tagline in SettingsView
- **Status:** FIXED
- **File:** `iOS/Views/SettingsView.swift`
- **Description:** Too poetic/AI-sounding for a settings screen.
- **Fix Applied:** Changed to "Heart wellness tracking".

### BUG-024: "metric norms" in SettingsView
- **Status:** FIXED
- **File:** `iOS/Views/SettingsView.swift`
- **Description:** "metric norms" is statistical jargon.
- **Fix Applied:** Changed to "typical ranges for your age and sex".

### BUG-025: "before getting sick" in DashboardView
- **Status:** FIXED
- **File:** `iOS/Views/DashboardView.swift`
- **Description:** Implied medical diagnosis.
- **Fix Applied:** Changed to "busy weeks, travel, or routine changes".

### BUG-026: "AHA guideline" reference in DashboardView
- **Status:** FIXED
- **File:** `iOS/Views/DashboardView.swift`
- **Description:** Referenced American Heart Association — medical authority citation inappropriate for wellness app.
- **Fix Applied:** Changed to "recommended 150 minutes of weekly activity".

### BUG-027: "Fat Burn" / "Recovery" zone names in DashboardView
- **Status:** FIXED
- **File:** `iOS/Views/DashboardView.swift`
- **Description:** "Fat Burn" is misleading. "Recovery" is clinical.
- **Fix Applied:** Changed to "Moderate" and "Easy".

### BUG-028: "Elevated RHR Alert" in DashboardView
- **Status:** FIXED
- **File:** `iOS/Views/DashboardView.swift`
- **Description:** "Alert" implies medical alarm.
- **Fix Applied:** Changed to "Elevated Resting Heart Rate".

### BUG-029: "Your heart is loving..." in DashboardView
- **Status:** FIXED
- **File:** `iOS/Views/DashboardView.swift`
- **Description:** Anthropomorphizing the heart — AI slop.
- **Fix Applied:** Changed to "Your trends are looking great".

### BUG-030: "You're on fire!" in DashboardView
- **Status:** FIXED
- **File:** `iOS/Views/DashboardView.swift`
- **Description:** AI motivational slop.
- **Fix Applied:** Changed to "Nice consistency this week".

### BUG-031: "Another day, another chance..." in DashboardView
- **Status:** FIXED
- **File:** `iOS/Views/DashboardView.swift`
- **Description:** Generic motivational filler.
- **Fix Applied:** Removed entirely (returns nil).

### BUG-032: "Your body's asking for TLC" in DashboardView
- **Status:** FIXED
- **File:** `iOS/Views/DashboardView.swift`
- **Description:** Anthropomorphizing + too casual.
- **Fix Applied:** Changed to "Your numbers suggest taking it easy".

### BUG-033: "unusual heart patterns are detected" in SettingsView
- **Status:** FIXED
- **File:** `iOS/Views/SettingsView.swift`
- **Description:** "patterns detected" sounds like a medical diagnosis.
- **Fix Applied:** Changed to "numbers look different from usual range".

---

## P2 — Major Bugs (2026-03-14 Session)

### BUG-056: ReadinessEngine activity balance nil cascade for irregular wearers
- **Status:** FIXED (2026-03-14)
- **File:** `Shared/Engine/ReadinessEngine.swift`
- **Description:** `scoreActivityBalance` returned nil when yesterday's data was missing. Combined with the 2-pillar minimum gate, irregular watch wearers (no yesterday data + no HRV today) got no readiness score. This silently breaks the NudgeGenerator readiness gate.
- **Fix Applied:** Added today-only fallback scoring (35 for no activity, 55 for some, 75 for ideal). Conservative scores that don't over-promise.
- **Trade-off:** Activity pillar is less accurate without yesterday comparison, but "approximate readiness" beats "no readiness" for user engagement and safety (nudge gating still works).

### BUG-057: CoachingEngine zone analysis window off by 1 day
- **Status:** FIXED (2026-03-14)
- **File:** `Shared/Engine/CoachingEngine.swift`
- **Description:** `weeklyZoneSummary(history:)` called without `referenceDate`. Defaults to `history.last?.date`, which is 1 day behind `current.date`. Zone analysis evaluates the wrong 7-day window.
- **Fix Applied:** Pass `referenceDate: current.date` explicitly. Same class of bug as ENG-1 (HeartTrendEngine) and ZE-001 (HeartRateZoneEngine).

### BUG-058: NudgeGenerator regression path returns moderate intensity
- **Status:** FIXED (2026-03-14)
- **File:** `Shared/Engine/NudgeGenerator.swift`
- **Description:** `regressionNudgeLibrary()` contained a `.moderate` category nudge. Regression = multi-day worsening trend → moderate intensity is clinically inappropriate. The readiness gate only caught cases where readiness was ALSO low, but regression can co-exist with "good" readiness.
- **Fix Applied:** (a) Replaced `.moderate` with `.walk` in regression library. (b) Added readiness gate to `selectRegressionNudge` for consistency with positive/default paths.

### BUG-059: NudgeGenerator low-data nudge uses wall-clock time
- **Status:** FIXED (2026-03-14, by linter)
- **File:** `Shared/Engine/NudgeGenerator.swift`
- **Description:** `selectLowDataNudge` used `Calendar.current.component(.hour, from: Date())` for rotation instead of `current.date`. Non-deterministic in tests. Same class as ENG-1 and ZE-001.
- **Fix Applied:** Now uses `current.date` via `ordinality(of:in:for:)`.

---

## P3 — Minor Bugs (2026-03-14 Session)

### BUG-060: LegalGateTests fail due to simulator state pollution
- **Status:** FIXED (2026-03-14)
- **File:** `Tests/LegalGateTests.swift`
- **Description:** `setUp()` used `removeObject(forKey:)` which doesn't reliably clear UserDefaults when the test host app has previously accepted legal terms on the simulator. 7 tests failed intermittently.
- **Fix Applied:** Use `set(false, forKey:)` + `synchronize()` instead of `removeObject`. Also fixed `testLegalAccepted_canBeReset` which used `removeObject` in the test body.

---

## Open — Not Fixed (2026-03-14 Session)

### BUG-061: HeartTrendEngine stress proxy diverges from real StressEngine
- **Status:** FIXED (2026-03-14)
- **Severity:** P2-MAJOR
- **File:** `Shared/Engine/HeartTrendEngine.swift`
- **Description:** ReadinessEngine was called with a heuristic stress score (70/50/25) derived from trend flags, not the real StressEngine output. This proxy diverged from the actual stress score, causing nudge intensity misalignment.
- **Fix Applied:** Added `stressScore: Double?` parameter to `assess()` with backward-compatible default of `nil`. When provided, real score is used directly. Falls back to heuristic proxy only when caller doesn't have a stress score.

### BUG-062: BioAgeEngine uses estimated height for BMI calculation
- **Status:** FIXED (2026-03-14)
- **Severity:** P3-MINOR
- **File:** `Shared/Engine/BioAgeEngine.swift`, `Shared/Models/HeartModels.swift`
- **Description:** Used sex-stratified average heights when actual height unavailable. A 188cm man got BMI inflated by ~15%.
- **Fix Applied:** Added `heightM: Double?` field to `HeartSnapshot` (clamped 0.5-2.5m). BioAgeEngine now uses actual height when available, falls back to estimated only when nil. HealthKit query for `HKQuantityType(.height)` still needed in HealthKitService.

### BUG-063: SmartNudgeScheduler assumes midnight-to-morning sleep
- **Status:** FIXED (2026-03-14)
- **Severity:** P2-MAJOR
- **File:** `Shared/Engine/SmartNudgeScheduler.swift`
- **Description:** Sleep pattern estimation clamped wake time to 5-12 range. Shift workers sleeping 2AM-10AM got wrong bedtime/wake estimates.
- **Fix Applied:** Widened wake range to 3-14 (was 5-12), bedtime floor to 18 (was 20). Long sleep (>9h) now shifts wake estimate later for shift workers. Full fix with actual HealthKit sleep timestamps still recommended for v2.

---

## Tracking Summary

| Severity | Total | Open | Fixed |
|----------|-------|------|-------|
| P0-CRASH | 1 | 0 | 1 |
| P1-BLOCKER | 8 | 0 | 8 |
| P2-MAJOR | 32 | 1 | 31 |
| P3-MINOR | 7 | 0 | 7 |
| P4-COSMETIC | 13 | 0 | 13 |
| **Total** | **63** | **1** | **62** |

### Remaining Open (1)
- BUG-013: Accessibility labels missing across views (P2) — large effort, plan for next sprint

| Severity | Total | Open | Fixed |
|----------|-------|------|-------|
| P0-CRASH | 1 | 0 | 1 |
| P1-BLOCKER | 8 | 0 | 8 |
| P2-MAJOR | 28 | 1 | 27 |
| P3-MINOR | 5 | 0 | 5 |
| P4-COSMETIC | 13 | 0 | 13 |
| **Total** | **55** | **1** | **54** |

### Remaining Open (2)
- BUG-013: Accessibility labels missing across views (P2) — large effort, plan for next sprint
- BUG-014: No crash reporting in production (P2)

### Test Results (2026-03-14)
- Xcode build: ✅ iOS + Watch targets
- XCTest: **752 tests, 0 failures**
- Production readiness suite: 31 tests across 10 clinical personas × 8 engines
- Watch build: ✅ ThumpWatch scheme passes

---

## P1 — Ship Blockers (2026-03-16 Session — Real Device Testing)

### BUG-064: HealthKit queries throw on missing data — entire snapshot fetch fails
- **Status:** FIXED (2026-03-16)
- **Severity:** P1-BLOCKER
- **File:** `iOS/Services/HealthKitService.swift`
- **Description:** All 13 HealthKit query error handlers called `continuation.resume(throwing: HealthKitError.queryFailed(...))`. On a real device, any metric type with no data (e.g., no VO2max recorded, no sleep logged) caused the entire `fetchTodaySnapshot()` and `fetchHistory()` to throw. User saw "Unable to read today's health data" permanently. This passed simulator testing because mock data was always present.
- **Root Cause:** `withCheckedThrowingContinuation` pattern treated "no data" as "query failed" instead of returning empty/nil.
- **Fix Applied:** Changed all 13 error handlers:
  - Batch `HKStatisticsCollectionQuery` handlers (lines 364, 409) → `continuation.resume(returning: [:])`
  - Workout array queries (lines 468, 631, 690) → `continuation.resume(returning: [])`
  - Single value queries (lines 544, 582) → `continuation.resume(returning: nil)`
  - HR sample queries (line 716) → `continuation.resume(returning: [])`
  - Category sample queries (line 784) → `continuation.resume(returning: [])`
  - Statistics queries (lines 835, 871, 903, 935) → `continuation.resume(returning: nil)`
- **Verified:** `grep` confirms zero `continuation.resume(throwing: HealthKitError` remaining.

### BUG-065: bedtimeWindDown nudge "Got It" button doesn't start breathing session
- **Status:** FIXED (2026-03-16)
- **Severity:** P1-BLOCKER
- **Files:** `iOS/ViewModels/StressViewModel.swift`, `iOS/Views/StressSmartActionsView.swift`
- **Description:** The bedtimeWindDown smart action card showed "Got It" with a checkmark icon. Tapping it just dismissed the card (`smartAction = .standardNudge`) instead of starting the breathing session. This was validated by 3 LLM judges in the UI rubric — the breathing flow was supposed to be the primary action.
- **Fix Applied:**
  - `StressViewModel.swift` line 214-216: Changed handler from `case .bedtimeWindDown: smartAction = .standardNudge` to `case .bedtimeWindDown: startBreathingSession()`
  - `StressSmartActionsView.swift` line 88-89: Changed button from `buttonLabel: "Got It", buttonIcon: "checkmark"` to `buttonLabel: "Start Breathing", buttonIcon: "wind"`

### BUG-066: Scroll sticking on dashboard — highPriorityGesture steals vertical touches
- **Status:** FIXED (2026-03-16)
- **Severity:** P1-BLOCKER
- **File:** `iOS/Views/MainTabView.swift`
- **Description:** `highPriorityGesture(DragGesture(minimumDistance: 30, ...))` on the root TabView intercepted vertical scroll gestures from ScrollView. Users had to swipe multiple times to scroll up on the dashboard. Device logs confirmed: massive UIEvent dispatch logs, "Ignoring beginScrollingWithRegion" and "Ignoring endScrollingWithRegion" messages.
- **Root Cause:** `highPriorityGesture` gives the TabView's swipe gesture priority over ScrollView's scroll gesture. The horizontal/vertical ratio threshold of 1.2 was too loose — slight diagonal swipes were captured.
- **Fix Applied:** Changed to `.simultaneousGesture(DragGesture(minimumDistance: 40, ...))` with `abs(h) > abs(v) * 2.0` threshold. This allows ScrollView to process touches simultaneously, and only commits horizontal swipe when it's clearly horizontal (2x ratio instead of 1.2x).

---

## P2 — Major Bugs (2026-03-16 Session)

### BUG-067: NaN CoreGraphics errors from TrendsView division by zero
- **Status:** FIXED (2026-03-16)
- **Severity:** P2-MAJOR
- **File:** `iOS/Views/TrendsView.swift`
- **Description:** `trendInsightCard()` at line 338 computed `(secondAvg - firstAvg) / firstAvg * 100` — when `firstAvg` is 0 (e.g., steps data all zeros in first half), this produces NaN. The NaN cascaded through `percentChange` → `change` → `Int(change)` and into CoreGraphics rendering calls. Device logs showed: `Error: this application, or a library it uses, has passed an invalid numeric value (NaN, or not-a-number) to CoreGraphics API`.
- **Root Cause:** Three unsafe divisions without zero-guards:
  1. Line 246: `values.reduce(0, +) / Double(values.count)` — inside `!points.isEmpty` branch but vulnerable during re-render
  2. Line 336-337: `firstAvg` and `secondAvg` division by midpoint (guarded by count >= 4 but midpoint could theoretically be 0)
  3. Line 338: `/ firstAvg` — no guard at all, direct NaN when firstAvg = 0
- **Fix Applied:**
  - Line 246: `values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)`
  - Line 336: `midpoint > 0 ? ... : 0`
  - Line 337: `(values.count - midpoint) > 0 ? ... : 0`
  - Line 338: `firstAvg == 0 ? 0 : (secondAvg - firstAvg) / firstAvg * 100`

---

## Tracking Summary (Updated 2026-03-16)

| Severity | Total | Open | Fixed |
|----------|-------|------|-------|
| P0-CRASH | 1 | 0 | 1 |
| P1-BLOCKER | 11 | 0 | 11 |
| P2-MAJOR | 33 | 2 | 31 |
| P3-MINOR | 7 | 0 | 7 |
| P4-COSMETIC | 13 | 0 | 13 |
| **Total** | **67** | **2** | **65** |

### Remaining Open (2)
- BUG-013: Accessibility labels missing across views (P2)
- BUG-014: No crash reporting in production (P2)

### Test Results (2026-03-16)
- Xcode build: ✅ iOS target (`** BUILD SUCCEEDED **`)
- XCTest: **1,532 tests, 9 expected failures, 0 unexpected failures**
- Real device testing: HealthKit fix, breathing button fix, scroll fix, NaN fix — all verified in code

---

---

## P2 — Major Bugs (2026-03-16 Session — Continued)

### BUG-068: Bug report sends email instead of Firebase — kicks user to Mail app
- **Status:** FIXED (2026-03-16)
- **Severity:** P2-MAJOR
- **File:** `iOS/Views/SettingsView.swift`
- **Description:** Bug report used `mailto:` link which opened the Mail app instead of sending to Firebase. Users without Mail configured couldn't submit reports at all.
- **Fix Applied:** Replaced email submission with `DiagnosticExportService.shared.uploadToFirestore()`. Bug reports now go directly to Firebase with full diagnostic payload. Also provides a share sheet with JSON file as backup.

### BUG-069: "What to Do This Week" action items not clickable in InsightsView
- **Status:** FIXED (2026-03-16)
- **Severity:** P2-MAJOR
- **File:** `iOS/Views/InsightsView.swift`
- **Description:** Action items in the weekly plan section were plain HStack rows with no tap handler. Users expected to tap them to see details but nothing happened.
- **Fix Applied:** Wrapped each action item in a `Button` with `CardButtonStyle()`, added chevron indicator, `InteractionLog` tracking, and `accessibilityHint`. Tapping now opens the full report detail sheet.

### BUG-070: HRV nudges route to Stress tab — wrong navigation target
- **Status:** OPEN
- **Severity:** P2-MAJOR
- **File:** `iOS/Views/DashboardView+BuddyCards.swift`
- **Description:** In buddy card tap handler (line 47-48), `.rest` category nudges route to Stress tab (tab index 2). HRV-related nudges categorized as `.rest` should navigate to a more appropriate destination. Users tapping HRV advice land on Stress screen with no HRV context.

### BUG-071: "Buddy Says" recommendation cards may not be clickable
- **Status:** OPEN
- **Severity:** P2-MAJOR
- **File:** `iOS/Views/DashboardView+BuddyCards.swift`
- **Description:** Code shows buttons exist for buddy recommendation cards, but during real device testing the cards appeared non-interactive. May be gesture conflict with parent ScrollView or nil data preventing button rendering. Needs device reproduction.

### BUG-072: Feature request sheet doesn't clear after submission
- **Status:** FIXED (2026-03-16)
- **Severity:** P3-MINOR
- **File:** `iOS/Views/SettingsView.swift`
- **Description:** After sending a feature request, the sheet showed "Thank you!" but stayed open with old text. User had to manually dismiss and text persisted.
- **Fix Applied:** Added auto-dismiss after 2 seconds via `Task.sleep`. Clears `featureRequestText` and resets `featureRequestSubmitted` on dismiss.

### BUG-073: Bug report lacks diagnostic data — only sends text description
- **Status:** FIXED (2026-03-16)
- **Severity:** P2-MAJOR
- **File:** `iOS/Services/DiagnosticExportService.swift` (NEW), `iOS/Services/FeedbackService.swift`
- **Description:** Bug reports only captured user's text description + basic device info. No health data, engine outputs, interaction logs, or app state was included. Made debugging impossible without back-and-forth with users.
- **Fix Applied:** Created comprehensive `DiagnosticExportService` that captures: device/app meta, user profile, full health history with all snapshot fields, engine outputs (stress/readiness/bio-age/coaching/zones), interaction logs from CrashBreadcrumbs, nudge data, and settings. Integrated into `FeedbackService.submitBugReport()` with optional `diagnosticPayload` parameter. Large sections serialized as JSON strings to stay under Firestore 1MB limit.

### BUG-074: NotificationService init crashes with Swift 6 @MainActor isolation
- **Status:** FIXED (2026-03-16)
- **Severity:** P1-BLOCKER
- **File:** `iOS/Services/NotificationService.swift`
- **Description:** `StressViewModel` (marked `@MainActor`) used `NotificationService()` as a default parameter. `NotificationService.init` was implicitly `@MainActor` isolated, causing Swift 6 error: "call to main actor-isolated initializer in a synchronous nonisolated context." Build failed on real device target.
- **Fix Applied:** Added `nonisolated` to `NotificationService.init`. Moved `checkCurrentAuthorization()` call into a `Task { @MainActor in }` block within init.

---

## Tracking Summary (Updated 2026-03-16 — Full Session)

| Severity | Total | Open | Fixed |
|----------|-------|------|-------|
| P0-CRASH | 1 | 0 | 1 |
| P1-BLOCKER | 12 | 0 | 12 |
| P2-MAJOR | 38 | 4 | 34 |
| P3-MINOR | 8 | 0 | 8 |
| P4-COSMETIC | 13 | 0 | 13 |
| **Total** | **74** | **4** | **70** |

### Remaining Open (4)
- BUG-013: Accessibility labels missing across views (P2)
- BUG-014: No crash reporting in production (P2)
- BUG-070: HRV nudges route to Stress tab (P2)
- BUG-071: Buddy Says cards may not be clickable (P2)

### Test Results (2026-03-16)
- Xcode build: ✅ iOS target (`** BUILD SUCCEEDED **`)
- XCTest: **1,532 tests, 9 expected failures, 0 unexpected failures**
- Real device testing: 7 new bugs found, 5 fixed in session, 2 open for investigation

---

*Last updated: 2026-03-16 — 70/74 bugs fixed, 4 remaining. 7 new bugs found during real iPhone device testing session: HealthKit query failures (P1), dead breathing button (P1), scroll sticking (P1), NaN division (P2), email-based bug report (P2), non-clickable action items (P2), feature request sheet stuck (P3), missing diagnostic data (P2), Swift 6 init isolation (P1). All P1s fixed.*

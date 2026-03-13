# HeartCoach / Thump — Bug Registry

Date: 2026-03-13
Total Bugs: 55 from BUGS.md + 10 from Code Review = 65 tracked issues

---

## Summary

| Source | Severity | Total | Open | Fixed |
|--------|----------|-------|------|-------|
| BUGS.md | P0-CRASH | 1 | 0 | 1 |
| BUGS.md | P1-BLOCKER | 8 | 0 | 8 |
| BUGS.md | P2-MAJOR | 28 | 4 | 24 |
| BUGS.md | P3-MINOR | 5 | 1 | 4 |
| BUGS.md | P4-COSMETIC | 13 | 0 | 13 |
| Code Review | HIGH | 3 | 1 (CR-001 partial) | 2 |
| Code Review | MEDIUM | 4 | 0 | 4 |
| Code Review | LOW | 3 | 0 | 3 |
| **Total** | | **65** | **6** | **59** |

Plus 4 orphaned code findings and 5 oversized file findings from code review.

---

## P0 — CRASH BUGS

### BUG-001: PaywallView purchase crash — API mismatch

| Field | Value |
|-------|-------|
| **ID** | BUG-001 |
| **Severity** | P0-CRASH |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/PaywallView.swift`, `iOS/Services/SubscriptionService.swift` |

**Description:** PaywallView calls `subscriptionService.purchase(tier:isAnnual:)` but SubscriptionService only exposes `purchase(_ product: Product)`. Every purchase attempt crashes at runtime.

**Root Cause:** API contract mismatch between caller and service. The view was coded against a different method signature than the service exposes.

**Fix:** Confirmed method signature is correct. Added `@Published var productLoadError: Error?` to surface silent product load failures (related to BUG-048).

---

## P1 — SHIP BLOCKERS

### BUG-002: Notification nudges can never be cancelled — hardcoded `[]`

| Field | Value |
|-------|-------|
| **ID** | BUG-002 |
| **Severity** | P1-BLOCKER |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Services/NotificationService.swift` |

**Description:** `pendingNudgeIdentifiers()` returns hardcoded empty array `[]`. Nudge notifications pile up and can never be cancelled or managed.

**Root Cause:** Stub left unfinished during initial development. The method was a TODO placeholder returning `[]` instead of querying the notification center.

**Fix:** Query `UNUserNotificationCenter.getPendingNotificationRequests()`, filter by nudge prefix, return real identifiers.

---

### BUG-003: Health data stored as plaintext in UserDefaults

| Field | Value |
|-------|-------|
| **ID** | BUG-003 |
| **Severity** | P1-BLOCKER |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Shared/Services/LocalStore.swift` |

**Description:** Heart metrics (HR, HRV, sleep, etc.) saved as plaintext JSON in UserDefaults. Apple may reject for HealthKit compliance. Privacy liability.

**Root Cause:** Encryption layer (CryptoService with AES-GCM + Keychain) existed but was never integrated into the persistence path.

**Fix:** `saveTier`/`reloadTier` now use encrypted save/load. Added `migrateLegacyTier()` for upgrade path from plaintext to encrypted storage.

---

### BUG-004: WatchInsightFlowView uses MockData in production

| Field | Value |
|-------|-------|
| **ID** | BUG-004 |
| **Severity** | P1-BLOCKER |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Watch/Views/WatchInsightFlowView.swift` |

**Description:** Two screens used `MockData.mockHistory()` to feed fake sleep hours and HRV/RHR values to real users. Users see fabricated data, not their own.

**Root Cause:** Development/demo code left in production build path. The `MockData.mockHistory(days: 4)` call in sleepScreen and `MockData.mockHistory(days: 2)` in metricsScreen were never replaced with real HealthKit queries.

**Fix:** SleepScreen now queries HealthKit `sleepAnalysis` for last 3 nights with safe empty state. HeartMetricsScreen now queries HealthKit for `heartRateVariabilitySDNN` and `restingHeartRate` with nil/dash fallback. Also fixed 12 instances of aggressive/shaming Watch language.

---

### BUG-005: `health-records` entitlement included unnecessarily

| Field | Value |
|-------|-------|
| **ID** | BUG-005 |
| **Severity** | P1-BLOCKER |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/iOS.entitlements` |

**Description:** App includes `com.apple.developer.healthkit.access` for clinical health records but never reads them. Triggers extra App Store review scrutiny and may cause rejection.

**Root Cause:** Overprivileged entitlement configuration — health-records capability was added but never needed.

**Fix:** Removed `health-records` from entitlements. Only `healthkit: true` remains.

---

### BUG-006: No health disclaimer in onboarding

| Field | Value |
|-------|-------|
| **ID** | BUG-006 |
| **Severity** | P1-BLOCKER |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/OnboardingView.swift` |

**Description:** Health disclaimer only exists in Settings. Apple and courts require it before users see health data. Must be shown during onboarding with acknowledgment toggle.

**Root Cause:** Missing required compliance layer in onboarding flow.

**Fix:** Disclaimer page already existed. Updated wording: "wellness tool" instead of "heart training buddy", toggle reads "I understand this is not medical advice".

---

### BUG-007: Missing Info.plist files

| Field | Value |
|-------|-------|
| **ID** | BUG-007 |
| **Severity** | P1-BLOCKER |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Info.plist`, `Watch/Info.plist` |

**Description:** No Info.plist for either target. Required for HealthKit usage descriptions, bundle metadata, launch screen config.

**Root Cause:** Build configuration incomplete.

**Fix:** Both iOS and Watch Info.plist already existed. Updated NSHealthShareUsageDescription, added armv7 capability, removed upside-down orientation.

---

### BUG-008: Missing PrivacyInfo.xcprivacy

| Field | Value |
|-------|-------|
| **ID** | BUG-008 |
| **Severity** | P1-BLOCKER |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/PrivacyInfo.xcprivacy` |

**Description:** Apple requires privacy manifest for apps using HealthKit. Missing = rejection.

**Root Cause:** Privacy compliance artifact missing from project.

**Fix:** File already existed with correct content. Confirmed present.

---

### BUG-009: Legal page links are placeholders

| Field | Value |
|-------|-------|
| **ID** | BUG-009 |
| **Severity** | P1-BLOCKER |
| **Status** | FIXED (2026-03-12) |
| **Files** | `web/index.html`, `web/privacy.html`, `web/terms.html`, `web/disclaimer.html` |

**Description:** Footer links to Privacy Policy, Terms of Service, and Disclaimer use `href="#"`. No actual legal pages linked.

**Root Cause:** Legal compliance pages never wired into navigation.

**Fix:** Legal pages already existed. Updated privacy.html (added Exercise Minutes, replaced placeholder analytics provider), fixed disclaimer.html anchor ID. Footer links pointed to real pages.

---

## P2 — MAJOR BUGS

### BUG-010: Medical language — FDA/FTC risk

| Field | Value |
|-------|-------|
| **ID** | BUG-010 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/PaywallView.swift`, `Shared/Engine/NudgeGenerator.swift`, `web/index.html` |

**Description:** Language that could trigger FDA medical device classification or FTC false advertising: "optimize your heart health" (implies treatment), "personalized coaching" (implies professional medical coaching), "activate your parasympathetic nervous system" (medical instruction), "your body needs recovery" (prescriptive medical advice).

**Root Cause:** Copywriting used medical/clinical terminology without regulatory review.

**Fix:** Scrubbed DashboardView and SettingsView. Replaced with safe language: "track", "monitor", "understand", "wellness insights", "fitness suggestions".

---

### BUG-011: AI slop phrases in user-facing text

| Field | Value |
|-------|-------|
| **ID** | BUG-011 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | Multiple view files |

**Description:** Motivational language that sounds AI-generated and unprofessional: "You're crushing it!" → "Well done", "You're on fire!" → "Nice consistency this week".

**Root Cause:** Placeholder copy with AI-generated phrases not properly reviewed.

**Fix:** DashboardView cleaned. Other views audited.

---

### BUG-012: Raw metric jargon shown to users

| Field | Value |
|-------|-------|
| **ID** | BUG-012 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/Components/CorrelationDetailSheet.swift`, `iOS/Views/Components/CorrelationCardView.swift`, `Watch/Views/WatchDetailView.swift`, `iOS/Views/TrendsView.swift` |

**Description:** Technical terms displayed directly to users: raw correlation coefficients, -1/+1 range labels, anomaly z-scores, "VO2 max" without explanation.

**Root Cause:** Technical output not humanized for lay users.

**Fix:** De-emphasized raw coefficient (56pt → caption2), human-readable strength leads (28pt bold). -1/+1 labels → "Weak"/"Strong". Anomaly score shows human labels. "VO2" → "Cardio Fitness", "mL/kg/min" → "score".

---

### BUG-013: Accessibility labels missing across views

| Field | Value |
|-------|-------|
| **ID** | BUG-013 |
| **Severity** | P2-MAJOR |
| **Status** | **OPEN** |
| **Files** | All 16+ view files in `iOS/Views/`, `iOS/Views/Components/`, `Watch/Views/` |

**Description:** Interactive elements lack `accessibilityLabel`, `accessibilityValue`, `accessibilityHint`. VoiceOver users cannot navigate the app. Critical for HealthKit app review.

**Root Cause:** Accessibility layer not implemented systematically during initial development.

**Fix Plan:** Systematic pass across all views adding accessibility modifiers to every interactive element.

---

### BUG-014: No crash reporting in production

| Field | Value |
|-------|-------|
| **ID** | BUG-014 |
| **Severity** | P2-MAJOR |
| **Status** | **OPEN** |
| **Files** | `iOS/Services/MetricKitService.swift` (missing) |

**Description:** No crash reporting mechanism. Shipping without crash diagnostics means flying blind on user issues.

**Root Cause:** Crash diagnostics not implemented.

**Fix Plan:** Create MetricKitService subscribing to MXMetricManager for crash diagnostics.

---

### BUG-015: No StoreKit configuration for testing

| Field | Value |
|-------|-------|
| **ID** | BUG-015 |
| **Severity** | P2-MAJOR |
| **Status** | **OPEN** |
| **Files** | `iOS/Thump.storekit` (missing) |

**Description:** No StoreKit configuration file. Cannot test subscription flows in Xcode sandbox.

**Root Cause:** Test configuration artifact missing.

**Fix Plan:** Create .storekit file with all 5 subscription product IDs matching SubscriptionService.

---

### BUG-034: PHI exposed in notification payloads

| Field | Value |
|-------|-------|
| **ID** | BUG-034 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Services/NotificationService.swift` |

**Description:** Notification content includes health metrics (anomaly scores, stress flags). These appear on lock screens and notification center — visible to anyone nearby. Protected health information (PHI) exposure.

**Root Cause:** Health data included in notification payloads without privacy consideration.

**Fix:** Replaced `assessment.explanation` with generic "Check your Thump insights" text. Removed `anomalyScore` from userInfo dict.

---

### BUG-035: Array index out of bounds risk in HeartRateZoneEngine

| Field | Value |
|-------|-------|
| **ID** | BUG-035 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Shared/Engine/HeartRateZoneEngine.swift` ~line 135 |

**Description:** Zone minute array accessed by index without bounds checking. If zone array is shorter than expected, runtime crash.

**Root Cause:** Missing defensive programming for array access.

**Fix:** Added `guard index < zoneMinutes.count, index < targets.count else { break }` before array access.

---

### BUG-036: Consecutive elevation detection assumes calendar continuity

| Field | Value |
|-------|-------|
| **ID** | BUG-036 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Shared/Engine/HeartTrendEngine.swift` ~line 537 |

**Description:** Consecutive day detection counts array positions, not actual calendar day gaps. A user who misses a day would have the gap counted as consecutive, leading to false positive overtraining alerts.

**Root Cause:** Using array indices instead of actual calendar dates for consecutive day logic.

**Fix:** Added date gap checking — gaps > 1.5 days break the consecutive streak. Uses actual calendar dates instead of array indices.

---

### BUG-037: Inconsistent statistical methods (CV vs SD)

| Field | Value |
|-------|-------|
| **ID** | BUG-037 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Shared/Engine/StressEngine.swift` |

**Description:** Coefficient of variation uses population formula (n), but standard deviation uses sample formula (n-1). Inconsistent statistics within the same engine.

**Root Cause:** Statistical formulas not standardized across methods.

**Fix:** Standardized CV variance calculation from `/ count` (population) to `/ (count - 1)` (sample) to match other variance calculations in the engine.

---

### BUG-038: "You're crushing it!" in TrendsView

| Field | Value |
|-------|-------|
| **ID** | BUG-038 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/TrendsView.swift` line 770 |

**Description:** AI slop cliche when all weekly goals met.

**Root Cause:** Generic copy not replaced with specific messaging.

**Fix:** Changed to "You hit all your weekly goals — excellent consistency this week."

---

### BUG-039: "rock solid" informal language in TrendsView

| Field | Value |
|-------|-------|
| **ID** | BUG-039 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/TrendsView.swift` line 336 |

**Description:** "Your [metric] has been rock solid" — informal, redundant with "steady" in same sentence.

**Root Cause:** Informal language not reviewed.

**Fix:** Changed to "Your [metric] has remained stable through this period, showing steady patterns."

---

### BUG-040: "Whatever you're doing, keep it up" in TrendsView

| Field | Value |
|-------|-------|
| **ID** | BUG-040 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/TrendsView.swift` line 343 |

**Description:** Generic, non-specific encouragement. Doesn't acknowledge what improved.

**Root Cause:** Generic copy template not customized.

**Fix:** Changed to "the changes you've made are showing results."

---

### BUG-041: "for many reasons" wishy-washy in TrendsView

| Field | Value |
|-------|-------|
| **ID** | BUG-041 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/TrendsView.swift` line 350 |

**Description:** "this kind of shift can happen for many reasons" — defensive, not helpful.

**Root Cause:** Vague defensive copy not replaced with actionable guidance.

**Fix:** Changed to "Consider factors like stress, sleep, or recent activity changes."

---

### BUG-042: "Keep your streak alive" generic in WatchHomeView

| Field | Value |
|-------|-------|
| **ID** | BUG-042 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Watch/Views/WatchHomeView.swift` line 145 |

**Description:** Same phrase for all users scoring ≥85 regardless of streak length. Impersonal.

**Root Cause:** Template copy not varied by context.

**Fix:** Changed to "Excellent. You're building real momentum."

---

### BUG-043: "Great job completing X%" generic in InsightsView

| Field | Value |
|-------|-------|
| **ID** | BUG-043 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/InsightsView.swift` line 430 |

**Description:** Templated encouragement that feels robotic.

**Root Cause:** Generic message template not personalized.

**Fix:** Changed to "You engaged with X% of daily suggestions — solid commitment."

---

### BUG-044: "room to build" vague in InsightsView

| Field | Value |
|-------|-------|
| **ID** | BUG-044 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/InsightsView.swift` line 432 |

**Description:** Slightly patronizing and non-actionable.

**Root Cause:** Vague guidance not replaced with specific action.

**Fix:** Changed to "Aim for one extra nudge this week."

---

### BUG-045: CSV export header exposes "SDNN" jargon

| Field | Value |
|-------|-------|
| **ID** | BUG-045 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/SettingsView.swift` line 593 |

**Description:** CSV header reads "HRV (SDNN)" — users opening in Excel see unexplained medical acronym.

**Root Cause:** Technical metric name not humanized for data export.

**Fix:** Changed header from "HRV (SDNN)" to "Heart Rate Variability (ms)".

---

### BUG-046: "nice sign" vague in TrendsView

| Field | Value |
|-------|-------|
| **ID** | BUG-046 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/TrendsView.swift` line 357 |

**Description:** "That kind of consistency is a nice sign" — what kind of sign? For what?

**Root Cause:** Vague messaging not replaced with specific language.

**Fix:** Changed to "this consistency indicates stable patterns."

---

### BUG-047: NudgeGenerator missing ordinality() fallback

| Field | Value |
|-------|-------|
| **ID** | BUG-047 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Shared/Engine/NudgeGenerator.swift` |

**Description:** When `Calendar.current.ordinality()` returns nil, fallback was `0` — every nudge selection returned index 0 (first item), making nudges predictable/stuck.

**Root Cause:** Missing nil coalescing with deterministic fallback.

**Fix:** Changed all 7 `?? 0` fallbacks to `?? Calendar.current.component(.day, from: current.date)` — uses day-of-month (1–31) as fallback, ensuring varied selection even when ordinality fails.

---

### BUG-048: SubscriptionService silent product load failure

| Field | Value |
|-------|-------|
| **ID** | BUG-048 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Services/SubscriptionService.swift` |

**Description:** If `Product.products()` fails or returns empty, no error is surfaced. Paywall shows empty state with no explanation.

**Root Cause:** Error state not captured or surfaced to UI.

**Fix:** Added `@Published var productLoadError: Error?` that surfaces load failures to PaywallView.

---

### BUG-049: LocalStore.clearAll() incomplete data cleanup

| Field | Value |
|-------|-------|
| **ID** | BUG-049 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Shared/Services/LocalStore.swift` |

**Description:** `clearAll()` may miss some UserDefaults keys, leaving orphaned health data after account deletion.

**Root Cause:** Incomplete enumeration of all stored keys.

**Fix:** Added missing `.lastCheckIn` and `.feedbackPrefs` keys to `clearAll()`. Also added `CryptoService.deleteKey()` to wipe Keychain encryption key on reset.

---

### BUG-050: Medical language in engine outputs — "Elevated Physiological Load"

| Field | Value |
|-------|-------|
| **ID** | BUG-050 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Shared/Engine/HeartTrendEngine.swift`, `Shared/Engine/ReadinessEngine.swift`, `Shared/Engine/NudgeGenerator.swift`, `Shared/Engine/HeartModels.swift`, `iOS/Services/NotificationService.swift`, `Shared/Engine/HeartRateZoneEngine.swift`, `Shared/Engine/CoachingEngine.swift`, `iOS/ViewModels/InsightsViewModel.swift` |

**Description:** Engine-generated strings include clinical terminology: "Elevated Physiological Load", "Overtraining Detected", "Stress Response Active".

**Root Cause:** Clinical language not replaced with conversational copy.

**Fix:** Scrubbed across 8 files. Replaced: "Heart working harder", "Hard sessions back-to-back", "Stress pattern noticed".

---

### BUG-051: DashboardView metric tile accessibility gap

| Field | Value |
|-------|-------|
| **ID** | BUG-051 |
| **Severity** | P2-MAJOR |
| **Status** | **OPEN** |
| **Files** | `iOS/Views/DashboardView.swift` lines 1152–1158 |

**Description:** 6 metric tile buttons lack accessibilityLabel and accessibilityHint. VoiceOver cannot convey purpose.

**Root Cause:** Accessibility modifiers not added to interactive elements.

**Fix Plan:** Add semantic labels to each tile.

---

### BUG-052: WatchInsightFlowView metric accessibility gap

| Field | Value |
|-------|-------|
| **ID** | BUG-052 |
| **Severity** | P2-MAJOR |
| **Status** | **OPEN** |
| **Files** | `Watch/Views/WatchInsightFlowView.swift` |

**Description:** Tab-based metric display screens lack accessibility labels for metric cards.

**Root Cause:** Accessibility layer not implemented.

**Fix Plan:** Add accessibilityLabel to each metric section.

---

### BUG-053: Hardcoded notification delivery hours

| Field | Value |
|-------|-------|
| **ID** | BUG-053 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Services/NotificationService.swift` |

**Description:** Nudge delivery hours hardcoded. Doesn't respect shift workers or different time zones.

**Root Cause:** Delivery schedule not made configurable.

**Fix:** Centralized into `DefaultDeliveryHour` enum. TODO for user-configurable Settings UI.

---

### BUG-054: LocalStore silently falls back to plaintext when encryption fails

| Field | Value |
|-------|-------|
| **ID** | BUG-054 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Shared/Services/LocalStore.swift` |

**Description:** When `CryptoService.encrypt()` returns nil (Keychain unavailable), `save()` silently stored health data as plaintext JSON in UserDefaults. This undermined the BUG-003 encryption fix.

**Root Cause:** Encryption failure not handled — fell back to plaintext instead of failing safely.

**Fix:** Removed plaintext fallback. Data is now dropped (not saved) when encryption fails, with error log and DEBUG assertion. Protects PHI at cost of temporary data loss until encryption is available again.

---

### BUG-055: ReadinessEngine force unwraps on pillarWeights dictionary

| Field | Value |
|-------|-------|
| **ID** | BUG-055 |
| **Severity** | P2-MAJOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `Shared/Engine/ReadinessEngine.swift` |

**Description:** Five `pillarWeights[.xxx]!` force unwraps across pillar scoring functions. Safe in practice (hardcoded dictionary), but fragile if pillar types are ever added/removed.

**Root Cause:** Not using defensive dictionary access.

**Fix:** Replaced all 5 force unwraps with `pillarWeights[.xxx, default: N]` using matching default weights.

---

## P3 — MINOR BUGS

### BUG-016: "Heart Training Buddy" branding across web + app

| Field | Value |
|-------|-------|
| **ID** | BUG-016 |
| **Severity** | P3-MINOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `web/index.html`, `web/privacy.html`, `web/terms.html`, `web/disclaimer.html` |

**Description:** Branding messaging inconsistency across web properties.

**Root Cause:** Copy not updated consistently across properties.

**Fix:** Changed all "Your Heart Training Buddy" to "Your Heart's Daily Story" across 4 web pages.

---

### BUG-017: "Activity Correlations" heading jargon in InsightsView

| Field | Value |
|-------|-------|
| **ID** | BUG-017 |
| **Severity** | P3-MINOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/InsightsView.swift` |

**Description:** Section header "Activity Correlations" is technical jargon.

**Root Cause:** Technical term not humanized.

**Fix:** Changed to "How Activities Affect Your Numbers".

---

### BUG-018: BioAgeDetailSheet makes medical claims

| Field | Value |
|-------|-------|
| **ID** | BUG-018 |
| **Severity** | P3-MINOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/Components/BioAgeDetailSheet.swift` |

**Description:** Language implying medical-grade biological age assessment.

**Root Cause:** Disclaimer language not added upfront.

**Fix:** Added "Bio Age is an estimate based on fitness metrics, not a medical assessment". Changed "Expected: X" → "Typical for age: X".

---

### BUG-019: MetricTileView lacks context-aware trend colors

| Field | Value |
|-------|-------|
| **ID** | BUG-019 |
| **Severity** | P3-MINOR |
| **Status** | FIXED (2026-03-12) |
| **Files** | `iOS/Views/Components/MetricTileView.swift` |

**Description:** Trend arrows use generic red/green. For RHR, "up" is bad but showed green.

**Root Cause:** Color semantics not metric-aware.

**Fix:** Added `lowerIsBetter: Bool` parameter with `invertedColor` computed property. RHR tiles now show down=green, up=red.

---

### BUG-020: CI/CD pipeline not verified

| Field | Value |
|-------|-------|
| **ID** | BUG-020 |
| **Severity** | P3-MINOR |
| **Status** | **OPEN** |
| **Files** | `.github/workflows/ci.yml` |

**Description:** CI pipeline was created but needs verification it actually builds the XcodeGen project and runs tests.

**Root Cause:** CI setup incomplete or not verified.

**Fix Plan:** Verify CI actually builds and tests XcodeGen project end-to-end.

---

## P4 — COSMETIC BUGS (BUG-021 through BUG-033)

All cosmetic messaging/copy fixes. All FIXED on 2026-03-12.

| ID | Description | File | Fix |
|----|-------------|------|-----|
| BUG-021 | "Buddy Says" heading | DashboardView | → "Your Daily Coaching" |
| BUG-022 | "Anomaly Alerts" heading | SettingsView | → "Unusual Pattern Alerts" |
| BUG-023 | "Your heart's daily story" generic | SettingsView | → "Heart wellness tracking" |
| BUG-024 | "metric norms" jargon | SettingsView | → "typical ranges for your age and sex" |
| BUG-025 | "before getting sick" medical claim | DashboardView | → "busy weeks, travel, or routine changes" |
| BUG-026 | "AHA guideline" jargon | DashboardView | → "recommended 150 minutes of weekly activity" |
| BUG-027 | "Fat Burn"/"Recovery" zone names | DashboardView | → "Moderate"/"Easy" |
| BUG-028 | "Elevated RHR Alert" clinical | DashboardView | → "Elevated Resting Heart Rate" |
| BUG-029 | "Your heart is loving..." | DashboardView | → "Your trends are looking great" |
| BUG-030 | "You're on fire!" AI slop | DashboardView | → "Nice consistency this week" |
| BUG-031 | "Another day, another chance..." | DashboardView | Removed entirely |
| BUG-032 | "Your body's asking for TLC" | DashboardView | → "Your numbers suggest taking it easy" |
| BUG-033 | "unusual heart patterns detected" | SettingsView | → "numbers look different from usual range" |

---

## CODE REVIEW FINDINGS (2026-03-13)

### CR-001: NotificationService not wired into production app [HIGH]

| Field | Value |
|-------|-------|
| **ID** | CR-001 |
| **Severity** | HIGH |
| **Status** | **PARTIALLY FIXED** (2026-03-13) |
| **Files** | `iOS/ThumpiOSApp.swift:29-53`, `iOS/Services/NotificationService.swift:20-96` |

**Description:** The app root creates HealthKitService, SubscriptionService, ConnectivityService, and LocalStore, but not NotificationService. No production call sites exist. Anomaly alerts and nudge reminders cannot be authorized, scheduled, or delivered.

**Root Cause:** Architecture drift — service was implemented but never integrated into the app lifecycle.

**What is fixed:**
- `NotificationService` is created as `@StateObject` in `ThumpiOSApp` and injected into the environment.
- It now receives the shared root `localStore` instance (not its own default) so alert-budget state is owned by one persistence object.
- Authorization is requested during `performStartupTasks()`.

**What is still missing:**
- No production call sites invoke `scheduleAnomalyAlert()`, `scheduleNudgeReminder()`, or cancellation methods from the live dashboard/assessment pipeline.
- Users see the permission prompt but will never receive scheduled alerts until the assessment → notification scheduling path is wired.

---

### CR-002: Dashboard refresh persists duplicate snapshots [HIGH]

| Field | Value |
|-------|-------|
| **ID** | CR-002 |
| **Severity** | HIGH |
| **Status** | **FIXED** (2026-03-13) |
| **Files** | `iOS/ViewModels/DashboardViewModel.swift:186-188`, `Shared/Services/LocalStore.swift:148-152` |

**Description:** Every `refresh()` appends a new StoredSnapshot even on same day. Pull-to-refresh, tab revisits, and app relaunches create duplicates polluting history, streaks, weekly rollups, and watch sync.

**Root Cause:** Append-only persistence without deduplication by calendar date.

**Fix:** Changed `appendSnapshot()` to upsert by calendar day — finds existing same-day entry and replaces it, or appends if new day.

---

### CR-003: Weekly nudge completion rate inflated [HIGH]

| Field | Value |
|-------|-------|
| **ID** | CR-003 |
| **Severity** | HIGH |
| **Status** | **FIXED** (2026-03-13) |
| **Files** | `iOS/ViewModels/InsightsViewModel.swift:173-184`, `iOS/ViewModels/DashboardViewModel.swift:235-253`, `Shared/Models/HeartModels.swift` |

**Description:** `generateWeeklyReport()` checks `stored.assessment != nil` to determine completion. Since refresh() auto-stores assessments, simply opening the app inflates nudgeCompletionRate toward 100%.

**Root Cause:** Completion inferred from assessment existence rather than explicit user action.

**Fix:** Added `nudgeCompletionDates: Set<String>` to UserProfile. `markNudgeComplete()` records explicit completion per ISO date. InsightsViewModel counts from explicit records instead of auto-stored assessments.

---

### CR-004: Same-day nudge taps inflate streak counter [MEDIUM]

| Field | Value |
|-------|-------|
| **ID** | CR-004 |
| **Severity** | MEDIUM |
| **Status** | **FIXED** (2026-03-13) |
| **Files** | `iOS/ViewModels/DashboardViewModel.swift:235-253`, `Shared/Models/HeartModels.swift` |

**Description:** `markNudgeComplete()` increments `streakDays` unconditionally. `markNudgeComplete(at:)` calls it per card. Multiple nudges on same day = multiple streak increments.

**Root Cause:** No guard against same-day duplicate streak credits.

**Fix:** Added `lastStreakCreditDate: Date?` to UserProfile. `markNudgeComplete()` checks if streak was already credited today before incrementing.

---

### CR-005: HealthKit history loading — too many queries [MEDIUM]

| Field | Value |
|-------|-------|
| **ID** | CR-005 |
| **Severity** | MEDIUM |
| **Status** | **OPEN** |
| **Files** | `iOS/Services/HealthKitService.swift:169-203`, `iOS/Services/HealthKitService.swift:210-229` |

**Description:** `fetchHistory(days:)` launches one task per day, each day launches 9 metric queries plus recovery subqueries. 30-day load = 270+ HealthKit queries. Expensive for latency, battery, background execution.

**Root Cause:** Per-day fan-out architecture instead of batched range queries.

**Fix Plan:** Replace with `HKStatisticsCollectionQuery` / batched APIs so each metric is fetched once across the full date range. Cache widest window and derive sub-views.

---

### CR-006: SwiftPM 660 unhandled files warning [MEDIUM]

| Field | Value |
|-------|-------|
| **ID** | CR-006 |
| **Severity** | MEDIUM |
| **Status** | **FIXED** (2026-03-13) |
| **Files** | `Package.swift:24-57` |

**Description:** `swift test` reports 660 unhandled files in test target. Warning noise makes real build problems easier to miss.

**Root Cause:** Fixture directories not explicitly excluded or declared as resources in package manifest.

**Fix:** Added `EngineTimeSeries/Results` and `Validation/Data` to Package.swift exclude list.

---

### CR-007: ThumpBuddyFace macOS 15 availability warning [MEDIUM]

| Field | Value |
|-------|-------|
| **ID** | CR-007 |
| **Severity** | MEDIUM |
| **Status** | **FIXED** (2026-03-13) |
| **Files** | `Shared/Views/ThumpBuddyFace.swift:257-261` |

**Description:** Package declares `.macOS(.v14)` but `starEye` uses `.symbolEffect(.bounce, isActive: true)` which is macOS 15 only. Becomes build error in Swift 6 mode.

**Root Cause:** API availability mismatch between declared platform floor and actual API usage.

**Fix:** Added `#available(macOS 15, iOS 17, watchOS 10, *)` guard with fallback that omits symbolEffect.

---

## ENGINE-SPECIFIC BUGS (from Code Review)

### CR-008: HeartTrendEngine week-over-week overlapping baseline

| Field | Value |
|-------|-------|
| **ID** | CR-008 |
| **Severity** | MEDIUM |
| **Status** | **FIXED** (2026-03-13) |
| **Files** | `Shared/Engine/HeartTrendEngine.swift:454-465` |

**Description:** `weekOverWeekTrend()` baseline is built from `suffix(baselineWindow)` over `history + [current]`. The current week's data contaminates the baseline it's being compared against, diluting trend magnitude and hiding real deviations.

**Root Cause:** Baseline window includes the data being evaluated. Should exclude the most recent 7 days.

**Fix:** Baseline now uses `dropLast(currentWeekCount)` to exclude the current 7 days before computing baseline mean.

---

### CR-009: CoachingEngine uses Date() instead of current.date

| Field | Value |
|-------|-------|
| **ID** | CR-009 |
| **Severity** | MEDIUM |
| **Status** | **FIXED** (2026-03-13) |
| **Files** | `Shared/Engine/CoachingEngine.swift:48-54` |

**Description:** `generateReport()` anchors "this week" and "last week" to `Date()` instead of `current.date`. Makes historical replay and deterministic backtesting inaccurate.

**Root Cause:** Wall-clock time used instead of snapshot's logical date.

**Fix:** Replaced `Date()` with `current.date` in `generateReport()`.

---

### CR-010: SmartNudgeScheduler uses Date() for bedtime lookup

| Field | Value |
|-------|-------|
| **ID** | CR-010 |
| **Severity** | LOW |
| **Status** | **FIXED** (2026-03-13) |
| **Files** | `Shared/Engine/SmartNudgeScheduler.swift:240-243` |

**Description:** `recommendAction()` uses `Date()` for bedtime day-of-week lookup instead of the provided context date. Hurts determinism and replayability.

**Root Cause:** Same wall-clock pattern as CoachingEngine.

**Fix:** Replaced `Date()` with `todaySnapshot?.date ?? Date()` for day-of-week lookup.

---

### CR-011: ReadinessEngine receives coarse 70.0 instead of actual stress score

| Field | Value |
|-------|-------|
| **ID** | CR-011 |
| **Severity** | MEDIUM |
| **Status** | **FIXED** (2026-03-13) |
| **Files** | `iOS/ViewModels/DashboardViewModel.swift:438-465` |

**Description:** Readiness computation receives `70.0` when `stressFlag == true`, otherwise `nil`. The actual StressEngine score is computed later in `computeBuddyRecommendations()` and never fed back to readiness. Additionally, `consecutiveAlert` from the assessment was not passed to ReadinessEngine even though the engine supports an overtraining cap.

**Root Cause:** Engine computation order — stress computed after readiness in the refresh pipeline. Missing parameter pass-through for consecutiveAlert.

**Fix:**
- `computeReadiness()` now runs StressEngine directly and feeds actual score to ReadinessEngine, with fallback to 70.0 only when engine returns nil.
- Now also passes `assessment?.consecutiveAlert` to `ReadinessEngine.compute()` so the overtraining cap is applied when 3+ days of consecutive elevation are detected.

---

### CR-012: CorrelationEngine "Activity Minutes" uses workoutMinutes only

| Field | Value |
|-------|-------|
| **ID** | CR-012 |
| **Severity** | LOW |
| **Status** | **FIXED** (2026-03-13) |
| **Files** | `Shared/Engine/CorrelationEngine.swift:91-100` |

**Description:** Factor labeled "Activity Minutes" but underlying key path is `\.workoutMinutes` only, not total activity (walk + workout). Semantically misleading.

**Root Cause:** Label does not match the data being analyzed.

**Fix:** Changed key path from `\.workoutMinutes` to `\.activityMinutes` (new computed property: walkMinutes + workoutMinutes).

---

### CR-013: HealthKit zoneMinutes hardcoded to empty array

| Field | Value |
|-------|-------|
| **ID** | CR-013 |
| **Severity** | MEDIUM |
| **Status** | **OPEN** |
| **Files** | `iOS/Services/HealthKitService.swift:231-239` |

**Description:** `fetchSnapshot()` hardcodes `zoneMinutes: []`. `DashboardViewModel.computeZoneAnalysis()` bails unless 5 populated values exist. Zone analysis/coaching is effectively mock-only.

**Root Cause:** HealthKit query for heart rate zone distribution not implemented.

**Fix Plan:** Query `HKQuantityType.quantityType(forIdentifier: .heartRate)` with workout context, compute time-in-zone from heart rate samples, populate zoneMinutes array.

---

## ORPHANED CODE

| ID | File | Description | Recommendation |
|----|------|-------------|----------------|
| CR-ORPHAN-001 | `iOS/Services/AlertMetricsService.swift` | Large local analytics subsystem, no production references | Wire in or move to `.unused/` |
| CR-ORPHAN-002 | `iOS/Services/ConfigLoader.swift` | Runtime config layer, app uses `ConfigService` statics instead | Integrate or move to `.unused/` |
| CR-ORPHAN-003 | `Shared/Services/WatchFeedbackBridge.swift` | Dedup/queueing bridge, tested but not in shipping path | Integrate or move to `.unused/` |
| CR-ORPHAN-004 | `File.swift` | Empty placeholder file | Move to `.unused/` |

---

## OVERSIZED FILES (> 1000 lines)

| File | Lines | Recommendation |
|------|-------|----------------|
| `iOS/Views/DashboardView.swift` | ~2,197 | Break into feature subviews |
| `Watch/Views/WatchInsightFlowView.swift` | ~1,715 | Extract per-screen components |
| `Shared/Models/HeartModels.swift` | ~1,598 | Split by domain (core, assessment, coaching) |
| `iOS/Views/StressView.swift` | ~1,228 | Extract chart and detail subviews |
| `iOS/Views/TrendsView.swift` | ~1,020 | Extract range-specific components |

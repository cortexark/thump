# Watch UI — Implementation Status

## Revenue Target

$10k/month = ~2,000 subscribers at $4.99/mo.

The apps that hit this number all do one thing: **raw data → single daily score → color-coded action → morning check-in habit → retention.**

- WHOOP ($260M revenue): Recovery Score
- Oura ($1B revenue): Readiness Score
- Athlytic ($3.6M ARR): Recovery Score (WHOOP for Apple Watch)
- Gentler Streak (50k+ subs): Activity Path

Our angle: **WHOOP's intelligence + an emotional companion character, on the Apple Watch you already own, at $4.99/mo.**

## Architecture

`ThumpWatchApp` → `WatchInsightFlowView` (7-screen TabView)

- **Screen 0: Readiness face** — The billboard. Score + buddy + actionable nudge.
- **Screens 1-6: Data screens** — The proof. Plan, steps, goal progress, stress, sleep, metrics.

## What's Implemented (compiles, builds, 717 tests pass)

### Screen 0: BuddyLivingScreen (`WatchLiveFaceView.swift`)

| Element | Purpose | Revenue justification |
|---------|---------|----------------------|
| Readiness score (top, large, color-coded) | Morning check-in number | WHOOP/Oura prove this creates daily habit → retention |
| Score color dot (green/yellow/red) | Instant readiness at a glance | Same color language as WHOOP Recovery |
| Short label next to score ("Strong"/"Low"/"Stress") | Context for the number | Removes need to open app further |
| ThumpBuddy (size 72, mood-reactive) | Emotional anchor | No competitor has a character — this is our moat |
| Atmospheric sky gradient (8 moods) | Visual differentiation | This is NOT another dashboard app |
| Floating particles (18, Canvas-rendered) | Ambient life | Makes screenshots/ads memorable |
| Ground glow (RadialGradient, pulsing) | World-building | Buddy lives in a place, not on a screen |
| "Where you are" line | Concrete status from engine data | Users pay for interpretation, not raw numbers |
| "What next to boost" line | Actionable next step | The coaching value proposition |
| Tap → breathing session (stressed mood) | Functional: 5 cycles, 40s guided breathing | Real health intervention |
| Tap → walk prompt (nudging mood) | Functional: shows nudge + Start → Apple Workout | Bridges to Apple's exercise tracking |
| Tap → peek card (all other moods) | Functional: shows detailed metrics | Crown scroll also opens this |
| Crown scroll → peek card | Detailed metrics view | Cardio score, trend, stress, data confidence |

**What was removed and why:**

| Removed | Reason |
|---------|--------|
| Rest overlay ("Cozy night ahead") | Shows text for 4s, does nothing. The status line already says "Recovery needed" + "Bed by 10pm rebuilds score" |
| Celebration overlay ("You're doing great!") | Shows text for 4s, does nothing. Buddy's conquering mood + status line communicate this |
| Health summary overlay | Merged into peek card — that's where detailed metrics belong |
| Active progress overlay ("Keep going!") | Shows text for 4s, does nothing. Status line says "Activity in progress" |

Rule applied: **every tap must DO something functional or show real data. No motivational text overlays.**

### Complications (`ThumpComplications.swift`)

| Complication | What it shows | Why |
|-------------|---------------|-----|
| Circular | Score number inside colored Gauge ring | The "what app is that?" moment on a friend's wrist. Athlytic's #1 growth driver |
| Rectangular | Score circle + status line + nudge line | Daily glanceable summary — users check this without opening the app |
| Corner | Score number or mood icon | Minimal, score-first |
| Inline | Heart icon + score + mood label | Text-only surfaces |

**Data pipeline**: Assessment arrives → `WatchViewModel.updateComplication()` → writes to shared UserDefaults (`group.com.thump.shared`) → `WidgetCenter.shared.reloadTimelines()` → provider reads and returns entry.

### Data Screens (Screens 1-6, unchanged)

| Screen | What it shows | Engine data |
|--------|--------------|-------------|
| 1: Plan | 3-state buddy (idle/active/done), time-aware messaging | Assessment, nudge |
| 2: Walk Nudge | Emoji + step count + context message | HealthKit stepCount |
| 3: Goal Progress | Ring + minutes done/remaining | HealthKit exerciseTime |
| 4: Stress | 12-hr HR heatmap + Breathe button | HealthKit heartRate, restingHR |
| 5: Sleep | Hours slept + bedtime + trend pill | HealthKit sleepAnalysis |
| 6: Metrics | HRV + RHR tiles with deltas | HealthKit HRV, restingHR |

## What's NOT Implemented

| Feature | Impact | What's needed |
|---------|--------|---------------|
| Widget extension target | **Blocking**: complications compile but won't appear on watch faces | Separate WidgetKit extension target in `project.yml` |
| Breathing session haptics | Medium: haptic feedback during breathe in/out | `WKInterfaceDevice.current().play(.start)` calls |
| Reduced motion accessibility | Medium: particles/sky don't respect `AccessibilityReduceMotion` | Check `UIAccessibility.isReduceMotionEnabled` |
| Live HealthKit on watch | Low: status uses phone assessment only | On-watch step count, sleep hours for fresher data |
| Pattern-based time engine | Future: smarter "what next" based on user patterns | Engine that learns exercise/sleep/stress timing |
| Breath prompt from phone | Low: screen 0 doesn't listen for phone-initiated breathe | `connectivityService.breathPrompt` subscription |

## Competitive Analysis (March 2026)

| App | Monthly price | What they sell | Our advantage |
|-----|--------------|----------------|---------------|
| WHOOP | $30/mo | Recovery Score + strain tracking | We're $4.99, no extra hardware, same intelligence |
| Oura | $5.99/mo | Readiness Score (requires $299+ ring) | No ring needed, character companion |
| Athlytic | $4.99/mo | Recovery/Exertion/Sleep scores | We have coaching nudges + character, not just numbers |
| Gentler Streak | $7.99/mo | Activity Path, rest-first philosophy | We combine activity tracking with stress/recovery |
| Apple Fitness | Free | Activity Rings, basic HR | We interpret data — what it MEANS and what to DO |

**Key insight from research**: 80% of health app revenue comes from subscriptions. Users pay for interpretation (scores, readiness) not raw data (HR, steps). The morning check-in habit (look at score → decide push/rest) is the #1 retention mechanism.

## Files

| File | Change | Purpose |
|------|--------|---------|
| `Watch/Views/WatchLiveFaceView.swift` | Rewritten | Readiness face: score + buddy + status + functional actions only |
| `Watch/Views/ThumpComplications.swift` | Rewritten | Score-first complications, status data pipeline |
| `Watch/ViewModels/WatchViewModel.swift` | Modified | Passes `status` to complication data |
| `Watch/Views/WatchInsightFlowView.swift` | Modified | Living face as screen 0, data screens 1-6 |
| `Watch/ThumpWatchApp.swift` | Unchanged | Entry point: WatchInsightFlowView with environment objects |

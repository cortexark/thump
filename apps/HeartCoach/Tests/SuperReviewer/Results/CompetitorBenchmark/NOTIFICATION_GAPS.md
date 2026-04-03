# Notification & Recommendation Gap Analysis

Built by GPT-5.4 + Gemini 3.1 Pro — designing the IDEAL wellness notification system from scratch, then comparing against WHOOP, Oura, and Thump.

Date: 2026-03-29

---

## The Ideal System: 28 Notification Types (GPT-5.4) + 13 Core Types (Gemini 3.1)

Both models converge on the same behavioral loop:
**Anticipate (Morning) -> Adjust (Midday/Real-time) -> Anchor (Evening) -> Reflect (Weekly)**

---

## Gap Matrix: What Each App Sends

| # | Ideal Notification | WHOOP | Oura | Thump | Priority | Effort |
|---|-------------------|:-----:|:----:|:-----:|:--------:|:------:|
| 1 | **Morning Readiness Briefing** | Y | Y | **N** | **P0** | Low |
| 2 | **Bedtime / Wind-Down Reminder** | Y | Y | **N** | **P0** | Low |
| 3 | **Sleep Debt Alert** | Y | Partial | **N** | **P1** | Medium |
| 4 | **High Stress Alert** | N | N | **Y** | -- | -- |
| 5 | **Recovery Drop Alert** | Y | Y | **Y** | -- | -- |
| 6 | **Illness Detection Alert** | Soft | Soft | **N** | **P1** | Medium |
| 7 | **Overtraining Alert** | Y | N | Partial | P2 | Low |
| 8 | **Training Opportunity ("Green Light")** | Y | N | **N** | **P1** | Low |
| 9 | **Midday Movement Nudge** | N | Y | **Y** | -- | -- |
| 10 | **Hydration Reminder** | N | N | **Y** | -- | -- |
| 11 | **Breathing / Downshift Prompt** | N | N | **Y** | -- | -- |
| 12 | **Pre-Workout Guidance** | Y | N | **N** | P2 | Medium |
| 13 | **Post-Workout Recovery** | Y | N | **N** | **P1** | Medium |
| 14 | **Evening Recovery Check** | Y | Y | **N** | **P1** | Low |
| 15 | **Weekly Summary Report** | Y | Y | **N** | P2 | Medium |
| 16 | **Monthly Progress Report** | Y | Y | **N** | P3 | Medium |
| 17 | **Streak / Milestone Celebration** | N | Y | **N** | P2 | Low |
| 18 | **Travel / Timezone Adjustment** | N | N | **N** | P3 | High |
| 19 | **Menstrual Cycle Phase Coach** | Y | Y | **N** | P3 | High |
| 20 | **Personal Best / Achievement** | Y | N | **N** | P2 | Low |
| 21 | **Rebound Confirmation** | N | N | **N** | **P1** | Low |
| 22 | **Weekend Consistency Reminder** | N | N | **N** | P2 | Low |
| 23 | **Sedentary Context Check** | N | Y | Partial | P3 | Medium |
| 24 | **Dynamic Island / Live Activities** | N | N | **N** | P2 | Medium |

**Thump has: 5 of 24 ideal types (21%)**
**WHOOP has: 14 of 24 (58%)**
**Oura has: 12 of 24 (50%)**

---

## Gap Matrix: In-App Recommendations

| # | Ideal Recommendation Scenario | WHOOP | Oura | Thump | Gap? |
|---|------------------------------|:-----:|:----:|:-----:|:----:|
| 1 | High Readiness Push Day | Y | Y | **Y** | -- |
| 2 | Moderate Readiness Maintain Day | Y | Y | **Y** | -- |
| 3 | Low Readiness Lighter Day | Y | Y | **Y** | -- |
| 4 | Severe Sleep Debt Protection | Y | Partial | **Y** | -- |
| 5 | High Stress + Low Readiness | Y | Y | **Y** | -- |
| 6 | High Stress + Adequate Readiness | N | N | **Y** | Thump ahead |
| 7 | Poor Sleep + Strong Readiness | Y | N | **Y** | -- |
| 8 | Overtraining / Absorb Work | Y | N | **Y** | -- |
| 9 | Post-Workout Recovery Guidance | Y | N | **N** | **Gap** |
| 10 | Midday Sedentary Reset | N | Y | **Y** | -- |
| 11 | Strain Target ("How hard today") | Y | N | **N** | **Gap** |
| 12 | Illness-Aware Mode | Soft | Soft | **N** | **Gap** |
| 13 | Cycle Phase Adjustment | Y | Y | **N** | **Gap** |
| 14 | Travel/Jet Lag Adaptation | N | N | **N** | All miss |
| 15 | Rebound Confirmation ("That helped") | N | N | **N** | All miss |
| 16 | Habit Impact Attribution | Y | N | **N** | **Gap** |
| 17 | Evening Wind-Down Guidance | Y | Y | **N** | **Gap** |
| 18 | Weekend Sleep Consistency | N | N | **N** | All miss |

**Thump covers: 10 of 18 recommendation scenarios (56%)**
**WHOOP covers: 13 of 18 (72%)**
**Oura covers: 9 of 18 (50%)**

Thump's in-app recommendations are actually close to Oura and not far from WHOOP. The main gap is **notifications** (5/24 vs 14/24).

---

## Top 10 Missing Notifications/Recommendations — Both Models Aligned

### P0: Ship This Week (Both models say these are retention-critical)

#### 1. Morning Readiness Briefing Push
**Current state:** Thump generates the hero message but only shows it when the user opens the app.
**What WHOOP does:** Recovery score + color + strain target on wake.
**What Oura does:** Readiness score + "One Big Thing" on wake.
**Ideal copy:**
```
Title: "Your body's ready check"
Subtitle: "Recovery, sleep, and stress for today"
Body: "You're trending [below normal] this morning. Open to see whether today is a push, maintain, or recover day."
```
**Trigger:** Sleep session ends OR typical wake window.
**Timing:** 15-45 min after wake.
**Interrupt:** `.passive`
**Effort:** Low — AdvicePresenter already generates this text.

#### 2. Bedtime Wind-Down Push
**Current state:** Thump has no bedtime notification.
**What WHOOP does:** "Time to wind down" based on sleep need.
**What Oura does:** Bedtime reminder based on sleep goal.
**Ideal copy:**
```
Title: "Start winding down"
Subtitle: "Tonight's sleep starts now"
Body: "A calm next hour helps tomorrow's recovery. Dim lights, put screens away, and protect your bedtime."
```
**Trigger:** 60 min before learned bedtime (SmartNudgeScheduler already knows this).
**Timing:** Evening, personalized.
**Interrupt:** `.passive`
**Effort:** Low — SmartNudgeScheduler already computes bedtime patterns.

### P1: Ship Next Sprint

#### 3. Post-Workout Recovery Notification
**Current state:** Nothing. User completes a workout, silence.
**What WHOOP does:** Strain score update + recovery guidance.
**Ideal copy:**
```
Title: "Nice work — recover it well"
Subtitle: "The next hour matters"
Body: "Rehydrate, eat, and let your system come down. Open for your post-workout recovery step."
```
**Trigger:** HKWorkout session ends. Wait 15 min for HR to settle.
**Interrupt:** `.passive`
**Effort:** Medium — need workout completion observer.

#### 4. Training Opportunity ("Green Light")
**Current state:** Hero message says "good day to push" but no proactive push notification.
**What WHOOP does:** Strain Coach + "your body can handle X strain today."
**Ideal copy:**
```
Title: "Today looks like a push day"
Subtitle: "Your body is ready for more"
Body: "Recovery is strong and stress is manageable. If you've planned a hard session, this is a good day for it."
```
**Trigger:** Readiness 80+ AND stress not elevated AND sleep adequate.
**Timing:** Morning, max 3/week.
**Interrupt:** `.passive`
**Effort:** Low — ReadinessEngine already computes this.

#### 5. Illness Detection Alert
**Current state:** "Pattern Shift Detected" — too vague, doesn't say "you might be sick."
**What WHOOP does:** Health Monitor flags multi-signal deviation.
**What Oura does:** Temperature + RHR + HRV convergence flagged.
**Ideal copy:**
```
Title: "Your body may be fighting something"
Subtitle: "Recovery signals look unusually off"
Body: "Several signals moved outside your normal range overnight. Keep today light, monitor symptoms, and prioritize rest."
```
**Trigger:** anomalyScore > 3.0 AND (HRV dip > 30% OR RHR spike > 10%) AND (temp elevated if available).
**Interrupt:** `.active`
**Effort:** Medium — need multi-signal convergence logic.

#### 6. Evening Recovery Check-In
**Current state:** Nothing between afternoon nudge and next morning.
**What WHOOP does:** Evening wind-down coaching on hard days.
**Ideal copy:**
```
Title: "Set up tomorrow now"
Subtitle: "Tonight matters"
Body: "Today put some load on your system. A calm evening and earlier bedtime can help recovery rebound."
```
**Trigger:** Hard day (strain high OR stress elevated OR readiness low).
**Timing:** Early evening (6-8 PM).
**Interrupt:** `.passive`
**Effort:** Low.

#### 7. Rebound Confirmation ("That Helped")
**Current state:** Neither WHOOP nor Oura does this either. First-mover advantage.
**What the ideal does:** Confirms when following advice actually worked.
**Ideal copy:**
```
Title: "That recovery choice helped"
Subtitle: "Your signals bounced back"
Body: "Recovery improved after yesterday's lighter day. Worth repeating when needed."
```
**Trigger:** User followed recovery advice AND next-day readiness improved significantly.
**Interrupt:** `.passive`
**Effort:** Low — compare yesterday's advice state to today's readiness.

### P2: Ship Within 2 Sprints

#### 8. Weekly Summary Report
**Current state:** Weekly report exists in Insights view but no push notification.
**Ideal copy:**
```
Title: "Your week in recovery"
Subtitle: "Trends, wins, and what to change"
Body: "See what helped, what hurt, and the one habit most likely to improve next week."
```
**Trigger:** Sunday 9 AM.
**Effort:** Medium.

#### 9. Streak / Milestone Celebration
**Current state:** Streak badge exists on Dashboard but no push notification for milestones.
**Ideal copy:**
```
Title: "5 Strong Days"
Subtitle: "Recovery above baseline all week"
Body: "Open to see your trendline and what's working."
```
**Trigger:** streak == 7, 14, 30, 60, 90.
**Effort:** Low.

#### 10. Habit Impact Attribution
**Current state:** Correlation Engine shows Pearson r but no habit tagging input.
**What WHOOP does:** "Alcohol lowered your recovery by 18%."
**Ideal copy:**
```
Title: "Late meals affected your sleep"
Subtitle: "HRV dropped 12% on those nights"
Body: "When you tagged late eating, your deep sleep and HRV both dropped the next morning."
```
**Trigger:** Enough habit tags + correlation significance.
**Effort:** Medium — needs habit tagging system first.

---

## What Thump Does BETTER Than Both Competitors

Both models identified these Thump strengths that WHOOP and Oura lack:

| Feature | Thump | WHOOP | Oura |
|---------|:-----:|:-----:|:----:|
| Real-time stress alerts | **Y** | N | N |
| Hydration reminders | **Y** | N | N |
| Breathing session prompts | **Y** | N | N |
| High stress + adequate readiness guidance | **Y** | N | N |
| Hourly stress heatmap | **Y** | N | N |
| Context-aware stress (acute vs desk) | **Y** | N | N |
| Readiness gate on stress guidance | **Y** | N | N |
| On-device privacy (no cloud health data) | **Y** | N | N |

---

## Implementation Priority: The Notification Sprint

**Week 1 (P0 + P1 low-effort):**
1. Morning Readiness Briefing Push — reuse AdvicePresenter text
2. Bedtime Wind-Down Push — reuse SmartNudgeScheduler bedtime
3. Training Opportunity Push — reuse ReadinessEngine threshold
4. Evening Recovery Check — conditional on hard-day detection
5. Rebound Confirmation — compare yesterday advice to today readiness

**Week 2 (P1 medium-effort):**
6. Post-Workout Recovery Push — add HKWorkout completion observer
7. Illness Detection Alert — multi-signal convergence threshold

**Week 3 (P2):**
8. Weekly Summary Push
9. Streak Milestone Push
10. Habit Impact Attribution (requires habit tagging)

After this sprint: **Thump goes from 5/24 notification types (21%) to 15/24 (63%)** — ahead of Oura (50%) and closing on WHOOP (58%).

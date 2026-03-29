Here’s a thorough senior-level review. Overall: the architecture is promising, but there are several **production-risk issues** around **races, duplicate scheduling, time handling, history growth, and test incompleteness** that would absolutely surface at scale.

---

# What the code does WELL

Keep these patterns:

1. **Protocol-based dependency injection**
   - `UserNotificationCenterType` and `ProactiveHistoryStoreType` are good abstractions for testing and future replacement.

2. **Async/await API shape**
   - The public scheduling/evaluation APIs are modern and readable.

3. **Actor-backed test doubles**
   - Using `actor` for mocks is directionally good for thread safety.

4. **Eligibility separated from scheduling**
   - `NotificationEligibility` is a good seam for logic isolation.

5. **Notification content avoids raw health metrics in body**
   - The copy is mostly qualitative and avoids explicit scores.

6. **Thread grouping**
   - `threadIdentifier` use is good for user-facing grouping.

7. **Some rate limiting exists**
   - Weekly max and cooldown logic are better than no controls.

---

# High-level production risks

The biggest issues:

- **Duplicate notifications due to check-then-schedule races**
- **No idempotency / no dedupe against pending requests**
- **History log written at schedule time instead of delivery time**
- **Time zone / DST / day-boundary behavior is not calendar-safe**
- **Unlimited history growth**
- **No global daily budget**
- **No cleanup of pending requests; can approach iOS limits**
- **MainActor on whole service is unnecessary and potentially harmful**
- **Several tests don’t compile / are invalid actor accesses**
- **Silent semantic failures: notification scheduled “successfully” but never shown / wrong time / stale assumptions**

---

# Issues found

---

## 1) Race condition: eligibility check and scheduling are not atomic
**Severity:** CRITICAL  
**Location:** Every public scheduling API + `schedule(content:trigger:type:)`

### What goes wrong
Two concurrent refreshes can both do:

1. `isEligible(...) == true`
2. `notificationCenter.add(...)`
3. `historyStore.logNotification(...)`

Result: duplicate notifications of same type.

This is likely in production when:
- app launches and background refresh overlap
- watch + phone both trigger logic
- HealthKit observer and app foreground refresh happen near-simultaneously

`@MainActor` does **not** save you across process/device boundaries, and even on one device it doesn’t make the eligibility-store-notification-center sequence transactional.

### Fix
Introduce a dedicated actor that serializes scheduling decisions per notification type and checks pending requests before adding.

```swift
import Foundation
import UserNotifications

actor ProactiveSchedulingGate {
    private var inFlightTypes: Set<ProactiveNotificationType> = []

    func begin(_ type: ProactiveNotificationType) -> Bool {
        if inFlightTypes.contains(type) { return false }
        inFlightTypes.insert(type)
        return true
    }

    func end(_ type: ProactiveNotificationType) {
        inFlightTypes.remove(type)
    }
}
```

Then in service:

```swift
public final class ProactiveNotificationService: ObservableObject {
    private let notificationCenter: UserNotificationCenterType
    private let eligibility: NotificationEligibility
    private let historyStore: ProactiveHistoryStoreType
    private let config: ProactiveNotificationConfig
    private let schedulingGate = ProactiveSchedulingGate()

    // remove @MainActor from whole class unless UI state truly requires it
}
```

And use it in `schedule`:

```swift
private func scheduleIfNeeded(
    content: UNMutableNotificationContent,
    trigger: UNNotificationTrigger?,
    type: ProactiveNotificationType
) async throws {
    let acquired = await schedulingGate.begin(type)
    guard acquired else { return } // Already being scheduled elsewhere

    defer {
        Task { await schedulingGate.end(type) }
    }

    let pending = await notificationCenter.pendingNotificationRequests()
    if pending.contains(where: { Self.matchesType($0.identifier, type: type) }) {
        return
    }

    let identifier = Self.identifier(for: type)
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    try await notificationCenter.add(request)
    await historyStore.logNotification(type: type, at: Date())
}

private static func identifier(for type: ProactiveNotificationType) -> String {
    "com.thump.\(type.rawValue)"
}

private static func matchesType(_ identifier: String, type: ProactiveNotificationType) -> Bool {
    identifier == Self.identifier(for: type)
}
```

---

## 2) Duplicate scheduling because identifiers are random UUIDs
**Severity:** HIGH  
**Location:** `schedule(content:trigger:type:)`

```swift
let uuid = UUID().uuidString
let identifier = "com.thump.\(type.rawValue).\(uuid)"
```

### What goes wrong
Because every notification gets a fresh UUID, the system cannot replace/update an existing pending notification of the same type. This guarantees duplicates over time.

### Fix
Use **stable identifiers**, optionally type + day bucket if you need more than one over time.

```swift
private static func identifier(for type: ProactiveNotificationType, date: Date = Date(), calendar: Calendar = .current) -> String {
    let day = calendar.startOfDay(for: date).timeIntervalSince1970
    return "com.thump.\(type.rawValue).\(Int(day))"
}
```

For one-at-a-time semantics, even simpler:

```swift
private static func identifier(for type: ProactiveNotificationType) -> String {
    "com.thump.\(type.rawValue)"
}
```

Then schedule with that identifier.

---

## 3) Logging notification history at schedule time is semantically wrong
**Severity:** HIGH  
**Location:** `schedule(content:trigger:type:)`

```swift
try await notificationCenter.add(request)
await historyStore.logNotification(type: type)
```

### What goes wrong
You record a notification as “sent” when it is merely **scheduled**.

Examples:
- bedtime wind-down scheduled for 10 PM at 8 AM => budget/cooldown spent all day
- user disables notifications after scheduling
- pending notification is canceled before firing
- system drops delivery
- app reschedules repeatedly while counting each as “already sent”

This contaminates cooldowns and budgets.

### Fix
Persist **scheduled** and **delivered** separately, or at minimum store scheduled timestamps with cleanup and use delivered timestamps for policy enforcement when possible.

Update protocol:

```swift
public protocol ProactiveHistoryStoreType: Sendable {
    func hasOpenedAppToday(now: Date, calendar: Calendar) async -> Bool
    func logScheduledNotification(type: ProactiveNotificationType, at date: Date) async
    func logDeliveredNotification(type: ProactiveNotificationType, at date: Date) async
    func fetchNotificationTimestamps(for type: ProactiveNotificationType) async -> [Date]
    func pruneNotificationHistory(olderThan cutoff: Date) async
    func isInSleepSession() async -> Bool
    func hasCompletedRecoveryNudgeToday(now: Date, calendar: Calendar) async -> Bool
}
```

And schedule:

```swift
try await notificationCenter.add(request)
await historyStore.logScheduledNotification(type: type, at: Date())
```

Then use `UNUserNotificationCenterDelegate` delivery callbacks in app layer to log delivery. If you cannot, at least name it `logScheduledNotification` to avoid semantic confusion.

---

## 4) No check for existing pending request of same type
**Severity:** HIGH  
**Location:** All scheduling paths

### What goes wrong
Even if history says eligible, there may already be a pending request for this type. Example:
- morning briefing scheduled overnight
- another refresh in morning schedules another one
- history won’t necessarily reflect pending-vs-delivered correctly

### Fix
Add this check before scheduling:

```swift
private func hasPendingNotification(of type: ProactiveNotificationType) async -> Bool {
    let pending = await notificationCenter.pendingNotificationRequests()
    return pending.contains { request in
        request.identifier == Self.identifier(for: type)
    }
}
```

Use in eligibility or scheduling gate:

```swift
if await hasPendingNotification(of: type) { return }
```

---

## 5) `@MainActor` on entire service is over-broad and harms concurrency design
**Severity:** MEDIUM  
**Location:** `@MainActor public final class ProactiveNotificationService`

### What goes wrong
This service is not UI-bound. Pinning all scheduling and history work to main actor:
- serializes unnecessary IO-like operations on main actor
- encourages unsafe assumptions that “MainActor == no races”
- makes testing and background execution awkward
- can interact badly if called from background tasks

### Fix
Remove `@MainActor` from the class. If it needs published UI state later, isolate only those methods/properties.

```swift
public final class ProactiveNotificationService: ObservableObject {
    // ...
}
```

If you need some UI-facing methods:

```swift
@MainActor
public func bindUIState(...) { ... }
```

---

## 6) `NotificationEligibility` uses `Calendar.current` repeatedly, making behavior unstable across travel/time-zone changes
**Severity:** HIGH  
**Location:** `NotificationEligibility.isEligible`

Examples:
```swift
Calendar.current.isDate($0, inSameDayAs: date)
Calendar.current.date(byAdding: .day, value: -7, to: date)
```

### What goes wrong
`Calendar.current` reflects the device’s current locale/time zone at execution time, not necessarily the context in which the event was logged.

Problems:
- user travels time zones: “today” changes unexpectedly
- DST changes shift weekly windows unexpectedly
- watch/phone may disagree if not synchronized promptly

### Fix
Inject a `Calendar` and `TimeZone` policy, ideally autoupdating current for user-facing scheduling, but use one consistent calendar per evaluation.

```swift
public struct NotificationEligibility: Sendable {
    private let historyStore: ProactiveHistoryStoreType
    private let config: ProactiveNotificationConfig
    private let calendar: Calendar

    public init(
        historyStore: ProactiveHistoryStoreType,
        config: ProactiveNotificationConfig = .init(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.historyStore = historyStore
        self.config = config
        self.calendar = calendar
    }

    public func isEligible(
        for type: ProactiveNotificationType,
        at date: Date = Date(),
        snapshotDate: Date? = nil
    ) async -> Bool {
        if let snapshotDate, date.timeIntervalSince(snapshotDate) > (config.morningBriefingStaleHours * 3600) {
            return false
        }

        switch type {
        case .morningBriefing:
            let opened = await historyStore.hasOpenedAppToday(now: date, calendar: calendar)
            let sentDates = await historyStore.fetchNotificationTimestamps(for: type)
            let sentToday = sentDates.contains { calendar.isDate($0, inSameDayAs: date) }
            return !opened && !sentToday

        case .trainingOpportunity:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: date) else { return false }
            let recentSends = await historyStore.fetchNotificationTimestamps(for: type)
            return recentSends.filter { $0 >= weekAgo && $0 <= date }.count < config.trainingOpportunityMaxPerWeek

        case .illnessDetection:
            let sentDates = await historyStore.fetchNotificationTimestamps(for: type)
            if let lastSent = sentDates.max(), date.timeIntervalSince(lastSent) < config.illnessDetectionCooldownHours * 3600 {
                return false
            }
            return true

        case .eveningRecovery:
            let completed = await historyStore.hasCompletedRecoveryNudgeToday(now: date, calendar: calendar)
            let sentDates = await historyStore.fetchNotificationTimestamps(for: type)
            let sentToday = sentDates.contains { calendar.isDate($0, inSameDayAs: date) }
            return !completed && !sentToday

        case .bedtimeWindDown:
            let sleeping = await historyStore.isInSleepSession()
            return !sleeping

        default:
            return true
        }
    }
}
```

---

## 7) Bedtime/evening scheduling uses `timeIntervalSinceNow`, which is fragile across DST/system clock changes
**Severity:** HIGH  
**Location:**  
- `scheduleBedtimeWindDown`
- `scheduleEveningRecoveryCheck`

### What goes wrong
Computing delays from `Date` and creating `UNTimeIntervalNotificationTrigger` means:
- DST transitions can make “1 hour before bedtime” become wrong in wall-clock terms
- manual device clock changes shift behavior
- timezone travel after scheduling won’t reinterpret relative trigger in local wall time

For bedtime-oriented alerts, **calendar-based triggers** are safer.

### Fix
Use `UNCalendarNotificationTrigger` based on local date components.

```swift
private let calendar: Calendar = .autoupdatingCurrent

public func scheduleBedtimeWindDown(expectedBedtime: Date, sleepDebtHours: Double, tomorrowImportance: Int) async throws {
    let isEligible = await eligibility.isEligible(for: .bedtimeWindDown)
    guard isEligible else { throw ProactiveNotificationError.ineligible }

    let body: String
    if sleepDebtHours > 1.5 {
        body = "You’ve been carrying some sleep debt lately. A 20-minute wind-down might help your recovery tonight."
    } else {
        body = "Getting ready for bed soon could support your usual baseline tomorrow. A 10-minute stretch may help."
    }

    let content = buildContent(title: "Wind Down", body: body, interruptionLevel: .passive, type: .bedtimeWindDown)

    guard let targetDate = calendar.date(byAdding: .minute, value: -Int(config.bedtimeWindDownLeadMinutes), to: expectedBedtime),
          targetDate > Date() else { return }

    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    try await scheduleIfNeeded(content: content, trigger: trigger, type: .bedtimeWindDown)
}
```

Do same for evening recovery.

---

## 8) Bedtime across midnight is underspecified and may skip or mis-time notifications
**Severity:** HIGH  
**Location:** `scheduleBedtimeWindDown(expectedBedtime:)`, `scheduleEveningRecoveryCheck(expectedBedtime:)`

### What goes wrong
If caller passes an `expectedBedtime` that represents “11:00 PM” on the wrong date, the service silently:
- schedules too early
- schedules tomorrow instead of tonight
- returns without scheduling because target already passed

This will absolutely happen with learned habits if only hour/minute is modeled elsewhere.

### Fix
Validate bedtime date is in the future and within a sane horizon, or accept **bedtime components + anchor day** instead of raw `Date`.

Example defensive check:

```swift
private func normalizedUpcomingDate(_ date: Date, maxFutureDays: Int = 2, calendar: Calendar) -> Date? {
    let now = Date()
    guard date > now else { return nil }
    guard let maxDate = calendar.date(byAdding: .day, value: maxFutureDays, to: now), date <= maxDate else {
        return nil
    }
    return date
}
```

Then:

```swift
guard let expectedBedtime = normalizedUpcomingDate(expectedBedtime, calendar: calendar) else {
    throw ProactiveNotificationError.belowThreshold
}
```

Better API long-term:

```swift
public func scheduleBedtimeWindDown(expectedBedtimeComponents: DateComponents, anchorDate: Date = Date()) async throws
```

---

## 9) No global daily budget enforcement
**Severity:** HIGH  
**Location:** Entire service/config

### What goes wrong
Your prompt explicitly mentions “all 3 daily notifications spent by 9 AM?” There is **no daily budget mechanism at all**.

At scale, users can get:
- morning briefing
- training opportunity
- illness detection
- post-workout
- evening recovery
- rebound confirmation
... all same day.

This is a retention risk.

### Fix
Add a daily budget policy in config/history.

```swift
public struct ProactiveNotificationConfig: Sendable {
    public let maxNotificationsPerDay: Int
    // ...
    public init(
        maxNotificationsPerDay: Int = 3
    ) {
        self.maxNotificationsPerDay = maxNotificationsPerDay
    }
}
```

Add store API:

```swift
func fetchAllNotificationTimestamps() async -> [Date]
```

Then:

```swift
private func hasRemainingDailyBudget(at date: Date) async -> Bool {
    let all = await historyStore.fetchAllNotificationTimestamps()
    let todayCount = all.filter { calendar.isDate($0, inSameDayAs: date) }.count
    return todayCount < config.maxNotificationsPerDay
}
```

And in atomic scheduling path:

```swift
guard await hasRemainingDailyBudget(at: Date()) else {
    throw ProactiveNotificationError.ineligible
}
```

Long-term, budget should prioritize by severity:
- illnessDetection > postWorkoutRecovery > bedtime/evening > trainingOpportunity

---

## 10) No priority system when budget is exhausted
**Severity:** MEDIUM  
**Location:** Entire service design

### What goes wrong
Even after adding budget, without priority you may spend all daily budget on low-value nudges and block important alerts later.

### Fix
Add priority:

```swift
public enum ProactivePriority: Int, Sendable {
    case criticalHealth = 100
    case importantRecovery = 75
    case informational = 50
    case lowValue = 25
}

extension ProactiveNotificationType {
    var priority: ProactivePriority {
        switch self {
        case .illnessDetection: return .criticalHealth
        case .postWorkoutRecovery, .eveningRecovery: return .importantRecovery
        case .morningBriefing, .reboundConfirmation: return .informational
        case .trainingOpportunity, .bedtimeWindDown: return .lowValue
        }
    }
}
```

Then allow high-priority notifications through if lower-priority budget was used, or reserve slots.

---

## 11) Unbounded growth of notification history arrays
**Severity:** HIGH  
**Location:** `MockHistoryStore.loggedNotifications`, implied real store API

### What goes wrong
`[ProactiveNotificationType: [Date]]` grows forever unless cleaned. Real store will too if implemented similarly.

Impacts:
- memory growth
- slower fetch/filter operations
- stale data affects cooldown windows incorrectly if APIs aren’t careful

### Fix
Prune aggressively.

```swift
public protocol ProactiveHistoryStoreType: Sendable {
    // ...
    func pruneNotificationHistory(olderThan cutoff: Date) async
}
```

Actor implementation:

```swift
actor MockHistoryStore: ProactiveHistoryStoreType {
    var openedAppToday = false
    var inSleepSession = false
    var completedRecoveryNudgeToday = false
    var loggedNotifications: [ProactiveNotificationType: [Date]] = [:]

    func logScheduledNotification(type: ProactiveNotificationType, at date: Date) async {
        loggedNotifications[type, default: []].append(date)
        let cutoff = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -30, to: date) ?? date
        await pruneNotificationHistory(olderThan: cutoff)
    }

    func pruneNotificationHistory(olderThan cutoff: Date) async {
        for key in loggedNotifications.keys {
            loggedNotifications[key] = loggedNotifications[key]?.filter { $0 >= cutoff }
            if loggedNotifications[key]?.isEmpty == true {
                loggedNotifications[key] = nil
            }
        }
    }
}
```

For production, prune to the max needed window:
- 7 days for training
- 2 days for illness cooldown
- maybe 30 days max for diagnostics

---

## 12) Notification center pending limit risk (64)
**Severity:** HIGH  
**Location:** Entire scheduling design

### What goes wrong
iOS caps pending notifications at around 64 per app. This code:
- never removes superseded requests
- uses random identifiers
- can repeatedly schedule future bedtime/evening/post-workout alerts

At scale, pending queue can fill, causing future adds to fail or old requests to be dropped unpredictably.

### Fix
Use stable identifiers and remove/replace prior requests before adding.

```swift
private func replacePendingRequest(
    content: UNMutableNotificationContent,
    trigger: UNNotificationTrigger?,
    type: ProactiveNotificationType
) async throws {
    let identifier = Self.identifier(for: type)
    notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    try await notificationCenter.add(request)
}
```

Also add maintenance cleanup:

```swift
public func pruneSupersededPendingRequests() async {
    let pending = await notificationCenter.pendingNotificationRequests()
    let grouped = Dictionary(grouping: pending) { request in
        ProactiveNotificationType.allCases.first { request.identifier.contains($0.rawValue) }
    }

    for (_, requests) in grouped {
        guard requests.count > 1 else { continue }
        let idsToDelete = requests.dropFirst().map(\.identifier)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: idsToDelete)
    }
}
```

---

## 13) `cancelPendingAlerts` identifier matching is inconsistent with comments and fragile
**Severity:** MEDIUM  
**Location:** `cancelPendingAlerts(for:)`

```swift
let identifiersToCancel = types.map { $0.rawValue }
// We look for requests that start with our prefix rules: com.thump.{type}
if request.identifier.starts(with: "com.thump.\(type)")
```

### What goes wrong
- Variable name `identifiersToCancel` is actually raw values, not IDs
- prefix matching could cancel unrelated IDs if future naming changes
- comments mention one convention; thread identifier uses another

### Fix
Centralize identifier format and matching:

```swift
public func cancelPendingAlerts(for types: [ProactiveNotificationType]) async {
    let pending = await notificationCenter.pendingNotificationRequests()
    let matchingIDs = pending.compactMap { request in
        types.contains { request.identifier == Self.identifier(for: $0) } ? request.identifier : nil
    }
    notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingIDs)
}
```

If day-bucketed identifiers are used, parse exactly:

```swift
private static func isIdentifier(_ identifier: String, for type: ProactiveNotificationType) -> Bool {
    identifier == "com.thump.\(type.rawValue)" || identifier.hasPrefix("com.thump.\(type.rawValue).")
}
```

---

## 14) `scheduleEveningRecoveryCheck` may schedule “immediately” even if the bedtime window already passed hours ago
**Severity:** MEDIUM  
**Location:** `scheduleEveningRecoveryCheck`

```swift
let delay = max(targetDate.timeIntervalSinceNow, 60.0)
```

### What goes wrong
If expected bedtime was 3 hours ago, this schedules a notification in 60 seconds, which is likely wrong and intrusive.

### Fix
If target is already in the past beyond a grace period, skip.

```swift
let now = Date()
guard targetDate > now else {
    return // or throw ineligible/belowThreshold
}
```

If you want grace:

```swift
if now.timeIntervalSince(targetDate) > 15 * 60 {
    return
}
let delay = max(targetDate.timeIntervalSince(now), 60)
```

---

## 15) `scheduleBedtimeWindDown` silently returns instead of reporting inability to schedule
**Severity:** LOW  
**Location:** `scheduleBedtimeWindDown`

```swift
guard delay > 0 else { return }
```

### What goes wrong
Caller cannot distinguish:
- successful schedule
- skipped because too late
- eligibility false
- stale data

This makes behavior hard to reason about and test.

### Fix
Throw explicit error or return result enum.

```swift
public enum ProactiveNotificationError: Error {
    case ineligible
    case staleData
    case belowThreshold
    case pastSchedulingWindow
}
```

Then:

```swift
guard targetDate > Date() else { throw ProactiveNotificationError.pastSchedulingWindow }
```

---

## 16) First-run experience is underdesigned
**Severity:** MEDIUM  
**Location:** Entire decision/copy layer

### What goes wrong
On first run:
- no baseline
- no learned bedtime
- no meaningful “trending above your baseline” claim
- illness/consecutive-day logic may be unavailable
- copy may overstate confidence

Some copy says “updated baseline” or “well above your typical baseline” even if no baseline exists.

### Fix
Gate baseline-dependent copy with confidence / baseline availability.

Add state:

```swift
public struct AdviceState: Sendable {
    let heroMessageID: String
    let focusInsightID: String
    let mode: AdviceMode
    let stressGuidanceLevel: Int
    let readinessLevel: ReadinessLevel
    let numericalReadiness: Double
    let baselineConfidence: Double
}
```

Then:

```swift
let body: String
if state.baselineConfidence >= 0.7 {
    body = "Your recovery metrics are trending well above your typical baseline today. It might be a good opportunity to push your physical training if you feel up for it."
} else {
    body = "Your recent recovery signals look favorable today. If you feel up for it, this could be a reasonable day for a more challenging session."
}
```

---

## 17) Copy quality: some messages are too assertive or medically risky
**Severity:** MEDIUM  
**Location:** various `buildContent` call sites

### What goes wrong
The request asked for hedged/baseline-anchored rules. Some copy violates this subtly:
- “Your Body is Ready” is stronger than body text
- “Rest Pays Off” implies causation
- “Recovery Disruption Detected” + time-sensitive may feel diagnostic
- “consult your doctor if you feel unwell” is okay, but title/body should remain non-diagnostic

### Fix
Use more hedged titles:

```swift
title: "Recovery Looks Favorable"
body: "Your recovery metrics are trending above your usual range today. If you feel up for it, this may be a good opportunity for harder training."
```

```swift
title: "Recovery May Be Strained"
body: "Your overnight metrics show a sustained shift from your usual range. It may mean your body is working harder than usual. Consider an easier day, and seek medical advice if you feel unwell."
```

```swift
title: "Recovery Appears Improved"
body: "Taking it easier yesterday may have helped. Your readiness signals improved today. Consider easing back into your routine if you feel up for it."
```

---

## 18) Privacy: `userInfo` includes dispatch timestamp unnecessarily
**Severity:** LOW  
**Location:** `buildContent`

```swift
content.userInfo = [
    "notificationType": type.rawValue,
    "dispatchedAt": Date().timeIntervalSince1970
]
```

### What goes wrong
Not a severe leak, but:
- timestamp can aid correlation/debugging beyond necessity
- userInfo may be surfaced in logs or analytics if mishandled downstream
- no need to embed send time in the notification payload

### Fix
Minimize metadata.

```swift
content.userInfo = [
    "notificationType": type.rawValue
]
```

If internal tracing needed, keep in local store, not payload.

---

## 19) Accessibility: some titles/bodies are okay, but not optimized for VoiceOver clarity
**Severity:** LOW  
**Location:** all copy strings

### What goes wrong
Titles like “Wind Down” are vague out of context. VoiceOver reads title and body; title should be self-contained.

### Fix
Improve title specificity and avoid ambiguous phrases.

Examples:
```swift
title: "Bedtime Wind-Down Reminder"
title: "Post-Workout Recovery Reminder"
title: "Evening Recovery Reminder"
```

Also avoid overly long clauses.

---

## 20) `tomorrowImportance` parameter is unused
**Severity:** LOW  
**Location:** `scheduleBedtimeWindDown(expectedBedtime:sleepDebtHours:tomorrowImportance:)`

### What goes wrong
Dead parameter means:
- misleading API
- likely missing logic
- future callers may assume it matters

### Fix
Either remove it or use it to adjust copy/priority.

```swift
public func scheduleBedtimeWindDown(expectedBedtime: Date, sleepDebtHours: Double) async throws
```

Or:

```swift
let body: String
if tomorrowImportance >= 8 {
    body = "Tomorrow looks important. Starting your wind-down soon may support steadier recovery overnight."
} else if sleepDebtHours > 1.5 {
    body = "You’ve been carrying some sleep debt lately. A 20-minute wind-down might help your recovery tonight."
} else {
    body = "Getting ready for bed soon could support your usual baseline tomorrow. A 10-minute stretch may help."
}
```

---

## 21) `currentState` parameter in post-workout API is unused
**Severity:** LOW  
**Location:** `schedulePostWorkoutRecovery(durationMinutes:isHighIntensity:currentState:)`

### What goes wrong
Another misleading API. Probably intended for suppression if illness/rest day/etc.

### Fix
Use it or remove it.

Example use:
```swift
guard currentState.mode != .illnessMode else { throw ProactiveNotificationError.ineligible }
```

---

## 22) Illness detection only cancels `trainingOpportunity`, not other conflicting “normal” cues
**Severity:** MEDIUM  
**Location:** `evaluateIllnessDetection`

```swift
await cancelPendingAlerts(for: [.trainingOpportunity])
```

### What goes wrong
If illness alert fires, user may still receive:
- postWorkoutRecovery
- reboundConfirmation
- morningBriefing
- eveningRecovery
- bedtimeWindDown

Some are okay, some conflict with “body is strained.”

### Fix
Cancel all contradictory lower-priority nudges.

```swift
await cancelPendingAlerts(for: [
    .trainingOpportunity,
    .reboundConfirmation
])
```

Potentially also suppress same-day lower-value notifications through budget/policy state.

---

## 23) Workout sessions spanning midnight / delayed HealthKit delivery not handled
**Severity:** HIGH  
**Location:** `schedulePostWorkoutRecovery`, general event model

### What goes wrong
HealthKit often delivers workouts late. If a workout ended hours ago and the app processes it later, current logic still schedules a notification 15 minutes from *now*, not 15 minutes after workout completion.

If a session spans midnight:
- cooldown/day budget may be applied to wrong day
- late-arriving event can cause weird nocturnal recovery pings

### Fix
Accept workout end date explicitly and bound lateness.

```swift
public func schedulePostWorkoutRecovery(
    workoutEndDate: Date,
    durationMinutes: Double,
    isHighIntensity: Bool,
    currentState: AdviceState
) async throws {
    guard durationMinutes >= config.postWorkoutMinDurationMinutes else {
        throw ProactiveNotificationError.belowThreshold
    }

    let now = Date()
    let elapsed = now.timeIntervalSince(workoutEndDate)
    guard elapsed >= 0 else { throw ProactiveNotificationError.belowThreshold }
    guard elapsed <= 2 * 3600 else { return } // Too stale to notify

    let isEligible = await eligibility.isEligible(for: .postWorkoutRecovery, at: now)
    guard isEligible else { throw ProactiveNotificationError.ineligible }

    let bodyText = isHighIntensity
        ? "That was a solid effort. Consider 10 minutes of active recovery or hydration to gently bring your heart rate down."
        : "Nice work staying active. Even a short 5-minute cooldown may support recovery tomorrow."

    let content = buildContent(title: "Post-Workout Recovery Reminder", body: bodyText, interruptionLevel: .passive, type: .postWorkoutRecovery)

    let remainingDelay = max((config.postWorkoutDelayMinutes * 60) - elapsed, 1)
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingDelay, repeats: false)
    try await scheduleIfNeeded(content: content, trigger: trigger, type: .postWorkoutRecovery)
}
```

---

## 24) Morning briefing stale-data path throws `.ineligible` instead of `.staleData`
**Severity:** LOW  
**Location:** `checkAndScheduleMorningBriefing`, `NotificationEligibility.isEligible`

### What goes wrong
You defined `.staleData` but never use it. This weakens observability and tests.

### Fix
Split stale-data check out of eligibility.

```swift
public func checkAndScheduleMorningBriefing(snapshot: HeartSnapshot, state: AdviceState) async throws {
    let age = Date().timeIntervalSince(snapshot.timestamp)
    guard age <= config.morningBriefingStaleHours * 3600 else {
        throw ProactiveNotificationError.staleData
    }

    let isEligible = await eligibility.isEligible(for: .morningBriefing, snapshotDate: nil)
    guard isEligible else { throw ProactiveNotificationError.ineligible }

    let body = state.baselineConfidence >= 0.7
        ? "Your metrics are trending \(state.readinessLevel == .thriving ? "higher" : "in a more sensitive range") today. Take a moment to review your updated baseline."
        : "Your latest signals suggest today may call for a quick check-in. Take a moment to review your guidance."

    let content = buildContent(title: "Morning Readiness Update", body: body, interruptionLevel: .passive, type: .morningBriefing)
    try await scheduleIfNeeded(content: content, trigger: nil, type: .morningBriefing)
}
```

---

## 25) No observability/telemetry hooks for failure reasons
**Severity:** MEDIUM  
**Location:** Entire service

### What goes wrong
In production, you’ll need to know:
- ineligible due to cooldown?
- pending duplicate?
- daily budget exhausted?
- add failed?
- stale data?
- too-late window?

Without structured outcome reporting, first-week rollout will be blind.

### Fix
Return structured result or emit analytics/logging callback.

```swift
public enum ProactiveNotificationOutcome: Sendable {
    case scheduled
    case skippedDuplicatePending
    case skippedBudgetExceeded
    case skippedIneligible
    case skippedPastWindow
    case skippedStaleData
}
```

Then APIs can return this instead of `Void`.

---

## 26) Potential silent product failure if notification permissions are denied/provisional/focus filtered
**Severity:** MEDIUM  
**Location:** Entire service

### What goes wrong
`add` may succeed, but user never meaningfully sees notifications due to authorization settings, summary, focus, or disabled alerts. The service doesn’t inspect authorization status at all.

### Fix
Add auth status checks and adapt behavior/telemetry.

Protocol:
```swift
public protocol UserNotificationCenterType: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func notificationSettings() async -> UNNotificationSettings
}
```

Use:
```swift
let settings = await notificationCenter.notificationSettings()
guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
    throw ProactiveNotificationError.ineligible
}
```

---

## 27) Test code has actor isolation / compile correctness problems
**Severity:** HIGH  
**Location:** Tests

### What goes wrong

### a) Invalid actor property access
```swift
let pending = await notificationCenter.pendingRequests
```
You cannot directly access actor-isolated stored properties like that from outside actor. Need method call.

### b) `simulateCompletion` extension is invalid
```swift
extension MockHistoryStore {
    func simulateCompletion(nudgeCompleted: Bool) {
        self.completedRecoveryNudgeToday = nudgeCompleted
    }
}
```
This mutates actor-isolated state from a non-actor-isolated sync method. Won’t compile.

### c) Test uses `await historyStore.simulateLogs(...)`
That helper exists on actor, okay, but consistency is poor.

### Fix
Add proper actor methods:

```swift
actor MockUserNotificationCenter: UserNotificationCenterType {
    private var pendingRequests: [UNNotificationRequest] = []

    func add(_ request: UNNotificationRequest) async throws {
        pendingRequests.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }
}

actor MockHistoryStore: ProactiveHistoryStoreType {
    private var openedAppToday = false
    private var inSleepSession = false
    private var completedRecoveryNudgeToday = false
    private var loggedNotifications: [ProactiveNotificationType: [Date]] = [:]

    func hasOpenedAppToday(now: Date, calendar: Calendar) async -> Bool { openedAppToday }
    func isInSleepSession() async -> Bool { inSleepSession }
    func hasCompletedRecoveryNudgeToday(now: Date, calendar: Calendar) async -> Bool { completedRecoveryNudgeToday }

    func logScheduledNotification(type: ProactiveNotificationType, at date: Date) async {
        loggedNotifications[type, default: []].append(date)
    }

    func logDeliveredNotification(type: ProactiveNotificationType, at date: Date) async {
        loggedNotifications[type, default: []].append(date)
    }

    func fetchNotificationTimestamps(for type: ProactiveNotificationType) async -> [Date] {
        loggedNotifications[type] ?? []
    }

    func pruneNotificationHistory(olderThan cutoff: Date) async {
        for key in loggedNotifications.keys {
            loggedNotifications[key] = loggedNotifications[key]?.filter { $0 >= cutoff }
        }
    }

    // helpers
    func setCompletedRecoveryNudgeToday(_ value: Bool) async {
        completedRecoveryNudgeToday = value
    }

    func simulateLogs(type: ProactiveNotificationType, dates: [Date]) async {
        loggedNotifications[type] = dates
    }
}
```

And tests should call:

```swift
let pending = await notificationCenter.pendingNotificationRequests()
await historyStore.setCompletedRecoveryNudgeToday(true)
```

---

## 28) Missing tests for core race and reliability scenarios
**Severity:** HIGH  
**Location:** Test suite coverage

### Missing scenarios
You asked what scenarios are NOT tested. Major missing tests:

1. **Concurrent duplicate scheduling**
   - Two `Task`s calling same API simultaneously

2. **Pending duplicate prevention**
   - Existing pending request blocks new schedule

3. **Daily budget exhaustion**
   - 3 notifications used before later ones

4. **DST transition**
   - bedtime before/after DST jump

5. **Time zone travel**
   - “same day” before and after calendar timezone change

6. **Past bedtime / past evening target**
   - ensure no immediate bad notification

7. **Notification add failure**
   - verify history is not logged on add failure

8. **History pruning**
   - old timestamps cleaned up

9. **Late HealthKit workout delivery**
   - workout ended 3 hours ago should skip

10. **64 pending limit behavior**
   - replacing existing identifiers rather than accumulating

11. **First-run / low-confidence baseline**
   - copy should not mention “typical baseline” unless confidence sufficient

12. **Watch + phone duplicate source simulation**
   - two service instances sharing same history/mock center

### Example race test
```swift
func testConcurrentMorningBriefing_SchedulesOnlyOne() async throws {
    let snapshot = HeartSnapshot.mock(timestamp: Date())
    let state = AdviceState.mock()

    async let first: Void = service.checkAndScheduleMorningBriefing(snapshot: snapshot, state: state)
    async let second: Void = service.checkAndScheduleMorningBriefing(snapshot: snapshot, state: state)

    _ = try? await [first, second]

    let pending = await notificationCenter.pendingNotificationRequests()
    XCTAssertEqual(pending.count, 1)
}
```

---

## 29) `UserNotificationCenterType` declared `Sendable`, but existential use deserves care
**Severity:** LOW  
**Location:** `private let notificationCenter: UserNotificationCenterType`

### What goes wrong
This is probably okay, but existential protocol values with async methods can still conceal non-thread-safe implementations. Since service may become non-MainActor, concrete implementations should be known thread-safe.

### Fix
Prefer storing as `any UserNotificationCenterType` and document thread safety. If you own concrete wrappers, make them actors.

```swift
private let notificationCenter: any UserNotificationCenterType
private let historyStore: any ProactiveHistoryStoreType
```

Not a functional fix, but improves explicitness.

---

## 30) `removePendingNotificationRequests` is sync in protocol while rest is async
**Severity:** LOW  
**Location:** `UserNotificationCenterType`

### What goes wrong
Inconsistent API shape. It’s okay for `UNUserNotificationCenter`, but wrapper actors may need async isolation to mutate state safely.

### Fix
Make it async in protocol.

```swift
public protocol UserNotificationCenterType: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
    func notificationSettings() async -> UNNotificationSettings
}
```

Mock implementation then naturally actor-safe.

---

# Recommended corrected core service skeleton

Here’s a safer condensed version of the critical path:

```swift
import Foundation
import UserNotifications

public enum ProactiveNotificationError: Error {
    case ineligible
    case staleData
    case belowThreshold
    case pastSchedulingWindow
}

actor ProactiveSchedulingGate {
    private var inFlight = Set<ProactiveNotificationType>()

    func begin(_ type: ProactiveNotificationType) -> Bool {
        guard !inFlight.contains(type) else { return false }
        inFlight.insert(type)
        return true
    }

    func end(_ type: ProactiveNotificationType) {
        inFlight.remove(type)
    }
}

public final class ProactiveNotificationService: ObservableObject {
    private let notificationCenter: any UserNotificationCenterType
    private let eligibility: NotificationEligibility
    private let historyStore: any ProactiveHistoryStoreType
    private let config: ProactiveNotificationConfig
    private let schedulingGate = ProactiveSchedulingGate()
    private let calendar: Calendar

    public init(
        notificationCenter: any UserNotificationCenterType = UNUserNotificationCenter.current(),
        historyStore: any ProactiveHistoryStoreType,
        config: ProactiveNotificationConfig = .init(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.notificationCenter = notificationCenter
        self.historyStore = historyStore
        self.config = config
        self.calendar = calendar
        self.eligibility = NotificationEligibility(historyStore: historyStore, config: config, calendar: calendar)
    }

    private static func identifier(for type: ProactiveNotificationType) -> String {
        "com.thump.\(type.rawValue)"
    }

    private func hasPendingNotification(of type: ProactiveNotificationType) async -> Bool {
        let pending = await notificationCenter.pendingNotificationRequests()
        return pending.contains { $0.identifier == Self.identifier(for: type) }
    }

    private func buildContent(
        title: String,
        body: String,
        interruptionLevel: UNNotificationInterruptionLevel,
        type: ProactiveNotificationType
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.threadIdentifier = type.threadIdentifier
        content.interruptionLevel = interruptionLevel
        content.sound = (interruptionLevel == .timeSensitive || interruptionLevel == .active) ? .default : nil
        content.userInfo = ["notificationType": type.rawValue]
        return content
    }

    private func scheduleIfNeeded(
        content: UNMutableNotificationContent,
        trigger: UNNotificationTrigger?,
        type: ProactiveNotificationType
    ) async throws {
        guard await schedulingGate.begin(type) else { return }
        defer { Task { await schedulingGate.end(type) } }

        guard !(await hasPendingNotification(of: type)) else { return }

        let request = UNNotificationRequest(
            identifier: Self.identifier(for: type),
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
        await historyStore.logScheduledNotification(type: type, at: Date())
    }

    public func cancelPendingAlerts(for types: [ProactiveNotificationType]) async {
        let ids = types.map(Self.identifier(for:))
        await notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
```

---

# What could go wrong in the first production week

1. **Users receive duplicates**
   - especially morning and training opportunity

2. **Nighttime notifications arrive at wrong times**
   - due to bedtime Date modeling and time interval triggers

3. **Users get too many notifications**
   - no daily cap

4. **Important notifications get blocked by earlier low-value nudges**
   - no priority system

5. **Real-world delayed HealthKit sync causes nonsense reminders**
   - post-workout recovery long after workout ended

6. **Support complains “notifications say baseline but I’m new”**
   - first-run confidence not respected

7. **Queue fills with pending requests**
   - random UUID identifiers + no replacement

8. **Analytics/QA can’t explain behavior**
   - staleData never surfaced, no structured outcomes

9. **Tests give false confidence**
   - they miss races, DST, pending dedupe, failures

10. **Watch and phone both schedule similar nudges**
   - no cross-device coordination visible here

---

# Final verdict

## Ship readiness: **Not production-ready yet**
The code is a decent prototype, but for a wellness app at scale, I would block merge until the following are fixed:

### Must-fix before ship
- Atomic scheduling/dedupe
- Stable identifiers
- Pending-request checks
- Daily budget + priority
- Calendar-safe bedtime/evening triggers
- History pruning
- Correct test actor access + race tests
- Explicit handling of stale data / past windows
- Workout-end-date based post-workout logic

### Nice-to-have soon after
- Authorization/settings awareness
- Baseline confidence-sensitive copy
- Better observability
- Distinguish scheduled vs delivered history

If you want, I can next provide:
1. a **fully revised production-grade implementation**, or  
2. a **patch-style diff** against this code, or  
3. a **complete expanded test suite** covering all 18 categories you
// NudgeGenerator.swift
// ThumpCore
//
// Extracted nudge generation with a rich library of contextual wellness nudges.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Nudge Generator

/// Generates contextual daily nudges based on physiological signals and user feedback.
///
/// The generator selects from a library of 15+ nudge variations organized by context:
/// stress, regression, low data, negative feedback, positive/improving, and defaults.
public struct NudgeGenerator: Sendable {

    public init() {}

    // MARK: - Public API

    /// Generate a single daily nudge based on current signals and context.
    ///
    /// Priority order (highest first):
    /// 1. Stress pattern detected
    /// 2. Multi-day regression flagged
    /// 3. Low data / low confidence
    /// 4. Negative user feedback from previous day
    /// 5. Positive / improving trend
    /// 6. Default general wellness nudge
    ///
    /// - Parameters:
    ///   - confidence: Data confidence level.
    ///   - anomaly: Composite anomaly score.
    ///   - regression: Whether regression was detected.
    ///   - stress: Whether a stress pattern was detected.
    ///   - feedback: Optional previous-day user feedback.
    ///   - current: Today's snapshot.
    ///   - history: Recent historical snapshots.
    ///   - readiness: Optional readiness result from ReadinessEngine.
    /// - Returns: A contextually appropriate `DailyNudge`.
    ///
    /// Readiness gate: moderate-intensity nudges are suppressed when readiness
    /// is recovering (<40) or moderate (<60). Poor sleep drives HRV down and
    /// RHR up, which lowers readiness — so the daily goal automatically backs
    /// off to walk/rest/breathe on those days rather than pushing harder.
    public func generate(
        confidence: ConfidenceLevel,
        anomaly: Double,
        regression: Bool,
        stress: Bool,
        feedback: DailyFeedback?,
        current: HeartSnapshot,
        history: [HeartSnapshot],
        readiness: ReadinessResult? = nil
    ) -> DailyNudge {
        // Priority 1: Stress pattern
        if stress {
            return selectStressNudge(current: current)
        }

        // Priority 2: Regression — readiness gates intensity
        if regression {
            return selectRegressionNudge(current: current, readiness: readiness)
        }

        // Priority 3: Low confidence / sparse data
        if confidence == .low {
            return selectLowDataNudge(current: current)
        }

        // Priority 4: Negative feedback adaptation
        if feedback == .negative {
            return selectNegativeFeedbackNudge(current: current)
        }

        // Priority 5: Positive / improving — readiness gates intensity
        if anomaly < 0.5 && confidence != .low {
            return selectPositiveNudge(current: current, history: history, readiness: readiness)
        }

        // Priority 6: Default — readiness gates intensity
        return selectDefaultNudge(current: current, readiness: readiness)
    }

    // MARK: - Multiple Nudge Generation

    /// Generate multiple data-driven nudges ranked by relevance.
    ///
    /// Returns up to 3 nudges from different categories so the user
    /// sees a variety of actionable suggestions based on their data.
    /// The first nudge is always the highest-priority one (same as `generate()`).
    ///
    /// - Parameters: Same as `generate()`, plus `readiness`.
    /// - Returns: Array of 1-3 contextually appropriate nudges from different categories.
    public func generateMultiple(
        confidence: ConfidenceLevel,
        anomaly: Double,
        regression: Bool,
        stress: Bool,
        feedback: DailyFeedback?,
        current: HeartSnapshot,
        history: [HeartSnapshot],
        readiness: ReadinessResult? = nil
    ) -> [DailyNudge] {
        var nudges: [DailyNudge] = []
        var usedCategories: Set<NudgeCategory> = []

        // Helper to add a nudge if its category isn't already used
        func addIfNew(_ nudge: DailyNudge) {
            guard !usedCategories.contains(nudge.category) else { return }
            nudges.append(nudge)
            usedCategories.insert(nudge.category)
        }

        let dayIndex = Calendar.current.ordinality(
            of: .day, in: .year, for: current.date
        ) ?? Calendar.current.component(.day, from: current.date)

        // Always start with the primary nudge
        let primary = generate(
            confidence: confidence,
            anomaly: anomaly,
            regression: regression,
            stress: stress,
            feedback: feedback,
            current: current,
            history: history,
            readiness: readiness
        )
        addIfNew(primary)

        // Add data-driven secondary suggestions based on what we know

        // ── Readiness-driven recovery block (highest priority secondary) ──
        // When readiness is low, the most important second nudge is "here's
        // what to do TONIGHT to fix tomorrow's metrics". This closes the loop:
        // poor sleep → HRV down → readiness low → primary backs off → secondary
        // explains WHY and gives a concrete tonight action.
        if let r = readiness, (r.level == .recovering || r.level == .moderate) {
            let hrvPillar = r.pillars.first { $0.type == .hrvTrend }
            let sleepPillar = r.pillars.first { $0.type == .sleep }

            // Build a specific "tonight" recovery nudge based on which pillar is weakest
            let weakestPillar = [hrvPillar, sleepPillar]
                .compactMap { $0 }
                .min { $0.score < $1.score }

            if weakestPillar?.type == .hrvTrend {
                // HRV is the bottleneck — sleep is the main lever for HRV recovery
                addIfNew(DailyNudge(
                    category: .rest,
                    title: "Sleep Is Your Recovery Tonight",
                    description: "Your HRV is below your recent baseline — a sign your body "
                        + "could use extra rest. The best thing you can do right now: "
                        + "aim for 8 hours tonight. Good sleep supports better HRV.",
                    durationMinutes: nil,
                    icon: "bed.double.fill"
                ))
            } else {
                // Sleep pillar is weak — direct sleep advice with the causal chain.
                // Severity-graduated: <4h acknowledges user may have had no choice,
                // 4-6h gives actionable bedtime advice.
                let hours = current.sleepHours ?? 0
                let hoursStr = String(format: "%.1f", hours)
                if hours > 0 && hours < 4.0 {
                    addIfNew(DailyNudge(
                        category: .rest,
                        title: "Rest When You Can Today",
                        description: "You got \(hoursStr) hours last night — sometimes life doesn't "
                            + "let you sleep. A short nap or even just sitting quietly helps. "
                            + "Tonight, protect your sleep window however you can.",
                        durationMinutes: nil,
                        icon: "bed.double.fill"
                    ))
                } else {
                    addIfNew(DailyNudge(
                        category: .rest,
                        title: "Earlier Bedtime = Better Tomorrow",
                        description: "You got \(hoursStr) hours last night. Less sleep can show up as "
                            + "a higher resting heart rate and lower HRV the next morning — which is "
                            + "what your metrics are showing. Whenever your next sleep window comes, "
                            + "try to protect it — even an extra 30 minutes makes a difference.",
                        durationMinutes: nil,
                        icon: "bed.double.fill"
                    ))
                }
            }

            // Fix 7: Medical escalation — when recovering AND stress is elevated,
            // surface a "talk to your doctor" nudge. This is highest priority (P0 liability)
            // so it goes before optional breathing/affirming nudges.
            if stress {
                addIfNew(DailyNudge(
                    category: .seekGuidance,
                    title: "Worth Sharing With Your Doctor",
                    description: "Your metrics have been outside your usual range. "
                        + "Some people find it helpful to share these patterns with their "
                        + "healthcare provider. This app is not intended to diagnose, treat, "
                        + "cure, or prevent any disease — your care team can give this data context.",
                    durationMinutes: nil,
                    icon: "stethoscope"
                ))
            }

            // Fix 6B: Positive anchor — when recovering, add an affirming nudge
            // (prioritized over breathing nudge per BCTTv1 positive-framing requirement)
            if r.level == .recovering && nudges.count < 3 {
                addIfNew(DailyNudge(
                    category: .celebrate,
                    title: "One Thing That Helps",
                    description: "On days like this, even 5 minutes outside or an extra 20 minutes of sleep tonight "
                        + "makes a real difference. Pick whichever one fits your day.",
                    durationMinutes: nil,
                    icon: "heart.fill"
                ))
            }

            // If recovering (severe), also add a breathing nudge to actively help HRV
            if r.level == .recovering && nudges.count < 3 {
                addIfNew(DailyNudge(
                    category: .breathe,
                    title: "4-7-8 Breathing Before Bed",
                    description: "Slow breathing before sleep helps you relax and "
                        + "may support better HRV overnight. "
                        + "Inhale 4 counts, hold 7, exhale 8. Do 4 rounds tonight.",
                    durationMinutes: 5,
                    icon: "wind"
                ))
            }
        } else {
            // Normal secondary nudge logic when readiness is fine

            // Sleep signal: too little or too much sleep
            if let sleep = current.sleepHours {
                if sleep < 6.5 {
                    addIfNew(DailyNudge(
                        category: .rest,
                        title: "Catch Up on Sleep",
                        description: "You logged \(String(format: "%.1f", sleep)) hours last night. "
                            + "An earlier bedtime tonight could help you feel more refreshed tomorrow.",
                        durationMinutes: nil,
                        icon: "bed.double.fill"
                    ))
                } else if sleep > 9.5 {
                    addIfNew(DailyNudge(
                        category: .walk,
                        title: "Get Some Fresh Air",
                        description: "You slept a long time. A gentle morning walk can help "
                            + "shake off grogginess and energize your day.",
                        durationMinutes: 10,
                        icon: "figure.walk"
                    ))
                }
            }

            // Activity signal: low movement day
            let walkMin = current.walkMinutes ?? 0
            let workoutMin = current.workoutMinutes ?? 0
            let totalActive = walkMin + workoutMin
            if totalActive < 10 && nudges.count < 3 {
                addIfNew(DailyNudge(
                    category: .walk,
                    title: "Move a Little Today",
                    description: "You haven't logged much activity yet. "
                        + "Even a 10-minute walk can boost your mood and energy.",
                    durationMinutes: 10,
                    icon: "figure.walk"
                ))
            }

            // HRV signal: below personal baseline
            if stress && nudges.count < 3 {
                addIfNew(DailyNudge(
                    category: .breathe,
                    title: "Try a Breathing Exercise",
                    description: "Your HRV suggests your body is working harder than usual. "
                        + "A few minutes of slow breathing can help you reset.",
                    durationMinutes: 3,
                    icon: "wind"
                ))
            }

            // Intensity signal: readiness is high, encourage effort not just volume.
            // Only when .primed or .ready — never when .recovering or .moderate.
            if let r = readiness, (r.level == .primed || r.level == .ready) && nudges.count < 3 {
                let intensityNudges = intensityNudgeLibrary()
                addIfNew(intensityNudges[dayIndex % intensityNudges.count])
            }
        }

        // Hydration reminder (universal, low-effort)
        if nudges.count < 3 {
            let hydrateNudges = [
                DailyNudge(
                    category: .hydrate,
                    title: "Stay Hydrated",
                    description: "A glass of water right now is one of the simplest "
                        + "things you can do for your energy and focus.",
                    durationMinutes: nil,
                    icon: "drop.fill"
                ),
                DailyNudge(
                    category: .hydrate,
                    title: "Quick Hydration Check",
                    description: "Have you had enough water today? Keeping a bottle "
                        + "nearby makes it easier to sip throughout the day.",
                    durationMinutes: nil,
                    icon: "drop.fill"
                )
            ]
            addIfNew(hydrateNudges[dayIndex % hydrateNudges.count])
        }

        // Zone-based recommendation from today's zone data
        let zones = current.zoneMinutes
        if zones.count >= 5, nudges.count < 3 {
            let zoneEngine = HeartRateZoneEngine()
            let analysis = zoneEngine.analyzeZoneDistribution(zoneMinutes: zones)
            if let rec = analysis.recommendation, rec != .perfectBalance {
                addIfNew(DailyNudge(
                    category: rec == .tooMuchIntensity ? .rest : .moderate,
                    title: rec.title,
                    description: rec.description,
                    durationMinutes: rec == .needsMoreActivity ? 20 : (rec == .needsMoreAerobic ? 15 : nil),
                    icon: rec.icon
                ))
            }
        }

        // Positive reinforcement if doing well
        if anomaly < 0.3 && confidence != .low && nudges.count < 3 {
            addIfNew(DailyNudge(
                category: .celebrate,
                title: "You're Doing Great",
                description: "Your metrics are looking solid. Keep up whatever "
                    + "you've been doing — it's working!",
                durationMinutes: nil,
                icon: "star.fill"
            ))
        }

        return Array(nudges.prefix(3))
    }

    // MARK: - Stress Nudges

    private func selectStressNudge(current: HeartSnapshot) -> DailyNudge {
        let stressNudges = stressNudgeLibrary()
        // Use day-of-year for deterministic but varied selection
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? Calendar.current.component(.day, from: current.date)
        return stressNudges[dayIndex % stressNudges.count]
    }

    private func stressNudgeLibrary() -> [DailyNudge] {
        [
            DailyNudge(
                category: .breathe,
                title: "A Little Breathing Break",
                description: "It looks like things might be a bit hectic lately. " +
                    "You might enjoy a few minutes of box breathing " +
                    "(4 seconds in, hold, out, hold) to help you unwind.",
                durationMinutes: 5,
                icon: "wind"
            ),
            DailyNudge(
                category: .walk,
                title: "A Gentle Stroll Could Feel Great",
                description: "A slow, easy walk in fresh air can be really refreshing. " +
                    "No rush, no goals, just enjoy being outside for a bit.",
                durationMinutes: 15,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .hydrate,
                title: "How About Some Extra Water Today?",
                description: "When things feel intense, a little extra hydration can go " +
                    "a long way. Maybe keep a glass of water nearby as a gentle reminder.",
                durationMinutes: nil,
                icon: "drop.fill"
            ),
            DailyNudge(
                category: .rest,
                title: "An Early Night Might Feel Nice",
                description: "Your patterns hint that a lighter evening could do wonders. " +
                    "Maybe try winding down a little earlier tonight and " +
                    "skipping screens before bed.",
                durationMinutes: nil,
                icon: "bed.double.fill"
            )
        ]
    }

    // MARK: - Regression Nudges

    private func selectRegressionNudge(
        current: HeartSnapshot,
        readiness: ReadinessResult? = nil
    ) -> DailyNudge {
        // Readiness gate: when recovering or moderate, suppress moderate-intensity
        // nudges and return a light backoff nudge instead.
        if let r = readiness, r.level == .recovering || r.level == .moderate {
            return selectReadinessBackoffNudge(current: current, readiness: r)
        }
        let nudges = regressionNudgeLibrary()
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? Calendar.current.component(.day, from: current.date)
        return nudges[dayIndex % nudges.count]
    }

    private func regressionNudgeLibrary() -> [DailyNudge] {
        [
            DailyNudge(
                category: .walk,
                title: "You Might Enjoy a Post-Meal Walk",
                description: "A short walk after your biggest meal can feel really good. " +
                    "Even ten minutes might make a nice difference over a few days.",
                durationMinutes: 10,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .walk,
                title: "How About Some Easy Movement Today?",
                description: "Your trend has been shifting a little. " +
                    "A gentle walk or easy movement " +
                    "could be just the thing to help recovery.",
                durationMinutes: 20,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .rest,
                title: "A Cozy Bedtime Routine",
                description: "Keeping a regular bedtime can make a real difference in " +
                    "how you feel. Maybe try settling in at the same time this week.",
                durationMinutes: nil,
                icon: "bed.double.fill"
            ),
            DailyNudge(
                category: .hydrate,
                title: "Keep That Water Bottle Handy",
                description: "Staying hydrated throughout the day is one of those " +
                    "simple things that really adds up. A visible water bottle helps!",
                durationMinutes: nil,
                icon: "drop.fill"
            )
        ]
    }

    // MARK: - Low Data Nudges

    private func selectLowDataNudge(current: HeartSnapshot) -> DailyNudge {
        let nudges = lowDataNudgeLibrary()
        // Use current.date for deterministic selection (not wall-clock Date())
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date)
            ?? Calendar.current.component(.day, from: current.date)
        return nudges[dayIndex % nudges.count]
    }

    private func lowDataNudgeLibrary() -> [DailyNudge] {
        [
            DailyNudge(
                category: .seekGuidance,
                title: "We're Getting to Know You",
                description: "The more you wear your Apple Watch, the better we can spot " +
                    "your patterns. Try wearing it to sleep tonight and we'll have " +
                    "more to share tomorrow!",
                durationMinutes: nil,
                icon: "applewatch"
            ),
            DailyNudge(
                category: .walk,
                title: "A Quick Walk to Get Started",
                description: "While we're learning your patterns, a 10-minute daily walk " +
                    "is a wonderful starting point. It feels good and helps us " +
                    "understand your rhythms better.",
                durationMinutes: 10,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .seekGuidance,
                title: "Quick Sync Check",
                description: "Make sure your Apple Watch is syncing with your " +
                    "iPhone. Pop into the Health app and check that Heart and Activity " +
                    "data sources are turned on.",
                durationMinutes: nil,
                icon: "arrow.triangle.2.circlepath"
            )
        ]
    }

    // MARK: - Negative Feedback Nudges

    private func selectNegativeFeedbackNudge(current: HeartSnapshot) -> DailyNudge {
        let nudges = negativeFeedbackNudgeLibrary()
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? Calendar.current.component(.day, from: current.date)
        return nudges[dayIndex % nudges.count]
    }

    private func negativeFeedbackNudgeLibrary() -> [DailyNudge] {
        [
            DailyNudge(
                category: .rest,
                title: "Let's Take It Easy Today",
                description: "Thanks for letting us know how you felt. " +
                    "Today might be a nice day for gentle movement and " +
                    "taking things at your own pace.",
                durationMinutes: nil,
                icon: "bed.double.fill"
            ),
            DailyNudge(
                category: .breathe,
                title: "Some Slow Breathing Might Help",
                description: "When things feel off, slow breathing can be a nice reset. " +
                    "You might enjoy 4-7-8 breathing: inhale for 4 counts, hold for 7, " +
                    "exhale for 8. Even a few rounds can feel calming.",
                durationMinutes: 5,
                icon: "wind"
            ),
            DailyNudge(
                category: .walk,
                title: "Just a Little Walk Today",
                description: "Yesterday's suggestion might not have been the right fit. " +
                    "How about just a 5-minute easy stroll? " +
                    "Every little bit counts!",
                durationMinutes: 5,
                icon: "figure.walk"
            )
        ]
    }

    // MARK: - Positive / Improving Nudges

    private func selectPositiveNudge(
        current: HeartSnapshot,
        history: [HeartSnapshot],
        readiness: ReadinessResult? = nil
    ) -> DailyNudge {
        // If readiness is low (recovering/moderate), suppress moderate and
        // return the gentler walk nudge regardless of how good the trend looks.
        // Poor sleep → low HRV → low readiness → body isn't ready to push harder.
        if let r = readiness, r.level == .recovering || r.level == .moderate {
            return selectReadinessBackoffNudge(current: current, readiness: r)
        }
        let nudges = positiveNudgeLibrary()
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? Calendar.current.component(.day, from: current.date)
        return nudges[dayIndex % nudges.count]
    }

    private func positiveNudgeLibrary() -> [DailyNudge] {
        [
            DailyNudge(
                category: .celebrate,
                title: "You're on a Roll!",
                description: "Things are looking great lately. " +
                    "Whatever you've been doing seems to be working really well. " +
                    "Keep it up!",
                durationMinutes: nil,
                icon: "star.fill"
            ),
            DailyNudge(
                category: .moderate,
                title: "Feeling Up for a Little Extra?",
                description: "Things are heading in a nice direction. " +
                    "If you're feeling good, you might enjoy adding a few " +
                    "extra minutes to your next workout.",
                durationMinutes: 5,
                icon: "flame.fill"
            ),
            DailyNudge(
                category: .walk,
                title: "Keep That Walking Groove Going",
                description: "Your consistency has been awesome. " +
                    "A brisk walk today could keep the good vibes rolling. " +
                    "You've built a great habit!",
                durationMinutes: 20,
                icon: "figure.walk"
            )
        ]
    }

    // MARK: - Default Nudges

    private func selectDefaultNudge(
        current: HeartSnapshot,
        readiness: ReadinessResult? = nil
    ) -> DailyNudge {
        // Readiness gate: recovering or moderate readiness = body needs a lighter day.
        if let r = readiness, r.level == .recovering || r.level == .moderate {
            return selectReadinessBackoffNudge(current: current, readiness: r)
        }
        let nudges = defaultNudgeLibrary()
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? Calendar.current.component(.day, from: current.date)
        return nudges[dayIndex % nudges.count]
    }

    // MARK: - Readiness Backoff Nudges

    /// Returns a light-intensity nudge when readiness is too low to safely push moderate effort.
    /// Triggered when poor sleep → HRV drops → RHR rises → readiness score falls below 60.
    private func selectReadinessBackoffNudge(
        current: HeartSnapshot,
        readiness: ReadinessResult
    ) -> DailyNudge {
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? Calendar.current.component(.day, from: current.date)

        // Recovering (<40): full rest or breathing — body is genuinely depleted
        if readiness.level == .recovering {
            let nudges: [DailyNudge] = [
                DailyNudge(
                    category: .rest,
                    title: "Rest and Recharge Today",
                    description: "Your HRV and sleep suggest a lighter day may help. "
                        + "Taking it easy now could help you bounce back faster.",
                    durationMinutes: nil,
                    icon: "bed.double.fill"
                ),
                DailyNudge(
                    category: .breathe,
                    title: "A Breathing Reset",
                    description: "Your metrics suggest you could use some downtime. Slow breathing "
                        + "can help you relax and wind down.",
                    durationMinutes: 5,
                    icon: "wind"
                )
            ]
            return nudges[dayIndex % nudges.count]
        }

        // Moderate (40–59): gentle walk only — movement helps but intensity hurts
        let nudges: [DailyNudge] = [
            DailyNudge(
                category: .walk,
                title: "An Easy Walk Today",
                description: "Your heart metrics suggest you're still bouncing back. "
                    + "A gentle walk keeps you moving without overdoing it.",
                durationMinutes: 15,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .walk,
                title: "Keep It Light Today",
                description: "Your HRV is a bit below your baseline — a sign your body "
                    + "is still catching up. An easy stroll is the right call.",
                durationMinutes: 20,
                icon: "figure.walk"
            )
        ]
        return nudges[dayIndex % nudges.count]
    }

    /// Intensity-focused nudges — only served when readiness is .ready or .primed.
    private func intensityNudgeLibrary() -> [DailyNudge] {
        [
            DailyNudge(
                category: .intensity,
                title: "Push Your Pace Today",
                description: "Your body is ready for more. Try picking up the pace for 2-3 minutes "
                    + "during your walk or run — get your breathing heavy, then ease back. "
                    + "Repeat a few times. That's where the real gains happen.",
                durationMinutes: 20,
                icon: "bolt.heart.fill"
            ),
            DailyNudge(
                category: .intensity,
                title: "10 Minutes in the Hard Zone",
                description: "Aim for 10 minutes today where you're breathing hard — a hill walk, "
                    + "stairs, or a jog all count. Intensity builds fitness faster than extra "
                    + "minutes at an easy pace.",
                durationMinutes: 10,
                icon: "flame.fill"
            ),
            DailyNudge(
                category: .intensity,
                title: "Make Today's Walk Count",
                description: "Instead of a longer easy walk, try a shorter one at a pace where "
                    + "talking feels hard. 15 minutes at real effort beats 30 minutes of "
                    + "strolling for your heart.",
                durationMinutes: 15,
                icon: "figure.walk.motion"
            ),
            DailyNudge(
                category: .intensity,
                title: "Challenge Your Heart Today",
                description: "Your recovery says you're primed. This is the day to push — intervals, "
                    + "a tempo run, or anything that gets your heart rate up for a few minutes. "
                    + "You'll feel it tomorrow in a good way.",
                durationMinutes: 20,
                icon: "heart.circle.fill"
            ),
        ]
    }

    private func defaultNudgeLibrary() -> [DailyNudge] {
        [
            DailyNudge(
                category: .walk,
                title: "A Walk Could Feel Great",
                description: "A 15-minute walk is one of the nicest things you can do " +
                    "for yourself. Find a pace that feels good and just enjoy it.",
                durationMinutes: 15,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .moderate,
                title: "Try Something Different Today",
                description: "Mixing things up keeps it fun! " +
                    "You might enjoy trying something different today, like gentle cycling, " +
                    "a swim, or a yoga session. If you have any health conditions, " +
                    "check with your care team first.",
                durationMinutes: 20,
                icon: "figure.mixed.cardio"
            ),
            DailyNudge(
                category: .hydrate,
                title: "Quick Hydration Check-In",
                description: "Staying hydrated is one of those little things that can make " +
                    "a big difference in how you feel. How about keeping a water bottle nearby today?",
                durationMinutes: nil,
                icon: "drop.fill"
            ),
            DailyNudge(
                category: .walk,
                title: "Two Little Walks",
                description: "How about splitting your walk into two shorter ones? " +
                    "One in the morning and one after lunch. " +
                    "Sometimes that feels easier and just as rewarding.",
                durationMinutes: 20,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .seekGuidance,
                title: "Peek at Your Trends",
                description: "Take a moment to browse your weekly trends in the app. " +
                    "Spotting your own patterns can be really interesting " +
                    "and help you find what works best for you.",
                durationMinutes: nil,
                icon: "chart.line.uptrend.xyaxis"
            )
        ]
    }
}

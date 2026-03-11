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
    /// - Returns: A contextually appropriate `DailyNudge`.
    public func generate(
        confidence: ConfidenceLevel,
        anomaly: Double,
        regression: Bool,
        stress: Bool,
        feedback: DailyFeedback?,
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> DailyNudge {
        // Priority 1: Stress pattern
        if stress {
            return selectStressNudge(current: current)
        }

        // Priority 2: Regression
        if regression {
            return selectRegressionNudge(current: current)
        }

        // Priority 3: Low confidence / sparse data
        if confidence == .low {
            return selectLowDataNudge()
        }

        // Priority 4: Negative feedback adaptation
        if feedback == .negative {
            return selectNegativeFeedbackNudge(current: current)
        }

        // Priority 5: Positive / improving
        if anomaly < 0.5 && confidence != .low {
            return selectPositiveNudge(current: current, history: history)
        }

        // Priority 6: Default
        return selectDefaultNudge(current: current)
    }

    // MARK: - Stress Nudges

    private func selectStressNudge(current: HeartSnapshot) -> DailyNudge {
        let stressNudges = stressNudgeLibrary()
        // Use day-of-year for deterministic but varied selection
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? 0
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

    private func selectRegressionNudge(current: HeartSnapshot) -> DailyNudge {
        let nudges = regressionNudgeLibrary()
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? 0
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
                category: .moderate,
                title: "How About Some Movement Today?",
                description: "Your trend has been shifting a little. " +
                    "Something like a brisk walk or a bike ride " +
                    "could be just the thing to mix it up.",
                durationMinutes: 20,
                icon: "gauge.with.dots.needle.33percent"
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

    private func selectLowDataNudge() -> DailyNudge {
        let nudges = lowDataNudgeLibrary()
        // Use current hour for variation when date isn't helpful
        let hour = Calendar.current.component(.hour, from: Date())
        return nudges[hour % nudges.count]
    }

    private func lowDataNudgeLibrary() -> [DailyNudge] {
        [
            DailyNudge(
                category: .moderate,
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
                category: .moderate,
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
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? 0
        return nudges[dayIndex % nudges.count]
    }

    private func negativeFeedbackNudgeLibrary() -> [DailyNudge] {
        [
            DailyNudge(
                category: .rest,
                title: "Let's Take It Easy Today",
                description: "Thanks for letting us know how you felt. " +
                    "Today might be a nice day for gentle movement and just " +
                    "listening to what your body needs.",
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
        history: [HeartSnapshot]
    ) -> DailyNudge {
        let nudges = positiveNudgeLibrary()
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? 0
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

    private func selectDefaultNudge(current: HeartSnapshot) -> DailyNudge {
        let nudges = defaultNudgeLibrary()
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: current.date) ?? 0
        return nudges[dayIndex % nudges.count]
    }

    private func defaultNudgeLibrary() -> [DailyNudge] {
        [
            DailyNudge(
                category: .walk,
                title: "A Brisk Walk Could Feel Great",
                description: "A 15-minute brisk walk is one of the nicest things you can do " +
                    "for yourself. Find a pace that feels good and just enjoy it.",
                durationMinutes: 15,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .moderate,
                title: "Try Something Different Today",
                description: "Mixing things up keeps it fun! " +
                    "You might enjoy trying something different today, like cycling, " +
                    "swimming, or a fitness class.",
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

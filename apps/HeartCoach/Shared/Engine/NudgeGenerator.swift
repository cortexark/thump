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
                title: "Try a Breathing Reset",
                description: "Your recent data suggests you might be under some extra stress. "
                    + "A 5-minute box breathing session (4 seconds in, hold, out, hold) "
                    + "can help you relax and unwind.",
                durationMinutes: 5,
                icon: "wind"
            ),
            DailyNudge(
                category: .walk,
                title: "Take a Gentle Stroll",
                description: "A slow, easy walk in fresh air can help you "
                    + "recover. Keep the pace conversational and enjoy the surroundings.",
                durationMinutes: 15,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .hydrate,
                title: "Focus on Hydration Today",
                description: "When things feel intense, staying well hydrated supports "
                    + "recovery. Aim for a glass of water every hour.",
                durationMinutes: nil,
                icon: "drop.fill"
            ),
            DailyNudge(
                category: .rest,
                title: "Prioritize Rest Tonight",
                description: "Your metrics suggest a lighter day may help. "
                    + "Consider winding down 30 minutes earlier tonight and avoiding "
                    + "screens before bed.",
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
                title: "Add a Post-Meal Walk",
                description: "A 10-minute walk after your largest meal may help stabilize "
                    + "your heart rate trend. Even a short walk makes a meaningful "
                    + "difference over several days.",
                durationMinutes: 10,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .moderate,
                title: "Include Moderate Activity",
                description: "Your trend has been shifting gradually. "
                    + "A moderate-intensity session like brisk walking or cycling "
                    + "may help turn things around.",
                durationMinutes: 20,
                icon: "gauge.with.dots.needle.33percent"
            ),
            DailyNudge(
                category: .rest,
                title: "Focus on Sleep Quality",
                description: "Improving sleep consistency may positively influence your "
                    + "heart rate trend. Try keeping a regular bedtime this week.",
                durationMinutes: nil,
                icon: "bed.double.fill"
            ),
            DailyNudge(
                category: .hydrate,
                title: "Stay Hydrated Through the Day",
                description: "Consistent hydration is great for overall well-being. "
                    + "Try keeping a water bottle visible as a reminder.",
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
                title: "Build Your Data Baseline",
                description: "Wearing your Apple Watch consistently helps build a solid "
                    + "data baseline. Try wearing it during sleep tonight for richer "
                    + "insights tomorrow.",
                durationMinutes: nil,
                icon: "applewatch"
            ),
            DailyNudge(
                category: .walk,
                title: "Start with a Short Walk",
                description: "While we build your baseline, a 10-minute daily walk is a "
                    + "great foundation. It also helps generate heart rate data we can "
                    + "use for better insights.",
                durationMinutes: 10,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .moderate,
                title: "Sync Your Watch Data",
                description: "Make sure your Apple Watch is syncing health data to your "
                    + "iPhone. Open the Health app and check that Heart and Activity "
                    + "data sources are enabled.",
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
                title: "Dial It Back Today",
                description: "Based on your feedback, today is a recovery day. "
                    + "Focus on gentle movement and avoid pushing hard. "
                    + "Tuning in to how you feel is a great habit.",
                durationMinutes: nil,
                icon: "bed.double.fill"
            ),
            DailyNudge(
                category: .breathe,
                title: "Recovery-Focused Breathing",
                description: "When things feel off, slow breathing can help reset. "
                    + "Try 4-7-8 breathing: inhale for 4 counts, hold for 7, "
                    + "exhale for 8. Repeat 4 times.",
                durationMinutes: 5,
                icon: "wind"
            ),
            DailyNudge(
                category: .walk,
                title: "A Lighter Walk Today",
                description: "Yesterday's plan felt like too much. "
                    + "Today, try just a 5-minute easy walk. "
                    + "Small steps still count toward progress.",
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
                title: "Great Progress This Week",
                description: "Your metrics are looking strong. "
                    + "Keep up what you have been doing. "
                    + "Consistency is key to building great habits.",
                durationMinutes: nil,
                icon: "star.fill"
            ),
            DailyNudge(
                category: .moderate,
                title: "Ready for a Small Challenge",
                description: "Your trend is positive, which means things are heading in a good direction. "
                    + "Consider adding 5 extra minutes to your next workout or "
                    + "picking up the pace slightly.",
                durationMinutes: 5,
                icon: "flame.fill"
            ),
            DailyNudge(
                category: .walk,
                title: "Maintain Your Walking Habit",
                description: "Your consistency is paying off. "
                    + "A brisk 20-minute walk today keeps the momentum going. "
                    + "Your data shows real consistency.",
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
                title: "Brisk Walk Today",
                description: "A 15-minute brisk walk is one of the simplest things you can do "
                    + "for yourself. Aim for a pace where you can talk but not sing.",
                durationMinutes: 15,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .moderate,
                title: "Mix Up Your Activity",
                description: "Variety keeps things interesting and your body guessing. "
                    + "Try a different activity today, such as cycling, swimming, or "
                    + "a fitness class.",
                durationMinutes: 20,
                icon: "figure.mixed.cardio"
            ),
            DailyNudge(
                category: .hydrate,
                title: "Hydration Check-In",
                description: "Good hydration supports overall well-being and helps your body "
                    + "perform at its best. Consider keeping a water bottle handy today.",
                durationMinutes: nil,
                icon: "drop.fill"
            ),
            DailyNudge(
                category: .walk,
                title: "Two Short Walks",
                description: "Split your walking into two 10-minute sessions today. "
                    + "One in the morning and one after lunch. "
                    + "This can be more sustainable than one long walk.",
                durationMinutes: 20,
                icon: "figure.walk"
            ),
            DailyNudge(
                category: .seekGuidance,
                title: "Check In With Your Trends",
                description: "Take a moment to review your weekly trends in the app. "
                    + "Understanding your patterns helps you make informed decisions "
                    + "about your activity level.",
                durationMinutes: nil,
                icon: "chart.line.uptrend.xyaxis"
            )
        ]
    }
}

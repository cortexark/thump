// ThumpAppIntents.swift
// Thump
//
// Siri Shortcuts for quick voice access to stress, readiness, and breathing.
// "Hey Siri, how's my stress in Thump?"
// "Hey Siri, start breathing with Thump"
// "Hey Siri, what's my readiness in Thump?"
//
// Uses AppIntents framework (iOS 16+ / watchOS 10+).
// Reads from the same shared UserDefaults as complications.
//
// Platforms: iOS 17+, watchOS 10+

import AppIntents

// MARK: - Check Stress Intent

/// "How's my stress?" — Returns current stress level and a suggestion.
struct CheckStressIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Stress"
    static var description = IntentDescription("Check your current stress level")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName)
        let isStressed = defaults?.bool(forKey: ThumpSharedKeys.stressFlagKey) ?? false
        let label = defaults?.string(forKey: ThumpSharedKeys.stressLabelKey) ?? "No stress data yet"
        let mood = defaults?.string(forKey: ThumpSharedKeys.moodKey) ?? "content"

        let message: String
        if isStressed {
            message = "Your stress levels are elevated — \(label.lowercased()). A quick breathing exercise could help."
        } else {
            let moodText = mood == "thriving" ? "You're doing great" : "You're looking calm"
            message = "\(moodText) — \(label.lowercased()). Keep it up!"
        }

        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Start Breathing Intent

/// "Start breathing" — Opens the app to trigger a breathing session.
/// On watchOS this opens the app; on iOS it navigates to the breathing screen.
struct StartBreathingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Breathing Exercise"
    static var description = IntentDescription("Launch a guided breathing exercise")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: "Starting your breathing exercise. Breathe in slowly...")
    }
}

// MARK: - Check Readiness Intent

/// "What's my readiness?" — Returns readiness score and today's coaching tip.
struct CheckReadinessIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Readiness"
    static var description = IntentDescription("Get your readiness score and a coaching tip")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName)
        let score = defaults?.object(forKey: ThumpSharedKeys.readinessScoreKey) as? Double
            ?? defaults?.object(forKey: ThumpSharedKeys.cardioScoreKey) as? Double
        let nudge = defaults?.string(forKey: ThumpSharedKeys.coachingNudgeTextKey)
            ?? defaults?.string(forKey: ThumpSharedKeys.nudgeTitleKey)

        let scoreText: String
        if let score {
            let level = score >= 75 ? "strong" : score >= 50 ? "moderate" : "low"
            scoreText = "Your readiness is \(Int(score)) out of 100 — that's \(level)."
        } else {
            scoreText = "No readiness data yet. Open Thump to sync."
        }

        let tipText = nudge.map { " Today's tip: \($0)." } ?? ""

        return .result(dialog: IntentDialog(stringLiteral: scoreText + tipText))
    }
}

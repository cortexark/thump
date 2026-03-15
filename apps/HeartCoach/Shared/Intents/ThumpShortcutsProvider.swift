// ThumpShortcutsProvider.swift
// Thump
//
// Registers Siri phrases so users can discover and use voice commands.
// These appear automatically in the Shortcuts app and Siri suggestions.
//
// Platforms: iOS 16+ / watchOS 10+

import AppIntents

struct ThumpShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckStressIntent(),
            phrases: [
                "How's my stress in \(.applicationName)",
                "Check stress with \(.applicationName)",
                "Am I stressed \(.applicationName)",
                "Stress level in \(.applicationName)",
            ],
            shortTitle: "Check Stress",
            systemImageName: "waveform.path.ecg"
        )

        AppShortcut(
            intent: StartBreathingIntent(),
            phrases: [
                "Start breathing with \(.applicationName)",
                "Breathe with \(.applicationName)",
                "Open breathing in \(.applicationName)",
                "Help me breathe \(.applicationName)",
            ],
            shortTitle: "Start Breathing",
            systemImageName: "wind"
        )

        AppShortcut(
            intent: CheckReadinessIntent(),
            phrases: [
                "What's my readiness in \(.applicationName)",
                "Check readiness with \(.applicationName)",
                "How ready am I \(.applicationName)",
                "Am I ready today \(.applicationName)",
            ],
            shortTitle: "Check Readiness",
            systemImageName: "heart.circle"
        )
    }
}

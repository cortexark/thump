// ThumpSharedKeys.swift
// Thump
//
// Shared UserDefaults keys used by complications, widgets, and Siri intents.
// Both iOS and watchOS targets include this file via the Shared/ source group.
//
// Data flow:
//   WatchViewModel writes → shared UserDefaults (app group) → widgets/intents read
//
// Platforms: iOS 17+, watchOS 10+

import Foundation

/// Keys for the shared app group UserDefaults used by complications,
/// Smart Stack widgets, and Siri AppIntents.
enum ThumpSharedKeys {
    static let suiteName = "group.com.thump.shared"

    // Core assessment data
    static let moodKey = "thump_mood"
    static let cardioScoreKey = "thump_cardio_score"
    static let nudgeTitleKey = "thump_nudge_title"
    static let nudgeIconKey = "thump_nudge_icon"
    static let stressFlagKey = "thump_stress_flag"
    static let statusKey = "thump_status"

    // Stress heatmap: 6 hourly stress levels as comma-separated doubles
    static let stressHeatmapKey = "thump_stress_heatmap"
    static let stressLabelKey = "thump_stress_label"

    // Readiness score (0-100)
    static let readinessScoreKey = "thump_readiness_score"

    // HRV trend: comma-separated last 7 daily HRV values (ms)
    static let hrvTrendKey = "thump_hrv_trend"

    // Coaching nudge text for inline complication
    static let coachingNudgeTextKey = "thump_coaching_nudge_text"
}

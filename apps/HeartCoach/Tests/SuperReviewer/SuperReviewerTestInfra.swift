// SuperReviewerTestInfra.swift
// ThumpTests
//
// Core data types for the Super Reviewer test infrastructure.
// Defines time-of-day stamps, journey scenarios, metric overrides,
// and comprehensive capture structs for full-page text validation.

import Foundation
@testable import Thump

// MARK: - Day Period

/// Time-of-day bucket for greeting and tone validation.
enum DayPeriod: String, Codable, Sendable, CaseIterable {
    case earlyMorning   // 5-7
    case morning        // 7-10
    case midMorning     // 10-12
    case midday         // 12-14
    case afternoon      // 14-17
    case evening        // 17-20
    case lateEvening    // 20-22
    case night          // 22-24
    case lateNight      // 0-5

    /// Returns the period for a given hour (0-23).
    static func from(hour: Int) -> DayPeriod {
        switch hour {
        case 0..<5:   return .lateNight
        case 5..<7:   return .earlyMorning
        case 7..<10:  return .morning
        case 10..<12: return .midMorning
        case 12..<14: return .midday
        case 14..<17: return .afternoon
        case 17..<20: return .evening
        case 20..<22: return .lateEvening
        case 22..<24: return .night
        default:       return .lateNight
        }
    }
}

// MARK: - Time of Day Stamp

/// A specific time-of-day used for greeting and tone tests.
struct TimeOfDayStamp: Sendable {
    let label: String
    let hour: Int
    let minute: Int

    var period: DayPeriod {
        DayPeriod.from(hour: hour)
    }

    /// Expected greeting prefix based on hour.
    var expectedGreeting: String {
        if hour >= 5 && hour < 12 {
            return "Good morning"
        } else if hour >= 12 && hour < 17 {
            return "Good afternoon"
        } else if hour >= 17 && hour < 21 {
            return "Good evening"
        } else {
            // Late night: 9 PM - 4:59 AM
            return "Good night"
        }
    }
}

// MARK: - Time of Day Stamps Collection

/// All 20 test timestamps spanning a full 24-hour cycle.
enum TimeOfDayStamps {

    static let all: [TimeOfDayStamp] = [
        TimeOfDayStamp(label: "1:00 AM",   hour: 1,  minute: 0),
        TimeOfDayStamp(label: "5:00 AM",   hour: 5,  minute: 0),
        TimeOfDayStamp(label: "6:00 AM",   hour: 6,  minute: 0),
        TimeOfDayStamp(label: "7:00 AM",   hour: 7,  minute: 0),
        TimeOfDayStamp(label: "8:00 AM",   hour: 8,  minute: 0),
        TimeOfDayStamp(label: "9:30 AM",   hour: 9,  minute: 30),
        TimeOfDayStamp(label: "10:30 AM",  hour: 10, minute: 30),
        TimeOfDayStamp(label: "11:30 AM",  hour: 11, minute: 30),
        TimeOfDayStamp(label: "12:00 PM",  hour: 12, minute: 0),
        TimeOfDayStamp(label: "1:00 PM",   hour: 13, minute: 0),
        TimeOfDayStamp(label: "2:00 PM",   hour: 14, minute: 0),
        TimeOfDayStamp(label: "3:00 PM",   hour: 15, minute: 0),
        TimeOfDayStamp(label: "4:30 PM",   hour: 16, minute: 30),
        TimeOfDayStamp(label: "5:30 PM",   hour: 17, minute: 30),
        TimeOfDayStamp(label: "6:30 PM",   hour: 18, minute: 30),
        TimeOfDayStamp(label: "7:30 PM",   hour: 19, minute: 30),
        TimeOfDayStamp(label: "8:30 PM",   hour: 20, minute: 30),
        TimeOfDayStamp(label: "9:30 PM",   hour: 21, minute: 30),
        TimeOfDayStamp(label: "10:30 PM",  hour: 22, minute: 30),
        TimeOfDayStamp(label: "11:30 PM",  hour: 23, minute: 30),
    ]
}

// MARK: - Day Metric Override

/// Optional per-day metric overrides that overlay on base persona baselines.
/// Sleep is absolute hours. RHR and HRV are deltas (additive for RHR,
/// percentage for HRV). Steps, workout, walk are absolute values.
struct DayMetricOverride: Sendable {
    /// Absolute sleep hours (replaces baseline).
    let sleepHours: Double?
    /// Additive delta to resting heart rate (e.g. +10 means RHR rises by 10).
    let rhrDelta: Double?
    /// Percentage delta to HRV (e.g. -45 means HRV drops by 45%).
    let hrvDelta: Double?
    /// Absolute step count (replaces baseline).
    let steps: Double?
    /// Absolute workout minutes (replaces baseline).
    let workoutMinutes: Double?
    /// Absolute walk minutes (replaces baseline).
    let walkMinutes: Double?

    init(
        sleep: Double? = nil,
        rhrDelta: Double? = nil,
        hrvDelta: Double? = nil,
        steps: Double? = nil,
        workout: Double? = nil,
        walk: Double? = nil
    ) {
        self.sleepHours = sleep
        self.rhrDelta = rhrDelta
        self.hrvDelta = hrvDelta
        self.steps = steps
        self.workoutMinutes = workout
        self.walkMinutes = walk
    }
}

// MARK: - Journey Scenario

/// A multi-day scenario with per-day metric overrides applied to a base persona.
struct JourneyScenario: Sendable {
    /// Unique identifier (e.g. "good_then_crash").
    let id: String
    /// Human-readable name.
    let name: String
    /// Description of what the journey tests.
    let description: String
    /// Total number of days in the journey.
    let dayCount: Int
    /// Per-day metric overrides. Key is day index (0-based).
    let dayOverrides: [Int: DayMetricOverride]
    /// Day indexes that need extra validation (crisis points, transitions).
    let criticalDays: Set<Int>
}

// MARK: - Super Reviewer Capture

/// Comprehensive Codable capture of ALL user-facing text from all pages.
/// One capture per (persona, journey, day, timeOfDay) combination.
struct SuperReviewerCapture: Codable, Sendable {

    // MARK: Identity

    let personaName: String
    let journeyID: String
    let dayIndex: Int
    let timeStampLabel: String
    let timeStampHour: Int

    // MARK: Metrics Context

    let sleepHours: Double?
    let rhr: Double?
    let hrv: Double?
    let steps: Double?
    let readinessScore: Int?
    let stressScore: Double?
    let stressLevel: String?

    // MARK: Dashboard Page

    let greetingText: String?
    let buddyMood: String?
    let heroMessage: String?
    let focusInsight: String?
    let checkBadge: String?
    let checkRecommendation: String?
    let recoveryNarrative: String?
    let recoveryTrendLabel: String?
    let recoveryAction: String?
    let goals: [CapturedGoal]
    let positivityAnchor: String?

    // MARK: Stress Page

    let stressLevelLabel: String?
    let friendlyMessage: String?
    let guidanceHeadline: String?
    let guidanceDetail: String?
    let guidanceActions: [String]?

    // MARK: Nudges

    let nudges: [CapturedNudge]

    // MARK: Buddy Recommendations

    let buddyRecs: [CapturedBuddyRec]

    // MARK: Coaching

    let coachingHeroMessage: String?
    let coachingInsights: [String]
}

// MARK: - Captured Sub-Structs

struct CapturedGoal: Codable, Sendable {
    let label: String
    let target: Double
    let current: Double
    let nudgeText: String
}

struct CapturedNudge: Codable, Sendable {
    let category: String
    let title: String
    let description: String
}

struct CapturedBuddyRec: Codable, Sendable {
    let title: String
    let message: String
    let priority: String
}

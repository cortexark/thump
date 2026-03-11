// MockData.swift
// ThumpCore
//
// Realistic mock data generators for SwiftUI previews, unit tests,
// and snapshot testing. Values are modelled after typical Apple Watch
// users with moderate fitness levels.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Mock Data

/// Static generators and sample instances for previews and tests.
///
/// All numeric ranges mirror real-world Apple Watch data for a
/// moderately active adult (age 30-50):
/// - Resting HR: 58-72 BPM
/// - HRV (SDNN): 30-65 ms
/// - VO2 max: 32-48 mL/kg/min
/// - Steps: 4 000-12 000
/// - Walk minutes: 15-60
/// - Workout minutes: 0-45
/// - Sleep hours: 5.5-8.5
/// - Recovery HR (1 min): 18-38 BPM drop
/// - Recovery HR (2 min): 30-52 BPM drop
public enum MockData {

    // MARK: - Seeded Random Helpers

    /// Deterministic pseudo-random Double in [min, max] based on seed.
    private static func seededRandom(
        min: Double,
        max: Double,
        seed: Int
    ) -> Double {
        // Simple LCG (linear congruential generator) for reproducibility.
        var state = UInt64(abs(seed) &+ 1)
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let fraction = Double(state >> 33) / Double(UInt32.max)
        return min + fraction * (max - min)
    }

    /// Optional value generator -- returns `nil` roughly `nilChance`
    /// fraction of the time.
    private static func optionalValue(
        min: Double,
        max: Double,
        seed: Int,
        nilChance: Double = 0.1
    ) -> Double? {
        let roll = seededRandom(min: 0, max: 1, seed: seed &* 31)
        if roll < nilChance { return nil }
        return seededRandom(min: min, max: max, seed: seed)
    }

    // MARK: - Mock History

    /// Generate an array of realistic daily ``HeartSnapshot`` values
    /// going back `days` from today.
    ///
    /// Values are generated with realistic physiological correlations
    /// baked in so that the CorrelationEngine surfaces meaningful insights:
    /// - High-activity days (more steps/walk/workout) → lower RHR, higher HRV
    /// - Good sleep → higher HRV
    /// - More workout minutes → better recovery HR
    ///
    /// The seed is derived from the day offset so output is deterministic
    /// for snapshot tests.
    ///
    /// - Parameter days: Number of historical days to generate.
    ///   Defaults to 21.
    /// - Returns: Array ordered oldest-first.
    public static func mockHistory(days: Int = 21) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<days).map { offset in
            let dayDate = calendar.date(
                byAdding: .day,
                value: -(days - 1 - offset),
                to: today
            )! // swiftlint:disable:this force_unwrapping

            let seed = offset &* 7 &+ 42

            // ── Activity drivers (0…1 normalized "fitness signal") ──────────
            // Each varies independently, but cardiac metrics are then derived
            // from them so the correlation engine finds real relationships.

            // Daily activity level: 0 = sedentary day, 1 = very active day
            let activitySignal = seededRandom(min: 0.0, max: 1.0, seed: seed &+ 5)

            // Sleep quality: 0 = poor sleep, 1 = great sleep
            let sleepSignal = seededRandom(min: 0.0, max: 1.0, seed: seed &+ 8)

            // Workout intensity signal (slightly correlated with activity)
            let workoutSignal = seededRandom(min: 0.0, max: 1.0, seed: seed &+ 7)

            // ── Activity metrics derived from signals ───────────────────────
            let stepsRaw = 4_000.0 + activitySignal * 8_000.0
            let steps: Double? = seededRandom(min: 0, max: 1, seed: seed &* 31 &+ 5) < 0.05
                ? nil : stepsRaw + seededRandom(min: -500, max: 500, seed: seed &+ 55)

            let walkMinRaw = 15.0 + activitySignal * 45.0
            let walkMin: Double? = seededRandom(min: 0, max: 1, seed: seed &* 31 &+ 6) < 0.08
                ? nil : walkMinRaw + seededRandom(min: -5, max: 5, seed: seed &+ 56)

            let workoutMinRaw = workoutSignal * 45.0
            let workoutMin: Double? = seededRandom(min: 0, max: 1, seed: seed &* 31 &+ 7) < 0.20
                ? nil : workoutMinRaw + seededRandom(min: -3, max: 3, seed: seed &+ 57)

            let sleepHrsRaw = 5.5 + sleepSignal * 3.0
            let sleepHrs: Double? = seededRandom(min: 0, max: 1, seed: seed &* 31 &+ 8) < 0.10
                ? nil : sleepHrsRaw + seededRandom(min: -0.3, max: 0.3, seed: seed &+ 58)

            // ── Cardiac metrics derived from activity + sleep signals ───────
            // Noise terms are deliberately larger than the signal terms so the
            // resulting Pearson r sits in a realistic 0.5–0.8 range rather than
            // looking suspiciously perfect.

            // RHR: active days → lower; range 58–72 BPM
            // activitySignal high → rhr low (negative correlation with steps)
            let rhrRaw = 72.0 - activitySignal * 14.0
            let rhr: Double? = seededRandom(min: 0, max: 1, seed: seed &* 31) < 0.05
                ? nil : rhrRaw + seededRandom(min: -5, max: 5, seed: seed)

            // HRV: good sleep + active → higher HRV; range 28–68 ms
            let hrvRaw = 28.0 + sleepSignal * 24.0 + activitySignal * 16.0
            let hrv: Double? = seededRandom(min: 0, max: 1, seed: seed &* 31 &+ 1) < 0.08
                ? nil : hrvRaw + seededRandom(min: -8, max: 8, seed: seed &+ 1)

            // Recovery HR 1m: more workout → better (higher) recovery drop
            let rec1Raw = 18.0 + workoutSignal * 20.0
            let rec1: Double? = seededRandom(min: 0, max: 1, seed: seed &* 31 &+ 2) < 0.25
                ? nil : rec1Raw + seededRandom(min: -6, max: 6, seed: seed &+ 2)

            // Recovery HR 2m: similar pattern
            let rec2Raw = 30.0 + workoutSignal * 22.0
            let rec2: Double? = seededRandom(min: 0, max: 1, seed: seed &* 31 &+ 3) < 0.30
                ? nil : rec2Raw + seededRandom(min: -6, max: 6, seed: seed &+ 3)

            // VO2 max: slowly improves with sustained activity over the window
            let vo2Raw = 36.0 + activitySignal * 8.0 + Double(offset) / Double(max(days, 1)) * 4.0
            let vo2: Double? = seededRandom(min: 0, max: 1, seed: seed &* 31 &+ 4) < 0.15
                ? nil : vo2Raw + seededRandom(min: -2, max: 2, seed: seed &+ 4)

            // Zone minutes: 5 zones (rest, light, moderate, vigorous, peak)
            let zoneMinutes: [Double] = (0..<5).map { zone in
                let base: Double = [180, 45, 25, 10, 3][zone]
                return max(0, seededRandom(
                    min: base * 0.6,
                    max: base * 1.4,
                    seed: seed &+ 10 &+ zone
                ))
            }

            return HeartSnapshot(
                date: dayDate,
                restingHeartRate: rhr,
                hrvSDNN: hrv,
                recoveryHR1m: rec1,
                recoveryHR2m: rec2,
                vo2Max: vo2,
                zoneMinutes: zoneMinutes,
                steps: steps,
                walkMinutes: walkMin,
                workoutMinutes: workoutMin,
                sleepHours: sleepHrs
            )
        }
    }

    // MARK: - Today's Mock Snapshot

    /// A fully-populated snapshot representing today's metrics for simulator use.
    ///
    /// All fields are present so the dashboard "Today's Metrics" tiles show real
    /// values rather than "-- " dashes.
    public static var mockTodaySnapshot: HeartSnapshot {
        HeartSnapshot(
            date: Calendar.current.startOfDay(for: Date()),
            restingHeartRate: 62.0,
            hrvSDNN: 54.0,
            recoveryHR1m: 28.0,
            recoveryHR2m: 44.0,
            vo2Max: 41.5,
            zoneMinutes: [175, 48, 28, 12, 4],
            steps: 9_240,
            walkMinutes: 42.0,
            workoutMinutes: 35.0,
            sleepHours: 7.4
        )
    }

    // MARK: - Sample Nudge

    /// A representative daily nudge for preview use.
    public static let sampleNudge = DailyNudge(
        category: .walk,
        title: "Brisk Walk Today",
        description: "A 15-minute brisk walk is one of the best things you can do "
            + "for your heart. Aim for a pace where you can talk but not sing.",
        durationMinutes: 15,
        icon: "figure.walk"
    )

    // MARK: - Sample Assessment

    /// A stable, medium-confidence assessment for preview use.
    public static let sampleAssessment = HeartAssessment(
        status: .stable,
        confidence: .medium,
        anomalyScore: 0.45,
        regressionFlag: false,
        stressFlag: false,
        cardioScore: 62.0,
        dailyNudge: sampleNudge,
        explanation: "Your heart metrics are within your normal range. "
            + "This assessment uses partial data. "
            + "More consistent wear will improve accuracy. "
            + "Your estimated cardio fitness score is 62 out of 100."
    )

    // MARK: - Sample Profile

    /// A completed-onboarding user profile for preview use.
    public static let sampleProfile = UserProfile(
        displayName: "Alex",
        joinDate: Calendar.current.date(
            byAdding: .day,
            value: -45,
            to: Date()
        ) ?? Date(),
        onboardingComplete: true,
        streakDays: 12
    )

    // MARK: - Sample Correlations

    /// Realistic correlation results across four factor pairs.
    public static let sampleCorrelations = [
        CorrelationResult(
            factorName: "Daily Steps",
            correlationStrength: -0.42,
            interpretation: "Higher step counts are moderately associated with "
                + "lower resting heart rate over the past three weeks.",
            confidence: .medium
        ),
        CorrelationResult(
            factorName: "Walk Minutes",
            correlationStrength: 0.55,
            interpretation: "More walking minutes correlate with higher heart rate "
                + "variability, suggesting improved autonomic balance.",
            confidence: .high
        ),
        CorrelationResult(
            factorName: "Activity Minutes",
            correlationStrength: 0.38,
            interpretation: "Regular workouts show a moderate positive association "
                + "with faster heart rate recovery after exercise.",
            confidence: .medium
        ),
        CorrelationResult(
            factorName: "Sleep Hours",
            correlationStrength: 0.61,
            interpretation: "Longer sleep duration is strongly associated with "
                + "higher HRV, indicating better cardiovascular recovery.",
            confidence: .high
        )
    ]

    // MARK: - Sample Weekly Report

    /// A representative weekly report for preview use.
    public static let sampleWeeklyReport = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // swiftlint:disable:next force_unwrapping
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!

        return WeeklyReport(
            weekStart: weekStart,
            weekEnd: today,
            avgCardioScore: 64.5,
            trendDirection: .up,
            topInsight: "Your resting heart rate dropped an average of 2 BPM this "
                + "week, suggesting improved cardiovascular fitness.",
            nudgeCompletionRate: 0.71
        )
    }()
}

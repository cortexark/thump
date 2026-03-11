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
    /// Each day's values have slight random variation around a healthy
    /// baseline. The seed is derived from the day offset so the output
    /// is deterministic for snapshot tests.
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

            // Base RHR drifts slightly across the window
            let rhrBase = 64.0 + sin(Double(offset) / 5.0) * 3.0
            let rhr = optionalValue(
                min: rhrBase - 3.0,
                max: rhrBase + 3.0,
                seed: seed,
                nilChance: 0.05
            )

            let hrvBase = 46.0 + cos(Double(offset) / 4.0) * 6.0
            let hrv = optionalValue(
                min: hrvBase - 5.0,
                max: hrvBase + 5.0,
                seed: seed &+ 1,
                nilChance: 0.08
            )

            let rec1 = optionalValue(
                min: 18.0,
                max: 38.0,
                seed: seed &+ 2,
                nilChance: 0.25
            )

            let rec2 = optionalValue(
                min: 30.0,
                max: 52.0,
                seed: seed &+ 3,
                nilChance: 0.30
            )

            let vo2 = optionalValue(
                min: 32.0,
                max: 48.0,
                seed: seed &+ 4,
                nilChance: 0.15
            )

            let steps = optionalValue(
                min: 4_000,
                max: 12_000,
                seed: seed &+ 5,
                nilChance: 0.05
            )

            let walkMin = optionalValue(
                min: 15.0,
                max: 60.0,
                seed: seed &+ 6,
                nilChance: 0.08
            )

            let workoutMin = optionalValue(
                min: 0.0,
                max: 45.0,
                seed: seed &+ 7,
                nilChance: 0.20
            )

            let sleepHrs = optionalValue(
                min: 5.5,
                max: 8.5,
                seed: seed &+ 8,
                nilChance: 0.10
            )

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
    // swiftlint:disable force_unwrapping
    public static let sampleProfile = UserProfile(
        displayName: "Alex",
        joinDate: Calendar.current.date(
            byAdding: .day,
            value: -45,
            to: Date()
        )!,
        onboardingComplete: true,
        streakDays: 12
    )
    // swiftlint:enable force_unwrapping

    // MARK: - Sample Correlations

    /// Realistic correlation results across four factor pairs.
    public static let sampleCorrelations: [CorrelationResult] = [
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
            factorName: "Workout Minutes",
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
    public static let sampleWeeklyReport: WeeklyReport = {
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

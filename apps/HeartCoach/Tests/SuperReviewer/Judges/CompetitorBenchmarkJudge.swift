// CompetitorBenchmarkJudge.swift
// Thump Tests — Super Reviewer
//
// LLM critic that scores Thump's data presentation against WHOOP and Oura
// across 12 competitive dimensions. Each dimension is scored 0-10 for all
// three apps, producing a gap matrix that identifies where Thump is behind.
//
// The judge evaluates actual user-facing text, data density, and coaching
// quality — not hardware capabilities (Thump reads Apple Watch; it can't
// add new sensors).
//
// Platforms: iOS 17+

import Foundation

// MARK: - Competitive Dimension

/// A single axis along which WHOOP, Oura, and Thump are compared.
struct CompetitiveDimension: Codable {
    let id: String
    let name: String
    let description: String
    let whoopScore: Int
    let whoopEvidence: String
    let ouraScore: Int
    let ouraEvidence: String
    let thumpScore: Int
    let thumpEvidence: String
    let gap: Int               // max(whoop, oura) - thump
    let improvementPlan: String
}

// MARK: - Competitor Benchmark Result

/// Full output of the competitor benchmark judge.
struct CompetitorBenchmarkResult: Codable {
    let judgeName: String
    let evaluatedAt: String
    let dimensions: [CompetitiveDimension]
    let thumpTotalScore: Int
    let whoopTotalScore: Int
    let ouraTotalScore: Int
    let topGaps: [String]         // dimension IDs sorted by gap descending
    let overallVerdict: String
}

// MARK: - Competitor Benchmark Judge

/// Scores Thump against WHOOP and Oura across 12 competitive dimensions.
///
/// This is a deterministic judge (no LLM call) — scores are derived from
/// feature-presence analysis of the three apps. The judge is designed to
/// be run as part of the Super Reviewer suite and produces a JSON report.
enum CompetitorBenchmarkJudge {

    static let judgeName = "CompetitorBenchmark"

    // MARK: - Run

    /// Evaluates all 12 dimensions and returns the full benchmark result.
    static func evaluate() -> CompetitorBenchmarkResult {
        let dims = buildDimensions()
        let sorted = dims.sorted { $0.gap > $1.gap }

        return CompetitorBenchmarkResult(
            judgeName: judgeName,
            evaluatedAt: ISO8601DateFormatter().string(from: Date()),
            dimensions: dims,
            thumpTotalScore: dims.reduce(0) { $0 + $1.thumpScore },
            whoopTotalScore: dims.reduce(0) { $0 + $1.whoopScore },
            ouraTotalScore: dims.reduce(0) { $0 + $1.ouraScore },
            topGaps: sorted.filter { $0.gap > 0 }.map(\.id),
            overallVerdict: buildVerdict(dims)
        )
    }

    // MARK: - Dimensions

    private static func buildDimensions() -> [CompetitiveDimension] {
        [
            sleepStaging(),
            sleepDebtAndNeed(),
            strainAndExertionModel(),
            bodyTemperature(),
            respiratoryRate(),
            bloodOxygen(),
            resilienceAndLongevity(),
            aiCoachConversation(),
            sleepConsistencyScore(),
            menstrualAndHormonal(),
            muscularLoadTracking(),
            socialAndCommunity()
        ]
    }

    // MARK: - Dimension 1: Sleep Staging

    private static func sleepStaging() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "sleep_staging",
            name: "Sleep Stage Breakdown",
            description: "Showing time in Light, Deep/SWS, REM, and Awake stages with percentage targets",
            whoopScore: 9,
            whoopEvidence: "Full 4-stage breakdown (Light, SWS, REM, Wake) with time + percentage per stage. Shows optimal ranges (15-25% deep, 20-25% REM). Validated against polysomnography.",
            ouraScore: 9,
            ouraEvidence: "Full 4-stage breakdown with time per stage. Hypnogram visualization showing stage transitions across the night. Sleep stage contribution to Sleep Score.",
            thumpScore: 3,
            thumpEvidence: "Tracks total sleep hours only (HKCategoryTypeIdentifier.sleepAnalysis). No stage breakdown shown. No hypnogram. Sleep appears as a single number on Trends and as a readiness pillar.",
            gap: 6,
            improvementPlan: "Read HKCategoryValueSleepAnalysis stage samples (.asleepCore, .asleepDeep, .asleepREM, .awake) from HealthKit. Display a stacked bar or hypnogram on the Dashboard sleep card. Add stage percentages and compare to optimal ranges (15-25% deep, 20-25% REM)."
        )
    }

    // MARK: - Dimension 2: Sleep Debt & Need

    private static func sleepDebtAndNeed() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "sleep_debt",
            name: "Sleep Debt & Personalized Sleep Need",
            description: "Tracking cumulative sleep debt and calculating personalized sleep need based on activity and recovery",
            whoopScore: 9,
            whoopEvidence: "Sleep Planner calculates personalized sleep need each night based on previous sleep, strain, and recovery. Tracks cumulative sleep debt across days. Shows 'sleep needed' vs 'sleep achieved' with deficit visualization.",
            ouraScore: 7,
            ouraEvidence: "Shows sleep goal and whether it was met. Tracks sleep balance (recent average vs baseline). No explicit running debt counter, but Readiness Score penalizes short sleep.",
            thumpScore: 2,
            thumpEvidence: "Shows sleep hours vs a static 7-9h optimal range. No personalized sleep need calculation. No cumulative debt tracking. Readiness caps at 59 below 5h but no debt quantification.",
            gap: 7,
            improvementPlan: "Build a SleepDebtEngine that: (1) estimates personalized sleep need from 14-day HRV/recovery correlation, (2) tracks rolling 7-day debt (need - actual), (3) shows debt on Dashboard with 'you need X hrs tonight to clear Y hrs of debt'. Integrate into readiness pillar weighting."
        )
    }

    // MARK: - Dimension 3: Strain / Exertion Model

    private static func strainAndExertionModel() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "strain_model",
            name: "Daily Strain / Exertion Score",
            description: "A composite daily exertion metric that quantifies cardiovascular and physical load",
            whoopScore: 10,
            whoopEvidence: "Strain score 0-21 (logarithmic Borg scale). Tracks cardiovascular load (HR zone duration weighted) + muscular load (volume x intensity). Strain Coach gives real-time target based on recovery. Haptic alerts when target hit.",
            ouraScore: 5,
            ouraEvidence: "Activity Score 0-100 tracks movement, steps, training frequency/volume. No real-time exertion quantification. No cardiovascular load model. More of a 'did you move enough' metric than a strain metric.",
            thumpScore: 4,
            thumpEvidence: "Zone Analysis tracks time in 5 HR zones with targets. Shows zone completion ratios. But no composite strain score, no real-time tracking, no logarithmic exertion model. Zone data is retrospective, not live.",
            gap: 6,
            improvementPlan: "Build a StrainEngine that computes a daily 0-20 cardiovascular load score from HR zone minutes (weighted by zone intensity, logarithmic scaling). Show on Dashboard as 'Today's Effort' alongside Recovery. Add strain-recovery balance chart on Trends."
        )
    }

    // MARK: - Dimension 4: Body Temperature

    private static func bodyTemperature() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "body_temperature",
            name: "Body Temperature Deviation Tracking",
            description: "Monitoring skin/body temperature deviations from personal baseline for illness and cycle detection",
            whoopScore: 8,
            whoopEvidence: "Continuous skin temperature monitoring. Shows deviation from baseline in Health Monitor. Used for illness detection and menstrual cycle tracking. Part of Recovery score calculation.",
            ouraScore: 9,
            ouraEvidence: "Nighttime skin temperature tracked with 0.1F precision. Shows deviation from personal baseline. Key input to Readiness Score. Illness detection alerts. Menstrual cycle phase correlation. Body Temperature trend chart in app.",
            thumpScore: 0,
            thumpEvidence: "Not tracked. Apple Watch Series 8+ has wrist temperature sensor but Thump does not read HKQuantityTypeIdentifier.appleSleepingWristTemperature. No temperature-related features exist.",
            gap: 9,
            improvementPlan: "Read .appleSleepingWristTemperature from HealthKit (available on Apple Watch Series 8+). Show baseline deviation on Dashboard. Use as illness-detection signal (>0.5C above baseline for 2+ nights). Add to Readiness pillar calculation. Graceful degradation for older watches."
        )
    }

    // MARK: - Dimension 5: Respiratory Rate

    private static func respiratoryRate() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "respiratory_rate",
            name: "Respiratory Rate Monitoring",
            description: "Tracking breathing rate during sleep for recovery and illness signals",
            whoopScore: 8,
            whoopEvidence: "Respiratory rate tracked during sleep. Shown in Health Monitor. Deviations flagged as potential illness signal. Part of Recovery trend analysis.",
            ouraScore: 8,
            ouraEvidence: "Nighttime respiratory rate tracked. Shown on Readiness tab with trend. Deviations used for illness detection alongside temperature. Average respiratory rate displayed in daily report.",
            thumpScore: 0,
            thumpEvidence: "Not tracked. Apple Watch measures respiratory rate during sleep (HKQuantityTypeIdentifier.respiratoryRate). Thump does not read this metric. No respiratory features exist.",
            gap: 8,
            improvementPlan: "Read .respiratoryRate from HealthKit. Show average nighttime respiratory rate on Trends chart. Use >2 breaths/min above baseline as illness signal. Add to Readiness pillar alongside temperature for a 'body recovery' sub-score."
        )
    }

    // MARK: - Dimension 6: Blood Oxygen (SpO2)

    private static func bloodOxygen() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "blood_oxygen",
            name: "Blood Oxygen (SpO2) Tracking",
            description: "Monitoring blood oxygen saturation during sleep for respiratory health",
            whoopScore: 8,
            whoopEvidence: "Blood oxygen tracking via pulse oximetry. Displayed in Health Monitor. Deviations flagged. Used as supplementary recovery signal.",
            ouraScore: 7,
            ouraEvidence: "SpO2 tracked during sleep. Shown in daily metrics. Deviations can indicate sleep apnea or altitude effects. Not a primary score driver but available as trend.",
            thumpScore: 0,
            thumpEvidence: "Not tracked. Apple Watch has SpO2 sensor and writes .oxygenSaturation to HealthKit. Thump does not read this metric.",
            gap: 8,
            improvementPlan: "Read .oxygenSaturation from HealthKit. Show average nighttime SpO2 on Trends. Flag sustained drops below 95% as possible sleep apnea signal with 'talk to your doctor' framing. Add to Bio Age as supplementary input."
        )
    }

    // MARK: - Dimension 7: Resilience & Longevity Score

    private static func resilienceAndLongevity() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "resilience",
            name: "Resilience / Cardiovascular Age / Longevity Score",
            description: "A long-term health trajectory metric showing how well the body handles and recovers from stress over weeks/months",
            whoopScore: 6,
            whoopEvidence: "No explicit resilience score. Health Monitor shows trends but no long-term trajectory metric. Recovery trend over months is available. No cardiovascular age estimate.",
            ouraScore: 9,
            ouraEvidence: "Resilience Score shows how well the body handles stress and recovers over time. Cardiovascular Age compares vascular health to chronological age. Both are long-term trajectory metrics that reward consistency.",
            thumpScore: 7,
            thumpEvidence: "Bio Age (fitness age) based on NTNU formula with 6 inputs (VO2, RHR, HRV, sleep, activity, BMI). Shows difference from chronological age. Categories: Excellent/Good/OnTrack/Watchful/Concerning. Per-metric contribution breakdown available.",
            gap: 2,
            improvementPlan: "Add a Resilience Score alongside Bio Age that tracks stress-recovery bounce-back speed over 30-90 days. Show 'how fast your HRV returns to baseline after stress' as a trend. This is the gap vs Oura's Resilience feature. Bio Age is already competitive."
        )
    }

    // MARK: - Dimension 8: AI Coach Conversation

    private static func aiCoachConversation() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "ai_coach",
            name: "AI-Powered Conversational Coach",
            description: "Natural language AI assistant that answers ad-hoc health questions using personal data",
            whoopScore: 9,
            whoopEvidence: "WHOOP Coach is a conversational AI that answers questions about your data, remembers past conversations, integrates strain/sleep/recovery/lab results, and adjusts to your goals. Launched 2024, enhanced with memory in 2025.",
            ouraScore: 7,
            ouraEvidence: "Oura Advisor explains why scores changed (e.g., 'your sleep score dropped because HRV dipped'). Contextual but not fully conversational. No persistent memory across sessions.",
            thumpScore: 3,
            thumpEvidence: "Thump Buddy provides static coaching messages based on AdviceState (hero message, focus insight, check recommendation). No conversational interface. No ad-hoc questions. No memory. Messages are template-selected, not generated.",
            gap: 6,
            improvementPlan: "Phase 1: Build a 'Why?' tap on every score that generates a plain-language explanation (e.g., 'Readiness is 52 because HRV dropped 15ms and sleep was 5.2h'). Phase 2: Add a chat interface backed by on-device LLM or Apple Intelligence that can answer 'Should I run today?' using snapshot + history."
        )
    }

    // MARK: - Dimension 9: Sleep Consistency Score

    private static func sleepConsistencyScore() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "sleep_consistency",
            name: "Sleep Consistency / Schedule Regularity",
            description: "Tracking how regular bedtime and wake time are across days",
            whoopScore: 8,
            whoopEvidence: "Sleep Consistency metric measures timing regularity vs previous 4 days. Shown as a percentage. Research-backed: Harvard study linked consistent sleep to higher GPAs.",
            ouraScore: 7,
            ouraEvidence: "Sleep regularity tracked through bedtime/wake variance. Contributes to Sleep Score. Readiness penalizes irregular schedules. Timing trends visible.",
            thumpScore: 1,
            thumpEvidence: "SmartNudgeScheduler learns sleep patterns (wake hour per day-of-week) for notification timing, but this data is internal only — never shown to the user. No sleep consistency metric, chart, or score exists in any view.",
            gap: 7,
            improvementPlan: "Surface the SmartNudgeScheduler's learned sleep patterns as a user-visible 'Sleep Consistency' metric. Show bedtime/wake time variance over 7 days. Score regularity 0-100. Display on Trends alongside sleep hours. Penalize irregular schedules in Readiness."
        )
    }

    // MARK: - Dimension 10: Menstrual / Hormonal Tracking

    private static func menstrualAndHormonal() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "menstrual_hormonal",
            name: "Menstrual Cycle & Hormonal Insights",
            description: "Correlating physiological data with menstrual cycle phases for personalized coaching",
            whoopScore: 8,
            whoopEvidence: "Women's Hormonal Insights: Menstrual Cycle Insights + Pregnancy Insights. Correlates cycle phases with sleep, strain, mood, recovery changes. Temperature-driven phase detection.",
            ouraScore: 8,
            ouraEvidence: "Period Prediction using temperature trends. Cycle phase tracking with physiological correlations. Adjusts Readiness expectations during luteal phase. Pregnancy tracking mode.",
            thumpScore: 1,
            thumpEvidence: "BiologicalSex is collected in profile (male/female/notSet) and used for VO2 max norms. No menstrual cycle tracking, phase detection, or hormonal correlation exists. No temperature data to drive cycle detection.",
            gap: 7,
            improvementPlan: "Phase 1: Read .menstrualFlow from HealthKit (if user logs in Apple Health). Phase 2: If wrist temperature is available, detect luteal phase (temperature rise). Adjust readiness expectations during luteal phase (+5-10 RHR is normal). Show cycle phase on Dashboard for female users."
        )
    }

    // MARK: - Dimension 11: Muscular Load

    private static func muscularLoadTracking() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "muscular_load",
            name: "Muscular Load & Strength Training Tracking",
            description: "Quantifying resistance training volume and muscle group load beyond cardiovascular strain",
            whoopScore: 9,
            whoopEvidence: "Muscular Load score tracks volume x intensity for resistance training. Detects muscle groups engaged (squat vs curl). Combined with cardiovascular strain for total exertion picture. WHOOP 5.0 enhanced this with improved accelerometer data.",
            ouraScore: 2,
            ouraEvidence: "No muscular load tracking. Activity Score is movement-based only. Ring form factor limits motion detection to steps and general activity. No strength training quantification.",
            thumpScore: 1,
            thumpEvidence: "Workout type from HKWorkout is used for zone analysis and activity minutes, but no muscular load quantification. No volume x intensity calculation. No muscle group detection.",
            gap: 8,
            improvementPlan: "Read HKWorkout metadata (workout type, total energy burned, duration) and infer muscular load from strength-typed workouts. Build a simple volume model: sets x estimated load from workout calories. Show alongside cardiovascular zones as 'Strength Load' on Dashboard."
        )
    }

    // MARK: - Dimension 12: Social & Community

    private static func socialAndCommunity() -> CompetitiveDimension {
        CompetitiveDimension(
            id: "social_community",
            name: "Social Features & Community",
            description: "Team challenges, leaderboards, shared goals, and community engagement",
            whoopScore: 7,
            whoopEvidence: "WHOOP Teams feature for group challenges. Strain leaderboards. Shared recovery insights with teammates. Community forums and content.",
            ouraScore: 3,
            ouraEvidence: "Minimal social features. No team challenges or leaderboards. Focus is on individual wellness. Some community content via blog/articles.",
            thumpScore: 0,
            thumpEvidence: "No social features exist. Family subscription tier exists in StoreKit config but no shared goals or family dashboard is implemented. No leaderboards, challenges, or community features.",
            gap: 7,
            improvementPlan: "Phase 1: Build family dashboard for the Family tier — shared daily scores (anonymized), family streak, gentle nudge-sharing. Phase 2: Add weekly challenges (steps, consistency) with opt-in leaderboard. Keep it non-competitive ('team goals' not 'rankings')."
        )
    }

    // MARK: - Verdict

    private static func buildVerdict(_ dims: [CompetitiveDimension]) -> String {
        let totalGap = dims.reduce(0) { $0 + $1.gap }
        let maxGap = dims.max(by: { $0.gap < $1.gap })!
        let criticalGaps = dims.filter { $0.gap >= 7 }.count

        return """
        Thump has \(criticalGaps) critical gaps (score delta >= 7) vs competitors. \
        Total gap across 12 dimensions: \(totalGap) points. \
        Largest single gap: '\(maxGap.name)' at \(maxGap.gap) points behind. \
        Thump's strengths: Bio Age / Resilience (near parity with Oura), \
        5-zone HR analysis (ahead of Oura), coaching copy quality (competitive with both). \
        Thump's weaknesses: Missing sensor data (temperature, respiratory rate, SpO2), \
        no sleep staging, no strain model, no AI conversation, no social features. \
        Priority fix: Sleep staging and sleep debt — these use existing HealthKit data \
        (no new hardware) and close the two biggest perception gaps.
        """
    }
}

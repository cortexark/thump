// ConfigService.swift
// ThumpCore
//
// App-wide configuration values, default thresholds, feature flags,
// and tier-based feature gating helpers.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Config Service

/// Centralized, static configuration for the Thump engine and services.
///
/// All values are compile-time constants or derived from the current
/// ``SubscriptionTier``. Nothing in this struct is mutable at runtime
/// -- feature flags are toggled via build configuration or remote config
/// in a future release.
public struct ConfigService: Sendable {

    // MARK: - Lookback & Window Defaults

    /// Number of historical days used by ``HeartTrendEngine`` for baseline
    /// computation (median / MAD calculations).
    public static let defaultLookbackWindow: Int = 21

    /// Number of recent days used for linear-regression slope checks
    /// when detecting multi-day regressions.
    public static let defaultRegressionWindow: Int = 7

    /// Minimum number of data points required before the engine
    /// will produce a high-confidence assessment.
    public static let minimumHighConfidenceDays: Int = 14

    /// Minimum data points for medium confidence.
    public static let minimumMediumConfidenceDays: Int = 7

    // MARK: - Default Alert Policy

    /// The default ``AlertPolicy`` shipped with the app.
    /// Individual thresholds can be overridden by Coach-tier users
    /// in a future settings screen.
    public static let defaultAlertPolicy = AlertPolicy(
        anomalyHigh: 2.0,
        regressionSlope: -0.3,
        stressRHRZ: 1.5,
        stressHRVZ: -1.5,
        stressRecoveryZ: -1.5,
        cooldownHours: 8.0,
        maxAlertsPerDay: 3
    )

    // MARK: - Correlation Engine

    /// Minimum number of paired data points required for a meaningful
    /// Pearson correlation calculation.
    public static let minimumCorrelationPoints: Int = 7

    // MARK: - Sync & Connectivity

    /// Minimum interval (in seconds) between consecutive Watch-to-Phone
    /// sync attempts to avoid excessive battery drain.
    public static let minimumSyncIntervalSeconds: TimeInterval = 300

    /// Maximum number of ``StoredSnapshot`` entries to keep in local storage
    /// before trimming the oldest records.
    public static let maxStoredSnapshots: Int = 365

    // MARK: - Feature Flags

    /// Whether the experimental weekly-report generation is enabled.
    public static let enableWeeklyReports: Bool = true

    /// Whether correlation insight cards are shown on the dashboard.
    public static let enableCorrelationInsights: Bool = true

    /// Whether the Watch complication tap-to-feedback flow is active.
    public static let enableWatchFeedbackCapture: Bool = true

    /// Whether push-based anomaly alerts are enabled.
    public static let enableAnomalyAlerts: Bool = true

    /// Whether the onboarding questionnaire collects baseline preferences.
    public static let enableOnboardingQuestionnaire: Bool = false

    // MARK: - Tier-Based Feature Gating

    /// Returns `true` when the given tier allows access to the full
    /// metric dashboard (HRV, Recovery HR, VO2, zone load).
    public static func canAccessFullMetrics(tier: SubscriptionTier) -> Bool {
        tier.canAccessFullMetrics
    }

    /// Returns `true` when the given tier allows personalized daily nudges
    /// with dosage information.
    public static func canAccessNudges(tier: SubscriptionTier) -> Bool {
        tier.canAccessNudges
    }

    /// Returns `true` when the given tier allows weekly reports
    /// and multi-week trend analysis.
    public static func canAccessReports(tier: SubscriptionTier) -> Bool {
        tier.canAccessReports
    }

    /// Returns `true` when the given tier allows correlation
    /// insight cards (activity vs. trend).
    public static func canAccessCorrelations(tier: SubscriptionTier) -> Bool {
        tier.canAccessCorrelations
    }

    /// Returns the complete set of feature strings available for a tier.
    public static func availableFeatures(for tier: SubscriptionTier) -> [String] {
        tier.features
    }

    /// Returns `true` when a given feature flag name is enabled.
    /// Useful for generic gating in view code without hard-coding booleans.
    public static func isFeatureEnabled(_ featureName: String) -> Bool {
        switch featureName {
        case "weeklyReports": return enableWeeklyReports
        case "correlationInsights": return enableCorrelationInsights
        case "watchFeedbackCapture": return enableWatchFeedbackCapture
        case "anomalyAlerts": return enableAnomalyAlerts
        case "onboardingQuestionnaire": return enableOnboardingQuestionnaire
        default: return false
        }
    }

    // MARK: - Engine Factory

    /// Convenience factory that builds a ``HeartTrendEngine`` with the
    /// default configuration values.
    public static func makeDefaultEngine() -> HeartTrendEngine {
        HeartTrendEngine(
            lookbackWindow: defaultLookbackWindow,
            policy: defaultAlertPolicy
        )
    }

    // MARK: - Health Policy Config

    /// Default health policy configuration with all coaching thresholds.
    public static let policy = HealthPolicyConfig()

    /// Override with custom values for testing or internal debug screen.
    /// Remote config integration deferred to future phase.
    public static var policyOverride: HealthPolicyConfig?

    /// Returns the active policy: override if set, otherwise default.
    public static var activePolicy: HealthPolicyConfig {
        policyOverride ?? policy
    }

    // MARK: - Feature Flags

    /// When true, DashboardViewModel uses DailyEngineCoordinator instead
    /// of calling engines directly. Default false for safe rollout.
    public static var enableCoordinator: Bool = true

    // MARK: - Init Prevention

    /// `ConfigService` is a namespace; it should not be instantiated.
    private init() {}
}

// MARK: - Health Policy Config

/// Centralized, typed container for all coaching thresholds used by engines and views.
///
/// Every value here is a 1:1 copy of a previously hard-coded literal.
/// Grouped into cohesive sub-structs by domain. All values are compile-time
/// constants in the default instance; `policyOverride` enables runtime tuning.
public struct HealthPolicyConfig: Codable, Equatable, Sendable {

    // MARK: - Sleep & Readiness Policy

    public struct SleepReadiness: Codable, Equatable, Sendable {
        /// Sleep < 3h → readiness capped at 20
        public var sleepCapCriticalHours: Double
        public var sleepCapCriticalScore: Double
        /// Sleep < 4h → readiness capped at 35
        public var sleepCapLowHours: Double
        public var sleepCapLowScore: Double
        /// Sleep < 5h → readiness capped at 50
        public var sleepCapModerateHours: Double
        public var sleepCapModerateScore: Double
        /// Readiness band: recovering (0 ..< recovering)
        public var readinessRecovering: Int
        /// Readiness band: moderate (recovering ..< ready)
        public var readinessReady: Int
        /// Readiness band: primed (>= primed)
        public var readinessPrimed: Int
        /// Overtraining cap on readiness when consecutive elevation detected
        public var consecutiveAlertCap: Double
        /// Sleep pillar: Gaussian optimal center (hours)
        public var sleepOptimalHours: Double
        /// Sleep pillar: Gaussian sigma
        public var sleepSigma: Double
        /// Recovery pillar: minimum HR drop (bpm) for score = 0
        public var recoveryMinDrop: Double
        /// Recovery pillar: maximum HR drop (bpm) for score = 100
        public var recoveryMaxDrop: Double
        /// Floor score for missing sleep or recovery data
        public var missingDataFloorScore: Double
        /// Pillar weights (sleep, recovery, stress, activityBalance, hrvTrend)
        public var pillarWeights: [String: Double]

        public init(
            sleepCapCriticalHours: Double = 3.0,
            sleepCapCriticalScore: Double = 20.0,
            sleepCapLowHours: Double = 4.0,
            sleepCapLowScore: Double = 35.0,
            sleepCapModerateHours: Double = 5.0,
            sleepCapModerateScore: Double = 50.0,
            readinessRecovering: Int = 40,
            readinessReady: Int = 60,
            readinessPrimed: Int = 80,
            consecutiveAlertCap: Double = 50.0,
            sleepOptimalHours: Double = 8.0,
            sleepSigma: Double = 1.5,
            recoveryMinDrop: Double = 10.0,
            recoveryMaxDrop: Double = 40.0,
            missingDataFloorScore: Double = 40.0,
            pillarWeights: [String: Double] = [
                "sleep": 0.25,
                "recovery": 0.25,
                "stress": 0.20,
                "activityBalance": 0.15,
                "hrvTrend": 0.15
            ]
        ) {
            self.sleepCapCriticalHours = sleepCapCriticalHours
            self.sleepCapCriticalScore = sleepCapCriticalScore
            self.sleepCapLowHours = sleepCapLowHours
            self.sleepCapLowScore = sleepCapLowScore
            self.sleepCapModerateHours = sleepCapModerateHours
            self.sleepCapModerateScore = sleepCapModerateScore
            self.readinessRecovering = readinessRecovering
            self.readinessReady = readinessReady
            self.readinessPrimed = readinessPrimed
            self.consecutiveAlertCap = consecutiveAlertCap
            self.sleepOptimalHours = sleepOptimalHours
            self.sleepSigma = sleepSigma
            self.recoveryMinDrop = recoveryMinDrop
            self.recoveryMaxDrop = recoveryMaxDrop
            self.missingDataFloorScore = missingDataFloorScore
            self.pillarWeights = pillarWeights
        }
    }

    // MARK: - Stress & Overtraining Policy

    public struct StressOvertraining: Codable, Equatable, Sendable {
        /// RHR sigma threshold for overtraining detection (mean + N*σ)
        public var overtainingSigma: Double
        /// Readiness cap during consecutive RHR elevation
        public var overtainingReadinessCap: Double
        /// Stress score triggering journal prompt
        public var journalStressThreshold: Double
        /// Stress score triggering breath prompt on watch
        public var breathPromptThreshold: Double
        /// Consecutive overtraining day thresholds for future escalation
        public var overtainingDaysWarning: Int
        public var overtainingDaysMedical: Int
        public var overtainingDaysCritical: Int
        public var overtainingDaysConsult: Int
        /// Minimum observations before trusting sleep patterns
        public var minPatternObservations: Int
        /// Hours past typical wake time = "late"
        public var lateWakeThresholdHours: Double
        /// Minutes before bedtime to send wind-down nudge
        public var bedtimeNudgeLeadMinutes: Int
        /// StressEngine sigmoid steepness
        public var sigmoidK: Double
        /// StressEngine sigmoid midpoint
        public var sigmoidMid: Double
        /// Steps threshold below which desk mode is considered
        public var deskStepsThreshold: Double
        /// Workout minutes threshold above which acute mode is considered
        public var acuteWorkoutThreshold: Double
        /// Acute branch weights (RHR, HRV, CV)
        public var acuteWeights: (rhr: Double, hrv: Double, cv: Double)
        /// Desk branch weights (RHR, HRV, CV)
        public var deskWeights: (rhr: Double, hrv: Double, cv: Double)
        /// Confidence cutoffs (high, moderate)
        public var confidenceHighCutoff: Double
        public var confidenceModerateCutoff: Double

        // Codable conformance for tuples
        enum CodingKeys: String, CodingKey {
            case overtainingSigma, overtainingReadinessCap
            case journalStressThreshold, breathPromptThreshold
            case overtainingDaysWarning, overtainingDaysMedical
            case overtainingDaysCritical, overtainingDaysConsult
            case minPatternObservations, lateWakeThresholdHours, bedtimeNudgeLeadMinutes
            case sigmoidK, sigmoidMid, deskStepsThreshold, acuteWorkoutThreshold
            case acuteRHRWeight, acuteHRVWeight, acuteCVWeight
            case deskRHRWeight, deskHRVWeight, deskCVWeight
            case confidenceHighCutoff, confidenceModerateCutoff
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            overtainingSigma = try c.decode(Double.self, forKey: .overtainingSigma)
            overtainingReadinessCap = try c.decode(Double.self, forKey: .overtainingReadinessCap)
            journalStressThreshold = try c.decode(Double.self, forKey: .journalStressThreshold)
            breathPromptThreshold = try c.decode(Double.self, forKey: .breathPromptThreshold)
            overtainingDaysWarning = try c.decode(Int.self, forKey: .overtainingDaysWarning)
            overtainingDaysMedical = try c.decode(Int.self, forKey: .overtainingDaysMedical)
            overtainingDaysCritical = try c.decode(Int.self, forKey: .overtainingDaysCritical)
            overtainingDaysConsult = try c.decode(Int.self, forKey: .overtainingDaysConsult)
            minPatternObservations = try c.decode(Int.self, forKey: .minPatternObservations)
            lateWakeThresholdHours = try c.decode(Double.self, forKey: .lateWakeThresholdHours)
            bedtimeNudgeLeadMinutes = try c.decode(Int.self, forKey: .bedtimeNudgeLeadMinutes)
            sigmoidK = try c.decode(Double.self, forKey: .sigmoidK)
            sigmoidMid = try c.decode(Double.self, forKey: .sigmoidMid)
            deskStepsThreshold = try c.decode(Double.self, forKey: .deskStepsThreshold)
            acuteWorkoutThreshold = try c.decode(Double.self, forKey: .acuteWorkoutThreshold)
            let aRHR = try c.decode(Double.self, forKey: .acuteRHRWeight)
            let aHRV = try c.decode(Double.self, forKey: .acuteHRVWeight)
            let aCV = try c.decode(Double.self, forKey: .acuteCVWeight)
            acuteWeights = (aRHR, aHRV, aCV)
            let dRHR = try c.decode(Double.self, forKey: .deskRHRWeight)
            let dHRV = try c.decode(Double.self, forKey: .deskHRVWeight)
            let dCV = try c.decode(Double.self, forKey: .deskCVWeight)
            deskWeights = (dRHR, dHRV, dCV)
            confidenceHighCutoff = try c.decode(Double.self, forKey: .confidenceHighCutoff)
            confidenceModerateCutoff = try c.decode(Double.self, forKey: .confidenceModerateCutoff)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(overtainingSigma, forKey: .overtainingSigma)
            try c.encode(overtainingReadinessCap, forKey: .overtainingReadinessCap)
            try c.encode(journalStressThreshold, forKey: .journalStressThreshold)
            try c.encode(breathPromptThreshold, forKey: .breathPromptThreshold)
            try c.encode(overtainingDaysWarning, forKey: .overtainingDaysWarning)
            try c.encode(overtainingDaysMedical, forKey: .overtainingDaysMedical)
            try c.encode(overtainingDaysCritical, forKey: .overtainingDaysCritical)
            try c.encode(overtainingDaysConsult, forKey: .overtainingDaysConsult)
            try c.encode(minPatternObservations, forKey: .minPatternObservations)
            try c.encode(lateWakeThresholdHours, forKey: .lateWakeThresholdHours)
            try c.encode(bedtimeNudgeLeadMinutes, forKey: .bedtimeNudgeLeadMinutes)
            try c.encode(sigmoidK, forKey: .sigmoidK)
            try c.encode(sigmoidMid, forKey: .sigmoidMid)
            try c.encode(deskStepsThreshold, forKey: .deskStepsThreshold)
            try c.encode(acuteWorkoutThreshold, forKey: .acuteWorkoutThreshold)
            try c.encode(acuteWeights.rhr, forKey: .acuteRHRWeight)
            try c.encode(acuteWeights.hrv, forKey: .acuteHRVWeight)
            try c.encode(acuteWeights.cv, forKey: .acuteCVWeight)
            try c.encode(deskWeights.rhr, forKey: .deskRHRWeight)
            try c.encode(deskWeights.hrv, forKey: .deskHRVWeight)
            try c.encode(deskWeights.cv, forKey: .deskCVWeight)
            try c.encode(confidenceHighCutoff, forKey: .confidenceHighCutoff)
            try c.encode(confidenceModerateCutoff, forKey: .confidenceModerateCutoff)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.overtainingSigma == rhs.overtainingSigma
            && lhs.overtainingReadinessCap == rhs.overtainingReadinessCap
            && lhs.journalStressThreshold == rhs.journalStressThreshold
            && lhs.breathPromptThreshold == rhs.breathPromptThreshold
            && lhs.overtainingDaysWarning == rhs.overtainingDaysWarning
            && lhs.overtainingDaysMedical == rhs.overtainingDaysMedical
            && lhs.overtainingDaysCritical == rhs.overtainingDaysCritical
            && lhs.overtainingDaysConsult == rhs.overtainingDaysConsult
            && lhs.minPatternObservations == rhs.minPatternObservations
            && lhs.lateWakeThresholdHours == rhs.lateWakeThresholdHours
            && lhs.bedtimeNudgeLeadMinutes == rhs.bedtimeNudgeLeadMinutes
            && lhs.sigmoidK == rhs.sigmoidK
            && lhs.sigmoidMid == rhs.sigmoidMid
            && lhs.deskStepsThreshold == rhs.deskStepsThreshold
            && lhs.acuteWorkoutThreshold == rhs.acuteWorkoutThreshold
            && lhs.acuteWeights.rhr == rhs.acuteWeights.rhr
            && lhs.acuteWeights.hrv == rhs.acuteWeights.hrv
            && lhs.acuteWeights.cv == rhs.acuteWeights.cv
            && lhs.deskWeights.rhr == rhs.deskWeights.rhr
            && lhs.deskWeights.hrv == rhs.deskWeights.hrv
            && lhs.deskWeights.cv == rhs.deskWeights.cv
            && lhs.confidenceHighCutoff == rhs.confidenceHighCutoff
            && lhs.confidenceModerateCutoff == rhs.confidenceModerateCutoff
        }

        public init(
            overtainingSigma: Double = 2.0,
            overtainingReadinessCap: Double = 50.0,
            journalStressThreshold: Double = 65.0,
            breathPromptThreshold: Double = 60.0,
            overtainingDaysWarning: Int = 3,
            overtainingDaysMedical: Int = 5,
            overtainingDaysCritical: Int = 7,
            overtainingDaysConsult: Int = 10,
            minPatternObservations: Int = 3,
            lateWakeThresholdHours: Double = 1.5,
            bedtimeNudgeLeadMinutes: Int = 30,
            sigmoidK: Double = 0.08,
            sigmoidMid: Double = 50.0,
            deskStepsThreshold: Double = 2000.0,
            acuteWorkoutThreshold: Double = 15.0,
            acuteWeights: (rhr: Double, hrv: Double, cv: Double) = (0.50, 0.30, 0.20),
            deskWeights: (rhr: Double, hrv: Double, cv: Double) = (0.20, 0.50, 0.30),
            confidenceHighCutoff: Double = 0.70,
            confidenceModerateCutoff: Double = 0.40
        ) {
            self.overtainingSigma = overtainingSigma
            self.overtainingReadinessCap = overtainingReadinessCap
            self.journalStressThreshold = journalStressThreshold
            self.breathPromptThreshold = breathPromptThreshold
            self.overtainingDaysWarning = overtainingDaysWarning
            self.overtainingDaysMedical = overtainingDaysMedical
            self.overtainingDaysCritical = overtainingDaysCritical
            self.overtainingDaysConsult = overtainingDaysConsult
            self.minPatternObservations = minPatternObservations
            self.lateWakeThresholdHours = lateWakeThresholdHours
            self.bedtimeNudgeLeadMinutes = bedtimeNudgeLeadMinutes
            self.sigmoidK = sigmoidK
            self.sigmoidMid = sigmoidMid
            self.deskStepsThreshold = deskStepsThreshold
            self.acuteWorkoutThreshold = acuteWorkoutThreshold
            self.acuteWeights = acuteWeights
            self.deskWeights = deskWeights
            self.confidenceHighCutoff = confidenceHighCutoff
            self.confidenceModerateCutoff = confidenceModerateCutoff
        }
    }

    // MARK: - Goal Targets

    public struct GoalTargets: Codable, Equatable, Sendable {
        /// Step targets by readiness band (primed/ready/moderate/recovering)
        public var stepsPrimed: Int
        public var stepsReady: Int
        public var stepsModerate: Int
        public var stepsRecovering: Int
        /// Active minute targets by readiness band
        public var activeMinPrimed: Int
        public var activeMinReady: Int
        public var activeMinModerate: Int
        public var activeMinRecovering: Int
        /// Sleep targets by readiness band (hours)
        public var sleepTargetRecovering: Double
        public var sleepTargetModerate: Double
        public var sleepTargetReady: Double

        public init(
            stepsPrimed: Int = 8000,
            stepsReady: Int = 7000,
            stepsModerate: Int = 5000,
            stepsRecovering: Int = 3000,
            activeMinPrimed: Int = 45,
            activeMinReady: Int = 30,
            activeMinModerate: Int = 20,
            activeMinRecovering: Int = 10,
            sleepTargetRecovering: Double = 8.0,
            sleepTargetModerate: Double = 7.5,
            sleepTargetReady: Double = 7.0
        ) {
            self.stepsPrimed = stepsPrimed
            self.stepsReady = stepsReady
            self.stepsModerate = stepsModerate
            self.stepsRecovering = stepsRecovering
            self.activeMinPrimed = activeMinPrimed
            self.activeMinReady = activeMinReady
            self.activeMinModerate = activeMinModerate
            self.activeMinRecovering = activeMinRecovering
            self.sleepTargetRecovering = sleepTargetRecovering
            self.sleepTargetModerate = sleepTargetModerate
            self.sleepTargetReady = sleepTargetReady
        }
    }

    // MARK: - View Display Thresholds

    public struct ViewThresholds: Codable, Equatable, Sendable {
        /// ThumpCheck: sleep hours below which workout is skipped
        public var sleepSkipWorkoutHours: Double
        /// ThumpCheck: sleep hours below which effort is capped at "very light"
        public var sleepLightOnlyHours: Double
        /// Recovery pill: score >= strong threshold
        public var recoveryStrongScore: Int
        /// Recovery pill: score >= moderate threshold
        public var recoveryModerateScore: Int
        /// Activity pill: total minutes >= "high"
        public var activityHighMinutes: Double
        /// Activity pill: total minutes >= "moderate"
        public var activityModerateMinutes: Double
        /// CoachStreak: progress score color thresholds
        public var streakGreenScore: Int
        public var streakBlueScore: Int
        /// InsightsView: nudge completion thresholds
        public var nudgeCompletionSolid: Int
        public var nudgeCompletionMinimum: Int
        /// Sleep hours threshold for "catch up on sleep" nudge
        public var lowSleepNudgeHours: Double
        /// Sleep hours threshold for "long sleep" nudge
        public var longSleepNudgeHours: Double

        public init(
            sleepSkipWorkoutHours: Double = 4.0,
            sleepLightOnlyHours: Double = 5.0,
            recoveryStrongScore: Int = 75,
            recoveryModerateScore: Int = 55,
            activityHighMinutes: Double = 30.0,
            activityModerateMinutes: Double = 10.0,
            streakGreenScore: Int = 70,
            streakBlueScore: Int = 45,
            nudgeCompletionSolid: Int = 70,
            nudgeCompletionMinimum: Int = 40,
            lowSleepNudgeHours: Double = 6.5,
            longSleepNudgeHours: Double = 9.5
        ) {
            self.sleepSkipWorkoutHours = sleepSkipWorkoutHours
            self.sleepLightOnlyHours = sleepLightOnlyHours
            self.recoveryStrongScore = recoveryStrongScore
            self.recoveryModerateScore = recoveryModerateScore
            self.activityHighMinutes = activityHighMinutes
            self.activityModerateMinutes = activityModerateMinutes
            self.streakGreenScore = streakGreenScore
            self.streakBlueScore = streakBlueScore
            self.nudgeCompletionSolid = nudgeCompletionSolid
            self.nudgeCompletionMinimum = nudgeCompletionMinimum
            self.lowSleepNudgeHours = lowSleepNudgeHours
            self.longSleepNudgeHours = longSleepNudgeHours
        }
    }

    // MARK: - HeartTrendEngine Thresholds

    public struct TrendEngineThresholds: Codable, Equatable, Sendable {
        /// Signal weights for composite anomaly score
        public var weightRHR: Double
        public var weightHRV: Double
        public var weightRecovery1m: Double
        public var weightRecovery2m: Double
        public var weightVO2: Double
        /// Consecutive elevation: minimum consecutive days for alert
        public var consecutiveElevationDays: Int
        /// Week-over-week z-score thresholds
        public var weeklySignificantZ: Double
        public var weeklyElevatedZ: Double
        /// Recovery trend z-score thresholds
        public var recoveryImprovingZ: Double
        public var recoveryDecliningZ: Double
        /// Scenario detection: RHR bpm above mean for overtraining
        public var overtainingRHRDelta: Double
        /// Scenario detection: HRV % below mean for overtraining
        public var overtainingHRVPercent: Double
        /// Scenario detection: HRV % below avg for high stress day
        public var highStressHRVPercent: Double
        /// Scenario detection: RHR bpm above avg for high stress day
        public var highStressRHRDelta: Double
        /// Scenario detection: HRV % above avg for great recovery
        public var greatRecoveryHRVPercent: Double
        /// Trend detection: slope threshold for improving/declining
        public var trendSlopeThreshold: Double

        public init(
            weightRHR: Double = 0.25,
            weightHRV: Double = 0.25,
            weightRecovery1m: Double = 0.20,
            weightRecovery2m: Double = 0.10,
            weightVO2: Double = 0.20,
            consecutiveElevationDays: Int = 3,
            weeklySignificantZ: Double = 1.5,
            weeklyElevatedZ: Double = 0.5,
            recoveryImprovingZ: Double = 1.0,
            recoveryDecliningZ: Double = -1.0,
            overtainingRHRDelta: Double = 7.0,
            overtainingHRVPercent: Double = 0.80,
            highStressHRVPercent: Double = 0.85,
            highStressRHRDelta: Double = 5.0,
            greatRecoveryHRVPercent: Double = 1.10,
            trendSlopeThreshold: Double = 0.15
        ) {
            self.weightRHR = weightRHR
            self.weightHRV = weightHRV
            self.weightRecovery1m = weightRecovery1m
            self.weightRecovery2m = weightRecovery2m
            self.weightVO2 = weightVO2
            self.consecutiveElevationDays = consecutiveElevationDays
            self.weeklySignificantZ = weeklySignificantZ
            self.weeklyElevatedZ = weeklyElevatedZ
            self.recoveryImprovingZ = recoveryImprovingZ
            self.recoveryDecliningZ = recoveryDecliningZ
            self.overtainingRHRDelta = overtainingRHRDelta
            self.overtainingHRVPercent = overtainingHRVPercent
            self.highStressHRVPercent = highStressHRVPercent
            self.highStressRHRDelta = highStressRHRDelta
            self.greatRecoveryHRVPercent = greatRecoveryHRVPercent
            self.trendSlopeThreshold = trendSlopeThreshold
        }
    }

    // MARK: - Sub-struct instances

    public var sleepReadiness: SleepReadiness
    public var stressOvertraining: StressOvertraining
    public var goals: GoalTargets
    public var view: ViewThresholds
    public var trendEngine: TrendEngineThresholds

    public init(
        sleepReadiness: SleepReadiness = SleepReadiness(),
        stressOvertraining: StressOvertraining = StressOvertraining(),
        goals: GoalTargets = GoalTargets(),
        view: ViewThresholds = ViewThresholds(),
        trendEngine: TrendEngineThresholds = TrendEngineThresholds()
    ) {
        self.sleepReadiness = sleepReadiness
        self.stressOvertraining = stressOvertraining
        self.goals = goals
        self.view = view
        self.trendEngine = trendEngine
    }
}

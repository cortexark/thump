// HealthPolicyConfigTests.swift
// Thump Tests
//
// Comprehensive TDD tests for HealthPolicyConfig and its sub-structs.
// Guards every default value, Codable roundtrip, override behavior,
// and structural invariants.

import XCTest
@testable import Thump

final class HealthPolicyConfigTests: XCTestCase {

    // MARK: - 1. Default Value Tests — SleepReadiness

    func testDefaultSleepCapCriticalHours() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.sleepCapCriticalHours, 3.0)
    }

    func testDefaultSleepCapCriticalScore() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.sleepCapCriticalScore, 20.0)
    }

    func testDefaultSleepCapLowHours() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.sleepCapLowHours, 4.0)
    }

    func testDefaultSleepCapLowScore() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.sleepCapLowScore, 35.0)
    }

    func testDefaultSleepCapModerateHours() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.sleepCapModerateHours, 5.0)
    }

    func testDefaultSleepCapModerateScore() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.sleepCapModerateScore, 50.0)
    }

    func testDefaultReadinessRecovering() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.readinessRecovering, 40)
    }

    func testDefaultReadinessReady() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.readinessReady, 60)
    }

    func testDefaultReadinessPrimed() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.readinessPrimed, 80)
    }

    func testDefaultConsecutiveAlertCap() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.consecutiveAlertCap, 50.0)
    }

    func testDefaultSleepOptimalHours() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.sleepOptimalHours, 8.0)
    }

    func testDefaultSleepSigma() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.sleepSigma, 1.5)
    }

    func testDefaultRecoveryMinDrop() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.recoveryMinDrop, 10.0)
    }

    func testDefaultRecoveryMaxDrop() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.recoveryMaxDrop, 40.0)
    }

    func testDefaultMissingDataFloorScore() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.missingDataFloorScore, 40.0)
    }

    func testDefaultPillarWeightSleep() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.pillarWeights["sleep"], 0.25)
    }

    func testDefaultPillarWeightRecovery() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.pillarWeights["recovery"], 0.25)
    }

    func testDefaultPillarWeightStress() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.pillarWeights["stress"], 0.20)
    }

    func testDefaultPillarWeightActivityBalance() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.pillarWeights["activityBalance"], 0.15)
    }

    func testDefaultPillarWeightHRVTrend() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.pillarWeights["hrvTrend"], 0.15)
    }

    func testDefaultPillarWeightsContainExactlyFiveKeys() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.sleepReadiness.pillarWeights.count, 5)
    }

    // MARK: - 1. Default Value Tests — StressOvertraining

    func testDefaultOvertrainingSigma() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.overtainingSigma, 2.0)
    }

    func testDefaultOvertrainingReadinessCap() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.overtainingReadinessCap, 50.0)
    }

    func testDefaultJournalStressThreshold() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.journalStressThreshold, 65.0)
    }

    func testDefaultBreathPromptThreshold() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.breathPromptThreshold, 60.0)
    }

    func testDefaultOvertrainingDaysWarning() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.overtainingDaysWarning, 3)
    }

    func testDefaultOvertrainingDaysMedical() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.overtainingDaysMedical, 5)
    }

    func testDefaultOvertrainingDaysCritical() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.overtainingDaysCritical, 7)
    }

    func testDefaultOvertrainingDaysConsult() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.overtainingDaysConsult, 10)
    }

    func testDefaultMinPatternObservations() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.minPatternObservations, 3)
    }

    func testDefaultLateWakeThresholdHours() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.lateWakeThresholdHours, 1.5)
    }

    func testDefaultBedtimeNudgeLeadMinutes() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.bedtimeNudgeLeadMinutes, 30)
    }

    func testDefaultSigmoidK() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.sigmoidK, 0.08)
    }

    func testDefaultSigmoidMid() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.sigmoidMid, 50.0)
    }

    func testDefaultDeskStepsThreshold() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.deskStepsThreshold, 2000.0)
    }

    func testDefaultAcuteWorkoutThreshold() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.acuteWorkoutThreshold, 15.0)
    }

    func testDefaultAcuteWeightsRHR() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.acuteWeights.rhr, 0.50)
    }

    func testDefaultAcuteWeightsHRV() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.acuteWeights.hrv, 0.30)
    }

    func testDefaultAcuteWeightsCV() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.acuteWeights.cv, 0.20)
    }

    func testDefaultDeskWeightsRHR() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.deskWeights.rhr, 0.20)
    }

    func testDefaultDeskWeightsHRV() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.deskWeights.hrv, 0.50)
    }

    func testDefaultDeskWeightsCV() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.deskWeights.cv, 0.30)
    }

    func testDefaultConfidenceHighCutoff() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.confidenceHighCutoff, 0.70)
    }

    func testDefaultConfidenceModerateCutoff() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.stressOvertraining.confidenceModerateCutoff, 0.40)
    }

    // MARK: - 1. Default Value Tests — GoalTargets

    func testDefaultStepsPrimed() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.stepsPrimed, 8000)
    }

    func testDefaultStepsReady() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.stepsReady, 7000)
    }

    func testDefaultStepsModerate() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.stepsModerate, 5000)
    }

    func testDefaultStepsRecovering() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.stepsRecovering, 3000)
    }

    func testDefaultActiveMinPrimed() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.activeMinPrimed, 45)
    }

    func testDefaultActiveMinReady() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.activeMinReady, 30)
    }

    func testDefaultActiveMinModerate() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.activeMinModerate, 20)
    }

    func testDefaultActiveMinRecovering() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.activeMinRecovering, 10)
    }

    func testDefaultSleepTargetRecovering() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.sleepTargetRecovering, 8.0)
    }

    func testDefaultSleepTargetModerate() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.sleepTargetModerate, 7.5)
    }

    func testDefaultSleepTargetReady() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.goals.sleepTargetReady, 7.0)
    }

    // MARK: - 1. Default Value Tests — ViewThresholds

    func testDefaultSleepSkipWorkoutHours() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.sleepSkipWorkoutHours, 4.0)
    }

    func testDefaultSleepLightOnlyHours() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.sleepLightOnlyHours, 5.0)
    }

    func testDefaultRecoveryStrongScore() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.recoveryStrongScore, 75)
    }

    func testDefaultRecoveryModerateScore() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.recoveryModerateScore, 55)
    }

    func testDefaultActivityHighMinutes() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.activityHighMinutes, 30.0)
    }

    func testDefaultActivityModerateMinutes() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.activityModerateMinutes, 10.0)
    }

    func testDefaultStreakGreenScore() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.streakGreenScore, 70)
    }

    func testDefaultStreakBlueScore() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.streakBlueScore, 45)
    }

    func testDefaultNudgeCompletionSolid() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.nudgeCompletionSolid, 70)
    }

    func testDefaultNudgeCompletionMinimum() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.nudgeCompletionMinimum, 40)
    }

    func testDefaultLowSleepNudgeHours() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.lowSleepNudgeHours, 6.5)
    }

    func testDefaultLongSleepNudgeHours() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.view.longSleepNudgeHours, 9.5)
    }

    // MARK: - 1. Default Value Tests — TrendEngineThresholds

    func testDefaultWeightRHR() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.weightRHR, 0.25)
    }

    func testDefaultWeightHRV() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.weightHRV, 0.25)
    }

    func testDefaultWeightRecovery1m() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.weightRecovery1m, 0.20)
    }

    func testDefaultWeightRecovery2m() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.weightRecovery2m, 0.10)
    }

    func testDefaultWeightVO2() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.weightVO2, 0.20)
    }

    func testDefaultConsecutiveElevationDays() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.consecutiveElevationDays, 3)
    }

    func testDefaultWeeklySignificantZ() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.weeklySignificantZ, 1.5)
    }

    func testDefaultWeeklyElevatedZ() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.weeklyElevatedZ, 0.5)
    }

    func testDefaultRecoveryImprovingZ() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.recoveryImprovingZ, 1.0)
    }

    func testDefaultRecoveryDecliningZ() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.recoveryDecliningZ, -1.0)
    }

    func testDefaultOvertrainingRHRDelta() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.overtainingRHRDelta, 7.0)
    }

    func testDefaultOvertrainingHRVPercent() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.overtainingHRVPercent, 0.80)
    }

    func testDefaultHighStressHRVPercent() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.highStressHRVPercent, 0.85)
    }

    func testDefaultHighStressRHRDelta() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.highStressRHRDelta, 5.0)
    }

    func testDefaultGreatRecoveryHRVPercent() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.greatRecoveryHRVPercent, 1.10)
    }

    func testDefaultTrendSlopeThreshold() {
        let cfg = HealthPolicyConfig()
        XCTAssertEqual(cfg.trendEngine.trendSlopeThreshold, 0.15)
    }

    // MARK: - 2. Codable Tests

    func testHealthPolicyConfigRoundtrip() throws {
        let original = HealthPolicyConfig()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HealthPolicyConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testSleepReadinessRoundtrip() throws {
        let original = HealthPolicyConfig.SleepReadiness()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HealthPolicyConfig.SleepReadiness.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testStressOvertrainingRoundtrip() throws {
        let original = HealthPolicyConfig.StressOvertraining()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HealthPolicyConfig.StressOvertraining.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testGoalTargetsRoundtrip() throws {
        let original = HealthPolicyConfig.GoalTargets()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HealthPolicyConfig.GoalTargets.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testViewThresholdsRoundtrip() throws {
        let original = HealthPolicyConfig.ViewThresholds()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HealthPolicyConfig.ViewThresholds.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testTrendEngineThresholdsRoundtrip() throws {
        let original = HealthPolicyConfig.TrendEngineThresholds()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HealthPolicyConfig.TrendEngineThresholds.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testCustomValuesRoundtrip() throws {
        var cfg = HealthPolicyConfig()
        cfg.sleepReadiness.sleepCapCriticalHours = 2.5
        cfg.stressOvertraining = .init(sigmoidK: 0.12, sigmoidMid: 55.0)
        cfg.goals.stepsPrimed = 10000
        cfg.view.streakGreenScore = 80
        cfg.trendEngine.weightRHR = 0.30
        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(HealthPolicyConfig.self, from: data)
        XCTAssertEqual(cfg, decoded)
    }

    // MARK: - 3. Override Tests

    func testPolicyOverrideReturnsOverride() {
        let custom = HealthPolicyConfig(goals: .init(stepsPrimed: 12000))
        ConfigService.policyOverride = custom
        XCTAssertEqual(ConfigService.activePolicy.goals.stepsPrimed, 12000)
        ConfigService.policyOverride = nil
    }

    func testPolicyOverrideNilReturnsDefault() {
        ConfigService.policyOverride = nil
        XCTAssertEqual(ConfigService.activePolicy, ConfigService.policy)
    }

    func testCustomStressWeightsDifferFromDefault() {
        let custom = HealthPolicyConfig(
            stressOvertraining: .init(
                acuteWeights: (0.40, 0.40, 0.20),
                deskWeights: (0.30, 0.30, 0.40)
            )
        )
        ConfigService.policyOverride = custom
        let active = ConfigService.activePolicy
        let defaults = ConfigService.policy
        XCTAssertNotEqual(active.stressOvertraining.acuteWeights.rhr, defaults.stressOvertraining.acuteWeights.rhr)
        XCTAssertNotEqual(active.stressOvertraining.deskWeights.hrv, defaults.stressOvertraining.deskWeights.hrv)
        ConfigService.policyOverride = nil
    }

    func testOverrideDoesNotMutateStaticDefault() {
        let originalSteps = ConfigService.policy.goals.stepsPrimed
        ConfigService.policyOverride = HealthPolicyConfig(goals: .init(stepsPrimed: 99999))
        XCTAssertEqual(ConfigService.policy.goals.stepsPrimed, originalSteps)
        ConfigService.policyOverride = nil
    }

    // MARK: - 4. Validation Tests — Weight Sums

    func testPillarWeightsSumToOne() {
        let cfg = HealthPolicyConfig()
        let sum = cfg.sleepReadiness.pillarWeights.values.reduce(0.0, +)
        XCTAssertEqual(sum, 1.0)
    }

    func testAcuteWeightsSumToOne() {
        let cfg = HealthPolicyConfig()
        let w = cfg.stressOvertraining.acuteWeights
        let sum = w.rhr + w.hrv + w.cv
        XCTAssertEqual(sum, 1.0)
    }

    func testDeskWeightsSumToOne() {
        let cfg = HealthPolicyConfig()
        let w = cfg.stressOvertraining.deskWeights
        let sum = w.rhr + w.hrv + w.cv
        XCTAssertEqual(sum, 1.0)
    }

    func testTrendEngineWeightsSumToOne() {
        let cfg = HealthPolicyConfig()
        let t = cfg.trendEngine
        let sum = t.weightRHR + t.weightHRV + t.weightRecovery1m + t.weightRecovery2m + t.weightVO2
        XCTAssertEqual(sum, 1.0)
    }

    // MARK: - 4. Validation Tests — Ordering Invariants

    func testSleepCapsOrdered() {
        let cfg = HealthPolicyConfig()
        let sr = cfg.sleepReadiness
        XCTAssertLessThan(sr.sleepCapCriticalHours, sr.sleepCapLowHours)
        XCTAssertLessThan(sr.sleepCapLowHours, sr.sleepCapModerateHours)
    }

    func testSleepCapScoresOrdered() {
        let cfg = HealthPolicyConfig()
        let sr = cfg.sleepReadiness
        XCTAssertLessThan(sr.sleepCapCriticalScore, sr.sleepCapLowScore)
        XCTAssertLessThan(sr.sleepCapLowScore, sr.sleepCapModerateScore)
    }

    func testReadinessBandsOrdered() {
        let cfg = HealthPolicyConfig()
        let sr = cfg.sleepReadiness
        XCTAssertLessThan(sr.readinessRecovering, sr.readinessReady)
        XCTAssertLessThan(sr.readinessReady, sr.readinessPrimed)
    }

    func testOvertrainingDaysOrdered() {
        let cfg = HealthPolicyConfig()
        let st = cfg.stressOvertraining
        XCTAssertLessThan(st.overtainingDaysWarning, st.overtainingDaysMedical)
        XCTAssertLessThan(st.overtainingDaysMedical, st.overtainingDaysCritical)
        XCTAssertLessThan(st.overtainingDaysCritical, st.overtainingDaysConsult)
    }

    // MARK: - 4. Validation Tests — Positive Values

    func testSigmoidKPositive() {
        let cfg = HealthPolicyConfig()
        XCTAssertGreaterThan(cfg.stressOvertraining.sigmoidK, 0)
    }

    func testAllScoreCapsPositive() {
        let cfg = HealthPolicyConfig()
        XCTAssertGreaterThan(cfg.sleepReadiness.sleepCapCriticalScore, 0)
        XCTAssertGreaterThan(cfg.sleepReadiness.sleepCapLowScore, 0)
        XCTAssertGreaterThan(cfg.sleepReadiness.sleepCapModerateScore, 0)
        XCTAssertGreaterThan(cfg.sleepReadiness.consecutiveAlertCap, 0)
        XCTAssertGreaterThan(cfg.stressOvertraining.overtainingReadinessCap, 0)
    }

    func testConfidenceCutoffsOrdered() {
        let cfg = HealthPolicyConfig()
        XCTAssertGreaterThan(cfg.stressOvertraining.confidenceHighCutoff,
                             cfg.stressOvertraining.confidenceModerateCutoff)
    }

    func testRecoveryDropRangeValid() {
        let cfg = HealthPolicyConfig()
        XCTAssertLessThan(cfg.sleepReadiness.recoveryMinDrop, cfg.sleepReadiness.recoveryMaxDrop)
    }

    // MARK: - 5. ConfigService Integration

    func testConfigServicePolicyIsDefault() {
        let policy = ConfigService.policy
        let fresh = HealthPolicyConfig()
        XCTAssertEqual(policy, fresh)
    }

    func testActivePolicyEqualsDefaultWhenNoOverride() {
        ConfigService.policyOverride = nil
        XCTAssertEqual(ConfigService.activePolicy, ConfigService.policy)
    }

    func testActivePolicyReturnsOverrideWhenSet() {
        let custom = HealthPolicyConfig(view: .init(streakGreenScore: 99))
        ConfigService.policyOverride = custom
        XCTAssertEqual(ConfigService.activePolicy.view.streakGreenScore, 99)
        XCTAssertNotEqual(ConfigService.activePolicy, ConfigService.policy)
        ConfigService.policyOverride = nil
    }
}

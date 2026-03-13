// HeartTrendEngine.swift
// ThumpCore
//
// Core trend computation engine using robust statistical methods.
// Computes daily assessments from health metric history.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Alert Policy

/// Configurable thresholds for anomaly detection and alerting.
public struct AlertPolicy: Codable, Equatable, Sendable {
    /// Anomaly score threshold above which the status becomes needsAttention.
    public let anomalyHigh: Double

    /// Linear slope threshold (negative means worsening) for regression detection.
    public let regressionSlope: Double

    /// Robust Z-score threshold for elevated RHR in stress pattern.
    public let stressRHRZ: Double

    /// Robust Z-score threshold for depressed HRV in stress pattern.
    public let stressHRVZ: Double

    /// Robust Z-score threshold for depressed recovery in stress pattern.
    public let stressRecoveryZ: Double

    /// Minimum hours between consecutive alerts.
    public let cooldownHours: Double

    /// Maximum alerts allowed per calendar day.
    public let maxAlertsPerDay: Int

    public init(
        anomalyHigh: Double = 2.0,
        regressionSlope: Double = -0.3,
        stressRHRZ: Double = 1.5,
        stressHRVZ: Double = -1.5,
        stressRecoveryZ: Double = -1.5,
        cooldownHours: Double = 8.0,
        maxAlertsPerDay: Int = 3
    ) {
        self.anomalyHigh = anomalyHigh
        self.regressionSlope = regressionSlope
        self.stressRHRZ = stressRHRZ
        self.stressHRVZ = stressHRVZ
        self.stressRecoveryZ = stressRecoveryZ
        self.cooldownHours = cooldownHours
        self.maxAlertsPerDay = maxAlertsPerDay
    }
}

// MARK: - Heart Trend Engine

/// Stateless trend computation engine. Accepts history and produces a daily assessment.
///
/// The engine uses robust statistics (median + MAD) to detect anomalies, linear
/// regression for multi-day trend detection, and composite pattern matching for
/// stress-like signals. All methods are pure functions with no side effects.
public struct HeartTrendEngine: Sendable {

    /// Number of historical days to consider for baseline computation.
    public let lookbackWindow: Int

    /// Alert detection thresholds.
    public let policy: AlertPolicy

    /// Number of recent days used for regression slope checks.
    private let regressionWindow: Int = 7

    // Signal weights for composite anomaly score
    private let weightRHR: Double = 0.25
    private let weightHRV: Double = 0.25
    private let weightRecovery1m: Double = 0.20
    private let weightRecovery2m: Double = 0.10
    private let weightVO2: Double = 0.20

    public init(lookbackWindow: Int = 21, policy: AlertPolicy = AlertPolicy()) {
        self.lookbackWindow = max(lookbackWindow, 3)
        self.policy = policy
    }

    // MARK: - Public API

    /// Produce a complete daily assessment from the snapshot history.
    ///
    /// - Parameters:
    ///   - history: Array of historical snapshots, ordered oldest-first.
    ///   - current: Today's snapshot to assess.
    ///   - feedback: Optional user feedback from the previous day.
    /// - Returns: A fully populated `HeartAssessment`.
    public func assess(
        history: [HeartSnapshot],
        current: HeartSnapshot,
        feedback: DailyFeedback? = nil
    ) -> HeartAssessment {
        let relevantHistory = recentHistory(from: history)
        let confidence = confidenceLevel(current: current, history: relevantHistory)
        let anomaly = anomalyScore(current: current, history: relevantHistory)
        let regression = detectRegression(history: relevantHistory, current: current)
        let stress = detectStressPattern(current: current, history: relevantHistory)
        let cardio = computeCardioScore(current: current, history: relevantHistory)

        // New signals: week-over-week, consecutive elevation, recovery, scenario
        let wowTrend = weekOverWeekTrend(history: relevantHistory, current: current)
        let consecutiveAlert = detectConsecutiveElevation(
            history: relevantHistory, current: current
        )
        let recovery = recoveryTrend(history: relevantHistory, current: current)
        let scenario = detectScenario(history: relevantHistory, current: current)

        let status = determineStatus(
            anomaly: anomaly,
            regression: regression,
            stress: stress,
            confidence: confidence,
            consecutiveAlert: consecutiveAlert,
            weekTrend: wowTrend
        )

        // Compute readiness so NudgeGenerator can gate intensity by HRV/RHR/sleep state.
        // Poor sleep → HRV drops + RHR rises → readiness falls → goal backs off to walk/rest.
        let readiness = ReadinessEngine().compute(
            snapshot: current,
            stressScore: stress ? 70.0 : (anomaly > 0.5 ? 50.0 : 25.0),
            recentHistory: relevantHistory
        )

        let nudgeGenerator = NudgeGenerator()
        let allNudges = nudgeGenerator.generateMultiple(
            confidence: confidence,
            anomaly: anomaly,
            regression: regression,
            stress: stress,
            feedback: feedback,
            current: current,
            history: relevantHistory,
            readiness: readiness
        )
        let primaryNudge = allNudges.first ?? nudgeGenerator.generate(
            confidence: confidence,
            anomaly: anomaly,
            regression: regression,
            stress: stress,
            feedback: feedback,
            current: current,
            history: relevantHistory,
            readiness: readiness
        )

        let explanation = buildExplanation(
            status: status,
            confidence: confidence,
            anomaly: anomaly,
            regression: regression,
            stress: stress,
            cardio: cardio,
            wowTrend: wowTrend,
            consecutiveAlert: consecutiveAlert,
            scenario: scenario,
            recovery: recovery
        )

        // Build recovery context when readiness is below threshold (recovering or moderate).
        // This flows to DashboardView (inline banner), StressView (bedtime action),
        // and the sleep goal tile — closing the loop: bad sleep → low HRV → lighter goal →
        // here's what to do TONIGHT to fix tomorrow.
        let recoveryCtx: RecoveryContext? = readiness.flatMap { r in
            guard r.level == .recovering || r.level == .moderate else { return nil }

            let hrvPillar  = r.pillars.first { $0.type == .hrvTrend }
            let sleepPillar = r.pillars.first { $0.type == .sleep }
            let weakest = [hrvPillar, sleepPillar]
                .compactMap { $0 }
                .min { $0.score < $1.score }

            if weakest?.type == .hrvTrend {
                return RecoveryContext(
                    driver: "HRV",
                    reason: "Your HRV is below your recent baseline — a sign your body could use extra rest.",
                    tonightAction: "Aim for 8 hours of sleep tonight. Every hour directly rebuilds HRV.",
                    bedtimeTarget: "10 PM",
                    readinessScore: r.score
                )
            } else {
                let hrs = current.sleepHours.map { String(format: "%.1f", $0) } ?? "not enough"
                return RecoveryContext(
                    driver: "Sleep",
                    reason: "You got \(hrs) hours last night — less sleep can show up as higher RHR and lower HRV.",
                    tonightAction: "Get to bed by 10 PM tonight for a full recovery cycle.",
                    bedtimeTarget: "10 PM",
                    readinessScore: r.score
                )
            }
        }

        return HeartAssessment(
            status: status,
            confidence: confidence,
            anomalyScore: anomaly,
            regressionFlag: regression,
            stressFlag: stress,
            cardioScore: cardio,
            dailyNudge: primaryNudge,
            dailyNudges: allNudges,
            explanation: explanation,
            weekOverWeekTrend: wowTrend,
            consecutiveAlert: consecutiveAlert,
            scenario: scenario,
            recoveryTrend: recovery,
            recoveryContext: recoveryCtx
        )
    }

    // MARK: - Confidence

    /// Determine data confidence based on metric availability and history depth.
    func confidenceLevel(
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> ConfidenceLevel {
        // Count available core metrics in the current snapshot
        var metricCount = 0
        if current.restingHeartRate != nil { metricCount += 1 }
        if current.hrvSDNN != nil { metricCount += 1 }
        if current.recoveryHR1m != nil { metricCount += 1 }
        if current.recoveryHR2m != nil { metricCount += 1 }
        if current.vo2Max != nil { metricCount += 1 }

        let historyDepth = history.count

        // High: 4+ core metrics and 14+ days of history
        if metricCount >= 4 && historyDepth >= 14 {
            return .high
        }
        // Medium: 2+ core metrics and 7+ days of history
        if metricCount >= 2 && historyDepth >= 7 {
            return .medium
        }
        // Low: sparse data or short history
        return .low
    }

    // MARK: - Anomaly Score

    /// Compute a weighted composite anomaly score using robust Z-scores.
    ///
    /// Each metric's Z-score is computed against the historical baseline using
    /// median and MAD (median absolute deviation). Weights reflect clinical importance.
    /// For RHR, higher values are worse so the Z-score is used directly.
    /// For HRV, Recovery, VO2, lower values are worse so the Z-score is negated.
    func anomalyScore(
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> Double {
        guard !history.isEmpty else { return 0.0 }

        var totalWeight: Double = 0.0
        var weightedSum: Double = 0.0

        // RHR: higher is worse, so positive Z = anomalous
        if let currentRHR = current.restingHeartRate {
            let rhrValues = history.compactMap(\.restingHeartRate)
            if rhrValues.count >= 3 {
                let zScore = robustZ(value: currentRHR, baseline: rhrValues)
                // For RHR, positive Z (elevated) is bad
                weightedSum += max(zScore, 0) * weightRHR
                totalWeight += weightRHR
            }
        }

        // HRV: lower is worse, so negative Z = anomalous
        if let currentHRV = current.hrvSDNN {
            let hrvValues = history.compactMap(\.hrvSDNN)
            if hrvValues.count >= 3 {
                let zScore = robustZ(value: currentHRV, baseline: hrvValues)
                // For HRV, negative Z (depressed) is bad
                weightedSum += max(-zScore, 0) * weightHRV
                totalWeight += weightHRV
            }
        }

        // Recovery 1m: lower is worse (less recovery), negative Z = anomalous
        if let currentRec1 = current.recoveryHR1m {
            let rec1Values = history.compactMap(\.recoveryHR1m)
            if rec1Values.count >= 3 {
                let zScore = robustZ(value: currentRec1, baseline: rec1Values)
                weightedSum += max(-zScore, 0) * weightRecovery1m
                totalWeight += weightRecovery1m
            }
        }

        // Recovery 2m: lower is worse, negative Z = anomalous
        if let currentRec2 = current.recoveryHR2m {
            let rec2Values = history.compactMap(\.recoveryHR2m)
            if rec2Values.count >= 3 {
                let zScore = robustZ(value: currentRec2, baseline: rec2Values)
                weightedSum += max(-zScore, 0) * weightRecovery2m
                totalWeight += weightRecovery2m
            }
        }

        // VO2 max: lower is worse, negative Z = anomalous
        if let currentVO2 = current.vo2Max {
            let vo2Values = history.compactMap(\.vo2Max)
            if vo2Values.count >= 3 {
                let zScore = robustZ(value: currentVO2, baseline: vo2Values)
                weightedSum += max(-zScore, 0) * weightVO2
                totalWeight += weightVO2
            }
        }

        guard totalWeight > 0 else { return 0.0 }
        return weightedSum / totalWeight
    }

    // MARK: - Cardio Score

    /// Compute a composite cardio fitness score (0-100) from available metrics.
    ///
    /// Uses percentile-rank approach against population reference ranges.
    func computeCardioScore(
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> Double? {
        var components: [Double] = []

        // RHR component: 50-80 BPM range, lower is better
        if let rhr = current.restingHeartRate {
            let score = max(0, min(100, (80.0 - rhr) / 30.0 * 100.0))
            components.append(score)
        }

        // HRV component: 20-100 ms range, higher is better
        if let hrv = current.hrvSDNN {
            let score = max(0, min(100, (hrv - 20.0) / 80.0 * 100.0))
            components.append(score)
        }

        // Recovery 1m component: 10-50 BPM drop, higher is better
        if let rec1 = current.recoveryHR1m {
            let score = max(0, min(100, (rec1 - 10.0) / 40.0 * 100.0))
            components.append(score)
        }

        // VO2 max component: 20-60 mL/kg/min, higher is better
        if let vo2 = current.vo2Max {
            let score = max(0, min(100, (vo2 - 20.0) / 40.0 * 100.0))
            components.append(score)
        }

        guard !components.isEmpty else { return nil }
        return components.reduce(0.0, +) / Double(components.count)
    }

    // MARK: - Regression Detection

    /// Detect multi-day regression using linear slope over the regression window.
    ///
    /// Checks if RHR is trending up or HRV is trending down beyond thresholds.
    func detectRegression(
        history: [HeartSnapshot],
        current: HeartSnapshot
    ) -> Bool {
        let allSnapshots = history + [current]
        let recentSnapshots = Array(allSnapshots.suffix(regressionWindow))
        guard recentSnapshots.count >= 5 else { return false }

        // Check RHR trending upward (worsening)
        let rhrValues = recentSnapshots.compactMap(\.restingHeartRate)
        if rhrValues.count >= 5 {
            let slope = linearSlope(values: rhrValues)
            // Positive slope = RHR increasing = worsening
            if slope > abs(policy.regressionSlope) {
                return true
            }
        }

        // Check HRV trending downward (worsening)
        let hrvValues = recentSnapshots.compactMap(\.hrvSDNN)
        if hrvValues.count >= 5 {
            let slope = linearSlope(values: hrvValues)
            // Negative slope = HRV decreasing = worsening
            if slope < policy.regressionSlope {
                return true
            }
        }

        return false
    }

    // MARK: - Stress Pattern Detection

    /// Detect stress-like pattern: RHR elevated + HRV depressed + Recovery depressed.
    ///
    /// All three conditions must be present simultaneously.
    func detectStressPattern(
        current: HeartSnapshot,
        history: [HeartSnapshot]
    ) -> Bool {
        guard !history.isEmpty else { return false }

        var rhrElevated = false
        var hrvDepressed = false
        var recoveryDepressed = false

        // RHR elevated
        if let currentRHR = current.restingHeartRate {
            let rhrValues = history.compactMap(\.restingHeartRate)
            if rhrValues.count >= 3 {
                let zScore = robustZ(value: currentRHR, baseline: rhrValues)
                rhrElevated = zScore >= policy.stressRHRZ
            }
        }

        // HRV depressed (negative Z = below baseline)
        if let currentHRV = current.hrvSDNN {
            let hrvValues = history.compactMap(\.hrvSDNN)
            if hrvValues.count >= 3 {
                let zScore = robustZ(value: currentHRV, baseline: hrvValues)
                hrvDepressed = zScore <= policy.stressHRVZ
            }
        }

        // Recovery depressed: check 1m first, fall back to 2m
        if let currentRec = current.recoveryHR1m {
            let recValues = history.compactMap(\.recoveryHR1m)
            if recValues.count >= 3 {
                let zScore = robustZ(value: currentRec, baseline: recValues)
                recoveryDepressed = zScore <= policy.stressRecoveryZ
            }
        } else if let currentRec = current.recoveryHR2m {
            let recValues = history.compactMap(\.recoveryHR2m)
            if recValues.count >= 3 {
                let zScore = robustZ(value: currentRec, baseline: recValues)
                recoveryDepressed = zScore <= policy.stressRecoveryZ
            }
        }

        return rhrElevated && hrvDepressed && recoveryDepressed
    }

    // MARK: - Week-Over-Week Trend

    /// Compute week-over-week RHR trend using a 28-day baseline.
    ///
    /// Compares the current 7-day mean RHR against a 28-day rolling baseline.
    /// Z-score thresholds: < -1.5 significant improvement, > 1.5 significant elevation.
    func weekOverWeekTrend(
        history: [HeartSnapshot],
        current: HeartSnapshot
    ) -> WeekOverWeekTrend? {
        let allSnapshots = history + [current]
        let rhrSnapshots = allSnapshots
            .filter { $0.restingHeartRate != nil }
            .sorted { $0.date < $1.date }

        // Need at least 14 days for a meaningful baseline
        guard rhrSnapshots.count >= 14 else { return nil }

        // Split: current week (last 7) vs baseline (everything before that) (ENG-4)
        let currentWeekCount = min(7, rhrSnapshots.count)
        let baselineSnapshots = Array(rhrSnapshots.dropLast(currentWeekCount))
        guard baselineSnapshots.count >= 7 else { return nil }

        let baselineValues = baselineSnapshots.compactMap(\.restingHeartRate)
        guard baselineValues.count >= 7 else { return nil }

        let baselineMean = baselineValues.reduce(0, +) / Double(baselineValues.count)
        let baselineStd = standardDeviation(baselineValues)
        guard baselineStd > 0.5 else {
            // Essentially no variance — everything is stable
            let recentMean = currentWeekRHRMean(rhrSnapshots)
            return WeekOverWeekTrend(
                zScore: 0,
                direction: .stable,
                baselineMean: baselineMean,
                baselineStd: baselineStd,
                currentWeekMean: recentMean
            )
        }

        // Current 7-day mean (non-overlapping with baseline)
        let recentMean = currentWeekRHRMean(rhrSnapshots)
        let z = (recentMean - baselineMean) / baselineStd

        let direction: WeeklyTrendDirection
        if z < -1.5 {
            direction = .significantImprovement
        } else if z < -0.5 {
            direction = .improving
        } else if z > 1.5 {
            direction = .significantElevation
        } else if z > 0.5 {
            direction = .elevated
        } else {
            direction = .stable
        }

        return WeekOverWeekTrend(
            zScore: z,
            direction: direction,
            baselineMean: baselineMean,
            baselineStd: baselineStd,
            currentWeekMean: recentMean
        )
    }

    /// Mean RHR of the most recent 7 snapshots with RHR data.
    private func currentWeekRHRMean(_ sortedSnapshots: [HeartSnapshot]) -> Double {
        let recent = sortedSnapshots.suffix(7)
        let values = recent.compactMap(\.restingHeartRate)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Consecutive Elevation Alert

    /// Detect when RHR exceeds personal_mean + 2σ for 3+ consecutive days.
    ///
    /// Research (ARIC study) shows this pattern precedes illness onset by 1-3 days.
    func detectConsecutiveElevation(
        history: [HeartSnapshot],
        current: HeartSnapshot
    ) -> ConsecutiveElevationAlert? {
        let allSnapshots = (history + [current])
            .sorted { $0.date < $1.date }
        let rhrValues = allSnapshots.compactMap(\.restingHeartRate)
        guard rhrValues.count >= 7 else { return nil }

        let mean = rhrValues.reduce(0, +) / Double(rhrValues.count)
        let std = standardDeviation(rhrValues)
        guard std > 0.5 else { return nil }

        let threshold = mean + 2.0 * std

        // Count consecutive calendar days from the most recent snapshot backwards.
        // Uses actual date gaps (not array positions) to avoid false counts
        // when a user misses a day of wearing the device.
        var consecutiveDays = 0
        var elevatedRHRs: [Double] = []
        let reversedSnapshots = allSnapshots.reversed()
        var previousDate: Date?
        for snapshot in reversedSnapshots {
            if let rhr = snapshot.restingHeartRate, rhr > threshold {
                // Check calendar continuity — gap of more than 1.5 days breaks the streak
                if let prev = previousDate {
                    let gap = prev.timeIntervalSince(snapshot.date) / 86400.0
                    if gap > 1.5 { break }
                }
                consecutiveDays += 1
                elevatedRHRs.append(rhr)
                previousDate = snapshot.date
            } else {
                break
            }
        }

        guard consecutiveDays >= 3 else { return nil }

        let elevatedMean = elevatedRHRs.reduce(0, +) / Double(elevatedRHRs.count)

        return ConsecutiveElevationAlert(
            consecutiveDays: consecutiveDays,
            threshold: threshold,
            elevatedMean: elevatedMean,
            personalMean: mean
        )
    }

    // MARK: - Recovery Trend

    /// Analyze heart rate recovery trend (post-exercise HR drop).
    ///
    /// Compares 7-day recovery mean against 28-day baseline. Improving recovery
    /// indicates better cardiovascular fitness; declining recovery may signal
    /// overtraining or fatigue.
    func recoveryTrend(
        history: [HeartSnapshot],
        current: HeartSnapshot
    ) -> RecoveryTrend? {
        let allSnapshots = (history + [current])
            .sorted { $0.date < $1.date }
        let recSnapshots = allSnapshots.filter { $0.recoveryHR1m != nil }

        guard recSnapshots.count >= 5 else {
            return RecoveryTrend(
                direction: .insufficientData,
                currentWeekMean: nil,
                baselineMean: nil,
                zScore: nil,
                dataPoints: recSnapshots.count
            )
        }

        let allRecValues = recSnapshots.compactMap(\.recoveryHR1m)
        let baselineMean = allRecValues.reduce(0, +) / Double(allRecValues.count)
        let baselineStd = standardDeviation(allRecValues)

        // Current week (last 7 data points with recovery data)
        let recentRec = Array(recSnapshots.suffix(7))
        let recentValues = recentRec.compactMap(\.recoveryHR1m)
        guard !recentValues.isEmpty else {
            return RecoveryTrend(
                direction: .insufficientData,
                currentWeekMean: nil,
                baselineMean: baselineMean,
                zScore: nil,
                dataPoints: 0
            )
        }

        let recentMean = recentValues.reduce(0, +) / Double(recentValues.count)

        let direction: RecoveryTrendDirection
        if baselineStd > 0.5 {
            let z = (recentMean - baselineMean) / baselineStd
            // For recovery, higher is better (more HR drop post-exercise)
            if z > 1.0 {
                direction = .improving
            } else if z < -1.0 {
                direction = .declining
            } else {
                direction = .stable
            }
            return RecoveryTrend(
                direction: direction,
                currentWeekMean: recentMean,
                baselineMean: baselineMean,
                zScore: z,
                dataPoints: recentValues.count
            )
        } else {
            direction = .stable
            return RecoveryTrend(
                direction: direction,
                currentWeekMean: recentMean,
                baselineMean: baselineMean,
                zScore: 0,
                dataPoints: recentValues.count
            )
        }
    }

    // MARK: - Scenario Detection

    /// Detect which coaching scenario best matches today's metrics.
    ///
    /// Scenarios are mutually exclusive — returns the highest priority match.
    /// Priority: overtraining > high stress > great recovery > missing activity > trends.
    func detectScenario(
        history: [HeartSnapshot],
        current: HeartSnapshot
    ) -> CoachingScenario? {
        let allSnapshots = history + [current]
        let rhrValues = history.compactMap(\.restingHeartRate)
        let hrvValues = history.compactMap(\.hrvSDNN)

        // --- Overtraining signals ---
        // RHR +7bpm for 3+ days AND HRV -20% persistent
        if rhrValues.count >= 7 && hrvValues.count >= 7 {
            let rhrMean = rhrValues.reduce(0, +) / Double(rhrValues.count)
            let hrvMean = hrvValues.reduce(0, +) / Double(hrvValues.count)

            // Check last 3 days for elevated RHR
            let recentSnapshots = Array(allSnapshots.suffix(3))
            let recentRHR = recentSnapshots.compactMap(\.restingHeartRate)
            let recentHRV = recentSnapshots.compactMap(\.hrvSDNN)

            if recentRHR.count >= 3 && recentHRV.count >= 3 {
                let allElevated = recentRHR.allSatisfy { $0 > rhrMean + 7.0 }
                let hrvDepressed = recentHRV.allSatisfy { $0 < hrvMean * 0.80 }
                if allElevated && hrvDepressed {
                    return .overtrainingSignals
                }
            }
        }

        // --- High stress day ---
        // HRV >15% below avg AND/OR RHR >5bpm above avg
        if let currentHRV = current.hrvSDNN, let currentRHR = current.restingHeartRate {
            let hrvMean = hrvValues.isEmpty ? currentHRV :
                hrvValues.reduce(0, +) / Double(hrvValues.count)
            let rhrMean = rhrValues.isEmpty ? currentRHR :
                rhrValues.reduce(0, +) / Double(rhrValues.count)

            let hrvBelow = currentHRV < hrvMean * 0.85
            let rhrAbove = currentRHR > rhrMean + 5.0

            if hrvBelow && rhrAbove {
                return .highStressDay
            }
        }

        // --- Great recovery day ---
        // HRV >10% above avg, RHR at/below baseline
        if let currentHRV = current.hrvSDNN, let currentRHR = current.restingHeartRate {
            let hrvMean = hrvValues.isEmpty ? currentHRV :
                hrvValues.reduce(0, +) / Double(hrvValues.count)
            let rhrMean = rhrValues.isEmpty ? currentRHR :
                rhrValues.reduce(0, +) / Double(rhrValues.count)

            if currentHRV > hrvMean * 1.10 && currentRHR <= rhrMean {
                return .greatRecoveryDay
            }
        }

        // --- Missing activity ---
        // No workout for 2+ consecutive days
        let recentTwo = Array(allSnapshots.suffix(2))
        if recentTwo.count >= 2 {
            let noActivity = recentTwo.allSatisfy {
                ($0.workoutMinutes ?? 0) < 5 && ($0.steps ?? 0) < 2000
            }
            if noActivity {
                return .missingActivity
            }
        }

        // --- Improving trend ---
        // 7-day rolling avg improving for 2+ weeks (need 14+ days)
        if let wowTrend = weekOverWeekTrend(history: history, current: current) {
            if wowTrend.direction == .significantImprovement || wowTrend.direction == .improving {
                // Verify it's a sustained multi-week improvement using slope
                let rhrRecent14 = allSnapshots.suffix(14).compactMap(\.restingHeartRate)
                if rhrRecent14.count >= 10 {
                    let slope = linearSlope(values: rhrRecent14)
                    if slope < -0.15 { // RHR declining at > 0.15 bpm/day
                        return .improvingTrend
                    }
                }
            }

            // --- Declining trend ---
            if wowTrend.direction == .significantElevation || wowTrend.direction == .elevated {
                let rhrRecent14 = allSnapshots.suffix(14).compactMap(\.restingHeartRate)
                if rhrRecent14.count >= 10 {
                    let slope = linearSlope(values: rhrRecent14)
                    if slope > 0.15 { // RHR increasing at > 0.15 bpm/day
                        return .decliningTrend
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Status Determination

    /// Map computed signals into a single TrendStatus.
    private func determineStatus(
        anomaly: Double,
        regression: Bool,
        stress: Bool,
        confidence: ConfidenceLevel,
        consecutiveAlert: ConsecutiveElevationAlert? = nil,
        weekTrend: WeekOverWeekTrend? = nil
    ) -> TrendStatus {
        // Needs attention: high anomaly, regression, stress, consecutive alert,
        // or significant weekly elevation
        if anomaly >= policy.anomalyHigh || regression || stress {
            return .needsAttention
        }
        if consecutiveAlert != nil {
            return .needsAttention
        }
        if let wt = weekTrend, wt.direction == .significantElevation {
            return .needsAttention
        }
        // Improving: low anomaly and reasonable confidence,
        // or significant weekly improvement
        if let wt = weekTrend,
           (wt.direction == .significantImprovement || wt.direction == .improving),
           confidence != .low {
            return .improving
        }
        if anomaly < 0.5 && confidence != .low {
            return .improving
        }
        return .stable
    }

    // MARK: - Explanation Builder

    /// Build a human-readable explanation string.
    private func buildExplanation(
        status: TrendStatus,
        confidence: ConfidenceLevel,
        anomaly: Double,
        regression: Bool,
        stress: Bool,
        cardio: Double?,
        wowTrend: WeekOverWeekTrend? = nil,
        consecutiveAlert: ConsecutiveElevationAlert? = nil,
        scenario: CoachingScenario? = nil,
        recovery: RecoveryTrend? = nil
    ) -> String {
        var parts: [String] = []

        switch status {
        case .improving:
            parts.append(
                "Your heart metrics are trending in a positive direction."
            )
        case .stable:
            parts.append(
                "Your heart metrics are within your normal range."
            )
        case .needsAttention:
            parts.append(
                "Some of your heart metrics have shifted from your usual baseline."
            )
        }

        if regression {
            parts.append(
                "A gradual shift has been observed over the past several days."
            )
        }

        if stress {
            parts.append(
                "A pattern suggesting your heart is working harder than usual was noticed today. " +
                "A lighter day might help you feel better."
            )
        }

        // Week-over-week insight
        if let wt = wowTrend {
            switch wt.direction {
            case .significantImprovement, .improving:
                parts.append(wt.direction.displayText + ".")
            case .significantElevation, .elevated:
                parts.append(wt.direction.displayText + ".")
            case .stable:
                break // Don't clutter with "stable" when already said "normal range"
            }
        }

        // Consecutive elevation alert
        if let alert = consecutiveAlert {
            parts.append(
                "Your resting heart rate has been elevated for \(alert.consecutiveDays) " +
                "consecutive days. This sometimes precedes feeling under the weather."
            )
        }

        // Recovery trend
        if let rec = recovery {
            switch rec.direction {
            case .improving:
                parts.append(rec.direction.displayText + ".")
            case .declining:
                parts.append(rec.direction.displayText + ".")
            case .stable, .insufficientData:
                break
            }
        }

        // Coaching scenario
        if let scenario = scenario {
            parts.append(scenario.coachingMessage)
        }

        if let score = cardio {
            parts.append(
                String(format: "Your estimated cardio fitness score is %.0f out of 100.", score)
            )
        }

        switch confidence {
        case .high:
            parts.append("This assessment is based on comprehensive data.")
        case .medium:
            parts.append(
                "This assessment uses partial data. " +
                "More consistent wear will improve accuracy."
            )
        case .low:
            parts.append(
                "Limited data is available. " +
                "Wearing your watch consistently will help build a reliable baseline."
            )
        }

        return parts.joined(separator: " ")
    }

    // MARK: - History Helpers

    /// Extract the most recent `lookbackWindow` days from the history.
    private func recentHistory(from history: [HeartSnapshot]) -> [HeartSnapshot] {
        Array(history.suffix(lookbackWindow))
    }

    // MARK: - Statistical Helpers (Internal for Testing)

    /// Compute a robust Z-score using median and MAD.
    ///
    /// MAD (median absolute deviation) is scaled by 1.4826 to approximate the
    /// standard deviation for normally distributed data.
    func robustZ(value: Double, baseline: [Double]) -> Double {
        let med = median(baseline)
        let madValue = mad(baseline)
        guard madValue > 0 else {
            // If MAD is zero, all baseline values are the same.
            // Return the raw deviation clamped to a reasonable range.
            let diff = value - med
            if abs(diff) < 1e-9 { return 0.0 }
            return diff > 0 ? 3.0 : -3.0
        }
        return (value - med) / madValue
    }

    /// Compute the linear slope of a sequence of equally-spaced values.
    ///
    /// Uses ordinary least squares. Returns slope per unit step.
    func linearSlope(values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0.0 }

        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumXX: Double = 0

        for (i, y) in values.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += y
            sumXY += x * y
            sumXX += x * x
        }

        let denominator = n * sumXX - sumX * sumX
        guard abs(denominator) > 1e-12 else { return 0.0 }
        return (n * sumXY - sumX * sumY) / denominator
    }

    /// Compute the median of an array of doubles.
    func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sorted = values.sorted()
        let count = sorted.count
        if count.isMultiple(of: 2) {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        }
        return sorted[count / 2]
    }

    /// Compute the MAD (median absolute deviation) scaled by 1.4826.
    func mad(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let med = median(values)
        let deviations = values.map { abs($0 - med) }
        return median(deviations) * 1.4826
    }

    /// Compute sample standard deviation.
    func standardDeviation(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0.0 }
        let mean = values.reduce(0, +) / n
        let sumSquares = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
        return (sumSquares / (n - 1)).squareRoot()
    }
}

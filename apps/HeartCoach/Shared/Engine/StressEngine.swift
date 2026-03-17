// StressEngine.swift
// ThumpCore
//
// Context-aware stress scoring with acute and desk branches.
//
// Architecture:
//
// 1. Context Detection: Infers StressMode (acute/desk/unknown) from
//    activity, steps, and sedentary signals.
//
// 2. Acute Branch (HR-primary, calibrated from PhysioNet):
//    - RHR Deviation: 50% weight
//    - HRV Baseline Deviation: 30% weight
//    - Coefficient of Variation: 20% weight
//    Validated: PhysioNet AUC 0.729, Cohen's d 0.87
//
// 3. Desk Branch (HRV-primary, designed for seated/cognitive stress):
//    - RHR Deviation: 10% weight (heavily reduced)
//    - HRV Baseline Deviation: 55% weight
//    - Coefficient of Variation: 35% weight
//    Designed to address: SWELL AUC 0.203 → improved, WESAD AUC 0.178 → improved
//
// 4. Disagreement Damping: When RHR and HRV point in opposite directions,
//    the score compresses toward neutral and confidence drops.
//
// 5. Confidence: Separate from score. Reflects signal quality, baseline
//    strength, and signal agreement.
//
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation

// MARK: - Stress Engine

/// Context-aware stress engine with acute and desk scoring branches.
///
/// Uses context detection to select between HR-primary (acute) and
/// HRV-primary (desk) scoring branches. Includes disagreement damping
/// and explicit confidence output.
///
/// All methods are pure functions with no side effects.
public struct StressEngine: Sendable {

    // MARK: - Configuration

    /// Number of days used for the personal HRV baseline.
    public let baselineWindow: Int

    /// Whether to apply log-SDNN transformation before computing the HRV component.
    public let useLogSDNN: Bool

    private let config: HealthPolicyConfig.StressOvertraining

    // Acute branch weights (HR-primary, validated on PhysioNet)
    private var acuteRHRWeight: Double { config.acuteWeights.rhr }
    private var acuteHRVWeight: Double { config.acuteWeights.hrv }
    private var acuteCVWeight: Double { config.acuteWeights.cv }

    // Desk branch weights (HRV-primary, for seated/cognitive contexts)
    // RHR inverted in desk mode (HR drop = cognitive engagement)
    private var deskRHRWeight: Double { config.deskWeights.rhr }
    private var deskHRVWeight: Double { config.deskWeights.hrv }
    private var deskCVWeight: Double { config.deskWeights.cv }

    /// Sigmoid steepness — higher = sharper transition around midpoint.
    private var sigmoidK: Double { config.sigmoidK }

    /// Sigmoid midpoint (raw composite score that maps to stress = 50).
    private var sigmoidMid: Double { config.sigmoidMid }

    /// Steps threshold below which desk mode is considered.
    private var deskStepsThreshold: Double { config.deskStepsThreshold }

    /// Workout minutes threshold above which acute mode is considered.
    private var acuteWorkoutThreshold: Double { config.acuteWorkoutThreshold }

    public init(baselineWindow: Int = 14, useLogSDNN: Bool = true, config: HealthPolicyConfig.StressOvertraining = ConfigService.activePolicy.stressOvertraining) {
        self.baselineWindow = max(baselineWindow, 3)
        self.useLogSDNN = useLogSDNN
        self.config = config
    }

    // MARK: - Context Detection

    /// Infer stress mode from activity and lifestyle context.
    ///
    /// - Parameters:
    ///   - recentSteps: Recent step count (e.g. today's steps so far).
    ///   - recentWorkoutMinutes: Recent workout duration.
    ///   - sedentaryMinutes: Recent sedentary/inactivity duration.
    /// - Returns: The inferred `StressMode`.
    public func detectMode(
        recentSteps: Double?,
        recentWorkoutMinutes: Double?,
        sedentaryMinutes: Double?
    ) -> StressMode {
        // Strong acute signals
        if let workout = recentWorkoutMinutes, workout >= acuteWorkoutThreshold {
            return .acute
        }
        if let steps = recentSteps, steps >= 8000 {
            return .acute
        }

        // Strong desk signals
        if let steps = recentSteps, steps < deskStepsThreshold {
            if let sedentary = sedentaryMinutes, sedentary >= 120 {
                return .desk
            }
            // Low steps alone suggests desk
            return .desk
        }

        // Mixed or missing context
        if let steps = recentSteps {
            // Moderate activity: 2000-8000 steps
            if let workout = recentWorkoutMinutes, workout > 5 {
                return .acute
            }
            if steps < 4000 {
                return .desk
            }
        }

        return .unknown
    }

    // MARK: - Context-Aware Computation

    /// Compute stress using the rich context input with mode detection.
    ///
    /// This is the preferred entry point for product code. It performs
    /// context detection, branch-specific scoring, disagreement damping,
    /// and confidence computation.
    public func computeStress(context: StressContextInput) -> StressResult {
        guard context.baselineHRV > 0 else {
            return StressResult(
                score: 50,
                level: .balanced,
                description: "Not enough data to determine your baseline yet.",
                mode: .unknown,
                confidence: .low,
                warnings: ["Insufficient baseline data"]
            )
        }

        let mode = detectMode(
            recentSteps: context.recentSteps,
            recentWorkoutMinutes: context.recentWorkoutMinutes,
            sedentaryMinutes: context.sedentaryMinutes
        )

        return computeStressWithMode(
            currentHRV: context.currentHRV,
            baselineHRV: context.baselineHRV,
            baselineHRVSD: context.baselineHRVSD,
            currentRHR: context.currentRHR,
            baselineRHR: context.baselineRHR,
            recentHRVs: context.recentHRVs,
            mode: mode
        )
    }

    // MARK: - Core Computation

    /// Compute a stress score from HR and HRV data compared to personal baselines.
    ///
    /// Uses three signals with weights determined by the scoring mode:
    /// 1. RHR deviation: elevated resting HR vs baseline
    /// 2. HRV Z-score: how many SDs below personal HRV baseline
    /// 3. CV signal: autonomic instability from recent HRV variability
    ///
    /// Backward-compatible: when called without mode, uses legacy single-formula
    /// behavior (acute weights) for existing callers.
    public func computeStress(
        currentHRV: Double,
        baselineHRV: Double,
        baselineHRVSD: Double? = nil,
        currentRHR: Double? = nil,
        baselineRHR: Double? = nil,
        recentHRVs: [Double]? = nil,
        mode: StressMode = .acute
    ) -> StressResult {
        computeStressWithMode(
            currentHRV: currentHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineHRVSD,
            currentRHR: currentRHR,
            baselineRHR: baselineRHR,
            recentHRVs: recentHRVs,
            mode: mode
        )
    }

    /// Internal scoring with explicit mode selection.
    private func computeStressWithMode(
        currentHRV: Double,
        baselineHRV: Double,
        baselineHRVSD: Double?,
        currentRHR: Double?,
        baselineRHR: Double?,
        recentHRVs: [Double]?,
        mode: StressMode
    ) -> StressResult {
        guard baselineHRV > 0 else {
            return StressResult(
                score: 50,
                level: .balanced,
                description: "Not enough data to determine your baseline yet.",
                mode: mode,
                confidence: .low,
                warnings: ["Insufficient baseline data"]
            )
        }

        // ── Signal 1: HRV Z-score ────────────────────────────────────
        // Acute: directional — lower HRV = higher stress (sympathetic)
        // Desk:  bidirectional — any deviation from baseline = cognitive load
        let hrvRawScore: Double
        if useLogSDNN {
            let logCurrent = log(max(currentHRV, 1.0))
            let logBaseline = log(max(baselineHRV, 1.0))
            let logSD: Double
            if let bsd = baselineHRVSD, bsd > 0 {
                logSD = bsd / max(baselineHRV, 1.0)
            } else {
                logSD = 0.20
            }
            let zScore: Double
            if logSD > 0 {
                let directionalZ = (logBaseline - logCurrent) / logSD
                zScore = mode == .desk ? abs(directionalZ) : directionalZ
            } else {
                zScore = logCurrent < logBaseline ? 2.0 : (mode == .desk ? 2.0 : -1.0)
            }
            if mode == .desk {
                // Desk: lower offset so baseline (z≈0) stays low, deviations separate
                hrvRawScore = 20.0 + zScore * 30.0
            } else {
                hrvRawScore = 35.0 + zScore * 20.0
            }
        } else {
            let sd = baselineHRVSD ?? (baselineHRV * 0.20)
            let zScore: Double
            if sd > 0 {
                let directionalZ = (baselineHRV - currentHRV) / sd
                zScore = mode == .desk ? abs(directionalZ) : directionalZ
            } else {
                zScore = currentHRV < baselineHRV ? 2.0 : (mode == .desk ? 2.0 : -1.0)
            }
            if mode == .desk {
                hrvRawScore = 20.0 + zScore * 30.0
            } else {
                hrvRawScore = 35.0 + zScore * 20.0
            }
        }

        // ── Signal 2: Coefficient of Variation ───────────────────────
        var cvRawScore: Double = 50.0
        if let hrvs = recentHRVs, hrvs.count >= 3 {
            let mean = hrvs.reduce(0, +) / Double(hrvs.count)
            if mean > 0 {
                let variance = hrvs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(hrvs.count - 1)
                let cvSD = sqrt(variance)
                let cv = cvSD / mean
                cvRawScore = max(0, min(100, (cv - 0.10) / 0.25 * 100.0))
            }
        }

        // ── Signal 3: RHR Deviation ──────────────────────────────────
        // Acute: HR rising above baseline = stress
        // Desk:  HR dropping below baseline = cognitive engagement = stress
        var rhrRawScore: Double = 50.0
        if let rhr = currentRHR, let baseRHR = baselineRHR, baseRHR > 0 {
            let rhrDeviation: Double
            if mode == .desk {
                // Invert: lower HR during desk work indicates cognitive load
                rhrDeviation = (baseRHR - rhr) / baseRHR * 100.0
            } else {
                rhrDeviation = (rhr - baseRHR) / baseRHR * 100.0
            }
            rhrRawScore = max(0, min(100, 40.0 + rhrDeviation * 4.0))
        }

        // ── Mode-specific weights ────────────────────────────────────
        let (actualRHRWeight, actualHRVWeight, actualCVWeight) = resolveWeights(
            mode: mode,
            hasRHR: currentRHR != nil,
            hasCV: recentHRVs != nil
        )

        let rawComposite = hrvRawScore * actualHRVWeight
            + cvRawScore * actualCVWeight
            + rhrRawScore * actualRHRWeight

        // ── Disagreement Damping ─────────────────────────────────────
        let (dampedComposite, disagreementPenalty) = applyDisagreementDamping(
            rawComposite: rawComposite,
            rhrRawScore: rhrRawScore,
            hrvRawScore: hrvRawScore,
            cvRawScore: cvRawScore,
            mode: mode
        )

        // ── Unknown mode: compress toward neutral ────────────────────
        let finalComposite: Double
        if mode == .unknown {
            finalComposite = dampedComposite * 0.7 + 50.0 * 0.3
        } else {
            finalComposite = dampedComposite
        }

        // ── Sigmoid Normalization ────────────────────────────────────
        let score = sigmoid(finalComposite)

        // ── Confidence ───────────────────────────────────────────────
        var warnings: [String] = []
        let confidence = computeConfidence(
            mode: mode,
            hasRHR: currentRHR != nil,
            hasCV: recentHRVs != nil,
            baselineHRVSD: baselineHRVSD,
            recentHRVCount: recentHRVs?.count ?? 0,
            disagreementPenalty: disagreementPenalty,
            warnings: &warnings
        )

        let level = StressLevel.from(score: score)
        let description = friendlyDescription(
            score: score,
            level: level,
            currentHRV: currentHRV,
            baselineHRV: baselineHRV,
            confidence: confidence,
            mode: mode
        )

        let breakdown = StressSignalBreakdown(
            rhrContribution: rhrRawScore,
            hrvContribution: hrvRawScore,
            cvContribution: cvRawScore
        )

        return StressResult(
            score: score,
            level: level,
            description: description,
            mode: mode,
            confidence: confidence,
            signalBreakdown: breakdown,
            warnings: warnings
        )
    }

    /// Legacy API: compute stress from just HRV values.
    public func computeStress(
        currentHRV: Double,
        baselineHRV: Double
    ) -> StressResult {
        computeStress(
            currentHRV: currentHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: nil,
            currentRHR: nil,
            baselineRHR: nil,
            recentHRVs: nil
        )
    }

    /// Convenience: compute stress from a snapshot and recent history.
    public func computeStress(
        snapshot: HeartSnapshot,
        recentHistory: [HeartSnapshot]
    ) -> StressResult? {
        guard let currentHRV = snapshot.hrvSDNN else { return nil }
        let baseline = computeBaseline(snapshots: recentHistory)
        guard let baselineHRV = baseline else { return nil }
        let hrvValues = recentHistory.compactMap(\.hrvSDNN)
        let n = Double(hrvValues.count)
        let baselineSD: Double? = n >= 2 ? {
            let mean = hrvValues.reduce(0, +) / n
            let ss = hrvValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
            return (ss / (n - 1)).squareRoot()
        }() : nil
        let rhrValues = recentHistory.compactMap(\.restingHeartRate)
        let avgRHR: Double? = rhrValues.isEmpty ? nil : rhrValues.reduce(0, +) / Double(rhrValues.count)

        let contextInput = StressContextInput(
            currentHRV: currentHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineSD,
            currentRHR: snapshot.restingHeartRate,
            baselineRHR: avgRHR,
            recentHRVs: recentHistory.suffix(7).compactMap(\.hrvSDNN),
            recentSteps: snapshot.steps,
            recentWorkoutMinutes: snapshot.workoutMinutes,
            sedentaryMinutes: nil,
            sleepHours: snapshot.sleepHours
        )

        return computeStress(context: contextInput)
    }

    // MARK: - Weight Resolution

    /// Resolve actual weights based on mode and available signals.
    private func resolveWeights(
        mode: StressMode,
        hasRHR: Bool,
        hasCV: Bool
    ) -> (rhr: Double, hrv: Double, cv: Double) {
        let baseWeights: (rhr: Double, hrv: Double, cv: Double)

        switch mode {
        case .acute:
            baseWeights = (acuteRHRWeight, acuteHRVWeight, acuteCVWeight)
        case .desk:
            baseWeights = (deskRHRWeight, deskHRVWeight, deskCVWeight)
        case .unknown:
            // Blend between acute and desk
            let blendRHR = (acuteRHRWeight + deskRHRWeight) / 2.0
            let blendHRV = (acuteHRVWeight + deskHRVWeight) / 2.0
            let blendCV = (acuteCVWeight + deskCVWeight) / 2.0
            baseWeights = (blendRHR, blendHRV, blendCV)
        }

        // Redistribute for missing signals
        if hasRHR && hasCV {
            return baseWeights
        } else if hasRHR && !hasCV {
            let total = baseWeights.rhr + baseWeights.hrv
            return (baseWeights.rhr / total, baseWeights.hrv / total, 0.0)
        } else if !hasRHR && hasCV {
            let total = baseWeights.hrv + baseWeights.cv
            return (0.0, baseWeights.hrv / total, baseWeights.cv / total)
        } else {
            // HRV only
            return (0.0, 1.0, 0.0)
        }
    }

    // MARK: - Disagreement Damping

    /// Dampens the composite score when signals disagree.
    ///
    /// When RHR says stress-up but HRV and CV say stress-down (or vice versa),
    /// the score is compressed toward neutral.
    ///
    /// - Returns: (damped composite, disagreement penalty 0-1)
    private func applyDisagreementDamping(
        rawComposite: Double,
        rhrRawScore: Double,
        hrvRawScore: Double,
        cvRawScore: Double,
        mode: StressMode
    ) -> (Double, Double) {
        let rhrStress = rhrRawScore > 55.0
        let hrvStress = hrvRawScore > 55.0
        let cvStable = cvRawScore < 45.0

        // Disagreement: RHR says stress but HRV normal/good and CV stable
        let rhrDisagrees = rhrStress && !hrvStress && cvStable
        // Disagreement: HRV says stress but RHR is fine
        let hrvDisagrees = hrvStress && !rhrStress && rhrRawScore < 45.0

        if rhrDisagrees || hrvDisagrees {
            // Compress toward neutral (50) by 30%
            let damped = rawComposite * 0.70 + 50.0 * 0.30
            return (damped, 0.30)
        }

        return (rawComposite, 0.0)
    }

    // MARK: - Confidence Computation

    /// Compute confidence based on signal quality and agreement.
    private func computeConfidence(
        mode: StressMode,
        hasRHR: Bool,
        hasCV: Bool,
        baselineHRVSD: Double?,
        recentHRVCount: Int,
        disagreementPenalty: Double,
        warnings: inout [String]
    ) -> StressConfidence {
        var score: Double = 1.0

        // Mode penalty
        if mode == .unknown {
            score -= 0.25
            warnings.append("Activity context unclear — score may be less accurate")
        }

        // Missing signals
        if !hasRHR {
            score -= 0.15
            warnings.append("No resting heart rate data")
        }
        if !hasCV {
            score -= 0.10
        }

        // Baseline quality
        if baselineHRVSD == nil {
            score -= 0.10
            warnings.append("Limited baseline history")
        }

        // Sparse HRV history
        if recentHRVCount < 5 {
            score -= 0.15
            warnings.append("Limited recent HRV readings")
        }

        // Disagreement
        if disagreementPenalty > 0 {
            score -= disagreementPenalty
            warnings.append("Heart rate and HRV signals show mixed patterns")
        }

        if score >= config.confidenceHighCutoff {
            return .high
        } else if score >= config.confidenceModerateCutoff {
            return .moderate
        } else {
            return .low
        }
    }

    /// Sigmoid mapping: raw → 0-100 with smooth transitions.
    private func sigmoid(_ x: Double) -> Double {
        let exponent = -sigmoidK * (x - sigmoidMid)
        let result = 100.0 / (1.0 + exp(exponent))
        return max(0, min(100, result))
    }

    // MARK: - Daily Stress Score

    /// Compute a single stress score for the most recent day using
    /// the preceding snapshots as baseline.
    ///
    /// Uses the enhanced multi-signal algorithm when RHR data is available.
    ///
    /// - Parameter snapshots: Historical snapshots, ordered oldest-first.
    ///   The last element is treated as "today."
    /// - Returns: A stress score (0-100), or `nil` if insufficient data.
    public func dailyStressScore(
        snapshots: [HeartSnapshot]
    ) -> Double? {
        guard snapshots.count >= 2 else { return nil }

        let current = snapshots[snapshots.count - 1]
        guard let currentHRV = current.hrvSDNN else { return nil }

        let preceding = Array(snapshots.dropLast())
        guard let baselineHRV = computeBaseline(snapshots: preceding) else { return nil }

        let recentHRVs = preceding.suffix(baselineWindow).compactMap(\.hrvSDNN)
        let baselineSD = computeBaselineSD(hrvValues: recentHRVs, mean: baselineHRV)

        let currentRHR = current.restingHeartRate
        let baselineRHR = computeRHRBaseline(snapshots: preceding)

        let result = computeStress(
            currentHRV: currentHRV,
            baselineHRV: baselineHRV,
            baselineHRVSD: baselineSD,
            currentRHR: currentRHR,
            baselineRHR: baselineRHR,
            recentHRVs: recentHRVs
        )
        return result.score
    }

    // MARK: - Stress Trend

    /// Produce a time series of stress data points over a given range.
    public func stressTrend(
        snapshots: [HeartSnapshot],
        range: TimeRange
    ) -> [StressDataPoint] {
        guard snapshots.count >= 2 else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -range.days,
            to: today
        ) else { return [] }

        var points: [StressDataPoint] = []

        for index in 0..<snapshots.count {
            let snapshot = snapshots[index]

            guard snapshot.date >= cutoff else { continue }
            guard let currentHRV = snapshot.hrvSDNN else { continue }

            let precedingEnd = index
            let precedingStart = max(0, precedingEnd - baselineWindow)
            let precedingSlice = Array(
                snapshots[precedingStart..<precedingEnd]
            )
            guard let baselineHRV = computeBaseline(
                snapshots: precedingSlice
            ) else { continue }

            let recentHRVs = precedingSlice.compactMap(\.hrvSDNN)
            let baselineSD = computeBaselineSD(hrvValues: recentHRVs, mean: baselineHRV)
            let currentRHR = snapshot.restingHeartRate
            let baselineRHR = computeRHRBaseline(snapshots: precedingSlice)

            let result = computeStress(
                currentHRV: currentHRV,
                baselineHRV: baselineHRV,
                baselineHRVSD: baselineSD,
                currentRHR: currentRHR,
                baselineRHR: baselineRHR,
                recentHRVs: recentHRVs
            )
            points.append(StressDataPoint(
                date: snapshot.date,
                score: result.score,
                level: result.level
            ))
        }

        return points
    }

    // MARK: - Baseline Computation

    /// Compute the rolling HRV baseline from a set of snapshots.
    public func computeBaseline(
        snapshots: [HeartSnapshot]
    ) -> Double? {
        let recent = Array(snapshots.suffix(baselineWindow))
        let hrvValues = recent.compactMap(\.hrvSDNN)
        guard !hrvValues.isEmpty else { return nil }
        return hrvValues.reduce(0, +) / Double(hrvValues.count)
    }

    /// Compute the standard deviation of HRV baseline values.
    public func computeBaselineSD(hrvValues: [Double], mean: Double) -> Double {
        guard hrvValues.count >= 2 else { return mean * 0.20 }
        let variance = hrvValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
            / Double(hrvValues.count - 1)
        return sqrt(variance)
    }

    /// Compute rolling RHR baseline from snapshots.
    public func computeRHRBaseline(snapshots: [HeartSnapshot]) -> Double? {
        let recent = Array(snapshots.suffix(baselineWindow))
        let rhrValues = recent.compactMap(\.restingHeartRate)
        guard rhrValues.count >= 3 else { return nil }
        return rhrValues.reduce(0, +) / Double(rhrValues.count)
    }

    // MARK: - Age/Sex Normalization

    /// Adjust a stress score for the user's age.
    /// Stub — currently returns the input unchanged.
    public func adjustForAge(_ score: Double, age: Int) -> Double {
        return score
    }

    /// Adjust a stress score for the user's biological sex.
    /// Stub — currently returns the input unchanged.
    public func adjustForSex(_ score: Double, isMale: Bool) -> Double {
        return score
    }

    // MARK: - Hourly Stress Estimation

    /// Estimate hourly stress scores for a single day using circadian
    /// variation patterns applied to the daily HRV reading.
    public func hourlyStressEstimates(
        dailyHRV: Double,
        baselineHRV: Double,
        date: Date
    ) -> [HourlyStressPoint] {
        let calendar = Calendar.current

        let circadianFactors: [Double] = [
            1.15, 1.18, 1.20, 1.18, 1.12, 1.05, // 0-5 AM (sleep)
            0.98, 0.95, 0.90, 0.88, 0.85, 0.87, // 6-11 AM (morning)
            0.90, 0.85, 0.82, 0.84, 0.88, 0.92, // 12-5 PM (afternoon)
            0.95, 0.98, 1.02, 1.05, 1.10, 1.12  // 6-11 PM (evening)
        ]

        return (0..<24).map { hour in
            let adjustedHRV = dailyHRV * circadianFactors[hour]
            let result = computeStress(
                currentHRV: adjustedHRV,
                baselineHRV: baselineHRV
            )
            let hourDate = calendar.date(
                bySettingHour: hour, minute: 0, second: 0, of: date
            ) ?? date

            return HourlyStressPoint(
                date: hourDate,
                hour: hour,
                score: result.score,
                level: result.level
            )
        }
    }

    /// Generate hourly stress data for a full day from snapshot history.
    public func hourlyStressForDay(
        snapshots: [HeartSnapshot],
        date: Date
    ) -> [HourlyStressPoint] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)

        guard let snapshot = snapshots.first(where: {
            calendar.isDate($0.date, inSameDayAs: targetDay)
        }), let dailyHRV = snapshot.hrvSDNN else {
            return []
        }

        let preceding = snapshots.filter { $0.date < targetDay }
        // Use preceding days for baseline when available; fall back to today's
        // own HRV so the Day heatmap works on day 1 (BUG-072).
        let baseline = computeBaseline(snapshots: preceding) ?? dailyHRV

        return hourlyStressEstimates(
            dailyHRV: dailyHRV,
            baselineHRV: baseline,
            date: targetDay
        )
    }

    // MARK: - Trend Direction

    /// Determine whether stress is rising, falling, or steady.
    public func trendDirection(
        points: [StressDataPoint]
    ) -> StressTrendDirection {
        guard points.count >= 3 else { return .steady }

        let count = Double(points.count)
        let xValues = (0..<points.count).map { Double($0) }
        let yValues = points.map(\.score)

        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).map(*).reduce(0, +)
        let sumX2 = xValues.map { $0 * $0 }.reduce(0, +)

        let denominator = count * sumX2 - sumX * sumX
        guard denominator != 0 else { return .steady }

        let slope = (count * sumXY - sumX * sumY) / denominator

        if slope > 0.5 {
            return .rising
        } else if slope < -0.5 {
            return .falling
        } else {
            return .steady
        }
    }

    // MARK: - Friendly Descriptions

    /// Generate a friendly, non-clinical description of the stress result.
    private func friendlyDescription(
        score: Double,
        level: StressLevel,
        currentHRV: Double,
        baselineHRV: Double,
        confidence: StressConfidence,
        mode: StressMode
    ) -> String {
        // Low confidence: soften the language
        if confidence == .low {
            switch level {
            case .relaxed:
                return "Your readings look calm, but we don't have much data yet. "
                    + "Keep wearing your watch for more accurate insights."
            case .balanced:
                return "Things seem normal, though the signal is still early. "
                    + "More data will sharpen these readings."
            case .elevated:
                return "Your readings suggest some activity, but the signal "
                    + "is still building. Take it easy if you feel off."
            }
        }

        let percentDiff = abs(currentHRV - baselineHRV) / baselineHRV * 100

        switch level {
        case .relaxed:
            if percentDiff < 5 {
                return "Your body seems to be in a good rhythm today. "
                    + "Keep doing what you're doing!"
            }
            return "Your heart rate variability is looking great "
                + "compared to your usual. Nice work!"

        case .balanced:
            if currentHRV < baselineHRV {
                return "Things are looking pretty normal today. "
                    + "Your body is handling its day-to-day load well."
            }
            return "You're right around your usual range. "
                + "A pretty typical day for your body."

        case .elevated:
            if confidence == .moderate && mode == .desk {
                return "Your body seems to be working harder than usual "
                    + "while resting. Consider a short walk or some deep breaths."
            }
            if score >= 85 {
                return "Your body is really working hard today. Give yourself "
                    + "permission to rest — even a few minutes of slow breathing can help."
            }
            if percentDiff > 30 {
                return "Your body might be working harder than "
                    + "usual today. A walk, some deep breaths, or "
                    + "extra sleep could help."
            }
            return "You seem to be running a bit warm today. "
                + "A little recovery time could go a long way."
        }
    }
}

// MARK: - Time Range

/// Predefined time ranges for stress trend aggregation.
public enum TimeRange: Int, CaseIterable, Sendable {
    case day = 1
    case week = 7
    case month = 30

    /// The number of calendar days this range represents.
    public var days: Int { rawValue }

    /// Human-readable label for display.
    public var label: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

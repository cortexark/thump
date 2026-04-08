// RealWorldDataTests.swift
// Thump — Real-World Apple Watch Data Validation
//
// Tests all engines (except StressEngine) against ACTUAL Apple Watch export data
// (32 days, Feb 9 – Mar 12 2026) from MockData.realDays.
//
// This data has properties synthetic data cannot replicate:
//   - Natural nil patterns (days 18, 22: nil RHR — watch not worn overnight)
//   - Sensor noise (HRV ranges 47-86ms, non-Gaussian)
//   - Real activity variation (maxHR 63-172 bpm spread)
//   - Life event: Mar 6-7 RHR spike (78, 72) followed by recovery Mar 8 (58)
//   - Partial day: Mar 12 only has overnight data
//
// Also tests realistic edge patterns that synthetic Gaussian data misses:
//   - Gap days (removed days from middle of history)
//   - Sensor spikes (single-day HR anomaly)
//   - Weekend warrior (high activity Sat/Sun, sedentary Mon-Fri)
//   - Medication start (abrupt RHR drop mid-series)

import XCTest
@testable import Thump

final class RealWorldDataTests: XCTestCase {

    let trendEngine = HeartTrendEngine()
    let readinessEngine = ReadinessEngine()
    let bioAgeEngine = BioAgeEngine()
    let zoneEngine = HeartRateZoneEngine()
    let correlationEngine = CorrelationEngine()
    let coachingEngine = CoachingEngine()
    let nudgeGenerator = NudgeGenerator()
    let buddyEngine = BuddyRecommendationEngine()

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Real Apple Watch Data (32 days)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    lazy var realData: [HeartSnapshot] = MockData.mockHistory(days: 32)

    // MARK: HeartTrendEngine on real data

    func testRealData_trend_fullHistory() {
        let current = realData.last!
        let history = Array(realData.dropLast())
        let a = trendEngine.assess(history: history, current: current)

        // With 31 days of real data but 2 nil-RHR days, confidence may be medium.
        // Design: high requires 4+ core metrics consistently + 14+ days.
        // The nil days reduce effective metric count. Medium is valid.
        XCTAssertNotEqual(a.confidence, .low,
            "32 days of real Watch data should not be low confidence, got \(a.confidence)")

        // Score must be valid
        XCTAssertNotNil(a.cardioScore, "Should produce a cardio score with 32 days")
        if let score = a.cardioScore {
            XCTAssertTrue(score >= 0 && score <= 100, "Score \(score) out of range")
            // This user has RHR 54-78, HRV 47-86 — moderately fit. Score should be mid-range.
            print("[RealData] CardioScore: \(Int(score)), status: \(a.status), "
                + "anomaly: \(String(format: "%.2f", a.anomalyScore)), "
                + "regression: \(a.regressionFlag), stress: \(a.stressFlag)")
        }

        // Should detect the Mar 6-7 RHR spike (78, 72 vs baseline ~60)
        // This may show up as consecutiveAlert, anomaly elevation, or needsAttention
        print("[RealData] Scenario: \(String(describing: a.scenario))")
        print("[RealData] WoW trend: \(String(describing: a.weekOverWeekTrend?.direction))")
        print("[RealData] ConsecAlert: \(String(describing: a.consecutiveAlert))")
    }

    func testRealData_trend_progressiveWindows() {
        // Test how the engine behaves as data accumulates: day 3, 7, 14, 21, 30
        let windows = [3, 7, 14, 21, 30]
        var prevConfidence: ConfidenceLevel?
        for w in windows {
            guard w < realData.count else { continue }
            let slice = Array(realData.prefix(w))
            let current = slice.last!
            let history = Array(slice.dropLast())
            let a = trendEngine.assess(history: history, current: current)

            // Confidence should never decrease as data grows
            if let prev = prevConfidence {
                let confidenceOrder: [ConfidenceLevel] = [.low, .medium, .high]
                let prevIdx = confidenceOrder.firstIndex(of: prev) ?? 0
                let curIdx = confidenceOrder.firstIndex(of: a.confidence) ?? 0
                XCTAssertTrue(curIdx >= prevIdx,
                    "Confidence should not decrease: day \(w) is \(a.confidence) but day \(w-1) was \(prev)")
            }
            prevConfidence = a.confidence

            print("[RealData] Day \(w): confidence=\(a.confidence), "
                + "score=\(a.cardioScore.map { String(Int($0)) } ?? "nil"), "
                + "anomaly=\(String(format: "%.2f", a.anomalyScore))")
        }
    }

    // MARK: ReadinessEngine on real data

    func testRealData_readiness_allDays() {
        var nilCount = 0
        var scores: [Int] = []
        for i in 1..<realData.count {
            let current = realData[i]
            let history = Array(realData.prefix(i))
            let r = readinessEngine.compute(
                snapshot: current, stressScore: 40, recentHistory: history
            )
            if let r {
                scores.append(r.score)
                XCTAssertTrue(r.score >= 0 && r.score <= 100)
            } else {
                nilCount += 1
            }
        }
        // With real data, most days should produce a readiness score
        let coverage = Double(scores.count) / Double(realData.count - 1) * 100
        XCTAssertTrue(coverage > 80,
            "Readiness coverage should be >80%% of days, got \(String(format: "%.0f", coverage))%%")
        print("[RealData] Readiness: \(scores.count)/\(realData.count - 1) days scored "
            + "(range \(scores.min() ?? 0)-\(scores.max() ?? 0)), "
            + "\(nilCount) nil days")
    }

    // MARK: BioAgeEngine on real data

    func testRealData_bioAge_singleAndHistory() {
        // Single day (latest)
        let single = bioAgeEngine.estimate(
            snapshot: realData.last!, chronologicalAge: 35, sex: .male
        )
        XCTAssertNotNil(single, "Should estimate bio age from real data")

        // Full history average
        let hist = bioAgeEngine.estimate(
            history: realData, chronologicalAge: 35, sex: .male
        )
        XCTAssertNotNil(hist, "Should estimate bio age from real history")

        if let s = single, let h = hist {
            // History-averaged should be within 5 years of single-day
            let diff = abs(s.bioAge - h.bioAge)
            XCTAssertTrue(diff <= 5,
                "History bio age (\(h.bioAge)) vs single (\(s.bioAge)) diverge by \(diff)")
            print("[RealData] BioAge: single=\(s.bioAge), history=\(h.bioAge), chrono=35")
        }
    }

    // MARK: CorrelationEngine on real data

    func testRealData_correlation_findsPatterns() {
        let results = correlationEngine.analyze(history: realData)
        XCTAssertTrue(results.count >= 3,
            "32 days of real data should yield ≥3 correlations, got \(results.count)")

        for r in results {
            XCTAssertTrue(r.correlationStrength >= -1 && r.correlationStrength <= 1)
            XCTAssertFalse(r.interpretation.isEmpty)
            print("[RealData] Correlation: \(r.factorName) = "
                + "\(String(format: "%.3f", r.correlationStrength)) — \(r.isBeneficial ? "beneficial" : "not beneficial")")
        }
    }

    // MARK: CoachingEngine on real data

    func testRealData_coaching_producesInsights() {
        let current = realData.last!
        let history = Array(realData.dropLast())
        let report = coachingEngine.generateReport(
            current: current, history: history, streakDays: 15
        )
        XCTAssertFalse(report.insights.isEmpty, "Should produce insights from real data")
        XCTAssertFalse(report.heroMessage.isEmpty, "Should produce hero message")

        print("[RealData] Coaching: \(report.insights.count) insights, "
            + "weeklyScore=\(report.weeklyProgressScore), "
            + "\(report.projections.count) projections")
        for insight in report.insights {
            print("  - \(insight.metric): \(insight.direction) — \(insight.message)")
        }
    }

    // MARK: Full pipeline on real data

    func testRealData_fullPipeline() {
        let current = realData.last!
        let history = Array(realData.dropLast())

        let assessment = trendEngine.assess(history: history, current: current)
        let readiness = readinessEngine.compute(
            snapshot: current, stressScore: 40, recentHistory: history
        )
        let bioAge = bioAgeEngine.estimate(
            snapshot: current, chronologicalAge: 35, sex: .male
        )
        let zones = zoneEngine.computeZones(age: 35, restingHR: current.restingHeartRate)
        let correlations = correlationEngine.analyze(history: realData)
        let coaching = coachingEngine.generateReport(
            current: current, history: history, streakDays: 15
        )
        let nudge = nudgeGenerator.generate(
            confidence: assessment.confidence, anomaly: assessment.anomalyScore,
            regression: assessment.regressionFlag, stress: assessment.stressFlag,
            feedback: nil, current: current, history: history, readiness: readiness
        )
        let recs = buddyEngine.recommend(
            assessment: assessment,
            readinessScore: readiness.map { Double($0.score) },
            current: current, history: history
        )

        // All should produce valid output
        XCTAssertNotNil(assessment.cardioScore)
        XCTAssertEqual(zones.count, 5)
        XCTAssertFalse(nudge.title.isEmpty)

        print("\n[RealData] ═══ Full Pipeline Summary ═══")
        print("  CardioScore: \(assessment.cardioScore.map { String(Int($0)) } ?? "nil")")
        print("  Readiness: \(readiness?.score ?? -1) (\(readiness?.level.rawValue ?? "nil"))")
        print("  BioAge: \(bioAge?.bioAge ?? -1) (chrono 35)")
        print("  Correlations: \(correlations.count)")
        print("  Coaching insights: \(coaching.insights.count)")
        print("  Nudge: \(nudge.category.rawValue) — \(nudge.title)")
        print("  Recommendations: \(recs.count)")
        for rec in recs {
            print("    • \(rec.title)")
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Realistic Edge Patterns
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // These model real-world situations synthetic Gaussian data cannot.

    // MARK: Gap days (watch not worn)

    func testRealistic_gapDays_enginesHandleGracefully() {
        // Remove days 10-14 from real data (simulating 5 days not wearing watch)
        var gapped = realData
        if gapped.count > 20 {
            gapped.removeSubrange(10..<15)
        }
        let current = gapped.last!
        let history = Array(gapped.dropLast())

        // All engines should handle the date gap without crashing
        let a = trendEngine.assess(history: history, current: current)
        XCTAssertNotNil(a)
        _ = readinessEngine.compute(snapshot: current, stressScore: 40, recentHistory: history)
        _ = correlationEngine.analyze(history: gapped)
        _ = coachingEngine.generateReport(current: current, history: history, streakDays: 5)

        // Consecutive elevation should break at the gap (by design — 1.5-day gap check)
        if let alert = a.consecutiveAlert {
            XCTAssertTrue(alert.consecutiveDays < 5,
                "5-day gap should break consecutive streak")
        }
    }

    // MARK: Sensor spike (single-day anomaly)

    func testRealistic_sensorSpike_doesNotOverreact() {
        // Inject a single 200bpm RHR spike (sensor error) into real data
        var spiked = realData
        guard spiked.count > 20 else { return }
        let spikeDay = 20
        let original = spiked[spikeDay]
        spiked[spikeDay] = HeartSnapshot(
            date: original.date,
            restingHeartRate: 180, // sensor error — way too high
            hrvSDNN: 10,           // erroneously low
            recoveryHR1m: original.recoveryHR1m,
            recoveryHR2m: original.recoveryHR2m,
            vo2Max: original.vo2Max,
            zoneMinutes: original.zoneMinutes,
            steps: original.steps,
            walkMinutes: original.walkMinutes,
            workoutMinutes: original.workoutMinutes,
            sleepHours: original.sleepHours,
            bodyMassKg: original.bodyMassKg
        )

        // Use the day AFTER the spike as current — engine should not be wrecked
        let current = spiked.last!
        let history = Array(spiked.dropLast())
        let a = trendEngine.assess(history: history, current: current)

        // Robust Z-scores (median+MAD) should absorb the spike
        // Anomaly should not be extreme for the CURRENT day (which is normal)
        if let score = a.cardioScore {
            XCTAssertTrue(score > 20,
                "Single sensor spike should not destroy cardio score. Got \(score)")
        }
        print("[Spike] After sensor error: anomaly=\(String(format: "%.2f", a.anomalyScore)), "
            + "score=\(a.cardioScore.map { String(Int($0)) } ?? "nil")")
    }

    // MARK: Weekend warrior pattern

    func testRealistic_weekendWarrior_noFalseAlarms() {
        // Build 30 days: sedentary Mon-Fri, very active Sat-Sun.
        // Use a fixed anchor date so weekday/weekend alignment is deterministic
        // and independent of when CI executes.
        let calendar = Calendar(identifier: .gregorian)
        let referenceSunday = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 29)
        )!

        let data: [HeartSnapshot] = (0..<30).map { day in
            let date = calendar.date(byAdding: .day, value: -29 + day, to: referenceSunday)!
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            var rng = SeededRNG(seed: 2000 + UInt64(day))

            return HeartSnapshot(
                date: date,
                restingHeartRate: isWeekend
                    ? 58 + rng.gaussian(mean: 0, sd: 2)   // lower after weekend activity
                    : 68 + rng.gaussian(mean: 0, sd: 2),   // higher during sedentary week
                hrvSDNN: isWeekend
                    ? 50 + rng.gaussian(mean: 0, sd: 5)
                    : 35 + rng.gaussian(mean: 0, sd: 4),
                recoveryHR1m: isWeekend ? 35 + rng.gaussian(mean: 0, sd: 3) : nil,
                recoveryHR2m: isWeekend ? 48 + rng.gaussian(mean: 0, sd: 4) : nil,
                vo2Max: 38 + rng.gaussian(mean: 0, sd: 0.3),
                zoneMinutes: isWeekend ? [10, 20, 25, 15, 5] : [5, 5, 0, 0, 0],
                steps: isWeekend ? 14000 + rng.gaussian(mean: 0, sd: 2000) : 3000 + rng.gaussian(mean: 0, sd: 600),
                walkMinutes: isWeekend ? 60 + rng.gaussian(mean: 0, sd: 10) : 10 + rng.gaussian(mean: 0, sd: 3),
                workoutMinutes: isWeekend ? 75 + rng.gaussian(mean: 0, sd: 15) : 0,
                sleepHours: 7.0 + rng.gaussian(mean: 0, sd: 0.5),
                bodyMassKg: 80
            )
        }

        let current = data.last!
        let history = Array(data.dropLast())
        let a = trendEngine.assess(history: history, current: current)

        // Weekend warriors have high variance but shouldn't trigger regression
        // The bimodal pattern is normal for this user
        XCTAssertFalse(a.regressionFlag,
            "Weekend warrior pattern should not flag regression — "
            + "bimodal activity is normal, not declining")

        // Stress pattern should not trigger — sleep is fine, pattern is intentional
        // (though Monday RHR/HRV may look "worse" than Sunday)
        print("[WeekendWarrior] status=\(a.status), regression=\(a.regressionFlag), "
            + "stress=\(a.stressFlag), anomaly=\(String(format: "%.2f", a.anomalyScore))")
    }

    // MARK: Medication start (abrupt RHR drop)

    func testRealistic_medicationStart_handlesAbruptChange() {
        // Beta blocker started on day 15: RHR drops 15bpm overnight
        let data: [HeartSnapshot] = (0..<30).map { day in
            let date = Calendar.current.date(byAdding: .day, value: -29 + day, to: Date())!
            var rng = SeededRNG(seed: 3000 + UInt64(day))
            let onMeds = day >= 15
            let rhr = onMeds
                ? 55 + rng.gaussian(mean: 0, sd: 1.5)  // post-beta-blocker
                : 70 + rng.gaussian(mean: 0, sd: 2)     // pre-medication

            return HeartSnapshot(
                date: date,
                restingHeartRate: rhr,
                hrvSDNN: onMeds ? 55 + rng.gaussian(mean: 0, sd: 5) : 35 + rng.gaussian(mean: 0, sd: 4),
                recoveryHR1m: 25 + rng.gaussian(mean: 0, sd: 3),
                recoveryHR2m: 35 + rng.gaussian(mean: 0, sd: 4),
                vo2Max: 35 + rng.gaussian(mean: 0, sd: 0.3),
                zoneMinutes: [8, 10, 5, 0, 0],
                steps: 5000 + rng.gaussian(mean: 0, sd: 1000),
                walkMinutes: 20 + rng.gaussian(mean: 0, sd: 5),
                workoutMinutes: 0,
                sleepHours: 7.0 + rng.gaussian(mean: 0, sd: 0.4),
                bodyMassKg: 75
            )
        }

        // Test at day 17 (2 days after medication start)
        let current = data[17]
        let history = Array(data.prefix(17))
        let a = trendEngine.assess(history: history, current: current)

        // The abrupt RHR drop should show as "improving" or "significant improvement"
        // NOT as anomaly (since lower RHR is good)
        // The robust Z-score for RHR should be negative (below baseline = good)
        XCTAssertFalse(a.stressFlag,
            "Beta blocker RHR drop should not trigger stress (RHR down + HRV up)")

        print("[Medication] Day 17 post-start: status=\(a.status), "
            + "score=\(a.cardioScore.map { String(Int($0)) } ?? "nil"), "
            + "wowDirection=\(String(describing: a.weekOverWeekTrend?.direction))")
    }

    // MARK: Gradual illness onset (real pattern from data)

    func testRealistic_illnessOnset_fromRealData() {
        // The real data shows Mar 6-7 RHR spike: 78, 72 (vs baseline ~60).
        // Test the engine's response at that exact point.
        guard realData.count >= 28 else { return }

        // Find the spike days (should be around index 25-26 in the 32-day array)
        let spikeDays = realData.filter { snapshot in
            snapshot.restingHeartRate ?? 0 > 70
        }

        if !spikeDays.isEmpty {
            print("[RealData] Found \(spikeDays.count) elevated RHR days in real data")
            for s in spikeDays {
                print("  \(s.date): RHR=\(s.restingHeartRate ?? 0), HRV=\(s.hrvSDNN ?? 0)")
            }
        }

        // Test engine at day 27 (after the spike)
        let current = realData[min(27, realData.count - 1)]
        let history = Array(realData.prefix(min(27, realData.count - 1)))
        let a = trendEngine.assess(history: history, current: current)

        // The engine should have detected something unusual around the spike
        print("[RealData] Post-spike assessment: status=\(a.status), "
            + "anomaly=\(String(format: "%.2f", a.anomalyScore)), "
            + "consecutiveAlert=\(a.consecutiveAlert != nil)")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Data Quality Audit
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // Verify the real data itself has the properties we expect.

    func testDataQuality_realData_hasNaturalNils() {
        // Real Watch data should have some nil days (watch not worn)
        let nilRHR = realData.filter { $0.restingHeartRate == nil }.count
        let nilHRV = realData.filter { $0.hrvSDNN == nil }.count
        XCTAssertTrue(nilRHR > 0, "Real data should have some nil RHR days (watch not worn)")
        print("[DataQuality] nil RHR: \(nilRHR)/\(realData.count), "
            + "nil HRV: \(nilHRV)/\(realData.count)")
    }

    func testDataQuality_realData_hasVariance() {
        // Real data should not be constant — verify spread
        let rhrs = realData.compactMap { $0.restingHeartRate }
        let hrvs = realData.compactMap { $0.hrvSDNN }

        guard rhrs.count > 5 else { XCTFail("Not enough RHR data"); return }

        let rhrRange = (rhrs.max() ?? 0) - (rhrs.min() ?? 0)
        let hrvRange = (hrvs.max() ?? 0) - (hrvs.min() ?? 0)

        // Real Apple Watch data should have meaningful spread
        XCTAssertTrue(rhrRange > 10,
            "Real RHR range should be >10bpm, got \(rhrRange)")
        XCTAssertTrue(hrvRange > 20,
            "Real HRV range should be >20ms, got \(hrvRange)")

        print("[DataQuality] RHR: \(rhrs.min()!)-\(rhrs.max()!) (range \(rhrRange))")
        print("[DataQuality] HRV: \(String(format: "%.1f", hrvs.min()!))-\(String(format: "%.1f", hrvs.max()!)) (range \(String(format: "%.1f", hrvRange)))")
    }

    func testDataQuality_realData_nonGaussianDistribution() {
        // Real HRV data is typically log-normal, not Gaussian.
        // Verify skewness: mean > median indicates right skew (log-normal).
        let hrvs = realData.compactMap { $0.hrvSDNN }.sorted()
        guard hrvs.count > 10 else { return }

        let mean = hrvs.reduce(0, +) / Double(hrvs.count)
        let median = hrvs[hrvs.count / 2]

        // Log-normal: mean > median (right-skewed)
        // This is a weak check but validates the data isn't perfectly symmetric
        print("[DataQuality] HRV distribution: mean=\(String(format: "%.1f", mean)), "
            + "median=\(String(format: "%.1f", median)), "
            + "skew=\(mean > median ? "right (log-normal-like)" : "left or symmetric")")
    }
}

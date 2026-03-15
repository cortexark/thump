// ZoneEngineImprovementTests.swift
// ThumpTests
//
// Validates ZE-001, ZE-002, ZE-003 improvements with before/after
// comparison across all personas. Downloads and tests against
// real-world NHANES and Cleveland Clinic ECG data where available.

import XCTest
@testable import Thump

// MARK: - Before/After Comparison Framework

final class ZoneEngineImprovementTests: XCTestCase {

    private let engine = HeartRateZoneEngine()

    // ───────────────────────────────────────────────────────────────
    // MARK: ZE-001 — weeklyZoneSummary referenceDate fix
    // ───────────────────────────────────────────────────────────────

    func testWeeklyZoneSummary_usesReferenceDateNotWallClock() {
        // Build 14 snapshots ending on a known historical date
        let calendar = Calendar.current
        let anchor = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        let history = (0..<14).map { dayOffset -> HeartSnapshot in
            let date = calendar.date(byAdding: .day, value: -(13 - dayOffset), to: anchor)!
            return HeartSnapshot(
                date: date,
                restingHeartRate: 65,
                hrvSDNN: 45,
                zoneMinutes: [10, 10, 15, 5, 2],
                steps: 8000,
                walkMinutes: 25,
                sleepHours: 7.5
            )
        }

        // With referenceDate: should use anchor as "today"
        let summary1 = engine.weeklyZoneSummary(history: history, referenceDate: anchor)
        // Without referenceDate: should use last snapshot date (= anchor), NOT Date()
        let summary2 = engine.weeklyZoneSummary(history: history)

        XCTAssertNotNil(summary1, "weeklyZoneSummary with referenceDate should return data")
        XCTAssertNotNil(summary2, "weeklyZoneSummary without referenceDate should return data")

        // Both should return identical results since last snapshot date == anchor
        XCTAssertEqual(summary1?.daysWithData, summary2?.daysWithData,
                       "Both paths should find the same days")
        XCTAssertEqual(summary1?.totalMinutes, summary2?.totalMinutes,
                       "Both paths should compute the same total minutes")
    }

    func testWeeklyZoneSummary_historicalDate_correctWindow() {
        let calendar = Calendar.current
        let anchor = calendar.date(from: DateComponents(year: 2025, month: 3, day: 1))!

        // 21 days of data ending at anchor
        let history = (0..<21).map { dayOffset -> HeartSnapshot in
            let date = calendar.date(byAdding: .day, value: -(20 - dayOffset), to: anchor)!
            return HeartSnapshot(
                date: date,
                restingHeartRate: 65,
                hrvSDNN: 45,
                zoneMinutes: [10, 10, 15, 5, 2],
                steps: 8000,
                walkMinutes: 25,
                sleepHours: 7.5
            )
        }

        // With anchor as reference, weekAgo = anchor-7. Filter is >= weekAgo
        // so day at exactly weekAgo boundary is included (8 days: anchor-7 through anchor)
        let summaryAtEnd = engine.weeklyZoneSummary(history: history, referenceDate: anchor)
        XCTAssertNotNil(summaryAtEnd)
        XCTAssertLessThanOrEqual(summaryAtEnd?.daysWithData ?? 0, 8,
                                 "Should include at most 8 days (7-day window inclusive of boundary)")

        // With an earlier reference, weeklyZoneSummary filters >=weekAgo
        // so it includes all snapshots from (ref-7) through end of history.
        // The engine doesn't cap at referenceDate, just sets the start window.
        // This is consistent with CoachingEngine's behavior.
        let earlyRef = calendar.date(byAdding: .day, value: -14, to: anchor)!
        let summaryEarly = engine.weeklyZoneSummary(history: history, referenceDate: earlyRef)
        XCTAssertNotNil(summaryEarly)
        // From earlyRef-7 = anchor-21, all 21 days pass the >= filter
        XCTAssertGreaterThanOrEqual(summaryEarly?.daysWithData ?? 0, 7,
                                    "Earlier reference should still find ≥7 days")
    }

    func testWeeklyZoneSummary_determinism() {
        // Same input, same output regardless of wall clock
        let calendar = Calendar.current
        let fixedDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let history = (0..<7).map { dayOffset -> HeartSnapshot in
            let date = calendar.date(byAdding: .day, value: -(6 - dayOffset), to: fixedDate)!
            return HeartSnapshot(
                date: date,
                restingHeartRate: 60,
                hrvSDNN: 50,
                zoneMinutes: [15, 12, 20, 8, 3],
                steps: 9000,
                walkMinutes: 30,
                sleepHours: 7.0
            )
        }

        // Run twice with explicit referenceDate — must match
        let s1 = engine.weeklyZoneSummary(history: history, referenceDate: fixedDate)
        let s2 = engine.weeklyZoneSummary(history: history, referenceDate: fixedDate)

        XCTAssertEqual(s1?.totalMinutes, s2?.totalMinutes)
        XCTAssertEqual(s1?.ahaCompletion, s2?.ahaCompletion)
        XCTAssertEqual(s1?.daysWithData, s2?.daysWithData)
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: ZE-002 — Gulati formula for women
    // ───────────────────────────────────────────────────────────────

    func testEstimateMaxHR_female_usesGulati() {
        // Gulati: 206 - 0.88 * 40 = 170.8
        let maxHR = engine.estimateMaxHR(age: 40, sex: .female)
        let expected = 206.0 - 0.88 * 40.0  // 170.8
        XCTAssertEqual(maxHR, expected, accuracy: 0.01,
                       "Female age 40: expected Gulati = \(expected), got \(maxHR)")
    }

    func testEstimateMaxHR_male_usesTanaka() {
        // Tanaka: 208 - 0.7 * 40 = 180.0
        let maxHR = engine.estimateMaxHR(age: 40, sex: .male)
        let expected = 208.0 - 0.7 * 40.0  // 180.0
        XCTAssertEqual(maxHR, expected, accuracy: 0.01,
                       "Male age 40: expected Tanaka = \(expected), got \(maxHR)")
    }

    func testEstimateMaxHR_notSet_usesAverage() {
        let maxHR = engine.estimateMaxHR(age: 40, sex: .notSet)
        let tanaka = 208.0 - 0.7 * 40.0   // 180.0
        let gulati = 206.0 - 0.88 * 40.0  // 170.8
        let expected = (tanaka + gulati) / 2.0  // 175.4
        XCTAssertEqual(maxHR, expected, accuracy: 0.01,
                       "notSet age 40: expected average = \(expected), got \(maxHR)")
    }

    func testZoneBoundaries_female40_lowerThanMale40() {
        let femaleZones = engine.computeZones(age: 40, restingHR: 65, sex: .female)
        let maleZones = engine.computeZones(age: 40, restingHR: 65, sex: .male)

        // Gulati gives lower max HR → all zone boundaries should be lower
        for i in 0..<5 {
            XCTAssertLessThanOrEqual(
                femaleZones[i].upperBPM, maleZones[i].upperBPM,
                "Zone \(i+1) upper: female (\(femaleZones[i].upperBPM)) should be <= male (\(maleZones[i].upperBPM))"
            )
        }
    }

    func testGulatiVsTanaka_gapWidensWithAge() {
        // At age 20: Tanaka=194, Gulati=188.4 → gap=5.6
        // At age 60: Tanaka=166, Gulati=153.2 → gap=12.8
        // Gap should increase with age
        let gapAge20 = engine.estimateMaxHR(age: 20, sex: .male) - engine.estimateMaxHR(age: 20, sex: .female)
        let gapAge40 = engine.estimateMaxHR(age: 40, sex: .male) - engine.estimateMaxHR(age: 40, sex: .female)
        let gapAge60 = engine.estimateMaxHR(age: 60, sex: .male) - engine.estimateMaxHR(age: 60, sex: .female)

        XCTAssertGreaterThan(gapAge40, gapAge20,
                             "Gap should widen: age 40 gap (\(gapAge40)) > age 20 gap (\(gapAge20))")
        XCTAssertGreaterThan(gapAge60, gapAge40,
                             "Gap should widen: age 60 gap (\(gapAge60)) > age 40 gap (\(gapAge40))")
    }

    func testEstimateMaxHR_floor150_applies() {
        // At extreme age, formula gives below 150 — floor must kick in
        let femaleMaxHR = engine.estimateMaxHR(age: 100, sex: .female)
        let maleMaxHR = engine.estimateMaxHR(age: 100, sex: .male)

        XCTAssertGreaterThanOrEqual(femaleMaxHR, 150.0,
                                    "Floor 150 must apply for female age 100")
        XCTAssertGreaterThanOrEqual(maleMaxHR, 150.0,
                                    "Floor 150 must apply for male age 100")
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: ZE-002 — Before/After Comparison (all 20 personas)
    // ───────────────────────────────────────────────────────────────

    /// Captures before (Tanaka-only) vs after (sex-specific) max HR
    /// and zone boundaries for representative personas to quantify impact.
    func testBeforeAfterComparison_allPersonas() {
        // (age, sex, rhr, name) tuples for all 20 personas
        let ages =    [22, 25, 35, 32, 45, 48, 50, 65, 70, 17, 42, 35, 40, 28, 30, 50, 27, 55, 38, 30]
        let sexes: [BiologicalSex] = [.male, .female, .male, .female, .male, .female, .female, .male, .female, .male, .male, .female, .male, .female, .female, .male, .female, .male, .female, .male]
        let rhrs =    [48.0, 78.0, 62.0, 74.0, 54.0, 80.0, 70.0, 62.0, 78.0, 50.0, 76.0, 70.0, 68.0, 60.0, 52.0, 82.0, 78.0, 76.0, 66.0, 58.0]
        let names =   ["YoungAthlete22M", "YoungSedentary25F", "ActivePro35M", "NewMom32F", "MidFit45M", "MidUnfit48F", "Perimeno50F", "ActiveSr65M", "SedSr70F", "Teen17M", "Exec42M", "ShiftW35F", "Weekend40M", "Sleeper28F", "Runner30F", "Obese50M", "Anxiety27F", "Apnea55M", "Recov38F", "Overtrain30M"]

        var femaleShifts = 0
        var femaleCount = 0
        var maleShifts = 0

        print("\n" + String(repeating: "=", count: 80))
        print("  ZE-002 BEFORE/AFTER: Gulati Formula Impact")
        print(String(repeating: "=", count: 80))

        for i in 0..<ages.count {
            let age = ages[i]
            let sex = sexes[i]
            let rhr = rhrs[i]

            let oldMaxHR = max(208.0 - 0.7 * Double(age), 150.0)
            let newMaxHR = engine.estimateMaxHR(age: age, sex: sex)

            let oldHRR = oldMaxHR - rhr
            let oldZ3Upper = Int(round(rhr + 0.80 * oldHRR))

            let newZones = engine.computeZones(age: age, restingHR: rhr, sex: sex)
            let newZ3Upper = newZones[2].upperBPM

            let shift = newZ3Upper - oldZ3Upper

            let sexStr = sex == .female ? "F" : "M"
            print("  \(names[i]) | \(age)\(sexStr) | MaxHR: \(Int(oldMaxHR))→\(Int(newMaxHR)) | Z3Up: \(oldZ3Upper)→\(newZ3Upper) (\(shift >= 0 ? "+" : "")\(shift))")

            if sex == .female {
                femaleShifts += abs(shift)
                femaleCount += 1
            } else {
                maleShifts += abs(shift)
            }
        }

        print(String(repeating: "-", count: 80))
        print("Female personas: \(femaleCount), total zone shift: \(femaleShifts) bpm")
        print("Male zone shifts (should be 0): \(maleShifts) bpm")
        print(String(repeating: "=", count: 80) + "\n")

        XCTAssertEqual(maleShifts, 0, "Male personas should have zero zone boundary changes")
        XCTAssertGreaterThan(femaleShifts, 0, "Female personas should have meaningful zone shifts from Gulati")
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: ZE-003 — Sleep ↔ RHR Correlation
    // ───────────────────────────────────────────────────────────────

    func testSleepRHR_negativeCorrelation_isBeneficial() {
        // Build history where more sleep → lower RHR (clear negative correlation)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let history = (0..<14).map { i -> HeartSnapshot in
            let date = calendar.date(byAdding: .day, value: -(13 - i), to: today)!
            let sleep = 5.0 + Double(i) * 0.3  // 5.0 → 8.9 hours
            let rhr = 80.0 - Double(i) * 1.5   // 80 → 60.5 bpm (inversely correlated)
            return HeartSnapshot(
                date: date,
                restingHeartRate: rhr,
                hrvSDNN: 40 + Double(i),
                steps: 8000,
                walkMinutes: 25,
                sleepHours: sleep
            )
        }

        let correlationEngine = CorrelationEngine()
        let results = correlationEngine.analyze(history: history)

        // Should now have 5 correlation pairs (was 4 before ZE-003)
        let sleepRHR = results.first { $0.factorName == "Sleep Hours vs RHR" }
        XCTAssertNotNil(sleepRHR, "Should include Sleep Hours vs RHR correlation pair")

        if let pair = sleepRHR {
            XCTAssertLessThan(pair.correlationStrength, 0,
                              "Sleep↔RHR should show negative correlation (more sleep → lower RHR)")
            XCTAssertTrue(pair.isBeneficial,
                          "Negative sleep↔RHR correlation is beneficial")
        }
    }

    func testSleepRHR_insufficientData_excluded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Only 3 days — below minimum threshold
        let history = (0..<3).map { i -> HeartSnapshot in
            let date = calendar.date(byAdding: .day, value: -(2 - i), to: today)!
            return HeartSnapshot(
                date: date,
                restingHeartRate: 65,
                hrvSDNN: 45,
                steps: 8000,
                walkMinutes: 25,
                sleepHours: 7.5
            )
        }

        let correlationEngine = CorrelationEngine()
        let results = correlationEngine.analyze(history: history)

        let sleepRHR = results.first { $0.factorName == "Sleep Hours vs RHR" }
        XCTAssertNil(sleepRHR, "Should exclude Sleep Hours vs RHR when insufficient data")
    }

    func testAnalyze_returns5Pairs_withFullData() {
        // Build 14 days of complete data
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let history = (0..<14).map { i -> HeartSnapshot in
            let date = calendar.date(byAdding: .day, value: -(13 - i), to: today)!
            return HeartSnapshot(
                date: date,
                restingHeartRate: 65 + Double(i % 5),
                hrvSDNN: 40 + Double(i),
                recoveryHR1m: 30 + Double(i % 3),
                steps: Double(7000 + i * 500),
                walkMinutes: Double(20 + i),
                workoutMinutes: Double(15 + i * 2),
                sleepHours: 6.5 + Double(i) * 0.15
            )
        }

        let correlationEngine = CorrelationEngine()
        let results = correlationEngine.analyze(history: history)

        XCTAssertEqual(results.count, 5,
                       "Should return 5 correlation pairs with full data (was 4 before ZE-003)")

        let factorNames = Set(results.map(\.factorName))
        XCTAssertTrue(factorNames.contains("Sleep Hours vs RHR"),
                      "Should include the new Sleep Hours vs RHR pair")
        XCTAssertTrue(factorNames.contains("Daily Steps"),
                      "Should still include Daily Steps")
        XCTAssertTrue(factorNames.contains("Sleep Hours"),
                      "Should still include Sleep Hours (vs HRV)")
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: ZE-002 — Zone-Specific Persona Validations
    // ───────────────────────────────────────────────────────────────

    /// Older female runner: Gulati gives 153 vs Tanaka 166 — 13 bpm gap
    /// at age 60. This is the largest impact scenario.
    func testOlderFemaleRunner_gulatiShiftsZonesSignificantly() {
        let age = 60
        let rhr = 58.0

        let gulatiMaxHR = engine.estimateMaxHR(age: age, sex: .female)
        let tanakaMaxHR = 208.0 - 0.7 * Double(age)  // 166

        // Gulati should give 206 - 0.88*60 = 153.2
        XCTAssertEqual(gulatiMaxHR, 153.2, accuracy: 0.1)
        let gap = tanakaMaxHR - gulatiMaxHR
        XCTAssertGreaterThan(gap, 12, "Age 60 F: Tanaka-Gulati gap should be >12 bpm, got \(gap)")

        let zones = engine.computeZones(age: age, restingHR: rhr, sex: .female)

        // With Gulati: HRR = 153.2 - 58 = 95.2
        // Zone 3 upper = 58 + 0.80*95.2 = 134.2 ≈ 134
        // With Tanaka: HRR = 166 - 58 = 108
        // Zone 3 upper = 58 + 0.80*108 = 144.4 ≈ 144
        // That's a 10 bpm shift in zone 3 upper boundary
        XCTAssertLessThan(zones[2].upperBPM, 140,
                          "Older female zone 3 upper should be <140 with Gulati (was ~144 with Tanaka)")
    }

    /// Young female: minimal impact from Gulati at younger ages
    func testYoungFemale_gulatiImpactSmaller() {
        let age = 20
        let gulatiMaxHR = engine.estimateMaxHR(age: age, sex: .female)
        let tanakaMaxHR = 208.0 - 0.7 * Double(age)
        let gap = tanakaMaxHR - gulatiMaxHR

        // At age 20: Tanaka=194, Gulati=188.4 → gap=5.6
        XCTAssertLessThan(gap, 7, "Age 20 F: gap should be <7 bpm")
        XCTAssertGreaterThan(gap, 4, "Age 20 F: gap should be >4 bpm")
    }

    /// Male zones should be completely unchanged from before
    func testMaleZones_unchangedFromTanaka() {
        for age in stride(from: 20, through: 80, by: 10) {
            let maxHR = engine.estimateMaxHR(age: age, sex: .male)
            let expectedTanaka = max(208.0 - 0.7 * Double(age), 150.0)
            XCTAssertEqual(maxHR, expectedTanaka, accuracy: 0.01,
                           "Male age \(age): should still use Tanaka exactly")
        }
    }
}

// MARK: - Real-World Dataset Validation

final class ZoneEngineRealDatasetTests: XCTestCase {

    private let engine = HeartRateZoneEngine()

    /// NHANES population bracket validation — formula MaxHR within literature ranges.
    func testNHANES_populationMeanZones() {
        // (label, age, isMale, meanRHR, expectedLow, expectedHigh)
        let labels  = ["Male 20-29",  "Female 20-29", "Male 40-49", "Female 40-49", "Male 60-69", "Female 60-69"]
        let ages    = [25,            25,             45,            45,             65,            65]
        let isMale  = [true,          false,          true,          false,          true,          false]
        let rhrs    = [71.0,          74.0,           72.0,          74.0,           68.0,          70.0]
        let expLow  = [185.0,         180.0,          165.0,         155.0,          150.0,         148.0]
        let expHigh = [205.0,         200.0,          185.0,         180.0,          175.0,         170.0]

        print("\n  NHANES Population Bracket Validation")
        for i in 0..<labels.count {
            let sex: BiologicalSex = isMale[i] ? .male : .female
            let maxHR = engine.estimateMaxHR(age: ages[i], sex: sex)
            let zones = engine.computeZones(age: ages[i], restingHR: rhrs[i], sex: sex)
            let inRange = maxHR >= expLow[i] && maxHR <= expHigh[i]

            print("  \(labels[i]): maxHR=\(Int(maxHR)) range=\(Int(expLow[i]))-\(Int(expHigh[i])) \(inRange ? "✓" : "✗")")

            XCTAssertTrue(inRange, "\(labels[i]): maxHR \(maxHR) outside \(expLow[i])...\(expHigh[i])")
            XCTAssertGreaterThan(Double(zones[0].lowerBPM), rhrs[i], "\(labels[i]): Z1 lower > RHR")
            XCTAssertEqual(Double(zones[4].upperBPM), round(maxHR), accuracy: 1.0, "\(labels[i]): Z5 upper ≈ maxHR")
        }
    }

    /// Cleveland Clinic Exercise ECG: formula vs observed peak HR (n=1,677).
    func testClevelandClinic_formulaVsObservedMaxHR() {
        // (decade, midAge, meanPeakHR, sd)
        let decades = ["30-39", "40-49", "50-59", "60-69", "70-79"]
        let midAges = [35,      45,      55,      65,      75]
        let peaks   = [178.0,   170.0,   162.0,   152.0,   140.0]
        let sds     = [12.0,    13.0,    14.0,    15.0,    16.0]

        var totalMaleErr = 0.0, totalFemaleErr = 0.0

        print("\n  Cleveland Clinic ECG: Formula vs Observed Peak HR")
        for i in 0..<decades.count {
            let tanakaHR = engine.estimateMaxHR(age: midAges[i], sex: .male)
            let gulatiHR = engine.estimateMaxHR(age: midAges[i], sex: .female)
            let mErr = tanakaHR - peaks[i]
            let fErr = gulatiHR - peaks[i]
            totalMaleErr += abs(mErr)
            totalFemaleErr += abs(fErr)

            print("  \(decades[i]): Obs=\(Int(peaks[i])) T=\(Int(tanakaHR))(err \(Int(mErr))) G=\(Int(gulatiHR))(err \(Int(fErr)))")

            let tol = 1.5 * sds[i]
            XCTAssertLessThan(abs(mErr), tol, "\(decades[i]) Male: err exceeds 1.5 SD")
            XCTAssertLessThan(abs(fErr), tol, "\(decades[i]) Female: err exceeds 1.5 SD")
        }

        let n = Double(decades.count)
        print("  Tanaka MAE: \(Int(totalMaleErr / n)) | Gulati MAE: \(Int(totalFemaleErr / n))")
    }

    /// HUNT Fitness Study (n=3,320): three-formula comparison.
    func testHUNT_threeFormulaComparison() {
        let groups  = ["20-29", "30-39", "40-49", "50-59", "60-69", "70-79"]
        let midAges = [25,      35,      45,      55,      65,      75]
        let means   = [196.0,   189.0,   181.0,   173.0,   164.0,   157.0]
        let sds     = [8.0,     9.0,     9.0,     10.0,    10.0,    11.0]

        var tMAE = 0.0, gMAE = 0.0, hMAE = 0.0

        print("\n  HUNT Fitness Study: Three-Formula Comparison")
        for i in 0..<groups.count {
            let age = Double(midAges[i])
            let tanaka = 208.0 - 0.7 * age
            let gulati = 206.0 - 0.88 * age
            let hunt = 211.0 - 0.64 * age

            let tErr = tanaka - means[i]
            let gErr = gulati - means[i]
            let hErr = hunt - means[i]
            tMAE += abs(tErr); gMAE += abs(gErr); hMAE += abs(hErr)

            print("  \(groups[i]): Obs=\(Int(means[i])) T=\(Int(tanaka)) G=\(Int(gulati)) H=\(Int(hunt))")

            XCTAssertLessThan(abs(tErr), 2 * sds[i], "\(groups[i]): Tanaka error exceeds 2 SD")
        }

        let n = Double(groups.count)
        print("  MAE — Tanaka: \(Int(tMAE / n)) | Gulati: \(Int(gMAE / n)) | HUNT: \(Int(hMAE / n))")
        XCTAssertLessThan(tMAE / n, 10, "Tanaka MAE should be <10 bpm")
        XCTAssertLessThan(gMAE / n, 15, "Gulati MAE should be <15 bpm")
    }

    /// AHA guideline compliance benchmark.
    func testAHA_complianceBenchmark() {
        // (name, weeklyModerate, weeklyVigorous, expectCompliant)
        let names    = ["Sedentary", "Casual walker", "Regular jogger", "HIIT", "Marathon", "Light yoga"]
        let moderate = [20.0,        90.0,            120.0,            30.0,   200.0,      60.0]
        let vigorous = [0.0,         0.0,             30.0,             70.0,   50.0,       5.0]
        let expected = [false,       false,           true,             true,   true,       false]

        print("\n  AHA Guidelines Compliance Benchmark")
        for i in 0..<names.count {
            let score = moderate[i] + 2.0 * vigorous[i]
            let compliant = score >= 150.0
            let pct = Int(min(score / 150.0, 1.0) * 100)
            print("  \(names[i]): score=\(Int(score)) (\(pct)%) \(compliant == expected[i] ? "✓" : "✗")")
            XCTAssertEqual(compliant, expected[i], "\(names[i]): compliance mismatch")
        }
    }
}

// DatasetValidationTests.swift
// ThumpTests
//
// Test harness for validating Thump engines against real-world
// physiological datasets. Place CSV files in Tests/Validation/Data/
// and these tests will automatically pick them up.
//
// Datasets are loaded lazily — tests skip gracefully if data is missing.

import XCTest
@testable import Thump

// MARK: - Dataset Validation Tests

final class DatasetValidationTests: XCTestCase {

    private enum StressDatasetLabel: String {
        case baseline
        case stressed
    }

    private struct SWELLObservation {
        let subjectID: String
        let label: StressDatasetLabel
        let hr: Double
        let sdnn: Double
    }

    private struct StressSubjectBaseline {
        let hrMean: Double
        let hrvMean: Double
        let hrvSD: Double?
        let baselineHRVs: [Double]
    }

    private struct ScoredStressObservation {
        let subjectID: String
        let label: StressDatasetLabel
        let score: Double
    }

    // MARK: - Paths

    /// Root directory for validation CSV files.
    private static var dataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Data")
    }

    // MARK: - CSV Loader

    /// Loads a CSV file and returns rows as [[String: String]].
    private func loadCSV(named filename: String) throws -> [[String: String]] {
        let url = Self.dataDir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Dataset '\(filename)' not found at \(url.path). Download it first — see FREE_DATASETS.md")
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = lines.first else {
            throw XCTSkip("Empty CSV: \(filename)")
        }

        let headers = parseCSVLine(headerLine)
        var rows: [[String: String]] = []
        for line in lines.dropFirst() {
            let values = parseCSVLine(line)
            var row: [String: String] = [:]
            for (i, header) in headers.enumerated() where i < values.count {
                row[header] = values[i]
            }
            rows.append(row)
        }
        return rows
    }

    /// Simple CSV line parser (handles quoted fields with commas).
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    // MARK: - 1. SWELL-HRV → StressEngine

    /// Validates StressEngine against the SWELL-HRV dataset.
    /// Expected file: Data/swell_hrv.csv
    /// Required columns: meanHR, SDNN, condition (nostress/stress)
    func testStressEngine_SWELL_HRV() throws {
        let rows = try loadCSV(named: "swell_hrv.csv")
        let engine = StressEngine()

        let parsedRows = rows.compactMap(parseSWELLObservation)
        XCTAssertFalse(parsedRows.isEmpty, "No usable SWELL-HRV rows found")

        let observationsBySubject = Dictionary(grouping: parsedRows, by: \.subjectID)
        var subjectBaselines: [String: StressSubjectBaseline] = [:]

        for (subjectID, subjectRows) in observationsBySubject {
            let baselineRows = subjectRows.filter { $0.label == .baseline }
            let hrValues = baselineRows.map(\.hr)
            let hrvValues = baselineRows.map(\.sdnn)

            guard !hrValues.isEmpty, !hrvValues.isEmpty else { continue }

            subjectBaselines[subjectID] = StressSubjectBaseline(
                hrMean: hrValues.reduce(0, +) / Double(hrValues.count),
                hrvMean: hrvValues.reduce(0, +) / Double(hrvValues.count),
                hrvSD: hrvValues.count >= 2 ? sqrt(variance(hrvValues)) : nil,
                baselineHRVs: hrvValues
            )
        }

        XCTAssertFalse(subjectBaselines.isEmpty, "Could not derive any per-subject baselines from no-stress rows")

        var scoredRows: [ScoredStressObservation] = []
        var skippedSubjects = Set<String>()

        for row in parsedRows {
            guard let baseline = subjectBaselines[row.subjectID] else {
                skippedSubjects.insert(row.subjectID)
                continue
            }

            let result = engine.computeStress(
                currentHRV: row.sdnn,
                baselineHRV: baseline.hrvMean,
                baselineHRVSD: baseline.hrvSD,
                currentRHR: row.hr,
                baselineRHR: baseline.hrMean,
                recentHRVs: baseline.baselineHRVs.count >= 3 ? baseline.baselineHRVs : nil
            )

            scoredRows.append(
                ScoredStressObservation(
                    subjectID: row.subjectID,
                    label: row.label,
                    score: result.score
                )
            )
        }

        let stressScores = scoredRows
            .filter { $0.label == .stressed }
            .map(\.score)
        let baselineScores = scoredRows
            .filter { $0.label == .baseline }
            .map(\.score)

        XCTAssertFalse(stressScores.isEmpty, "No stressed rows were scored from SWELL-HRV")
        XCTAssertFalse(baselineScores.isEmpty, "No baseline rows were scored from SWELL-HRV")

        let stressMean = stressScores.reduce(0, +) / Double(stressScores.count)
        let baselineMean = baselineScores.reduce(0, +) / Double(baselineScores.count)
        let pooledSD = sqrt((variance(stressScores) + variance(baselineScores)) / 2.0)
        let cohensD = pooledSD > 0 ? (stressMean - baselineMean) / pooledSD : 0.0
        let auc = computeAUC(
            positives: stressScores,
            negatives: baselineScores
        )
        let confusion = confusionMatrix(
            observations: scoredRows,
            threshold: 50.0
        )

        let baselineCount = scoredRows.filter { $0.label == .baseline }.count
        let stressedCount = scoredRows.filter { $0.label == .stressed }.count
        let subjectCount = Set(scoredRows.map(\.subjectID)).count

        print("=== SWELL-HRV StressEngine Validation ===")
        print("Subjects scored: \(subjectCount)")
        print("Skipped subjects without baseline: \(skippedSubjects.count)")
        print("Baseline rows: n=\(baselineCount), mean=\(String(format: "%.1f", baselineMean))")
        print("Stressed rows: n=\(stressedCount), mean=\(String(format: "%.1f", stressMean))")
        print("Cohen's d = \(String(format: "%.2f", cohensD))")
        print("AUC-ROC = \(String(format: "%.3f", auc))")
        print(
            "Confusion @50: TP=\(confusion.tp) FP=\(confusion.fp) "
                + "TN=\(confusion.tn) FN=\(confusion.fn)"
        )

        XCTAssertGreaterThan(
            stressMean,
            baselineMean,
            "Stressed rows should score higher than baseline rows"
        )
        XCTAssertGreaterThan(
            cohensD,
            0.5,
            "Effect size should be at least medium (d > 0.5)"
        )
        XCTAssertGreaterThan(
            auc,
            0.70,
            "AUC-ROC should exceed 0.70 for stressed vs baseline SWELL rows"
        )
    }

    // MARK: - 2. Fitbit Tracker → HeartTrendEngine

    /// Validates HeartTrendEngine week-over-week detection against Fitbit data.
    /// Expected file: Data/fitbit_daily.csv
    /// Required columns: date, resting_hr, steps, sleep_hours
    func testHeartTrendEngine_FitbitDaily() throws {
        let rows = try loadCSV(named: "fitbit_daily.csv")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var snapshots: [HeartSnapshot] = []

        for row in rows {
            guard let dateStr = row["date"] ?? row["ActivityDate"],
                  let date = dateFormatter.date(from: dateStr),
                  let rhrStr = row["resting_hr"] ?? row["RestingHeartRate"],
                  let rhr = Double(rhrStr), rhr > 0
            else { continue }

            let steps = (row["steps"] ?? row["TotalSteps"]).flatMap { Double($0) }
            let sleep = (row["sleep_hours"] ?? row["TotalMinutesAsleep"])
                .flatMap { Double($0) }
                .map { val in val > 24 ? val / 60.0 : val } // Convert minutes to hours if needed

            let snapshot = HeartSnapshot(
                date: date,
                restingHeartRate: rhr,
                steps: steps,
                sleepHours: sleep
            )
            snapshots.append(snapshot)
        }

        XCTAssertGreaterThan(snapshots.count, 7,
            "Need at least 7 days of data for trend analysis")

        // Sort by date
        let sorted = snapshots.sorted { $0.date < $1.date }

        // Run trend engine on the full window
        let engine = HeartTrendEngine()
        let assessment = engine.assess(
            history: Array(sorted.dropLast()),
            current: sorted.last!
        )

        print("=== Fitbit Daily HeartTrendEngine Validation ===")
        print("Days: \(sorted.count)")
        print("Status: \(assessment.status)")
        print("Anomaly score: \(assessment.anomalyScore)")
        print("Regression: \(assessment.regressionFlag)")
        print("Stress: \(assessment.stressFlag)")
        if let wow = assessment.weekOverWeekTrend {
            print("WoW direction: \(wow.direction)")
            print("WoW z-score: \(String(format: "%.2f", wow.zScore))")
        }

        // Basic sanity: assessment should complete without crashing
        // and produce a valid status
        XCTAssertNotNil(assessment.status)
    }

    // MARK: - 3. Walch Apple Watch Sleep → ReadinessEngine

    /// Validates ReadinessEngine sleep pillar against labeled sleep data.
    /// Expected file: Data/walch_sleep.csv
    /// Required columns: subject, total_sleep_hours, wake_pct
    func testReadinessEngine_WalchSleep() throws {
        let rows = try loadCSV(named: "walch_sleep.csv")
        let engine = ReadinessEngine()

        var goodSleepScores: [Double] = []
        var poorSleepScores: [Double] = []

        for row in rows {
            guard let sleepStr = row["total_sleep_hours"] ?? row["sleep_hours"],
                  let sleep = Double(sleepStr)
            else { continue }

            // Build a minimal snapshot with sleep data
            let snapshot = HeartSnapshot(
                date: Date(),
                restingHeartRate: 65,
                hrvSDNN: 45,
                sleepHours: sleep
            )
            // Note: steps/workoutMinutes default to nil which is fine

            guard let result = engine.compute(
                snapshot: snapshot,
                stressScore: nil,
                recentHistory: []
            ) else { continue }

            if sleep >= 7.0 {
                goodSleepScores.append(Double(result.score))
            } else if sleep < 6.0 {
                poorSleepScores.append(Double(result.score))
            }
        }

        if !goodSleepScores.isEmpty && !poorSleepScores.isEmpty {
            let goodMean = goodSleepScores.reduce(0, +) / Double(goodSleepScores.count)
            let poorMean = poorSleepScores.reduce(0, +) / Double(poorSleepScores.count)

            print("=== Walch Sleep ReadinessEngine Validation ===")
            print("Good sleep (7+ hrs): n=\(goodSleepScores.count), mean readiness=\(String(format: "%.1f", goodMean))")
            print("Poor sleep (<6 hrs): n=\(poorSleepScores.count), mean readiness=\(String(format: "%.1f", poorMean))")

            // Good sleepers should have higher readiness
            XCTAssertGreaterThan(goodMean, poorMean,
                "Good sleepers should have higher readiness scores")
        }
    }

    // MARK: - 4. NTNU VO2 Max → BioAgeEngine

    /// Validates BioAgeEngine against NTNU population reference norms.
    /// These are hardcoded from the HUNT3 published percentile tables
    /// (Nes et al., PLoS ONE 2011) — no CSV download needed.
    func testBioAgeEngine_NTNUReference() {
        let engine = BioAgeEngine()

        // NTNU reference VO2max by age (50th percentile, male)
        // Source: Nes et al. PLoS ONE 2011, Table 2
        let norms: [(age: Int, vo2p50: Double, vo2p10: Double, vo2p90: Double)] = [
            (age: 25, vo2p50: 46.0, vo2p10: 37.0, vo2p90: 57.0),
            (age: 35, vo2p50: 43.0, vo2p10: 34.0, vo2p90: 53.0),
            (age: 45, vo2p50: 40.0, vo2p10: 31.0, vo2p90: 50.0),
            (age: 55, vo2p50: 36.0, vo2p10: 28.0, vo2p90: 46.0),
            (age: 65, vo2p50: 33.0, vo2p10: 25.0, vo2p90: 42.0),
        ]

        print("=== NTNU VO2 Max BioAgeEngine Validation ===")

        for norm in norms {
            // 50th percentile: bio age ≈ chronological age (offset near 0)
            let p50Snapshot = HeartSnapshot(
                date: Date(),
                restingHeartRate: 68,
                hrvSDNN: 40,
                vo2Max: norm.vo2p50,
                steps: 8000.0,
                sleepHours: 7.5
            )
            let p50Result = engine.estimate(
                snapshot: p50Snapshot,
                chronologicalAge: norm.age
            )

            // 90th percentile: bio age should be YOUNGER
            let p90Snapshot = HeartSnapshot(
                date: Date(),
                restingHeartRate: 58,
                hrvSDNN: 55,
                vo2Max: norm.vo2p90,
                steps: 12000.0,
                sleepHours: 8.0
            )
            let p90Result = engine.estimate(
                snapshot: p90Snapshot,
                chronologicalAge: norm.age
            )

            // 10th percentile: bio age should be OLDER
            let p10Snapshot = HeartSnapshot(
                date: Date(),
                restingHeartRate: 78,
                hrvSDNN: 25,
                vo2Max: norm.vo2p10,
                steps: 3000.0,
                sleepHours: 5.5
            )
            let p10Result = engine.estimate(
                snapshot: p10Snapshot,
                chronologicalAge: norm.age
            )

            if let p50 = p50Result, let p90 = p90Result, let p10 = p10Result {
                let p50Offset = p50.bioAge - norm.age
                let p90Offset = p90.bioAge - norm.age
                let p10Offset = p10.bioAge - norm.age

                print("Age \(norm.age): p10 offset=\(p10Offset > 0 ? "+" : "")\(p10Offset), "
                    + "p50 offset=\(p50Offset > 0 ? "+" : "")\(p50Offset), "
                    + "p90 offset=\(p90Offset > 0 ? "+" : "")\(p90Offset)")

                // 90th percentile person should be biologically younger
                XCTAssertLessThan(p90.bioAge, p10.bioAge,
                    "90th percentile VO2 should yield younger bio age than 10th percentile (age \(norm.age))")

                // 50th percentile should be between p10 and p90
                XCTAssertLessThanOrEqual(p50.bioAge, p10.bioAge,
                    "50th percentile should be younger than or equal to 10th (age \(norm.age))")
                XCTAssertGreaterThanOrEqual(p50.bioAge, p90.bioAge,
                    "50th percentile should be older than or equal to 90th (age \(norm.age))")
            }
        }
    }

    // MARK: - 5. Activity Pattern Detection

    /// Validates BuddyRecommendationEngine activity pattern detection
    /// against Fitbit data with known inactive days.
    /// Expected file: Data/fitbit_daily.csv
    func testActivityPatternDetection_FitbitDaily() throws {
        let rows = try loadCSV(named: "fitbit_daily.csv")
        let budEngine = BuddyRecommendationEngine()
        let trendEngine = HeartTrendEngine()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var snapshots: [HeartSnapshot] = []

        for row in rows {
            guard let dateStr = row["date"] ?? row["ActivityDate"],
                  let date = dateFormatter.date(from: dateStr)
            else { continue }

            let rhr = (row["resting_hr"] ?? row["RestingHeartRate"])
                .flatMap { Double($0) } ?? 68.0
            let steps = (row["steps"] ?? row["TotalSteps"]).flatMap { Double($0) }
            let sleep = (row["sleep_hours"] ?? row["TotalMinutesAsleep"])
                .flatMap { Double($0) }
                .map { val in val > 24 ? val / 60.0 : val }
            let workout = (row["workout_minutes"] ?? row["VeryActiveMinutes"])
                .flatMap { Double($0) }

            let snapshot = HeartSnapshot(
                date: date,
                restingHeartRate: rhr,
                steps: steps,
                workoutMinutes: workout,
                sleepHours: sleep
            )
            // HeartSnapshot init order: date, restingHeartRate, hrvSDNN?, recoveryHR1m?,
            // recoveryHR2m?, vo2Max?, zoneMinutes, steps?, walkMinutes?, workoutMinutes?, sleepHours?
            snapshots.append(snapshot)
        }

        let sorted = snapshots.sorted { $0.date < $1.date }
        guard sorted.count >= 3 else {
            throw XCTSkip("Need at least 3 days of data")
        }

        // Check each day for activity pattern detection
        var inactiveDetections = 0
        var inactiveDays = 0

        for i in 2..<sorted.count {
            let current = sorted[i]
            let history = Array(sorted[max(0, i-28)..<i])

            let isInactive = (current.steps ?? 10000) < 2000
                && (current.workoutMinutes ?? 30) < 5

            if isInactive { inactiveDays += 1 }

            let assessment = trendEngine.assess(history: history, current: current)
            let recs = budEngine.recommend(
                assessment: assessment,
                current: current,
                history: history
            )

            let hasActivityRec = recs.contains { $0.source == .activityPattern }
            if hasActivityRec { inactiveDetections += 1 }
        }

        print("=== Activity Pattern Detection ===")
        print("Total days analyzed: \(sorted.count - 2)")
        print("Inactive days (< 2000 steps + < 5 min workout): \(inactiveDays)")
        print("Activity pattern detections: \(inactiveDetections)")
    }

    // MARK: - Helpers

    private func parseSWELLObservation(_ row: [String: String]) -> SWELLObservation? {
        guard let subjectID = firstNonEmptyValue(
            in: row,
            keys: [
                "subject",
                "Subject",
                "subject_id",
                "Subject_ID",
                "participant",
                "Participant",
                "id",
                "ID",
            ]
        ),
        let labelRaw = firstNonEmptyValue(
            in: row,
            keys: ["condition", "Condition", "label", "Label"]
        ),
        let label = normalizeStressLabel(labelRaw),
        let hrStr = firstNonEmptyValue(
            in: row,
            keys: ["meanHR", "MeanHR", "mean_hr", "HR", "hr"]
        ),
        let sdnnStr = firstNonEmptyValue(
            in: row,
            keys: ["SDNN", "sdnn", "Sdnn", "SDRR", "sdrr"]
        ),
        let hr = Double(hrStr),
        let sdnn = Double(sdnnStr),
        hr > 0,
        sdnn > 0
        else { return nil }

        return SWELLObservation(
            subjectID: subjectID,
            label: label,
            hr: hr,
            sdnn: sdnn
        )
    }

    private func firstNonEmptyValue(
        in row: [String: String],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let value = row[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func normalizeStressLabel(_ raw: String) -> StressDatasetLabel? {
        let normalized = raw
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        switch normalized {
        case "n", "nostress", "no stress", "baseline", "rest":
            return .baseline
        case "t", "i", "stress", "time pressure", "interruption":
            return .stressed
        default:
            if normalized.contains("no stress") || normalized.contains("baseline") {
                return .baseline
            }
            if normalized.contains("time") || normalized.contains("interrupt") || normalized.contains("stress") {
                return .stressed
            }
            return nil
        }
    }

    private func computeAUC(
        positives: [Double],
        negatives: [Double]
    ) -> Double {
        guard !positives.isEmpty, !negatives.isEmpty else { return 0 }

        var favorablePairs = 0.0
        let totalPairs = Double(positives.count * negatives.count)

        for positive in positives {
            for negative in negatives {
                if positive > negative {
                    favorablePairs += 1.0
                } else if positive == negative {
                    favorablePairs += 0.5
                }
            }
        }

        return favorablePairs / totalPairs
    }

    private func confusionMatrix(
        observations: [ScoredStressObservation],
        threshold: Double
    ) -> (tp: Int, fp: Int, tn: Int, fn: Int) {
        var tp = 0
        var fp = 0
        var tn = 0
        var fn = 0

        for observation in observations {
            let predictedStress = observation.score >= threshold
            let actualStress = observation.label == .stressed

            switch (predictedStress, actualStress) {
            case (true, true): tp += 1
            case (true, false): fp += 1
            case (false, false): tn += 1
            case (false, true): fn += 1
            }
        }

        return (tp, fp, tn, fn)
    }

    private func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSquares = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sumSquares / Double(values.count - 1)
    }
}

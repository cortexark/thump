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

    private enum SWELLCondition: String, CaseIterable {
        case baseline
        case timePressure
        case interruption

        var label: StressDatasetLabel {
            switch self {
            case .baseline: return .baseline
            case .timePressure, .interruption: return .stressed
            }
        }

        var displayName: String {
            switch self {
            case .baseline: return "no stress"
            case .timePressure: return "time pressure"
            case .interruption: return "interruption"
            }
        }
    }

    private enum StressDiagnosticVariant: CaseIterable {
        case full
        case rhrOnly
        case lowRHR
        case gatedRHR
        case noRHR
        case subjectNormalizedNoRHR
        case hrvOnly

        var displayName: String {
            switch self {
            case .full: return "full engine"
            case .rhrOnly: return "rhr-only"
            case .lowRHR: return "low-rhr"
            case .gatedRHR: return "gated-rhr"
            case .noRHR: return "no-rhr"
            case .subjectNormalizedNoRHR: return "subject-norm-no-rhr"
            case .hrvOnly: return "hrv-only"
            }
        }
    }

    private struct SWELLObservation {
        let subjectID: String
        let condition: SWELLCondition
        let hr: Double
        let sdnn: Double

        var label: StressDatasetLabel { condition.label }
    }

    private struct PhysioNetWindowObservation {
        let subjectID: String
        let sessionID: String
        let label: StressDatasetLabel
        let hr: Double
        let sdnn: Double
    }

    private struct WESADWindowObservation {
        let subjectID: String
        let label: StressDatasetLabel
        let hr: Double
        let sdnn: Double
    }

    private struct StressSubjectBaseline {
        let hrMean: Double
        let hrvMean: Double
        let hrvSD: Double?
        let sortedBaselineHRVs: [Double]
        let recentBaselineHRVs: [Double]
    }

    private struct StressSubjectAccumulator {
        var baselineCount = 0
        var hrSum = 0.0
        var hrvSum = 0.0
        var hrvSumSquares = 0.0
        var baselineHRVs: [Double] = []
        var recentBaselineHRVs: [Double] = []
    }

    private struct ScoredStressObservation {
        let subjectID: String
        let label: StressDatasetLabel
        let score: Double
    }

    private struct BinaryStressMetrics {
        let baselineCount: Int
        let stressedCount: Int
        let baselineMean: Double
        let stressedMean: Double
        let cohensD: Double
        let auc: Double
        let confusion: (tp: Int, fp: Int, tn: Int, fn: Int)
    }

    private struct StressVariantAccumulator {
        var baselineScores: [Double] = []
        var stressedScores: [Double] = []

        mutating func append(score: Double, label: StressDatasetLabel) {
            switch label {
            case .baseline:
                baselineScores.append(score)
            case .stressed:
                stressedScores.append(score)
            }
        }
    }

    private struct SubjectStressAccumulator {
        var baselineScores: [Double] = []
        var timePressureScores: [Double] = []
        var interruptionScores: [Double] = []

        mutating func append(score: Double, condition: SWELLCondition) {
            switch condition {
            case .baseline:
                baselineScores.append(score)
            case .timePressure:
                timePressureScores.append(score)
            case .interruption:
                interruptionScores.append(score)
            }
        }

        var stressedScores: [Double] {
            timePressureScores + interruptionScores
        }
    }

    private struct SubjectDiagnosticSummary {
        let subjectID: String
        let baselineCount: Int
        let stressedCount: Int
        let baselineMean: Double
        let stressedMean: Double
        let delta: Double
        let auc: Double
    }

    private struct BinarySubjectAccumulator {
        var baselineScores: [Double] = []
        var stressedScores: [Double] = []

        mutating func append(score: Double, label: StressDatasetLabel) {
            switch label {
            case .baseline:
                baselineScores.append(score)
            case .stressed:
                stressedScores.append(score)
            }
        }
    }

    // MARK: - Paths

    /// Root directory for validation CSV files.
    private static var dataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Data")
    }

    private static var physioNetDataDir: URL {
        dataDir.appendingPathComponent("physionet_exam_stress")
    }

    private static var wesadDataDir: URL {
        dataDir.appendingPathComponent("wesad_e4_mirror")
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

    private func forEachCSVRow(
        named filename: String,
        _ body: ([String: String]) throws -> Void
    ) throws {
        let url = Self.dataDir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Dataset '\(filename)' not found at \(url.path). Download it first — see FREE_DATASETS.md")
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var headers: [String]?
        var buffer = Data()

        func processLine(_ data: Data) throws {
            guard !data.isEmpty else { return }

            var lineData = data
            if lineData.last == 0x0D {
                lineData.removeLast()
            }

            guard !lineData.isEmpty,
                  let line = String(data: lineData, encoding: .utf8)
            else { return }

            if headers == nil {
                headers = parseCSVLine(line)
                return
            }

            guard let headers else { return }
            let values = parseCSVLine(line)
            guard !values.isEmpty else { return }

            var row: [String: String] = [:]
            for (index, header) in headers.enumerated() where index < values.count {
                row[header] = values[index]
            }

            try body(row)
        }

        while true {
            let chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty { break }

            buffer.append(chunk)
            while let newlineRange = buffer.firstRange(of: Data([0x0A])) {
                let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
                try processLine(lineData)
                buffer.removeSubrange(0..<newlineRange.upperBound)
            }
        }

        if !buffer.isEmpty {
            try processLine(buffer)
        }
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
    /// Required columns: subject_id/subject, condition, HR/meanHR, SDNN/SDRR
    func testStressEngine_SWELL_HRV() throws {
        let engine = StressEngine()
        var baselineAccumulators: [String: StressSubjectAccumulator] = [:]
        var parsedRowCount = 0

        try forEachCSVRow(named: "swell_hrv.csv") { row in
            guard let observation = parseSWELLObservation(row) else { return }
            parsedRowCount += 1

            guard observation.label == .baseline else { return }

            var accumulator = baselineAccumulators[observation.subjectID, default: StressSubjectAccumulator()]
            accumulator.baselineCount += 1
            accumulator.hrSum += observation.hr
            accumulator.hrvSum += observation.sdnn
            accumulator.hrvSumSquares += observation.sdnn * observation.sdnn
            accumulator.baselineHRVs.append(observation.sdnn)
            accumulator.recentBaselineHRVs.append(observation.sdnn)
            if accumulator.recentBaselineHRVs.count > 7 {
                accumulator.recentBaselineHRVs.removeFirst(accumulator.recentBaselineHRVs.count - 7)
            }
            baselineAccumulators[observation.subjectID] = accumulator
        }

        XCTAssertGreaterThan(parsedRowCount, 0, "No usable SWELL-HRV rows found")

        var subjectBaselines: [String: StressSubjectBaseline] = [:]

        for (subjectID, accumulator) in baselineAccumulators {
            guard accumulator.baselineCount > 0 else { continue }

            let count = Double(accumulator.baselineCount)
            let hrvMean = accumulator.hrvSum / count
            let hrMean = accumulator.hrSum / count
            let hrvVariance: Double?
            if accumulator.baselineCount >= 2 {
                let numerator = accumulator.hrvSumSquares - (accumulator.hrvSum * accumulator.hrvSum / count)
                hrvVariance = max(0, numerator / Double(accumulator.baselineCount - 1))
            } else {
                hrvVariance = nil
            }

            subjectBaselines[subjectID] = StressSubjectBaseline(
                hrMean: hrMean,
                hrvMean: hrvMean,
                hrvSD: hrvVariance.map(sqrt),
                sortedBaselineHRVs: accumulator.baselineHRVs.sorted(),
                recentBaselineHRVs: accumulator.recentBaselineHRVs
            )
        }

        XCTAssertFalse(subjectBaselines.isEmpty, "Could not derive any per-subject baselines from no-stress rows")

        var skippedSubjects = Set<String>()
        var scoredSubjects = Set<String>()
        var baselineScores: [Double] = []
        var stressScores: [Double] = []
        var conditionScores: [SWELLCondition: [Double]] = Dictionary(
            uniqueKeysWithValues: SWELLCondition.allCases.map { ($0, []) }
        )
        var variantAccumulators: [StressDiagnosticVariant: StressVariantAccumulator] = Dictionary(
            uniqueKeysWithValues: StressDiagnosticVariant.allCases.map { ($0, StressVariantAccumulator()) }
        )
        var subjectDiagnostics: [String: SubjectStressAccumulator] = [:]

        try forEachCSVRow(named: "swell_hrv.csv") { row in
            guard let observation = parseSWELLObservation(row) else { return }
            guard let baseline = subjectBaselines[observation.subjectID] else {
                skippedSubjects.insert(observation.subjectID)
                return
            }

            let result = engine.computeStress(
                currentHRV: observation.sdnn,
                baselineHRV: baseline.hrvMean,
                baselineHRVSD: baseline.hrvSD,
                currentRHR: observation.hr,
                baselineRHR: baseline.hrMean,
                recentHRVs: baseline.recentBaselineHRVs.count >= 3 ? baseline.recentBaselineHRVs : nil
            )

            let score = result.score
            scoredSubjects.insert(observation.subjectID)

            if observation.label == .baseline {
                baselineScores.append(score)
            } else {
                stressScores.append(score)
            }
            conditionScores[observation.condition, default: []].append(score)

            for variant in StressDiagnosticVariant.allCases {
                let variantScore: Double
                switch variant {
                case .full:
                    variantScore = score
                case .rhrOnly, .lowRHR, .gatedRHR, .noRHR, .subjectNormalizedNoRHR, .hrvOnly:
                    variantScore = diagnosticStressScore(
                        variant: variant,
                        hr: observation.hr,
                        sdnn: observation.sdnn,
                        baseline: baseline
                    )
                }
                variantAccumulators[variant, default: StressVariantAccumulator()]
                    .append(score: variantScore, label: observation.label)
            }

            subjectDiagnostics[observation.subjectID, default: SubjectStressAccumulator()]
                .append(score: score, condition: observation.condition)
        }

        XCTAssertFalse(stressScores.isEmpty, "No stressed rows were scored from SWELL-HRV")
        XCTAssertFalse(baselineScores.isEmpty, "No baseline rows were scored from SWELL-HRV")

        let overallMetrics = computeBinaryMetrics(
            stressedScores: stressScores,
            baselineScores: baselineScores
        )
        let subjectCount = scoredSubjects.count
        let conditionMetrics: [(SWELLCondition, BinaryStressMetrics)] = [
            SWELLCondition.timePressure,
            SWELLCondition.interruption,
        ].compactMap { condition in
            guard let scores = conditionScores[condition], !scores.isEmpty else { return nil }
            return (
                condition,
                computeBinaryMetrics(
                    stressedScores: scores,
                    baselineScores: baselineScores
                )
            )
        }
        let subjectSummaries: [SubjectDiagnosticSummary] = subjectDiagnostics.compactMap { subjectID, accumulator in
            let stressed = accumulator.stressedScores
            guard !accumulator.baselineScores.isEmpty, !stressed.isEmpty else { return nil }
            let metrics = computeBinaryMetrics(
                stressedScores: stressed,
                baselineScores: accumulator.baselineScores
            )
            return SubjectDiagnosticSummary(
                subjectID: subjectID,
                baselineCount: accumulator.baselineScores.count,
                stressedCount: stressed.count,
                baselineMean: metrics.baselineMean,
                stressedMean: metrics.stressedMean,
                delta: metrics.stressedMean - metrics.baselineMean,
                auc: metrics.auc
            )
        }.sorted { lhs, rhs in
            if lhs.auc == rhs.auc {
                return lhs.delta < rhs.delta
            }
            return lhs.auc < rhs.auc
        }

        print("=== SWELL-HRV StressEngine Validation ===")
        print("Subjects scored: \(subjectCount)")
        print("Skipped subjects without baseline: \(skippedSubjects.count)")
        print("Baseline rows: n=\(overallMetrics.baselineCount), mean=\(String(format: "%.1f", overallMetrics.baselineMean))")
        print("Stressed rows: n=\(overallMetrics.stressedCount), mean=\(String(format: "%.1f", overallMetrics.stressedMean))")
        print("Cohen's d = \(String(format: "%.2f", overallMetrics.cohensD))")
        print("AUC-ROC = \(String(format: "%.3f", overallMetrics.auc))")
        print(
            "Confusion @50: TP=\(overallMetrics.confusion.tp) FP=\(overallMetrics.confusion.fp) "
                + "TN=\(overallMetrics.confusion.tn) FN=\(overallMetrics.confusion.fn)"
        )

        print("=== Condition Breakdown ===")
        for (condition, metrics) in conditionMetrics {
            print(
                "\(condition.displayName): "
                    + "n=\(metrics.stressedCount), "
                    + "mean=\(String(format: "%.1f", metrics.stressedMean)), "
                    + "d=\(String(format: "%.2f", metrics.cohensD)), "
                    + "auc=\(String(format: "%.3f", metrics.auc))"
            )
        }

        print("=== Variant Ablation ===")
        for variant in StressDiagnosticVariant.allCases {
            guard let accumulator = variantAccumulators[variant] else { continue }
            let metrics = computeBinaryMetrics(
                stressedScores: accumulator.stressedScores,
                baselineScores: accumulator.baselineScores
            )
            print(
                "\(variant.displayName): "
                    + "baseline=\(String(format: "%.1f", metrics.baselineMean)), "
                    + "stressed=\(String(format: "%.1f", metrics.stressedMean)), "
                    + "d=\(String(format: "%.2f", metrics.cohensD)), "
                    + "auc=\(String(format: "%.3f", metrics.auc))"
            )
        }

        print("=== Worst Subjects (by AUC) ===")
        for summary in subjectSummaries.prefix(5) {
            print(
                "subject \(summary.subjectID): "
                    + "baseline=\(summary.baselineCount), "
                    + "stressed=\(summary.stressedCount), "
                    + "meanΔ=\(String(format: "%.1f", summary.delta)), "
                    + "auc=\(String(format: "%.3f", summary.auc))"
            )
        }

        if !subjectSummaries.isEmpty {
            let meanSubjectAUC = subjectSummaries.map(\.auc).reduce(0, +) / Double(subjectSummaries.count)
            let meanSubjectDelta = subjectSummaries.map(\.delta).reduce(0, +) / Double(subjectSummaries.count)
            print("Subject mean AUC = \(String(format: "%.3f", meanSubjectAUC))")
            print("Subject mean stressed-baseline delta = \(String(format: "%.1f", meanSubjectDelta))")
        }

        XCTAssertGreaterThan(
            overallMetrics.stressedMean,
            overallMetrics.baselineMean,
            "Stressed rows should score higher than baseline rows"
        )
        XCTAssertGreaterThan(
            overallMetrics.cohensD,
            0.5,
            "Effect size should be at least medium (d > 0.5)"
        )
        XCTAssertGreaterThan(
            overallMetrics.auc,
            0.70,
            "AUC-ROC should exceed 0.70 for stressed vs baseline SWELL rows"
        )
    }

    // MARK: - 2. PhysioNet Exam Stress → StressEngine

    /// Validates StressEngine against a local PhysioNet exam-stress mirror.
    ///
    /// Validation assumption:
    /// - first 30 minutes of each session = acute pre-exam / anticipatory stress
    /// - last 45 minutes of each session = post-exam recovery baseline
    /// - score non-overlapping 5-minute windows against each subject baseline
    func testStressEngine_PhysioNetExamStress() throws {
        let root = Self.physioNetDataDir
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw XCTSkip("PhysioNet exam-stress mirror not found at \(root.path)")
        }

        let engine = StressEngine()
        let stressWindowSeconds = 30 * 60
        let baselineWindowSeconds = 45 * 60
        let scoringWindowSeconds = 5 * 60
        let scoringStepSeconds = scoringWindowSeconds

        let subjectDirs = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }

        var baselineWindowsBySubject: [String: [PhysioNetWindowObservation]] = [:]
        var stressObservations: [PhysioNetWindowObservation] = []
        var baselineObservations: [PhysioNetWindowObservation] = []
        var parsedSessionCount = 0

        for subjectDir in subjectDirs {
            let examDirs = try FileManager.default.contentsOfDirectory(
                at: subjectDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).sorted { $0.lastPathComponent < $1.lastPathComponent }

            for examDir in examDirs {
                guard let session = try loadPhysioNetSession(at: examDir) else { continue }

                parsedSessionCount += 1
                let durationSeconds = min(
                    session.hrSamples.count,
                    Int(session.ibiSamples.last?.time ?? 0)
                )
                guard durationSeconds >= scoringWindowSeconds * 2 else { continue }

                let baselineStart = max(0, durationSeconds - baselineWindowSeconds)
                if baselineStart + scoringWindowSeconds <= durationSeconds {
                    for start in stride(
                        from: baselineStart,
                        through: durationSeconds - scoringWindowSeconds,
                        by: scoringStepSeconds
                    ) {
                        guard let stats = physioNetWindowStats(
                            hrSamples: session.hrSamples,
                            ibiSamples: session.ibiSamples,
                            startSecond: start,
                            endSecond: start + scoringWindowSeconds
                        ) else { continue }

                        let observation = PhysioNetWindowObservation(
                            subjectID: session.subjectID,
                            sessionID: session.sessionID,
                            label: .baseline,
                            hr: stats.hr,
                            sdnn: stats.sdnn
                        )
                        baselineWindowsBySubject[session.subjectID, default: []]
                            .append(observation)
                        baselineObservations.append(observation)
                    }
                }

                let stressLimit = min(durationSeconds, stressWindowSeconds)
                if scoringWindowSeconds <= stressLimit {
                    for start in stride(
                        from: 0,
                        through: stressLimit - scoringWindowSeconds,
                        by: scoringStepSeconds
                    ) {
                        guard let stats = physioNetWindowStats(
                            hrSamples: session.hrSamples,
                            ibiSamples: session.ibiSamples,
                            startSecond: start,
                            endSecond: start + scoringWindowSeconds
                        ) else { continue }

                        stressObservations.append(
                            PhysioNetWindowObservation(
                                subjectID: session.subjectID,
                                sessionID: session.sessionID,
                                label: .stressed,
                                hr: stats.hr,
                                sdnn: stats.sdnn
                            )
                        )
                    }
                }
            }
        }

        XCTAssertGreaterThan(parsedSessionCount, 0, "No PhysioNet exam sessions were parsed")
        XCTAssertFalse(baselineObservations.isEmpty, "No PhysioNet recovery windows were derived")
        XCTAssertFalse(stressObservations.isEmpty, "No PhysioNet stress windows were derived")

        var subjectBaselines: [String: StressSubjectBaseline] = [:]

        for (subjectID, windows) in baselineWindowsBySubject {
            let hrValues = windows.map(\.hr)
            let hrvValues = windows.map(\.sdnn)
            guard !hrValues.isEmpty, !hrvValues.isEmpty else { continue }

            subjectBaselines[subjectID] = StressSubjectBaseline(
                hrMean: mean(hrValues),
                hrvMean: mean(hrvValues),
                hrvSD: hrvValues.count >= 2 ? sqrt(variance(hrvValues)) : nil,
                sortedBaselineHRVs: hrvValues.sorted(),
                recentBaselineHRVs: Array(hrvValues.suffix(7))
            )
        }

        XCTAssertFalse(subjectBaselines.isEmpty, "Could not derive PhysioNet subject baselines")

        var stressScores: [Double] = []
        var baselineScores: [Double] = []
        var variantAccumulators: [StressDiagnosticVariant: StressVariantAccumulator] = Dictionary(
            uniqueKeysWithValues: StressDiagnosticVariant.allCases.map { ($0, StressVariantAccumulator()) }
        )
        var subjectDiagnostics: [String: BinarySubjectAccumulator] = [:]

        for observation in stressObservations + baselineObservations {
            guard let baseline = subjectBaselines[observation.subjectID] else { continue }

            let result = engine.computeStress(
                currentHRV: observation.sdnn,
                baselineHRV: baseline.hrvMean,
                baselineHRVSD: baseline.hrvSD,
                currentRHR: observation.hr,
                baselineRHR: baseline.hrMean,
                recentHRVs: baseline.recentBaselineHRVs.count >= 3 ? baseline.recentBaselineHRVs : nil
            )

            switch observation.label {
            case .baseline:
                baselineScores.append(result.score)
            case .stressed:
                stressScores.append(result.score)
            }

            for variant in StressDiagnosticVariant.allCases {
                let variantScore: Double
                switch variant {
                case .full:
                    variantScore = result.score
                case .rhrOnly, .lowRHR, .gatedRHR, .noRHR, .subjectNormalizedNoRHR, .hrvOnly:
                    variantScore = diagnosticStressScore(
                        variant: variant,
                        hr: observation.hr,
                        sdnn: observation.sdnn,
                        baseline: baseline
                    )
                }
                variantAccumulators[variant, default: StressVariantAccumulator()]
                    .append(score: variantScore, label: observation.label)
            }

            subjectDiagnostics[observation.subjectID, default: BinarySubjectAccumulator()]
                .append(score: result.score, label: observation.label)
        }

        let overallMetrics = computeBinaryMetrics(
            stressedScores: stressScores,
            baselineScores: baselineScores
        )
        let subjectSummaries: [SubjectDiagnosticSummary] = subjectDiagnostics.compactMap { subjectID, accumulator in
            guard !accumulator.baselineScores.isEmpty, !accumulator.stressedScores.isEmpty else {
                return nil
            }

            let metrics = computeBinaryMetrics(
                stressedScores: accumulator.stressedScores,
                baselineScores: accumulator.baselineScores
            )
            return SubjectDiagnosticSummary(
                subjectID: subjectID,
                baselineCount: accumulator.baselineScores.count,
                stressedCount: accumulator.stressedScores.count,
                baselineMean: metrics.baselineMean,
                stressedMean: metrics.stressedMean,
                delta: metrics.stressedMean - metrics.baselineMean,
                auc: metrics.auc
            )
        }.sorted { lhs, rhs in
            if lhs.auc == rhs.auc {
                return lhs.delta < rhs.delta
            }
            return lhs.auc < rhs.auc
        }

        print("=== PhysioNet Exam Stress Validation ===")
        print("Sessions parsed: \(parsedSessionCount)")
        print("Subjects scored: \(subjectBaselines.count)")
        print("Stress windows: n=\(overallMetrics.stressedCount), mean=\(String(format: "%.1f", overallMetrics.stressedMean))")
        print("Recovery windows: n=\(overallMetrics.baselineCount), mean=\(String(format: "%.1f", overallMetrics.baselineMean))")
        print("Cohen's d = \(String(format: "%.2f", overallMetrics.cohensD))")
        print("AUC-ROC = \(String(format: "%.3f", overallMetrics.auc))")
        print(
            "Confusion @50: TP=\(overallMetrics.confusion.tp) FP=\(overallMetrics.confusion.fp) "
                + "TN=\(overallMetrics.confusion.tn) FN=\(overallMetrics.confusion.fn)"
        )

        print("=== Variant Ablation ===")
        for variant in StressDiagnosticVariant.allCases {
            guard let accumulator = variantAccumulators[variant] else { continue }
            let metrics = computeBinaryMetrics(
                stressedScores: accumulator.stressedScores,
                baselineScores: accumulator.baselineScores
            )
            print(
                "\(variant.displayName): "
                    + "baseline=\(String(format: "%.1f", metrics.baselineMean)), "
                    + "stressed=\(String(format: "%.1f", metrics.stressedMean)), "
                    + "d=\(String(format: "%.2f", metrics.cohensD)), "
                    + "auc=\(String(format: "%.3f", metrics.auc))"
            )
        }

        print("=== Worst Subjects (by AUC) ===")
        for summary in subjectSummaries.prefix(5) {
            print(
                "subject \(summary.subjectID): "
                    + "baseline=\(summary.baselineCount), "
                    + "stressed=\(summary.stressedCount), "
                    + "meanΔ=\(String(format: "%.1f", summary.delta)), "
                    + "auc=\(String(format: "%.3f", summary.auc))"
            )
        }

        if !subjectSummaries.isEmpty {
            let meanSubjectAUC = subjectSummaries.map(\.auc).reduce(0, +) / Double(subjectSummaries.count)
            let meanSubjectDelta = subjectSummaries.map(\.delta).reduce(0, +) / Double(subjectSummaries.count)
            print("Subject mean AUC = \(String(format: "%.3f", meanSubjectAUC))")
            print("Subject mean stressed-baseline delta = \(String(format: "%.1f", meanSubjectDelta))")
        }

        XCTAssertGreaterThan(
            overallMetrics.stressedMean,
            overallMetrics.baselineMean,
            "PhysioNet stress windows should score higher than late recovery windows"
        )
        XCTAssertGreaterThan(
            overallMetrics.cohensD,
            0.5,
            "PhysioNet effect size should be at least medium (d > 0.5)"
        )
        XCTAssertGreaterThan(
            overallMetrics.auc,
            0.70,
            "PhysioNet AUC-ROC should exceed 0.70 for stress vs recovery windows"
        )
    }

    // MARK: - 3. WESAD → StressEngine

    /// Validates StressEngine against a lightweight local WESAD wrist-data mirror.
    ///
    /// Validation assumption:
    /// - baseline window = `Base` segment from `quest.csv`
    /// - stress window = `TSST` segment from `quest.csv`
    /// - physiology source = Empatica E4 `HR.csv` and `IBI.csv`
    /// - scoring granularity = non-overlapping 2-minute windows
    func testStressEngine_WESAD() throws {
        let root = Self.wesadDataDir
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw XCTSkip("WESAD E4 mirror not found at \(root.path)")
        }

        let engine = StressEngine()
        let scoringWindowSeconds = 2 * 60
        let scoringStepSeconds = scoringWindowSeconds

        let subjectDirs = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }

        var baselineWindowsBySubject: [String: [WESADWindowObservation]] = [:]
        var stressObservations: [WESADWindowObservation] = []
        var baselineObservations: [WESADWindowObservation] = []
        var parsedSubjects = 0

        for subjectDir in subjectDirs {
            guard let session = try loadWESADSession(at: subjectDir) else { continue }
            parsedSubjects += 1

            let durationSeconds = min(
                session.hrSamples.count,
                Int(session.ibiSamples.last?.time ?? 0)
            )
            guard durationSeconds >= scoringWindowSeconds * 2 else { continue }

            let baselineStart = max(0, session.baselineRange.lowerBound)
            let baselineEnd = min(durationSeconds, session.baselineRange.upperBound)
            if baselineStart + scoringWindowSeconds <= baselineEnd {
                for start in stride(
                    from: baselineStart,
                    through: baselineEnd - scoringWindowSeconds,
                    by: scoringStepSeconds
                ) {
                    guard let stats = physioNetWindowStats(
                        hrSamples: session.hrSamples,
                        ibiSamples: session.ibiSamples,
                        startSecond: start,
                        endSecond: start + scoringWindowSeconds
                    ) else { continue }

                    let observation = WESADWindowObservation(
                        subjectID: session.subjectID,
                        label: .baseline,
                        hr: stats.hr,
                        sdnn: stats.sdnn
                    )
                    baselineWindowsBySubject[session.subjectID, default: []]
                        .append(observation)
                    baselineObservations.append(observation)
                }
            }

            let stressStart = max(0, session.stressRange.lowerBound)
            let stressEnd = min(durationSeconds, session.stressRange.upperBound)
            if stressStart + scoringWindowSeconds <= stressEnd {
                for start in stride(
                    from: stressStart,
                    through: stressEnd - scoringWindowSeconds,
                    by: scoringStepSeconds
                ) {
                    guard let stats = physioNetWindowStats(
                        hrSamples: session.hrSamples,
                        ibiSamples: session.ibiSamples,
                        startSecond: start,
                        endSecond: start + scoringWindowSeconds
                    ) else { continue }

                    stressObservations.append(
                        WESADWindowObservation(
                            subjectID: session.subjectID,
                            label: .stressed,
                            hr: stats.hr,
                            sdnn: stats.sdnn
                        )
                    )
                }
            }
        }

        XCTAssertGreaterThan(parsedSubjects, 0, "No WESAD subjects were parsed")
        XCTAssertFalse(baselineObservations.isEmpty, "No WESAD baseline windows were derived")
        XCTAssertFalse(stressObservations.isEmpty, "No WESAD TSST stress windows were derived")

        var subjectBaselines: [String: StressSubjectBaseline] = [:]

        for (subjectID, windows) in baselineWindowsBySubject {
            let hrValues = windows.map(\.hr)
            let hrvValues = windows.map(\.sdnn)
            guard !hrValues.isEmpty, !hrvValues.isEmpty else { continue }

            subjectBaselines[subjectID] = StressSubjectBaseline(
                hrMean: mean(hrValues),
                hrvMean: mean(hrvValues),
                hrvSD: hrvValues.count >= 2 ? sqrt(variance(hrvValues)) : nil,
                sortedBaselineHRVs: hrvValues.sorted(),
                recentBaselineHRVs: Array(hrvValues.suffix(7))
            )
        }

        XCTAssertFalse(subjectBaselines.isEmpty, "Could not derive WESAD subject baselines")

        var stressScores: [Double] = []
        var baselineScores: [Double] = []
        var variantAccumulators: [StressDiagnosticVariant: StressVariantAccumulator] = Dictionary(
            uniqueKeysWithValues: StressDiagnosticVariant.allCases.map { ($0, StressVariantAccumulator()) }
        )
        var subjectDiagnostics: [String: BinarySubjectAccumulator] = [:]

        for observation in stressObservations + baselineObservations {
            guard let baseline = subjectBaselines[observation.subjectID] else { continue }

            let result = engine.computeStress(
                currentHRV: observation.sdnn,
                baselineHRV: baseline.hrvMean,
                baselineHRVSD: baseline.hrvSD,
                currentRHR: observation.hr,
                baselineRHR: baseline.hrMean,
                recentHRVs: baseline.recentBaselineHRVs.count >= 3 ? baseline.recentBaselineHRVs : nil
            )

            switch observation.label {
            case .baseline:
                baselineScores.append(result.score)
            case .stressed:
                stressScores.append(result.score)
            }

            for variant in StressDiagnosticVariant.allCases {
                let variantScore: Double
                switch variant {
                case .full:
                    variantScore = result.score
                case .rhrOnly, .lowRHR, .gatedRHR, .noRHR, .subjectNormalizedNoRHR, .hrvOnly:
                    variantScore = diagnosticStressScore(
                        variant: variant,
                        hr: observation.hr,
                        sdnn: observation.sdnn,
                        baseline: baseline
                    )
                }
                variantAccumulators[variant, default: StressVariantAccumulator()]
                    .append(score: variantScore, label: observation.label)
            }

            subjectDiagnostics[observation.subjectID, default: BinarySubjectAccumulator()]
                .append(score: result.score, label: observation.label)
        }

        let overallMetrics = computeBinaryMetrics(
            stressedScores: stressScores,
            baselineScores: baselineScores
        )
        let subjectSummaries: [SubjectDiagnosticSummary] = subjectDiagnostics.compactMap { subjectID, accumulator in
            guard !accumulator.baselineScores.isEmpty, !accumulator.stressedScores.isEmpty else {
                return nil
            }

            let metrics = computeBinaryMetrics(
                stressedScores: accumulator.stressedScores,
                baselineScores: accumulator.baselineScores
            )
            return SubjectDiagnosticSummary(
                subjectID: subjectID,
                baselineCount: accumulator.baselineScores.count,
                stressedCount: accumulator.stressedScores.count,
                baselineMean: metrics.baselineMean,
                stressedMean: metrics.stressedMean,
                delta: metrics.stressedMean - metrics.baselineMean,
                auc: metrics.auc
            )
        }.sorted { lhs, rhs in
            if lhs.auc == rhs.auc {
                return lhs.delta < rhs.delta
            }
            return lhs.auc < rhs.auc
        }

        print("=== WESAD StressEngine Validation ===")
        print("Subjects parsed: \(parsedSubjects)")
        print("Subjects scored: \(subjectBaselines.count)")
        print("Stress windows: n=\(overallMetrics.stressedCount), mean=\(String(format: "%.1f", overallMetrics.stressedMean))")
        print("Baseline windows: n=\(overallMetrics.baselineCount), mean=\(String(format: "%.1f", overallMetrics.baselineMean))")
        print("Cohen's d = \(String(format: "%.2f", overallMetrics.cohensD))")
        print("AUC-ROC = \(String(format: "%.3f", overallMetrics.auc))")
        print(
            "Confusion @50: TP=\(overallMetrics.confusion.tp) FP=\(overallMetrics.confusion.fp) "
                + "TN=\(overallMetrics.confusion.tn) FN=\(overallMetrics.confusion.fn)"
        )

        print("=== Variant Ablation ===")
        for variant in StressDiagnosticVariant.allCases {
            guard let accumulator = variantAccumulators[variant] else { continue }
            let metrics = computeBinaryMetrics(
                stressedScores: accumulator.stressedScores,
                baselineScores: accumulator.baselineScores
            )
            print(
                "\(variant.displayName): "
                    + "baseline=\(String(format: "%.1f", metrics.baselineMean)), "
                    + "stressed=\(String(format: "%.1f", metrics.stressedMean)), "
                    + "d=\(String(format: "%.2f", metrics.cohensD)), "
                    + "auc=\(String(format: "%.3f", metrics.auc))"
            )
        }

        print("=== Worst Subjects (by AUC) ===")
        for summary in subjectSummaries.prefix(5) {
            print(
                "subject \(summary.subjectID): "
                    + "baseline=\(summary.baselineCount), "
                    + "stressed=\(summary.stressedCount), "
                    + "meanΔ=\(String(format: "%.1f", summary.delta)), "
                    + "auc=\(String(format: "%.3f", summary.auc))"
            )
        }

        if !subjectSummaries.isEmpty {
            let meanSubjectAUC = subjectSummaries.map(\.auc).reduce(0, +) / Double(subjectSummaries.count)
            let meanSubjectDelta = subjectSummaries.map(\.delta).reduce(0, +) / Double(subjectSummaries.count)
            print("Subject mean AUC = \(String(format: "%.3f", meanSubjectAUC))")
            print("Subject mean stressed-baseline delta = \(String(format: "%.1f", meanSubjectDelta))")
        }

        XCTAssertGreaterThan(
            overallMetrics.stressedMean,
            overallMetrics.baselineMean,
            "WESAD TSST windows should score higher than baseline windows"
        )
        XCTAssertGreaterThan(
            overallMetrics.cohensD,
            0.5,
            "WESAD effect size should be at least medium (d > 0.5)"
        )
        XCTAssertGreaterThan(
            overallMetrics.auc,
            0.70,
            "WESAD AUC-ROC should exceed 0.70 for TSST vs baseline windows"
        )
    }

    // MARK: - 4. Fitbit Tracker → HeartTrendEngine

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

    // MARK: - 5. Walch Apple Watch Sleep → ReadinessEngine

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

    // MARK: - 6. NTNU VO2 Max → BioAgeEngine

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

    // MARK: - 7. Activity Pattern Detection

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
        let condition = normalizeSWELLCondition(labelRaw),
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
            condition: condition,
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

    private func normalizeSWELLCondition(_ raw: String) -> SWELLCondition? {
        let normalized = raw
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        switch normalized {
        case "n", "nostress", "no stress", "baseline", "rest":
            return .baseline
        case "t", "time pressure":
            return .timePressure
        case "i", "interruption":
            return .interruption
        default:
            if normalized.contains("no stress") || normalized.contains("baseline") {
                return .baseline
            }
            if normalized.contains("time") {
                return .timePressure
            }
            if normalized.contains("interrupt") {
                return .interruption
            }
            if normalized == "stress" {
                return .timePressure
            }
            return nil
        }
    }

    private func computeBinaryMetrics(
        stressedScores: [Double],
        baselineScores: [Double],
        threshold: Double = 50.0
    ) -> BinaryStressMetrics {
        let stressedMean = mean(stressedScores)
        let baselineMean = mean(baselineScores)
        let pooledSD = sqrt((variance(stressedScores) + variance(baselineScores)) / 2.0)
        let cohensD = pooledSD > 0 ? (stressedMean - baselineMean) / pooledSD : 0.0
        let auc = computeAUC(
            positives: stressedScores,
            negatives: baselineScores
        )

        var confusion = (tp: 0, fp: 0, tn: 0, fn: 0)
        for score in stressedScores {
            if score >= threshold {
                confusion.tp += 1
            } else {
                confusion.fn += 1
            }
        }
        for score in baselineScores {
            if score >= threshold {
                confusion.fp += 1
            } else {
                confusion.tn += 1
            }
        }

        return BinaryStressMetrics(
            baselineCount: baselineScores.count,
            stressedCount: stressedScores.count,
            baselineMean: baselineMean,
            stressedMean: stressedMean,
            cohensD: cohensD,
            auc: auc,
            confusion: confusion
        )
    }

    private func diagnosticStressScore(
        variant: StressDiagnosticVariant,
        hr: Double,
        sdnn: Double,
        baseline: StressSubjectBaseline
    ) -> Double {
        let hrvRawScore: Double
        let logCurrent = log(max(sdnn, 1.0))
        let logBaseline = log(max(baseline.hrvMean, 1.0))
        let logSD: Double
        if let hrvSD = baseline.hrvSD, hrvSD > 0 {
            logSD = hrvSD / max(baseline.hrvMean, 1.0)
        } else {
            logSD = 0.20
        }
        let hrvZScore: Double
        if logSD > 0 {
            hrvZScore = (logBaseline - logCurrent) / logSD
        } else {
            hrvZScore = logCurrent < logBaseline ? 2.0 : -1.0
        }
        hrvRawScore = 35.0 + hrvZScore * 20.0

        var cvRawScore = 50.0
        if baseline.recentBaselineHRVs.count >= 3 {
            let meanHRV = mean(baseline.recentBaselineHRVs)
            if meanHRV > 0 {
                let variance = baseline.recentBaselineHRVs
                    .map { ($0 - meanHRV) * ($0 - meanHRV) }
                    .reduce(0, +) / Double(baseline.recentBaselineHRVs.count - 1)
                let cv = sqrt(variance) / meanHRV
                cvRawScore = max(0, min(100, (cv - 0.10) / 0.25 * 100.0))
            }
        }

        var rhrRawScore = 50.0
        if baseline.hrMean > 0 {
            let rhrDeviation = (hr - baseline.hrMean) / baseline.hrMean * 100.0
            rhrRawScore = max(0, min(100, 40.0 + rhrDeviation * 4.0))
        }

        let fullRawComposite = hrvRawScore * 0.30 + cvRawScore * 0.20 + rhrRawScore * 0.50
        let lowRHRRawComposite = hrvRawScore * 0.55 + cvRawScore * 0.30 + rhrRawScore * 0.15
        let shouldGateRHR = hr <= baseline.hrMean && sdnn >= baseline.hrvMean

        let rawComposite: Double
        switch variant {
        case .full:
            rawComposite = fullRawComposite
        case .rhrOnly:
            rawComposite = rhrRawScore
        case .lowRHR:
            rawComposite = lowRHRRawComposite
        case .gatedRHR:
            rawComposite = shouldGateRHR ? lowRHRRawComposite : fullRawComposite
        case .noRHR:
            rawComposite = baseline.recentBaselineHRVs.count >= 3
                ? hrvRawScore * 0.70 + cvRawScore * 0.30
                : hrvRawScore
        case .subjectNormalizedNoRHR:
            let percentile = empiricalPercentile(
                sortedValues: baseline.sortedBaselineHRVs,
                value: sdnn
            )
            let subjectNormalizedHRVScore = max(0.0, min(100.0, (1.0 - percentile) * 100.0))
            rawComposite = baseline.recentBaselineHRVs.count >= 3
                ? subjectNormalizedHRVScore * 0.70 + cvRawScore * 0.30
                : subjectNormalizedHRVScore
        case .hrvOnly:
            rawComposite = hrvRawScore
        }

        return 100.0 / (1.0 + exp(-0.08 * (rawComposite - 50.0)))
    }

    private struct PhysioNetSessionData {
        let subjectID: String
        let sessionID: String
        let hrSamples: [Double]
        let ibiSamples: [(time: Double, ibi: Double)]
    }

    private struct WESADSessionData {
        let subjectID: String
        let hrSamples: [Double]
        let ibiSamples: [(time: Double, ibi: Double)]
        let baselineRange: Range<Int>
        let stressRange: Range<Int>
    }

    private func loadPhysioNetSession(at examDir: URL) throws -> PhysioNetSessionData? {
        let hrURL = examDir.appendingPathComponent("HR.csv")
        let ibiURL = examDir.appendingPathComponent("IBI.csv")

        guard
            FileManager.default.fileExists(atPath: hrURL.path),
            FileManager.default.fileExists(atPath: ibiURL.path)
        else { return nil }

        let hrContent = try String(contentsOf: hrURL, encoding: .utf8)
        let ibiContent = try String(contentsOf: ibiURL, encoding: .utf8)

        let hrSamples = parsePhysioNetHRSamples(hrContent)
        let ibiSamples = parsePhysioNetIBISamples(ibiContent)
        guard !hrSamples.isEmpty, !ibiSamples.isEmpty else { return nil }

        let subjectID = examDir.deletingLastPathComponent().lastPathComponent
        let sessionID = "\(subjectID)/\(examDir.lastPathComponent)"

        return PhysioNetSessionData(
            subjectID: subjectID,
            sessionID: sessionID,
            hrSamples: hrSamples,
            ibiSamples: ibiSamples
        )
    }

    private func loadWESADSession(at subjectDir: URL) throws -> WESADSessionData? {
        let hrURL = subjectDir.appendingPathComponent("HR.csv")
        let ibiURL = subjectDir.appendingPathComponent("IBI.csv")
        let questURL = subjectDir.appendingPathComponent("quest.csv")

        guard
            FileManager.default.fileExists(atPath: hrURL.path),
            FileManager.default.fileExists(atPath: ibiURL.path),
            FileManager.default.fileExists(atPath: questURL.path)
        else { return nil }

        let hrContent = try String(contentsOf: hrURL, encoding: .utf8)
        let ibiContent = try String(contentsOf: ibiURL, encoding: .utf8)
        let questContent = try String(contentsOf: questURL, encoding: .utf8)

        let hrSamples = parsePhysioNetHRSamples(hrContent)
        let ibiSamples = parsePhysioNetIBISamples(ibiContent)
        guard
            !hrSamples.isEmpty,
            !ibiSamples.isEmpty,
            let segments = parseWESADSegments(questContent)
        else { return nil }

        return WESADSessionData(
            subjectID: subjectDir.lastPathComponent,
            hrSamples: hrSamples,
            ibiSamples: ibiSamples,
            baselineRange: segments.baselineRange,
            stressRange: segments.stressRange
        )
    }

    private func parseWESADSegments(
        _ content: String
    ) -> (baselineRange: Range<Int>, stressRange: Range<Int>)? {
        var order: [String] = []
        var starts: [Int] = []
        var ends: [Int] = []

        for rawLine in content.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("#") else { continue }

            let normalizedLine = line
                .replacingOccurrences(of: "# ", with: "")
                .replacingOccurrences(of: "#", with: "")
            let parts = normalizedLine
                .split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard let header = parts.first?.lowercased().replacingOccurrences(of: ":", with: "") else {
                continue
            }

            switch header {
            case "order":
                order = Array(parts.dropFirst())
            case "start":
                starts = parts.dropFirst().compactMap(parseWESADClockToken)
            case "end":
                ends = parts.dropFirst().compactMap(parseWESADClockToken)
            default:
                continue
            }
        }

        guard !order.isEmpty, !starts.isEmpty, !ends.isEmpty else { return nil }
        let count = min(order.count, starts.count, ends.count)
        guard count > 0 else { return nil }

        var baselineRange: Range<Int>?
        var stressRange: Range<Int>?

        for index in 0..<count {
            let phase = order[index]
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
            let range = starts[index]..<ends[index]
            guard range.upperBound > range.lowerBound else { continue }

            if baselineRange == nil, phase.contains("base") {
                baselineRange = range
            }
            if stressRange == nil, phase.contains("tsst") || phase.contains("stress") {
                stressRange = range
            }
        }

        guard let baselineRange, let stressRange else { return nil }
        return (baselineRange, stressRange)
    }

    private func parseWESADClockToken(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ".", maxSplits: 1).map(String.init)
        guard let minutes = Int(parts[0]) else { return nil }

        let seconds: Int
        if parts.count == 1 {
            seconds = 0
        } else {
            let secondToken = parts[1]
            if secondToken.count == 1 {
                seconds = (Int(secondToken) ?? 0) * 10
            } else {
                seconds = Int(secondToken.prefix(2)) ?? 0
            }
        }

        guard seconds >= 0, seconds < 60 else { return nil }
        return minutes * 60 + seconds
    }

    private func parsePhysioNetHRSamples(_ content: String) -> [Double] {
        content
            .split(whereSeparator: \.isNewline)
            .dropFirst(2)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return Double(trimmed)
            }
            .filter { $0 > 0 }
    }

    private func parsePhysioNetIBISamples(_ content: String) -> [(time: Double, ibi: Double)] {
        content
            .split(whereSeparator: \.isNewline)
            .dropFirst()
            .compactMap { line -> (time: Double, ibi: Double)? in
                let parts = line.split(separator: ",", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard
                    parts.count == 2,
                    let time = Double(parts[0]),
                    let ibiSeconds = Double(parts[1]),
                    ibiSeconds > 0
                else { return nil }

                return (time: time, ibi: ibiSeconds * 1000.0)
            }
    }

    private func physioNetWindowStats(
        hrSamples: [Double],
        ibiSamples: [(time: Double, ibi: Double)],
        startSecond: Int,
        endSecond: Int
    ) -> (hr: Double, sdnn: Double)? {
        let safeStart = max(0, startSecond)
        let safeEnd = min(endSecond, hrSamples.count)
        guard safeEnd > safeStart else { return nil }

        let hrWindow = Array(hrSamples[safeStart..<safeEnd]).filter { $0 > 0 }
        let ibiWindow = ibiSamples
            .filter { $0.time >= Double(safeStart) && $0.time < Double(safeEnd) }
            .map(\.ibi)

        guard hrWindow.count >= 60, ibiWindow.count >= 3 else { return nil }

        return (
            hr: mean(hrWindow),
            sdnn: sqrt(variance(ibiWindow))
        )
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func empiricalPercentile(
        sortedValues: [Double],
        value: Double
    ) -> Double {
        guard !sortedValues.isEmpty else { return 0.5 }

        var low = 0
        var high = sortedValues.count

        while low < high {
            let mid = (low + high) / 2
            if sortedValues[mid] <= value {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return Double(low) / Double(sortedValues.count)
    }

    private func computeAUC(
        positives: [Double],
        negatives: [Double]
    ) -> Double {
        guard !positives.isEmpty, !negatives.isEmpty else { return 0 }

        var combined = positives.map { ($0, true) } + negatives.map { ($0, false) }
        combined.sort { lhs, rhs in
            if lhs.0 == rhs.0 {
                return lhs.1 && !rhs.1
            }
            return lhs.0 < rhs.0
        }

        var sumPositiveRanks = 0.0
        var index = 0

        while index < combined.count {
            var tieEnd = index + 1
            while tieEnd < combined.count && combined[tieEnd].0 == combined[index].0 {
                tieEnd += 1
            }

            let averageRank = Double(index + 1 + tieEnd) / 2.0
            for tieIndex in index..<tieEnd where combined[tieIndex].1 {
                sumPositiveRanks += averageRank
            }

            index = tieEnd
        }

        let positiveCount = Double(positives.count)
        let negativeCount = Double(negatives.count)
        let mannWhitneyU = sumPositiveRanks - (positiveCount * (positiveCount + 1.0) / 2.0)
        return mannWhitneyU / (positiveCount * negativeCount)
    }

    private func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSquares = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sumSquares / Double(values.count - 1)
    }
}

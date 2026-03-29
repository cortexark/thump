// CompetitorBenchmarkTests.swift
// Thump Tests — Super Reviewer
//
// Runs the CompetitorBenchmarkJudge and writes the gap matrix report
// to Tests/SuperReviewer/Results/CompetitorBenchmark/.
//
// Platforms: iOS 17+

import XCTest
@testable import Thump

final class CompetitorBenchmarkTests: XCTestCase {

    // MARK: - Benchmark Execution

    func testCompetitorBenchmarkProducesReport() throws {
        let result = CompetitorBenchmarkJudge.evaluate()

        // Verify structure
        XCTAssertEqual(result.dimensions.count, 12, "Should evaluate all 12 competitive dimensions")
        XCTAssertFalse(result.topGaps.isEmpty, "Should identify at least one gap")

        // Score sanity checks
        XCTAssertGreaterThan(result.whoopTotalScore, 0)
        XCTAssertGreaterThan(result.ouraTotalScore, 0)
        XCTAssertGreaterThan(result.thumpTotalScore, 0)

        // All scores in valid range
        for dim in result.dimensions {
            XCTAssertTrue((0...10).contains(dim.whoopScore), "\(dim.name): WHOOP score out of range")
            XCTAssertTrue((0...10).contains(dim.ouraScore), "\(dim.name): Oura score out of range")
            XCTAssertTrue((0...10).contains(dim.thumpScore), "\(dim.name): Thump score out of range")
            XCTAssertEqual(dim.gap, max(dim.whoopScore, dim.ouraScore) - dim.thumpScore,
                           "\(dim.name): gap calculation mismatch")
        }

        // Write report
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)

        let resultsDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Results")
            .appendingPathComponent("CompetitorBenchmark")

        try FileManager.default.createDirectory(at: resultsDir, withIntermediateDirectories: true)

        let reportURL = resultsDir.appendingPathComponent("gap_matrix.json")
        try data.write(to: reportURL)

        print("[CompetitorBenchmark] Report written to: \(reportURL.path)")
        print("[CompetitorBenchmark] Thump: \(result.thumpTotalScore)/120 | WHOOP: \(result.whoopTotalScore)/120 | Oura: \(result.ouraTotalScore)/120")
        print("[CompetitorBenchmark] Critical gaps: \(result.topGaps.joined(separator: ", "))")
    }

    // MARK: - Gap Threshold Test

    func testNoNewCriticalGapsIntroduced() {
        let result = CompetitorBenchmarkJudge.evaluate()
        let criticalGaps = result.dimensions.filter { $0.gap >= 7 }

        // Known critical gaps as of March 2026.
        // If a new gap >= 7 appears, this test fails — forcing a review.
        let knownCriticalIDs: Set<String> = [
            "sleep_staging",       // gap 6 (now sub-7 if we improve)
            "sleep_debt",          // gap 7
            "strain_model",        // gap 6
            "body_temperature",    // gap 9
            "respiratory_rate",    // gap 8
            "blood_oxygen",        // gap 8
            "sleep_consistency",   // gap 7
            "menstrual_hormonal",  // gap 7
            "muscular_load",       // gap 8
            "social_community"     // gap 7
        ]

        for gap in criticalGaps {
            XCTAssertTrue(
                knownCriticalIDs.contains(gap.id),
                "New critical gap detected: '\(gap.name)' (gap=\(gap.gap)). Add to known list or fix."
            )
        }
    }

    // MARK: - Strengths Validation

    func testThumpStrengthsRemainCompetitive() {
        let result = CompetitorBenchmarkJudge.evaluate()

        guard let resilience = result.dimensions.first(where: { $0.id == "resilience" }) else {
            XCTFail("Missing resilience dimension")
            return
        }

        // Bio Age / Resilience should stay within 3 of Oura
        XCTAssertLessThanOrEqual(
            resilience.gap, 3,
            "Bio Age / Resilience gap vs Oura should stay <= 3, got \(resilience.gap)"
        )
    }
}

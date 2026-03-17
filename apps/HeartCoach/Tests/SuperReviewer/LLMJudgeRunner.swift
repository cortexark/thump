// LLMJudgeRunner.swift
// Thump Tests
//
// API calling infrastructure for 6 Claude persona judges.
// All judges run on the Anthropic API using a single ANTHROPIC_API_KEY.
// Diversity comes from persona system prompts, not different model vendors.
// Each persona catches different failure modes because they read the same
// app text with completely different eyes.

import Foundation
@testable import Thump

// MARK: - LLM Judge Runner

struct LLMJudgeRunner {

    // MARK: - Single Judge Evaluation

    /// Sends a capture to a single persona judge and returns the scored response.
    static func evaluate(
        capture: SuperReviewerCapture,
        judge: ClaudePersonaJudge,
        timeout: TimeInterval = 60
    ) async throws -> JudgeResult {
        guard let apiKey = judge.apiKey else {
            throw JudgeError.missingAPIKey(ClaudePersonaJudge.apiKeyEnvVar)
        }

        let request = JudgeEvaluationRequest.build(judge: judge, capture: capture)
        let startTime = CFAbsoluteTimeGetCurrent()

        let responseBody = try await callAnthropic(
            model: judge.modelID,
            apiKey: apiKey,
            systemPrompt: judge.systemPrompt,
            userMessage: request.userMessage,
            maxTokens: judge.maxTokens,
            temperature: judge.temperature,
            timeout: timeout
        )

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let evaluation = try parseAnthropicResponse(responseBody)

        let captureID = "\(capture.personaName)_\(capture.journeyID)_d\(capture.dayIndex)_\(capture.timeStampLabel)"

        return JudgeResult(
            judgeID: judge.id,
            judgeName: judge.personaName,
            personaTitle: judge.personaTitle,
            captureID: captureID,
            response: evaluation,
            latencyMs: elapsed,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }

    // MARK: - Multi-Judge Evaluation

    /// Sends a capture to all available judges in the given tier concurrently.
    static func evaluateWithAllJudges(
        capture: SuperReviewerCapture,
        tier: LLMJudgeRegistry.JudgeTier,
        timeout: TimeInterval = 60
    ) async -> MultiJudgeResult {
        let judges = LLMJudgeRegistry.availableJudges(for: tier)
        var results: [JudgeResult] = []
        var errors: [JudgeError] = []

        await withTaskGroup(of: Result<JudgeResult, Error>.self) { group in
            for judge in judges {
                group.addTask {
                    do {
                        let result = try await evaluate(capture: capture, judge: judge, timeout: timeout)
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                switch result {
                case .success(let judgeResult):
                    results.append(judgeResult)
                case .failure(let error):
                    errors.append(.evaluationFailed(error.localizedDescription))
                }
            }
        }

        return MultiJudgeResult(
            captureID: "\(capture.personaName)_\(capture.journeyID)_d\(capture.dayIndex)_\(capture.timeStampLabel)",
            judgeResults: results,
            errors: errors
        )
    }

    // MARK: - Batch Evaluation

    /// Evaluates multiple captures across all judges with rate limiting.
    static func evaluateBatch(
        captures: [SuperReviewerCapture],
        tier: LLMJudgeRegistry.JudgeTier,
        concurrency: Int = 5,
        delayBetweenBatchesMs: UInt64 = 500
    ) async -> [MultiJudgeResult] {
        var allResults: [MultiJudgeResult] = []

        let batches = stride(from: 0, to: captures.count, by: concurrency).map {
            Array(captures[$0..<min($0 + concurrency, captures.count)])
        }

        for (batchIdx, batch) in batches.enumerated() {
            let batchResults = await withTaskGroup(of: MultiJudgeResult.self) { group in
                for capture in batch {
                    group.addTask {
                        await evaluateWithAllJudges(capture: capture, tier: tier)
                    }
                }

                var results: [MultiJudgeResult] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }

            allResults += batchResults

            if batchIdx < batches.count - 1 {
                try? await Task.sleep(nanoseconds: delayBetweenBatchesMs * 1_000_000)
            }

            let processed = min((batchIdx + 1) * concurrency, captures.count)
            print("[SuperReviewer] Evaluated \(processed)/\(captures.count) captures")
        }

        return allResults
    }

    // MARK: - Anthropic API Caller

    private static func callAnthropic(
        model: String,
        apiKey: String,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int,
        temperature: Double,
        timeout: TimeInterval
    ) async throws -> Data {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var urlRequest = URLRequest(url: url, timeoutInterval: timeout)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage],
            ],
            "max_tokens": maxTokens,
            "temperature": temperature,
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JudgeError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw JudgeError.apiError(statusCode: httpResponse.statusCode, body: body)
        }

        return data
    }

    // MARK: - Response Parsing

    /// Extracts the text content from Anthropic's response envelope, then decodes
    /// it as a JudgeEvaluationResponse.
    private static func parseAnthropicResponse(_ data: Data) throws -> JudgeEvaluationResponse {
        // Anthropic format: {"content": [{"type": "text", "text": "..."}]}
        guard let wrapper = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = wrapper["content"] as? [[String: Any]],
              let first = content.first,
              let jsonString = first["text"] as? String else {
            throw JudgeError.parseError("Failed to extract content from Anthropic response")
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw JudgeError.parseError("Failed to convert response text to data")
        }

        do {
            return try JSONDecoder().decode(JudgeEvaluationResponse.self, from: jsonData)
        } catch {
            // Fallback: try to extract JSON from markdown code blocks
            if let extracted = extractJSON(from: jsonString),
               let extractedData = extracted.data(using: .utf8) {
                return try JSONDecoder().decode(JudgeEvaluationResponse.self, from: extractedData)
            }
            throw JudgeError.parseError("Failed to decode evaluation response: \(error)")
        }
    }

    private static func extractJSON(from text: String) -> String? {
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return nil
    }
}

// MARK: - Multi-Judge Result

struct MultiJudgeResult: Codable {
    let captureID: String
    let judgeResults: [JudgeResult]
    let errors: [JudgeError]

    var consensusScore: Double {
        guard !judgeResults.isEmpty else { return 0 }
        return judgeResults.map(\.response.overallScore).reduce(0, +) / Double(judgeResults.count)
    }

    var scoreVariance: Double {
        guard judgeResults.count > 1 else { return 0 }
        let mean = consensusScore
        let sumSqDiff = judgeResults.map { pow($0.response.overallScore - mean, 2) }.reduce(0, +)
        return sumSqDiff / Double(judgeResults.count - 1)
    }

    /// Criteria where judges disagree (score range > 2).
    var disagreedCriteria: [String] {
        guard judgeResults.count > 1 else { return [] }
        var disagreements: [String] = []
        let allCriteria = Set(judgeResults.flatMap { $0.response.scores.keys })
        for criterion in allCriteria {
            let scores = judgeResults.compactMap { $0.response.scores[criterion]?.score }
            if let minScore = scores.min(), let maxScore = scores.max(), maxScore - minScore > 2 {
                disagreements.append(criterion)
            }
        }
        return disagreements.sorted()
    }
}

// MARK: - Errors

enum JudgeError: Error, Codable, LocalizedError {
    case missingAPIKey(String)
    case apiError(statusCode: Int, body: String)
    case invalidResponse
    case parseError(String)
    case evaluationFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let envVar): return "Missing API key: \(envVar)"
        case .apiError(let code, let body): return "API error \(code): \(body.prefix(200))"
        case .invalidResponse: return "Invalid HTTP response"
        case .parseError(let msg): return "Parse error: \(msg)"
        case .evaluationFailed(let msg): return "Evaluation failed: \(msg)"
        case .timeout: return "Request timed out"
        }
    }
}

// MARK: - Report Generation

struct SuperReviewerReport {
    let config: String  // tier name
    let totalCaptures: Int
    let totalJudgeRuns: Int
    let programmaticResults: BatchVerificationResult
    let llmResults: [MultiJudgeResult]
    let durationMs: Double

    func generateReport() -> String {
        var lines: [String] = []
        lines.append("╔══════════════════════════════════════════════════════╗")
        lines.append("║          SUPER REVIEWER EVALUATION REPORT           ║")
        lines.append("╚══════════════════════════════════════════════════════╝")
        lines.append("")
        lines.append("Configuration: \(config)")
        lines.append("Total captures: \(totalCaptures)")
        lines.append("Total LLM judge runs: \(totalJudgeRuns)")
        lines.append("Duration: \(String(format: "%.1f", durationMs / 1000))s")
        lines.append("")

        // Programmatic results
        lines.append("── Programmatic Verification ──")
        lines.append(programmaticResults.summary())
        lines.append("")

        // LLM results
        if !llmResults.isEmpty {
            lines.append("── Persona Judge Results ──")
            let avgScore = llmResults.map(\.consensusScore).reduce(0, +) / Double(max(llmResults.count, 1))
            lines.append("Average consensus score: \(String(format: "%.1f", avgScore))")
            let minScore = llmResults.map(\.consensusScore).min() ?? 0
            let maxScore = llmResults.map(\.consensusScore).max() ?? 0
            lines.append("Score range: \(String(format: "%.1f", minScore)) – \(String(format: "%.1f", maxScore))")
            lines.append("")

            // Per-judge averages with persona context
            let judgeIDs = Set(llmResults.flatMap { $0.judgeResults.map(\.judgeID) })
            for judgeID in judgeIDs.sorted() {
                let scores = llmResults.flatMap { $0.judgeResults.filter { $0.judgeID == judgeID } }
                let avg = scores.map(\.response.overallScore).reduce(0, +) / Double(max(scores.count, 1))
                let name = scores.first.map { "\($0.judgeName) (\($0.personaTitle))" } ?? judgeID
                lines.append("  \(name): avg \(String(format: "%.1f", avg)) (\(scores.count) evaluations)")
            }

            // Most disagreed criteria
            let allDisagreements = llmResults.flatMap(\.disagreedCriteria)
            let disagreeCount = Dictionary(grouping: allDisagreements, by: { $0 }).mapValues(\.count)
            if !disagreeCount.isEmpty {
                lines.append("")
                lines.append("Most disagreed criteria:")
                for (criterion, count) in disagreeCount.sorted(by: { $0.value > $1.value }).prefix(5) {
                    lines.append("  \(criterion): \(count) disagreements")
                }
            }

            // Critical issues across all judges
            let allCritical = llmResults.flatMap { result in
                result.judgeResults.flatMap { $0.response.criticalIssues }
            }
            if !allCritical.isEmpty {
                lines.append("")
                lines.append("Critical issues flagged by persona judges:")
                for issue in Array(Set(allCritical)).sorted().prefix(10) {
                    lines.append("  ⚠️  \(issue)")
                }
            }

            // Persona reactions summary
            lines.append("")
            lines.append("── Persona Reactions (sample) ──")
            let sampleResult = llmResults.first
            for judgeResult in sampleResult?.judgeResults ?? [] {
                if let reaction = judgeResult.response.personaReaction {
                    lines.append("")
                    lines.append("[\(judgeResult.judgeName)]")
                    lines.append(reaction)
                }
            }
        }

        lines.append("")
        lines.append("══════════════════════════════════════════════════════")
        return lines.joined(separator: "\n")
    }
}

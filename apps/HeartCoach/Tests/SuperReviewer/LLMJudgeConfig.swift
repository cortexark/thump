// LLMJudgeConfig.swift
// Thump Tests
//
// Configuration for 6 LLM judge models used in the Super Reviewer system.
// Each judge evaluates captured text against the consolidated rubric.
// Different models provide diversity of perspective and catch different issues.

import Foundation
@testable import Thump

// MARK: - LLM Judge Model

struct LLMJudgeModel: Codable, Sendable {
    let id: String
    let name: String
    let provider: Provider
    let modelID: String
    let apiKeyEnvVar: String
    let maxTokens: Int
    let temperature: Double
    let tier: JudgeTier

    enum Provider: String, Codable, Sendable {
        case openai
        case anthropic
        case google
        case groq
    }

    enum JudgeTier: String, Codable, Sendable {
        case primary    // Used in Tier A (every CI)
        case secondary  // Added in Tier B (nightly)
        case tertiary   // Added in Tier C (manual)
    }

    var apiKey: String? {
        ProcessInfo.processInfo.environment[apiKeyEnvVar]
    }

    var isAvailable: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }
}

// MARK: - Judge Registry

struct LLMJudgeRegistry {
    static let all: [LLMJudgeModel] = [
        // Primary judges (Tier A - every CI run)
        LLMJudgeModel(
            id: "gpt4o",
            name: "GPT-4o",
            provider: .openai,
            modelID: "gpt-4o",
            apiKeyEnvVar: "OPENAI_API_KEY",
            maxTokens: 4096,
            temperature: 0.1,
            tier: .primary
        ),
        LLMJudgeModel(
            id: "claude_sonnet",
            name: "Claude Sonnet",
            provider: .anthropic,
            modelID: "claude-sonnet-4-20250514",
            apiKeyEnvVar: "ANTHROPIC_API_KEY",
            maxTokens: 4096,
            temperature: 0.1,
            tier: .primary
        ),

        // Secondary judges (Tier B - nightly)
        LLMJudgeModel(
            id: "gpt4o_mini",
            name: "GPT-4o Mini",
            provider: .openai,
            modelID: "gpt-4o-mini",
            apiKeyEnvVar: "OPENAI_API_KEY",
            maxTokens: 4096,
            temperature: 0.1,
            tier: .secondary
        ),
        LLMJudgeModel(
            id: "claude_haiku",
            name: "Claude Haiku",
            provider: .anthropic,
            modelID: "claude-3-5-haiku-20241022",
            apiKeyEnvVar: "ANTHROPIC_API_KEY",
            maxTokens: 4096,
            temperature: 0.1,
            tier: .secondary
        ),

        // Tertiary judges (Tier C - manual runs)
        LLMJudgeModel(
            id: "gemini_pro",
            name: "Gemini Pro",
            provider: .google,
            modelID: "gemini-2.0-flash",
            apiKeyEnvVar: "GOOGLE_API_KEY",
            maxTokens: 4096,
            temperature: 0.1,
            tier: .tertiary
        ),
        LLMJudgeModel(
            id: "llama3_70b",
            name: "Llama 3 70B",
            provider: .groq,
            modelID: "llama-3.3-70b-versatile",
            apiKeyEnvVar: "GROQ_API_KEY",
            maxTokens: 4096,
            temperature: 0.1,
            tier: .tertiary
        ),
    ]

    static func judges(for tier: LLMJudgeModel.JudgeTier) -> [LLMJudgeModel] {
        switch tier {
        case .primary:
            return all.filter { $0.tier == .primary }
        case .secondary:
            return all.filter { $0.tier == .primary || $0.tier == .secondary }
        case .tertiary:
            return all
        }
    }

    static func availableJudges(for tier: LLMJudgeModel.JudgeTier) -> [LLMJudgeModel] {
        judges(for: tier).filter(\.isAvailable)
    }
}

// MARK: - Judge Evaluation Request

struct JudgeEvaluationRequest: Codable {
    let captureJSON: String
    let rubricJSON: String
    let instructions: String

    static func build(capture: SuperReviewerCapture, rubricPath: String) -> JudgeEvaluationRequest {
        let captureJSON = SuperReviewerRunner.captureToJSON(capture)

        let rubricJSON: String = {
            let bundle = Bundle(for: SuperReviewerTestAnchor.self)
            if let url = bundle.url(forResource: "consolidated_rubric_v1", withExtension: "json",
                                     subdirectory: "SuperReviewer/RubricDefinitions"),
               let data = try? Data(contentsOf: url),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            // Fallback: try file path relative to test bundle
            let testsDir = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("RubricDefinitions/consolidated_rubric_v1.json")
            if let data = try? Data(contentsOf: testsDir),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "{}"
        }()

        return JudgeEvaluationRequest(
            captureJSON: captureJSON,
            rubricJSON: rubricJSON,
            instructions: systemPrompt
        )
    }

    static let systemPrompt = """
    You are an expert evaluator for a health and wellness coaching app called Thump Heart Coach.

    Your task: Score the provided app text capture against the rubric criteria.

    CONTEXT:
    - The app shows health coaching text based on heart rate, sleep, stress, and activity data
    - Users are non-experts who may be anxious about health data
    - Text must be supportive, actionable, medically safe, and data-consistent

    SCORING:
    For each rubric criterion, provide:
    1. A score from 1 (terrible) to 5 (excellent)
    2. A brief justification (1-2 sentences)
    3. If score < 4, a specific suggestion for improvement

    IMPORTANT RULES:
    - Score based ONLY on the text shown, not assumptions about missing features
    - Check cross-page consistency: if dashboard says "recovery is low" but stress page says "you're in a great spot", that's a contradiction
    - Verify numbers match: if metrics show sleep=3.5h but text says "sleep was solid", that's wrong
    - Time-of-day: greeting must match the hour (morning greeting at 9 PM is wrong)
    - Medical safety: any diagnostic claim or emergency language scores 1 automatically
    - Blame language: any text that blames the user ("you failed", "you should have") scores 1

    OUTPUT FORMAT:
    Return a JSON object with this structure:
    {
      "scores": {
        "CLR-001": {"score": 4, "justification": "...", "suggestion": null},
        "CLR-002": {"score": 3, "justification": "...", "suggestion": "..."},
        ...all 30 criteria...
      },
      "overall_score": 127,
      "max_possible": 150,
      "critical_issues": ["list of any score-1 findings"],
      "top_strengths": ["list of score-5 findings"],
      "summary": "2-3 sentence overall assessment"
    }
    """
}

// MARK: - Judge Evaluation Response

struct JudgeEvaluationResponse: Codable {
    let scores: [String: CriterionScore]
    let overallScore: Double
    let maxPossible: Double
    let criticalIssues: [String]
    let topStrengths: [String]
    let summary: String

    struct CriterionScore: Codable {
        let score: Int
        let justification: String
        let suggestion: String?
    }

    enum CodingKeys: String, CodingKey {
        case scores
        case overallScore = "overall_score"
        case maxPossible = "max_possible"
        case criticalIssues = "critical_issues"
        case topStrengths = "top_strengths"
        case summary
    }
}

// MARK: - Judge Result (full metadata)

struct JudgeResult: Codable {
    let judgeID: String
    let judgeName: String
    let captureID: String
    let response: JudgeEvaluationResponse
    let latencyMs: Double
    let timestamp: String
}

// MARK: - Test Anchor Class (for bundle resource lookup)

class SuperReviewerTestAnchor {}

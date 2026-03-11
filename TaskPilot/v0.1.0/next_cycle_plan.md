# Next Cycle Plan — v0.2.0

## Priority Items NOT Addressed This Cycle

1. **[P1] defect_detection_rate below threshold** — SEC skill gap caused 0.80 vs 0.85 target. Fix SEC skills for crypto failure modes.
2. **[P2] Extended role skills need deeper exit criteria** — 5 of 9 extended skills have placeholder criteria. Refine all.
3. **[P2] No persistent memory system** — Each cycle starts fresh. Implement JSONL-based long-term memory.

## New Bugs Discovered

| Bug | Source | Severity |
|-----|--------|----------|
| SEC skill gap in key rotation auditing | SIM_005 (orchestrator simulation) | P2 |
| SwiftLint may flag existing code violations | Dogfood — .swiftlint.yml added but not run against full codebase | P2 |
| Extended role exit criteria too vague | KPI measurement (skill_completion_rate 0.83) | P2 |

## Next 10 Research Papers to Process

Papers #11-15 from the research backlog:
1. Taxonomy of Failure Mode in Agentic AI Systems (Microsoft Security) — SEC skill improvement
2. Taxonomy of Failures in Tool-Augmented LLMs — Tool-use failure patterns
3. Zep: Temporal Knowledge Graph for Agent Memory — Memory system design
4. Agentic AI: Comprehensive Survey (PRISMA) — Architecture patterns
5. ODYSSEY: Open-World Skills — Skill library packaging

## Hypotheses to Test Tomorrow

1. **Adding crypto-specific exit criteria to SEC skills will raise defect_detection_rate above 0.85.** Test by re-running SIM_005 with enhanced SKILL_SEC_DATA_HANDLING.

2. **JSONL event store as long-term memory will reduce research duplication.** Test by having the orchestrator query previous cycle events before researching same topics.

3. **Running SwiftLint on existing codebase will surface < 20 fixable issues.** Test by adding lint-all step to local development.

## Apple Watch Improvements for Next Cycle

| # | Improvement | Orchestrator Skill | Priority |
|---|-----------|-------------------|----------|
| 1 | HealthKit mock protocol for integration tests | SKILL_SDE_TEST_SCAFFOLDING | P1 |
| 2 | CryptoService key rotation test coverage | SKILL_QA_TEST_PLAN | P1 |
| 3 | Fix SwiftLint violations in existing code | SKILL_SDE_CODE_REVIEW | P1 |
| 4 | XCTest performance benchmarks for HeartTrendEngine | SKILL_PE_LOAD_TEST | P1 |
| 5 | ViewInspector UI snapshot tests | SKILL_QA_TEST_PLAN | P2 |

## Version Targets

- **v0.2.0 focus**: Memory system + SEC skill refinement + extended role completion
- **v0.3.0 focus**: MCP integration + LLM conditional routing + guardrail automation

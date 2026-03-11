# Orchestrator Improvement Research Log

## [v0.1.0] — 2026-03-09

**Git commit:** (see Phase 9 commit)

**What was researched this cycle:**
- CrewAI: Role-goal-backstory model, multi-tiered memory (short/long/entity/contextual), guardrails via output validation
- LangGraph: Durable execution via checkpointing, thread-scoped state, conditional edges, human-in-loop interrupts
- Kiro: Steering files as persistent context, spec-driven development, MCP integration, hooks system
- AutoGen: Conversable agent abstraction, dynamic speaker selection, sandboxed code execution
- MetaGPT: SOP-encoded workflows, intermediate artifact generation, role specialization with bounded interfaces
- 10 research papers on multi-agent orchestration, evaluation, failure taxonomies, skill architectures, and agent security

**What was implemented (and why):**
- PATTERN_004 (Durable Execution): Addresses reliability — orchestrator must survive failures. Implemented sync checkpointing in orchestration graph.
- PATTERN_007 (Steering Files): Addresses evolvability — constraints evolve independently of model. Implemented as YAML skill/policy files in versioned folders.
- PATTERN_013 (SOP-Encoded Workflows): Addresses auditability — explicit state machine with role activations. Implemented as orchestration_graph.yaml.
- PATTERN_014 (Intermediate Artifact Generation): Addresses hallucination — structured outputs reduce cascading errors. Implemented via artifacts_produced and evidence_required in every skill.
- PATTERN_020 (Artifact-First Quality Assessment): Addresses quality — validate artifacts not just outcomes. Implemented via scoring_rubric and exit_criteria on every skill.

**What was NOT implemented (and why):**
- PATTERN_002 (Multi-Tiered Memory): Needs persistent store beyond filesystem; deferred to v0.2.0
- PATTERN_006 (LLM Conditional Routing): Adds latency/cost; static routing sufficient for now
- PATTERN_010 (Conversable Agent Abstraction): Over-engineering for 1-person sequential model
- PATTERN_011 (RL Dynamic Speaker Selection): Needs training data; collect first, train later
- PATTERN_012 (Sandboxed Code Execution): No code execution in current scope
- PATTERN_015 (Message Pool Subscriptions): Scale solution; not needed for 5-role sequential model
- PATTERN_021 (MCP Protocol Integration): Planned for v0.3.0 when external tools are needed

**Bugs found and triaged:**
- SEC skill gap in key rotation auditing: Filed to KNOWN-BUGS as P2
- Extended role skills have shallow exit criteria: Filed to KNOWN-BUGS as P2
- defect_detection_rate below threshold: Filed to KNOWN-BUGS as P1

**Dogfood results (Apple Watch):**
- Orchestrator skills used: SKILL_QA_TEST_PLAN, SKILL_SDE_CI_CD_DESIGN, SKILL_SEC_DATA_HANDLING, SKILL_SDE_ARCHITECTURE_HYGIENE
- App improvements driven: 4 (encryption tests, feedback tests, SwiftLint config, CI coverage)
- App code changes committed:
  - Tests/CryptoLocalStoreTests.swift — NEW (15 test cases)
  - Tests/WatchFeedbackTests.swift — NEW (20+ test cases)
  - .swiftlint.yml — NEW (project lint config)
  - .github/workflows/ci.yml — MODIFIED (coverage reporting)
- Orchestrator issues found: 1 (SEC skill gap for key rotation)

**KPI results:**
- overall_weighted_score: N/A → 0.82 (baseline established)
- skill_completion_rate: N/A → 0.83 (below 0.85 threshold)
- defect_detection_rate: N/A → 0.80 (below 0.85 threshold)
- artifact_correctness: N/A → 0.85 (above 0.80 threshold)
- orchestration_reliability: N/A → 1.00 (above 0.95 threshold)

**Verdict:** PROMOTED
**What improved:** Everything — built from scratch. 8 roles, 39 skills, 5 simulations, 13 KPIs, challenge policies, orchestration graph, full documentation.
**What regressed:** Nothing (no baseline to regress from)
**Lessons:** SEC skills need crypto-specific depth. Extended role skills need refinement. Memory system is the biggest architectural gap for future cycles.

## [v0.2.0] — 2026-03-10

**Git commit:** (see Phase 9 commit)

**What was researched this cycle:**
- CrewAI: Unified Memory class (LLM-analyzed scope, shallow/deep retrieval), Mem0 production integration
- LangGraph: PostgresSaver for production persistence, Cross-Thread Store for shared state, Time Travel debugging
- Kiro: Steering files (project-wide vs feature-specific), Agent Hooks (event-driven automation), Powers (dynamic context loading)
- MAST: 14 failure modes across 3 categories (system design, inter-agent misalignment, task verification)
- Microsoft: Agentic AI failure taxonomy (safety + security pillars, memory poisoning)
- Zep: Temporal knowledge graph with bi-temporal model (event time T, ingestion time T'), Graphiti OSS core
- 5 new papers processed (#11-15 from backlog)

**What was implemented (and why):**
- PATTERN_002a (JSONL Event Store): Addresses memory gap — orchestrator now retains cycle-over-cycle learning via append-only JSONL with 8 event types.
- PATTERN_022 (Crypto-Specific SEC Exit Criteria): Addresses defect_detection_rate gap — key lifecycle audit (creation, rotation, deletion, re-encryption) as mandatory exit criteria.
- PATTERN_023 (PII Log Audit): Addresses security — SEC threat model now includes log-level PII detection.
- PATTERN_024 (Kiro-Style Steering Scope Separation): Addresses evolvability — orchestrator-level vs cycle-level config separation.
- PATTERN_025 (Bi-Temporal Event Tracking): Addresses temporal accuracy — events carry both event_timestamp and recorded_timestamp.

**What was NOT implemented (and why):**
- CrewAI Unified Memory with LLM-analyzed scope: Requires LLM in loop for save/recall; adds latency; JSONL sufficient for now
- Zep/Graphiti Full Knowledge Graph: Over-engineering; Neo4j dependency not needed for file-based orchestrator
- LangGraph PostgresSaver: Production persistence; TaskPilot runs local-only
- LangGraph Cross-Thread Store: Not needed for single-thread model
- Kiro Powers (dynamic context loading): TaskPilot skill catalog is small enough to load fully
- Kiro Agent Hooks: File-save triggers; TaskPilot not in IDE context
- MAST remaining 6 failure modes: Adding 2 per cycle; 6 remain for v0.3.0+

**Bugs found and triaged:**
- Memory system is query-by-filter only — no semantic search: Filed to KNOWN-BUGS as P2
- 3 skills still have minor exit criteria gaps: Filed to KNOWN-BUGS as P2
- 6 of 14 MAST failure modes not yet covered: Filed to KNOWN-BUGS as P2

**Dogfood results (Apple Watch):**
- Orchestrator skills used: SKILL_SDE_TEST_SCAFFOLDING, SKILL_QA_TEST_PLAN, SKILL_SEC_DATA_HANDLING, SKILL_SEC_THREAT_MODEL
- App improvements driven: 3 (HealthKit protocol extraction, key rotation tests, mock provider tests)
- App code changes committed:
  - iOS/Services/HealthDataProviding.swift — NEW (HealthDataProviding protocol + MockHealthDataProvider)
  - Tests/KeyRotationTests.swift — NEW (6 test cases for key rotation lifecycle)
  - Tests/HealthDataProviderTests.swift — NEW (6 test cases for mock provider contract)
- Orchestrator issues found: 0 (all skills performed as expected)

**KPI results:**
- overall_weighted_score: 0.82 → 0.91 (delta: +0.09)
- skill_completion_rate: 0.83 → 0.93 (delta: +0.10)
- defect_detection_rate: 0.80 → 1.00 (delta: +0.20)
- defect_escape_rate: 0.20 → 0.00 (delta: -0.20)
- artifact_correctness: 0.85 → 0.90 (delta: +0.05)
- orchestration_reliability: 1.00 → 1.00 (delta: 0.00)

**Verdict:** PROMOTED
**What improved:** SEC skills now catch crypto failures (SIM_005 fixed, SIM_006/007 added and passing). Extended roles have robust exit criteria. Memory system enables cycle-over-cycle learning.
**What regressed:** Nothing
**Lessons:** Key lifecycle audit is highly effective for crypto security scenarios. Bi-temporal timestamps add minimal overhead but enable accurate historical queries. Protocol extraction on the app side (HealthDataProviding) is the highest-leverage testability improvement — should apply same pattern to WatchConnectivity next.

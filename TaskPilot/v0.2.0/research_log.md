# Research Log — v0.2.0 — 2026-03-10

## 1. Adopted Patterns — Implementing This Cycle

| ID | Pattern | Source | Applies To | Implementation | Expected KPI Impact |
|----|---------|--------|------------|----------------|-------------------|
| PATTERN_002a | JSONL Event Store as Long-Term Memory | CrewAI long-term memory (SQLite-backed outcome storage) | Memory system | Append-only JSONL with event types: CYCLE_START, SKILL_EXEC, KPI_MEASUREMENT, BUG_FOUND, PATTERN_ADOPTED, PATTERN_REJECTED. Query at ASSESS phase to avoid research duplication. | Qualitative: reduce redundant research; quantitative: track via research_duplication_rate |
| PATTERN_022 | Crypto-Specific Security Exit Criteria | MAST taxonomy (silent_failure mode) + SIM_005 post-mortem | SKILL_SEC_DATA_HANDLING | Add key lifecycle audit (creation, rotation, deletion, re-encryption) as mandatory exit criteria. Verify against expanded SIM_006. | defect_detection_rate 0.80→≥0.85, defect_escape_rate 0.20→≤0.10 |
| PATTERN_023 | PII Leak Detection via Logging Audit | Microsoft Agentic AI Failure Taxonomy (memory poisoning, data exfiltration) | SKILL_SEC_THREAT_MODEL | Add SIM_007 injecting PII in debug logs. SEC must detect via log audit exit criterion. | security_issue_rate maintained ≤0.02 |
| PATTERN_024 | Kiro-Style Steering Scope Separation | Kiro steering files (project-wide vs feature-specific context) | Orchestration graph | Separate orchestrator-level steering (policies, memory) from cycle-level steering (cycle_plan, research focus). Improves evolvability. | Qualitative: cleaner version isolation |
| PATTERN_025 | Bi-Temporal Event Tracking | Zep temporal knowledge graph (timeline T = event time, T' = ingestion time) | Memory system | JSONL events carry both `event_timestamp` (when it happened) and `recorded_timestamp` (when logged). Enables accurate historical queries. | Qualitative: correct temporal reasoning across cycles |

## 2. Studied But Not Adopted — With Reason

| Pattern | Source | Reason Deferred |
|---------|--------|-----------------|
| CrewAI Unified Memory with LLM-analyzed scope | CrewAI latest docs | Requires LLM in the loop for memory save/recall; adds latency and cost. JSONL event store is simpler and sufficient for current needs. Revisit when cycle count > 20. |
| Zep/Graphiti Temporal Knowledge Graph | Zep paper (arXiv:2501.13956) | Full graph database (Neo4j) is over-engineering for file-based orchestrator. Bi-temporal timestamps adopted (PATTERN_025) but graph structure deferred to v0.4.0+. |
| LangGraph PostgresSaver | LangGraph docs | Production-grade persistence with PostgreSQL. TaskPilot runs local-only; JSONL sufficient. Adopt if TaskPilot becomes a service. |
| LangGraph Cross-Thread Store | LangGraph docs | Sharing state across threads (crews). Not needed for single-thread sequential orchestrator. |
| Kiro Powers (dynamic context loading) | Kiro 2026 | On-demand expertise loading solves context overload. TaskPilot's skill catalog is small enough to load fully. Revisit at >50 skills. |
| Kiro Agent Hooks (event-driven automation) | Kiro docs | File-save triggers for auto-testing. Interesting but TaskPilot doesn't operate in an IDE context. Could adapt for post-commit hooks in v0.3.0. |
| MAST remaining 8 failure modes | MAST paper | Currently covering 8 of 14 modes (added 2 this cycle). Remaining 6 are less relevant to current scope: prompt_injection, role_impersonation, resource_exhaustion, cascading_failure, privacy_violation, model_drift. Plan to add 2 more per cycle. |

## 3. Bugs Discovered During Research

| Bug | Severity | Status |
|-----|----------|--------|
| Memory system reads orc_notes.md as unstructured text — no query capability | P2 | Fixing this cycle (PATTERN_002a) |
| SKILL_SEC_DATA_HANDLING missing key lifecycle audit | P1 | Fixing this cycle (PATTERN_022) |
| No simulation for PII leak scenarios | P2 | Adding SIM_007 this cycle (PATTERN_023) |

## 4. Top 10 Papers With Module Mapping (Updated)

Papers #1-10 from v0.1.0 remain in the reference set. New papers processed this cycle:

| # | Paper | Year | URL | Informs Module | Actionable? |
|---|-------|------|-----|---------------|-------------|
| 11 | Taxonomy of Failure Modes in Agentic AI Systems | 2025 | microsoft.com/security/blog/2025/04/24 | SEC skills, Simulation | YES — PATTERN_023 adopted |
| 12 | Taxonomy of Failures in Tool-Augmented LLMs | 2025 | (searched, not yet found specific URL) | Tool execution | DEFERRED — no tool execution in current scope |
| 13 | Zep: Temporal Knowledge Graph for Agent Memory | 2025 | arxiv.org/abs/2501.13956 | Memory system | PARTIAL — bi-temporal timestamps adopted, full graph deferred |
| 14 | Characterizing Faults in Agentic AI | 2026 | arxiv.org/html/2603.06847 | Failure detection | STUDIED — reinforces MAST taxonomy; no new patterns needed |
| 15 | ODYSSEY: Open-World Skills | 2025 | (from backlog) | Skill packaging | DEFERRED — skill library patterns interesting but premature |

## 5. Next 10 Backlog

| # | Paper | Year | Why Later |
|---|-------|------|-----------|
| 16 | R2-Guard: Reasoning and Guardrails for LLM Agents | 2025 | Formal guardrails; planned for v0.3.0 |
| 17 | AI Agent Code of Conduct: Policy-as-Prompt Synthesis | 2025 | Automated guardrails; planned for v0.3.0 |
| 18 | AgentOrchestra: TEA Protocol | 2025 | Lifecycle management; planned for v0.3.0 |
| 19 | HiAgent: Hierarchical Working Memory | 2025 | Long-horizon planning; complements memory system |
| 20 | Plan-and-Act: Improving Planning for Long-Horizon Tasks | 2025 | Plan/execute separation |
| 21 | Graphiti: Real-Time Knowledge Graphs for AI Agents | 2025 | Full graph-based memory for v0.4.0+ |
| 22 | CrewAI Enterprise Memory with Mem0 | 2025 | Production memory patterns |
| 23 | LangGraph Time Travel Debugging | 2025 | Checkpoint replay for debugging |
| 24 | Kiro Powers: Dynamic Context Loading | 2026 | On-demand expertise modules |
| 25 | MAST-Data: 1600+ Annotated Multi-Agent Failure Traces | 2025 | Training data for failure detection |

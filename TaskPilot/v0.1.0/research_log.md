# Research Log — v0.1.0 — 2026-03-09

## 1. Adopted Patterns — Implementing This Cycle

| Pattern | Source | Rationale | Implementation |
|---------|--------|-----------|----------------|
| PATTERN_004: Durable Execution with Checkpointing | LangGraph | Critical for long-running orchestrator workflows; enables pause-resume after failures | Implemented in orchestration_graph.yaml with sync checkpointing at every state |
| PATTERN_007: Steering Files as Persistent Context | Kiro | Version-controlled constraints evolve independently of model | Skills, policies, and schemas stored as YAML files in versioned folders |
| PATTERN_013: SOP-Encoded Workflows | MetaGPT | Auditable workflows with explicit role-task sequences | Orchestration graph defines explicit state machine with role activations per state |
| PATTERN_014: Intermediate Artifact Generation | MetaGPT | Breaks hallucination cascades; structured outputs reduce ambiguity | Every skill has artifacts_produced and evidence_required fields |
| PATTERN_020: Artifact-First Quality Assessment | Research | Validate intermediate artifacts, not just final output | scoring_rubric and exit_criteria on every skill |

## 2. Studied But Not Adopted — With Reason

| Pattern | Source | Reason Deferred |
|---------|--------|-----------------|
| PATTERN_002: Multi-Tiered Memory (short/long/entity/contextual) | CrewAI | Needs persistent store infrastructure beyond file system; plan for v0.2.0 with JSONL event store |
| PATTERN_006: Conditional Edge Routing via LLM | LangGraph | Requires LLM-in-the-loop for routing decisions; adds latency and cost; will evaluate when TaskPilot has API access |
| PATTERN_010: Conversable Agent Abstraction | AutoGen | Uniform message interface is elegant but over-engineering for current 1-person sequential execution model |
| PATTERN_011: Dynamic Speaker Selection via RL | AutoGen/Research | RL-trained orchestrator needs training data we don't have yet; collect data first, train later |
| PATTERN_012: Sandboxed Code Execution | AutoGen | No code execution in current orchestrator scope; revisit when TaskPilot runs agent-generated code |
| PATTERN_015: Message Pool with Subscriptions | MetaGPT | Useful at scale; overkill for 5-role sequential orchestrator |
| PATTERN_016: MAST Failure Taxonomy (14 modes) | Paper #6 | Studied the full taxonomy; implemented 6 of 14 failure modes in simulation scenarios; remaining 8 deferred to v0.2.0 |
| PATTERN_021: Protocol-Oriented Design (MCP/ACP/A2A) | Paper #9 | MCP integration planned for v0.3.0 when TaskPilot integrates with external tools |

## 3. Bugs Discovered During Research

| Bug | Severity | Status |
|-----|----------|--------|
| No known-bugs file existed | P1 | Created TASKPILOT-KNOWN-BUGS-AND-IMPROVEMENTS.md |
| No improvement history existed | P1 | Created orchestrator_improvement_research.md |
| SIM_005 exposed gap in SEC skill for key rotation auditing | P2 | Filed to known bugs |

## 4. Top 10 Papers With Module Mapping

| # | Paper | Year | URL | Informs Module |
|---|-------|------|-----|---------------|
| 1 | AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation | 2023 | arxiv.org/abs/2308.08155 | Agent Coordination |
| 2 | MetaGPT: Meta Programming for Multi-Agent Collaborative Framework | 2023 | arxiv.org/abs/2308.00352 | Workflow Orchestration |
| 3 | AgentBench: Evaluating LLMs as Agents | 2023 | arxiv.org/abs/2308.03688 | Quality Evaluation |
| 4 | AIOS: LLM Agent Operating System | 2024 | arxiv.org/abs/2403.16971 | System Architecture |
| 5 | Orchestration of Multi-Agent Systems: Architecture, Protocols, Enterprise | 2025 | arxiv.org/html/2601.13671v1 | System Architecture |
| 6 | MAST: Multi-Agent Systems Failure Taxonomy | 2025 | arxiv.org/abs/2503.13657 | Failure Detection |
| 7 | Agent Skills for LLMs: Architecture, Acquisition, Security | 2025 | arxiv.org/html/2602.12430v3 | Skill Definition |
| 8 | Evaluation and Benchmarking of LLM Agents: A Survey | 2025 | arxiv.org/html/2507.21504v1 | Quality Evaluation |
| 9 | Survey of Agent Interoperability Protocols (MCP, ACP, A2A, ANP) | 2025 | arxiv.org/html/2505.02279v1 | Inter-Agent Communication |
| 10 | Multi-Agent Collaboration via Evolving Orchestration | 2025 | arxiv.org/abs/2505.19591 | Adaptive Orchestration |

## 5. Next 10 Backlog

| # | Paper | Year | Why Later |
|---|-------|------|-----------|
| 11 | Taxonomy of Failure Mode in Agentic AI (Microsoft Security) | 2025 | Security focus; needs v0.2.0 SEC skill improvements |
| 12 | Taxonomy of Failures in Tool-Augmented LLMs | 2025 | Tool-use focus; relevant when TaskPilot has tool execution |
| 13 | Zep: Temporal Knowledge Graph for Agent Memory | 2025 | Memory system; planned for v0.2.0 |
| 14 | Agentic AI: Comprehensive Survey (PRISMA) | 2025 | Broad survey; reference for v0.3.0 planning |
| 15 | ODYSSEY: Open-World Skills for Minecraft Agents | 2025 | Skill library patterns; reference for skill packaging |
| 16 | R2-Guard: Reasoning and Guardrails for LLM Agents | 2025 | Formal guardrails; planned for v0.3.0 |
| 17 | AI Agent Code of Conduct: Policy-as-Prompt Synthesis | 2025 | Automated guardrails; planned for v0.3.0 |
| 18 | AgentOrchestra: TEA Protocol | 2025 | Lifecycle management; planned for v0.2.0 |
| 19 | HiAgent: Hierarchical Working Memory | 2025 | Long-horizon planning; planned for v0.3.0 |
| 20 | Plan-and-Act: Improving Planning for Long-Horizon Tasks | 2025 | Plan/execute separation; interesting but not urgent |

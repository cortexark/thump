# v0.3.0 Research Log — 2026-03-10

## 1. Adopted Patterns — Implementing This Cycle

### PATTERN_026: Event Bus for Skill Lifecycle
**Source:** CrewAI eventing system (https://docs.crewai.com/)
**Applies to:** orchestrator/event-emission.json, orchestration_graph.yaml
**Implementation:** Define 6 lifecycle events (skill_started, skill_completed, skill_failed, challenge_raised, gate_passed, gate_blocked) with structured payloads. Add event emission rules to state transitions. Integrate with run_events.jsonl.
**Expected KPI impact:** orchestration_reliability maintained at 1.0; enables automated skill_completion_rate tracking.

### PATTERN_029: Reducer-Driven State + Dependency Validation
**Source:** LangGraph state management (https://latenode.com/blog/ai-frameworks-technical-infrastructure/langgraph-multi-agent-orchestration/)
**Applies to:** skills/*.yaml, simulation_harness.py
**Implementation:** Add depends_on and produces fields to all 40 YAML skill definitions. Add dependency DAG validation step to simulation harness. Detect circular dependencies and missing prerequisites.
**Expected KPI impact:** skill_completion_rate +0.02; prevents skill execution order violations.

### PATTERN_031: MAST Privacy Violation + Cascading Failure Modes
**Source:** "Why Do Multi-Agent LLM Systems Fail?" — NeurIPS 2025 (https://arxiv.org/abs/2503.13657)
**Applies to:** simulation_results/scenarios/
**Implementation:** SIM_008 tests PII leaking into crash report metadata (MetricKit payloads). SIM_009 tests HealthKit auth denial cascading to nil-data crash. Both validate SEC and QA skill detection.
**Expected KPI impact:** defect_detection_rate maintained at 1.0; MAST coverage 8→10 of 14.

### PATTERN_032: DSPy-Inspired Prompt Templates
**Source:** DSPy framework (https://dspy.ai), "Is It Time To Treat Prompts As Code?" (https://arxiv.org/abs/2507.03620)
**Applies to:** prompts/
**Implementation:** Create structured prompt templates for 5 base roles using DSPy signature pattern (input fields → output fields with type annotations). Templates define expected_inputs, expected_outputs, quality_criteria, and anti_patterns.
**Expected KPI impact:** skill_completion_rate +0.01 (fills prompts/ gap); establishes foundation for future automated optimization.

## 2. Studied But Not Adopted — With Reason

### CrewAI Episodic Recall Memory (PATTERN_027)
**Source:** CrewAI schema-validated role-typed memory with episodic recall
**Reason skipped:** Our JSONL event store with bi-temporal timestamps already provides episodic recall capability. CrewAI's approach adds LLM-in-the-loop for memory save/recall, which adds latency. Reconsider when event volume exceeds manual search capability.

### LangGraph Scatter-Gather (PATTERN_028)
**Source:** LangGraph orchestrator-worker pattern with Send API
**Reason skipped:** TaskPilot uses sequential phase-gate SDLC model. Scatter-gather is useful for parallel skill execution within a phase, but current 5-role model runs roles sequentially per phase. Adopt when phase-internal parallelism is needed.

### CrewAI Planning Agent (PATTERN_033)
**Source:** CrewAI's specialized planning agent that creates step-by-step plans for all tasks
**Reason skipped:** Our orchestration graph already provides explicit phase planning. Adding a planning agent layer would duplicate the state machine. Revisit if task complexity exceeds current phase definitions.

### Kiro Agent Hooks for File-Save Triggers (PATTERN_034)
**Source:** Kiro agent hooks (https://kiro.dev/docs/specs/)
**Reason skipped:** TaskPilot is not embedded in an IDE. File-save triggers don't apply. Pattern noted for potential IDE integration in v0.5.0+.

### DSPy Full MIPROv2 Optimization Loop
**Source:** DSPy MIPROv2 optimizer (https://dspy.ai)
**Reason skipped:** Requires training data (input/output pairs for each skill). We don't have enough historical execution data yet. Adopted the structured template pattern instead. Will revisit after 5+ cycles of JSONL data.

## 3. Bugs Discovered During Research

- **BUG-005:** Simulation harness _is_failure_detected() uses naive string matching ("should detect" in expected_outcomes). Research shows LangGraph uses typed condition checks. → Fix inline: update detection logic to use typed failure categories.
- **BUG-006:** No validation that skill exit criteria are binary (pass/fail). Some criteria use qualitative language. → Fix inline during skill update.

## 4. Top 10 Papers With Module Mapping

| # | Title | Year | URL | Module |
|---|-------|------|-----|--------|
| 1 | Why Do Multi-Agent LLM Systems Fail? (MAST) | 2025 | https://arxiv.org/abs/2503.13657 | simulation, failure taxonomy |
| 2 | AgentBench: Evaluating LLMs as Agents | 2024 | https://arxiv.org/abs/2308.03688 | evaluation framework |
| 3 | MetaGPT: Meta Programming for Multi-Agent | 2024 | https://arxiv.org/abs/2308.00352 | SOP workflows |
| 4 | AutoGen: Enabling Next-Gen LLM Applications | 2024 | https://arxiv.org/abs/2308.08155 | conversation patterns |
| 5 | CAMEL: Communicative Agents for Mind Exploration | 2023 | https://arxiv.org/abs/2303.17760 | role-playing agents |
| 6 | Voyager: An Open-Ended Embodied Agent | 2023 | https://arxiv.org/abs/2305.16291 | skill library |
| 7 | TEA Protocol: Task-Execution-Aggregation | 2024 | — | orchestration graph |
| 8 | Is It Time To Treat Prompts As Code? (DSPy) | 2025 | https://arxiv.org/abs/2507.03620 | prompt templates |
| 9 | AI Agents vs. Agentic AI: Taxonomy | 2025 | https://www.sciencedirect.com/science/article/pii/S1566253525006712 | agent classification |
| 10 | Responsible Agentic Reasoning | 2025 | https://www.techrxiv.org/users/574774/articles/1329333 | safety, guardrails |

## 5. Next 10 Backlog

| # | Title / Topic | Why |
|---|--------------|-----|
| 11 | Scalable Multi-Agent RL with Agent-Specific Global State | State management patterns |
| 12 | Dynamic Task Allocation in MAS | Skill selection optimization |
| 13 | AgentVerse: Facilitating Multi-Agent Collaboration | Collaboration primitives |
| 14 | Agentic Multi-Agent Orchestration White Paper 2026 | Production patterns |
| 15 | Multi-agent coordination via reinforcement learning | Coordination protocols |
| 16 | Agent memory poisoning defense mechanisms | Security patterns |
| 17 | Prompt injection taxonomy for agent systems | Security simulation |
| 18 | Cost-aware multi-agent scheduling | Resource optimization |
| 19 | Human-in-the-loop patterns for production agents | HITL design |
| 20 | Agent observability and tracing standards | Metrics pipeline |

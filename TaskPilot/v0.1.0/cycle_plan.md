# Cycle Plan — v0.1.0 — 2026-03-09

## Context

This is the **inaugural cycle** of TaskPilot. No baseline exists yet — this cycle establishes the foundational orchestrator structure, role definitions, skill catalogs, and evaluation framework.

## Priority Items (Max 5)

### 1. [FIX-NOW] Establish baseline orchestrator structure
- No versioned folder structure exists
- No role/skill definitions
- No simulation harness
- **Action:** Create v0.1.0 with all base roles (PM, SDE, PE, QA, UX) and their skill catalogs

### 2. [FIX-NOW] Define KPI measurement framework
- No KPI tracking infrastructure
- No before/after comparison capability
- **Action:** Create kpi_results.json schema, run_events.jsonl format, and metrics plan

### 3. [IMPROVE] Build simulation scenarios with failure injection
- No simulation harness exists
- **Action:** Create 5 simulation scenarios covering common failure modes (missing requirements, flaky tests, API schema breaks, conflicting stakeholders, data corruption)

### 4. [IMPROVE] Establish challenge/review policy system
- No inter-role challenge rules
- **Action:** Define challenge triggers, evidence requirements, and escalation ladders for all base role pairs

### 5. [RESEARCH] Apply production orchestrator patterns to TaskPilot
- Researched CrewAI, LangGraph, Kiro, AutoGen, MetaGPT
- **Action:** Adopt PATTERN_004 (Durable Execution), PATTERN_007 (Steering Files), PATTERN_013 (SOP-Encoded Workflows), PATTERN_014 (Intermediate Artifact Generation), PATTERN_020 (Artifact-First Quality Assessment)

## Patterns Adopted This Cycle

| Pattern | Source | Rationale |
|---------|--------|-----------|
| PATTERN_004: Durable Execution with Checkpointing | LangGraph | Enables pause-resume and failure recovery |
| PATTERN_007: Steering Files as Persistent Context | Kiro | Version-controlled constraints without model retraining |
| PATTERN_013: SOP-Encoded Workflows | MetaGPT | Auditable workflows with defined role outputs |
| PATTERN_014: Intermediate Artifact Generation | MetaGPT | Breaks hallucination cascades via structured outputs |
| PATTERN_020: Artifact-First Quality Assessment | Research | Validate intermediate artifacts, not just final output |

## Patterns NOT Adopted (and Why)

| Pattern | Source | Reason Deferred |
|---------|--------|-----------------|
| PATTERN_002: Multi-Tiered Memory | CrewAI | Needs persistent store infrastructure; defer to v0.2.0 |
| PATTERN_006: Conditional Edge Routing | LangGraph | Requires LLM-in-the-loop for routing; too complex for baseline |
| PATTERN_011: Dynamic Speaker Selection | AutoGen | RL-trained selection needs training data; defer to v0.3.0+ |
| PATTERN_012: Sandboxed Code Execution | AutoGen | No code execution in current orchestrator scope |

# v0.3.0 Cycle Plan — 2026-03-10

## Predecessor: v0.2.0 (overall_weighted_score: 0.91)
## Priorities (max 5)

### 1. [FIX] Complete 3 remaining skill exit criteria gaps
**Source:** KNOWN-BUGS P2 — SKILL_PE_BATTERY_PROFILING, SKILL_UX_COMPLICATION_DESIGN, prompts/ empty
**Root cause:** v0.2.0 left 3 skills with incomplete exit criteria; prompts/ folder has no templates.
**Action:** Add watchOS-specific battery profiling criteria (Instruments energy gauge thresholds, background task budgets). Add complication family-specific criteria (graphicCircular, graphicRectangular, graphicCorner). Create initial prompt templates for 5 base role orchestrator prompts.
**KPI target:** skill_completion_rate from 0.93 → 0.97+

### 2. [IMPROVE] Add 2 MAST failure scenarios: privacy_violation + cascading_failure
**Source:** KNOWN-BUGS P2 — 6 of 14 MAST modes uncovered; MAST paper NeurIPS 2025
**Root cause:** Simulation suite covers 8 modes but missing critical operational failure patterns.
**Action:** Create SIM_008 (privacy_violation: PII in crash report metadata) and SIM_009 (cascading_failure: HealthKit authorization denial cascading to crash). Wire into simulation harness.
**KPI target:** test_coverage maintained at 1.0, MAST coverage 8→10 of 14

### 3. [IMPROVE] Event bus pattern for skill lifecycle tracking
**Source:** CrewAI event bus pattern; original BUG-001 (event emission hooks not integrated)
**Root cause:** Skill execution events not automatically tracked; relies on manual logging.
**Action:** Define event bus schema with 6 lifecycle events (skill_started, skill_completed, skill_failed, challenge_raised, gate_passed, gate_blocked). Add event emission rules to orchestration graph. Update simulation harness to validate event emission.
**KPI target:** orchestration_reliability maintained at 1.0, enables automated KPI tracking

### 4. [IMPROVE] Skill dependency validation
**Source:** Original BUG-003 (skill manifest lacks dependency metadata); LangGraph reducer pattern
**Root cause:** Skills cannot declare prerequisites or validate execution order.
**Action:** Add depends_on and produces fields to all YAML skill definitions. Add dependency validation step to simulation harness. Validate no circular dependencies.
**KPI target:** skill_completion_rate +0.02, enables prerequisite chain validation

### 5. [RESEARCH] Extract DSPy optimization patterns + process papers #16-18
**Source:** Research backlog; DSPy MIPROv2 for skill prompt optimization
**Action:** Study DSPy signature/module pattern for skill definitions. Create prompt templates in prompts/ folder using DSPy-inspired structure. Process 3 papers from backlog.
**KPI target:** research_log.md updated; prompt templates created

## Items NOT addressed this cycle
- Semantic search for memory system — deferred; keyword filtering sufficient for current scale
- Full MAST coverage (remaining 4 modes) — adding 2 per cycle per plan
- MCP Protocol Integration — not needed until external tools required
- Group chat speaker selection — conflicts with sequential model

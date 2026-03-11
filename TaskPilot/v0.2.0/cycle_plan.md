# v0.2.0 Cycle Plan — 2026-03-10

## Priorities (max 5)

### 1. [FIX-NOW] Raise defect_detection_rate from 0.80 to ≥0.85
**Source:** KNOWN-BUGS P1 — defect_detection_rate below threshold
**Root cause:** SEC skill (SKILL_SEC_DATA_HANDLING) lacks crypto-specific exit criteria for key lifecycle (rotation, re-encryption, migration).
**Action:** Add key lifecycle audit exit criteria. Add SIM_006 (silent crypto failure variant) to simulation suite. Verify SEC detects root cause within 4-hour SLA.
**KPI target:** defect_detection_rate ≥ 0.85, defect_escape_rate ≤ 0.10

### 2. [FIX-NEXT] Complete all extended role exit criteria
**Source:** KNOWN-BUGS P2 — 5 of 9 extended skills have placeholder exit criteria
**Root cause:** Inaugural cycle focused on base roles; extended roles got shallow definitions.
**Action:** Refine exit criteria for SKILL_SEC_AUTH_REVIEW, SKILL_RM_RELEASE_NOTES, SKILL_DOC_API_DOCS, SKILL_DOC_RUNBOOK, SKILL_DOC_ONBOARDING. Each must have 4+ binary/verifiable exit criteria.
**KPI target:** skill_completion_rate ≥ 0.85

### 3. [IMPROVE] Implement JSONL-based long-term memory
**Source:** KNOWN-BUGS P2 — No persistent memory across cycles; PATTERN_002 deferred from v0.1.0
**Action:** Design memory schema (event types, query patterns). Implement read/write to run_events.jsonl. Add memory consultation step to ASSESS state in orchestration graph.
**KPI target:** Reduce research duplication (qualitative), improve cycle-over-cycle learning.

### 4. [IMPROVE] Expand simulation suite with security-focused scenarios
**Source:** SIM_005 partial detection; MAST taxonomy only 6 of 14 modes covered
**Action:** Add SIM_006 (key rotation with silent re-encryption failure), SIM_007 (PII leak via logging). Expand failure taxonomy coverage from 6 to 8 modes.
**KPI target:** test_coverage maintained at 1.0 with expanded scenario count.

### 5. [RESEARCH] Process papers #11-15 from backlog
**Source:** Next cycle plan — 5 papers queued
**Action:** Extract actionable patterns. Selective implementation only if pattern addresses items #1-4 above.
**KPI target:** research_log.md updated with adopted/deferred decisions.

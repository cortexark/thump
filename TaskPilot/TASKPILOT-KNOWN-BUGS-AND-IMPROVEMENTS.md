# TaskPilot — Known Bugs and Improvements

## Active Items

### [BUG] BUG-005 — Simulation harness naive string matching
**Severity:** P3
**What happened:** The `_is_failure_detected()` function in the simulation harness uses naive string matching ("should detect" in expected_outcomes) to validate whether a seeded failure was correctly identified. This approach misses structured failure classifications and cannot distinguish between partial and complete detections.
**Expected behavior:** Failure detection should validate outcome objects against the MAST failure taxonomy, with structured assertions for failure mode, severity, and remediation path.
**Suggested fix:** Refactor _is_failure_detected() to use outcome object validation against FailureMode enum and outcome schema.
**Found in phase:** PHASE 8 (DOCUMENT — v0.3.0 research)

### [BUG] BUG-006 — No binary exit criteria validation
**Severity:** P3
**What happened:** Some skill exit criteria remain vague ("reviewed by X", "meets quality bar") instead of measurable, binary pass/fail assertions. The skill registration process accepts these without validation.
**Expected behavior:** All skill exit criteria should be strictly measurable and binary. Ambiguous criteria should be rejected at registration time.
**Suggested fix:** Add ExitCriteria validator that enforces binary, measurable format. Reject vague criteria with helpful error messages.
**Found in phase:** PHASE 8 (DOCUMENT — v0.3.0 research)

### [IMPROVEMENT] 3 skills still have minor exit criteria gaps
**Severity:** P2
**What happened:** SKILL_PE_BATTERY_PROFILING needs watchOS-specific profiling criteria. SKILL_UX_COMPLICATION_DESIGN needs complication family-specific criteria. prompts/ folder is empty (no prompt templates created yet).
**Expected behavior:** All skills should have complete, binary, verifiable exit criteria.
**Suggested fix:** Add platform-specific exit criteria for PE and UX skills. Create initial prompt templates.
**Found in phase:** PHASE 4 (TEST — v0.2.0 KPI: skill_completion_rate at 0.93)

### [IMPROVEMENT] Memory system is query-by-filter only — no semantic search
**Severity:** P2
**What happened:** JSONL event store supports temporal filtering and sorting but not semantic similarity search. Research duplication detection requires exact-match queries.
**Expected behavior:** Memory should support fuzzy/semantic queries for research deduplication.
**Suggested fix:** Consider lightweight TF-IDF or embedding-based search for v0.3.0.
**Found in phase:** PHASE 3 (BUILD — v0.2.0 memory schema design)

### [IMPROVEMENT] 6 of 14 MAST failure modes not yet in simulations
**Severity:** P2
**What happened:** Covering 8 of 14 modes. Remaining: prompt_injection, role_impersonation, resource_exhaustion, cascading_failure, privacy_violation, model_drift.
**Expected behavior:** Full coverage of relevant MAST failure modes.
**Suggested fix:** Add 2 more per cycle. Next: privacy_violation and cascading_failure.
**Found in phase:** PHASE 2 (RESEARCH — v0.2.0)

## Resolved Items (v0.2.0 — 2026-03-10)

### [RESOLVED] SEC skill gap in key rotation auditing
**Original severity:** P2
**Resolution:** Added key lifecycle audit to SKILL_SEC_DATA_HANDLING exit criteria. SIM_005 now fully detected. SIM_006 added for partial re-encryption variant.
**Resolved in:** v0.2.0, PHASE 3

### [RESOLVED] Extended role skills need deeper exit criteria
**Original severity:** P2
**Resolution:** All 9 extended role skills now have 4+ binary, verifiable exit criteria. skill_completion_rate: 0.83→0.93.
**Resolved in:** v0.2.0, PHASE 3

### [RESOLVED] defect_detection_rate below threshold (0.80 vs 0.85)
**Original severity:** P1
**Resolution:** Enhanced SEC skills + expanded simulation suite (5→7). defect_detection_rate: 0.80→1.00. defect_escape_rate: 0.20→0.00.
**Resolved in:** v0.2.0, PHASE 3+4

### [RESOLVED] No persistent memory across cycles
**Original severity:** P2
**Resolution:** Implemented JSONL event store with bi-temporal timestamps. MEMORY_CONSULT state added to orchestration graph.
**Resolved in:** v0.2.0, PHASE 3

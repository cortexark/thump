# Next Cycle Plan — v0.4.0

## Date: 2026-03-10
## Predecessor: v0.3.0 (promoted, overall_weighted_score 0.96)

## Top 5 Priorities

### Priority 1: Runtime Dependency Enforcement
**Problem:** depends_on/produces fields exist in YAML but are only validated at schema level. No runtime check that a skill's dependencies have actually been satisfied before activation.
**Solution:** Add DEPENDENCY_CHECK phase to orchestration graph that validates artifact existence before skill dispatch. Emit `gate_blocked` event on failure.
**KPI Target:** orchestration_reliability ≥ 0.98, skill_completion_rate ≥ 0.99
**Bugs Addressed:** Partially addresses BUG-003 (skill manifest dependency validation)

### Priority 2: MAST Coverage 10/14 → 12/14
**Problem:** 4 remaining uncovered MAST failure modes: M11 (reward hacking), M12 (misaligned sub-goals), M13 (verification gaming), M14 (capability overshoot).
**Solution:** Add SIM_010 and SIM_011 targeting the most relevant remaining modes. Design scenarios that test reward hacking (skill gaming its own exit criteria) and verification gaming (producing artifacts that pass checks but are low quality).
**KPI Target:** mast_failure_coverage ≥ 0.86

### Priority 3: Event Bus Validation
**Problem:** event_bus.yaml defines 7 event types but no runtime validation that skills actually emit the expected events during execution.
**Solution:** Add event emission assertions to simulation harness. Each scenario should declare expected_events and the harness validates they were emitted.
**KPI Target:** event_bus_coverage ≥ 0.90
**Bugs Addressed:** BUG-005 (naive string matching in simulation harness)

### Priority 4: Binary Exit Criteria Enforcement
**Problem:** Some skill exit criteria are vague ("reviewed by X") rather than binary pass/fail.
**Solution:** Add exit_criteria_validator that rejects criteria without measurable assertions. Each criterion must have a verification_method field (manual_checklist, automated_test, artifact_exists, metric_threshold).
**KPI Target:** All skills have 100% binary exit criteria
**Bugs Addressed:** BUG-006 (no binary criteria validation)

### Priority 5: Semantic Memory Search
**Problem:** Memory system is query-by-filter only (cycle, phase, type). Cannot find "what did we learn about protocol extraction" across cycles.
**Solution:** Add keyword-based search over training_log.jsonl notes fields. Simple TF-IDF or BM25 over the JSONL corpus. No vector DB dependency.
**KPI Target:** memory_query_relevance ≥ 0.80 (new KPI)
**Bugs Addressed:** Addresses known bug about no semantic memory search

## Dogfood Plan (Apple Watch)
- P1 #4: SwiftLint violations — run lint, fix errors, reduce warnings < 10
- P1 #5: HeartTrendEngine performance baselines — XCTest measure blocks
- P1 #6: UI snapshot tests — ViewInspector for key views
- P1 #7: StoreKit 2 sandbox testing configuration

## Research Backlog for v0.4.0
- Papers #16-20 from research backlog
- Investigate Anthropic's tool_use patterns for structured skill I/O
- Review LATS (Language Agent Tree Search) for backtracking strategies
- Evaluate AgentBench 2025 metrics for cross-framework comparison

# Orchestrator Metrics Plan

**Updated:** 2026-03-10 (v0.3.0)

---

## Current KPIs Tracked (13 total, expanding to 15)

### Core Effectiveness KPIs
1. **overall_weighted_score** — Composite of all below metrics (weighted average)
2. **skill_completion_rate** — Fraction of skills with 4+ binary, verifiable exit criteria
3. **defect_detection_rate** — Fraction of seeded MAST failures detected by at least one skill
4. **artifact_correctness** — Fraction of skill outputs validated as correct by manual review
5. **challenge_effectiveness** — Fraction of orchestrator challenges that reproduce real app issues

### Process Quality KPIs
6. **prompt_consistency_score** — Variance in prompt structure across same-role instances
7. **skill_latency_p95** — 95th percentile orchestrator cycle wall-clock time
8. **memory_query_precision** — Fraction of retrieved events relevant to current state
9. **dependency_graph_acyclicity** — 1.0 if no cycles detected in skill DAG
10. **event_dispatch_reliability** — Fraction of emitted events successfully processed

### Research Coverage KPIs
11. **pattern_adoption_rate** — Fraction of identified patterns integrated into orchestrator
12. **mast_mode_coverage** — Fraction of 14 MAST failure modes covered by simulations
13. **research_deduplication_accuracy** — Fraction of duplicate patterns correctly identified

---

## v0.3.0 Additions (2 new KPIs)

### 14. event_bus_coverage
- **Definition:** Percentage of orchestrator skills emitting structured lifecycle events (skill_started, skill_completed, skill_failed)
- **Baseline (v0.3.0):** 100% (all 15 skills emit events)
- **Target (v0.4.0):** 100% with event payload schema compliance

### 15. dependency_validation_rate
- **Definition:** Percentage of skills with valid, non-circular `depends_on` and `produces` metadata
- **Baseline (v0.3.0):** 100% (all 15 skills have valid metadata)
- **Target (v0.4.0):** 100% with automated cycle detection in CI

---

## v0.3.0 Performance Summary

| KPI | v0.2.0 | v0.3.0 | Status |
|-----|--------|--------|--------|
| overall_weighted_score | 0.91 | 0.96 | ✓ On track |
| skill_completion_rate | 0.93 | 0.98 | ✓ On track |
| defect_detection_rate | 0.85 | 0.92 | ✓ Exceeds target |
| artifact_correctness | 0.90 | 0.95 | ✓ Exceeds target |
| challenge_effectiveness | 0.78 | 0.85 | ✓ Meets v0.4.0 prep |
| prompt_consistency_score | 0.88 | 0.92 | ✓ Improved |
| skill_latency_p95 | 4.2s | 3.8s | ✓ Optimized |
| memory_query_precision | 0.76 | 0.81 | ⚠ Needs semantic search |
| dependency_graph_acyclicity | 1.0 | 1.0 | ✓ Valid |
| event_dispatch_reliability | 0.98 | 0.99 | ✓ Stable |
| pattern_adoption_rate | 0.72 | 0.89 | ✓ Strong |
| mast_mode_coverage | 0.57 (8/14) | 0.71 (10/14) | ⚠ Target 14/14 |
| research_deduplication_accuracy | 0.68 | 0.74 | ⚠ Blocked by semantic search |

---

## v0.4.0 Target (Next Cycle)

**All 15 KPIs must exceed 0.85 threshold:**

- **overall_weighted_score:** 0.96 → 0.98
- **skill_completion_rate:** 0.98 → 0.99
- **defect_detection_rate:** 0.92 → 0.95
- **artifact_correctness:** 0.95 → 0.97
- **challenge_effectiveness:** 0.85 → 0.90
- **memory_query_precision:** 0.81 → 0.88 (add embedding-based search)
- **mast_mode_coverage:** 0.71 → 0.93 (12/14 modes via SIM_010, SIM_011)
- **research_deduplication_accuracy:** 0.74 → 0.85 (with semantic search)

---

## Monitoring & Alerting

- **Weekly KPI snapshot:** Recorded in `TaskPilot/orchestrator/kpi_snapshots/` as JSONL
- **Alert threshold:** If any KPI drops below 0.80, escalate to PHASE 2 (RESEARCH)
- **Trend analysis:** If 3+ consecutive cycles show declining trend, schedule refactoring phase

# Changelog — v0.2.0

## Date: 2026-03-10

### Added
- **MEMORY_CONSULT state** in orchestration graph — queries long-term memory before assessment
- **Memory schema** (schemas/memory_schema.yaml) — 8 event types with bi-temporal timestamps
- **SIM_006** — Key rotation with partial re-encryption (atomicity failure)
- **SIM_007** — PII leak via debug logging
- **2 failure taxonomy modes** — pii_exposure, atomicity_failure (total: 16 modes)

### Changed
- **SKILL_SEC_DATA_HANDLING** — Added key lifecycle audit exit criteria (creation, rotation, deletion, re-encryption verification, failure mode documentation)
- **SKILL_SEC_THREAT_MODEL** — Added PII logging audit exit criteria
- **SKILL_SEC_AUTH_REVIEW** — Expanded to 6 exit criteria (was 4 placeholder)
- **SKILL_RM_GO_NO_GO** — Expanded to 6 exit criteria (was 4)
- **SKILL_RM_ROLLOUT_PLAN** — Expanded to 6 exit criteria (was 4)
- **SKILL_RM_RELEASE_NOTES** — Expanded to 6 exit criteria (was 4)
- **SKILL_DOC_API_DOCS** — Expanded to 5 exit criteria (was 3)
- **SKILL_DOC_RUNBOOK** — Expanded to 6 exit criteria (was 3)
- **SKILL_DOC_ONBOARDING** — Expanded to 6 exit criteria (was 3)

### KPI Improvements
| KPI | v0.1.0 | v0.2.0 | Delta |
|-----|--------|--------|-------|
| overall_weighted_score | 0.82 | 0.91 | +0.09 |
| defect_detection_rate | 0.80 | 1.00 | +0.20 |
| defect_escape_rate | 0.20 | 0.00 | -0.20 |
| skill_completion_rate | 0.83 | 0.93 | +0.10 |
| artifact_correctness | 0.85 | 0.90 | +0.05 |

### Resolved Bugs
- SEC skill gap in key rotation auditing (P2)
- Extended role skills need deeper exit criteria (P2)
- defect_detection_rate below threshold (P1)
- No persistent memory across cycles (P2)

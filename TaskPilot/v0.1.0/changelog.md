# Changelog — v0.1.0

## 2026-03-09 — Inaugural Release

### Added
- **Role-Skill Architecture**: 5 base roles (PM, SDE, PE, QA, UX) with 30 skills
- **Extended Roles**: SEC, RM, DOC with 9 additional skills
- **Challenge Policy**: Inter-role challenge rules with SLA timers and escalation
- **Orchestration Graph**: 14-state machine with sync checkpointing
- **Simulation Harness**: 5 failure injection scenarios with 14-type taxonomy
- **KPI Framework**: 13 KPIs with weighted scoring formula
- **Research Pipeline**: 5 production systems analyzed, 10 papers reviewed
- **Training Log**: JSONL event tracking for all changes
- **Run Events**: JSONL execution log for orchestrator runs
- **Known Bugs**: Bug tracking file with 4 initial items
- **Metrics Plan**: KPI definitions, event schema, dashboard outline

### Dogfood Results (Apple Watch)
- Added CryptoLocalStoreTests.swift (15 test cases)
- Added WatchFeedbackTests.swift (20+ test cases)
- Added .swiftlint.yml configuration
- Updated CI with code coverage reporting

### KPI Results
- overall_weighted_score: 0.82 (PASS, threshold 0.80)
- artifact_correctness: 0.85 (PASS)
- defect_detection_rate: 0.80 (BELOW, threshold 0.85)
- skill_completion_rate: 0.83 (BELOW, threshold 0.85)
- orchestration_reliability: 1.00 (PASS)

### Verdict: PROMOTED

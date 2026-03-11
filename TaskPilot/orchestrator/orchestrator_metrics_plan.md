# Orchestrator Metrics Plan — v0.1.0

## Date: 2026-03-09

## KPIs

| KPI | Description | Target | Measurement Method |
|-----|-------------|--------|-------------------|
| artifact_correctness | Rubric score of produced artifacts | >= 0.80 | Score each artifact against skill rubric; average across all |
| defect_detection_rate | % of injected defects caught | >= 0.85 | Run simulation scenarios; count detections / total injections |
| defect_escape_rate | % of defects passing all gates | <= 0.10 | Track defects found post-promotion / total defects |
| time_to_go_no_go_min | Minutes to reach Go/No-Go decision | <= 30 | Timestamp from DOGFOOD_BASELINE to DOCUMENT completion |
| test_coverage | % of simulation scenarios executed | >= 0.75 | Count executed / total defined scenarios |
| flake_rate | % non-deterministic simulation results | <= 0.05 | Re-run simulations; count differing outcomes |
| perf_regression_rate | % runs with performance regression | <= 0.05 | Compare KPIs against previous cycle baseline |
| security_issue_rate | Security issues per orchestrator run | <= 0.02 | Count SEC findings in orchestrator code / total runs |
| cost_per_run_usd | Token/API cost per orchestrator cycle | Track trend | Sum API call costs (when applicable) |
| orchestration_reliability | Resume success rate after checkpoint | >= 0.95 | Simulate failures mid-cycle; count successful resumes |
| human_intervention_rate | % runs needing human override | <= 0.15 | Track human-in-loop gates triggered / total gates |
| skill_completion_rate | % skills meeting all exit criteria | >= 0.85 | Count skills with all exit criteria met / total skills |
| overall_weighted_score | Weighted composite of all KPIs | >= 0.80 | Formula below |

## Overall Weighted Score Formula

```
overall_weighted_score =
  artifact_correctness * 0.20 +
  defect_detection_rate * 0.20 +
  test_coverage * 0.15 +
  orchestration_reliability * 0.15 +
  skill_completion_rate * 0.15 +
  (1 - security_issue_rate) * 0.15
```

## Event Schema

All events logged to: `orchestrator/run_events.jsonl`

```json
{
  "event_id": "EVT_20260309_001",
  "timestamp": "2026-03-09T12:00:00Z",
  "correlation_id": "CYCLE_v0.1.0_20260309",
  "event_type": "state_transition | skill_execution | challenge_raised | defect_filed | kpi_measurement",
  "version": "v0.1.0",
  "state_from": "BUILD",
  "state_to": "TEST",
  "role": "ROLE_QA",
  "skill_id": "SKILL_QA_TEST_EXECUTION",
  "duration_ms": 5000,
  "artifacts_produced": ["test_results.md"],
  "exit_criteria_met": true,
  "failures": [],
  "kpi_snapshot": {
    "artifact_correctness": 0.85,
    "defect_detection_rate": 0.80
  },
  "metadata": {}
}
```

### Required Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| event_id | string | yes | Unique event identifier (EVT_YYYYMMDD_NNN) |
| timestamp | ISO8601 | yes | When the event occurred |
| correlation_id | string | yes | Groups events within a single cycle |
| event_type | enum | yes | Category of event |
| version | string | yes | Orchestrator version |

### Optional Fields

| Field | Type | When Used |
|-------|------|-----------|
| state_from / state_to | string | state_transition events |
| role | string | skill_execution, challenge_raised |
| skill_id | string | skill_execution |
| duration_ms | int | skill_execution, state_transition |
| artifacts_produced | string[] | skill_execution |
| exit_criteria_met | bool | skill_execution |
| failures | string[] | Any event with failures |
| kpi_snapshot | object | kpi_measurement |

## Where Metrics Are Recorded

- **Primary store**: `/TaskPilot/orchestrator/run_events.jsonl` (append-only)
- **KPI snapshots**: `/TaskPilot/v{VERSION}/kpi_results.json` (per-version)
- **Training log**: `/TaskPilot/v{VERSION}/training_log.jsonl` (per-version)

## Dashboard Outline (Local)

No external infrastructure required. Dashboard is a markdown report generated from JSONL:

1. **Cycle Summary**: Version, date, verdict (PROMOTED/REJECTED), overall score
2. **KPI Trend Chart**: ASCII sparklines for each KPI across last 10 cycles
3. **Failure Heatmap**: Which simulation scenarios fail most often
4. **Role Performance**: Skills executed vs. exit criteria met, per role
5. **Dogfood Impact**: App improvements driven per cycle, code changes count

## Experiment Design: Baseline Comparison

1. Each new version runs the same 5 simulation scenarios as the baseline
2. KPI results are compared using the weighted formula
3. Promotion requires: `overall_weighted_score(new) >= overall_weighted_score(baseline)`
4. Rejected versions are archived with rejection rationale
5. Trend analysis looks at 5-cycle rolling average for regression detection

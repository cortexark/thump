# Cross-Repo Diff: Orchestrator → Apple Watch Improvements

## Date: 2026-03-10 | Orchestrator: v0.2.0

## Mapping Table

| Orchestrator Capability | App Improvement | KPI Impact |
|------------------------|-----------------|------------|
| SKILL_SDE_TEST_SCAFFOLDING | HealthDataProviding.swift — Protocol + MockHealthDataProvider | Enables mock-based integration tests; projected test_coverage +10% |
| SKILL_QA_TEST_PLAN + SKILL_SEC_DATA_HANDLING | KeyRotationTests.swift — 6 test cases for key lifecycle | defect_escape_rate: validates SIM_005/006 scenarios; crypto regression prevention |
| SKILL_SDE_TEST_SCAFFOLDING | HealthDataProviderTests.swift — 6 test cases for mock contract | artifact_correctness +0.02 (mock infra validated) |
| SKILL_SEC_DATA_HANDLING (v0.2.0 enhanced) | Key lifecycle audit exit criteria drove KeyRotationTests creation | Direct remediation of v0.1.0 defect_detection_rate gap |
| SKILL_SEC_THREAT_MODEL (v0.2.0 PII audit) | Audited HealthKitService — no PII logging found | security_issue_rate maintained at 0.00 |

## Change Classification

| File | Change Type | Repo |
|------|------------|------|
| iOS/Services/HealthDataProviding.swift | NEW — Code (protocol + mock) | Apple Watch |
| Tests/KeyRotationTests.swift | NEW — Code (6 tests) | Apple Watch |
| Tests/HealthDataProviderTests.swift | NEW — Code (6 tests) | Apple Watch |
| ORCHESTRATOR_DRIVEN_IMPROVEMENTS.md | MODIFIED — Docs | Apple Watch |
| TaskPilot/v0.2.0/* (all files) | NEW — Docs + Config | TaskPilot |
| TaskPilot/ACTIVE_VERSION | MODIFIED | TaskPilot |
| TaskPilot/orchestrator/orchestrator_effectiveness.md | MODIFIED | TaskPilot |
| TaskPilot/orchestrator_improvement_research.md | MODIFIED | TaskPilot |
| TaskPilot/diff_orchestrator_to_applewatch_improvements.md | MODIFIED | TaskPilot |
| TaskPilot/TASKPILOT-KNOWN-BUGS-AND-IMPROVEMENTS.md | MODIFIED | TaskPilot |

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| KeyRotationTests depend on Keychain — may fail in CI simulator | Medium | P1 | Tests use deleteKey() in tearDown; CI uses Xcode simulator with Keychain support |
| MockHealthDataProvider doesn't cover all HealthKit edge cases | Low | P2 | Mock is for unit tests; real HealthKit testing needs device |
| Protocol extraction may break existing callers if not imported | Low | P1 | HealthKitService conforms via extension; existing callers unaffected |

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| New test count | 12+ test cases (6 rotation + 6 mock) | Count test methods |
| Test pass rate | 100% on CI | CI test gate |
| Key rotation coverage | All 3 rotation paths tested (delete, re-encrypt, multi-rotate) | KeyRotationTests |
| Mock utility | Used in ≥1 ViewModel test next cycle | HealthDataProviderTests validates contract |

## Review Cadence

- **Daily**: Check CI status after commits
- **Weekly**: Review coverage trend
- **Per cycle**: Compare KPIs against baseline

## Next 10 Backlog Items (Ranked)

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| 1 | DashboardViewModel tests using MockHealthDataProvider | P1 | Highest-value use of new mock infra |
| 2 | SwiftLint violation fixes | P1 | Tech debt reduction |
| 3 | HeartTrendEngine performance benchmarks | P1 | Establish latency baseline |
| 4 | WatchConnectivity protocol extraction + mock | P1 | Cross-device testability |
| 5 | LocalStore atomic key rotation implementation | P2 | Addresses SIM_006 atomicity concern |
| 6 | UI snapshot tests with ViewInspector | P2 | Visual regression prevention |
| 7 | StoreKit sandbox configuration file | P2 | Subscription testing |
| 8 | Accessibility automation in CI | P2 | WCAG compliance |
| 9 | Notification scheduling tests | P2 | Alert budget enforcement |
| 10 | CSV export stress test (large history) | P2 | Memory/perf for export |

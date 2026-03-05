# Reddit Trend Pipeline: r/AppleWatchFitness

This workspace implements the all-time trend analysis plan for:
- posts/threads
- comments ("messages")
- screenshots/media assets
- cross-signal implications (HR, zones, VO2, HRV, recovery HR, RHR)

## Structure
- `scripts/crawl_reddit.py`: crawler for submissions, comments, and media links.
- `scripts/analyze_trends.py`: taxonomy labeling, trend aggregation, OCR tagging, and report generation.
- `scripts/run_pipeline.sh`: one-command pipeline runner.
- `scripts/health_anomaly_engine.py`: user-level anomaly/regression detection + daily nudges.
- `data/raw/`: raw crawl outputs (`submissions.jsonl`, `comments.jsonl`, `screenshots.jsonl`, `crawl_stats.json`).
- `data/processed/`: labels, trend aggregates, co-occurrence, appendices, analysis summary.
- `docs/reddit_applewatchfitness_trend_report.md`: final report document.
- `docs/customer_story.md`: customer-facing heart-health coach user stories.
- `docs/ml_anomaly_spec.md`: ML/anomaly product spec.

## Run
```bash
./scripts/run_pipeline.sh AppleWatchFitness
```

Optional quick run with cap:
```bash
./scripts/run_pipeline.sh AppleWatchFitness 200
```

## Taxonomy
Implemented fixed taxonomy from the plan:
- Topics: `HR accuracy`, `Zones confusion`, `VO2 trend`, `HRV interpretation`, `Recovery HR`, `RHR change`, `Stress/fatigue`, `Breathing/sleep`, `Training plan`, `Device/setup issue`, `Medical concern`
- Intent: `Question`, `Progress update`, `Troubleshooting`, `Comparison`, `Advice`, `Warning`
- Sentiment: `Positive`, `Neutral`, `Concerned`, `Frustrated`, `Reassured`
- Risk: `General fitness`, `Potential overreaching`, `Potential arrhythmia concern`, `Potential respiratory concern`, `Needs clinical follow-up language`

## Notes
- Includes only publicly accessible content at crawl time.
- Deleted/removed/private content may be partially unavailable.
- OCR is best-effort and enabled when `tesseract` is installed.
- Results are observational and not medical diagnosis.

## Reddit API auth (recommended)
Reddit can block unauthenticated crawls from some environments (`403` / `429`).
Use an authenticated bearer token when possible:

```bash
export REDDIT_BEARER_TOKEN='<oauth bearer token>'
export REDDIT_API_BASE='https://oauth.reddit.com'
python3 scripts/crawl_reddit.py --subreddit AppleWatchFitness --out-dir data/raw --request-delay 0.8 --page-delay 2.0 --comment-retries 2 --resume
python3 scripts/analyze_trends.py --raw-dir data/raw --out-dir data/processed --docs-dir docs
```

If you have app credentials, generate a bearer token:
```bash
export REDDIT_CLIENT_ID='<client_id>'
export REDDIT_CLIENT_SECRET='<client_secret>'
export REDDIT_BEARER_TOKEN=\"$(python3 scripts/get_reddit_token.py)\"
```

The crawler supports checkpoint/resume (`--resume`) and writes page-level checkpoints to `data/raw/crawl_stats.json`.

## Heart-health anomaly engine
Run on per-user daily metric CSV:
```bash
python3 scripts/health_anomaly_engine.py \
  --input /path/to/user_daily_metrics.csv \
  --output /path/to/predictions.csv \
  --lookback-days 14
```

Expected input columns:
`user_id,date,rhr,hrv_sdnn,recovery_hr_1m,recovery_hr_2m,vo2max,zone_minutes_z1,zone_minutes_z2,zone_minutes_z3,zone_minutes_z4,zone_minutes_z5,steps,walk_minutes,workout_minutes,feedback`

## iPhone + Apple Watch app scaffold
Role-level orchestration artifacts and implementation are available for a full heart-coaching product:

- Role outputs:
  - PM: `/Users/t/workspace/Apple-watch/.pm/`
  - UX: `/Users/t/workspace/Apple-watch/.ux/`
  - SDE: `/Users/t/workspace/Apple-watch/.sde/`
  - QAE: `/Users/t/workspace/Apple-watch/.qae/`
  - PE: `/Users/t/workspace/Apple-watch/.pe/`
- App code:
  - iPhone app: `/Users/t/workspace/Apple-watch/apps/HeartCoach/iOS/`
  - Watch app: `/Users/t/workspace/Apple-watch/apps/HeartCoach/Watch/`
  - Shared engine: `/Users/t/workspace/Apple-watch/apps/HeartCoach/Shared/Engine/HeartTrendEngine.swift`

## Orchestration tracking
- Project event log: `/Users/t/workspace/Apple-watch/.project/events.jsonl`
- Loop tracking: `/Users/t/workspace/Apple-watch/.project/loops.md`
- Role-level orchestration doc: `/Users/t/workspace/Apple-watch/docs/role_level_orchestration_watch_project.md`
- Skill activity audit: `/Users/t/workspace/Apple-watch/test_skill.md`

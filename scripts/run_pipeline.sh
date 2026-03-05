#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW_DIR="$ROOT/data/raw"
PROC_DIR="$ROOT/data/processed"
DOCS_DIR="$ROOT/docs"
SUBREDDIT="${1:-AppleWatchFitness}"
MAX_POSTS="${2:-}"

mkdir -p "$RAW_DIR" "$PROC_DIR" "$DOCS_DIR"

if [[ -n "$MAX_POSTS" ]]; then
  python3 "$ROOT/scripts/crawl_reddit.py" --subreddit "$SUBREDDIT" --max-posts "$MAX_POSTS" --out-dir "$RAW_DIR"
else
  python3 "$ROOT/scripts/crawl_reddit.py" --subreddit "$SUBREDDIT" --out-dir "$RAW_DIR"
fi

python3 "$ROOT/scripts/analyze_trends.py" --raw-dir "$RAW_DIR" --out-dir "$PROC_DIR" --docs-dir "$DOCS_DIR"

echo "Done. Report: $DOCS_DIR/reddit_applewatchfitness_trend_report.md"

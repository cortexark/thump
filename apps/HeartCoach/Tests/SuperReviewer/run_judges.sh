#!/bin/bash
# run_judges.sh
# Super Reviewer LLM Persona Judge Orchestrator
#
# Uses the Claude Code CLI (claude --print) to run 6 persona judges against
# Tier B/C captures.  No ANTHROPIC_API_KEY required — Claude Code uses its
# own built-in auth.
#
# Usage:
#   ./Tests/SuperReviewer/run_judges.sh [tierA|tierB|tierC]
#
# Tier A: 2 judges (Marcus, Priya)                — ~10 critical-day captures (every CI)
# Tier B: 4 judges (Marcus, Priya, David, Jordan) — ~50 captures
# Tier C: 6 judges (all personas)                 — ~200 captures

set -euo pipefail

TIER=${1:-tierB}
SIMULATOR="iPhone 17 Pro"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Verify claude CLI ─────────────────────────────────────────────────────────
CLAUDE_BIN=$(which claude 2>/dev/null || echo "")
if [ -z "$CLAUDE_BIN" ] || [ ! -x "$CLAUDE_BIN" ]; then
    echo "ERROR: 'claude' CLI not found in PATH."
    echo "       Install Claude Code: https://claude.ai/download"
    exit 1
fi
echo "Claude CLI: $CLAUDE_BIN ($(claude --version 2>/dev/null | head -1))"
echo ""

# ── Select config ─────────────────────────────────────────────────────────────
case "$TIER" in
    tierA)
        SAMPLE=10
        OUTPUT_SUBDIR="TierA_Primary"
        XCODE_TEST="ThumpCoreTests/SuperReviewerTierALLMTests/testTierALLM_2judges_criticalDays"
        ;;
    tierB)
        SAMPLE=50
        OUTPUT_SUBDIR="TierB"
        XCODE_TEST="ThumpCoreTests/SuperReviewerTierBTests/testTierB_2judges_nightlyEvaluation"
        ;;
    tierC)
        SAMPLE=200
        OUTPUT_SUBDIR="TierC"
        XCODE_TEST="ThumpCoreTests/SuperReviewerTierCTests/testTierC_6judges_fullEvaluation"
        ;;
    *)
        echo "Unknown tier: $TIER. Use 'tierA', 'tierB', or 'tierC'."
        exit 1
        ;;
esac

CAPTURE_DIR="$SCRIPT_DIR/CaptureOutput/SuperReviewerOutput/TierA"
RESULTS_DIR="$SCRIPT_DIR/CaptureOutput/$OUTPUT_SUBDIR/JudgeResults"
RUBRIC="$SCRIPT_DIR/RubricDefinitions/consolidated_rubric_v1.json"

# ── Step 1: Export captures ────────────────────────────────────────────────────
echo "► Step 1/3: Generating captures via Tier A export..."
cd "$PROJECT_DIR"
xcodebuild test \
  -project Thump.xcodeproj \
  -scheme Thump \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -only-testing "ThumpCoreTests/SuperReviewerTierATests/testExportTierACaptures_toJSON" \
  2>&1 | grep -E "(SuperReviewer|PASSED|FAILED|error:)" | head -10
echo ""

# ── Step 2: Run judges via Python + claude CLI ─────────────────────────────────
echo "► Step 2/3: Running persona judges via Claude Code CLI..."
python3 "$SCRIPT_DIR/judge_runner.py" \
  --tier "$TIER" \
  --capture-dir "$CAPTURE_DIR" \
  --results-dir "$RESULTS_DIR" \
  --rubric "$RUBRIC" \
  --sample "$SAMPLE" \
  --claude "$CLAUDE_BIN"
echo ""

# ── Step 3: XCTest quality gates ──────────────────────────────────────────────
echo "► Step 3/3: Running XCTest quality gates..."
xcodebuild test \
  -project Thump.xcodeproj \
  -scheme Thump \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -only-testing "$XCODE_TEST" \
  2>&1 | grep -E "(SuperReviewer|PASSED|FAILED|Test Case|skipping|error:|Average|consensus|Score range|═|─)"

echo ""
echo "Done. Judge results saved to: $RESULTS_DIR"

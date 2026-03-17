#!/bin/bash
# run_judges.sh
# Runs the Super Reviewer LLM persona judge evaluation.
#
# Usage:
#   export ANTHROPIC_API_KEY=sk-ant-...
#   ./Tests/SuperReviewer/run_judges.sh [tierB|tierC]
#
# Tier B: 4 judges (Marcus, Priya, David, Jordan) — ~50 sampled captures, ~5 min
# Tier C: all 6 judges — ~200 sampled captures, ~20 min

TIER=${1:-tierB}
SIMULATOR="iPhone 17 Pro"

if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "ERROR: ANTHROPIC_API_KEY not set."
    echo "       export ANTHROPIC_API_KEY=sk-ant-..."
    exit 1
fi

case "$TIER" in
    tierB)
        TEST_ID="ThumpCoreTests/SuperReviewerTierBTests/testTierB_2judges_nightlyEvaluation"
        echo "Running Tier B: 4 Claude persona judges (Marcus, Priya, David, Jordan)"
        ;;
    tierC)
        TEST_ID="ThumpCoreTests/SuperReviewerTierCTests/testTierC_6judges_fullEvaluation"
        echo "Running Tier C: all 6 Claude persona judges"
        ;;
    *)
        echo "Unknown tier: $TIER. Use 'tierB' or 'tierC'."
        exit 1
        ;;
esac

echo "Judges: Marcus Chen, Priya Okafor, David Nakamura, Jordan Rivera, Aisha Thompson, Sarah Kovacs"
echo ""

cd "$(dirname "$0")/../.." && \
xcodebuild test \
  -project Thump.xcodeproj \
  -scheme "Thump" \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -only-testing "$TEST_ID" \
  -testenv ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  2>&1 | grep -E "(SuperReviewer|\[Marcus\]|\[Priya\]|\[David\]|\[Jordan\]|\[Aisha\]|\[Sarah\]|PASSED|FAILED|Test Case|╔|╚|══|──|⚠️|Persona Judge|consensus|critical|Average|Duration|Score range)"

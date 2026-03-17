#!/bin/bash
# validate_test_coverage.sh
# Ensures every `func test*` defined in the Tests directory is accounted for
# in the Xcode test run. Run after `xcodebuild test` to catch orphaned tests.
#
# Usage:
#   1. Run tests:  xcodebuild -project Thump.xcodeproj -scheme Thump \
#                    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tee test_output.log
#   2. Validate:   ./Tests/validate_test_coverage.sh test_output.log
#
# Exit codes: 0 = all tests accounted for, 1 = orphaned tests found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"
PROJECT_DIR="$(dirname "$TESTS_DIR")"

# --- Count defined tests ---
DEFINED_TESTS=$(grep -rn "func test" "$TESTS_DIR" --include="*.swift" | sed 's/.*func \(test[^(]*\).*/\1/' | sort -u)
DEFINED_COUNT=$(echo "$DEFINED_TESTS" | wc -l | tr -d ' ')

# --- Count tests in Xcode project ---
PBXPROJ="$PROJECT_DIR/Thump.xcodeproj/project.pbxproj"
MISSING_FILES=()
for f in $(find "$TESTS_DIR" -name "*Tests.swift" -exec basename {} \;); do
    if ! grep -q "$f" "$PBXPROJ" 2>/dev/null; then
        MISSING_FILES+=("$f")
    fi
done

# --- If a test log was provided, compare executed vs defined ---
EXECUTED_COUNT=0
SKIPPED_COUNT=0
ORPHANED_TESTS=()

if [ -n "${1:-}" ] && [ -f "$1" ]; then
    LOG_FILE="$1"

    # Extract executed test names from xcodebuild output
    EXECUTED_TESTS=$(grep "Test Case.*started" "$LOG_FILE" | sed "s/.*Test Case '-\[ThumpCoreTests\.\([^ ]*\) \(test[^']*\)\]'.*/\2/" | sort -u)
    EXECUTED_COUNT=$(echo "$EXECUTED_TESTS" | wc -l | tr -d ' ')

    # Extract skipped tests
    SKIPPED_COUNT=$(grep -c "skipped" "$LOG_FILE" 2>/dev/null || echo "0")

    # Find orphaned tests (defined but never executed)
    while IFS= read -r test; do
        if ! echo "$EXECUTED_TESTS" | grep -q "^${test}$"; then
            ORPHANED_TESTS+=("$test")
        fi
    done <<< "$DEFINED_TESTS"
fi

# --- Report ---
echo "============================================"
echo "  TEST PIPELINE COVERAGE VALIDATION"
echo "============================================"
echo ""
echo "  Defined test functions:    $DEFINED_COUNT"
if [ "$EXECUTED_COUNT" -gt 0 ]; then
    echo "  Executed in last run:      $EXECUTED_COUNT"
    echo "  Skipped:                   $SKIPPED_COUNT"
fi
echo ""

EXIT_CODE=0

# Report files missing from Xcode project
if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo "⚠️  FILES NOT IN XCODE PROJECT (tests will never run):"
    for f in "${MISSING_FILES[@]}"; do
        TEST_COUNT=$(grep -c "func test" "$TESTS_DIR/$f" 2>/dev/null || grep -c "func test" "$TESTS_DIR"/**/"$f" 2>/dev/null || echo "?")
        echo "    ❌ $f ($TEST_COUNT tests)"
    done
    echo ""
    EXIT_CODE=1
fi

# Report orphaned tests
if [ ${#ORPHANED_TESTS[@]} -gt 0 ]; then
    echo "⚠️  ORPHANED TESTS (defined but not executed):"
    for t in "${ORPHANED_TESTS[@]}"; do
        FILE=$(grep -rn "func $t" "$TESTS_DIR" --include="*.swift" | head -1 | cut -d: -f1 | xargs basename 2>/dev/null || echo "unknown")
        echo "    ❌ $t  ($FILE)"
    done
    echo ""
    EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All $DEFINED_COUNT test functions are in the pipeline."
else
    ORPHAN_COUNT=${#ORPHANED_TESTS[@]}
    MISSING_COUNT=${#MISSING_FILES[@]}
    echo "❌ $ORPHAN_COUNT orphaned tests, $MISSING_COUNT files missing from project."
    echo ""
    echo "ACTION REQUIRED: Add missing files to ThumpCoreTests target in Xcode."
fi

echo "============================================"
exit $EXIT_CODE

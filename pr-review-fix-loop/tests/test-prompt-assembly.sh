#!/bin/bash
# Smoke tests for assemble-prompt.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSEMBLE="$SCRIPT_DIR/scripts/assemble-prompt.sh"

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  FAIL: $1"; }

echo "Running assemble-prompt.sh smoke tests..."
echo ""

# Test 1: Default args — no template placeholders, exit 0
echo "Test 1: Default args, no placeholders"
OUTPUT=$("$ASSEMBLE" 2>/dev/null)
if echo "$OUTPUT" | grep -qP '\{[a-z_]+\}'; then
  fail "Template placeholders found in output"
else
  pass "No template placeholders in default output"
fi

# Test 2: --codex --base master
echo "Test 2: --codex --base master"
OUTPUT=$("$ASSEMBLE" --codex --base master 2>/dev/null)
if echo "$OUTPUT" | grep -q "codex review --base master" && \
   echo "$OUTPUT" | grep -q "Шаг 0:" && \
   echo "$OUTPUT" | grep -q "Шаг 1.5:"; then
  pass "--codex --base master includes codex steps"
else
  fail "Missing codex steps with --codex --base master"
fi

# Test 3: --lint --lint-cmd "bundle exec rubocop -a"
echo "Test 3: --lint --lint-cmd"
OUTPUT=$("$ASSEMBLE" --lint --lint-cmd "bundle exec rubocop -a" 2>/dev/null)
if echo "$OUTPUT" | grep -q "Шаг 3.5:" && \
   echo "$OUTPUT" | grep -q "bundle exec rubocop -a"; then
  pass "--lint --lint-cmd includes lint step"
else
  fail "Missing lint step with --lint --lint-cmd"
fi

# Test 4: --codex --base main --lint --lint-cmd "rubocop -a"
echo "Test 4: Both codex and lint"
OUTPUT=$("$ASSEMBLE" --codex --base main --lint --lint-cmd "rubocop -a" 2>/dev/null)
if echo "$OUTPUT" | grep -q "Шаг 0:" && \
   echo "$OUTPUT" | grep -q "Шаг 3.5:"; then
  pass "Both codex and lint steps present"
else
  fail "Missing steps when both codex and lint enabled"
fi

# Test 5: Output is single line
echo "Test 5: Single line output"
OUTPUT=$("$ASSEMBLE" 2>/dev/null)
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
if [[ "$LINE_COUNT" -eq 1 ]]; then
  pass "Output is exactly 1 line"
else
  fail "Output is $LINE_COUNT lines, expected 1"
fi

# Test 6: --codex without --base
echo "Test 6: --codex without --base warns"
STDERR=$("$ASSEMBLE" --codex 2>&1 >/dev/null || true)
OUTPUT=$("$ASSEMBLE" --codex 2>/dev/null)
if echo "$STDERR" | grep -q "Warning.*--codex.*--base" && \
   ! echo "$OUTPUT" | grep -q "Шаг 0:"; then
  pass "--codex without --base: warning + no codex steps"
else
  fail "--codex without --base: missing warning or has codex steps"
fi

# Test 7: No env-exec — must NOT contain the phrase
echo "Test 7: No --env-exec"
OUTPUT=$("$ASSEMBLE" 2>/dev/null)
if echo "$OUTPUT" | grep -q "Все команды запускать через"; then
  fail "env-exec phrase present without --env-exec flag"
else
  pass "No env-exec phrase without --env-exec flag"
fi

# Test 8: --env-exec "direnv exec ."
echo "Test 8: --env-exec"
OUTPUT=$("$ASSEMBLE" --env-exec "direnv exec ." 2>/dev/null)
if echo "$OUTPUT" | grep -q "Все команды запускать через direnv exec ."; then
  pass "--env-exec phrase present in output"
else
  fail "Missing env-exec phrase with --env-exec flag"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed out of $((PASSED + FAILED))"
[[ "$FAILED" -eq 0 ]] && exit 0 || exit 1

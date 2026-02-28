#!/bin/bash

# Tests for pr-review-fix-loop scripts
# Usage: ./pr-review-fix-loop/tests/test-loop-scripts.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/scripts/setup-loop.sh"
STOP_HOOK="$SCRIPT_DIR/hooks/stop-hook.sh"

PASSED=0
FAILED=0
TMPDIR=""

# --- Helpers ---

setup() {
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  mkdir -p .claude
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

pass() {
  PASSED=$((PASSED + 1))
  echo "  PASS: $1"
}

fail() {
  FAILED=$((FAILED + 1))
  echo "  FAIL: $1"
  if [[ -n "${2:-}" ]]; then
    echo "        $2"
  fi
}

create_state_file() {
  local iteration="${1:-1}"
  local max="${2:-20}"
  local promise="${3:-null}"
  local prompt="${4:-Review and fix PR issues}"

  if [[ "$promise" != "null" ]]; then
    promise="\"$promise\""
  fi

  cat > .claude/pr-review-fix-loop.local.md <<EOF
---
active: true
iteration: $iteration
max_iterations: $max
completion_promise: $promise
started_at: "2026-02-23T00:00:00Z"
---

$prompt
EOF
}

create_transcript() {
  local text="$1"
  local file="${2:-transcript.jsonl}"

  # Write a JSONL line with an assistant message (compact for grep)
  jq -cn --arg t "$text" '{
    "role": "assistant",
    "message": {
      "content": [{"type": "text", "text": $t}]
    }
  }' > "$file"
}

hook_input() {
  local transcript_path="$1"
  jq -n --arg p "$transcript_path" '{"transcript_path": $p}'
}

# --- setup-loop.sh tests ---

echo "=== setup-loop.sh ==="

# Test 1: Creates state file with correct frontmatter
setup
echo "Review the PR" | bash "$SETUP_SCRIPT" --max-iterations 5 --completion-promise "All issues resolved" >/dev/null
if [[ -f .claude/pr-review-fix-loop.local.md ]]; then
  content=$(cat .claude/pr-review-fix-loop.local.md)
  ok=true
  echo "$content" | grep -q '^iteration: 1$' || ok=false
  echo "$content" | grep -q '^max_iterations: 5$' || ok=false
  echo "$content" | grep -q '^completion_promise: "All issues resolved"$' || ok=false
  echo "$content" | grep -q 'Review the PR' || ok=false
  if $ok; then
    pass "creates state file with correct frontmatter"
  else
    fail "creates state file with correct frontmatter" "missing expected fields"
  fi
else
  fail "creates state file with correct frontmatter" "state file not created"
fi
teardown

# Test 2: Empty stdin -> exit 1
setup
if echo -n "" | bash "$SETUP_SCRIPT" 2>/dev/null; then
  fail "empty stdin exits with error" "expected exit 1"
else
  pass "empty stdin exits with error"
fi
teardown

# Test 3: Invalid --max-iterations -> exit 1
setup
if echo "test" | bash "$SETUP_SCRIPT" --max-iterations abc 2>/dev/null; then
  fail "invalid --max-iterations exits with error" "expected exit 1"
else
  pass "invalid --max-iterations exits with error"
fi
teardown

# Test 4: Missing --completion-promise argument -> exit 1
setup
if echo "test" | bash "$SETUP_SCRIPT" --completion-promise 2>/dev/null; then
  fail "missing --completion-promise arg exits with error" "expected exit 1"
else
  pass "missing --completion-promise arg exits with error"
fi
teardown

# Test 5: Default max_iterations = 20
setup
echo "test prompt" | bash "$SETUP_SCRIPT" >/dev/null
if grep -q '^max_iterations: 20$' .claude/pr-review-fix-loop.local.md; then
  pass "default max_iterations is 20"
else
  fail "default max_iterations is 20"
fi
teardown

# Test 6: Null completion_promise when not specified
setup
echo "test prompt" | bash "$SETUP_SCRIPT" >/dev/null
if grep -q '^completion_promise: null$' .claude/pr-review-fix-loop.local.md; then
  pass "null completion_promise when not specified"
else
  fail "null completion_promise when not specified"
fi
teardown

# --- stop-hook.sh tests ---

echo ""
echo "=== stop-hook.sh ==="

# Test 7: No state file -> exit 0, does not block
setup
OUTPUT=$(echo '{}' | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && [[ -z "$OUTPUT" ]]; then
  pass "no state file -> exits 0, no output"
else
  fail "no state file -> exits 0, no output" "exit=$EXIT_CODE output='$OUTPUT'"
fi
teardown

# Test 8: max_iterations reached -> exit 0, writes exit reason, deletes state
setup
create_state_file 5 5 "null"
touch .claude/pr-review-loop-report.local.md
OUTPUT=$(echo '{}' | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
[[ ! -f .claude/pr-review-fix-loop.local.md ]] || ok=false
grep -q '\[EXIT:LIMIT\]' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
if $ok; then
  pass "max iterations reached -> cleanup and exit reason"
else
  fail "max iterations reached -> cleanup and exit reason" "exit=$EXIT_CODE state_exists=$(test -f .claude/pr-review-fix-loop.local.md && echo yes || echo no)"
fi
teardown

# Test 9: Promise detected -> exit 0, deletes state
setup
create_state_file 1 10 "All issues resolved"
create_transcript '<promise>All issues resolved</promise>'
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "promise detected -> exit 0, state deleted"
else
  fail "promise detected -> exit 0, state deleted" "exit=$EXIT_CODE state_exists=$(test -f .claude/pr-review-fix-loop.local.md && echo yes || echo no)"
fi
teardown

# Test 10: Normal iteration -> blocks, increments, writes marker
setup
create_state_file 1 10 "null" "Fix the bugs"
create_transcript "I fixed some issues but more remain"
touch .claude/pr-review-loop-report.local.md
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.reason | contains("Fix the bugs")' >/dev/null 2>&1 || ok=false
grep -q "ИТЕРАЦИЯ 2 НАЧАЛО" .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
grep -q '^iteration: 2$' .claude/pr-review-fix-loop.local.md 2>/dev/null || ok=false
if $ok; then
  pass "normal iteration -> block, increment, marker"
else
  fail "normal iteration -> block, increment, marker" "exit=$EXIT_CODE output='$OUTPUT'"
fi
teardown

# Test 11: Corrupted state file -> exit 0, deletes state (Bug 1 fix)
setup
cat > .claude/pr-review-fix-loop.local.md <<'EOF'
---
active: true
garbage_field: something
---

some prompt
EOF
OUTPUT=$(echo '{}' | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "corrupted state file -> graceful cleanup"
else
  fail "corrupted state file -> graceful cleanup" "exit=$EXIT_CODE state_exists=$(test -f .claude/pr-review-fix-loop.local.md && echo yes || echo no)"
fi
teardown

# Test 12: Missing transcript -> exit 0, deletes state
setup
create_state_file 1 10 "null"
INPUT=$(hook_input "/nonexistent/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "missing transcript -> graceful cleanup"
else
  fail "missing transcript -> graceful cleanup" "exit=$EXIT_CODE"
fi
teardown

# Test 13: No report file -> still blocks (does not crash)
setup
create_state_file 1 10 "null" "Do review"
create_transcript "Working on it"
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
# Intentionally do NOT create .claude/pr-review-loop-report.local.md
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  pass "no report file -> still blocks without crash"
else
  fail "no report file -> still blocks without crash" "exit=$EXIT_CODE output='$OUTPUT'"
fi
teardown

# Test 14: null completion_promise -> does not detect promise, continues loop
setup
create_state_file 1 10 "null" "Review PR"
create_transcript '<promise>something</promise>'
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  pass "null completion_promise -> ignores promise tags, continues loop"
else
  fail "null completion_promise -> ignores promise tags, continues loop" "exit=$EXIT_CODE output='$OUTPUT'"
fi
teardown

# --- New tests (15-24) ---

echo ""
echo "=== New tests ==="

# Test 15: Multiple --completion-promise joined with pipe
setup
echo "test prompt" | bash "$SETUP_SCRIPT" --completion-promise "REVIEW CLEAN" --completion-promise "REVIEW STAGNANT" >/dev/null
if grep -q '^completion_promise: "REVIEW CLEAN|REVIEW STAGNANT"$' .claude/pr-review-fix-loop.local.md; then
  pass "multiple --completion-promise joined with pipe"
else
  fail "multiple --completion-promise joined with pipe" "$(grep completion_promise .claude/pr-review-fix-loop.local.md)"
fi
teardown

# Test 16: REVIEW CLEAN -> [EXIT:SUCCESS] in report
setup
create_state_file 1 20 "REVIEW CLEAN|REVIEW STAGNANT"
touch .claude/pr-review-loop-report.local.md
create_transcript '<promise>REVIEW CLEAN</promise>'
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
[[ ! -f .claude/pr-review-fix-loop.local.md ]] || ok=false
grep -q '\[OK\] \[EXIT:SUCCESS\]' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
if $ok; then
  pass "REVIEW CLEAN -> [EXIT:SUCCESS] in report"
else
  fail "REVIEW CLEAN -> [EXIT:SUCCESS] in report" "exit=$EXIT_CODE report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 17: REVIEW STAGNANT -> [EXIT:STAGNANT] in report
setup
create_state_file 1 20 "REVIEW CLEAN|REVIEW STAGNANT"
touch .claude/pr-review-loop-report.local.md
create_transcript '<promise>REVIEW STAGNANT</promise>'
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
[[ ! -f .claude/pr-review-fix-loop.local.md ]] || ok=false
grep -q '\[!!\] \[EXIT:STAGNANT\]' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
if $ok; then
  pass "REVIEW STAGNANT -> [EXIT:STAGNANT] in report"
else
  fail "REVIEW STAGNANT -> [EXIT:STAGNANT] in report" "exit=$EXIT_CODE report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 18: Max iterations -> [EXIT:LIMIT] in report
setup
create_state_file 5 5 "null"
touch .claude/pr-review-loop-report.local.md
OUTPUT=$(echo '{}' | bash "$STOP_HOOK" 2>/dev/null)
ok=true
grep -q '\[!!\] \[EXIT:LIMIT\]' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
grep -q 'Max iterations (5) reached' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
if $ok; then
  pass "max iterations -> [EXIT:LIMIT] with reason in report"
else
  fail "max iterations -> [EXIT:LIMIT] with reason in report" "report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 19: Corrupted state -> [EXIT:ERROR] in report
setup
cat > .claude/pr-review-fix-loop.local.md <<'EOF'
---
active: true
iteration: abc
max_iterations: xyz
---

some prompt
EOF
touch .claude/pr-review-loop-report.local.md
OUTPUT=$(echo '{}' | bash "$STOP_HOOK" 2>/dev/null)
if grep -q '\[XX\] \[EXIT:ERROR\]' .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "corrupted state -> [EXIT:ERROR] in report"
else
  fail "corrupted state -> [EXIT:ERROR] in report" "report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 20: Missing transcript -> [EXIT:ERROR] in report
setup
create_state_file 1 10 "null"
touch .claude/pr-review-loop-report.local.md
INPUT=$(hook_input "/nonexistent/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
if grep -q '\[XX\] \[EXIT:ERROR\]' .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "missing transcript -> [EXIT:ERROR] in report"
else
  fail "missing transcript -> [EXIT:ERROR] in report" "report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 21: Unknown promise text -> loop continues (block)
setup
create_state_file 1 20 "REVIEW CLEAN|REVIEW STAGNANT" "Do review"
create_transcript '<promise>SOMETHING ELSE</promise>'
touch .claude/pr-review-loop-report.local.md
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
[[ -f .claude/pr-review-fix-loop.local.md ]] || ok=false
if $ok; then
  pass "unknown promise text -> loop continues (block)"
else
  fail "unknown promise text -> loop continues (block)" "exit=$EXIT_CODE output='$OUTPUT'"
fi
teardown

# Test 22: Default max_iterations = 20 (setup-loop)
setup
OUTPUT=$(echo "test" | bash "$SETUP_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | grep -q 'max 20'; then
  pass "default max_iterations = 20 in output"
else
  fail "default max_iterations = 20 in output" "output='$OUTPUT'"
fi
teardown

# Test 23: Single promise -> [EXIT:SUCCESS] (backward compatibility)
setup
create_state_file 1 10 "REVIEW CLEAN"
touch .claude/pr-review-loop-report.local.md
create_transcript '<promise>REVIEW CLEAN</promise>'
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
[[ ! -f .claude/pr-review-fix-loop.local.md ]] || ok=false
grep -q '\[OK\] \[EXIT:SUCCESS\]' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
if $ok; then
  pass "single promise -> [EXIT:SUCCESS] (backward compat)"
else
  fail "single promise -> [EXIT:SUCCESS] (backward compat)" "exit=$EXIT_CODE report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 24: Error exit without report file -> does not crash
setup
create_state_file 1 10 "null"
# Intentionally do NOT create report file
INPUT=$(hook_input "/nonexistent/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "error exit without report file -> does not crash"
else
  fail "error exit without report file -> does not crash" "exit=$EXIT_CODE"
fi
teardown

# --- Summary ---

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi

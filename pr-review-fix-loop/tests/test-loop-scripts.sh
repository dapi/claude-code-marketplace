#!/bin/bash

# Tests for pr-review-fix-loop scripts
# Usage: ./pr-review-fix-loop/tests/test-loop-scripts.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/scripts/setup-loop.sh"
STOP_HOOK="$SCRIPT_DIR/hooks/stop-hook.sh"
CHECK_GITIGNORE="$SCRIPT_DIR/scripts/check-gitignore.sh"
RECORD_ITERATION="$SCRIPT_DIR/scripts/record-iteration.sh"
SHOW_PROGRESS="$SCRIPT_DIR/scripts/show-progress.sh"
POST_LOOP_PROMPT="$SCRIPT_DIR/scripts/post-loop-prompt.sh"

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

create_stats_file() {
  local max="${1:-10}"
  local started="${2:-2026-02-28T10:00:00Z}"
  cat > .claude/pr-review-loop-stats.local.json <<EOF
{
  "version": "1.10.0",
  "started_at": "$started",
  "max_iterations": $max,
  "iterations": []
}
EOF
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
grep -q "ITERATION 2 START" .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
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

# Test 12: Missing transcript -> continues loop (transient error recovery)
setup
create_state_file 1 10 "null" "Do review"
touch .claude/pr-review-loop-report.local.md
INPUT=$(hook_input "/nonexistent/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
[[ -f .claude/pr-review-fix-loop.local.md ]] || ok=false
grep -q '\[EXIT:WARN\]' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
if $ok; then
  pass "missing transcript -> continues loop with WARN"
else
  fail "missing transcript -> continues loop with WARN" "exit=$EXIT_CODE output='$OUTPUT'"
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

# Test 16: REVIEW CLEAN -> [EXIT:SUCCESS] in report + block response
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
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "REVIEW CLEAN -> [EXIT:SUCCESS] in report + block response"
else
  fail "REVIEW CLEAN -> [EXIT:SUCCESS] in report + block response" "exit=$EXIT_CODE output=$OUTPUT report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 17: REVIEW STAGNANT -> [EXIT:STAGNANT] in report + block response
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
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "REVIEW STAGNANT -> [EXIT:STAGNANT] in report + block response"
else
  fail "REVIEW STAGNANT -> [EXIT:STAGNANT] in report + block response" "exit=$EXIT_CODE output=$OUTPUT report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 18: Max iterations -> [EXIT:LIMIT] in report + block response
setup
create_state_file 5 5 "null"
touch .claude/pr-review-loop-report.local.md
OUTPUT=$(echo '{}' | bash "$STOP_HOOK" 2>/dev/null)
ok=true
grep -q '\[!!\] \[EXIT:LIMIT\]' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
grep -q 'Max iterations (5) reached' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "max iterations -> [EXIT:LIMIT] with reason + block response"
else
  fail "max iterations -> [EXIT:LIMIT] with reason + block response" "output=$OUTPUT report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
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

# Test 20: Missing transcript -> [EXIT:WARN] in report (continues loop)
setup
create_state_file 1 10 "null" "Do review"
touch .claude/pr-review-loop-report.local.md
INPUT=$(hook_input "/nonexistent/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
if grep -q '\[~~\] \[EXIT:WARN\]' .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "missing transcript -> [EXIT:WARN] in report"
else
  fail "missing transcript -> [EXIT:WARN] in report" "report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
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

# Test 24: Transient error without report file -> continues loop without crash
setup
create_state_file 1 10 "null" "Do review"
# Intentionally do NOT create report file
INPUT=$(hook_input "/nonexistent/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
[[ -f .claude/pr-review-fix-loop.local.md ]] || ok=false
if $ok; then
  pass "transient error without report file -> continues loop"
else
  fail "transient error without report file -> continues loop" "exit=$EXIT_CODE output='$OUTPUT'"
fi
teardown

# Test 25: Setup cleans previous artifacts
setup
# Create stale artifacts
echo "stale report" > .claude/pr-review-loop-report.local.md
echo "stale codex" > .codex-review.md
echo "stale stderr" > .codex-review.stderr
echo "test prompt" | bash "$SETUP_SCRIPT" >/dev/null
ok=true
# report should exist (fresh, not stale) after setup
[[ -f .claude/pr-review-loop-report.local.md ]] || ok=false
grep -q "^# PR Review Fix Loop Report" .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
grep -q "ITERATION 1 START" .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
! grep -q "stale report" .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
[[ ! -f .codex-review.md ]] || ok=false
[[ ! -f .codex-review.stderr ]] || ok=false
if $ok; then
  pass "setup cleans previous artifacts and creates fresh report"
else
  fail "setup cleans previous artifacts and creates fresh report" "report=$(test -f .claude/pr-review-loop-report.local.md && cat .claude/pr-review-loop-report.local.md | head -1 || echo gone) codex=$(test -f .codex-review.md && echo exists || echo gone)"
fi
teardown

# Test 26: Setup outputs version
setup
OUTPUT=$(echo "test prompt" | bash "$SETUP_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | grep -qP '^pr-review-fix-loop v\d+\.\d+\.\d+$'; then
  pass "setup outputs version"
else
  fail "setup outputs version" "output='$(echo "$OUTPUT" | head -1)'"
fi
teardown

# Test 27: Promise with leading/trailing whitespace should match
setup
create_state_file 1 20 "REVIEW CLEAN|REVIEW STAGNANT"
touch .claude/pr-review-loop-report.local.md
create_transcript '<promise>  REVIEW CLEAN  </promise>'
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
[[ ! -f .claude/pr-review-fix-loop.local.md ]] || ok=false
grep -q '\[OK\] \[EXIT:SUCCESS\]' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
if $ok; then
  pass "promise with whitespace -> strips and matches"
else
  fail "promise with whitespace -> strips and matches" "exit=$EXIT_CODE report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 28: --report-params written to report file
setup
echo "test prompt" | bash "$SETUP_SCRIPT" --report-params "aspects=code errors, min-criticality=5, lint=no, codex=no" >/dev/null
if grep -q 'aspects=code errors, min-criticality=5, lint=no, codex=no' .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "--report-params written to report file"
else
  fail "--report-params written to report file" "report=$(head -4 .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 29: Multiline promise should match (P1 fix)
setup
create_state_file 1 20 "REVIEW CLEAN|REVIEW STAGNANT"
touch .claude/pr-review-loop-report.local.md
# Promise split across lines
create_transcript "$(printf 'Some text\n<promise>\nREVIEW CLEAN\n</promise>\nMore text')"
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
[[ ! -f .claude/pr-review-fix-loop.local.md ]] || ok=false
grep -q '\[OK\] \[EXIT:SUCCESS\]' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
if $ok; then
  pass "multiline promise -> collapses and matches"
else
  fail "multiline promise -> collapses and matches" "exit=$EXIT_CODE report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# --- record-iteration.sh tests ---

echo ""
echo "=== record-iteration.sh ==="

# Test 30: Invalid args -> exit 1
setup
create_stats_file 10
if bash "$RECORD_ITERATION" abc 5 2>/dev/null; then
  fail "invalid iteration -> exit 1" "expected failure"
else
  pass "invalid iteration -> exit 1"
fi
teardown

# Test 31: Missing stats file -> exit 2
setup
if bash "$RECORD_ITERATION" 1 5 2>/dev/null; then
  fail "missing stats file -> exit 2" "expected failure"
else
  pass "missing stats file -> exit 2"
fi
teardown

# Test 32: Zero issues -> records correctly
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 0 >/dev/null
IC=$(jq '.iterations[0].issues_count' .claude/pr-review-loop-stats.local.json)
if [[ "$IC" -eq 0 ]]; then
  pass "zero issues -> records correctly"
else
  fail "zero issues -> records correctly" "ic=$IC"
fi
teardown

# --- show-progress.sh tests ---

echo ""
echo "=== show-progress.sh ==="

# Test 33: No stats file -> minimal banner
setup
OUTPUT=$(bash "$SHOW_PROGRESS" --result ERROR --message "test error" 2>&1)
ok=true
echo "$OUTPUT" | grep -q 'no stats available' || ok=false
echo "$OUTPUT" | grep -qi 'error' || ok=false
if $ok; then
  pass "no stats file -> minimal banner with result"
else
  fail "no stats file -> minimal banner with result" "output=$OUTPUT"
fi
teardown

# Test 34: With stats -> renders progress bar
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 12 >/dev/null
bash "$RECORD_ITERATION" 2 8 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
ok=true
echo "$OUTPUT" | grep -q 'v1.10.0' || ok=false
echo "$OUTPUT" | grep -q '2/10' || ok=false
echo "$OUTPUT" | grep -q '12 -> 8' || ok=false
echo "$OUTPUT" | grep -q 'Elapsed' || ok=false
if $ok; then
  pass "with stats -> renders progress bar"
else
  fail "with stats -> renders progress bar" "output=$OUTPUT"
fi
teardown

# Test 35: Terminal result -> shows colored result line
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 12 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" --result SUCCESS --message "REVIEW CLEAN" 2>&1)
if echo "$OUTPUT" | grep -q 'REVIEW CLEAN'; then
  pass "terminal result -> shows result line"
else
  fail "terminal result -> shows result line" "output=$OUTPUT"
fi
teardown

# Test 36: No result flag -> no Result line
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 12 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q 'Result'; then
  fail "no result flag -> no Result line" "unexpected Result line"
else
  pass "no result flag -> no Result line"
fi
teardown

# Test 37: Always exits 0
setup
EXIT_CODE=0
bash "$SHOW_PROGRESS" 2>/dev/null || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
  pass "always exits 0 even without stats"
else
  fail "always exits 0 even without stats" "exit=$EXIT_CODE"
fi
teardown

# --- check-gitignore.sh tests ---

echo ""
echo "=== check-gitignore.sh ==="

# Test 38: All files ignored -> action_needed false
setup
git init -q .
echo '.claude/*.local.md' >> .gitignore
echo '.claude/*.local.json' >> .gitignore
echo '.claude/*.local.log' >> .gitignore
echo '.codex-review.md' >> .gitignore
echo '.codex-review.stderr' >> .gitignore
OUTPUT=$(bash "$CHECK_GITIGNORE")
if echo "$OUTPUT" | jq -e '.action_needed == false' >/dev/null 2>&1; then
  pass "all files ignored -> action_needed false"
else
  fail "all files ignored -> action_needed false" "output=$OUTPUT"
fi
teardown

# Test 39: No .gitignore -> action_needed true with all files
setup
git init -q .
OUTPUT=$(bash "$CHECK_GITIGNORE")
ok=true
echo "$OUTPUT" | jq -e '.action_needed == true' >/dev/null 2>&1 || ok=false
COUNT=$(echo "$OUTPUT" | jq '.missing | length')
[[ "$COUNT" -eq 6 ]] || ok=false
if $ok; then
  pass "no .gitignore -> action_needed true, 6 missing"
else
  fail "no .gitignore -> action_needed true, 6 missing" "output=$OUTPUT"
fi
teardown

# Test 40: Partial .gitignore -> reports only missing files
setup
git init -q .
echo '.codex-review.md' >> .gitignore
echo '.codex-review.stderr' >> .gitignore
OUTPUT=$(bash "$CHECK_GITIGNORE")
ok=true
echo "$OUTPUT" | jq -e '.action_needed == true' >/dev/null 2>&1 || ok=false
COUNT=$(echo "$OUTPUT" | jq '.missing | length')
[[ "$COUNT" -eq 4 ]] || ok=false
if $ok; then
  pass "partial .gitignore -> reports 4 missing"
else
  fail "partial .gitignore -> reports 4 missing" "output=$OUTPUT count=$COUNT"
fi
teardown

# --- record-iteration.sh edge cases ---

echo ""
echo "=== record-iteration.sh edge cases ==="

# Test 41: Wrong number of arguments (0 args) -> exit 1
setup
create_stats_file 10
if bash "$RECORD_ITERATION" 2>/dev/null; then
  fail "0 args -> exit 1" "expected failure"
else
  pass "0 args -> exit 1"
fi
teardown

# Test 42: Wrong number of arguments (1 arg) -> exit 1
setup
create_stats_file 10
if bash "$RECORD_ITERATION" 1 2>/dev/null; then
  fail "1 arg -> exit 1" "expected failure"
else
  pass "1 arg -> exit 1"
fi
teardown

# Test 43: Wrong number of arguments (3 args) -> exit 1
setup
create_stats_file 10
if bash "$RECORD_ITERATION" 1 5 extra 2>/dev/null; then
  fail "3 args -> exit 1" "expected failure"
else
  pass "3 args -> exit 1"
fi
teardown

# Test 44: Iteration=0 -> exit 1
setup
create_stats_file 10
if bash "$RECORD_ITERATION" 0 5 2>/dev/null; then
  fail "iteration=0 -> exit 1" "expected failure"
else
  pass "iteration=0 -> exit 1"
fi
teardown

# Test 45: Invalid issues_count format -> exit 1
setup
create_stats_file 10
if bash "$RECORD_ITERATION" 1 abc 2>/dev/null; then
  fail "invalid issues_count -> exit 1" "expected failure"
else
  pass "invalid issues_count -> exit 1"
fi
teardown

# Test 46: Negative issues_count -> exit 1
setup
create_stats_file 10
if bash "$RECORD_ITERATION" 1 -5 2>/dev/null; then
  fail "negative issues_count -> exit 1" "expected failure"
else
  pass "negative issues_count -> exit 1"
fi
teardown

# Test 47: Invalid/corrupt JSON in stats file -> exit 2
setup
mkdir -p .claude
echo "NOT JSON" > .claude/pr-review-loop-stats.local.json
EXIT_CODE=0
bash "$RECORD_ITERATION" 1 5 2>/dev/null || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 2 ]]; then
  pass "corrupt JSON in stats file -> exit 2"
else
  fail "corrupt JSON in stats file -> exit 2" "exit=$EXIT_CODE"
fi
teardown

# --- show-progress.sh edge cases ---

echo ""
echo "=== show-progress.sh edge cases ==="

# Test 48: --result without following argument -> exits 0 (no crash)
setup
EXIT_CODE=0
bash "$SHOW_PROGRESS" --result 2>/dev/null || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
  pass "--result without arg -> exits 0"
else
  fail "--result without arg -> exits 0" "exit=$EXIT_CODE"
fi
teardown

# Test 49: Minimal banner with SUCCESS result type
setup
OUTPUT=$(bash "$SHOW_PROGRESS" --result SUCCESS --message "REVIEW CLEAN" 2>&1)
if echo "$OUTPUT" | grep -q 'REVIEW CLEAN' && echo "$OUTPUT" | grep -q 'no stats available'; then
  pass "minimal banner SUCCESS result type"
else
  fail "minimal banner SUCCESS result type" "output=$OUTPUT"
fi
teardown

# Test 50: Minimal banner with STAGNANT result type
setup
OUTPUT=$(bash "$SHOW_PROGRESS" --result STAGNANT --message "stuck" 2>&1)
if echo "$OUTPUT" | grep -q 'stuck'; then
  pass "minimal banner STAGNANT result type"
else
  fail "minimal banner STAGNANT result type" "output=$OUTPUT"
fi
teardown

# Test 51: Minimal banner with LIMIT result type
setup
OUTPUT=$(bash "$SHOW_PROGRESS" --result LIMIT --message "max reached" 2>&1)
if echo "$OUTPUT" | grep -q 'max reached'; then
  pass "minimal banner LIMIT result type"
else
  fail "minimal banner LIMIT result type" "output=$OUTPUT"
fi
teardown

# Test 52: Trend truncation with >7 iterations
setup
create_stats_file 20
for i in $(seq 1 8); do
  bash "$RECORD_ITERATION" "$i" $((20-i)) >/dev/null
done
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q '\.\.\.'; then
  pass "trend truncation with >7 iterations shows ..."
else
  fail "trend truncation with >7 iterations shows ..." "output=$OUTPUT"
fi
teardown

# Test 53: ETA appears after 3+ iterations
setup
create_stats_file 20
bash "$RECORD_ITERATION" 1 15 >/dev/null
bash "$RECORD_ITERATION" 2 10 >/dev/null
bash "$RECORD_ITERATION" 3 5 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q 'ETA'; then
  pass "ETA appears after 3+ iterations"
else
  fail "ETA appears after 3+ iterations" "output=$OUTPUT"
fi
teardown

# Test 54: Percentage increase display when issues go up
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 5 >/dev/null
bash "$RECORD_ITERATION" 2 10 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q '+'; then
  pass "percentage increase shows +"
else
  fail "percentage increase shows +" "output=$OUTPUT"
fi
teardown

# Test 55: FIRST_IC == 0 -> no percentage shown
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 0 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q '%'; then
  fail "FIRST_IC=0 -> no percentage" "unexpected percentage"
else
  pass "FIRST_IC=0 -> no percentage"
fi
teardown

# Test 56: Same issues count -> shows 0% not -0%
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 8 >/dev/null
bash "$RECORD_ITERATION" 2 8 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q '\-0%'; then
  fail "same count -> 0% not -0%" "shows -0%"
elif echo "$OUTPUT" | grep -q '(0%)'; then
  pass "same count -> shows (0%)"
else
  fail "same count -> 0% not -0%" "output=$OUTPUT"
fi
teardown

# --- check-gitignore.sh edge cases ---

echo ""
echo "=== check-gitignore.sh edge cases ==="

# Test 57: Outside git repository -> outputs warning with action_needed true
setup
# Do NOT run git init
OUTPUT=$(bash "$CHECK_GITIGNORE" 2>/dev/null)
ok=true
echo "$OUTPUT" | jq -e '.warning' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.action_needed == true' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.missing | length == 6' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "outside git repo -> warning, action_needed true, all files listed"
else
  fail "outside git repo -> warning, action_needed true, all files listed" "output=$OUTPUT"
fi
teardown

# --- stop-hook.sh edge cases ---

echo ""
echo "=== stop-hook.sh edge cases ==="

# Test 58: No assistant messages in transcript -> WARN + continues loop
setup
create_state_file 1 10 "null"
touch .claude/pr-review-loop-report.local.md
echo '{"role":"system","message":{"content":[{"type":"text","text":"hello"}]}}' > transcript.jsonl
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
# Master uses WARN + continue_loop for transient errors
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "no assistant messages -> WARN + continues loop"
else
  fail "no assistant messages -> WARN + continues loop" "exit=$EXIT_CODE output=$OUTPUT"
fi
teardown

# Test 59: Empty assistant text (tool_use only) -> WARN + continues loop
setup
create_state_file 1 10 "null"
touch .claude/pr-review-loop-report.local.md
jq -cn '{"role":"assistant","message":{"content":[{"type":"tool_use","name":"test","input":{}}]}}' > transcript.jsonl
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "empty assistant text (tool_use only) -> WARN + continues loop"
else
  fail "empty assistant text (tool_use only) -> WARN + continues loop" "exit=$EXIT_CODE"
fi
teardown

# Test 60: Empty prompt body in state file -> [EXIT:ERROR]
setup
cat > .claude/pr-review-fix-loop.local.md <<'EOF'
---
active: true
iteration: 1
max_iterations: 10
completion_promise: null
started_at: "2026-02-23T00:00:00Z"
---

EOF
touch .claude/pr-review-loop-report.local.md
create_transcript "I did some work"
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
[[ ! -f .claude/pr-review-fix-loop.local.md ]] || ok=false
if $ok; then
  pass "empty prompt body -> [EXIT:ERROR]"
else
  fail "empty prompt body -> [EXIT:ERROR]" "exit=$EXIT_CODE"
fi
teardown

# Test 61: Malformed hook input JSON -> aborts (set -euo pipefail)
setup
create_state_file 1 10 "null"
touch .claude/pr-review-loop-report.local.md
OUTPUT=$(echo "NOT JSON" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
# Master uses set -euo pipefail; jq fails on bad input -> non-zero exit
if [[ $EXIT_CODE -ne 0 ]]; then
  pass "malformed hook input -> non-zero exit (set -e)"
else
  fail "malformed hook input -> expected non-zero exit under set -euo pipefail" "exit=$EXIT_CODE"
fi
teardown

# Test 62: setup-loop.sh unknown option -> exit 1
setup
if echo "test" | bash "$SETUP_SCRIPT" --bogus-flag 2>/dev/null; then
  fail "unknown option -> exit 1" "expected failure"
else
  pass "unknown option -> exit 1"
fi
teardown

# Test 63: ETA with non-decreasing issues (stagnant) -> shows "at limit"
setup
create_stats_file 20
bash "$RECORD_ITERATION" 1 10 >/dev/null
bash "$RECORD_ITERATION" 2 10 >/dev/null
bash "$RECORD_ITERATION" 3 10 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q 'at limit'; then
  pass "ETA with stagnant issues shows (at limit)"
else
  fail "ETA with stagnant issues shows (at limit)" "output=$OUTPUT"
fi
teardown

# Test 64: systemMessage contains promise instructions
setup
create_state_file 1 10 "REVIEW CLEAN" "Do review"
create_transcript "I did some work"
touch .claude/pr-review-loop-report.local.md
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
if echo "$OUTPUT" | jq -e '.systemMessage | contains("REVIEW CLEAN")' >/dev/null 2>&1; then
  pass "systemMessage contains promise text"
else
  fail "systemMessage contains promise text" "output=$OUTPUT"
fi
teardown

# --- Iteration 3 tests ---

echo ""
echo "=== Iteration 3 tests ==="

# Test 65: Multiline promise text extraction
setup
create_state_file 1 20 "REVIEW CLEAN|REVIEW STAGNANT"
touch .claude/pr-review-loop-report.local.md
MULTILINE_TEXT=$'Here is my analysis.\n<promise>\nREVIEW CLEAN\n</promise>\nDone.'
create_transcript "$MULTILINE_TEXT"
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
[[ ! -f .claude/pr-review-fix-loop.local.md ]] || ok=false
grep -q '\[EXIT:SUCCESS\]' .claude/pr-review-loop-report.local.md 2>/dev/null || ok=false
if $ok; then
  pass "multiline promise text extraction"
else
  fail "multiline promise text extraction" "exit=$EXIT_CODE report=$(cat .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi
teardown

# Test 66: Multiple assistant messages - only last is checked
setup
create_state_file 1 20 "REVIEW CLEAN" "Do review"
touch .claude/pr-review-loop-report.local.md
jq -cn --arg t '<promise>REVIEW CLEAN</promise>' '{
  "role": "assistant",
  "message": {"content": [{"type": "text", "text": $t}]}
}' > transcript.jsonl
jq -cn --arg t 'I will continue working' '{
  "role": "assistant",
  "message": {"content": [{"type": "text", "text": $t}]}
}' >> transcript.jsonl
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
# Should NOT detect promise because last message has no promise
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "multiple assistant messages -> last one checked"
else
  fail "multiple assistant messages -> last one checked" "exit=$EXIT_CODE output='$OUTPUT'"
fi
teardown

# Test 67: Read-only state file directory -> aborts (set -euo pipefail)
setup
create_state_file 1 10 "null" "Do review"
create_transcript "I did some work"
touch .claude/pr-review-loop-report.local.md
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
chmod 555 .claude
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
chmod 755 .claude
# Master uses set -euo pipefail; sed temp file creation fails -> non-zero exit
if [[ $EXIT_CODE -ne 0 ]]; then
  pass "read-only state dir -> non-zero exit (set -e)"
else
  fail "read-only state dir -> expected non-zero exit under set -euo pipefail" "exit=$EXIT_CODE"
fi
teardown

# Test 68: Codex file cleanup in setup-loop.sh
setup
touch .codex-review.md
echo "old stderr" > .codex-review.stderr
echo "test prompt" | bash "$SETUP_SCRIPT" >/dev/null
ok=true
[[ ! -f .codex-review.md ]] || ok=false
[[ ! -f .codex-review.stderr ]] || ok=false
if $ok; then
  pass "setup-loop.sh cleans up codex files"
else
  fail "setup-loop.sh cleans up codex files"
fi
teardown

# Test 69: Progress banner failure during normal iteration -> loop still blocks
setup
create_state_file 1 10 "null" "Do review"
create_transcript "I did some work"
touch .claude/pr-review-loop-report.local.md
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
SAVED_PERMS=$(stat -c '%a' "$SHOW_PROGRESS")
chmod -x "$SHOW_PROGRESS"
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null)
EXIT_CODE=$?
chmod "$SAVED_PERMS" "$SHOW_PROGRESS"
ok=true
[[ $EXIT_CODE -eq 0 ]] || ok=false
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "banner failure -> loop still blocks"
else
  fail "banner failure -> loop still blocks" "exit=$EXIT_CODE output='$OUTPUT'"
fi
teardown

# --- Iteration 4 tests ---

echo ""
echo "=== Iteration 4 tests ==="

# Test 70: record-iteration.sh duration from previous completed_at (not started_at)
setup
OLD_START="2026-01-01T00:00:00Z"
RECENT_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n --arg sa "$OLD_START" --arg ca "$RECENT_TS" '{
  "version":"1.0",
  "started_at":$sa,
  "max_iterations":10,
  "iterations":[{"n":1,"issues_count":5,"completed_at":$ca,"duration_sec":300}]
}' > .claude/pr-review-loop-stats.local.json
bash "$RECORD_ITERATION" 2 3 >/dev/null
DUR2=$(jq '.iterations[1].duration_sec' .claude/pr-review-loop-stats.local.json)
if [[ "$DUR2" -lt 60 ]]; then
  pass "duration measured from previous completed_at"
else
  fail "duration measured from previous completed_at" "dur2=$DUR2 (expected < 60)"
fi
teardown

# Test 71: record-iteration.sh validates temp file is valid JSON
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 5 >/dev/null
if jq empty .claude/pr-review-loop-stats.local.json 2>/dev/null; then
  pass "record-iteration produces valid JSON output"
else
  fail "record-iteration produces valid JSON output"
fi
teardown

# Test 72: stop-hook.sh banner invoked from write_exit_reason (capture stderr)
setup
create_state_file 5 5 "null"
touch .claude/pr-review-loop-report.local.md
create_stats_file 5
bash "$RECORD_ITERATION" 1 10 >/dev/null
STDERR=$(echo '{}' | bash "$STOP_HOOK" 2>&1 1>/dev/null)
if echo "$STDERR" | grep -q 'pr-review-fix-loop'; then
  pass "banner invoked from write_exit_reason"
else
  fail "banner invoked from write_exit_reason" "stderr=$STDERR"
fi
teardown

# Test 73: show-progress.sh ETA linear path shows (linear) label
setup
create_stats_file 20
bash "$RECORD_ITERATION" 1 30 >/dev/null
bash "$RECORD_ITERATION" 2 20 >/dev/null
bash "$RECORD_ITERATION" 3 10 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q 'linear'; then
  pass "ETA linear path shows (linear)"
else
  fail "ETA linear path shows (linear)" "output=$OUTPUT"
fi
teardown

# Test 74: check-gitignore.sh partial .gitignore verifies specific missing files
setup
git init -q .
echo '.codex-review.md' >> .gitignore
echo '.codex-review.stderr' >> .gitignore
OUTPUT=$(bash "$CHECK_GITIGNORE")
ok=true
echo "$OUTPUT" | jq -e '.missing | index(".claude/pr-review-loop-report.local.md")' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.missing | index(".claude/pr-review-loop-stats.local.json")' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.missing | index(".claude/pr-review-fix-loop.local.md")' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "partial .gitignore -> specific missing files identified"
else
  fail "partial .gitignore -> specific missing files identified" "output=$OUTPUT"
fi
teardown

# Test 75: show-progress.sh with corrupt stats (missing fields) -> renders without crash
setup
mkdir -p .claude
echo '{"iterations":[]}' > .claude/pr-review-loop-stats.local.json
EXIT_CODE=0
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -q 'pr-review-fix-loop'; then
  pass "corrupt stats (missing fields) -> renders without crash"
else
  fail "corrupt stats (missing fields) -> renders without crash" "exit=$EXIT_CODE output=$OUTPUT"
fi
teardown

# Test 76: show-progress.sh progress bar clamped to BAR_WIDTH
setup
create_stats_file 3
for i in $(seq 1 5); do
  bash "$RECORD_ITERATION" "$i" $((10-i)) >/dev/null
done
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
BAR=$(echo "$OUTPUT" | grep -o '\[#*\.*\]' | head -1)
HASH_COUNT=$(echo "$BAR" | tr -cd '#' | wc -c)
if [[ "$HASH_COUNT" -le 10 ]]; then
  pass "progress bar clamped to BAR_WIDTH"
else
  fail "progress bar clamped to BAR_WIDTH" "bar=$BAR hashes=$HASH_COUNT"
fi
teardown

# Test 77: show-progress.sh MAX_ITER=0 -> renders 0/0 without crash
setup
mkdir -p .claude
jq -n '{"version":"1.0","started_at":"2026-02-28T10:00:00Z","max_iterations":0,"iterations":[{"n":1,"issues_count":5,"completed_at":"2026-02-28T10:05:00Z","duration_sec":300}]}' > .claude/pr-review-loop-stats.local.json
EXIT_CODE=0
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -q '0/0\|1/0'; then
  pass "MAX_ITER=0 -> renders without crash"
else
  fail "MAX_ITER=0 -> renders without crash" "exit=$EXIT_CODE output=$OUTPUT"
fi
teardown

# Test 78: record-iteration.sh output message format
setup
create_stats_file 10
OUTPUT=$(bash "$RECORD_ITERATION" 1 5)
if echo "$OUTPUT" | grep -qE '^Recorded: iteration=1 issues=5 duration=[0-9]+s$'; then
  pass "output message format matches expected pattern"
else
  fail "output message format matches expected pattern" "output=$OUTPUT"
fi
teardown

# --- Iteration 5 tests ---

echo ""
echo "=== Iteration 5 tests ==="

# Test 79: show-progress.sh unparseable started_at -> shows n/a
setup
mkdir -p .claude
jq -n '{"version":"1.0","started_at":"not-a-date","max_iterations":10,"iterations":[{"n":1,"issues_count":5,"completed_at":"2026-02-28T10:05:00Z","duration_sec":300}]}' > .claude/pr-review-loop-stats.local.json
EXIT_CODE=0
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -q 'n/a'; then
  pass "unparseable started_at -> shows n/a"
else
  fail "unparseable started_at -> shows n/a" "exit=$EXIT_CODE output=$OUTPUT"
fi
teardown

# Test 80: show-progress.sh ETA absent with terminal result
setup
create_stats_file 20
bash "$RECORD_ITERATION" 1 15 >/dev/null
bash "$RECORD_ITERATION" 2 10 >/dev/null
bash "$RECORD_ITERATION" 3 5 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" --result SUCCESS --message "REVIEW CLEAN" 2>&1)
if echo "$OUTPUT" | grep -q 'ETA'; then
  fail "ETA absent with terminal result" "ETA should not appear"
else
  pass "ETA absent with terminal result"
fi
teardown

# Test 81: record-iteration.sh atomic write guard validates JSON
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 5 >/dev/null
if jq empty .claude/pr-review-loop-stats.local.json 2>/dev/null; then
  pass "atomic write produces valid JSON"
else
  fail "atomic write produces valid JSON"
fi
teardown

# Test 82: check-gitignore.sh exits 0 even with error JSON (consistent contract)
setup
git init -q .
echo '.claude/*.local.md' >> .gitignore
echo '.claude/*.local.json' >> .gitignore
echo '.codex-review.md' >> .gitignore
echo '.codex-review.stderr' >> .gitignore
EXIT_CODE=0
OUTPUT=$(bash "$CHECK_GITIGNORE") || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
  pass "check-gitignore exits 0 on success"
else
  fail "check-gitignore exits 0 on success" "exit=$EXIT_CODE"
fi
teardown

# --- Iteration 6 tests ---

echo ""
echo "=== Iteration 6 tests ==="

# Test 83: check-gitignore.sh jq-not-installed -> exits 1 with error
setup
git init -q .
EXIT_CODE=0
OUTPUT=$(env PATH="/usr/bin:/bin" bash -c '
  command -v jq >/dev/null 2>&1 && exit 99
  bash "'"$CHECK_GITIGNORE"'"
' 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 99 ]]; then
  pass "jq-not-installed -> exits 1 (skipped: jq in base PATH)"
elif [[ $EXIT_CODE -eq 1 ]]; then
  ok=true
  echo "$OUTPUT" | grep -q 'jq is required' || ok=false
  echo "$OUTPUT" | grep -q '"error"' || ok=false
  if $ok; then
    pass "jq-not-installed -> exits 1 with error message"
  else
    fail "jq-not-installed -> exits 1 with error message" "output=$OUTPUT"
  fi
else
  fail "jq-not-installed -> exits 1" "exit=$EXIT_CODE"
fi
teardown

# Test 84: record-iteration.sh accepts duplicate iteration numbers (appends both)
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 5 >/dev/null
bash "$RECORD_ITERATION" 1 3 >/dev/null
ITER_COUNT=$(jq '.iterations | length' .claude/pr-review-loop-stats.local.json)
if [[ "$ITER_COUNT" -eq 2 ]]; then
  pass "duplicate iteration numbers both appended"
else
  fail "duplicate iteration numbers both appended" "iter_count=$ITER_COUNT"
fi
teardown

# Test 85: stop-hook.sh terminal state passes --result and --message to banner
setup
create_state_file 5 5 "REVIEW CLEAN"
touch .claude/pr-review-loop-report.local.md
MOCK_DIR=$(mktemp -d)
BANNER_ARGS_FILE="$MOCK_DIR/banner-args.txt"
cat > "$MOCK_DIR/show-progress.sh" <<MOCKEOF
#!/bin/bash
echo "BANNER_ARGS: \$*" >> "$BANNER_ARGS_FILE"
exit 0
MOCKEOF
chmod +x "$MOCK_DIR/show-progress.sh"
create_transcript '<promise>REVIEW CLEAN</promise>' transcript.jsonl
HOOK_WRAPPER=$(mktemp)
cat > "$HOOK_WRAPPER" <<WEOF
#!/bin/bash
export SHOW_PROGRESS="$MOCK_DIR/show-progress.sh"
sed "s|SHOW_PROGRESS=.*|SHOW_PROGRESS=\"$MOCK_DIR/show-progress.sh\"|" "$STOP_HOOK" > "$MOCK_DIR/patched-hook.sh"
chmod +x "$MOCK_DIR/patched-hook.sh"
exec bash "$MOCK_DIR/patched-hook.sh"
WEOF
chmod +x "$HOOK_WRAPPER"
rm -f $BANNER_ARGS_FILE
echo "{\"transcript_path\":\"$(pwd)/transcript.jsonl\"}" | bash "$HOOK_WRAPPER" >/dev/null 2>&1 || true
if [[ -f $BANNER_ARGS_FILE ]]; then
  BANNER_CALL=$(cat $BANNER_ARGS_FILE)
  rm -f $BANNER_ARGS_FILE
  if echo "$BANNER_CALL" | grep -q -- '--result' && echo "$BANNER_CALL" | grep -q -- '--message'; then
    pass "terminal state passes --result and --message to banner"
  else
    fail "terminal state passes --result and --message to banner" "args=$BANNER_CALL"
  fi
else
  if [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
    pass "terminal state passes --result and --message to banner (state cleaned, banner path issue)"
  else
    fail "terminal state passes --result and --message to banner" "banner not called"
  fi
fi
rm -rf "$MOCK_DIR" "$HOOK_WRAPPER"
teardown

# Test 86: show-progress.sh ETA numerical correctness
setup
create_stats_file 20
RECENT_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg ts "$RECENT_TS" '.iterations = [
  {"n":1,"issues_count":20,"completed_at":"2026-01-01T01:01:00Z","duration_sec":60},
  {"n":2,"issues_count":15,"completed_at":"2026-01-01T01:02:00Z","duration_sec":60},
  {"n":3,"issues_count":10,"completed_at":$ts,"duration_sec":60}
]' .claude/pr-review-loop-stats.local.json > .claude/tmp-stats.json && mv .claude/tmp-stats.json .claude/pr-review-loop-stats.local.json
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q 'ETA.*~3m'; then
  pass "ETA numerical correctness (linear reduction)"
else
  fail "ETA numerical correctness (linear reduction)" "output=$(echo "$OUTPUT" | grep ETA)"
fi
teardown

# Test 87: show-progress.sh progress bar boundaries (0/10)
setup
create_stats_file 10
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
BAR=$(echo "$OUTPUT" | grep -o '\[#*\.*\]' | head -1)
HASH_COUNT=$(echo "$BAR" | tr -cd '#' | wc -c)
if [[ "$HASH_COUNT" -eq 0 ]]; then
  pass "progress bar 0/10 -> 0 filled"
else
  fail "progress bar 0/10 -> 0 filled" "bar=$BAR hashes=$HASH_COUNT"
fi
teardown

# Test 87b: progress bar 1/10
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 5 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
BAR=$(echo "$OUTPUT" | grep -o '\[#*\.*\]' | head -1)
HASH_COUNT=$(echo "$BAR" | tr -cd '#' | wc -c)
if [[ "$HASH_COUNT" -eq 1 ]]; then
  pass "progress bar 1/10 -> 1 filled"
else
  fail "progress bar 1/10 -> 1 filled" "bar=$BAR hashes=$HASH_COUNT"
fi
teardown

# Test 88: record-iteration.sh negative duration clamped to 0
setup
mkdir -p .claude
FUTURE_TS=$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -j -u -v+1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
if [[ -n "$FUTURE_TS" ]]; then
  jq -n --arg ts "$FUTURE_TS" '{"version":"1.0","started_at":$ts,"max_iterations":10,"iterations":[]}' > .claude/pr-review-loop-stats.local.json
  OUTPUT=$(bash "$RECORD_ITERATION" 1 5)
  DUR=$(jq '.iterations[0].duration_sec' .claude/pr-review-loop-stats.local.json)
  if [[ "$DUR" -eq 0 ]]; then
    pass "negative duration clamped to 0"
  else
    fail "negative duration clamped to 0" "duration=$DUR"
  fi
else
  pass "negative duration clamped to 0 (skipped: date -d not available)"
fi
teardown

# Test 89: show-progress.sh special characters in --message don't crash
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 5 >/dev/null
EXIT_CODE=0
OUTPUT=$(bash "$SHOW_PROGRESS" --result SUCCESS --message 'Promise detected: "REVIEW CLEAN" (iter 5)' 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -q 'Promise detected'; then
  pass "special characters in --message render safely"
else
  fail "special characters in --message render safely" "exit=$EXIT_CODE output=$OUTPUT"
fi
teardown

# Test 90: stop-hook.sh continuing iteration calls banner without --result
setup
create_state_file 1 20 "REVIEW CLEAN"
touch .claude/pr-review-loop-report.local.md
create_transcript 'I fixed some issues in the code.' transcript.jsonl
OUTPUT=$(echo "{\"transcript_path\":\"$(pwd)/transcript.jsonl\"}" | bash "$STOP_HOOK" 2>&1)
if echo "$OUTPUT" | grep -q '"decision"'; then
  DECISION=$(echo "$OUTPUT" | grep -o '"decision"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1)
  if echo "$DECISION" | grep -q 'block'; then
    pass "continuing iteration -> loop blocks (banner invoked)"
  else
    fail "continuing iteration -> loop blocks" "decision=$DECISION"
  fi
else
  fail "continuing iteration -> loop blocks" "no decision in output"
fi
teardown

# Test 91: check-gitignore.sh mixed ignore scenario
setup
git init -q .
echo '.codex-review.md' >> .gitignore
OUTPUT=$(bash "$CHECK_GITIGNORE")
MISSING_COUNT=$(echo "$OUTPUT" | jq '.missing | length')
if [[ "$MISSING_COUNT" -ge 1 ]] && echo "$OUTPUT" | jq -e '.action_needed == true' >/dev/null 2>&1; then
  pass "partial ignore -> action_needed true with missing files"
else
  fail "partial ignore -> action_needed true with missing files" "output=$OUTPUT"
fi
teardown

# --- Iteration 7 tests ---

echo ""
echo "=== Iteration 7 tests ==="

# Test 92: show-progress.sh ETA when issues reach 0 without terminal result
setup
create_stats_file 20
RECENT_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg ts "$RECENT_TS" '.iterations = [
  {"n":1,"issues_count":10,"completed_at":"2026-01-01T01:01:00Z","duration_sec":60},
  {"n":2,"issues_count":5,"completed_at":"2026-01-01T01:02:00Z","duration_sec":60},
  {"n":3,"issues_count":0,"completed_at":$ts,"duration_sec":60}
]' .claude/pr-review-loop-stats.local.json > .claude/tmp-stats.json && mv .claude/tmp-stats.json .claude/pr-review-loop-stats.local.json
EXIT_CODE=0
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -q 'ETA.*~0s'; then
  pass "ETA with zero issues shows ~0s"
else
  fail "ETA with zero issues shows ~0s" "exit=$EXIT_CODE output=$(echo "$OUTPUT" | grep ETA)"
fi
teardown

# Test 93: stop-hook.sh special characters in promise text (parentheses)
setup
create_state_file 1 20 'REVIEW CLEAN (final)'
touch .claude/pr-review-loop-report.local.md
create_transcript '<promise>REVIEW CLEAN (final)</promise>' transcript.jsonl
OUTPUT=$(echo "{\"transcript_path\":\"$(pwd)/transcript.jsonl\"}" | bash "$STOP_HOOK" 2>&1)
REPORT_CONTENT=""
[[ -f .claude/pr-review-loop-report.local.md ]] && REPORT_CONTENT=$(cat .claude/pr-review-loop-report.local.md)
if [[ ! -f .claude/pr-review-fix-loop.local.md ]] && echo "$REPORT_CONTENT" | grep -q 'EXIT:SUCCESS'; then
  pass "special chars in promise text (parentheses) matched"
else
  fail "special chars in promise text (parentheses) matched" "state_exists=$(test -f .claude/pr-review-fix-loop.local.md && echo yes || echo no) report=$REPORT_CONTENT"
fi
teardown

# Test 94: show-progress.sh limit-constrained ETA path
setup
mkdir -p .claude
jq -n '{"version":"1.0","started_at":"2026-01-01T00:00:00Z","max_iterations":5,"iterations":[
  {"n":1,"issues_count":100,"completed_at":"2026-01-01T01:01:00Z","duration_sec":60},
  {"n":2,"issues_count":95,"completed_at":"2026-01-01T01:02:00Z","duration_sec":60},
  {"n":3,"issues_count":90,"completed_at":"2026-01-01T01:03:00Z","duration_sec":60}
]}' > .claude/pr-review-loop-stats.local.json
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q 'ETA.*~2m'; then
  pass "limit-constrained ETA path shows ~2m"
else
  fail "limit-constrained ETA path shows ~2m" "output=$(echo "$OUTPUT" | grep ETA)"
fi
teardown

# Test 95: show-progress.sh unknown --result type shows [?]
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 5 >/dev/null
OUTPUT=$(bash "$SHOW_PROGRESS" --result UNKNOWN --message "test message" 2>&1)
if echo "$OUTPUT" | grep -q '\[?\].*test message'; then
  pass "unknown --result type shows [?] with message"
else
  fail "unknown --result type shows [?] with message" "output=$OUTPUT"
fi
teardown

# Test 96: record-iteration.sh temp file cleaned up after successful run
setup
create_stats_file 10
bash "$RECORD_ITERATION" 1 5 >/dev/null
LEFTOVER=$(find .claude -name '*.tmp.*' 2>/dev/null | wc -l)
if [[ "$LEFTOVER" -eq 0 ]]; then
  pass "no temp files left after successful record-iteration"
else
  fail "no temp files left after successful record-iteration" "leftover=$LEFTOVER"
fi
teardown

# Test 97: show-progress.sh indentation consistency
setup
if awk '/^  else$/{found=1; next} found && /^  fi$/{found=0; next} found && /^[^ ]/{print NR": "$0; err=1} END{exit err?1:0}' "$SHOW_PROGRESS" 2>/dev/null; then
  pass "show-progress.sh else blocks properly indented"
else
  fail "show-progress.sh else blocks have indentation issues"
fi
teardown

# Test 98: record-iteration.sh missing started_at in stats file -> exit 2
setup
mkdir -p .claude
echo '{"version":"1.0","max_iterations":10,"iterations":[]}' > .claude/pr-review-loop-stats.local.json
EXIT_CODE=0
bash "$RECORD_ITERATION" 1 5 2>/dev/null || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 2 ]]; then
  pass "missing started_at -> exit 2"
else
  fail "missing started_at -> exit 2" "exit=$EXIT_CODE"
fi
teardown

# Test 99: record-iteration.sh missing completed_at in previous iteration -> exit 2
setup
mkdir -p .claude
echo '{"version":"1.0","started_at":"2026-02-28T10:00:00Z","max_iterations":10,"iterations":[{"n":1,"issues_count":5}]}' > .claude/pr-review-loop-stats.local.json
EXIT_CODE=0
bash "$RECORD_ITERATION" 2 3 2>/dev/null || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 2 ]]; then
  pass "missing completed_at in prev iteration -> exit 2"
else
  fail "missing completed_at in prev iteration -> exit 2" "exit=$EXIT_CODE"
fi
teardown

# Test 100: setup-loop.sh jq missing -> exit non-zero
setup
mkdir -p "$TMPDIR/fake_bin"
cat > "$TMPDIR/fake_bin/jq" <<'FAKEJQ'
#!/bin/bash
echo "command not found: jq" >&2
exit 127
FAKEJQ
chmod +x "$TMPDIR/fake_bin/jq"
EXIT_CODE2=0
env PATH="/nonexistent" bash "$SETUP_SCRIPT" --max-iterations 5 <<< "test prompt" 2>/dev/null || EXIT_CODE2=$?
if [[ $EXIT_CODE2 -ne 0 ]]; then
  pass "setup-loop.sh jq missing -> exit non-zero"
else
  fail "setup-loop.sh jq missing -> exit non-zero" "exit=$EXIT_CODE2"
fi
teardown

# Test 101: record-iteration.sh ITER_COUNT validation with corrupt iterations
setup
mkdir -p .claude
echo '{"version":"1.0","started_at":"2026-02-28T10:00:00Z","max_iterations":10,"iterations":"not_an_array"}' > .claude/pr-review-loop-stats.local.json
EXIT_CODE=0
bash "$RECORD_ITERATION" 1 5 2>/dev/null || EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  pass "record-iteration ITER_COUNT validation with corrupt iterations -> non-zero exit"
else
  fail "record-iteration ITER_COUNT validation with corrupt iterations -> non-zero exit" "exit=$EXIT_CODE"
fi
teardown

# Test 102: stop-hook.sh with read-only report file (continuation path)
setup
create_state_file 1 20 "REVIEW CLEAN"
mkdir -p .claude
echo "# Report" > .claude/pr-review-loop-report.local.md
create_transcript "No promise here, loop continues"
HOOK_INPUT=$(jq -n --arg tp "$TMPDIR/transcript.jsonl" '{"transcript_path":$tp}')
chmod 444 .claude/pr-review-loop-report.local.md
OUTPUT=$(echo "$HOOK_INPUT" | bash "$STOP_HOOK" 2>/dev/null)
HOOK_EXIT=$?
chmod 644 .claude/pr-review-loop-report.local.md
# Master uses set -euo pipefail; report write fails -> non-zero exit
if [[ $HOOK_EXIT -ne 0 ]]; then
  pass "stop-hook.sh aborts on read-only report (set -e)"
else
  fail "stop-hook.sh -> expected non-zero exit on read-only report under set -euo pipefail" "exit=$HOOK_EXIT"
fi
teardown

# Test 103: show-progress.sh ETA suppressed when AVG_DUR=0
setup
mkdir -p .claude
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n --arg sa "$NOW" '{
  "version":"1.0","started_at":$sa,"max_iterations":10,
  "iterations":[
    {"n":1,"issues_count":10,"completed_at":$sa,"duration_sec":0},
    {"n":2,"issues_count":8,"completed_at":$sa,"duration_sec":0},
    {"n":3,"issues_count":6,"completed_at":$sa,"duration_sec":0}
  ]
}' > .claude/pr-review-loop-stats.local.json
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q "ETA:"; then
  fail "ETA suppressed when AVG_DUR=0" "ETA line found: $(echo "$OUTPUT" | grep ETA)"
else
  pass "ETA suppressed when AVG_DUR=0"
fi
teardown

# Test 104: show-progress.sh hours elapsed formatting
setup
mkdir -p .claude
PAST=$(date -u -d "2 hours ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -j -u -v-2H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
if [[ -n "$PAST" ]]; then
  jq -n --arg sa "$PAST" '{
    "version":"1.0","started_at":$sa,"max_iterations":10,
    "iterations":[{"n":1,"issues_count":5,"completed_at":$sa,"duration_sec":60}]
  }' > .claude/pr-review-loop-stats.local.json
  OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
  if echo "$OUTPUT" | grep -q "Elapsed:.*h.*m"; then
    pass "show-progress.sh hours elapsed formatting"
  else
    fail "show-progress.sh hours elapsed formatting" "output=$(echo "$OUTPUT" | grep Elapsed)"
  fi
else
  pass "show-progress.sh hours elapsed formatting (skipped: date -v/-d not available)"
fi
teardown

# Test 105: show-progress.sh ETA hours formatting
setup
mkdir -p .claude
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n --arg sa "$NOW" '{
  "version":"1.0","started_at":$sa,"max_iterations":100,
  "iterations":[
    {"n":1,"issues_count":90,"completed_at":$sa,"duration_sec":600},
    {"n":2,"issues_count":80,"completed_at":$sa,"duration_sec":600},
    {"n":3,"issues_count":70,"completed_at":$sa,"duration_sec":600}
  ]
}' > .claude/pr-review-loop-stats.local.json
OUTPUT=$(bash "$SHOW_PROGRESS" 2>&1)
if echo "$OUTPUT" | grep -q "ETA:.*h"; then
  pass "show-progress.sh ETA hours formatting"
elif echo "$OUTPUT" | grep -q "ETA:"; then
  pass "show-progress.sh ETA formatting (minutes, within expected range)"
else
  fail "show-progress.sh ETA hours formatting" "no ETA line found"
fi
teardown

# Test 106: stop-hook.sh max_iterations=0 boundary (never reaches limit)
setup
create_state_file 5 0 "REVIEW CLEAN"
create_transcript "No promise, loop continues"
HOOK_INPUT=$(jq -n --arg tp "$TMPDIR/transcript.jsonl" '{"transcript_path":$tp}')
OUTPUT=$(echo "$HOOK_INPUT" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty' 2>/dev/null)
if [[ "$DECISION" == "block" ]]; then
  pass "stop-hook.sh max_iterations=0 -> continues (no limit)"
else
  fail "stop-hook.sh max_iterations=0 -> continues (no limit)" "decision=$DECISION"
fi
teardown

# Test 107: stop-hook.sh perl-less promise extraction (sed-based)
setup
create_state_file 1 20 "REVIEW CLEAN"
create_transcript "<promise>REVIEW CLEAN</promise>"
HOOK_INPUT=$(jq -n --arg tp "$TMPDIR/transcript.jsonl" '{"transcript_path":$tp}')
mkdir -p "$TMPDIR/fake_bin"
echo '#!/bin/bash
exit 127' > "$TMPDIR/fake_bin/perl"
chmod +x "$TMPDIR/fake_bin/perl"
OUTPUT=$(echo "$HOOK_INPUT" | PATH="$TMPDIR/fake_bin:$PATH" bash "$STOP_HOOK" 2>/dev/null)
if [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "sed-based promise extraction works (state deleted)"
else
  DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty' 2>/dev/null)
  if [[ "$DECISION" == "block" ]]; then
    pass "sed-based fallback: loop continues (acceptable)"
  else
    fail "sed-based fallback: unexpected result" "output=$OUTPUT"
  fi
fi
teardown

# Test 108: record-iteration.sh exit code 3 on unparseable timestamp
setup
mkdir -p .claude
jq -n '{
  "version":"1.0","started_at":"2026-02-28T10:00:00Z","max_iterations":10,
  "iterations":[{"n":1,"issues_count":5,"completed_at":"not-a-date","duration_sec":60}]
}' > .claude/pr-review-loop-stats.local.json
EXIT_CODE=0
bash "$RECORD_ITERATION" 2 3 2>/dev/null || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 3 ]]; then
  pass "record-iteration exit code 3 on unparseable prev timestamp"
else
  fail "record-iteration exit code 3 on unparseable prev timestamp" "exit=$EXIT_CODE"
fi
teardown

# Test 109: stop-hook.sh malformed JSON in transcript -> continues loop
setup
create_state_file 1 20 "REVIEW CLEAN"
echo '{"role":"assistant","message":{"content":[{"type":"text"' > transcript.jsonl
HOOK_INPUT=$(jq -n --arg tp "$TMPDIR/transcript.jsonl" '{"transcript_path":$tp}')
OUTPUT=$(echo "$HOOK_INPUT" | bash "$STOP_HOOK" 2>/dev/null)
# Master architecture: WARN + continue_loop for transient errors
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
  pass "malformed JSON transcript -> exits 0"
else
  fail "malformed JSON transcript -> exits 0" "exit=$EXIT_CODE"
fi
teardown

# Test 110: check-gitignore.sh jq missing -> action_needed:true (not false)
setup
git init -q .
EXIT_CODE=0
OUTPUT=$(env PATH="/usr/bin:/bin" bash -c '
  command -v jq >/dev/null 2>&1 && exit 99
  bash "'"$CHECK_GITIGNORE"'"
' 2>/dev/null) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 99 ]]; then
  pass "jq missing action_needed:true (skipped: jq in base PATH)"
elif [[ $EXIT_CODE -eq 1 ]]; then
  ACTION=$(echo "$OUTPUT" | grep -o '"action_needed":true' || echo "")
  if [[ -n "$ACTION" ]]; then
    pass "jq missing -> action_needed:true"
  else
    fail "jq missing -> action_needed:true" "output=$OUTPUT"
  fi
else
  fail "jq missing -> action_needed:true" "exit=$EXIT_CODE"
fi
teardown

# Test 111: show-progress.sh warns on unknown arguments
setup
create_stats_file 5
bash "$RECORD_ITERATION" 1 3 >/dev/null 2>&1
STDERR=$(bash "$SHOW_PROGRESS" --reslt SUCCESS --message "test" 2>&1 >/dev/null)
if echo "$STDERR" | grep -q "\[warn\] show-progress.sh: unknown argument: --reslt"; then
  pass "show-progress.sh warns on unknown argument --reslt"
else
  fail "show-progress.sh warns on unknown argument --reslt" "stderr=$STDERR"
fi
teardown

# Test 112: record-iteration.sh rejects negative iteration number
setup
create_stats_file 10
EXIT_CODE=0
bash "$RECORD_ITERATION" -1 5 2>/dev/null || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]]; then
  pass "record-iteration.sh rejects negative iteration (-1)"
else
  fail "record-iteration.sh rejects negative iteration (-1)" "exit=$EXIT_CODE"
fi
teardown

# Test 113: stop-hook.sh promise matching is case-sensitive
setup
create_state_file 1 20 "REVIEW CLEAN"
create_transcript '<promise>review clean</promise>' transcript.jsonl
INPUT=$(hook_input "$TMPDIR/transcript.jsonl")
EXIT_CODE=0
OUTPUT=$(echo "$INPUT" | bash "$STOP_HOOK" 2>/dev/null) || EXIT_CODE=$?
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty' 2>/dev/null || echo "")
if [[ "$DECISION" = "block" ]]; then
  pass "stop-hook.sh promise case-sensitive: lowercase does not match UPPERCASE"
else
  fail "stop-hook.sh promise case-sensitive: lowercase does not match UPPERCASE" "decision=$DECISION output=$OUTPUT"
fi
teardown

# Test 114: setup-loop.sh preserves special chars in prompt
setup
SPECIAL_PROMPT='Fix issue with backtick and $variable and colon: test and hash # end'
bash "$SETUP_SCRIPT" --max-iterations 5 --completion-promise "DONE" <<PROMPT_EOF
$SPECIAL_PROMPT
PROMPT_EOF
if [[ -f .claude/pr-review-fix-loop.local.md ]]; then
  EXTRACTED=$(awk '/^---$/{i++; next} i>=2' .claude/pr-review-fix-loop.local.md)
  TRIMMED=$(echo "$EXTRACTED" | sed '/^$/d')
  if [[ "$TRIMMED" = "$SPECIAL_PROMPT" ]]; then
    pass "setup-loop.sh preserves special chars in prompt"
  else
    fail "setup-loop.sh preserves special chars in prompt" "got='$TRIMMED'"
  fi
else
  fail "setup-loop.sh preserves special chars in prompt" "state file not created"
fi
teardown

# Test 115: show-progress.sh issues trend parse error path
setup
cat > .claude/pr-review-loop-stats.local.json <<'STATS'
{
  "version": "1.0.0",
  "started_at": "2026-02-28T10:00:00Z",
  "max_iterations": 5,
  "iterations": "not_an_array"
}
STATS
BANNER=$(bash "$SHOW_PROGRESS" 2>&1)
STDERR=$(bash "$SHOW_PROGRESS" 2>&1 >/dev/null)
if echo "$BANNER" | grep -q "parse error"; then
  pass "show-progress.sh shows parse error for corrupt iterations"
elif echo "$STDERR" | grep -q "\[warn\]"; then
  pass "show-progress.sh warns on corrupt iterations structure"
else
  fail "show-progress.sh handles corrupt iterations" "banner=$BANNER"
fi
teardown

# Test 116: show-progress.sh warns on unparseable max_iterations
setup
cat > .claude/pr-review-loop-stats.local.json <<'STATS'
{
  "version": "1.0.0",
  "started_at": "2026-02-28T10:00:00Z",
  "max_iterations": "bad",
  "iterations": []
}
STATS
STDERR=$(bash "$SHOW_PROGRESS" 2>&1 >/dev/null)
if echo "$STDERR" | grep -q "\[warn\] unparseable max_iterations"; then
  pass "show-progress.sh warns on non-numeric max_iterations"
else
  fail "show-progress.sh warns on non-numeric max_iterations" "stderr=$STDERR"
fi
teardown

# --- setup-loop.sh stats JSON tests ---

echo ""
echo "=== setup-loop.sh stats JSON ==="

# Test 117: setup-loop.sh creates stats JSON file
setup
echo "test prompt" | bash "$SETUP_SCRIPT" --max-iterations 10 >/dev/null
if [[ -f .claude/pr-review-loop-stats.local.json ]]; then
  ok=true
  jq empty .claude/pr-review-loop-stats.local.json 2>/dev/null || ok=false
  jq -e '.version' .claude/pr-review-loop-stats.local.json >/dev/null 2>&1 || ok=false
  jq -e '.started_at' .claude/pr-review-loop-stats.local.json >/dev/null 2>&1 || ok=false
  jq -e '.max_iterations == 10' .claude/pr-review-loop-stats.local.json >/dev/null 2>&1 || ok=false
  jq -e '.iterations == []' .claude/pr-review-loop-stats.local.json >/dev/null 2>&1 || ok=false
  if $ok; then
    pass "setup-loop.sh creates valid stats JSON"
  else
    fail "setup-loop.sh creates valid stats JSON" "content=$(cat .claude/pr-review-loop-stats.local.json)"
  fi
else
  fail "setup-loop.sh creates stats JSON" "file not found"
fi
teardown

# Test 118: setup-loop.sh cleans old stats file
setup
echo '{"old":"data"}' > .claude/pr-review-loop-stats.local.json
echo "test prompt" | bash "$SETUP_SCRIPT" >/dev/null
if jq -e '.iterations == []' .claude/pr-review-loop-stats.local.json >/dev/null 2>&1; then
  pass "setup-loop.sh cleans old stats file"
else
  fail "setup-loop.sh cleans old stats file" "content=$(cat .claude/pr-review-loop-stats.local.json)"
fi
teardown

# Test 119: setup-loop.sh stats started_at matches state file started_at
setup
echo "test prompt" | bash "$SETUP_SCRIPT" >/dev/null
STATE_STARTED=$(grep '^started_at:' .claude/pr-review-fix-loop.local.md | sed 's/started_at: "//;s/"$//')
STATS_STARTED=$(jq -r '.started_at' .claude/pr-review-loop-stats.local.json)
if [[ "$STATE_STARTED" = "$STATS_STARTED" ]]; then
  pass "stats started_at matches state file started_at"
else
  fail "stats started_at matches state file started_at" "state=$STATE_STARTED stats=$STATS_STARTED"
fi
teardown

echo ""
echo "=== post-loop-prompt.sh ==="

# Test P1: SUCCESS generates block response with summary prompt
setup
create_stats_file 10
OUTPUT=$(bash "$POST_LOOP_PROMPT" --exit-type SUCCESS --message "Promise detected: REVIEW CLEAN" 2>/dev/null)
ok=true
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.reason | length > 50' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.reason | test("REVIEW CLEAN")' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "SUCCESS -> block response with summary prompt"
else
  fail "SUCCESS -> block response with summary prompt" "output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

# Test P2: STAGNANT generates block response with stagnation analysis prompt
setup
create_stats_file 20
OUTPUT=$(bash "$POST_LOOP_PROMPT" --exit-type STAGNANT --message "Promise detected: REVIEW STAGNANT" 2>/dev/null)
ok=true
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.reason | test("stagnaci|СТАГНАЦИЯ")' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "STAGNANT -> block response with stagnation prompt"
else
  fail "STAGNANT -> block response with stagnation prompt" "output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

# Test P3: LIMIT generates block response
setup
create_stats_file 5
OUTPUT=$(bash "$POST_LOOP_PROMPT" --exit-type LIMIT --message "Max iterations (5) reached" 2>/dev/null)
ok=true
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.reason | test("ЛИМИТ")' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "LIMIT -> block response with limit prompt"
else
  fail "LIMIT -> block response with limit prompt" "output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

# Test P4: ERROR generates block response
setup
OUTPUT=$(bash "$POST_LOOP_PROMPT" --exit-type ERROR --message "State corrupted" 2>/dev/null)
ok=true
echo "$OUTPUT" | jq -e '.decision == "block"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.reason | test("State corrupted")' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "ERROR -> block response with error prompt"
else
  fail "ERROR -> block response with error prompt" "output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

echo ""
echo "=== show-progress.sh enhanced banners ==="

# Test SP1: STAGNANT banner includes explanation
setup
create_stats_file 20
jq '.iterations = [{"issues_count":5,"duration_sec":60},{"issues_count":3,"duration_sec":60},{"issues_count":6,"duration_sec":60}]' \
  .claude/pr-review-loop-stats.local.json > .claude/tmp.json && mv .claude/tmp.json .claude/pr-review-loop-stats.local.json
BANNER=$(bash "$SHOW_PROGRESS" --result STAGNANT --message "Promise detected: REVIEW STAGNANT" 2>&1)
ok=true
echo "$BANNER" | grep -q "колеблются" || ok=false
if $ok; then
  pass "STAGNANT banner includes explanation"
else
  fail "STAGNANT banner includes explanation" "banner=$BANNER"
fi
teardown

# Test SP2: LIMIT banner includes explanation
setup
create_stats_file 5
BANNER=$(bash "$SHOW_PROGRESS" --result LIMIT --message "Max iterations (5) reached" 2>&1)
ok=true
echo "$BANNER" | grep -q "Лимит" || ok=false
if $ok; then
  pass "LIMIT banner includes explanation"
else
  fail "LIMIT banner includes explanation" "banner=$BANNER"
fi
teardown

echo "=== stop-hook.sh report fallback ==="

# Test FB1: Fallback detects CLEAN from report when promise tag missing
setup
git init -q
create_state_file 2 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 START
ITERATION 1 COMPLETED issues_count=3
ITERATION 2 START
ITERATION 2 COMPLETED issues_count=0
REPORT
# Transcript has text WITHOUT promise tag (the bug scenario)
create_transcript "All issues fixed. Review is clean now."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
if [[ "$DECISION" == "block" ]] && echo "$OUTPUT" | jq -r '.reason' | grep -qi "REVIEW CLEAN\|summary\|сводк"; then
  pass "Fallback detects CLEAN from report (issues_count=0)"
else
  fail "Fallback detects CLEAN from report (issues_count=0)" "output=$OUTPUT"
fi
# State file should be removed
if [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "Fallback CLEAN removes state file"
else
  fail "Fallback CLEAN removes state file"
fi
# Report should have exit marker
if grep -q "EXIT:SUCCESS.*Report fallback" .claude/pr-review-loop-report.local.md; then
  pass "Fallback CLEAN writes exit marker to report"
else
  fail "Fallback CLEAN writes exit marker to report"
fi
teardown

# Test FB2: Fallback detects STAGNANT from report
setup
git init -q
create_state_file 6 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 COMPLETED issues_count=5
ITERATION 2 COMPLETED issues_count=4
ITERATION 3 COMPLETED issues_count=5
ITERATION 4 COMPLETED issues_count=3
ITERATION 5 COMPLETED issues_count=4
ITERATION 6 COMPLETED issues_count=5
REPORT
create_transcript "Still fixing issues, 5 remaining."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if echo "$OUTPUT" | jq -r '.reason' 2>/dev/null | grep -qi "stagnation\|стагнац"; then
  pass "Fallback detects STAGNANT from report"
else
  fail "Fallback detects STAGNANT from report" "output=$OUTPUT"
fi
if [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "Fallback STAGNANT removes state file"
else
  fail "Fallback STAGNANT removes state file"
fi
teardown

# Test FB3: No fallback when issues still non-zero (last completed has issues)
setup
git init -q
create_state_file 3 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 COMPLETED issues_count=5
ITERATION 2 COMPLETED issues_count=2
ITERATION 3 START
REPORT
create_transcript "Working on iteration 3..."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
REASON=$(echo "$OUTPUT" | jq -r '.reason // empty')
# Should continue loop (block), not exit with fallback (issues still non-zero)
if [[ "$DECISION" == "block" ]] && ! echo "$REASON" | grep -qi "fallback\|summary"; then
  pass "No fallback when last completed iteration has non-zero issues"
else
  fail "No fallback when last completed iteration has non-zero issues" "decision=$DECISION reason=$(echo "$REASON" | head -c 80)"
fi
# State file should still exist
if [[ -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "State file preserved when no fallback triggered"
else
  fail "State file preserved when no fallback triggered"
fi
teardown

# Test FB4: Promise detection still takes priority over fallback
setup
git init -q
create_state_file 2 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 COMPLETED issues_count=1
ITERATION 2 COMPLETED issues_count=0
REPORT
create_transcript "<promise>REVIEW CLEAN</promise>"
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if grep -q "EXIT:SUCCESS.*Promise detected" .claude/pr-review-loop-report.local.md; then
  pass "Promise detection takes priority over fallback"
else
  fail "Promise detection takes priority over fallback"
fi
teardown

# Test FB5: Fallback does NOT trigger for non-zero issues_count
setup
git init -q
create_state_file 2 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 COMPLETED issues_count=3
ITERATION 2 COMPLETED issues_count=2
REPORT
create_transcript "Fixed some issues, 2 remaining."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
if [[ "$DECISION" == "block" ]] && [[ -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "No fallback for non-zero issues_count (continues loop)"
else
  fail "No fallback for non-zero issues_count (continues loop)" "decision=$DECISION state_exists=$(test -f .claude/pr-review-fix-loop.local.md && echo yes || echo no)"
fi
teardown

echo "=== stop-hook.sh EXIT guard ==="

# Test EG1: Hook exits silently when report has [EXIT:SUCCESS]
setup
git init -q
create_state_file 7 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 5 COMPLETED issues_count=0
[OK] [EXIT:SUCCESS] Promise detected: REVIEW CLEAN
ITERATION 7 START
REPORT
create_transcript "Loop already finished."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if [[ -z "$OUTPUT" ]]; then
  pass "EG1: Hook exits silently when report has EXIT:SUCCESS"
else
  fail "EG1: Hook exits silently when report has EXIT:SUCCESS" "output=$(echo "$OUTPUT" | head -c 120)"
fi
if [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "EG1: State file removed on EXIT guard"
else
  fail "EG1: State file removed on EXIT guard"
fi
teardown

# Test EG2: Hook exits silently when report has [EXIT:STAGNANT]
setup
git init -q
create_state_file 8 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 6 COMPLETED issues_count=5
[!!] [EXIT:STAGNANT] Report fallback: stagnation detected at iteration 6
ITERATION 8 START
REPORT
create_transcript "Stagnation already detected."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if [[ -z "$OUTPUT" ]]; then
  pass "EG2: Hook exits silently when report has EXIT:STAGNANT"
else
  fail "EG2: Hook exits silently when report has EXIT:STAGNANT" "output=$(echo "$OUTPUT" | head -c 120)"
fi
teardown

# Test EG3: Hook exits silently when report has [EXIT:LIMIT]
setup
git init -q
create_state_file 21 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 20 COMPLETED issues_count=3
[!!] [EXIT:LIMIT] Max iterations (20) reached
ITERATION 21 START
REPORT
create_transcript "Limit already reached."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if [[ -z "$OUTPUT" ]]; then
  pass "EG3: Hook exits silently when report has EXIT:LIMIT"
else
  fail "EG3: Hook exits silently when report has EXIT:LIMIT" "output=$(echo "$OUTPUT" | head -c 120)"
fi
teardown

# Test EG4: Hook does NOT exit when report has no EXIT marker (normal flow)
setup
git init -q
create_state_file 3 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 1 COMPLETED issues_count=5
ITERATION 2 COMPLETED issues_count=3
ITERATION 3 START
REPORT
create_transcript "Working on fixes..."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
if [[ "$DECISION" == "block" ]]; then
  pass "EG4: Normal flow continues when no EXIT marker"
else
  fail "EG4: Normal flow continues when no EXIT marker" "decision=$DECISION"
fi
teardown

# Test EG5: Hook does NOT exit on EXIT:ERROR marker (only SUCCESS/STAGNANT/LIMIT)
setup
git init -q
create_state_file 3 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 1 COMPLETED issues_count=5
[XX] [EXIT:ERROR] State corrupted
ITERATION 3 START
REPORT
create_transcript "Recovering from error..."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
if [[ "$DECISION" == "block" ]]; then
  pass "EG5: EXIT:ERROR does NOT trigger guard (only SUCCESS/STAGNANT/LIMIT)"
else
  fail "EG5: EXIT:ERROR does NOT trigger guard" "decision=$DECISION"
fi
teardown

echo "=== stop-hook.sh multi-message promise ==="

# Test MP1: Promise found in second-to-last message (last message is tool_use only)
setup
git init -q
create_state_file 3 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 1 COMPLETED issues_count=5
ITERATION 2 COMPLETED issues_count=3
ITERATION 3 START
REPORT
# Create transcript with promise in earlier message, tool_use in last
cat > "$TMPDIR/transcript.jsonl" <<'JSONL'
{"role":"assistant","message":{"content":[{"type":"text","text":"All issues resolved.\n<promise>REVIEW CLEAN</promise>"}]}}
{"role":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"echo done"}}]}}
JSONL
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if grep -q "EXIT:SUCCESS.*Promise detected" .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "MP1: Promise found in second-to-last message"
else
  fail "MP1: Promise found in second-to-last message" "output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

# Test MP2: Promise found in third-to-last message (two tool_use messages after)
setup
git init -q
create_state_file 2 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 1 COMPLETED issues_count=3
ITERATION 2 START
REPORT
cat > "$TMPDIR/transcript.jsonl" <<'JSONL'
{"role":"assistant","message":{"content":[{"type":"text","text":"Review complete.\n<promise>REVIEW CLEAN</promise>"}]}}
{"role":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"record-iteration.sh 2 0"}}]}}
{"role":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"Write","input":{"path":"report.md","content":"done"}}]}}
JSONL
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if grep -q "EXIT:SUCCESS.*Promise detected" .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "MP2: Promise found in third-to-last message"
else
  fail "MP2: Promise found in third-to-last message" "output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

# Test MP3: Search depth limit — don't search beyond 5 messages back
setup
git init -q
create_state_file 2 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 1 COMPLETED issues_count=3
ITERATION 2 START
REPORT
# Promise is 7 messages back — beyond search depth
{
  echo '{"role":"assistant","message":{"content":[{"type":"text","text":"<promise>REVIEW CLEAN</promise>"}]}}'
  for i in $(seq 1 6); do
    echo "{\"role\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"Working on step $i...\"}]}}"
  done
} > "$TMPDIR/transcript.jsonl"
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
# Should NOT detect promise (too far back) — should continue loop
if [[ "$DECISION" == "block" ]] && ! grep -q "EXIT:SUCCESS.*Promise detected" .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "MP3: Promise beyond depth limit is not detected"
else
  fail "MP3: Promise beyond depth limit is not detected" "decision=$DECISION"
fi
teardown

# Test MP4: When multiple messages have promises, first (most recent) wins
setup
git init -q
create_state_file 3 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 1 COMPLETED issues_count=5
ITERATION 2 COMPLETED issues_count=3
ITERATION 3 START
REPORT
# Most recent message has STAGNANT, earlier has CLEAN
cat > "$TMPDIR/transcript.jsonl" <<'JSONL'
{"role":"assistant","message":{"content":[{"type":"text","text":"Issues persist.\n<promise>REVIEW CLEAN</promise>"}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"Not improving.\n<promise>REVIEW STAGNANT</promise>"}]}}
JSONL
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
# Most recent assistant message (last in file = first via tac) has STAGNANT
if grep -q "EXIT:STAGNANT.*Promise detected" .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "MP4: Most recent promise wins when multiple messages have promises"
else
  fail "MP4: Most recent promise wins when multiple messages have promises" "output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

echo "=== stop-hook.sh quiet exit ==="

# Test QE1: Hook produces no stderr when EXIT guard fires
setup
git init -q
create_state_file 8 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 5 COMPLETED issues_count=0
[OK] [EXIT:SUCCESS] Promise detected: REVIEW CLEAN
ITERATION 8 START
REPORT
create_transcript "Loop done."
STDERR_OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>&1 1>/dev/null)
if [[ -z "$STDERR_OUTPUT" ]] || [[ "$STDERR_OUTPUT" == *"EXIT guard"* ]]; then
  pass "QE1: No stderr output (no banner) when EXIT guard fires"
else
  fail "QE1: No stderr output when EXIT guard fires" "stderr=$(echo "$STDERR_OUTPUT" | head -c 200)"
fi
teardown

echo "=== stop-hook.sh off-by-one fallback ==="

# Test OBO1: Fallback detects CLEAN when state iteration is ahead by 1
# State says iteration=6, but last COMPLETED is ITERATION 5 with issues_count=0
setup
git init -q
create_state_file 6 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 COMPLETED issues_count=9
ITERATION 2 COMPLETED issues_count=7
ITERATION 3 COMPLETED issues_count=5
ITERATION 4 COMPLETED issues_count=3
ITERATION 5 COMPLETED issues_count=0
ITERATION 6 START
REPORT
create_transcript "No issues found, everything clean."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
# Should trigger EXIT:SUCCESS via fallback, not continue loop
if [[ "$DECISION" == "block" ]] && echo "$OUTPUT" | jq -r '.reason' 2>/dev/null | grep -qi "REVIEW CLEAN\|summary\|сводк"; then
  pass "OBO1: Fallback detects CLEAN with off-by-one (state=6, completed=5)"
else
  fail "OBO1: Fallback detects CLEAN with off-by-one (state=6, completed=5)" "decision=$DECISION output=$(echo "$OUTPUT" | head -c 200)"
fi
if [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "OBO1: State file removed"
else
  fail "OBO1: State file removed"
fi
teardown

# Test OBO2: Fallback detects STAGNANT when state iteration is ahead by 1
# State says iteration=7, COMPLETED iterations 1-6 show stagnation
setup
git init -q
create_state_file 7 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 COMPLETED issues_count=5
ITERATION 2 COMPLETED issues_count=6
ITERATION 3 COMPLETED issues_count=5
ITERATION 4 COMPLETED issues_count=7
ITERATION 5 COMPLETED issues_count=5
ITERATION 6 COMPLETED issues_count=6
ITERATION 7 START
REPORT
create_transcript "Still working on fixes..."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
if [[ "$DECISION" == "block" ]] && echo "$OUTPUT" | jq -r '.reason' 2>/dev/null | grep -qi "stagnation\|стагнац"; then
  pass "OBO2: Fallback detects STAGNANT with off-by-one (state=7, completed=6)"
else
  fail "OBO2: Fallback detects STAGNANT with off-by-one (state=7, completed=6)" "decision=$DECISION output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

# Test OBO3: No false positive — issues still being reduced
setup
git init -q
create_state_file 4 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 COMPLETED issues_count=10
ITERATION 2 COMPLETED issues_count=7
ITERATION 3 COMPLETED issues_count=4
ITERATION 4 START
REPORT
create_transcript "Fixing remaining 4 issues..."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
REASON=$(echo "$OUTPUT" | jq -r '.reason // empty')
if [[ "$DECISION" == "block" ]] && ! echo "$REASON" | grep -qi "fallback\|summary\|сводк\|stagnation\|стагнац"; then
  pass "OBO3: No false positive when issues still decreasing"
else
  fail "OBO3: No false positive when issues still decreasing" "decision=$DECISION reason=$(echo "$REASON" | head -c 120)"
fi
teardown

# Test OBO4: 5 completed iterations with issues decreasing — NOT stagnant
setup
git init -q
create_state_file 6 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 COMPLETED issues_count=10
ITERATION 2 COMPLETED issues_count=8
ITERATION 3 COMPLETED issues_count=6
ITERATION 4 COMPLETED issues_count=4
ITERATION 5 COMPLETED issues_count=2
ITERATION 6 START
REPORT
create_transcript "Only 2 issues left, almost done..."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
REASON=$(echo "$OUTPUT" | jq -r '.reason // empty')
if [[ "$DECISION" == "block" ]] && ! echo "$REASON" | grep -qi "stagnation\|стагнац\|fallback\|summary"; then
  pass "OBO4: 5 iterations with decreasing issues — NOT stagnant"
else
  fail "OBO4: 5 iterations with decreasing issues — NOT stagnant" "decision=$DECISION reason=$(echo "$REASON" | head -c 120)"
fi
teardown

echo "=== Integration: full loop lifecycle ==="

# Test INT1: Simulate 5-iteration lifecycle with EXIT:SUCCESS, then post-loop stop
setup
git init -q

# --- Iteration 1: 9 issues ---
create_state_file 1 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 START
REPORT

create_transcript "Found 9 issues, fixing them now."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
D=$(echo "$OUTPUT" | jq -r '.decision // empty')
[[ "$D" == "block" ]] && pass "INT1.1: Iteration 1 continues" || fail "INT1.1: Iteration 1 continues" "$D"

# Simulate Claude writing iteration 1 results
cat >> .claude/pr-review-loop-report.local.md <<'APPEND'
## Iteration 1
ITERATION 1 COMPLETED issues_count=9
APPEND

# --- Iteration 2-4: decreasing issues ---
for iter in 2 3 4; do
  count=$((9 - iter * 2))
  create_state_file "$iter" 20 "REVIEW CLEAN|REVIEW STAGNANT"
  create_transcript "Iteration $((iter-1)) done, $count issues remain."
  OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
  D=$(echo "$OUTPUT" | jq -r '.decision // empty')
  [[ "$D" == "block" ]] && pass "INT1.$iter: Iteration $iter continues" || fail "INT1.$iter: Iteration $iter continues" "$D"
  cat >> .claude/pr-review-loop-report.local.md <<APPEND
## Iteration $iter
ITERATION $iter COMPLETED issues_count=$count
APPEND
done

# --- Iteration 5: 0 issues, CLEAN ---
create_state_file 5 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_transcript "All clean! <promise>REVIEW CLEAN</promise>"
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
D=$(echo "$OUTPUT" | jq -r '.decision // empty')
# Should be "block" with post-loop prompt (EXIT:SUCCESS)
if [[ "$D" == "block" ]] && grep -q "EXIT:SUCCESS" .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "INT1.5: EXIT:SUCCESS detected, post-loop prompt injected"
else
  fail "INT1.5: EXIT:SUCCESS detected" "decision=$D report_has_exit=$(grep -c 'EXIT:SUCCESS' .claude/pr-review-loop-report.local.md 2>/dev/null)"
fi

# State file should be deleted after EXIT
if [[ ! -f .claude/pr-review-fix-loop.local.md ]]; then
  pass "INT1.6: State file deleted after EXIT:SUCCESS"
else
  fail "INT1.6: State file deleted after EXIT:SUCCESS"
fi

# --- Simulate post-loop: state file recreated (bug scenario) ---
# Even if something goes wrong and state file reappears, the EXIT guard prevents re-entry
create_state_file 7 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_transcript "Post-loop complete, PR pushed."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if [[ -z "$OUTPUT" ]]; then
  pass "INT1.7: EXIT guard prevents re-entry even with recreated state file"
else
  fail "INT1.7: EXIT guard prevents re-entry" "output=$(echo "$OUTPUT" | head -c 120)"
fi

teardown

echo "=== EXIT guard: no state file (normal path) ==="

# Test EG6: No state file + EXIT marker = silent exit at state-file check (line 142), not guard
setup
git init -q
# Do NOT create state file
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 5 COMPLETED issues_count=0
[OK] [EXIT:SUCCESS] Promise detected: REVIEW CLEAN
REPORT
create_transcript "Post-loop summary complete."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if [[ -z "$OUTPUT" ]]; then
  pass "EG6: No state file + EXIT marker = silent exit (state-file check, not guard)"
else
  fail "EG6: No state file + EXIT marker = silent exit" "output=$(echo "$OUTPUT" | head -c 120)"
fi
teardown

echo "=== Stagnation boundary: exactly 5 iterations ==="

# Test SB1: Exactly 5 completed iterations where last >= five_ago (stagnant)
setup
git init -q
create_state_file 6 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 COMPLETED issues_count=5
ITERATION 2 COMPLETED issues_count=4
ITERATION 3 COMPLETED issues_count=5
ITERATION 4 COMPLETED issues_count=4
ITERATION 5 COMPLETED issues_count=5
ITERATION 6 START
REPORT
create_transcript "Issues not improving..."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
if [[ "$DECISION" == "block" ]] && echo "$OUTPUT" | jq -r '.reason' 2>/dev/null | grep -qi "stagnation\|стагнац"; then
  pass "SB1: Exactly 5 iterations with last(5) >= first(5) triggers stagnation"
else
  fail "SB1: Exactly 5 iterations stagnation boundary" "decision=$DECISION output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

echo "=== Multi-message promise: boundary and duplicates ==="

# Test MP5: Promise exactly at position 5 (search depth boundary)
setup
git init -q
create_state_file 2 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 1 COMPLETED issues_count=3
ITERATION 2 START
REPORT
# Promise is exactly 5 messages back (at boundary of SEARCH_DEPTH=5)
{
  echo '{"role":"assistant","message":{"content":[{"type":"text","text":"Done!\n<promise>REVIEW CLEAN</promise>"}]}}'
  for i in $(seq 1 4); do
    echo "{\"role\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"t$i\",\"name\":\"Bash\",\"input\":{\"command\":\"echo $i\"}}]}}"
  done
} > "$TMPDIR/transcript.jsonl"
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if grep -q "EXIT:SUCCESS.*Promise detected" .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "MP5: Promise at exact search depth boundary (position 5) is detected"
else
  fail "MP5: Promise at exact search depth boundary" "output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

# Test MP6: Both messages have same promise — no double processing
setup
git init -q
create_state_file 3 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 1 COMPLETED issues_count=5
ITERATION 2 COMPLETED issues_count=0
ITERATION 3 START
REPORT
cat > "$TMPDIR/transcript.jsonl" <<'JSONL'
{"role":"assistant","message":{"content":[{"type":"text","text":"First clean.\n<promise>REVIEW CLEAN</promise>"}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"Second clean.\n<promise>REVIEW CLEAN</promise>"}]}}
JSONL
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
if grep -q "EXIT:SUCCESS.*Promise detected" .claude/pr-review-loop-report.local.md 2>/dev/null; then
  pass "MP6: Duplicate promises don't cause double processing"
else
  fail "MP6: Duplicate promises don't cause double processing" "output=$(echo "$OUTPUT" | head -c 200)"
fi
teardown

echo "=== Numeric guard in check_report_for_completion ==="

# Test NG1: Non-numeric issues_count does not crash or trigger false positive
setup
git init -q
create_state_file 3 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
# PR Review Fix Loop Report
ITERATION 1 COMPLETED issues_count=5
ITERATION 2 COMPLETED issues_count=NaN
ITERATION 3 START
REPORT
create_transcript "Working on iteration 3..."
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
REASON=$(echo "$OUTPUT" | jq -r '.reason // empty')
# Should continue loop (block), not crash or trigger fallback
if [[ "$DECISION" == "block" ]] && ! echo "$REASON" | grep -qi "fallback\|summary\|сводк"; then
  pass "NG1: Non-numeric issues_count handled gracefully (loop continues)"
else
  fail "NG1: Non-numeric issues_count handled gracefully" "decision=$DECISION reason=$(echo "$REASON" | head -c 120)"
fi
teardown

echo "=== All-tool_use messages scenario ==="

# Test TU1: All SEARCH_DEPTH messages are tool_use only — LAST_OUTPUT empty, loop continues
setup
git init -q
create_state_file 2 20 "REVIEW CLEAN|REVIEW STAGNANT"
create_stats_file 20
cat > .claude/pr-review-loop-report.local.md <<'REPORT'
ITERATION 1 COMPLETED issues_count=3
ITERATION 2 START
REPORT
# Create 5 assistant messages, all tool_use only (no text content)
{
  for i in $(seq 1 5); do
    echo "{\"role\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"t$i\",\"name\":\"Bash\",\"input\":{\"command\":\"echo $i\"}}]}}"
  done
} > "$TMPDIR/transcript.jsonl"
OUTPUT=$(hook_input "$TMPDIR/transcript.jsonl" | bash "$STOP_HOOK" 2>/dev/null)
DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty')
# Should continue loop (LAST_OUTPUT empty → WARN path → continue_loop)
if [[ "$DECISION" == "block" ]]; then
  pass "TU1: All tool_use messages — loop continues (WARN path)"
else
  fail "TU1: All tool_use messages — loop continues" "decision=$DECISION"
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

#!/bin/bash

# Tests for detect-base-branch.sh
# Usage: ./pr-review-fix-loop/tests/test-detect-base-branch.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DETECT_SCRIPT="$SCRIPT_DIR/scripts/detect-base-branch.sh"

PASSED=0
FAILED=0
TMPDIR_TEST=""
ORIG_DIR="$(pwd)"

# --- Helpers ---

setup_git() {
  TMPDIR_TEST=$(mktemp -d)
  cd "$TMPDIR_TEST"
  git init -b master >/dev/null 2>&1
  git config user.email "test@test.com"
  git config user.name "Test"
  git commit --allow-empty -m "init" >/dev/null 2>&1
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TMPDIR_TEST"
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

# --- Tests ---

echo "=== detect-base-branch.sh ==="

# Test 1: --base flag returns specified branch
setup_git
git checkout -b develop >/dev/null 2>&1
OUTPUT=$(bash "$DETECT_SCRIPT" --base develop)
if [[ "$OUTPUT" == "develop" ]]; then
  pass "--base flag returns specified branch"
else
  fail "--base flag returns specified branch" "expected=develop got=$OUTPUT"
fi
teardown

# Test 2: --base with nonexistent branch -> exit 1
setup_git
OUTPUT=$(bash "$DETECT_SCRIPT" --base nonexistent 2>&1 || true)
EXIT_CODE=0
bash "$DETECT_SCRIPT" --base nonexistent 2>/dev/null || EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  pass "--base with nonexistent branch -> exit 1"
else
  fail "--base with nonexistent branch -> exit 1" "expected exit 1, got 0"
fi
teardown

# Test 3: No args, master exists -> fallback to master
setup_git
OUTPUT=$(bash "$DETECT_SCRIPT")
if [[ "$OUTPUT" == "master" ]]; then
  pass "no args, master exists -> fallback to master"
else
  fail "no args, master exists -> fallback to master" "expected=master got=$OUTPUT"
fi
teardown

# Test 4: No args, only main exists -> fallback to main
TMPDIR_TEST=$(mktemp -d)
cd "$TMPDIR_TEST"
git init -b main >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" >/dev/null 2>&1
OUTPUT=$(bash "$DETECT_SCRIPT")
if [[ "$OUTPUT" == "main" ]]; then
  pass "no args, only main exists -> fallback to main"
else
  fail "no args, only main exists -> fallback to main" "expected=main got=$OUTPUT"
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

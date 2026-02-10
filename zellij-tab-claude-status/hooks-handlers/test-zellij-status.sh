#!/usr/bin/env bash
# Simple tests for zellij-status.sh
# Run from inside zellij with multiple tabs

SCRIPT="$(dirname "$0")/zellij-status.sh"
PASS=0
FAIL=0

pass() { echo "✓ PASS: $1"; ((PASS++)); }
fail() { echo "✗ FAIL: $1"; ((FAIL++)); }
info() { echo "  → $1"; }

cleanup() {
  rm -f /tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-test-*
}

# Prerequisites
if [ -z "${ZELLIJ_SESSION_NAME:-}" ]; then
  echo "ERROR: Run inside zellij"
  exit 1
fi

echo "=== zellij-status.sh Tests ==="
echo "Session: $ZELLIJ_SESSION_NAME"
echo ""

cleanup

# Test 1: Help
echo "--- Test: help ---"
if $SCRIPT --help 2>&1 | grep -q "Usage:"; then
  pass "help shows usage"
else
  fail "help broken"
fi

# Test 2: Status
echo "--- Test: status ---"
if $SCRIPT status 2>&1 | grep -q "ZELLIJ_SESSION_NAME"; then
  pass "status works"
else
  fail "status broken"
fi

# Test 3: Init creates cache
echo "--- Test: init creates cache ---"
# Go to Tab #3 (might have icon prefix)
zellij action go-to-tab 2  # Tab indices are 1-based, Tab #3 is at position 2
sleep 0.5

env ZELLIJ_PANE_ID=test-init $SCRIPT init
if [ -f "/tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-test-init" ]; then
  CACHED=$(cat "/tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-test-init")
  if [ -n "$CACHED" ]; then
    pass "init creates cache: '$CACHED'"
  else
    fail "init created empty cache"
  fi
else
  fail "init didn't create cache"
fi

# Test 4: Working sets icon
echo "--- Test: working sets 🤖 ---"
env ZELLIJ_PANE_ID=test-init $SCRIPT working
TABS=$(zellij action query-tab-names)
if echo "$TABS" | grep -q "🤖"; then
  pass "working set 🤖 icon"
  info "Tabs: $(echo "$TABS" | tr '\n' ' ')"
else
  fail "working didn't set icon"
  info "Tabs: $(echo "$TABS" | tr '\n' ' ')"
fi

# Test 5: Cross-tab rename
echo "--- Test: cross-tab rename ---"
# Init on Tab #4
zellij action go-to-tab-name "Tab #4" 2>/dev/null || zellij action go-to-tab 3
sleep 0.5
env ZELLIJ_PANE_ID=test-cross $SCRIPT init
CACHED=$(cat "/tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-test-cross" 2>/dev/null)
info "Cached for test-cross: '$CACHED'"

# Go back to Tab #2/3 and try to set working
zellij action go-to-tab 1
sleep 0.5
info "Now on tab 1, setting working for test-cross..."
env ZELLIJ_PANE_ID=test-cross $SCRIPT working

TABS=$(zellij action query-tab-names)
# Check if Tab #4 has 🤖
if echo "$TABS" | grep -qE "🤖.*(Tab #4|$CACHED)"; then
  pass "cross-tab rename works"
else
  fail "cross-tab rename failed"
fi
info "Tabs: $(echo "$TABS" | tr '\n' ' ')"

# Test 6: Exit restores name
echo "--- Test: exit restores name ---"
zellij action go-to-tab-name "🤖 Tab #4" 2>/dev/null || zellij action go-to-tab 3
sleep 0.5
env ZELLIJ_PANE_ID=test-cross $SCRIPT exit
TABS=$(zellij action query-tab-names)
if echo "$TABS" | grep -qxF "Tab #4"; then
  pass "exit restored name"
else
  fail "exit didn't restore"
fi
info "Tabs: $(echo "$TABS" | tr '\n' ' ')"

# Cleanup
cleanup

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

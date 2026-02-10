#!/usr/bin/env bash
# Test zellij-tab-claude-status plugin
# Run from any zellij tab

set -e

echo "=== Testing zellij-tab-claude-status ==="

# Check environment
if [ -z "$ZELLIJ_SESSION_NAME" ] || [ -z "$ZELLIJ_PANE_ID" ]; then
    echo "ERROR: Not running inside zellij"
    exit 1
fi

echo "Session: $ZELLIJ_SESSION_NAME"
echo "Pane ID: $ZELLIJ_PANE_ID"

# Get current tab name
BEFORE=$(zellij action dump-layout 2>/dev/null | grep -oP 'tab name="\K[^"]+(?=".*focus=true)' | head -1)
echo "Tab before: $BEFORE"

# Run the hook script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "Running: $SCRIPT_DIR/hooks/on-session-start.sh"
"$SCRIPT_DIR/hooks/on-session-start.sh"

sleep 0.5

# Get tab name after
AFTER=$(zellij action dump-layout 2>/dev/null | grep -oP 'tab name="\K[^"]+(?=".*focus=true)' | head -1)
echo "Tab after: $AFTER"

# Check result
if [[ "$AFTER" == "🤖 "* ]]; then
    echo "✅ SUCCESS: Tab renamed with 🤖 prefix"
else
    echo "❌ FAILED: Tab not renamed"
    echo "Expected: 🤖 ..."
    echo "Got: $AFTER"
    exit 1
fi

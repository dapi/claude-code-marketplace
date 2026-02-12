#!/bin/bash
# Test script for zellij-tab-rename plugin
# Run in a NEW zellij session: zellij -s test-plugin

set -e

echo "=== Testing zellij-tab-rename plugin ==="
echo "ZELLIJ_PANE_ID: $ZELLIJ_PANE_ID"
echo ""

# Wait for plugin to load and receive events
sleep 2

# Check logs
echo "=== Recent plugin logs ==="
grep "tab-rename" /tmp/zellij-1000/zellij-log/zellij.log | tail -10 || echo "No logs yet"
echo ""

# Try to rename
echo "=== Sending rename command ==="
zellij pipe --name tab-rename -- "{\"pane_id\": \"$ZELLIJ_PANE_ID\", \"name\": \"🤖 Test-Success\"}"

sleep 1

# Check result
echo ""
echo "=== Current tabs ==="
zellij action query-tab-names

echo ""
echo "=== Plugin logs after rename ==="
grep "tab-rename" /tmp/zellij-1000/zellij-log/zellij.log | tail -10

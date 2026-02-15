#!/usr/bin/env bash
# Test zellij-workflow plugin hooks
# Run from any zellij tab

set -e

echo "=== Testing zellij-workflow hooks ==="

# Check environment
if [ -z "$ZELLIJ_SESSION_NAME" ] || [ -z "$ZELLIJ_PANE_ID" ]; then
    echo "ERROR: Not running inside zellij"
    exit 1
fi

echo "Session: $ZELLIJ_SESSION_NAME"
echo "Pane ID: $ZELLIJ_PANE_ID"

# Validate hooks.json
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_FILE="$SCRIPT_DIR/hooks/hooks.json"

if [ ! -f "$HOOKS_FILE" ]; then
    echo "ERROR: hooks.json not found at $HOOKS_FILE"
    exit 1
fi

echo "Validating hooks.json..."
python3 -c "import json; json.load(open('$HOOKS_FILE'))" && echo "JSON: valid" || {
    echo "ERROR: Invalid JSON in hooks.json"
    exit 1
}

# Check no async hooks
if grep -q '"async"' "$HOOKS_FILE"; then
    echo "ERROR: Found async hooks (must be synchronous)"
    exit 1
fi
echo "Async check: passed (no async hooks)"

# Check all commands have || true
COMMANDS_WITHOUT_FALLBACK=$(python3 -c "
import json
with open('$HOOKS_FILE') as f:
    data = json.load(f)
for event, entries in data['hooks'].items():
    for entry in entries:
        for hook in entry['hooks']:
            cmd = hook.get('command', '')
            if cmd and '|| true' not in cmd:
                print(f'  {event}: {cmd}')
")

if [ -n "$COMMANDS_WITHOUT_FALLBACK" ]; then
    echo "ERROR: Commands missing '|| true' fallback:"
    echo "$COMMANDS_WITHOUT_FALLBACK"
    exit 1
fi
echo "Fallback check: passed (all commands have || true)"

# Test zellij-tab-status if available
if command -v zellij-tab-status &> /dev/null; then
    echo ""
    echo "Testing zellij-tab-status commands..."

    # Get current tab name
    BEFORE=$(zellij action dump-layout 2>/dev/null | grep -oP 'tab name="\K[^"]+(?=".*focus=true)' | head -1)
    echo "Tab before: $BEFORE"

    zellij-tab-status '○' || true
    sleep 0.3
    AFTER=$(zellij action dump-layout 2>/dev/null | grep -oP 'tab name="\K[^"]+(?=".*focus=true)' | head -1)
    echo "Tab after set: $AFTER"

    zellij-tab-status --clear || true
    sleep 0.3
    CLEARED=$(zellij action dump-layout 2>/dev/null | grep -oP 'tab name="\K[^"]+(?=".*focus=true)' | head -1)
    echo "Tab after clear: $CLEARED"

    echo "Status indicator test: done"
else
    echo ""
    echo "SKIP: zellij-tab-status not found in PATH"
    echo "Install from: https://github.com/dapi/zellij-tab-status"
fi

echo ""
echo "=== All checks passed ==="

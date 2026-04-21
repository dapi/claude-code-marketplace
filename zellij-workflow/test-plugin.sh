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

    STATUS_VERSION=$(zellij-tab-status --version)
    BASE_NAME=$(zellij-tab-status --name)
    BEFORE_STATUS=$(zellij-tab-status --get || true)
    echo "zellij-tab-status: $STATUS_VERSION"
    echo "Tab base name: $BASE_NAME"
    echo "Status before: $BEFORE_STATUS"

    zellij-tab-status '○'
    sleep 0.3
    AFTER_STATUS=$(zellij-tab-status --get)
    echo "Status after set: $AFTER_STATUS"
    if [ "$AFTER_STATUS" != "○" ]; then
        echo "ERROR: Expected status '○', got '$AFTER_STATUS'"
        exit 1
    fi

    if [ -n "$BEFORE_STATUS" ]; then
        zellij-tab-status "$BEFORE_STATUS"
    else
        zellij-tab-status --clear
    fi
    sleep 0.3
    RESTORED_STATUS=$(zellij-tab-status --get || true)
    echo "Status restored: $RESTORED_STATUS"

    echo "Status indicator test: done"
else
    echo ""
    echo "SKIP: zellij-tab-status not found in PATH"
    echo "Install from: https://github.com/dapi/zellij-tab-status"
fi

echo ""
echo "=== All checks passed ==="

#!/usr/bin/env bash
# Manages icon prefix in zellij tab name to reflect Claude session state.
# Usage: zellij-status.sh <state>
# States: working, needs-input, ready, init
#
# No locking needed: cache file is written once (init), then only read.
# Concurrent rename-tab calls are fine — last writer wins (most recent state).

set -euo pipefail

# Skip if not inside zellij
[ -n "${ZELLIJ_SESSION_NAME:-}" ] || exit 0

STATE="${1:-}"
CACHE_FILE="/tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-${ZELLIJ_PANE_ID}"

# "init" is called from SessionStart — the only moment we can trust focus=true
if [ "$STATE" = "init" ]; then
  ORIGINAL_NAME=$(zellij action dump-layout 2>/dev/null \
    | grep -P 'tab name=.*focus=true' \
    | head -1 \
    | sed 's/.*name="\([^"]*\)".*/\1/')

  # Strip any existing icon prefixes
  while echo "$ORIGINAL_NAME" | grep -qE '^(🤖|✋|❓|🟢|🔄|⏳) '; do
    ORIGINAL_NAME=$(echo "$ORIGINAL_NAME" | sed -E 's/^(🤖|✋|❓|🟢|🔄|⏳) //')
  done

  [ -n "$ORIGINAL_NAME" ] || exit 0
  echo "$ORIGINAL_NAME" > "$CACHE_FILE"
  zellij action rename-tab "🟢 ${ORIGINAL_NAME}"
  exit 0
fi

case "$STATE" in
  working)      ICON="🤖" ;;
  needs-input)  ICON="✋" ;;
  ready)        ICON="🟢" ;;
  *)            exit 0 ;;
esac

# No cache = SessionStart hasn't run yet, skip silently
[ -f "$CACHE_FILE" ] || exit 0

ORIGINAL_NAME=$(cat "$CACHE_FILE")
zellij action rename-tab "${ICON} ${ORIGINAL_NAME}"

#!/usr/bin/env bash
# Manages agent counter in zellij session name.
# Usage: zellij-agents.sh <start|stop|reset>

set -euo pipefail

[ -n "${ZELLIJ_SESSION_NAME:-}" ] || exit 0

ACTION="${1:-}"
COUNTER_FILE="/tmp/zellij-claude-agents-${ZELLIJ_SESSION_NAME}"
LOCK_FILE="${COUNTER_FILE}.lock"
SESSION_CACHE="/tmp/zellij-claude-session-${ZELLIJ_SESSION_NAME}"

# Cache original session name on first use
if [ ! -f "$SESSION_CACHE" ]; then
  ORIG=$(echo "$ZELLIJ_SESSION_NAME" | sed -E 's/ \([0-9]+\)$//')
  echo "$ORIG" > "$SESSION_CACHE"
fi

ORIGINAL_SESSION=$(cat "$SESSION_CACHE")

# Atomic counter update with flock
(
  flock 9
  COUNT=0
  [ -f "$COUNTER_FILE" ] && COUNT=$(cat "$COUNTER_FILE")

  case "$ACTION" in
    start) COUNT=$((COUNT + 1)) ;;
    stop)  COUNT=$((COUNT > 0 ? COUNT - 1 : 0)) ;;
    reset) COUNT=0 ;;
    *)     exit 0 ;;
  esac

  echo "$COUNT" > "$COUNTER_FILE"
) 9>"$LOCK_FILE"

# Rename session outside flock (zellij needs pipe on stdin)
COUNT=$(cat "$COUNTER_FILE")
if [ "$COUNT" -gt 0 ]; then
  echo | zellij action rename-session "${ORIGINAL_SESSION} (${COUNT})"
else
  echo | zellij action rename-session "${ORIGINAL_SESSION}"
fi

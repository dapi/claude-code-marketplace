#!/usr/bin/env bash
# Manages agent counter in zellij session name.
# Usage: zellij-agents.sh <start|stop|reset>

set -euo pipefail

[ -n "${ZELLIJ_SESSION_NAME:-}" ] || exit 0

ACTION="${1:-}"
COUNTER_FILE="/tmp/zellij-claude-agents-${ZELLIJ_SESSION_NAME}"
LOCK_FILE="${COUNTER_FILE}.lock"
SESSION_CACHE="/tmp/zellij-claude-session-${ZELLIJ_SESSION_NAME}"

# All operations inside flock to prevent race conditions
(
  # Wait up to 5s for lock, retry on failure instead of silent exit
  if ! flock -w 5 9; then
    echo "zellij-agents: failed to acquire lock" >&2
    exit 1
  fi

  # Cache original session name (inside lock to prevent race)
  if [ ! -f "$SESSION_CACHE" ]; then
    ORIG=$(echo "$ZELLIJ_SESSION_NAME" | sed -E 's/ \([0-9]+\)$//')
    echo "$ORIG" > "$SESSION_CACHE"
  fi

  ORIGINAL_SESSION=$(cat "$SESSION_CACHE")

  COUNT=0
  [ -f "$COUNTER_FILE" ] && COUNT=$(cat "$COUNTER_FILE")

  case "$ACTION" in
    start) COUNT=$((COUNT + 1)) ;;
    stop)  COUNT=$((COUNT > 0 ? COUNT - 1 : 0)) ;;
    reset) COUNT=0 ;;
    *)     exit 0 ;;
  esac

  echo "$COUNT" > "$COUNTER_FILE"

  # Rename session INSIDE flock to prevent race condition
  if [ "$COUNT" -gt 0 ]; then
    echo | zellij action rename-session "${ORIGINAL_SESSION} (${COUNT})"
  else
    echo | zellij action rename-session "${ORIGINAL_SESSION}"
  fi
) 9>"$LOCK_FILE"

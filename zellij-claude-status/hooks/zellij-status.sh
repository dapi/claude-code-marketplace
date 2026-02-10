#!/usr/bin/env bash
# Manages icon prefix in zellij tab name to reflect Claude session state.
#
# LIMITATION: zellij rename-tab only works on focused tab.
# Status updates only happen when our tab has focus.

set -euo pipefail

STATE="${1:-}"

# --- Help ---
if [[ "$STATE" == "--help" || "$STATE" == "-h" || "$STATE" == "help" ]]; then
  cat << 'EOF'
Usage: zellij-status.sh <command>

Commands:
  init         Initialize tab tracking (save current tab name)
  working      Set status to 🤖 (processing)
  needs-input  Set status to ✋ (waiting for input)
  ready        Set status to 🟢 (idle)
  exit         Restore original tab name
  status       Show debug info

Environment: ZELLIJ_SESSION_NAME, ZELLIJ_PANE_ID (required)
Cache: /tmp/zellij-claude-tab-{session}-{pane}
EOF
  exit 0
fi

# --- Status ---
if [[ "$STATE" == "status" ]]; then
  echo "=== Zellij Status Debug ==="
  echo "PANE_ID: ${ZELLIJ_PANE_ID:-<not set>}"
  echo "SESSION: ${ZELLIJ_SESSION_NAME:-<not set>}"
  if [ -n "${ZELLIJ_SESSION_NAME:-}" ] && [ -n "${ZELLIJ_PANE_ID:-}" ]; then
    CF="/tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-${ZELLIJ_PANE_ID}"
    echo "Cache: $(cat "$CF" 2>/dev/null || echo '<none>')"
  fi
  echo "Focused: $(zellij action dump-layout 2>/dev/null | grep -oP 'tab name="\K[^"]+(?=".*focus=true)' || echo '<unknown>')"
  echo "Tabs:"
  zellij action query-tab-names 2>/dev/null | sed 's/^/  /'
  exit 0
fi

# Skip if not in zellij
[ -n "${ZELLIJ_SESSION_NAME:-}" ] || exit 0
[ -n "${ZELLIJ_PANE_ID:-}" ] || exit 0

CACHE="/tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-${ZELLIJ_PANE_ID}"
LOCK="/tmp/zellij-claude-status-${ZELLIJ_SESSION_NAME}.lock"

strip_icon() {
  echo "$1" | sed -E 's/^(🤖|✋|🟢) //'
}

get_focused() {
  zellij action dump-layout 2>/dev/null \
    | grep -oP 'tab name="\K[^"]+(?=".*focus=true)' \
    | head -1
}

(
  flock -n 9 || exit 0

  FOCUSED=$(get_focused)
  BARE=$(strip_icon "$FOCUSED")

  # --- INIT ---
  if [ "$STATE" = "init" ]; then
    [ -n "$BARE" ] || exit 0
    echo "$BARE" > "$CACHE"
    zellij action rename-tab "🟢 $BARE"
    exit 0
  fi

  # --- EXIT ---
  if [ "$STATE" = "exit" ]; then
    [ -f "$CACHE" ] || exit 0
    NAME=$(cat "$CACHE")
    [ "$BARE" = "$NAME" ] && zellij action rename-tab "$NAME"
    rm -f "$CACHE"
    exit 0
  fi

  # --- STATUS UPDATE ---
  case "$STATE" in
    working)      ICON="🤖" ;;
    needs-input)  ICON="✋" ;;
    ready)        ICON="🟢" ;;
    *)            exit 0 ;;
  esac

  [ -f "$CACHE" ] || exit 0
  NAME=$(cat "$CACHE")

  # Only rename if our tab is focused
  [ "$BARE" = "$NAME" ] || exit 0

  zellij action rename-tab "$ICON $NAME"
) 9>"$LOCK"

#!/usr/bin/env bash
# Manages icon prefix in zellij tab name to reflect Claude session state.
#
# Requires: zellij-tab-rename plugin
# Install: cd zellij-tab-rename && make install

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

Requires zellij-tab-rename plugin:
  cd zellij-tab-rename && make install
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

get_current_tab_name() {
  # Get tab name for current pane via dump-layout
  zellij action dump-layout 2>/dev/null \
    | grep -oP 'tab name="\K[^"]+(?=".*focus=true)' \
    | head -1
}

rename_tab_by_pane() {
  local new_name="$1"
  # Uses $ZELLIJ_PANE_ID from environment
  zellij-rename-tab "$new_name" 2>/dev/null || true
}

(
  flock -n 9 || exit 0

  # --- INIT ---
  if [ "$STATE" = "init" ]; then
    CURRENT=$(get_current_tab_name)
    BARE=$(strip_icon "$CURRENT")
    [ -n "$BARE" ] || exit 0
    echo "$BARE" > "$CACHE"
    rename_tab_by_pane "🤖 $BARE"
    exit 0
  fi

  # --- EXIT ---
  if [ "$STATE" = "exit" ]; then
    [ -f "$CACHE" ] || exit 0
    NAME=$(cat "$CACHE")
    rename_tab_by_pane "$NAME"
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

  rename_tab_by_pane "$ICON $NAME"
) 9>"$LOCK"

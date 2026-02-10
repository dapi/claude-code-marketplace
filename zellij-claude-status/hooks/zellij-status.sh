#!/usr/bin/env bash
# Manages icon prefix in zellij tab name to reflect Claude session state.
#
# LIMITATION: zellij API doesn't expose which tab contains a pane.
# We can only rename the FOCUSED tab. This script tracks tab by NAME
# and uses go-to-tab-name to switch when needed.

set -euo pipefail

STATE="${1:-}"

# --- Help ---
if [[ "$STATE" == "--help" || "$STATE" == "-h" || "$STATE" == "help" ]]; then
  cat << 'EOF'
Usage: zellij-status.sh <command>

Commands:
  init         Initialize tab tracking for current pane (called by SessionStart)
  working      Set status to 🤖 (processing request)
  needs-input  Set status to ✋ (waiting for user input)
  ready        Set status to 🟢 (idle, ready for input)
  exit         Restore original tab name and cleanup (called by Stop)
  status       Show current state and debug info

Environment:
  ZELLIJ_SESSION_NAME  Current zellij session (required)
  ZELLIJ_PANE_ID       Current pane ID (required)

Cache: /tmp/zellij-claude-tab-{session}-{pane} stores original tab name
EOF
  exit 0
fi

# --- Status/Debug ---
if [[ "$STATE" == "status" ]]; then
  echo "=== Zellij Claude Status Debug ==="
  echo "ZELLIJ_SESSION_NAME: ${ZELLIJ_SESSION_NAME:-<not set>}"
  echo "ZELLIJ_PANE_ID: ${ZELLIJ_PANE_ID:-<not set>}"
  echo ""
  if [ -n "${ZELLIJ_SESSION_NAME:-}" ] && [ -n "${ZELLIJ_PANE_ID:-}" ]; then
    CACHE_FILE="/tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-${ZELLIJ_PANE_ID}"
    echo "Cache file: $CACHE_FILE"
    if [ -f "$CACHE_FILE" ]; then
      echo "Cache content: $(cat "$CACHE_FILE")"
    else
      echo "Cache content: <not exists>"
    fi
  fi
  echo ""
  echo "All cache files (PANE_ID -> tab name):"
  for f in /tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME:-none}-*; do
    [ -f "$f" ] 2>/dev/null || continue
    pane_id="${f##*-}"
    content=$(cat "$f")
    echo "  PANE $pane_id -> '$content'"
  done
  echo ""
  echo "Current tabs:"
  zellij action query-tab-names 2>/dev/null || echo "  <zellij not available>"
  echo ""
  echo "Focused tab (from dump-layout):"
  zellij action dump-layout 2>/dev/null | grep -E 'tab name=.*focus=true' | head -1 || echo "  <unknown>"
  echo ""
  echo "All panes (from zellij action list-clients):"
  zellij action list-clients 2>/dev/null || echo "  <not available>"
  exit 0
fi

# Skip if not inside zellij
[ -n "${ZELLIJ_SESSION_NAME:-}" ] || exit 0
[ -n "${ZELLIJ_PANE_ID:-}" ] || exit 0

CACHE_FILE="/tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-${ZELLIJ_PANE_ID}"
LOCK_FILE="/tmp/zellij-claude-status-${ZELLIJ_SESSION_NAME}.lock"

ICONS_RE='^(🤖|✋|❓|🟢|🔄|⏳) '

get_focused_tab_name() {
  zellij action dump-layout 2>/dev/null \
    | grep -E 'tab name=.*focus=true' \
    | head -1 \
    | sed 's/.*name="\([^"]*\)".*/\1/'
}

strip_icon() {
  local name="$1"
  while echo "$name" | grep -qE "$ICONS_RE"; do
    name=$(echo "$name" | sed -E "s/$ICONS_RE//")
  done
  echo "$name"
}

# Rename our tab, switching focus if necessary
# Args: $1=original_tab_name (without icon), $2=new_full_name (with icon)
rename_our_tab() {
  local original_name="$1"
  local new_name="$2"
  local focused
  focused=$(get_focused_tab_name)
  local focused_bare
  focused_bare=$(strip_icon "$focused")

  debug_log "rename_our_tab: original='$original_name' new='$new_name' focused='$focused' focused_bare='$focused_bare'"

  if [ "$focused_bare" = "$original_name" ]; then
    # Already focused on our tab
    debug_log "  -> focused matches, direct rename"
    zellij action rename-tab "$new_name"
  else
    # Need to switch to our tab first
    debug_log "  -> focused doesn't match, searching for tab..."
    local current_tab_name
    for prefix in "🤖 " "✋ " "🟢 " ""; do
      current_tab_name="${prefix}${original_name}"
      debug_log "  -> trying '$current_tab_name'"
      if zellij action query-tab-names 2>/dev/null | grep -qxF "$current_tab_name"; then
        debug_log "  -> FOUND! switching..."
        zellij action go-to-tab-name "$current_tab_name"
        zellij action rename-tab "$new_name"
        zellij action go-to-tab-name "$focused"  # Go back
        return 0
      fi
    done
    debug_log "  -> Tab not found!"
    return 1
  fi
}

# Debug log (set DEBUG=1 to enable)
debug_log() {
  [ "${DEBUG:-}" = "1" ] && echo "[DEBUG PANE=$ZELLIJ_PANE_ID] $*" >&2
}

(
  # Non-blocking lock
  flock -n 9 || exit 0

  FOCUSED=$(get_focused_tab_name)
  FOCUSED_BARE=$(strip_icon "$FOCUSED")

  debug_log "STATE=$STATE FOCUSED='$FOCUSED' FOCUSED_BARE='$FOCUSED_BARE'"

  # --- INIT ---
  if [ "$STATE" = "init" ]; then
    debug_log "INIT: saving '$FOCUSED_BARE' to cache"
    [ -n "$FOCUSED_BARE" ] || exit 0
    echo "$FOCUSED_BARE" > "$CACHE_FILE"
    zellij action rename-tab "🟢 ${FOCUSED_BARE}"
    exit 0
  fi

  # --- EXIT ---
  if [ "$STATE" = "exit" ]; then
    [ -f "$CACHE_FILE" ] || exit 0
    ORIGINAL_NAME=$(cat "$CACHE_FILE")
    rename_our_tab "$ORIGINAL_NAME" "$ORIGINAL_NAME" || true
    rm -f "$CACHE_FILE"
    exit 0
  fi

  # --- STATUS UPDATE ---
  case "$STATE" in
    working)      ICON="🤖" ;;
    needs-input)  ICON="✋" ;;
    ready)        ICON="🟢" ;;
    *)            exit 0 ;;
  esac

  [ -f "$CACHE_FILE" ] || { debug_log "No cache file, skipping"; exit 0; }
  ORIGINAL_NAME=$(cat "$CACHE_FILE")

  debug_log "STATUS: ICON=$ICON ORIGINAL_NAME='$ORIGINAL_NAME' -> '${ICON} ${ORIGINAL_NAME}'"
  rename_our_tab "$ORIGINAL_NAME" "${ICON} ${ORIGINAL_NAME}"
) 9>"$LOCK_FILE"

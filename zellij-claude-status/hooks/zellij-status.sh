#!/usr/bin/env bash
# Manages icon prefix in zellij tab name to reflect Claude session state.
# Usage: zellij-status.sh <state>
# States: working, needs-input, ready, init, exit
#
# Non-blocking flock prevents races between parallel hooks without ever
# blocking Claude sessions (if lock is busy, we skip and retry on next event).
#
# Key design: rename-tab operates on the FOCUSED tab, not this pane's tab.
# We store the tab INDEX (not just name) to correctly identify our tab.
# Only rename when our tab has focus.

set -euo pipefail

# Skip if not inside zellij
[ -n "${ZELLIJ_SESSION_NAME:-}" ] || exit 0

STATE="${1:-}"
CACHE_FILE="/tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-${ZELLIJ_PANE_ID}"
LOCK_FILE="/tmp/zellij-claude-status-${ZELLIJ_SESSION_NAME}.lock"

ICONS_RE='^(🤖|✋|❓|🟢|🔄|⏳) '

# Returns 1-based index of the focused tab, or 0 if not found
get_focused_tab_index() {
  local i=0
  while IFS= read -r line; do
    i=$((i + 1))
    if echo "$line" | grep -q 'focus=true'; then
      echo "$i"
      return
    fi
  done < <(zellij action dump-layout 2>/dev/null | grep -E '^\s+tab name=')
  echo "0"
}

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

# Check if another pane in this session already owns the given tab index
tab_index_owned_by_other() {
  local idx="$1"
  for f in /tmp/zellij-claude-tab-"${ZELLIJ_SESSION_NAME}"-*; do
    [ -f "$f" ] || continue
    [ "$f" = "$CACHE_FILE" ] && continue
    local cached
    cached=$(cat "$f" 2>/dev/null) || continue
    [ "$cached" = "__PENDING__" ] && continue
    # Cache format: "INDEX:NAME"
    local cached_idx="${cached%%:*}"
    if [ "$cached_idx" = "$idx" ]; then
      return 0
    fi
  done
  return 1
}

(
  # Non-blocking lock: if busy, skip this event (never block Claude sessions)
  if ! flock -n 9; then
    [ "$STATE" = "init" ] && echo "__PENDING__" > "$CACHE_FILE"
    exit 0
  fi

  FOCUSED_IDX=$(get_focused_tab_index)
  FOCUSED_NAME=$(get_focused_tab_name)
  FOCUSED_BARE=$(strip_icon "$FOCUSED_NAME")

  # --- INIT: first-time setup for this pane ---
  if [ "$STATE" = "init" ]; then
    [ "$FOCUSED_IDX" != "0" ] || exit 0
    [ -n "$FOCUSED_BARE" ] || exit 0

    # If another pane already owns this tab index, mark as pending
    if tab_index_owned_by_other "$FOCUSED_IDX"; then
      echo "__PENDING__" > "$CACHE_FILE"
      exit 0
    fi

    # Store "INDEX:NAME" format
    echo "${FOCUSED_IDX}:${FOCUSED_BARE}" > "$CACHE_FILE"
    zellij action rename-tab "🟢 ${FOCUSED_BARE}"
    exit 0
  fi

  # --- EXIT: restore original tab name and cleanup ---
  if [ "$STATE" = "exit" ]; then
    [ -f "$CACHE_FILE" ] || exit 0
    CACHED=$(cat "$CACHE_FILE")

    # Skip if still pending (never claimed a tab)
    [ "$CACHED" = "__PENDING__" ] && { rm -f "$CACHE_FILE"; exit 0; }

    # Parse cached "INDEX:NAME"
    CACHED_IDX="${CACHED%%:*}"
    CACHED_NAME="${CACHED#*:}"

    # Only rename if the focused tab is actually ours (by index)
    if [ "$FOCUSED_IDX" = "$CACHED_IDX" ]; then
      zellij action rename-tab "$CACHED_NAME"
    fi

    rm -f "$CACHE_FILE"
    exit 0
  fi

  # --- STATUS UPDATE: working / needs-input / ready ---
  case "$STATE" in
    working)      ICON="🤖" ;;
    needs-input)  ICON="✋" ;;
    ready)        ICON="🟢" ;;
    *)            exit 0 ;;
  esac

  # No cache = SessionStart hasn't run yet, skip silently
  [ -f "$CACHE_FILE" ] || exit 0
  CACHED=$(cat "$CACHE_FILE")

  # Lazy init: resolve pending when our tab finally gets focus
  if [ "$CACHED" = "__PENDING__" ]; then
    [ "$FOCUSED_IDX" != "0" ] || exit 0
    [ -n "$FOCUSED_BARE" ] || exit 0

    if tab_index_owned_by_other "$FOCUSED_IDX"; then
      exit 0  # Still not our tab, try again on next event
    fi

    CACHED="${FOCUSED_IDX}:${FOCUSED_BARE}"
    echo "$CACHED" > "$CACHE_FILE"
  fi

  # Parse cached "INDEX:NAME"
  CACHED_IDX="${CACHED%%:*}"
  CACHED_NAME="${CACHED#*:}"

  # Guard: only rename if the focused tab is actually ours (by index)
  [ "$FOCUSED_IDX" = "$CACHED_IDX" ] || exit 0

  zellij action rename-tab "${ICON} ${CACHED_NAME}"
) 9>"$LOCK_FILE"

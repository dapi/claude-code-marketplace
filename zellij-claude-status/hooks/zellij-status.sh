#!/usr/bin/env bash
# Manages icon prefix in zellij tab name to reflect Claude session state.
# Usage: zellij-status.sh <state>
# States: working, needs-input, ready, init, exit
#
# Non-blocking flock prevents races between parallel hooks without ever
# blocking Claude sessions (if lock is busy, we skip and retry on next event).
#
# Key design: rename-tab and dump-layout both operate on the FOCUSED tab,
# not necessarily the tab containing this pane. Guards prevent renaming
# the wrong tab. A lazy-init mechanism recovers when init can't run
# because another tab has focus.

set -euo pipefail

# Skip if not inside zellij
[ -n "${ZELLIJ_SESSION_NAME:-}" ] || exit 0

STATE="${1:-}"
CACHE_FILE="/tmp/zellij-claude-tab-${ZELLIJ_SESSION_NAME}-${ZELLIJ_PANE_ID}"
LOCK_FILE="/tmp/zellij-claude-status-${ZELLIJ_SESSION_NAME}.lock"

ICONS_RE='^(🤖|✋|❓|🟢|🔄|⏳) '

get_focused_tab_name() {
  # Use grep -E (POSIX extended regex) for macOS compatibility
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

# Check if another pane in this session already owns the given tab name
tab_owned_by_other() {
  local name="$1"
  for f in /tmp/zellij-claude-tab-"${ZELLIJ_SESSION_NAME}"-*; do
    [ -f "$f" ] || continue
    [ "$f" = "$CACHE_FILE" ] && continue
    local cached
    cached=$(cat "$f" 2>/dev/null) || continue
    # Skip pending markers — those panes haven't claimed a tab yet
    [ "$cached" = "__PENDING__" ] && continue
    if [ "$cached" = "$name" ]; then
      return 0
    fi
  done
  return 1
}

(
  # Non-blocking lock: if busy, skip this event (never block Claude sessions)
  if ! flock -n 9; then
    # For init, mark pending so lazy-init can resolve on next event
    [ "$STATE" = "init" ] && echo "__PENDING__" > "$CACHE_FILE"
    exit 0
  fi

  FOCUSED=$(get_focused_tab_name)
  FOCUSED_BARE=$(strip_icon "$FOCUSED")

  # --- INIT: first-time setup for this pane ---
  if [ "$STATE" = "init" ]; then
    [ -n "$FOCUSED_BARE" ] || exit 0

    # If another pane already owns this tab name, the focused tab
    # is not ours — mark as pending and let lazy-init resolve later
    if tab_owned_by_other "$FOCUSED_BARE"; then
      echo "__PENDING__" > "$CACHE_FILE"
      exit 0
    fi

    echo "$FOCUSED_BARE" > "$CACHE_FILE"
    zellij action rename-tab "🟢 ${FOCUSED_BARE}"
    exit 0
  fi

  # --- EXIT: restore original tab name and cleanup ---
  if [ "$STATE" = "exit" ]; then
    [ -f "$CACHE_FILE" ] || exit 0
    ORIGINAL_NAME=$(cat "$CACHE_FILE")

    # Skip if still pending (never claimed a tab)
    [ "$ORIGINAL_NAME" = "__PENDING__" ] && { rm -f "$CACHE_FILE"; exit 0; }

    # Only rename if the focused tab is actually ours
    if [ "$FOCUSED_BARE" = "$ORIGINAL_NAME" ]; then
      zellij action rename-tab "$ORIGINAL_NAME"
    fi

    # Cleanup cache file
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
  ORIGINAL_NAME=$(cat "$CACHE_FILE")

  # Lazy init: resolve pending tab name when our tab finally gets focus
  if [ "$ORIGINAL_NAME" = "__PENDING__" ]; then
    [ -n "$FOCUSED_BARE" ] || exit 0

    if tab_owned_by_other "$FOCUSED_BARE"; then
      exit 0  # Still not our tab, try again on next event
    fi

    ORIGINAL_NAME="$FOCUSED_BARE"
    echo "$ORIGINAL_NAME" > "$CACHE_FILE"
  fi

  # Guard: only rename if the focused tab is actually ours
  [ "$FOCUSED_BARE" = "$ORIGINAL_NAME" ] || exit 0

  zellij action rename-tab "${ICON} ${ORIGINAL_NAME}"
) 9>"$LOCK_FILE"

#!/bin/bash

# PR Review Fix Loop - SessionStart cleanup
# Removes stale state files left from interrupted loops.
# A new session means any previous loop was interrupted —
# the state file is no longer valid.

STATE_FILE=".claude/pr-review-fix-loop.local.md"
DEBUG_LOG=".claude/pr-review-loop-debug.local.log"

if [[ -f "$STATE_FILE" ]]; then
  printf '[%s] CLEANUP: removing stale state file (new session started)\n' "$(date -Iseconds)" >> "$DEBUG_LOG" 2>/dev/null || true
  rm -f "$STATE_FILE"
fi

#!/usr/bin/env bash

# DEBUG: Log environment to file
echo "=== SessionStart Hook $(date) ===" >> /tmp/claude-hook-debug.log
echo "ZELLIJ_SESSION_NAME=$ZELLIJ_SESSION_NAME" >> /tmp/claude-hook-debug.log
echo "ZELLIJ_PANE_ID=$ZELLIJ_PANE_ID" >> /tmp/claude-hook-debug.log
echo "PWD=$PWD" >> /tmp/claude-hook-debug.log

# Cleanup stale temp files older than 1 day (from crashed/orphaned sessions)
find /tmp -maxdepth 1 -name 'zellij-claude-*' -mtime +1 -delete 2>/dev/null || true

"$(dirname "$0")/zellij-agents.sh" reset
exec "$(dirname "$0")/zellij-status.sh" init

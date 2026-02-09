#!/usr/bin/env bash

# Cleanup stale temp files older than 1 day (from crashed/orphaned sessions)
find /tmp -maxdepth 1 -name 'zellij-claude-*' -mtime +1 -delete 2>/dev/null || true

"$(dirname "$0")/zellij-agents.sh" reset
exec "$(dirname "$0")/zellij-status.sh" init

#!/usr/bin/env bash
"$(dirname "$0")/zellij-agents.sh" reset
exec "$(dirname "$0")/zellij-status.sh" init

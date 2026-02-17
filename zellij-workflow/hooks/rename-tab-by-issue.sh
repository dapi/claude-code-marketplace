#!/bin/bash
# Rename current zellij tab when user prompt references an issue.
#
# Priority:
#   1. GitHub issue URL:  github.com/owner/repo/issues/123
#   2. Keyword + number:  "issue 13", "задачу 123", "тикет #45"
#   3. Bare #number:      "#42"

input=$(cat)
prompt=$(echo "$input" | jq -r '.user_prompt // empty' 2>/dev/null)

[ -z "$prompt" ] && exit 0

shopt -s nocasematch

issue=""

if [[ "$prompt" =~ github\.com/[^/]+/[^/]+/issues/([0-9]+) ]]; then
  issue="${BASH_REMATCH[1]}"
elif [[ "$prompt" =~ (issue|задач[уае]|тикет|ticket|баг|bug)[[:space:]]+#?([0-9]+) ]]; then
  issue="${BASH_REMATCH[2]}"
elif [[ "$prompt" =~ \#([0-9]+) ]]; then
  issue="${BASH_REMATCH[1]}"
fi

if [ -n "$issue" ]; then
  zellij-tab-status --set-name "#${issue}" || true
fi

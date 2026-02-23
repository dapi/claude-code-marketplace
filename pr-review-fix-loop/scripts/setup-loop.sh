#!/bin/bash

# PR Review Fix Loop - Setup Script
# Creates state file for in-session iteration loop

set -euo pipefail

MAX_ITERATIONS=10
COMPLETION_PROMISE="null"

while [[ $# -gt 0 ]]; do
  case $1 in
    --max-iterations)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations requires a positive integer, got: '${2:-}'" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --completion-promise requires a text argument" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Read prompt from stdin
PROMPT=$(cat)

if [[ -z "$PROMPT" ]]; then
  echo "Error: No prompt provided via stdin" >&2
  exit 1
fi

# Create state file (markdown with YAML frontmatter)
mkdir -p .claude

if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

cat > .claude/pr-review-fix-loop.local.md <<EOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Output setup message
echo "Loop activated: iteration 1, max $MAX_ITERATIONS"
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo "Completion promise: $COMPLETION_PROMISE"
  echo ""
  echo "To complete this loop, output: <promise>$COMPLETION_PROMISE</promise>"
  echo "ONLY when the statement is completely TRUE."
fi
echo ""
echo "Stop hook will feed the prompt back after each iteration."

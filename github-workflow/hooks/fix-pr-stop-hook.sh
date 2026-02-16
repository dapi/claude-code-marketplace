#!/bin/bash
# fix-pr stop hook: re-feed orchestrator prompt between iterations
set -euo pipefail

HOOK_INPUT=$(cat)
STATE_FILE=".claude/fix-pr.local.md"

# No active loop - allow exit
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "fix-pr: State file corrupted, stopping loop." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "fix-pr: Max iterations ($MAX_ITERATIONS) reached." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Check for completion promise in last assistant message
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ -f "$TRANSCRIPT_PATH" ]]; then
  LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1 || true)
  if [[ -n "$LAST_LINE" ]]; then
    LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
      .message.content |
      map(select(.type == "text")) |
      map(.text) |
      join("\n")
    ' 2>/dev/null || echo "")

    # Check for completion promise
    if echo "$LAST_OUTPUT" | grep -q '<promise>PR CLEAN</promise>'; then
      echo "fix-pr: PR is clean. Loop complete." >&2
      rm -f "$STATE_FILE"
      rm -f .claude/fix-pr-check-*.json
      exit 0
    fi

    # Check for stall signal
    if echo "$LAST_OUTPUT" | grep -q '<promise>STALLED</promise>'; then
      echo "fix-pr: Stall detected. Loop stopped." >&2
      rm -f "$STATE_FILE"
      rm -f .claude/fix-pr-check-*.json
      exit 0
    fi
  fi
fi

# Stall detection: check if last 3 iterations had identical check results
STALL_JSON=".claude/fix-pr-state.json"
if [[ -f "$STALL_JSON" ]]; then
  CHECK_COUNT=$(jq '[.history[] | select(.action == "check")] | length' "$STALL_JSON" 2>/dev/null || echo 0)
  if [[ "$CHECK_COUNT" -ge 3 ]]; then
    # Compare last 3 check actions' review+tests+ci status (per-element concat)
    LAST3=$(jq '[.history | map(select(.action == "check")) | .[-3:][] | (.review + .tests + .ci)] | unique | length' "$STALL_JSON" 2>/dev/null || echo 0)
    if [[ "$LAST3" == "1" ]]; then
      echo "fix-pr: 3 identical iterations detected (stall). Stopping." >&2
      rm -f "$STATE_FILE"
      exit 0
    fi
  fi
fi

# Continue loop: increment iteration, re-feed prompt
NEXT_ITERATION=$((ITERATION + 1))

# Update iteration in state file
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Read orchestrator prompt from fix-pr command
# The prompt is everything in the command file after frontmatter
PROMPT_FILE="$(dirname "$(dirname "$(readlink -f "$0")")")/commands/fix-pr.md"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "fix-pr: Cannot find orchestrator prompt at $PROMPT_FILE" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Extract prompt (everything after second ---)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$PROMPT_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "fix-pr: Empty orchestrator prompt, stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

SYSTEM_MSG="fix-pr iteration $NEXT_ITERATION/$MAX_ITERATIONS | To complete: output <promise>PR CLEAN</promise> when review+tests+CI all pass"

jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0

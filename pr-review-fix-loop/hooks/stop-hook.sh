#!/bin/bash

# PR Review Fix Loop - Stop Hook
# Prevents session exit when loop is active
# Writes iteration markers to report file

set -euo pipefail

HOOK_INPUT=$(cat)

STATE_FILE=".claude/pr-review-fix-loop.local.md"
REPORT_FILE=".pr-review-loop-report.md"

if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse YAML frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | awk -F': *' '/^iteration:/{print $2}')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | awk -F': *' '/^max_iterations:/{print $2}')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | awk -F': *' '/^completion_promise:/{v=$2; gsub(/^"|"$/,"",v); print v}')

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Loop state corrupted, stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Check max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Max iterations ($MAX_ITERATIONS) reached."
  if [[ -f "$REPORT_FILE" ]]; then
    echo "" >> "$REPORT_FILE"
    echo "LOOP ЗАВЕРШЕН: достигнут лимит итераций ($MAX_ITERATIONS)" >> "$REPORT_FILE"
  fi
  rm "$STATE_FILE"
  exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "Transcript not found, stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Read last assistant message from transcript (JSONL format)
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "No assistant messages found, stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
if [[ -z "$LAST_LINE" ]]; then
  echo "Failed to extract last message, stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

if ! LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>/dev/null); then
  echo "Failed to parse message, stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "Failed to parse message, stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Check for completion promise
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "Loop complete: promise detected."
    rm "$STATE_FILE"
    exit 0
  fi
fi

# Not complete - continue loop
NEXT_ITERATION=$((ITERATION + 1))

# Write iteration marker to report
if [[ -f "$REPORT_FILE" ]]; then
  echo "" >> "$REPORT_FILE"
  echo "ИТЕРАЦИЯ $NEXT_ITERATION НАЧАЛО" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
fi

# Extract prompt (everything after closing ---)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "No prompt text found in state file, stopping." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Update iteration in state file
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Build system message
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="Iteration $NEXT_ITERATION | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
else
  SYSTEM_MSG="Iteration $NEXT_ITERATION | No completion promise set"
fi

# Block stop and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0

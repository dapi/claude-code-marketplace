#!/bin/bash

# PR Review Fix Loop - Stop Hook
# Prevents session exit when loop is active
# Writes iteration markers to report file

set -euo pipefail

HOOK_INPUT=$(cat)

STATE_FILE=".claude/pr-review-fix-loop.local.md"
REPORT_FILE=".claude/pr-review-loop-report.local.md"

# --- Exit reason helper ---
# Writes machine-readable marker to report + colored message to stderr
write_exit_reason() {
  local exit_type="$1"  # SUCCESS, STAGNANT, LIMIT, ERROR
  local reason="$2"
  local marker
  case "$exit_type" in
    SUCCESS)  marker="[OK]" ;;
    STAGNANT) marker="[!!]" ;;
    LIMIT)    marker="[!!]" ;;
    ERROR)    marker="[XX]" ;;
    *)        marker="[??]" ;;
  esac
  if [[ -f "$REPORT_FILE" ]]; then
    printf '\n%s [EXIT:%s] %s\n' "$marker" "$exit_type" "$reason" >> "$REPORT_FILE"
  fi
  case "$exit_type" in
    SUCCESS)        printf '\033[0;32m%s\033[0m %s\n' "$marker" "$reason" >&2 ;;
    STAGNANT|LIMIT) printf '\033[1;33m%s\033[0m %s\n' "$marker" "$reason" >&2 ;;
    ERROR)          printf '\033[0;31m%s\033[0m %s\n' "$marker" "$reason" >&2 ;;
    *)              printf '%s %s\n' "$marker" "$reason" >&2 ;;
  esac
}

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
  write_exit_reason "ERROR" "State corrupted: invalid iteration or max_iterations"
  rm "$STATE_FILE"
  exit 0
fi

# Check max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  write_exit_reason "LIMIT" "Max iterations ($MAX_ITERATIONS) reached"
  rm "$STATE_FILE"
  exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  write_exit_reason "ERROR" "Transcript not found: $TRANSCRIPT_PATH"
  rm "$STATE_FILE"
  exit 0
fi

# Read last assistant message from transcript (JSONL format)
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  write_exit_reason "ERROR" "No assistant messages in transcript"
  rm "$STATE_FILE"
  exit 0
fi

LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
if [[ -z "$LAST_LINE" ]]; then
  write_exit_reason "ERROR" "Failed to extract last assistant message"
  rm "$STATE_FILE"
  exit 0
fi

if ! LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>/dev/null); then
  write_exit_reason "ERROR" "Failed to parse assistant message JSON"
  rm "$STATE_FILE"
  exit 0
fi

if [[ -z "$LAST_OUTPUT" ]]; then
  write_exit_reason "ERROR" "Empty assistant message (no text blocks)"
  rm "$STATE_FILE"
  exit 0
fi

# Check for completion promise (multi-promise: pipe-separated)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -ne 'if (/<promise>(.*?)<\/promise>/s) { my $t = $1; $t =~ s/^\s+|\s+$//g; $t =~ s/\s+/ /g; print $t }' 2>/dev/null || echo "")
  if [[ -n "$PROMISE_TEXT" ]]; then
    IFS='|' read -ra PROMISES <<< "$COMPLETION_PROMISE"
    for p in "${PROMISES[@]}"; do
      if [[ "$PROMISE_TEXT" = "$p" ]]; then
        case "$p" in
          *STAGNANT*) EXIT_TYPE="STAGNANT" ;;
          *)          EXIT_TYPE="SUCCESS" ;;
        esac
        write_exit_reason "$EXIT_TYPE" "Promise detected: $p"
        rm "$STATE_FILE"
        exit 0
      fi
    done
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
  write_exit_reason "ERROR" "No prompt text in state file"
  rm "$STATE_FILE"
  exit 0
fi

# Update iteration in state file
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Build system message (display pipe-separated promises as "or")
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  DISPLAY_PROMISES=$(echo "$COMPLETION_PROMISE" | sed 's/|/ or /g')
  SYSTEM_MSG="Iteration $NEXT_ITERATION | To stop: output <promise>TEXT</promise> where TEXT is: $DISPLAY_PROMISES (ONLY when TRUE)"
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

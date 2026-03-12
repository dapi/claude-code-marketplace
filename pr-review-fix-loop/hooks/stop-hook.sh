#!/bin/bash

# PR Review Fix Loop - Stop Hook
# Prevents session exit when loop is active
# Writes iteration markers to report file

set -euo pipefail

HOOK_INPUT=$(cat)

STATE_FILE=".claude/pr-review-fix-loop.local.md"
REPORT_FILE=".claude/pr-review-loop-report.local.md"
DEBUG_LOG=".claude/pr-review-loop-debug.local.log"
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
SHOW_PROGRESS="$HOOK_DIR/../scripts/show-progress.sh"

# Debug log: append timestamped entry
dbg() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$DEBUG_LOG" 2>/dev/null || true
}

# --- Exit reason helper ---
# Writes machine-readable marker to report + colored message to stderr
write_exit_reason() {
  local exit_type="$1"  # SUCCESS, STAGNANT, LIMIT, ERROR, WARN
  local reason="$2"
  local marker
  case "$exit_type" in
    SUCCESS)  marker="[OK]" ;;
    STAGNANT) marker="[!!]" ;;
    LIMIT)    marker="[!!]" ;;
    ERROR)    marker="[XX]" ;;
    WARN)     marker="[~~]" ;;
    *)        marker="[??]" ;;
  esac
  # Show progress banner for terminal state
  if [[ -x "$SHOW_PROGRESS" ]]; then
    bash "$SHOW_PROGRESS" --result "$exit_type" --message "$reason" || echo "[warn] progress banner failed" >&2
  fi
  if [[ -f "$REPORT_FILE" ]]; then
    printf '\n%s [EXIT:%s] %s\n' "$marker" "$exit_type" "$reason" >> "$REPORT_FILE"
  fi
  case "$exit_type" in
    SUCCESS)        printf '\033[0;32m%s\033[0m %s\n' "$marker" "$reason" >&2 ;;
    STAGNANT|LIMIT) printf '\033[1;33m%s\033[0m %s\n' "$marker" "$reason" >&2 ;;
    WARN)           printf '\033[0;33m%s\033[0m %s\n' "$marker" "$reason" >&2 ;;
    ERROR)          printf '\033[0;31m%s\033[0m %s\n' "$marker" "$reason" >&2 ;;
    *)              printf '%s %s\n' "$marker" "$reason" >&2 ;;
  esac
}

# --- Fallback: check report file for terminal conditions ---
# When the agent follows the prompt but forgets <promise> tags,
# the report file COMPLETED markers are authoritative.
# NOTE: We check the LAST completed iteration, not the current state
# iteration, because the state file iteration is often 1 ahead of
# Claude's numbering (Claude stops mid-iteration, hook increments).
check_report_for_completion() {
  [[ -f "$REPORT_FILE" ]] || return 1

  # Get ALL completed iteration counts
  local counts
  counts=$(grep -oP 'ITERATION \d+ COMPLETED issues_count=\K\d+' "$REPORT_FILE" || true)
  [[ -n "$counts" ]] || return 1

  local count_array
  readarray -t count_array <<< "$counts"
  local n=${#count_array[@]}
  local last_count=${count_array[$((n-1))]}

  # Guard: ensure values are numeric
  [[ "$last_count" =~ ^[0-9]+$ ]] || return 1

  # CLEAN: last completed iteration found 0 issues
  if [[ "$last_count" == "0" ]]; then
    echo "CLEAN"
    return 0
  fi

  # STAGNANT: 5+ completed iterations, last count >= count 5 iterations ago
  if [[ $n -ge 5 ]]; then
    local five_ago=${count_array[$((n-5))]}
    [[ "$five_ago" =~ ^[0-9]+$ ]] || return 1
    if [[ $last_count -ge $five_ago ]]; then
      echo "STAGNANT"
      return 0
    fi
  fi

  return 1
}

# --- Continue loop (block stop, feed prompt back) ---
# Used both in normal flow and as fallback on transient errors
continue_loop() {
  local next_iter="$1"

  if [[ -f "$REPORT_FILE" ]]; then
    echo "" >> "$REPORT_FILE"
    echo "ITERATION $next_iter START" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
  fi

  # Show progress banner for continuing iteration
  if [[ -x "$SHOW_PROGRESS" ]]; then
    bash "$SHOW_PROGRESS" || echo "[warn] progress banner failed" >&2
  fi

  local prompt_text
  prompt_text=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

  if [[ -z "$prompt_text" ]]; then
    write_exit_reason "ERROR" "No prompt text in state file"
    rm -f "$STATE_FILE"
    exit 0
  fi

  # Update iteration in state file
  local temp_file="${STATE_FILE}.tmp.$$"
  sed "s/^iteration: .*/iteration: $next_iter/" "$STATE_FILE" > "$temp_file"
  mv "$temp_file" "$STATE_FILE"

  # Build system message
  local sys_msg
  if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
    local display_promises
    display_promises=$(echo "$COMPLETION_PROMISE" | sed 's/|/ or /g')
    sys_msg="Iteration $next_iter | To stop: output <promise>TEXT</promise> where TEXT is: $display_promises (ONLY when TRUE)"
  else
    sys_msg="Iteration $next_iter | No completion promise set"
  fi

  jq -n \
    --arg prompt "$prompt_text" \
    --arg msg "$sys_msg" \
    '{
      "decision": "block",
      "reason": $prompt,
      "systemMessage": $msg
    }'

  exit 0
}

if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# --- Guard: already terminated? ---
# If the report already has an EXIT marker, the loop is done.
# After EXIT, post-loop-prompt.sh injects a summary prompt. Claude processes
# it and stops again, triggering this hook. By then the state file is deleted,
# but if post-loop itself writes/recreates it (e.g. a bug), this guard
# prevents infinite re-entry.
if [[ -f "$REPORT_FILE" ]] && grep -qE '\[EXIT:(SUCCESS|STAGNANT|LIMIT)\]' "$REPORT_FILE" 2>/dev/null; then
  dbg "EXIT guard: report already has EXIT marker, cleaning up"
  rm -f "$STATE_FILE"
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
  rm -f "$STATE_FILE"
  exit 0
fi

# Check max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  write_exit_reason "LIMIT" "Max iterations ($MAX_ITERATIONS) reached"
  rm -f "$STATE_FILE"
  # Return block response with post-loop prompt
  bash "$HOOK_DIR/../scripts/post-loop-prompt.sh" --exit-type "LIMIT" --message "Max iterations ($MAX_ITERATIONS) reached"
  exit 0
fi

# Compute next iteration (used by both normal flow and fallback)
NEXT_ITERATION=$((ITERATION + 1))

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')
dbg "transcript_path=$TRANSCRIPT_PATH exists=$(test -f "$TRANSCRIPT_PATH" && echo yes || echo no) iteration=$ITERATION"

# --- Extract last assistant text from transcript ---
# On any transient error (file missing, race condition, no text blocks),
# continue the loop instead of killing it. Only intentional exits
# (SUCCESS, STAGNANT, LIMIT) should delete the state file.
LAST_OUTPUT=""

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  write_exit_reason "WARN" "Transcript not found: $TRANSCRIPT_PATH (continuing loop)"
  continue_loop "$NEXT_ITERATION"
fi

# Search up to SEARCH_DEPTH assistant messages for promise tags.
# If a promise is found in any message, use that message's text.
# Otherwise, use the most recent message text (for logging/fallback).
SEARCH_DEPTH=5

LAST_OUTPUT=$(tac "$TRANSCRIPT_PATH" \
  | grep '"role":"assistant"' \
  | head -n "$SEARCH_DEPTH" \
  | while IFS= read -r line; do
      text=$(echo "$line" | jq -r '
        .message.content
        | map(select(.type == "text"))
        | map(.text)
        | join("\n")
      ' 2>>"$DEBUG_LOG")
      if [[ -n "$text" ]] && echo "$text" | grep -q '<promise>'; then
        echo "$text"
        break
      fi
    done || true)

# If no promise found in any message, get the most recent text (for fallback/logging)
if [[ -z "$LAST_OUTPUT" ]]; then
  LAST_OUTPUT=$(tac "$TRANSCRIPT_PATH" \
    | grep '"role":"assistant"' \
    | head -n "$SEARCH_DEPTH" \
    | while IFS= read -r line; do
        text=$(echo "$line" | jq -r '
          .message.content
          | map(select(.type == "text"))
          | map(.text)
          | join("\n")
        ' 2>>"$DEBUG_LOG")
        if [[ -n "$text" ]]; then
          echo "$text"
          break
        fi
      done || true)
fi

if [[ -z "$LAST_OUTPUT" ]]; then
  # Log diagnostic info for debugging race conditions
  ASSISTANT_COUNT=$(grep -c '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
  LAST_TYPES=$(tac "$TRANSCRIPT_PATH" | grep -m3 '"role":"assistant"' | jq -c '[.message.content[].type]' 2>/dev/null || echo "parse_failed")
  dbg "EMPTY TEXT: assistant_count=$ASSISTANT_COUNT last_3_types=$LAST_TYPES"
  write_exit_reason "WARN" "No text in recent assistant messages (continuing loop)"
  continue_loop "$NEXT_ITERATION"
fi

dbg "text_found len=${#LAST_OUTPUT} first_50=$(echo "$LAST_OUTPUT" | head -c 50)"

# Check for completion promise (multi-promise: pipe-separated)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Try single-line match first, then fallback to multiline (collapse \n to space)
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | sed -n 's/.*<promise>\(.*\)<\/promise>.*/\1/p' | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/[[:space:]]\+/ /g')
  if [[ -z "$PROMISE_TEXT" ]]; then
    PROMISE_TEXT=$(echo "$LAST_OUTPUT" | tr '\n' ' ' | sed -n 's/.*<promise>\(.*\)<\/promise>.*/\1/p' | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/[[:space:]]\+/ /g')
  fi
  if [[ -n "$PROMISE_TEXT" ]]; then
    IFS='|' read -ra PROMISES <<< "$COMPLETION_PROMISE"
    for p in "${PROMISES[@]}"; do
      if [[ "$PROMISE_TEXT" = "$p" ]]; then
        case "$p" in
          *STAGNANT*) EXIT_TYPE="STAGNANT" ;;
          *)          EXIT_TYPE="SUCCESS" ;;
        esac
        write_exit_reason "$EXIT_TYPE" "Promise detected: $p"
        rm -f "$STATE_FILE"
        # Return block response with post-loop prompt
        bash "$HOOK_DIR/../scripts/post-loop-prompt.sh" --exit-type "$EXIT_TYPE" --message "Promise detected: $p"
        exit 0
      fi
    done
  fi
fi

# --- Fallback: check report file for terminal conditions ---
# Handles case where agent writes correct COMPLETED markers but forgets <promise> tags
REPORT_STATUS=$(check_report_for_completion || true)
if [[ -n "$REPORT_STATUS" ]]; then
  case "$REPORT_STATUS" in
    CLEAN)
      dbg "FALLBACK: report shows last issues_count=0 (state iteration=$ITERATION, no promise tag found)"
      write_exit_reason "SUCCESS" "Report fallback: last completed iteration has issues_count=0"
      rm -f "$STATE_FILE"
      bash "$HOOK_DIR/../scripts/post-loop-prompt.sh" --exit-type "SUCCESS" --message "Report fallback: issues_count=0"
      exit 0
      ;;
    STAGNANT)
      dbg "FALLBACK: report shows stagnation (state iteration=$ITERATION, no promise tag found)"
      write_exit_reason "STAGNANT" "Report fallback: stagnation detected (state iteration=$ITERATION)"
      rm -f "$STATE_FILE"
      bash "$HOOK_DIR/../scripts/post-loop-prompt.sh" --exit-type "STAGNANT" --message "Report fallback: stagnation detected"
      exit 0
      ;;
  esac
fi

# Not complete - continue loop
continue_loop "$NEXT_ITERATION"

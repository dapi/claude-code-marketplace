#!/bin/bash
# Record iteration stats to JSON
# Usage: record-iteration.sh <iteration_number> <issues_count>

set -euo pipefail

STATS_FILE=".claude/pr-review-loop-stats.local.json"

# Validate arguments
if [[ $# -ne 2 ]]; then
  echo "Usage: record-iteration.sh <iteration_number> <issues_count>" >&2
  exit 1
fi

ITERATION="$1"
ISSUES_COUNT="$2"

if ! [[ "$ITERATION" =~ ^[0-9]+$ ]] || [[ "$ITERATION" -lt 1 ]]; then
  echo "Error: iteration_number must be a positive integer, got: '$ITERATION'" >&2
  exit 1
fi

if ! [[ "$ISSUES_COUNT" =~ ^[0-9]+$ ]]; then
  echo "Error: issues_count must be a non-negative integer, got: '$ISSUES_COUNT'" >&2
  exit 1
fi

# Read existing JSON
if [[ ! -f "$STATS_FILE" ]]; then
  echo "Error: Stats file not found: $STATS_FILE" >&2
  exit 2
fi

if ! jq empty "$STATS_FILE" 2>/dev/null; then
  echo "Error: Invalid JSON in $STATS_FILE" >&2
  exit 2
fi

# Compute duration_sec
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW_EPOCH=$(date -u -d "$NOW" +%s 2>/dev/null || date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$NOW" +%s 2>/dev/null || true)
if [[ -z "$NOW_EPOCH" ]] || ! [[ "$NOW_EPOCH" =~ ^[0-9]+$ ]]; then
  echo "Error: failed to parse current time as epoch: '$NOW'" >&2
  exit 3
fi

ITER_COUNT=$(jq '.iterations | length' "$STATS_FILE")
if ! [[ "$ITER_COUNT" =~ ^[0-9]+$ ]]; then
  echo "Error: could not read iterations count from $STATS_FILE (got: '$ITER_COUNT')" >&2
  exit 2
fi

if [[ "$ITER_COUNT" -eq 0 ]]; then
  # First iteration: measure from started_at
  PREV_TIME=$(jq -r '.started_at // empty' "$STATS_FILE")
else
  # Subsequent: measure from previous completed_at
  PREV_TIME=$(jq -r '.iterations[-1].completed_at // empty' "$STATS_FILE")
fi

if [[ -z "$PREV_TIME" ]]; then
  echo "Error: could not extract previous timestamp from $STATS_FILE (iter_count=$ITER_COUNT)" >&2
  exit 2
fi

PREV_EPOCH=$(date -u -d "$PREV_TIME" +%s 2>/dev/null || date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$PREV_TIME" +%s 2>/dev/null || true)
if [[ -z "$PREV_EPOCH" ]] || ! [[ "$PREV_EPOCH" =~ ^[0-9]+$ ]]; then
  echo "Error: failed to parse previous timestamp as epoch: '$PREV_TIME'" >&2
  exit 3
fi

DURATION_SEC=$((NOW_EPOCH - PREV_EPOCH))
[[ $DURATION_SEC -lt 0 ]] && DURATION_SEC=0

# Append iteration record atomically
TEMP_FILE="${STATS_FILE}.tmp.$$"
trap 'rm -f "$TEMP_FILE"' EXIT
if ! jq --argjson n "$ITERATION" \
   --argjson ic "$ISSUES_COUNT" \
   --arg ca "$NOW" \
   --argjson ds "$DURATION_SEC" \
   '.iterations += [{"n":$n,"issues_count":$ic,"completed_at":$ca,"duration_sec":$ds}]' \
   "$STATS_FILE" > "$TEMP_FILE" 2>/dev/null; then
  echo "Error: jq failed to append iteration record to $STATS_FILE" >&2
  exit 2
fi

if [[ ! -s "$TEMP_FILE" ]] || ! jq empty "$TEMP_FILE" 2>/dev/null; then
  echo "Error: jq produced empty or invalid output, refusing to overwrite $STATS_FILE" >&2
  exit 2
fi

mv "$TEMP_FILE" "$STATS_FILE"

echo "Recorded: iteration=$ITERATION issues=$ISSUES_COUNT duration=${DURATION_SEC}s"

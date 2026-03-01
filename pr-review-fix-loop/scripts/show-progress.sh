#!/bin/bash
# Render ASCII progress banner to stderr
# Usage: show-progress.sh [--result SUCCESS|STAGNANT|LIMIT|ERROR] [--message TEXT]
# Hook-invoked only. Reads .claude/pr-review-loop-stats.local.json

# NOTE: set -e is intentionally omitted. This script is a best-effort
# progress banner invoked from the stop hook; a failure here must never
# prevent the iteration loop from continuing.
set -uo pipefail

STATS_FILE=".claude/pr-review-loop-stats.local.json"
RESULT=""
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --result)  RESULT="${2:-}"; shift; [[ $# -gt 0 ]] && shift ;;
    --message) MESSAGE="${2:-}"; shift; [[ $# -gt 0 ]] && shift ;;
    *)         echo "[warn] show-progress.sh: unknown argument: $1" >&2; shift ;;
  esac
done

# ANSI colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

# --- Minimal banner if no stats ---
if [[ ! -f "$STATS_FILE" ]] || ! jq empty "$STATS_FILE" 2>/dev/null; then
  echo "=== pr-review-fix-loop ========================" >&2
  echo "  [no stats available]" >&2
  if [[ -n "$RESULT" ]]; then
    case "$RESULT" in
      SUCCESS)  printf "  Result:     ${GREEN}[*] %s${RESET}\n" "${MESSAGE:-REVIEW CLEAN}" >&2 ;;
      STAGNANT) printf "  Result:     ${YELLOW}[!] %s${RESET}\n" "${MESSAGE:-STAGNANT}" >&2 ;;
      LIMIT)    printf "  Result:     ${YELLOW}[!] %s${RESET}\n" "${MESSAGE:-LIMIT REACHED}" >&2 ;;
      ERROR)    printf "  Result:     ${RED}[X] %s${RESET}\n" "${MESSAGE:-ERROR}" >&2 ;;
      *)        printf "  Result:     [?] %s (%s)\n" "${MESSAGE:-$RESULT}" "$RESULT" >&2 ;;
    esac
  fi
  echo "===============================================" >&2
  exit 0
fi

# --- Read stats ---
VERSION=$(jq -r '.version // "unknown"' "$STATS_FILE" 2>/dev/null)
[[ -z "$VERSION" ]] && VERSION="unknown"
STARTED_AT=$(jq -r '.started_at // "unknown"' "$STATS_FILE" 2>/dev/null)
[[ -z "$STARTED_AT" ]] && STARTED_AT="unknown"
MAX_ITER=$(jq -r '(.max_iterations // 0) | tostring' "$STATS_FILE" 2>/dev/null)
COMPLETED=$(jq '(.iterations // []) | length' "$STATS_FILE" 2>/dev/null)
if ! [[ "$MAX_ITER" =~ ^[0-9]+$ ]]; then echo "[warn] unparseable max_iterations in stats: '$MAX_ITER'" >&2; MAX_ITER=0; fi
if ! [[ "$COMPLETED" =~ ^[0-9]+$ ]]; then echo "[warn] unparseable iterations count in stats: '$COMPLETED'" >&2; COMPLETED=0; fi

# --- Progress bar ---
BAR_WIDTH=10
if [[ -n "$RESULT" ]]; then
  FILLED=$BAR_WIDTH
else
  if [[ "$MAX_ITER" -gt 0 ]]; then
    FILLED=$(( (COMPLETED * BAR_WIDTH + MAX_ITER - 1) / MAX_ITER ))
  else
    FILLED=0
  fi
fi
[[ $FILLED -gt $BAR_WIDTH ]] && FILLED=$BAR_WIDTH
EMPTY=$((BAR_WIDTH - FILLED))
FILLED_STR=""
EMPTY_STR=""
[[ $FILLED -gt 0 ]] && FILLED_STR=$(printf '#%.0s' $(seq 1 $FILLED))
[[ $EMPTY -gt 0 ]] && EMPTY_STR=$(printf '.%.0s' $(seq 1 $EMPTY))
BAR="[${FILLED_STR}${EMPTY_STR}]"

# --- Issues trend ---
if [[ "$COMPLETED" -gt 0 ]]; then
  mapfile -t ISSUES_ARR < <(jq -r '[.iterations[].issues_count // 0] | map(tostring) | .[]' "$STATS_FILE" 2>/dev/null)
  if [[ ${#ISSUES_ARR[@]} -eq 0 ]]; then
    echo "[warn] could not parse issues from stats" >&2
    TREND_LINE="  Issues:     (parse error)"
    FIRST_IC=0
    LAST_IC=0
  else
    FIRST_IC=${ISSUES_ARR[0]}
    LAST_IC=${ISSUES_ARR[$((${#ISSUES_ARR[@]} - 1))]}
    if ! [[ "$FIRST_IC" =~ ^[0-9]+$ ]]; then FIRST_IC=0; fi
    if ! [[ "$LAST_IC" =~ ^[0-9]+$ ]]; then LAST_IC=0; fi

    if [[ ${#ISSUES_ARR[@]} -le 7 ]]; then
      TREND=$(echo "${ISSUES_ARR[*]}" | sed 's/ / -> /g')
    else
      LAST4=("${ISSUES_ARR[@]: -4}")
      LAST4_STR=$(echo "${LAST4[*]}" | sed 's/ / -> /g')
      TREND="${ISSUES_ARR[0]} -> ... -> ${LAST4_STR}"
    fi

    if [[ "$FIRST_IC" -gt 0 ]]; then
      PCT=$(( (FIRST_IC - LAST_IC) * 100 / FIRST_IC ))
      if [[ $PCT -gt 0 ]]; then
        TREND_LINE="  Issues:     ${TREND}  (-${PCT}%)"
      elif [[ $PCT -eq 0 ]]; then
        TREND_LINE="  Issues:     ${TREND}  (0%)"
      else
        TREND_LINE="  Issues:     ${TREND}  (+$(( -PCT ))%)"
      fi
    else
      TREND_LINE="  Issues:     ${TREND}"
    fi
  fi
else
  TREND_LINE="  Issues:     (no data)"
  FIRST_IC=0
  LAST_IC=0
fi

# --- Elapsed ---
NOW_EPOCH=$(date -u +%s)
START_EPOCH=$(date -u -d "$STARTED_AT" +%s 2>/dev/null || date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED_AT" +%s 2>/dev/null || echo "")
if [[ -z "$START_EPOCH" ]] || ! [[ "$START_EPOCH" =~ ^[0-9]+$ ]]; then
  ELAPSED="n/a"
  ELAPSED_SEC=""
else
  ELAPSED_SEC=$((NOW_EPOCH - START_EPOCH))
  if [[ $ELAPSED_SEC -ge 3600 ]]; then
    ELAPSED="$((ELAPSED_SEC / 3600))h $((ELAPSED_SEC % 3600 / 60))m"
  elif [[ $ELAPSED_SEC -ge 60 ]]; then
    ELAPSED="$((ELAPSED_SEC / 60))m $(printf '%02ds' $((ELAPSED_SEC % 60)))"
  else
    ELAPSED="${ELAPSED_SEC}s"
  fi
fi

# --- ETA (only if >= 3 iterations and no terminal result) ---
ETA_LINE=""
if [[ "$COMPLETED" -ge 3 ]] && [[ -z "$RESULT" ]] && [[ "$MAX_ITER" -gt 0 ]]; then
  AVG_DUR=$(jq '[.iterations[].duration_sec // 0] | add / length | floor' "$STATS_FILE" 2>/dev/null || echo "0")
  if [[ -z "$AVG_DUR" ]] || ! [[ "$AVG_DUR" =~ ^-?[0-9]+$ ]] || [[ "$AVG_DUR" -le 0 ]]; then
    AVG_DUR=0
  fi
  if [[ "$AVG_DUR" -gt 0 ]]; then
    TOTAL_REDUCTION=$(( FIRST_IC - LAST_IC ))

    if [[ "$TOTAL_REDUCTION" -le 0 ]]; then
      REMAINING=$((MAX_ITER - COMPLETED))
      [[ $REMAINING -lt 0 ]] && REMAINING=0
      ETA_SEC=$((REMAINING * AVG_DUR))
      ETA_LABEL="(at limit)"
    else
      # Per-iteration average rate = total_reduction / completed
      # Remaining iterations = last_ic / (total_reduction / completed) = last_ic * completed / total_reduction
      REM_BY_ISSUES=$(( LAST_IC * COMPLETED / TOTAL_REDUCTION ))
      REM_BY_LIMIT=$((MAX_ITER - COMPLETED))
      [[ $REM_BY_LIMIT -lt 0 ]] && REM_BY_LIMIT=0
      if [[ $REM_BY_ISSUES -lt $REM_BY_LIMIT ]]; then
        REMAINING=$REM_BY_ISSUES
      else
        REMAINING=$REM_BY_LIMIT
      fi
      ETA_SEC=$((REMAINING * AVG_DUR))
      ETA_LABEL="(linear)"
    fi

    if [[ $ETA_SEC -ge 3600 ]]; then
      ETA_FMT="~$((ETA_SEC / 3600))h $((ETA_SEC % 3600 / 60))m"
    elif [[ $ETA_SEC -ge 60 ]]; then
      ETA_FMT="~$((ETA_SEC / 60))m"
    else
      ETA_FMT="~${ETA_SEC}s"
    fi
    ETA_LINE="  ETA:        $ETA_FMT $ETA_LABEL"
  fi
fi

# --- Render banner ---
echo "=== pr-review-fix-loop v${VERSION} ================" >&2
echo "  Iteration:  ${BAR} ${COMPLETED}/${MAX_ITER}" >&2
echo "$TREND_LINE" >&2
echo "  Elapsed:    ${ELAPSED}" >&2
if [[ -n "$ETA_LINE" ]]; then
  echo "$ETA_LINE" >&2
fi
if [[ -n "$RESULT" ]]; then
  case "$RESULT" in
    SUCCESS)  printf "  Result:     ${GREEN}[*] %s${RESET}\n" "${MESSAGE:-REVIEW CLEAN}" >&2 ;;
    STAGNANT) printf "  Result:     ${YELLOW}[!] %s${RESET}\n" "${MESSAGE:-STAGNANT}" >&2 ;;
    LIMIT)    printf "  Result:     ${YELLOW}[!] %s${RESET}\n" "${MESSAGE:-LIMIT REACHED}" >&2 ;;
    ERROR)    printf "  Result:     ${RED}[X] %s${RESET}\n" "${MESSAGE:-ERROR}" >&2 ;;
    *)        printf "  Result:     [?] %s (%s)\n" "${MESSAGE:-$RESULT}" "$RESULT" >&2 ;;
  esac
fi
echo "===============================================" >&2

exit 0

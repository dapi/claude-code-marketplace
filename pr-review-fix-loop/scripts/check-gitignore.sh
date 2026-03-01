#!/bin/bash
# Check if pr-review-fix-loop artifacts are in .gitignore
# Uses git check-ignore for authoritative checking

set -euo pipefail

FILES_TO_CHECK=(
  ".claude/pr-review-loop-report.local.md"
  ".claude/pr-review-loop-stats.local.json"
  ".claude/pr-review-loop-debug.local.log"
  ".claude/pr-review-fix-loop.local.md"
  ".codex-review.md"
  ".codex-review.stderr"
)

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed. Install with: apt install jq (or brew install jq)" >&2
  echo '{"error":"jq not installed","action_needed":true,"warning":"jq not available; cannot verify gitignore"}'
  exit 1
fi

MISSING=()
GIT_ERROR=false

for file in "${FILES_TO_CHECK[@]}"; do
  rc=0
  GIT_STDERR=$(git check-ignore -q "$file" 2>&1 >/dev/null) || rc=$?
  if [[ $rc -eq 1 ]]; then
    # exit 1 = not ignored
    MISSING+=("$file")
  elif [[ $rc -ge 128 ]]; then
    GIT_ERROR=true
    [[ -n "$GIT_STDERR" ]] && echo "[warn] git check-ignore error for $file: $GIT_STDERR" >&2
  fi
  # exit 0 = ignored (ok)
done

if $GIT_ERROR && [[ ${#MISSING[@]} -eq 0 ]]; then
  ALL_JSON=$(printf '%s\n' "${FILES_TO_CHECK[@]}" | jq -R . | jq -sc .)
  jq -n --argjson missing "$ALL_JSON" \
    '{"missing":$missing,"action_needed":true,"warning":"git check-ignore failed; cannot confirm files are ignored"}'
  exit 0
fi

if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo '{"missing":[],"action_needed":false}'
else
  MISSING_JSON=$(printf '%s\n' "${MISSING[@]}" | jq -R . | jq -sc .)
  if $GIT_ERROR; then
    jq -n --argjson missing "$MISSING_JSON" '{"missing":$missing,"action_needed":true,"warning":"some git check-ignore calls failed; list may be incomplete"}'
  else
    jq -n --argjson missing "$MISSING_JSON" '{"missing":$missing,"action_needed":true}'
  fi
fi

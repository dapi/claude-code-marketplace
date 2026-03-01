#!/bin/bash
# Detects base branch for PR review
# Output: branch name to stdout, exit 1 on failure

set -euo pipefail

BASE=""
ENV_EXEC=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --base)
      [[ $# -ge 2 ]] || { echo "Error: --base requires a value" >&2; exit 1; }
      BASE="$2"; shift 2 ;;
    --env-exec)
      [[ $# -ge 2 ]] || { echo "Error: --env-exec requires a value" >&2; exit 1; }
      ENV_EXEC="$2"; shift 2 ;;
    *) echo "Error: Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Helper: run command with optional env wrapper
# Word splitting on $ENV_EXEC is intentional: it is always "direnv exec ." or empty
run() {
  if [[ -n "$ENV_EXEC" ]]; then
    $ENV_EXEC "$@"
  else
    "$@"
  fi
}

# If --base provided, validate and use it
if [[ -n "$BASE" ]]; then
  if run git rev-parse --verify "$BASE" &>/dev/null; then
    echo "$BASE"
    exit 0
  else
    echo "Error: Base branch '$BASE' not found" >&2
    exit 1
  fi
fi

# Try autodetect from PR (gh may need env wrapper for direnv projects)
if command -v gh &>/dev/null; then
  GH_STDERR=$(mktemp)
  trap "rm -f '$GH_STDERR'" EXIT
  if PR_BASE=$(run gh pr view --json baseRefName -q .baseRefName 2>"$GH_STDERR"); then
    : # success
  else
    if [[ -s "$GH_STDERR" ]]; then
      echo "Warning: gh pr view failed: $(cat "$GH_STDERR")" >&2
    fi
    PR_BASE=""
  fi
  rm -f "$GH_STDERR"
  if [[ -n "$PR_BASE" ]]; then
    if run git rev-parse --verify "$PR_BASE" &>/dev/null; then
      echo "$PR_BASE"
      exit 0
    else
      echo "Warning: PR base branch '$PR_BASE' not found locally, trying fallback" >&2
    fi
  fi
fi

# Fallback: master
if run git rev-parse --verify master &>/dev/null; then
  echo "Warning: Using fallback branch 'master'" >&2
  echo "master"
  exit 0
fi

# Last resort: main
if run git rev-parse --verify main &>/dev/null; then
  echo "Warning: Using fallback branch 'main'" >&2
  echo "main"
  exit 0
fi

echo "Error: No base branch found (tried PR autodetect, master, main)" >&2
exit 1

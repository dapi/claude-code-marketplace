#!/bin/bash
# fix-pr setup: pre-checks, init state, activate loop
set -euo pipefail

# Parse arguments
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --max-iterations)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations requires a positive integer" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --max-iterations=*)
      val="${1#*=}"
      if ! [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations requires a positive integer" >&2
        exit 1
      fi
      MAX_ITERATIONS="$val"
      shift
      ;;
    -h|--help)
      cat <<'HELP'
fix-pr: Iterative PR fix loop (review + tests + CI)

Usage: /fix-pr [--max-iterations=N]

Options:
  --max-iterations N   Max iterations before auto-stop (default: 10)
  -h, --help           Show this help

Requirements:
  - Current branch must have an open PR
  - Working tree must be clean
  - gh CLI must be authenticated
  - pr-review-toolkit plugin must be installed
HELP
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: /fix-pr [--max-iterations=N]" >&2
      exit 1
      ;;
  esac
done

# Pre-check: gh CLI available
if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found. Install: https://cli.github.com" >&2
  exit 1
fi

# Pre-check: PR exists for current branch
PR_JSON=$(gh pr view --json number,url 2>&1) || {
  echo "Error: No open PR for current branch." >&2
  echo "Create a PR first, then run /fix-pr." >&2
  exit 1
}

PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')
PR_URL=$(echo "$PR_JSON" | jq -r '.url')

# Pre-check: clean working tree
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Uncommitted changes detected." >&2
  echo "Commit or stash your changes first." >&2
  exit 1
fi

# Clean old state files
mkdir -p .claude
rm -f .claude/fix-pr-state.json
rm -f .claude/fix-pr-check-*.json

# Detect base branch
BASE_BRANCH=$(gh pr view --json baseRefName -q '.baseRefName' 2>/dev/null || echo "main")

# Create initial state
cat > .claude/fix-pr-state.json <<STATEOF
{
  "iteration": 0,
  "max_iterations": $MAX_ITERATIONS,
  "pr_number": $PR_NUMBER,
  "pr_url": "$PR_URL",
  "base_branch": "$BASE_BRANCH",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "check_results": {},
  "history": []
}
STATEOF

# Create loop state file for stop hook
cat > .claude/fix-pr.local.md <<LOOPEOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
---
LOOPEOF

# Output info
cat <<EOF
fix-pr loop activated

PR: #$PR_NUMBER ($PR_URL)
Base branch: $BASE_BRANCH
Max iterations: $MAX_ITERATIONS

The stop hook will re-feed the orchestrator prompt after each iteration.
To cancel: rm .claude/fix-pr.local.md
EOF

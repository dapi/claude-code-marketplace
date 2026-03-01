#!/bin/bash

# PR Review Fix Loop - Setup Script
# Creates state file for in-session iteration loop

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null) || {
  echo "Warning: failed to read plugin version from $PLUGIN_ROOT/.claude-plugin/plugin.json" >&2
  VERSION="unknown"
}

MAX_ITERATIONS=20
COMPLETION_PROMISES=()
REPORT_PARAMS=""

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
      COMPLETION_PROMISES+=("$2")
      shift 2
      ;;
    --report-params)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --report-params requires a text argument" >&2
        exit 1
      fi
      REPORT_PARAMS="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Build pipe-separated completion promise string
if [[ ${#COMPLETION_PROMISES[@]} -gt 0 ]]; then
  COMPLETION_PROMISE=$(IFS='|'; echo "${COMPLETION_PROMISES[*]}")
else
  COMPLETION_PROMISE="null"
fi

# Read prompt from stdin
PROMPT=$(cat)

if [[ -z "$PROMPT" ]]; then
  echo "Error: No prompt provided via stdin" >&2
  exit 1
fi

# Clean up previous run artifacts
mkdir -p .claude
rm -f .claude/pr-review-loop-report.local.md .codex-review.md .codex-review.stderr

# Create fresh report file (consumed by assemble-prompt and stop-hook)
cat > .claude/pr-review-loop-report.local.md <<REPORT_EOF
# PR Review Fix Loop Report

Дата: $(date -u +%Y-%m-%d)
Параметры: ${REPORT_PARAMS:-n/a}

---

ИТЕРАЦИЯ 1 НАЧАЛО

REPORT_EOF

# Ensure .claude/*.local.md is in .gitignore (double protection against report leaking into git)
if [[ -f .gitignore ]]; then
  if ! grep -qF '.claude/*.local.md' .gitignore; then
    printf '\n# pr-review-fix-loop local artifacts\n.claude/*.local.md\n' >> .gitignore
  fi
else
  printf '# pr-review-fix-loop local artifacts\n.claude/*.local.md\n' > .gitignore
fi

# Create state file (markdown with YAML frontmatter)

if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  # Escape backslashes and double quotes for safe YAML embedding
  ESCAPED=$(printf '%s' "$COMPLETION_PROMISE" | sed 's/\\/\\\\/g; s/"/\\"/g')
  COMPLETION_PROMISE_YAML="\"$ESCAPED\""
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

EOF
# Append prompt without shell expansion to avoid double-interpolation of $ in prompt text
printf '%s\n' "$PROMPT" >> .claude/pr-review-fix-loop.local.md

# Output setup message
echo "pr-review-fix-loop v$VERSION"
echo "Loop activated: iteration 1, max $MAX_ITERATIONS"
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo "Completion promises: $(echo "$COMPLETION_PROMISE" | sed 's/|/, /g')"
  echo ""
  echo "To complete this loop, output one of:"
  IFS='|' read -ra P <<< "$COMPLETION_PROMISE"
  for p in "${P[@]}"; do
    echo "  <promise>$p</promise>"
  done
  echo "ONLY when the statement is completely TRUE."
fi
echo ""
echo "Stop hook will feed the prompt back after each iteration."

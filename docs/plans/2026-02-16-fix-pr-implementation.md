# fix-pr Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite `/fix-pr` as a Ralph Loop orchestrator that delegates all work to parallel subagents, with context reset between iterations.

**Architecture:** Stop hook re-feeds orchestrator prompt each iteration. Three parallel check subagents (review + tests + CI) write results to separate JSON files. Orchestrator merges, evaluates, and either stops or launches fix subagent.

**Tech Stack:** Bash (setup + stop hook), Markdown (command prompt), JSON (state files), `gh` CLI, `jq`

**Design doc:** `docs/plans/2026-02-16-fix-pr-redesign.md`

---

### Task 1: Create setup script

**Files:**
- Create: `github-workflow/scripts/setup-fix-pr.sh`

**Step 1: Create the script**

```bash
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
rm -f .claude/fix-pr-check-review.json
rm -f .claude/fix-pr-check-tests.json
rm -f .claude/fix-pr-check-ci.json

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
cat > .claude/fix-pr.local.md <<'LOOPEOF'
---
active: true
iteration: 1
max_iterations: MAX_ITERATIONS_PLACEHOLDER
---
LOOPEOF

# Replace placeholder with actual value
sed -i "s/MAX_ITERATIONS_PLACEHOLDER/$MAX_ITERATIONS/" .claude/fix-pr.local.md

# Output info
cat <<EOF
fix-pr loop activated

PR: #$PR_NUMBER ($PR_URL)
Base branch: $BASE_BRANCH
Max iterations: $MAX_ITERATIONS

The stop hook will re-feed the orchestrator prompt after each iteration.
To cancel: rm .claude/fix-pr.local.md
EOF
```

**Step 2: Make executable**

Run: `chmod +x github-workflow/scripts/setup-fix-pr.sh`

**Step 3: Verify script syntax**

Run: `bash -n github-workflow/scripts/setup-fix-pr.sh`
Expected: no output (clean syntax)

**Step 4: Commit**

```bash
git add github-workflow/scripts/setup-fix-pr.sh
git commit -m "Add fix-pr setup script with pre-checks and state init"
```

---

### Task 2: Create stop hook

**Files:**
- Create: `github-workflow/hooks/fix-pr-stop-hook.sh`

**Step 1: Create the stop hook**

```bash
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
      exit 0
    fi
  fi
fi

# Stall detection: check if last 3 iterations had identical check results
STALL_JSON=".claude/fix-pr-state.json"
if [[ -f "$STALL_JSON" ]]; then
  HISTORY_LEN=$(jq '.history | length' "$STALL_JSON" 2>/dev/null || echo 0)
  if [[ "$HISTORY_LEN" -ge 6 ]]; then
    # Compare last 3 check actions' review+tests+ci status
    LAST3=$(jq '[.history | map(select(.action == "check")) | .[-3:][].review + .[-3:][].tests + .[-3:][].ci] | unique | length' "$STALL_JSON" 2>/dev/null || echo 0)
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
```

**Step 2: Make executable**

Run: `chmod +x github-workflow/hooks/fix-pr-stop-hook.sh`

**Step 3: Verify script syntax**

Run: `bash -n github-workflow/hooks/fix-pr-stop-hook.sh`
Expected: no output (clean syntax)

**Step 4: Commit**

```bash
git add github-workflow/hooks/fix-pr-stop-hook.sh
git commit -m "Add fix-pr stop hook for Ralph Loop iteration control"
```

---

### Task 3: Create hooks.json

**Files:**
- Create: `github-workflow/hooks/hooks.json`

**Step 1: Create hooks.json**

```json
{
  "description": "github-workflow hooks for PR fix loop",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/fix-pr-stop-hook.sh"
          }
        ]
      }
    ]
  }
}
```

**Step 2: Verify valid JSON**

Run: `jq . github-workflow/hooks/hooks.json`
Expected: pretty-printed JSON, exit code 0

**Step 3: Commit**

```bash
git add github-workflow/hooks/hooks.json
git commit -m "Register fix-pr stop hook in hooks.json"
```

---

### Task 4: Rewrite fix-pr.md command

**Files:**
- Modify: `github-workflow/commands/fix-pr.md` (full rewrite)

**Step 1: Rewrite the command file**

Replace entire contents with:

````markdown
---
description: Iterative PR fix loop until clean (review + tests + CI)
argument-hint: [--max-iterations=N]
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-fix-pr.sh:*)"]
---

# PR Fix Orchestrator

Run the setup script first:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-fix-pr.sh" $ARGUMENTS
```

You are a thin PR fix orchestrator. You do NOT write code yourself.
You ONLY read state, delegate to subagents, and evaluate results.

## Step 1: Read State

Read `.claude/fix-pr-state.json` to get:
- `iteration` (current), `max_iterations`
- `pr_number`, `pr_url`, `base_branch`
- `history` (previous iterations)

Remove stale check files if they exist from previous iteration:
```bash
rm -f .claude/fix-pr-check-review.json .claude/fix-pr-check-tests.json .claude/fix-pr-check-ci.json
```

## Step 2: Run 3 Parallel Check Subagents

Launch ALL THREE as parallel Task subagents (subagent_type: "general-purpose").
Each subagent writes results to its own JSON file.

**Subagent 1 -- Code Review:**

```
Run a comprehensive code review of the current PR.

Use the Skill tool to invoke: pr-review-toolkit:review-pr

After the review completes, extract all issues and write results to .claude/fix-pr-check-review.json:
{
  "status": "pass" or "fail",
  "critical": <count>,
  "important": <count>,
  "issues": [
    {"severity": "critical|important", "file": "path", "line": N, "description": "...", "fix_hint": "..."}
  ]
}

If status is "pass", critical and important must both be 0.
Only include critical and important issues (ignore suggestions/nitpicks).
If any error occurs, write: {"status": "error", "error": "description"}
```

**Subagent 2 -- Local Tests:**

```
Run the project's test suite.

1. Read CLAUDE.md in the project root to find the test command
2. If no test command in CLAUDE.md, try common commands: make test, npm test, cargo test, pytest
3. Run the test command
4. Write results to .claude/fix-pr-check-tests.json:
{
  "status": "pass" or "fail",
  "command": "the command you ran",
  "output_tail": "last 50 lines of output",
  "failed_tests": ["list", "of", "failed", "test", "names"]
}

If all tests pass, status is "pass" and failed_tests is [].
If any error occurs, write: {"status": "error", "error": "description"}
```

**Subagent 3 -- CI Status:**

Read `pr_number` from `.claude/fix-pr-state.json`, then:

```
Check CI status for the current PR.

1. Read .claude/fix-pr-state.json to get pr_number
2. Run: gh pr checks
3. Parse the output into structured data
4. Write results to .claude/fix-pr-check-ci.json:
{
  "status": "pass" or "fail" or "pending",
  "checks": [
    {"name": "check-name", "status": "pass|fail|pending", "url": "..."}
  ]
}

If ALL checks passed: status is "pass".
If ANY check failed: status is "fail".
If ANY check is still running/pending and none failed: status is "pending".
If CI has not started yet or no checks exist: status is "pending".
If any error occurs (gh auth, network): write {"status": "error", "error": "description"}
```

Wait for ALL THREE subagents to complete before proceeding.

## Step 3: Merge Results and Evaluate

Read the three result files:
- `.claude/fix-pr-check-review.json`
- `.claude/fix-pr-check-tests.json`
- `.claude/fix-pr-check-ci.json`

Merge them into `.claude/fix-pr-state.json` under `check_results`.
Add a history entry: `{"iteration": N, "action": "check", "review": STATUS, "tests": STATUS, "ci": STATUS}`

**Decision matrix:**

| review | tests | ci      | Action                                              |
|--------|-------|---------|-----------------------------------------------------|
| pass   | pass  | pass    | Output `<promise>PR CLEAN</promise>` and STOP       |
| pass   | pass  | pending | Run `sleep 30` then exit (re-check next iteration)  |
| *      | *     | *       | Continue to Step 4 (at least one failure)            |
| error  | error | error   | If 2+ consecutive all-error iterations: output `<promise>STALLED</promise>` and STOP. Otherwise exit to retry. |

## Step 4: Fix (only if failures exist)

Collect ALL failures from the three check results. Build a fix prompt with priority order:
1. Test failures (highest priority)
2. CI failures
3. Review issues (critical + important only)

Launch ONE Task subagent (subagent_type: "general-purpose") with this prompt:

```
You are fixing issues in a PR.

## Context
1. Read CLAUDE.md in project root for coding conventions
2. Read the git diff to understand what this PR changes:
   git diff BASE_BRANCH...HEAD
   (replace BASE_BRANCH with actual base branch from state)

## Issues to fix (by priority)

### Test failures (fix first)
TEST_FAILURES_JSON

### CI failures
CI_FAILURES_JSON

### Review issues (critical + important only)
REVIEW_ISSUES_JSON

## Rules
1. Fix ONLY the listed issues. Do NOT refactor unrelated code.
2. Do NOT add comments explaining fixes.
3. Stage only specific changed files:
   git add file1.ts file2.ts
   (NEVER use git add -A or git add .)
4. Create fixup commit:
   git commit -m "fix: BRIEF_DESCRIPTION (iteration N)"
5. Push: git push
6. Write a JSON summary to .claude/fix-pr-check-fix.json:
   {"status": "done", "fixes_applied": N, "skipped": [...], "commit_sha": "...", "summary": "..."}

## Anti-patterns (do NOT do these)
- Do not "fix" issues by deleting tests
- Do not suppress linter warnings with ignore comments
- Do not change test expectations to match buggy behavior
- If an issue is unclear, skip it rather than guess
```

Replace TEST_FAILURES_JSON, CI_FAILURES_JSON, REVIEW_ISSUES_JSON with actual data from check results.
Replace BASE_BRANCH with value from state file.
Replace N with current iteration number.

## Step 5: Update State and Exit

After fix subagent completes:
1. Read `.claude/fix-pr-check-fix.json` if it exists
2. Add history entry: `{"iteration": N, "action": "fix", "fixes": COUNT, "commit": "SHA"}`
3. Save updated `.claude/fix-pr-state.json`
4. Exit normally (stop hook will catch and re-feed this prompt for next iteration)

Do NOT output `<promise>PR CLEAN</promise>` after a fix -- always let the next iteration verify.
````

**Step 2: Verify no emoji in file**

Run: `grep -P '[\x{10000}-\x{10FFFF}]' github-workflow/commands/fix-pr.md || echo "Clean"`
Expected: "Clean"

**Step 3: Commit**

```bash
git add github-workflow/commands/fix-pr.md
git commit -m "Rewrite fix-pr as Ralph Loop orchestrator with parallel subagents"
```

---

### Task 5: Update README.md

**Files:**
- Modify: `github-workflow/README.md` (update /fix-pr section)

**Step 1: Update the fix-pr section**

Replace the current `/fix-pr` section with:

```markdown
### Command: /fix-pr

Iterative PR fix loop -- runs parallel checks (code review + local tests + CI) and fixes issues until the PR is clean.

```
/fix-pr
/fix-pr --max-iterations=5
```

**How it works:**
1. Verifies PR exists and working tree is clean
2. Activates a stop-hook loop (Ralph Loop pattern)
3. Each iteration runs 3 parallel checks: code review, local tests, CI
4. If failures found: fix subagent patches code, commits, pushes
5. Loop continues until all checks pass or max iterations reached

**Stop conditions:**
- All three checks pass (review clean + tests green + CI green)
- Max iterations reached (default: 10)
- Stall detected (3 identical failure iterations)

**To cancel:** `rm .claude/fix-pr.local.md`
```

**Step 2: Commit**

```bash
git add github-workflow/README.md
git commit -m "Update README with new fix-pr documentation"
```

---

### Task 6: Reinstall plugin and smoke test

**Step 1: Reinstall github-workflow plugin**

Run: `make reinstall-plugin PLUGIN=github-workflow`

**Step 2: Verify hooks registered**

Run: `cat ~/.config/claude-code/plugins/github-workflow@dapi/hooks/hooks.json | jq .`
Expected: JSON with Stop hook pointing to fix-pr-stop-hook.sh

**Step 3: Verify script is executable**

Run: `ls -la ~/.config/claude-code/plugins/github-workflow@dapi/scripts/setup-fix-pr.sh`
Expected: `-rwxr-xr-x` permissions

**Step 4: Verify command available**

Start new Claude Code session and check `/fix-pr --help` works via the setup script.

**Step 5: Commit if any fixes needed**

Fix any issues found during smoke test, commit each fix separately.

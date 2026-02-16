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

# fix-pr Redesign: Ralph Loop Orchestrator with Parallel Subagents

**Date:** 2026-02-16
**Plugin:** github-workflow
**Status:** Design approved

## Problem

Current `/fix-pr` runs review + fix in a single context window. Each iteration accumulates context from 4 review agents + fix work + test output. After 2-3 iterations the context is full of stale data. No local test or CI verification.

## Solution

Rewrite `/fix-pr` as a thin orchestrator using a Ralph Loop stop hook pattern. All heavy work delegated to Task subagents. Context resets between iterations. Three parallel checks (review + tests + CI) per iteration.

## Architecture

```
/fix-pr [--max-iterations=N]
    |
    v
  setup-fix-pr.sh: verify PR, init state, print info
    |
    v
  Orchestrator prompt (re-fed by stop hook each iteration)
    |
    +---> Task: review    (Skill pr-review-toolkit:review-pr)
    +---> Task: tests     (read CLAUDE.md, find test cmd, run)
    +---> Task: ci        (gh pr checks, parse output)
    |     [all 3 parallel]
    v
  Orchestrator merges results, evaluates
    |
    +--> all pass? -> <promise>PR CLEAN</promise> -> STOP
    +--> ci pending? -> sleep 30, exit -> next iteration re-checks
    +--> stall (3x same failures)? -> warning, stop
    +--> failures? -> Task: fix subagent -> commit + push -> exit
    |
    v
  Stop hook: increment iteration, re-feed same prompt
```

## Files

### Created/Modified

| File | Action | Lines | Purpose |
|------|--------|-------|---------|
| `commands/fix-pr.md` | Rewrite | ~80 | Setup call + orchestrator prompt |
| `scripts/setup-fix-pr.sh` | Create | ~60 | Pre-checks, init state, info output |
| `hooks/fix-pr-stop-hook.sh` | Create | ~50 | Re-feed prompt, iteration++, stall detect |
| `hooks/hooks.json` | Create | ~15 | Register Stop hook |
| `README.md` | Update | delta | Documentation for /fix-pr |

### Runtime Files (in .claude/, not committed)

| File | Writer | Reader |
|------|--------|--------|
| `fix-pr.local.md` | setup script | stop hook |
| `fix-pr-state.json` | orchestrator | orchestrator, stop hook |
| `fix-pr-check-review.json` | review subagent | orchestrator |
| `fix-pr-check-tests.json` | test subagent | orchestrator |
| `fix-pr-check-ci.json` | ci subagent | orchestrator |

## Pre-checks (setup script)

| Check | Command | On failure |
|-------|---------|------------|
| PR exists | `gh pr view --json number,url` | "No PR for current branch." STOP |
| Clean git | `git status --porcelain` | "Uncommitted changes." STOP |

## State File Schema

`.claude/fix-pr-state.json`:

```json
{
  "iteration": 2,
  "max_iterations": 10,
  "pr_number": 123,
  "pr_url": "https://github.com/owner/repo/pull/123",
  "check_results": {
    "review": {
      "status": "pass|fail|error",
      "critical": 0,
      "important": 1,
      "issues": [
        {
          "severity": "important",
          "file": "src/auth.ts",
          "line": 42,
          "description": "Missing null check",
          "fix_hint": "Add guard clause"
        }
      ]
    },
    "tests": {
      "status": "pass|fail|error",
      "output_tail": "last 50 lines of test output",
      "failed_tests": ["test_auth_refresh"]
    },
    "ci": {
      "status": "pass|fail|pending|error",
      "checks": [
        {"name": "lint", "status": "pass"},
        {"name": "test", "status": "fail", "url": "https://..."}
      ]
    }
  },
  "history": [
    {"iteration": 1, "action": "check", "review": "fail", "tests": "fail", "ci": "fail"},
    {"iteration": 1, "action": "fix", "fixes": 3, "commit": "abc123"},
    {"iteration": 2, "action": "check", "review": "pass", "tests": "pass", "ci": "pass"}
  ]
}
```

## Decision Matrix

| review | tests | ci | Action |
|--------|-------|----|--------|
| pass | pass | pass | `<promise>PR CLEAN</promise>` -- STOP |
| pass | pass | pending | sleep 30, exit (re-check next iteration) |
| pass | pass | fail | fix subagent with CI failure details |
| fail | pass | * | fix subagent with review issues |
| * | fail | * | fix subagent with test failures (priority) |
| error | error | error | exit (retry next iteration, max 2 retries) |

Fix priority: tests > CI > review.

## CI Pending Throttle

When CI is pending, orchestrator runs `sleep 30` before exiting to give CI time to complete. If CI pending for 3+ consecutive iterations, subagent uses `gh pr checks --watch --timeout 120`.

## Stall Detection

Stop hook checks history in state file. If last 3 iterations have identical failure signatures (same files, same test names), it's a stall. Output warning with remaining issues and stop.

## Fix Subagent Prompt

```
You are fixing issues in a PR.

## Context
1. Read CLAUDE.md in project root for coding conventions
2. Read the git diff to understand what this PR changes:
   git diff main...HEAD

## Issues to fix (by priority)

### Test failures (fix first)
{test failures from check_results.tests}

### CI failures
{ci failures from check_results.ci}

### Review issues (critical + important only)
{issues from check_results.review}

## Rules
1. Fix ONLY the listed issues. Do NOT refactor unrelated code.
2. Do NOT add comments explaining fixes.
3. Stage only specific changed files:
   git add file1.ts file2.ts
   (NEVER use git add -A or git add .)
4. Create fixup commit:
   git commit -m "fix: [brief description] (iteration N)"
5. Push: git push
6. Write a brief summary of what was fixed to stdout.

## Anti-patterns (do NOT do these)
- Do not "fix" issues by deleting tests
- Do not suppress linter warnings with ignore comments
- Do not change test expectations to match buggy behavior
- If an issue is unclear, skip it rather than guess
```

## Error Handling

Subagent crash: each subagent writes `"status": "error"` on failure. Orchestrator:
- review error: skip review, fix only tests+CI
- tests error: treat as fail, pass error output to fix agent
- ci error: skip CI (network/auth issue), continue without
- all three error: exit, retry next iteration (max 2 consecutive error retries)

Race condition on push: after fix+push, orchestrator does NOT check CI immediately. Exits. Next iteration CI runs on fresh commit.

Parallel write safety: each subagent writes to its own file (fix-pr-check-*.json). Orchestrator merges after all complete.

## Dependencies

- `pr-review-toolkit` plugin -- for review Skill invocation
- `gh` CLI -- for CI checks and PR verification
- No dependency on `ralph-loop` plugin -- own stop hook

## Removed from Current Version

- `.pr-fix-state.json` in project root (moved to .claude/)
- Internal loop logic in prompt
- Pseudocode and verbose documentation (260 lines -> ~80)
- `git add -A` (replaced with specific file staging)

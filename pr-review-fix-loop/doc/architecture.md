# pr-review-fix-loop Architecture

## 1. Overview

pr-review-fix-loop is a **stop-hook loop engine** that iteratively reviews and fixes PR issues until the codebase is clean or a termination condition is met.

The core idea: a Claude Code Stop hook intercepts agent exit, evaluates whether the loop should continue, and either injects the next iteration prompt (blocking exit) or allows the session to end with a post-loop automation phase.

## 2. Component Map

| File | Role |
|-|-|
| `commands/pr-review-fix-loop.md` | Main command: argument parsing, orchestration, launches setup-loop |
| `commands/codex-pr-review.md` | Standalone Codex CLI review (no loop) |
| `hooks/hooks.json` | Registers `stop-hook.sh` on the `Stop` event |
| `hooks/stop-hook.sh` | Loop controller: reads transcript, detects exit conditions, writes EXIT markers |
| `scripts/setup-loop.sh` | Creates state/report/stats files, outputs initial instructions |
| `scripts/assemble-prompt.sh` | Builds iteration prompt text from parameters (5 steps) |
| `scripts/post-loop-prompt.sh` | Generates post-loop `block` JSON for SUCCESS/STAGNANT/LIMIT/ERROR |
| `scripts/record-iteration.sh` | Appends JSON record to stats file (iteration N, issues, duration) |
| `scripts/show-progress.sh` | Renders ASCII progress banner to stderr |
| `scripts/detect-project.sh` | Auto-detects stack (Ruby/Node/Python/Go/Rust), returns JSON |
| `scripts/detect-base-branch.sh` | Determines base branch for Codex diff |
| `scripts/check-gitignore.sh` | Checks if `*.local.md` patterns are in `.gitignore` |
| `skills/pr-review-fix-loop/SKILL.md` | Auto-activating skill (universal trigger) |

## 3. Data Flow

```
User: /pr-review-fix-loop [args]
         |
         v
  [command] parse args, detect-project.sh, check-gitignore.sh
         |
         v
  assemble-prompt.sh  -->  iteration prompt text (stdin)
         |
         v
  setup-loop.sh  -->  creates 3 files:
         |             - state (.local.md with frontmatter + prompt)
         |             - report (.local.md for iteration logs)
         |             - stats (.local.json for ETA data)
         |
         v
  Agent executes iteration prompt (Steps 0-5)
         |
         v  (agent finishes turn)
  stop-hook.sh  -->  reads transcript, searches for <promise> tags
         |
         +-- CONTINUE --> block exit, inject next iteration prompt
         |                (continue_loop writes ITERATION N START marker)
         |
         +-- SUCCESS/STAGNANT/LIMIT/ERROR
                  |
                  v
            post-loop-prompt.sh --> block exit, inject post-loop instructions
                  |
                  v
            Agent executes post-loop (push, merge, analysis...)
                  |
                  v
            stop-hook.sh --> state file deleted --> exit 0 (loop inactive)
```

## 4. State Machine

The stop-hook evaluates these conditions in order:

```
  state file missing?
       |yes --> exit 0 (loop not active)
       |no
       v
  transcript missing or empty?
       |yes --> WARN + continue_loop
       |no
       v
  iteration >= max_iterations?
       |yes --> EXIT:LIMIT
       |no
       v
  <promise> tag found? (REVIEW CLEAN or REVIEW STAGNANT)
       |yes, contains STAGNANT --> EXIT:STAGNANT
       |yes, otherwise         --> EXIT:SUCCESS
       |no
       v
  fallback: check_report_for_completion()
       |-- issues_count=0 in report --> EXIT:SUCCESS (fallback)
       |-- 5+ iters, last_count >= count[-5] --> EXIT:STAGNANT (fallback)
       |-- neither --> CONTINUE (next iteration)
```

**Exit paths:**

| Exit | Marker | Post-loop action |
|-|-|-|
| SUCCESS | `[OK] [EXIT:SUCCESS]` | Final review, commit, push, CI check, offer merge |
| STAGNANT | `[!!] [EXIT:STAGNANT]` | Root cause analysis via general-purpose agent, no push |
| LIMIT | `[!!] [EXIT:LIMIT]` | Summary of remaining issues, no push |
| ERROR | `[XX] [EXIT:ERROR]` | Report error, suggest checking debug log |

## 5. Artifacts

| File | Created by | Read by | Deleted by | Lifecycle |
|-|-|-|-|-|
| `.claude/pr-review-fix-loop.local.md` | `setup-loop.sh` | `stop-hook.sh` (frontmatter + prompt) | `stop-hook.sh` on exit | Per-loop session |
| `.claude/pr-review-loop-report.local.md` | `setup-loop.sh` | Agent, `stop-hook.sh`, `post-loop-prompt.sh` | `setup-loop.sh` on next run | Per-loop session |
| `.claude/pr-review-loop-stats.local.json` | `setup-loop.sh` | `record-iteration.sh`, `show-progress.sh` | `setup-loop.sh` on next run | Per-loop session |
| `.claude/pr-review-loop-debug.local.log` | `stop-hook.sh` (dbg()) | Developer | Never | Persistent |
| `.codex-review.md` | Agent (codex run) | Agent | `setup-loop.sh` on next run | Per-loop session |
| `.codex-review.stderr` | Agent (codex run) | Agent | `setup-loop.sh` on next run | Per-loop session |

All `.local.md` files are expected to be in `.gitignore`.

## 6. Report Format

The report file (`.claude/pr-review-loop-report.local.md`) uses structured markers:

```
## ITERATION 1 START
... iteration content ...
## ITERATION 1 COMPLETED issues_count=5

## ITERATION 2 START
... iteration content ...
## ITERATION 2 COMPLETED issues_count=3

## USER DECISION iteration=2 -- file: src/foo.ts -- topic: naming -- choice: SKIP -- context: user prefers current name

[OK] [EXIT:SUCCESS] All issues resolved after 3 iterations
```

**Marker reference:**

| Marker | Written by | Purpose |
|-|-|-|
| `ITERATION N START` | `stop-hook.sh` (continue_loop) / `setup-loop.sh` | Marks iteration beginning |
| `ITERATION N COMPLETED issues_count=K` | Agent (Step 5) | Marks iteration end with issue count |
| `[OK] [EXIT:SUCCESS] reason` | `stop-hook.sh` | Clean completion |
| `[!!] [EXIT:STAGNANT] reason` | `stop-hook.sh` | Stagnation detected |
| `[!!] [EXIT:LIMIT] reason` | `stop-hook.sh` | Max iterations reached |
| `[XX] [EXIT:ERROR] reason` | `stop-hook.sh` | Error during loop |
| `[~~] [EXIT:WARN] reason` | `stop-hook.sh` | Warning (no transcript/text) |
| `USER DECISION iteration=N -- file: ... -- topic: ... -- choice: ... -- context: ...` | Agent (Step 3e) | Persisted user decisions for filtering in next iterations |

## 7. Key Algorithms

### Stagnation Detection

Two mechanisms, both checking if issue counts plateau over 5 iterations:

**In stop-hook (fallback)** -- `check_report_for_completion()`:
```
counts = all K values from "ITERATION N COMPLETED issues_count=K"
if len(counts) >= 5 AND counts[-1] >= counts[-5]:
    --> STAGNANT
```

**In agent prompt (Step 5)** -- agent evaluates the same logic and emits `<promise>REVIEW STAGNANT</promise>` if true.

### ETA Calculation

In `show-progress.sh`, displayed only when `COMPLETED >= 3`:

```
AVG_DUR = total_duration / completed_iterations
TOTAL_REDUCTION = first_issues_count - last_issues_count

if TOTAL_REDUCTION <= 0:
    # No progress -- estimate by remaining iterations
    ETA = (MAX_ITER - COMPLETED) * AVG_DUR    (label: "at limit")
else:
    # Linear projection by issue reduction rate
    REM_BY_ISSUES = last_count * COMPLETED / TOTAL_REDUCTION
    REMAINING = min(REM_BY_ISSUES, MAX_ITER - COMPLETED)
    ETA = REMAINING * AVG_DUR                 (label: "linear")
```

### Prompt Assembly Conditionals

`assemble-prompt.sh` builds the prompt by concatenating steps. Conditional blocks:

| Condition | Included block |
|-|-|
| `--codex` flag | Step 0 (codex run in background) + Step 1.5 (read codex results) |
| `--lint` flag | Step 3.5 (run auto-detected linter) |
| `TEST_CMD` non-empty | Step 3c TDD section (red/green cycle for criticality >= 7) |

Safety check at end: `grep -qE '\{[a-z_]+\}'` to catch unfilled placeholders.

## 8. Iteration Prompt Structure

Each iteration executes these steps:

| Step | Name | Description |
|-|-|-|
| 0 | Codex review | (optional, `--codex`) Run `codex review --base $BASE` in background, stdout to `.codex-review.md` |
| 0.5 | Decision journal | Read `USER DECISION` entries from report, build skip-list for filtering |
| 1 | PR review | Run `/pr-review-toolkit:review-pr $ASPECTS` |
| 1.5 | Codex results | (optional, `--codex`) Wait for codex, read `.codex-review.md` |
| 2 | Issue triage | Collect issues with criticality >= MIN_CRITICALITY, exclude SKIPPED (from decision journal), write to report, count issues |
| 2.5 | Record stats | Run `record-iteration.sh N K` |
| 3a-3b | Context exploration | Launch code-explorer agents in parallel for each issue group |
| 3c | TDD fixes | (if TEST_CMD set) Red/green TDD cycle for issues with criticality >= 7 |
| 3d | Direct fixes | Fix issues with criticality < 7 but >= MIN_CRITICALITY |
| 3e | Record fixes | Write fix results to report; record any USER DECISIONs |
| 3.5 | Lint | (optional, `--lint`) Run auto-detected linter |
| 4 | Test | Run tests for affected files |
| 4.5 | Commit | `fix: address PR review issues (iteration N)` (no push) |
| 5 | Evaluate | Write `ITERATION N COMPLETED issues_count=K`, check CLEAN/STAGNANT/CONTINUE, emit `<promise>` tag |

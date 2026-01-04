---
description: Orchestrate iterative PR review and fix cycle until no critical issues remain
argument-hint: [--max-iterations=N]
---

# PR Fix Orchestrator

Iteratively review and fix PR until no critical/important issues remain.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR                         │
│  (maintains minimal state, delegates to subagents)      │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  /pr-review-toolkit:review-pr       │
│  (Skill - launches 4 agents)        │
├─────────────────────────────────────┤
│ ├─ code-reviewer        (parallel)  │
│ ├─ pr-test-analyzer     (parallel)  │
│ ├─ silent-failure-hunter(parallel)  │
│ └─ comment-analyzer     (parallel)  │
└─────────────────────────────────────┘
         │
         ▼ (consolidated issues)
┌─────────────────┐
│   Fix Agent     │ ──▶ [Loop back to review if issues remain]
│  (subagent)     │
└─────────────────┘
         │
         ▼
   fixup commit
```

## Configuration

- **Max iterations:** $ARGUMENTS or default 5
- **Stop condition:** No `critical` or `important` severity issues

## Execution Steps

### Step 0: Initialize

1. Parse arguments for `--max-iterations=N` (default: 5)
2. Set `iteration = 0`
3. Create state file: `.pr-fix-state.json`
   ```json
   {
     "iteration": 0,
     "max_iterations": 5,
     "status": "in_progress",
     "history": []
   }
   ```

### Step 1: Run Review (Skill)

**IMPORTANT:** Use Skill tool to invoke `/pr-review-toolkit:review-pr` — this runs 4 specialized agents in parallel:
- code-reviewer
- pr-test-analyzer
- silent-failure-hunter
- comment-analyzer

```
Skill tool invocation:
  skill: "pr-review-toolkit:review-pr"
```

Wait for all 4 agents to complete and collect their results.

After review completes, consolidate results into JSON:
```json
{
  "issues": [
    {
      "severity": "critical|important|suggestion|nitpick",
      "file": "path/to/file.ts",
      "line": 42,
      "description": "Brief description of the issue",
      "fix_hint": "How to fix it",
      "source": "code-reviewer|test-analyzer|silent-failure|comment-analyzer"
    }
  ],
  "summary": {
    "critical": 0,
    "important": 0,
    "suggestion": 0,
    "nitpick": 0
  }
}
```

Extract only `critical` and `important` issues for fixing.

### Step 2: Parse Review Results

After subagent returns:

1. Parse JSON from response
2. Extract `critical` and `important` counts
3. Update state file:
   ```json
   {
     "iteration": 1,
     "history": [
       {"iteration": 1, "critical": 2, "important": 3, "action": "review"}
     ]
   }
   ```

### Step 3: Check Stop Condition

**IF** `critical == 0 AND important == 0`:
- Set `status: "success"`
- Output: "PR review complete. No critical or important issues remaining."
- **STOP**

**IF** `iteration >= max_iterations`:
- Set `status: "max_iterations_reached"`
- Output: "Max iterations reached. Remaining issues: {critical} critical, {important} important"
- **STOP**

**ELSE**: Continue to Step 4

### Step 4: Run Fix (Subagent)

Launch Task tool with `subagent_type: "general-purpose"`:

```
Prompt for subagent:
---
Fix the following PR issues. Apply fixes directly to the files.

ISSUES TO FIX:
{JSON array of critical and important issues from Step 2}

RULES:
1. Fix ONLY the issues listed above
2. Do NOT refactor unrelated code
3. Do NOT add comments explaining fixes
4. After fixing, stage changes: git add -A
5. Create fixup commit: git commit -m "fix: address review feedback (iteration N)"

Output a brief summary of what was fixed.
---
```

### Step 5: Update State and Loop

1. Increment `iteration`
2. Add to history:
   ```json
   {"iteration": N, "action": "fix", "fixes_applied": X}
   ```
3. **GOTO Step 1**

## State File Schema

File: `.pr-fix-state.json` (in project root)

```json
{
  "iteration": 2,
  "max_iterations": 5,
  "status": "in_progress|success|max_iterations_reached|error",
  "started_at": "2024-01-15T10:30:00Z",
  "history": [
    {"iteration": 1, "critical": 2, "important": 3, "action": "review"},
    {"iteration": 1, "fixes_applied": 5, "action": "fix"},
    {"iteration": 2, "critical": 0, "important": 1, "action": "review"},
    {"iteration": 2, "fixes_applied": 1, "action": "fix"},
    {"iteration": 3, "critical": 0, "important": 0, "action": "review"}
  ],
  "final_result": {
    "total_iterations": 3,
    "total_fixes": 6,
    "remaining_issues": 0
  }
}
```

## Orchestrator Pseudocode

```python
def fix_pr(max_iterations=5):
    state = initialize_state(max_iterations)

    for iteration in range(1, max_iterations + 1):
        state.iteration = iteration

        # Review phase - invoke skill (runs 4 agents in parallel)
        review_result = invoke_skill("pr-review-toolkit:review-pr")
        # This launches: code-reviewer, pr-test-analyzer,
        #                silent-failure-hunter, comment-analyzer

        issues = consolidate_issues(review_result)
        state.history.append({"iteration": iteration, "action": "review", **issues.summary})

        # Check stop condition
        if issues.critical == 0 and issues.important == 0:
            state.status = "success"
            save_state(state)
            return "Success: No critical/important issues"

        # Fix phase (subagent)
        fix_result = run_subagent(
            type="general-purpose",
            prompt=FIX_PROMPT.format(issues=issues.critical_and_important())
        )
        state.history.append({"iteration": iteration, "action": "fix"})
        save_state(state)

    state.status = "max_iterations_reached"
    save_state(state)
    return f"Max iterations reached. Remaining: {issues.summary}"
```

## Output Format

### On Success
```
✅ PR Fix Complete

Iterations: 3
Total fixes applied: 6
Final status: No critical or important issues

History:
  [1] Review: 2 critical, 3 important → Fix: 5 issues
  [2] Review: 0 critical, 1 important → Fix: 1 issue
  [3] Review: 0 critical, 0 important → Done
```

### On Max Iterations
```
⚠️ PR Fix Incomplete

Iterations: 5 (max reached)
Remaining: 1 critical, 2 important

History:
  [1] Review: 5 critical, 8 important → Fix: 10 issues
  ...
  [5] Review: 1 critical, 2 important → Stopped

Run `/fix-pr` again to continue, or review remaining issues manually.
```

## Rules

- Each review/fix runs in isolated subagent context
- Orchestrator maintains only minimal state (JSON file)
- Never pass full file contents between iterations
- Subagents work with current git state, not cached data
- Commits are created after each fix iteration for easy rollback

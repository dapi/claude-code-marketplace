---
name: pr-review-fix-loop
description: |
  **UNIVERSAL TRIGGER**: Iterative PR review + autofix loop. Use when user wants to review, check, or fix PR changes automatically.

  Common patterns:
  - "review my PR", "check my PR", "review changes"
  - "fix review comments", "address review findings"
  - "run review loop", "autofix PR issues"
  - "проверь мой PR", "ревью PR", "проверь изменения"
  - "исправь замечания ревью", "пофикси замечания"
  - "запусти ревью", "автоисправление PR"

  **PR Review** (iterative review + fix cycle):
  - "review and fix my PR", "check PR and fix issues"
  - "iterate on PR review", "review loop"
  - "проверь и исправь PR", "итеративное ревью"

  **Code Review Fix** (address existing review comments):
  - "fix review comments", "address PR feedback"
  - "fix code review issues", "resolve review findings"
  - "исправь замечания", "пофикси комментарии ревью"

  **Codex Review** (standalone Codex CLI review):
  - "codex review", "run codex on my changes"
  - "codex ревью", "запусти codex"

  TRIGGERS: review PR, check PR, fix PR, review changes, review loop,
  autofix, pr review, code review fix, address review, fix comments,
  review findings, iterate review, codex review, run codex,
  проверь PR, ревью PR, исправь замечания, пофикси PR,
  проверь изменения, запусти ревью, автоисправление,
  codex ревью, замечания ревью, фикс PR
---

# PR Review Fix Loop

Navigator for iterative PR review + autofix loop. Analyzes context and suggests the optimal command.

## When to activate

- User wants to review their PR changes
- User wants to fix review comments automatically
- User mentions "review loop", "autofix", "check PR"
- User wants Codex CLI review (standalone)

## Instructions

### Step 1: Determine user intent

Determine which command fits:

| Intent | Command |
|-|-|
| Iterative review + fix cycle | `/pr-review-fix-loop` |
| Standalone Codex review | `/codex-pr-review` |
| Just review without fixing | Suggest `/pr-review-toolkit:review-pr` instead |

If intent is unclear, ask the user.

### Step 2: Suggest parameters (for /pr-review-fix-loop)

Based on context, suggest relevant flags:

- If user mentions specific aspects (code, errors, tests, types, comments, simplify) -- add `--aspects "..."`
- If user mentions criticality threshold -- add `--min-criticality N`
- If user mentions linting -- add `--lint`
- If user mentions Codex -- add `--codex`
- If user mentions specific base branch -- add `--base BRANCH`
- If user mentions iteration limit -- add `--max-iterations N`

Default (no flags) is fine for most cases.

### Step 3: Present the command

Show the user the suggested command with brief explanation:

```
/pr-review-fix-loop [flags]
```

Explain what will happen:
1. PR review via pr-review-toolkit
2. Automatic fix of issues above criticality threshold
3. Repeat until clean or stagnation detected
4. Report saved to `.claude/pr-review-loop-report.local.md`

### Step 4: Let user run the command

Do NOT run the command yourself. Present it and let the user invoke it.

## Examples

### Example 1: Simple PR review

User says: "review my PR"
Action: Suggest `/pr-review-fix-loop`
Result: User runs the command, loop starts

### Example 2: Review with specific focus

User says: "check my PR for errors and code issues only"
Action: Suggest `/pr-review-fix-loop --aspects "code errors"`

### Example 3: Review with Codex

User says: "review my changes with codex too"
Action: Suggest `/pr-review-fix-loop --codex`

### Example 4: Codex-only review

User says: "run codex review"
Action: Suggest `/codex-pr-review`

### Example 5: Fix review comments

User says: "fix the review comments on my PR"
Action: Suggest `/pr-review-fix-loop --min-criticality 3` (lower threshold to catch more issues)

## Troubleshooting

### Plugin not installed
If `/pr-review-fix-loop` command is not available, tell user:
```
/plugin install pr-review-fix-loop@dapi
```

### Required plugins missing
If pr-review-toolkit or feature-dev not installed:
```
/plugin install pr-review-toolkit
/plugin install feature-dev
```

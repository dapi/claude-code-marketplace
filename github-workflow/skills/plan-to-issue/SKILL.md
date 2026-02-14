---
name: plan-to-issue
description: |
  **UNIVERSAL TRIGGER**: SAVE/PUBLISH/EXPORT implementation plan TO GitHub issue for separate session execution.

  Common patterns:
  - "save/publish/export plan to issue"
  - "create issue from plan", "plan to github"
  - "сохрани план в issue", "создай issue из плана"

  **Save Plan**:
  - "save plan to issue", "publish plan to github"
  - "сохрани план в issue", "экспортируй план"

  **Create Issue from Plan**:
  - "create issue from plan", "plan as issue"
  - "создай issue из плана", "план в задачу"

  **Execute Later**:
  - "save for separate session", "execute plan later"
  - "сохрани для отдельной сессии", "выполнить потом"

  **Should NOT activate**:
  - General "create issue" without plan context
  - Reading existing issues
  - Working with issue checkboxes

  TRIGGERS: plan to issue, save plan, export plan, publish plan,
    plan as issue, issue from plan, plan to github,
    сохрани план, план в issue, экспорт плана, план в задачу,
    save for later, execute later, separate session,
    сохрани для сессии, выполнить потом, план в github
allowed-tools: Bash, Read, Glob, Grep
---

# Plan to GitHub Issue

Save an implementation plan as a GitHub issue for execution in a separate Claude Code session.

**Announce at start:** "Saving implementation plan to GitHub issue."

## Algorithm

### Step 1: Find the plan file

Search from the git repository root:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
ls -t "$REPO_ROOT"/docs/plans/*.md 2>/dev/null | head -1
```

If no plan files found, check if user specified a file path. If still nothing, report error:
"No plan files found in docs/plans/. Please specify the plan file path."

### Step 2: Read the plan

Read the plan file content using the Read tool.

### Step 3: Gather context metadata

Run these commands to get repository and branch info:

```bash
# Repository (owner/repo format)
gh repo view --json nameWithOwner -q .nameWithOwner

# Current branch
git branch --show-current

# Working directory
pwd
```

### Step 4: Compose the issue body

Structure the issue body as follows:

```markdown
> **For Claude:** Use `superpowers:executing-plans` skill to implement this plan task-by-task.
> Start in the worktree directory shown below.

**Context**

| Field | Value |
|-------|-------|
| Repository | {owner/repo} |
| Branch | {branch-name} |
| Working directory | {pwd} |
| Plan file | {relative path to plan file} |

---

{Full plan file content}
```

### Step 5: Extract title from plan

Parse the first `# ` heading from the plan file as the issue title.
If no heading found, use the filename (without date prefix and extension).

### Step 6: Create the issue

Use `--body-file -` to handle large plans (avoids command-line length limits):

```bash
echo "$BODY" | gh issue create --title "{title}" --body-file - --label "plan"
```

If the "plan" label does not exist, create without labels:

```bash
echo "$BODY" | gh issue create --title "{title}" --body-file -
```

### Step 7: Report result

Show the created issue URL and suggest how to use it:

"Plan saved to {issue_url}

To execute in a separate session:
1. Open new Claude Code session in the worktree
2. Tell Claude: 'Execute plan from {issue_url}'"

## Error Handling

- **No plan file**: Ask user to specify the path
- **No git repo**: Report error, suggest running from within a repository
- **gh not authenticated**: Suggest `gh auth login`
- **Label creation fails**: Create issue without labels (non-blocking)

## Important

- Pipe body via `echo "$BODY" | gh issue create --body-file -` to preserve formatting
- Do NOT modify the plan content, copy it as-is
- Include the `superpowers:executing-plans` reference so the next session knows what skill to use

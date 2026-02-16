# Merge Zellij Skills Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge `zellij-dev-tab` into `zellij-tab-pane` as Mode D, delete the old skill.

**Architecture:** Add Mode D (issue development) to the existing decision tree in `zellij-tab-pane/SKILL.md`, merge trigger keywords from both skills, then remove `zellij-dev-tab/` directory.

**Tech Stack:** Markdown (SKILL.md with YAML frontmatter)

---

### Task 1: Update SKILL.md -- add Mode D and merge triggers

**Files:**
- Modify: `zellij-workflow/skills/zellij-tab-pane/SKILL.md`

**Step 1: Update YAML frontmatter description**

Merge trigger keywords from `zellij-dev-tab` into `zellij-tab-pane` description. Add issue-specific patterns to the description block:

```yaml
---
name: zellij-tab-pane
description: |
  **UNIVERSAL TRIGGER**: OPEN/CREATE/RUN/GET/START tab or pane IN zellij -- empty, with command, with Claude session, or with GitHub issue.

  Common patterns:
  - "open/create/get new tab/pane in zellij"
  - "run/launch/start [command] in new tab/pane"
  - "execute/delegate/send [task/plan] in new tab/pane"
  - "start/open/launch [issue] in new tab/pane"
  - "show/display/view command output in tab/pane"
  - "check/retrieve/fetch results in tab/pane"
  - "open/create tab/pane", "run [command] in pane/tab"
  - "start issue #N in tab/pane", "start-issue in tab/pane"
  - "run start-issue in new tab/pane"

  Russian:
  - "open/create tab/pane", "run [command] in pane/tab"
  - "start issue in tab/pane", "issue development in tab/pane"
  - "run start-issue in tab/pane"

  TRIGGERS: new tab, new pane, create tab, create pane, open tab, open pane,
  run in tab, run in pane, execute in tab, execute in pane, launch in tab,
  launch in pane, delegate to tab, delegate to pane, command in tab,
  command in pane, parallel tab, parallel pane, background tab, background pane,
  zellij tab, zellij pane, zellij panel,
  start issue tab, open issue tab, launch issue tab, create tab issue,
  run start-issue tab, zellij new tab issue, separate tab development,
  new tab issue, development in tab, issue development tab,
  work on issue in tab, begin issue tab,
  start issue pane, open issue pane, launch issue pane, create pane issue,
  run start-issue pane, issue development pane, work on issue in pane,
  new tab, new pane, create tab, create pane, open tab, open pane,
  run in tab, run in pane, zellij tab, zellij pane, zellij panel,
  start issue tab, open issue tab, launch issue tab,
  start issue pane, open issue pane, launch issue pane,
  zellij new tab issue, issue development tab, issue development pane
allowed-tools: Bash
---
```

**Step 2: Update Decision Tree**

Replace the existing decision tree with:

```
Step 1: Container
  "pane"/"panel"/"panel'" -> PANE
  "tab"/"tab'"/"default   -> TAB

Step 2: Mode
  nothing to run              -> A (empty)
  shell command               -> B (command)
  Claude prompt/plan/task     -> C (claude session)
  GitHub issue (#N / URL)     -> D (issue dev via start-issue)
```

**Step 3: Add Mode D section**

Insert after Mode C section (before Examples), the full Mode D block:

```markdown
## Mode D: Issue Development in Tab/Pane

User wants to start development on a GitHub issue. Recognized when request contains issue reference (number, #number, or GitHub URL).

**Tab name:** always `#NUMBER`.

### Issue Number Parsing

` ` `bash
parse_issue_number() {
  local arg="$1"
  if [[ "$arg" =~ github\.com/.*/issues/([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$arg" =~ ^#?([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}
` ` `

### Issue Argument Format

| Format | Example | Result |
|--------|---------|--------|
| Number | `123` | Issue #123 |
| With hash | `#123` | Issue #123 |
| URL | `https://github.com/owner/repo/issues/123` | Issue #123 |

### TAB

` ` `bash
ISSUE_NUMBER=$(parse_issue_number "$ARG")

timeout 5 zellij action new-tab --name "#${ISSUE_NUMBER}" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "start-issue $ARG
" || {
  _rc=$?
  echo "Command failed. Diagnosing..."
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif [ $_rc -eq 124 ]; then echo "Timed out -- zellij may be hanging"
  elif ! command -v start-issue &>/dev/null; then echo "start-issue not found in PATH"
  else echo "Unknown error (exit code: $_rc)"
  fi
  exit $_rc
}
` ` `

### PANE

` ` `bash
timeout 5 zellij run -- start-issue $ARG || {
  _rc=$?
  echo "Command failed. Diagnosing..."
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif [ $_rc -eq 124 ]; then echo "Timed out -- zellij may be hanging"
  elif ! command -v start-issue &>/dev/null; then echo "start-issue not found in PATH"
  else echo "Unknown error (exit code: $_rc)"
  fi
  exit $_rc
}
` ` `
```

**Step 4: Add Mode D examples**

Add after existing examples:

```markdown
### Example 6: Issue in tab

**User:** "start issue #45 in a new tab"

` ` `bash
timeout 5 zellij action new-tab --name "#45" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "start-issue 45
"
` ` `

### Example 7: Issue URL in pane

**User:** "start https://github.com/org/repo/issues/123 in a pane"

` ` `bash
timeout 5 zellij run -- start-issue https://github.com/org/repo/issues/123
` ` `
```

**Step 5: Update Dependencies and Errors**

Add to Dependencies:
```
- **start-issue** -- issue development command (for Mode D only)
```

Add to Errors table:
```
| `start-issue not found` | start-issue not in PATH | Install or add to PATH |
| `Invalid issue format` | Bad argument | Use number, #number, or URL |
```

**Step 6: Remove cross-reference line**

Delete the last line: "This skill does NOT handle issue development -- use `zellij-dev-tab` skill for that"

**Step 7: Verify no emoji in file**

Run: `bash -c 'grep -P "[\x{10000}-\x{10FFFF}]" zellij-workflow/skills/zellij-tab-pane/SKILL.md || echo "OK: no emoji"'`
Expected: "OK: no emoji"

**Step 8: Commit**

```bash
git add zellij-workflow/skills/zellij-tab-pane/SKILL.md
git commit -m "Merge zellij-dev-tab Mode D into zellij-tab-pane skill"
```

---

### Task 2: Delete zellij-dev-tab skill

**Files:**
- Delete: `zellij-workflow/skills/zellij-dev-tab/` (entire directory)

**Step 1: Remove the directory**

Run: `rm -rf zellij-workflow/skills/zellij-dev-tab`

**Step 2: Verify no references remain**

Run: `grep -r "zellij-dev-tab" zellij-workflow/`
Expected: no output (no remaining references)

**Step 3: Commit**

```bash
git add -A zellij-workflow/skills/zellij-dev-tab
git commit -m "Remove zellij-dev-tab skill (merged into zellij-tab-pane)"
```

---

### Task 3: Update plugin metadata

**Files:**
- Modify: `zellij-workflow/.claude-plugin/plugin.json` (if description mentions skill count)
- Modify: `CLAUDE.md` (update Current State table: zellij-workflow now has 1 skill instead of 2)

**Step 1: Check plugin.json**

Read `zellij-workflow/.claude-plugin/plugin.json`. Update description if it references two skills.

**Step 2: Update CLAUDE.md Current State table**

Change zellij-workflow row from "2 skills" to "1 skill". Update totals from "11 skills" to "10 skills".

**Step 3: Commit**

```bash
git add zellij-workflow/.claude-plugin/plugin.json CLAUDE.md
git commit -m "Update metadata: zellij-workflow now has 1 merged skill"
```

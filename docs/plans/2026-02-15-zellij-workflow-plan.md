# zellij-workflow Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create unified `zellij-workflow` plugin merging `zellij-tab-claude-status`, `zellij-dev-tab`, and new `zellij-claude-tab` into one.

**Architecture:** Single plugin with hooks (tab status), two skills (dev-tab, claude-tab), and two commands. Replaces three separate plugins.

**Tech Stack:** Markdown (skills/commands), JSON (hooks, plugin.json), Bash (zellij actions)

**Design doc:** `docs/plans/2026-02-15-zellij-workflow-design.md`

---

### Task 1: Create plugin structure and plugin.json

**Files:**
- Create: `zellij-workflow/.claude-plugin/plugin.json`

**Step 1: Create directory structure**

```bash
mkdir -p zellij-workflow/.claude-plugin
mkdir -p zellij-workflow/hooks
mkdir -p zellij-workflow/skills/zellij-dev-tab
mkdir -p zellij-workflow/skills/zellij-claude-tab
mkdir -p zellij-workflow/commands
```

**Step 2: Create plugin.json**

Create `zellij-workflow/.claude-plugin/plugin.json`:

```json
{
  "name": "zellij-workflow",
  "description": "Zellij workflow: tab status indicators, issue development tabs, Claude session tabs",
  "version": "1.0.0",
  "author": {
    "name": "Danil Pismenny",
    "email": "danilpismenny@gmail.com"
  },
  "license": "MIT",
  "homepage": "https://github.com/dapi/claude-code-marketplace",
  "repository": "https://github.com/dapi/claude-code-marketplace",
  "keywords": ["zellij", "tabs", "workflow", "status", "claude", "session", "development"]
}
```

**Step 3: Verify JSON**

Run: `python3 -c "import json; json.load(open('zellij-workflow/.claude-plugin/plugin.json'))"`
Expected: No output (valid)

---

### Task 2: Migrate hooks from zellij-tab-claude-status

**Files:**
- Create: `zellij-workflow/hooks/hooks.json`

**Step 1: Create hooks.json**

Create `zellij-workflow/hooks/hooks.json` -- based on `zellij-tab-claude-status/hooks/hooks.json` with `|| true` added to all commands for graceful degradation:

```json
{
  "description": "Zellij tab status indicator hooks",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [{"type": "command", "command": "zellij-tab-status '◉' || true"}]
      }
    ],
    "PostToolUseFailure": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [{"type": "command", "command": "zellij-tab-status '○' || true"}]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [{"type": "command", "command": "zellij-tab-status '○' || true"}]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [{"type": "command", "command": "zellij-tab-status '◉' || true"}]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [{"type": "command", "command": "zellij-tab-status '✋' || true"}]
      },
      {
        "matcher": "idle_prompt",
        "hooks": [{"type": "command", "command": "zellij-tab-status '○' || true"}]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{"type": "command", "command": "zellij-tab-status '○' || true"}]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [{"type": "command", "command": "zellij-tab-status --clear || true"}]
      }
    ]
  }
}
```

**IMPORTANT:**
- No `async: true` anywhere -- hooks must be synchronous for correct tab focus
- All commands end with `|| true` -- graceful degradation if zellij-tab-status is not installed

**Step 2: Verify JSON**

Run: `python3 -c "import json; json.load(open('zellij-workflow/hooks/hooks.json'))"`
Expected: No output (valid)

**Step 3: Migrate test-plugin.sh**

Copy from `zellij-tab-claude-status/test-plugin.sh` to `zellij-workflow/test-plugin.sh`.
Update paths inside the script to reference `zellij-workflow/hooks/hooks.json`.

---

### Task 3: Migrate zellij-dev-tab skill

**Files:**
- Create: `zellij-workflow/skills/zellij-dev-tab/SKILL.md`
- Create: `zellij-workflow/skills/zellij-dev-tab/TRIGGER_EXAMPLES.md`

**Step 1: Copy SKILL.md**

Copy from `zellij-dev-tab/skills/zellij-dev-tab/SKILL.md` to `zellij-workflow/skills/zellij-dev-tab/SKILL.md`.

No content changes needed -- file is self-contained with no references to parent plugin structure.

**Step 2: Copy TRIGGER_EXAMPLES.md with cross-skill negatives**

Copy from `zellij-dev-tab/skills/zellij-dev-tab/TRIGGER_EXAMPLES.md` to `zellij-workflow/skills/zellij-dev-tab/TRIGGER_EXAMPLES.md`.

**Add cross-skill negative examples** to the "Should NOT Activate" section:

```markdown
### Claude session requests (use zellij-claude-tab instead)

- "execute plan in a new zellij tab"
- "run claude with these instructions in new tab"
- "launch plan from docs/plans/audit.md in separate tab"
- "delegate this task to a new tab"
- "выполни план в новой вкладке"
- "запусти claude с инструкциями в отдельной вкладке"
```

**Step 3: Verify no absolute paths**

Run: `grep -rn "^/" zellij-workflow/skills/zellij-dev-tab/ || echo "OK"`
Expected: "OK"

---

### Task 4: Migrate start-issue-in-new-tab command

**Files:**
- Create: `zellij-workflow/commands/start-issue-in-new-tab.md`

**Step 1: Copy command**

Copy from `zellij-dev-tab/commands/start-issue-in-new-tab.md` to `zellij-workflow/commands/start-issue-in-new-tab.md`.

No content changes needed.

---

### Task 5: Create zellij-claude-tab skill (new)

**Files:**
- Create: `zellij-workflow/skills/zellij-claude-tab/SKILL.md`

**Step 1: Create SKILL.md**

Create `zellij-workflow/skills/zellij-claude-tab/SKILL.md`:

````markdown
---
name: zellij-claude-tab
description: |
  **UNIVERSAL TRIGGER**: EXECUTE/RUN/LAUNCH Claude session with instructions IN separate zellij TAB.

  Common patterns:
  - "execute/run/launch [task/plan] in new tab"
  - "start claude session in new tab with [instructions]"
  - "выполни/запусти [задачу] в новой вкладке zellij"

  **Execute Plan/Task**:
  - "run this plan in a new zellij tab"
  - "execute plan from docs/plans/... in separate tab"
  - "launch this task in new tab", "start in parallel tab"
  - "выполни план в отдельной вкладке"

  **Start Session**:
  - "open claude session in new tab"
  - "start new claude in zellij tab with these instructions"
  - "create tab and run claude with prompt"
  - "открой сессию claude в новой вкладке"

  **Delegate Work**:
  - "delegate this to a new tab"
  - "run this in background tab", "parallel session for this"
  - "send to new tab", "offload to separate tab"
  - "запусти в параллельной вкладке"

  TRIGGERS: run in new tab, execute in tab, launch in tab, new tab claude,
  claude session tab, zellij claude tab, parallel tab, delegate to tab,
  start session tab, run plan tab, execute plan tab, separate session,
  выполни в вкладке, запусти в вкладке, новая вкладка, сессия в вкладке,
  параллельная сессия, отдельная вкладка, делегируй в вкладку
allowed-tools: Bash
---

# Zellij Claude Tab Skill

Launch an interactive Claude Code session in a separate zellij tab with arbitrary instructions.
The session remains a working chat after processing the initial prompt.

## MANDATORY CHECKS

**Claude MUST verify before executing:**

```bash
# 1. Check we are inside zellij
if [ -z "$ZELLIJ" ]; then
  echo "Error: not in a zellij session. Start zellij first."
  # DO NOT execute, warn user
fi

# 2. Check claude CLI is available
if ! command -v claude &>/dev/null; then
  echo "Error: claude not found in PATH. Install Claude Code CLI."
  # DO NOT execute, warn user
fi
```

**If any check fails** -- inform the user and DO NOT run `zellij action`.

## How It Works

1. Claude receives instructions to execute in a new tab
2. Generates a short tab name from context (e.g. `plan-audit`, `#123`, `refactor`)
3. Writes prompt to a temp file (avoids escaping issues)
4. Creates zellij tab and launches `claude` with the prompt
5. Temp file is deleted immediately after reading, before claude starts

## Execution Steps

### Step 1: Determine tab name

Auto-generate a short name (1-2 words, max 20 chars) from the instruction context:
- Has issue reference -> `#123`
- Has plan file -> `plan-audit`
- General task -> `refactor`, `fix-tests`, etc.
- Fallback -> `claude-<HH:MM>` (e.g. `claude-14:35`)

**Handle tab name collisions:**

```bash
# Check if tab with chosen name already exists, append suffix if needed
EXISTING=$(zellij action query-tab-names 2>/dev/null || true)
if echo "$EXISTING" | grep -qx "$TAB_NAME"; then
  N=2
  while echo "$EXISTING" | grep -qx "${TAB_NAME}-${N}"; do N=$((N+1)); done
  TAB_NAME="${TAB_NAME}-${N}"
fi
```

### Step 2: Write prompt to temp file

```bash
PROMPT_FILE=$(mktemp /tmp/claude-tab-XXXXXX.md)
cat > "$PROMPT_FILE" << 'PROMPT_EOF'
<instructions here - the full prompt for the new session>
PROMPT_EOF
```

### Step 3: Create tab and launch claude

```bash
TAB_NAME="<auto-generated>"
PROJECT_DIR=$(pwd)

zellij action go-to-tab-name --create "$TAB_NAME" && \
zellij action new-pane -- bash -c \
  "cd '$PROJECT_DIR' && PROMPT=\$(cat '$PROMPT_FILE') && rm '$PROMPT_FILE' && claude \"\$PROMPT\"" && \
zellij action focus-previous-pane && \
zellij action close-pane
```

**NOTE:** Single quotes around `$PROJECT_DIR` and `$PROMPT_FILE` inside the bash -c string prevent issues with spaces in paths. These variables are expanded before bash -c runs, so the single quotes end up in the inner shell command.

**How it works:**
1. `go-to-tab-name --create` -- creates tab (or switches if exists)
2. `new-pane -- command` -- runs command in a new pane
3. Prompt is read into variable, temp file deleted immediately
4. `claude "$PROMPT"` -- starts **interactive** session with initial prompt
5. `focus-previous-pane` + `close-pane` -- removes empty shell pane

## Examples

### Example 1: Execute a plan

**User:** "Execute the plan from docs/plans/skill-audit-plan.md in a new zellij tab"

**Claude writes to temp file:**
```
Execute the plan from docs/plans/2026-02-14-skill-audit-plan.md for issue #20.
Use superpowers:executing-plans.
```

**Claude runs:**
```bash
PROMPT_FILE=$(mktemp /tmp/claude-tab-XXXXXX.md)
cat > "$PROMPT_FILE" << 'PROMPT_EOF'
Execute the plan from docs/plans/2026-02-14-skill-audit-plan.md for issue #20. Use superpowers:executing-plans.
PROMPT_EOF
zellij action go-to-tab-name --create "plan-audit" && \
zellij action new-pane -- bash -c "cd '$(pwd)' && PROMPT=\$(cat '$PROMPT_FILE') && rm '$PROMPT_FILE' && claude \"\$PROMPT\"" && \
zellij action focus-previous-pane && \
zellij action close-pane
```

### Example 2: Arbitrary task

**User:** "Run refactoring of the auth module in a separate tab"

**Claude generates tab name:** `refactor-auth`
**Prompt:** "Refactor the auth module: <details from conversation context>"

## Dependencies

- **zellij** -- terminal multiplexer (must be running)
- **claude** -- Claude Code CLI (available in new tab's PATH)

## Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Not in zellij session` | Running outside zellij | Start zellij first |
| `claude: command not found` | Claude CLI not in PATH | Install Claude Code |
| Temp file not created | /tmp not writable | Check disk space |

## Important

- Skill works **only inside zellij session**
- Zellij spawns a fresh shell in new tab -- no env var inheritance issues
- Session is **interactive** (not -p print mode) -- remains a working chat
- Temp file is removed immediately after reading, before claude starts
- This skill does NOT handle pure issue development -- use `zellij-dev-tab` skill for that
````

**Step 2: Verify no emoji**

Run: `./scripts/lint_no_emoji.sh zellij-workflow`
Expected: PASS

---

### Task 6: Create zellij-claude-tab TRIGGER_EXAMPLES.md

**Files:**
- Create: `zellij-workflow/skills/zellij-claude-tab/TRIGGER_EXAMPLES.md`

**Step 1: Create trigger examples**

Create `zellij-workflow/skills/zellij-claude-tab/TRIGGER_EXAMPLES.md`:

```markdown
# Zellij Claude Tab Trigger Examples

## [YES] Should Activate

### Execute Plan (EN)

- "execute this plan in a new zellij tab"
- "run the plan from docs/plans/audit.md in separate tab"
- "launch plan execution in new tab"
- "start executing this plan in a parallel tab"
- "open a new tab and execute this plan"
- "run this in a new zellij tab"
- "execute in separate tab"
- "run the implementation plan in another tab"
- "execute this plan file in a fresh tab"
- "kick off the plan in a new zellij tab"

### **Выполнить план (RU)**

- "выполни этот план в новой вкладке zellij"
- "запусти план в отдельной вкладке"
- "открой новую вкладку и выполни план"
- "выполни в параллельной вкладке"
- "запусти в отдельной сессии zellij"
- "выполни задачу в новой вкладке"
- "запусти в новом табе"
- "исполни план в другой вкладке"
- "план выполнения запусти в табе zellij"

### Start Session (EN)

- "start a claude session in new tab"
- "open claude in a new zellij tab with these instructions"
- "create a new tab and run claude"
- "launch claude session in separate tab"
- "start new session in tab"
- "claude in new tab"
- "spin up a claude session in another tab"
- "new claude tab with this prompt"
- "fire up claude in a fresh zellij tab"

### **Начать сессию (RU)**

- "открой сессию claude в новой вкладке"
- "создай вкладку и запусти claude"
- "новая сессия claude в вкладке"
- "запусти claude в новой вкладке с инструкциями"
- "сессия в отдельной вкладке"
- "нужна новая сессия claude в табе"
- "создай claude сессию в отдельной вкладке"

### Delegate Work (EN)

- "delegate this task to a new tab"
- "offload this to a separate tab"
- "run this in a background tab"
- "send this work to a new tab"
- "parallel session for this task"
- "hand this off to a new tab"
- "move this work to its own tab"
- "fork this into a new tab"

### **Делегировать (RU)**

- "делегируй это в новую вкладку"
- "отправь в отдельную вкладку"
- "запусти параллельно в другой вкладке"
- "перенеси в новую вкладку"
- "вынеси эту работу в отдельный таб"
- "раздели на параллельную вкладку"

### With Plan File Reference

- "execute docs/plans/2026-02-14-skill-audit-plan.md in new tab"
- "run the plan from skill-audit-plan.md in a zellij tab"
- "выполни план из docs/plans/audit.md в новой вкладке"
- "launch docs/plans/refactor-plan.md in separate tab"
- "open docs/plans/migration.md in a new tab and execute it"
- "запусти docs/plans/feature-plan.md в отдельной вкладке"

### With Issue Reference + Instructions

- "execute plan for issue #20 in new tab"
- "start working on #45 in a separate zellij tab with executing-plans"
- "выполни задачу #123 в новой вкладке с планом"
- "run the plan for #78 in another tab"
- "запусти план для issue #56 в параллельной вкладке"

### Combined / Polite

- "could you run this in a new zellij tab?"
- "please execute the plan in a separate tab"
- "I'd like this running in a new tab"
- "можешь запустить в новой вкладке?"
- "пожалуйста выполни в отдельной вкладке"
- "would you mind running this in its own tab?"
- "будь добр, запусти в отдельном табе"

## [NO] Should NOT Activate

### General zellij Questions

- "what is zellij?"
- "how to install zellij?"
- "как настроить zellij?"
- "zellij documentation"

### Tab Management (no claude session)

- "rename this tab"
- "close the tab"
- "switch to another tab"
- "переименуй вкладку"

### Issue Development (use zellij-dev-tab skill instead)

- "запусти разработку issue 45 в новой вкладке"
- "start issue #123 in new tab"
- "start-issue в отдельной вкладке"
- "открой issue в новой вкладке"
- "run start-issue in new tab"

### Issue Without Tab Context

- "show issue #123"
- "read issue 45"
- "create a new issue"

### Run Commands (not claude session)

- "run tests"
- "execute make build"
- "start the server"

### Questions About Plans

- "show me the plan"
- "what does the plan contain?"
- "read docs/plans/audit.md"

## Key Trigger Words

### Verbs

**EN:** execute, run, launch, start, open, create, delegate, offload, send
**RU:** выполни, запусти, открой, создай, делегируй, отправь, перенеси

### Nouns

**EN:** tab, session, claude, plan, task, instructions
**RU:** вкладка, сессия, план, задача, инструкции

### Distinguishing from zellij-dev-tab

This skill: **arbitrary instructions** in new tabs.
zellij-dev-tab: **issue development** via `start-issue`.

Key: if request is purely "start issue #N in tab" without extra instructions -> zellij-dev-tab.
```

---

### Task 7: Create run-in-new-tab command (new)

**Files:**
- Create: `zellij-workflow/commands/run-in-new-tab.md`

**Step 1: Create the command**

Create `zellij-workflow/commands/run-in-new-tab.md`:

````markdown
---
description: Run Claude session in new zellij tab with given instructions
argument-hint: <instructions or plan-file-path>
---

# Run in New Tab

Launch an interactive Claude Code session in a new zellij tab.

## Input

- **INSTRUCTIONS**: `$ARGUMENTS` -- prompt text or path to a plan file

## Steps

### 1. Check environment

```bash
if [ -z "$ZELLIJ" ]; then
  echo "[FAIL] Not in zellij session. Run zellij first."
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "[FAIL] claude not found in PATH. Install Claude Code CLI."
  exit 1
fi
```

**If any check fails** -- inform user and DO NOT continue.

### 2. Determine tab name and prompt

If `$ARGUMENTS` is a file path (ends with `.md`), the prompt should be:
```
Execute the plan from <plan-file-path>. Use superpowers:executing-plans.
```
Otherwise use `$ARGUMENTS` directly as the prompt.

Generate a short tab name (1-2 words) from the content.
Fallback: `claude-<HH:MM>`.

**Handle tab name collisions:**
```bash
EXISTING=$(zellij action query-tab-names 2>/dev/null || true)
if echo "$EXISTING" | grep -qx "$TAB_NAME"; then
  N=2; while echo "$EXISTING" | grep -qx "${TAB_NAME}-${N}"; do N=$((N+1)); done
  TAB_NAME="${TAB_NAME}-${N}"
fi
```

### 3. Write prompt to temp file

```bash
PROMPT_FILE=$(mktemp /tmp/claude-tab-XXXXXX.md)
echo "<prompt>" > "$PROMPT_FILE"
```

### 4. Create tab and launch claude

```bash
PROJECT_DIR=$(pwd)
TAB_NAME="<auto-generated>"

zellij action go-to-tab-name --create "$TAB_NAME" && \
zellij action new-pane -- bash -c \
  "cd '$PROJECT_DIR' && PROMPT=\$(cat '$PROMPT_FILE') && rm '$PROMPT_FILE' && claude \"\$PROMPT\"" && \
zellij action focus-previous-pane && \
zellij action close-pane
```

## Examples

```bash
/run-in-new-tab Execute plan from docs/plans/skill-audit-plan.md. Use executing-plans.
/run-in-new-tab Refactor auth module following DRY principles
/run-in-new-tab Fix all failing tests in spec-reviewer plugin
```

## Result

- New zellij tab created with auto-generated name
- Interactive Claude Code session running with the given instructions
- Session remains a working chat after initial prompt
````

---

### Task 8: Create README.md

**Files:**
- Create: `zellij-workflow/README.md`

**Step 1: Create README**

Create `zellij-workflow/README.md`:

```markdown
# zellij-workflow

Unified Zellij workflow plugin: tab status indicators, issue development tabs, and Claude session tabs.

## Features

### Tab Status Indicators

Automatically shows Claude session state via icon prefix in tab name:

| Icon | State | Description |
|------|-------|-------------|
| `○` | Ready | Waiting for input |
| `◉` | Working | Processing request |
| `✋` | Needs input | Permission prompt waiting |

Requires [zellij-tab-status](https://github.com/dapi/zellij-tab-status) plugin.

### Issue Development Tabs

Launch `start-issue` in a new zellij tab:

```
/start-issue-in-new-tab 123
/start-issue-in-new-tab #45
/start-issue-in-new-tab https://github.com/owner/repo/issues/78
```

Or say: "Start issue #123 in a new tab"

### Claude Session Tabs

Launch interactive Claude Code session with arbitrary instructions:

```
/run-in-new-tab Execute plan from docs/plans/audit-plan.md. Use executing-plans.
/run-in-new-tab Refactor the auth module
```

Or say:
- "Execute the plan in a new zellij tab"
- "Выполни план в новой вкладке"
- "Delegate this to a new tab"

## Installation

### Step 1: Install zellij-tab-status dependency (optional, for status icons)

Install [zellij-tab-status](https://github.com/dapi/zellij-tab-status):

```bash
make install-zellij-tab-status
```

Add to `~/.config/zellij/config.kdl`:

```kdl
load_plugins {
    "file:~/.config/zellij/plugins/zellij-tab-status.wasm"
}
```

### Step 2: Install plugin

```bash
/plugin install zellij-workflow@dapi
```

## Requirements

- [Zellij](https://zellij.dev) >= 0.40 terminal multiplexer (`query-tab-names` support)
- [zellij-tab-status](https://github.com/dapi/zellij-tab-status) (optional, for status icons)
- `start-issue` in PATH (for issue development tabs)
- `claude` CLI in PATH (for Claude session tabs)

## Components

| Component | File | Purpose |
|-----------|------|---------|
| Hooks | [hooks/hooks.json](./hooks/hooks.json) | Tab status indicators |
| Skill | [skills/zellij-dev-tab/SKILL.md](./skills/zellij-dev-tab/SKILL.md) | Issue development in tab |
| Skill | [skills/zellij-claude-tab/SKILL.md](./skills/zellij-claude-tab/SKILL.md) | Claude session in tab |
| Command | [commands/start-issue-in-new-tab.md](./commands/start-issue-in-new-tab.md) | `/start-issue-in-new-tab` |
| Command | [commands/run-in-new-tab.md](./commands/run-in-new-tab.md) | `/run-in-new-tab` |
```

---

### Task 9: Register in marketplace and remove old plugins

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Edit marketplace.json**

Remove entries for `zellij-tab-claude-status` and `zellij-dev-tab`.

Add new entry (in their place):

```json
{
  "name": "zellij-workflow",
  "source": "./zellij-workflow",
  "description": "Zellij workflow: tab status indicators, issue development tabs, Claude session tabs"
}
```

**Step 2: Verify JSON**

Run: `python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))"`
Expected: No output (valid)

---

### Task 10: Quality checks

**Step 1: Run emoji lint**

Run: `./scripts/lint_no_emoji.sh zellij-workflow`
Expected: PASS

**Step 2: Run skill trigger review for both skills**

Run: `./scripts/review_skill_triggers.sh zellij-workflow/zellij-dev-tab`
Expected: Score >= 75/100

Run: `./scripts/review_skill_triggers.sh zellij-workflow/zellij-claude-tab`
Expected: Score >= 75/100

**Step 3: Verify no absolute paths**

Run: `grep -rn "^/" zellij-workflow/skills/ zellij-workflow/commands/ zellij-workflow/README.md | grep -v "/tmp/" || echo "OK"`
Expected: "OK"

**Step 4: Verify no parent marketplace references**

Run: `grep -r "\.\./\.\./\.claude-plugin" zellij-workflow/ || echo "OK"`
Expected: "OK"

**Step 5: Verify hooks.json has no async:true**

Run: `grep -i "async" zellij-workflow/hooks/hooks.json || echo "OK: no async"`
Expected: "OK: no async"

**Step 6: Verify all hook commands have || true**

Run: `grep '"command":' zellij-workflow/hooks/hooks.json | grep -v '|| true' && echo "FAIL: missing || true" || echo "OK: all have || true"`
Expected: "OK: all have || true"

**Step 7: Fix any issues, re-run checks**

---

### Task 11: Commit new plugin

**Step 1: Stage and commit**

```bash
git add zellij-workflow/
git commit -m "Add zellij-workflow plugin: unified zellij tab management"
```

---

### Task 12: Update marketplace.json and commit

**Step 1: Stage and commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "Replace zellij-tab-claude-status and zellij-dev-tab with unified zellij-workflow"
```

---

### Task 13: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update Current State section**

Replace this row in the plugin table:
```
| zellij-tab-claude-status | hooks only |
```

With:
```
| zellij-workflow | 2 skills, 2 commands, hooks |
```

Note: `zellij-dev-tab` is not in the current CLAUDE.md table (only in marketplace.json), so only `zellij-tab-claude-status` needs replacing.

Update totals accordingly (plugin count stays the same if zellij-dev-tab was not listed; adjust if it was).

Also update the `zellij-tab-claude-status Plugin` special rules section to reference `zellij-workflow` instead.

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Update CLAUDE.md: replace zellij plugins with unified zellij-workflow"
```

---

### Task 14: Remove old plugin directories (after verification)

**Step 1: Verify zellij-workflow is complete**

Check that all files from old plugins exist in zellij-workflow:
- hooks.json content matches
- SKILL.md content matches
- Command content matches

**Step 2: Remove old directories**

```bash
rm -rf zellij-tab-claude-status/
rm -rf zellij-dev-tab/
rm -rf zellij-claude-tab/  # if it was created
```

**Step 3: Commit**

```bash
git add -A
git commit -m "Remove old zellij plugins replaced by zellij-workflow"
```

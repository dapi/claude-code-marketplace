# Design: zellij-workflow Plugin (unified)

**Date**: 2026-02-15
**Status**: Draft
**Supersedes**: `2026-02-14-zellij-claude-tab-design.md`

## Problem

Zellij functionality is split across 3 separate plugins (`zellij-tab-claude-status`, `zellij-dev-tab`, and planned `zellij-claude-tab`). This means 3 installs, 3 plugin.json files, fragmented documentation, and no shared context between related features.

## Solution

Merge all Zellij-related functionality into one unified plugin **`zellij-workflow`**:
- Tab status indicators (hooks)
- Issue development in new tabs (skill + command)
- Claude sessions with arbitrary prompts in new tabs (skill + command)

## Architecture

```
zellij-workflow/
+-- .claude-plugin/plugin.json
+-- hooks/
|   +-- hooks.json                     # Tab status hooks (from zellij-tab-claude-status)
+-- skills/
|   +-- zellij-dev-tab/                # Start issue in tab
|   |   +-- SKILL.md
|   |   +-- TRIGGER_EXAMPLES.md
|   +-- zellij-claude-tab/             # Claude session with prompt in tab
|       +-- SKILL.md
|       +-- TRIGGER_EXAMPLES.md
+-- commands/
|   +-- start-issue-in-new-tab.md      # /start-issue-in-new-tab #123
|   +-- run-in-new-tab.md              # /run-in-new-tab <instructions>
+-- test-plugin.sh                     # Hook testing script (from zellij-tab-claude-status)
+-- README.md
```

## Components

### 1. Hooks: Tab Status Indicators

Migrated from `zellij-tab-claude-status` with `|| true` added to all commands. Shows Claude session state via icon prefix.

| Event | Icon | Meaning |
|-------|------|---------|
| SessionStart | `○` | Ready |
| UserPromptSubmit | `◉` | Working |
| Notification (permission/elicitation) | `✋` | Needs input |
| Notification (idle_prompt) | `○` | Ready |
| Stop | `○` | Stopped |
| SessionEnd | --clear | Clear icon |

**Rules:**
- NO `async: true` -- hooks must run synchronously for correct tab focus
- Depends on external `zellij-tab-status` CLI + WASM plugin
- ALL commands must end with `|| true` -- graceful degradation if zellij-tab-status is not installed
- Example: `zellij-tab-status '◉' || true`

### 2. Skill: zellij-dev-tab

Migrated from `zellij-dev-tab` plugin. Launches `start-issue` in a new tab.

**Trigger:** "start/open/launch issue in new tab" / "запусти issue в новой вкладке"

**Flow:**
1. Parse issue number (number, #number, or GitHub URL)
2. Create tab named `#123`
3. Run `start-issue` in new pane

### 3. Skill: zellij-claude-tab (new)

Launches interactive Claude Code session with arbitrary instructions in a new tab.

**Trigger:** "execute/run/launch [task] in new tab" / "выполни [задачу] в новой вкладке"

**Flow:**
1. Write prompt to temp file
2. Generate tab name from context (fallback: `claude-<HH:MM>`)
3. Create tab, read prompt into variable, delete temp file, launch `claude "$PROMPT"`

**Pre-checks:**
```bash
# Both must pass before executing
if [ -z "$ZELLIJ" ]; then echo "Error: not in zellij session"; exit 1; fi
if ! command -v claude &>/dev/null; then echo "Error: claude not in PATH"; exit 1; fi
```

**Tab name collision handling:**
```bash
# If tab already exists, append numeric suffix
EXISTING=$(zellij action query-tab-names 2>/dev/null || true)
if echo "$EXISTING" | grep -qx "$TAB_NAME"; then
  N=2; while echo "$EXISTING" | grep -qx "${TAB_NAME}-${N}"; do N=$((N+1)); done
  TAB_NAME="${TAB_NAME}-${N}"
fi
```

**Key command:**
```bash
zellij action go-to-tab-name --create "$TAB_NAME" && \
zellij action new-pane -- bash -c \
  "cd '$PROJECT_DIR' && PROMPT=\$(cat '$PROMPT_FILE') && rm '$PROMPT_FILE' && claude \"\$PROMPT\"" && \
zellij action focus-previous-pane && \
zellij action close-pane
```

### 4. Commands

- `/start-issue-in-new-tab <issue>` -- direct invocation for issue development
- `/run-in-new-tab <instructions>` -- direct invocation for Claude sessions

## Trigger Conflict Resolution

`zellij-dev-tab` vs `zellij-claude-tab` when request mentions both issue AND tab:
- Pure issue development (start-issue, no extra instructions) -> `zellij-dev-tab`
- Arbitrary instructions, plan files, non-issue tasks -> `zellij-claude-tab`
- Both skills include cross-reference negative examples:
  - `zellij-claude-tab` negative: issue-only requests (use dev-tab)
  - `zellij-dev-tab` negative: plan/instructions requests (use claude-tab)

## Tab Naming

- Issue reference -> `#123`
- Plan file -> `plan-audit`
- General task -> `refactor`, `fix-tests`
- Fallback -> `claude-<HH:MM>`
- Duplicate name -> append suffix: `plan-audit-2`

## Migration Plan

### Files to migrate (non-obvious)

- `zellij-tab-claude-status/test-plugin.sh` -- migrate to `zellij-workflow/test-plugin.sh` for hook testing

### Plugins to remove from marketplace

1. `zellij-tab-claude-status` -- hooks migrated to `zellij-workflow/hooks/`
2. `zellij-dev-tab` -- skill+command migrated to `zellij-workflow/`

### New plugin to add

1. `zellij-workflow` -- unified plugin with all components

### Old directories

Keep old plugin directories until migration is verified, then remove.

## Dependencies

- **zellij >= 0.40** -- terminal multiplexer (must be running; 0.40+ required for `query-tab-names`)
- **zellij-tab-status** -- WASM plugin + CLI for tab status icons (optional, hooks degrade gracefully)
- **claude** -- Claude Code CLI (for zellij-claude-tab skill)
- **start-issue** -- external script (for zellij-dev-tab skill)

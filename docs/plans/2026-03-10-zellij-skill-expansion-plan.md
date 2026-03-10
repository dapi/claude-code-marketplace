# Zellij Skill Expansion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite `zellij-tab-pane` skill into `zellij` skill covering 7 domains (~48 unique commands) of zellij 0.44, replacing the current 4-mode structure.

**Architecture:** Single mega-skill with domain-based sections. Decision tree at top routes to correct section. Error diagnostics at bottom with three templates (session-required action, session-required top-level, standalone top-level).

**Tech Stack:** Markdown (SKILL.md), YAML frontmatter, bash code blocks

**Key simplification:** `write-chars` completely eliminated from skill and commands. All modes use `new-tab -- CMD` (verified on zellij 0.44). `write-chars` not documented at all — if Claude needs to type into existing pane, it can use `send-keys`.

**Quoting caveat:** For Claude session prompts with special characters (quotes, `$`, backticks), use an intermediate script via `bash -c` or `mktemp`. Simple prompts work directly.

**Timeout policy:** `timeout 5` removed from all commands. Rationale: `new-tab -- CMD` is non-blocking (returns immediately after creating tab), unlike the old `write-chars` chain that could hang mid-sequence. Top-level commands (`list-sessions`, `attach`) are also fast. If a command hangs, the user can Ctrl+C — an explicit timeout adds complexity without benefit for non-blocking operations.

**Error handling convention:** Three templates based on command type:
1. `zellij action ...` and session-required top-level (`zellij run`, `zellij edit`) -> check `$ZELLIJ`
2. Standalone top-level (`list-sessions`, `attach`, `kill-session`, `delete-session`) -> no `$ZELLIJ` check
3. All use `_rc=$?` immediately after `||` to preserve the original exit code

Domain-specific checks (e.g. `command -v start-issue`, `command -v claude`) go in `elif` branches where relevant. No `command -v zellij` check — if the command ran and failed, zellij is in PATH.

---

### Task 1: Rename skill directory and write complete SKILL.md

**Files:**
- Rename: `zellij-workflow/skills/zellij-tab-pane/` -> `zellij-workflow/skills/zellij/`
- Create: `zellij-workflow/skills/zellij/SKILL.md` (full rewrite)

**Step 1: Rename directory**

```bash
git mv zellij-workflow/skills/zellij-tab-pane zellij-workflow/skills/zellij
```

Note: `git mv` preserves history and stages the rename automatically. The existing `TRIGGER_EXAMPLES.md` is carried over by the rename — Task 3 overwrites it with the expanded version.

**Step 2: Write YAML frontmatter**

```yaml
---
name: zellij
description: |
  **UNIVERSAL TRIGGER**: Any action IN zellij terminal multiplexer.

  7 domains: sessions, tabs, panes, floating/fullscreen, layout, edit, input/output.

  Examples: "open new tab", "list sessions", "close pane", "toggle floating",
  "dump layout", "edit file.rs", "send ctrl+c to pane",
  "открой вкладку", "список сессий", "закрой панель", "плавающие панели",
  "сохрани layout", "редактировать файл", "отправь ctrl+c"

  TRIGGERS: zellij, zellij tab, zellij pane, zellij session,
  zellij multiplexer, terminal multiplexer,
  floating pane, fullscreen, layout,
  вкладка zellij, панель zellij, сессия zellij, плавающ, раскладка,
  мультиплексер, терминальный мультиплексер,
  open tab, new tab, new pane, list sessions, switch session,
  close tab, close pane, rename pane, rename tab,
  toggle floating, dump layout, edit file in zellij, send keys,
  resize pane, move focus, go to tab, attach session, kill session,
  открой вкладку, новая панель, список сессий, закрой вкладку,
  закрой панель, переименуй вкладку, подключись к сессии
allowed-tools: Bash
---
```

**Step 3: Write Decision Tree**

```markdown
# Zellij Skill

Manage zellij terminal multiplexer: sessions, tabs, panes, layouts, and more.

## Decision Tree

Request -> identify domain:

  session/сессия                                  -> Sessions
  tab/вкладка + create/open/run/claude/issue      -> Tabs: Create
  tab/вкладка + list/show/info                    -> Tabs: Query
  tab/вкладка + go-to/switch/next/prev            -> Tabs: Navigate
  tab/вкладка + close/rename/move                 -> Tabs: Manage
  pane/панель + create/open/run                   -> Panes: Create
  pane/панель + list/show                         -> Panes: Query
  pane/панель + close/rename/move/resize/focus    -> Panes: Manage
  floating/fullscreen/плавающ                     -> Floating & Fullscreen
  layout/раскладка                                -> Layout
  edit/редакт + file                              -> Edit (NB: `zellij edit`, not `zellij action`)
  send-keys/paste/dump-screen/clear               -> Input/Output

**Ambiguity rules:**
- Creates something new -> Create (even "open floating pane" -> Panes: Create with -f)
- Toggles visibility -> Floating & Fullscreen
- Moves focus -> Navigate
```

**Step 4: Write Sessions section**

Two groups: commands that work anywhere vs commands requiring active session.

```markdown
## Sessions

### Works anywhere (no active session required)

**List sessions:**
zellij list-sessions              # table with status
zellij list-sessions -s           # names only
zellij list-sessions -n           # no colors (for parsing)

**Attach to session:**
zellij attach SESSION_NAME
zellij attach -c SESSION_NAME    # create if not exists
zellij attach -b SESSION_NAME    # create detached in background

**Kill session:**
zellij kill-session TARGET
zellij kill-all-sessions

**Delete session (remove saved state):**
zellij delete-session TARGET
zellij delete-session -f TARGET  # kill first if running
zellij delete-all-sessions

### Requires active session

**Switch session:**
zellij action switch-session NAME
zellij action switch-session NAME --cwd /path --layout LAYOUT   # verify flags on 0.44

**Rename current session:**
zellij action rename-session NEW_NAME
```

**Step 5: Write Tabs section**

Subsections: Create, Query, Navigate, Manage.

Key: `new-tab -- CMD` replaces `write-chars` hack for all modes.

NOTE on code format: Commands in SKILL.md should be in ` ```bash ``` ` code blocks (matching current SKILL.md style), not plain text. The plan shows them inline for brevity.

```markdown
## Tabs

### Create tab

**Empty tab:**
zellij action new-tab --name "$NAME"

**Tab with shell command:**
zellij action new-tab --name "$NAME" -- $CMD
zellij action new-tab --name "$NAME" --cwd /path -- $CMD
zellij action new-tab --name "$NAME" --close-on-exit -- $CMD

**Tab with Claude session:**

Simple prompt (no special characters):
zellij action new-tab --name "$NAME" --cwd "$PROJECT_DIR" -- claude --dangerously-skip-permissions "$PROMPT"

Complex prompt (quotes, $, backticks):
SCRIPT=$(mktemp /tmp/claude-tab-XXXXXX.sh)
cat > "$SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
exec claude --dangerously-skip-permissions '<PROMPT with escaped single quotes>'
SCRIPT_EOF
chmod +x "$SCRIPT"
zellij action new-tab --name "$NAME" --cwd "$PROJECT_DIR" -- bash "$SCRIPT"

Tab name: from context (1-2 words, max 20 chars). Has issue -> `#123`. Has plan -> `plan-audit`. General -> `refactor`. Fallback -> `claude-HH:MM`.

**Tab with GitHub issue:**
zellij action new-tab --name "#$NUMBER" -- start-issue $NUMBER

Issue formats: `123`, `#123`, `https://github.com/owner/repo/issues/123`

**Tab with layout:**
zellij action new-tab --layout /path/to/layout.kdl --name "$NAME"

### Query tabs
zellij action list-tabs                  # table format
zellij action list-tabs --json           # JSON
zellij action query-tab-names            # tab names (verify on 0.44)

### Navigate tabs
zellij action go-to-tab-name NAME
zellij action go-to-tab-name NAME --create   # create if missing (verify flag)
zellij action go-to-tab INDEX                # by 1-based index
zellij action go-to-next-tab
zellij action go-to-previous-tab

### Manage tabs
zellij action close-tab                      # close current
zellij action rename-tab NEW_NAME            # rename current
zellij action undo-rename-tab
zellij action move-tab left|right
zellij action toggle-active-sync-tab         # broadcast input to all panes

NOTE: Verify on 0.44: close-tab-by-id, rename-tab-by-id may not exist. If absent, omit.
```

**Step 6: Write Panes section**

```markdown
## Panes

### Create pane
zellij action new-pane                                # auto-placed
zellij action new-pane -d right|down                  # directional (verify -d flag)
zellij action new-pane -f                             # floating
zellij action new-pane -f --width 50% --height 50%    # sized floating
zellij action new-pane -f --pinned                    # always on top (verify flag)
zellij action new-pane -i                             # in-place (suspends current)
zellij action new-pane --stacked                      # stacked (verify flag)
zellij action new-pane -n "name" -- CMD               # with command
zellij action new-pane --cwd /path -- CMD             # with cwd

**Shorthand (zellij run):**
zellij run -- CMD                              # new pane with command
zellij run -f -- CMD                           # floating
zellij run -i -- CMD                           # in-place
zellij run -n "name" --cwd /path -- CMD        # named, with cwd
zellij run -c -- CMD                           # close on exit
zellij run -s -- CMD                           # start suspended (verify flag)
zellij run --block-until-exit -- CMD           # block caller until command finishes (verify flag)

### Query panes
zellij action list-panes                  # table
zellij action list-panes --json           # JSON (includes command, geometry, state, tab)

NOTE: `list-panes --json` returns all fields at once. No per-field filters exist.

### Manage panes
zellij action close-pane
zellij action rename-pane NEW_NAME
zellij action undo-rename-pane
zellij action move-focus right|left|up|down
zellij action focus-next-pane
zellij action focus-previous-pane
zellij action move-pane [right|left|up|down]
zellij action move-pane-backwards
zellij action resize increase|decrease [right|left|up|down]
NOTE: Verify on 0.44 before including:
  zellij action stack-panes -- terminal_1 terminal_2 plugin_3  (syntax may differ)
  zellij action set-pane-color ...  (args may be positional, not --bg/--fg)
  zellij action change-floating-pane-coordinates ...  (verify arg names)
```

**Step 7: Write Floating & Fullscreen section**

```markdown
## Floating and Fullscreen

zellij action toggle-floating-panes                   # toggle all floating in tab
zellij action show-floating-panes                      # show (exit 2 if already visible)
zellij action show-floating-panes --tab-id ID          # in specific tab
zellij action hide-floating-panes                      # hide (exit 2 if already hidden)
zellij action hide-floating-panes --tab-id ID
zellij action toggle-pane-embed-or-floating            # convert focused pane
zellij action toggle-pane-pinned                       # pin/unpin floating pane
zellij action toggle-fullscreen                        # fullscreen focused pane

NOTE: `change-floating-pane-coordinates` — verify exact arg names on 0.44 before including.
```

**Step 8: Write Layout section**

```markdown
## Layout

### Save current layout
zellij action dump-layout                              # to stdout
zellij action dump-layout > layout.kdl                 # to file (relative to CWD)

### Apply layout
zellij action override-layout /path/to/layout.kdl
zellij action override-layout /path/to/layout.kdl --apply-only-to-active-tab          # verify flag
zellij action override-layout /path/to/layout.kdl --retain-existing-terminal-panes   # verify flag
zellij action override-layout /path/to/layout.kdl --retain-existing-plugin-panes     # verify flag

### Cycle swap layouts
zellij action next-swap-layout
zellij action previous-swap-layout
```

**Step 9: Write Edit section**

```markdown
## Edit

### Open file in $EDITOR pane
zellij edit /path/to/file.rs                     # new pane
zellij edit /path/to/file.rs -l 42               # at line 42
zellij edit /path/to/file.rs -f                  # floating
zellij edit /path/to/file.rs -i                  # in-place
zellij edit /path/to/file.rs -f --width 80% --height 80%
zellij edit /path/to/file.rs --cwd /project

### Edit scrollback
zellij action edit-scrollback                    # open pane scrollback in $EDITOR
```

**Step 10: Write Input/Output section**

```markdown
## Input/Output

### Send keys to pane
zellij action send-keys "Ctrl c"                           # to focused pane
zellij action send-keys -p terminal_1 "Ctrl c"             # to specific pane
zellij action send-keys "Alt Shift b"                      # modifier combos
zellij action send-keys "F1"                               # function keys

### Paste
zellij action paste                                        # bracketed paste from clipboard

### Dump screen
zellij action dump-screen /path/to/output.txt              # viewport only
zellij action dump-screen -f /path/to/output.txt           # with full scrollback

### Clear
zellij action clear                                        # clear focused pane buffers
```

**Step 11: Write Examples section**

10 examples covering all 7 domains (at least one per domain):

```markdown
## Examples

### List sessions
User: "show zellij sessions"
  zellij list-sessions -s

### Attach to session
User: "attach to zellij session dev"
  zellij attach dev

### Run command in new tab
User: "run npm test in new tab"
  zellij action new-tab --name "npm-test" -- npm test

### Navigate to tab
User: "go to tab api"
  zellij action go-to-tab-name api

### Edit file at line
User: "open src/main.rs at line 42 in zellij"
  zellij edit src/main.rs -l 42

### Query panes as JSON
User: "show all panes with their commands"
  zellij action list-panes --json

### Floating pane with command
User: "run htop in floating pane"
  zellij run -f -n "htop" -- htop

### Toggle floating panes
User: "toggle floating panes"
  zellij action toggle-floating-panes

### Save layout to file
User: "save current zellij layout"
  zellij action dump-layout > layout.kdl

### Send Ctrl+C to specific pane
User: "send ctrl+c to pane terminal_3"
  zellij action send-keys -p terminal_3 "Ctrl c"
```

**Step 12: Write Error Diagnostics and Dependencies**

Three error templates based on command type:

```markdown
## Error Diagnostics

### For `zellij action` commands (require active session)
command || {
  _rc=$?
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  else echo "Exit code: $_rc"
  fi
}

### For session-required top-level commands (`zellij run`, `zellij edit`)
Same template as `zellij action` -- these are top-level but still need an active session.
command || {
  _rc=$?
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  else echo "Exit code: $_rc"
  fi
}

### For standalone top-level commands (list-sessions, attach, kill-session, delete-session)
No $ZELLIJ check needed -- these work outside zellij.
command || { _rc=$?; echo "Failed (exit code: $_rc)"; }

| Error | Cause | Solution |
|-|-|-|
| Not in zellij session | Running outside zellij | Start zellij first |
| claude not found | CLI not in PATH | Install Claude Code |
| start-issue not found | Script not in PATH | Install or add to PATH |
| exit code 2 (show/hide) | Already in target state | Not an error, ignore |

## Dependencies

- **zellij 0.44+** (terminal multiplexer)
- **claude CLI** (for Claude session tabs only)
- **start-issue** (for GitHub issue tabs only)
- **$EDITOR / $VISUAL** (for `zellij edit` only)

## Important

- `zellij action` commands work only inside zellij session
- Top-level commands (list-sessions, attach, kill/delete) work anywhere
- `new-tab -- CMD` provides full TTY -- interactive commands work
- Pane stays in "held" state after command exits (press Enter to close)
- Use `--close-on-exit` to auto-close pane when command finishes
- For Claude prompts with special characters, use mktemp script instead of inline quoting
```

**Step 13: Update README.md**

Replace `zellij-tab-pane` with `zellij` in `zellij-workflow/README.md` (skill name and path references).

**Step 14: Commit**

```bash
git add zellij-workflow/skills/ zellij-workflow/README.md
git commit -m "Add zellij mega-skill: rewrite zellij-tab-pane as 7-domain skill

BREAKING: skill renamed zellij-tab-pane -> zellij
BREAKING: write-chars hack replaced with new-tab -- CMD (zellij 0.44)
New domains: sessions, floating/fullscreen, layout, edit, input/output
Existing domains expanded: tabs (query, navigate, manage), panes (query, manage)"
```

---

### Task 2: Update slash commands to use `new-tab -- CMD`

**Files:**
- Modify: `zellij-workflow/commands/start-issue-in-new-tab.md`
- Modify: `zellij-workflow/commands/run-in-new-tab.md`

**Step 1: Rewrite start-issue-in-new-tab.md**

Keep "### 1. Parse issue number" section unchanged. Replace "### 2. Create tab and launch start-issue" — `write-chars` hack with `new-tab -- CMD`:

```markdown
### 2. Create tab and launch start-issue

**In a new tab (default):**
zellij action new-tab --name "#${ISSUE_NUMBER}" -- start-issue $ISSUE_NUMBER || {
  _rc=$?
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif ! command -v start-issue &>/dev/null; then echo "start-issue not found in PATH"
  else echo "Exit code: $_rc"
  fi
}

**In a new pane:**
zellij run -- start-issue $ISSUE_NUMBER || {
  _rc=$?
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif ! command -v start-issue &>/dev/null; then echo "start-issue not found in PATH"
  else echo "Exit code: $_rc"
  fi
}
```

Remove: `sleep 0.3`, `write-chars`, `timeout 5`.

**Step 2: Rewrite run-in-new-tab.md**

Replace `write-chars` hack with `new-tab -- CMD`. Use `--cwd` instead of `cd` in script.

For simple prompts:
```markdown
zellij action new-tab --name "$TAB_NAME" --cwd "$PROJECT_DIR" -- claude --dangerously-skip-permissions "$PROMPT" || {
  _rc=$?
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif ! command -v claude &>/dev/null; then echo "claude not found in PATH"
  else echo "Exit code: $_rc"
  fi
}
```

For complex prompts (keep mktemp script but without `cd`):
```markdown
SCRIPT=$(mktemp /tmp/claude-tab-XXXXXX.sh)
cat > "$SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
exec claude --dangerously-skip-permissions '<PROMPT>'
SCRIPT_EOF
chmod +x "$SCRIPT"
zellij action new-tab --name "$TAB_NAME" --cwd "$PROJECT_DIR" -- bash "$SCRIPT" || {
  _rc=$?
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif ! command -v claude &>/dev/null; then echo "claude not found in PATH"
  else echo "Exit code: $_rc"
  fi
}
```

**In a new pane (simple prompt):**
```markdown
zellij run -- claude --dangerously-skip-permissions "$PROMPT" || {
  _rc=$?
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif ! command -v claude &>/dev/null; then echo "claude not found in PATH"
  else echo "Exit code: $_rc"
  fi
}
```

**In a new pane (complex prompt):**
```markdown
zellij run -- bash "$SCRIPT" || {
  _rc=$?
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif ! command -v claude &>/dev/null; then echo "claude not found in PATH"
  else echo "Exit code: $_rc"
  fi
}
```

Remove: `sleep 0.3`, `write-chars`, `timeout 5`, `cd` in script, `clear`+`echo` preamble.

Bump command versions: `1.0.0` -> `2.0.0`.

**Step 3: Commit**

```bash
git add zellij-workflow/commands/
git commit -m "Update zellij commands: use new-tab -- CMD, remove write-chars"
```

---

### Task 3: Create TRIGGER_EXAMPLES.md

**Files:**
- Create: `zellij-workflow/skills/zellij/TRIGGER_EXAMPLES.md`

**Step 1: Write trigger examples**

Minimum 54 positive (6 per domain x 9 categories), 10 negative. EN + RU.

**Categories:**

**Sessions (6):**
- "list zellij sessions" / "список сессий zellij"
- "switch to session dev" / "переключись на сессию dev"
- "kill session test" / "убей сессию test"
- "show active zellij sessions" / "покажи активные сессии"
- "attach to session main" / "подключись к сессии main"
- "rename zellij session" / "переименуй сессию"

**Tabs - Create (6):**
- "open new tab" / "открой новую вкладку"
- "run npm test in new tab" / "запусти npm test в новой вкладке"
- "start issue #45 in tab" / "стартани issue #45 в вкладке"
- "delegate refactoring to new tab" / "делегируй рефакторинг в вкладку"
- "execute plan in tab" / "запусти план в вкладке"
- "open tab with layout" / "открой вкладку с layout"

**Tabs - Query/Navigate/Manage (6):**
- "list zellij tabs" / "покажи вкладки"
- "go to tab api" / "перейди на вкладку api"
- "close current tab" / "закрой вкладку"
- "rename tab to dev" / "переименуй вкладку в dev"
- "next tab" / "следующая вкладка"
- "move tab left" / "сдвинь вкладку влево"

**Panes - Create (6):**
- "open new pane" / "открой панель"
- "run htop in floating pane" / "запусти htop в плавающей панели"
- "open pane to the right" / "открой панель справа"
- "run tests in pane below" / "запусти тесты в панели снизу"
- "open pane in-place" / "открой панель вместо текущей"
- "create stacked pane" / "создай stacked панель"

**Panes - Query/Manage (6):**
- "list panes as json" / "покажи панели в json"
- "resize pane right" / "увеличь панель вправо"
- "close pane" / "закрой панель"
- "move focus down" / "переключи фокус вниз"
- "rename pane to logs" / "переименуй панель в logs"
- "stack these panes" / "объедини панели в стек"

**Floating/Fullscreen (6):**
- "toggle floating panes" / "переключи плавающие панели"
- "fullscreen this pane" / "на весь экран"
- "pin floating pane" / "закрепи плавающую панель"
- "show floating panes" / "покажи плавающие панели"
- "hide floating panes" / "скрой плавающие панели"
- "make pane floating" / "сделай панель плавающей"

**Layout (6):**
- "dump current layout" / "сохрани раскладку"
- "apply layout from file" / "примени layout из файла"
- "next swap layout" / "следующий layout"
- "save layout to file" / "экспортируй layout"
- "override layout keeping existing panes" / "примени layout с сохранением панелей"
- "previous swap layout" / "предыдущий layout"

**Edit (6):**
- "edit file.rs in zellij" / "открой file.rs в редакторе"
- "open scrollback" / "открой скроллбэк"
- "edit src/main.rs at line 42" / "редактируй main.rs строка 42"
- "open file in floating editor" / "открой файл в плавающем редакторе"
- "edit file in-place" / "редактируй файл вместо текущей панели"
- "open config.yaml in zellij editor" / "открой config.yaml в редакторе zellij"

**Input/Output (6):**
- "send ctrl+c to pane" / "отправь ctrl+c в панель"
- "dump screen to file" / "сдампь экран в файл"
- "clear pane" / "очисти панель"
- "paste text into pane" / "вставь текст в панель"
- "send F1 to pane" / "отправь F1 в панель"
- "dump screen with full scrollback" / "сдампь экран со всем скроллбэком"

**Negative (10):**
- "install zellij"
- "configure zellij keybindings"
- "zellij vs tmux"
- "what is zellij"
- "zellij plugin development"
- "zellij config file location"
- "update zellij to latest version"
- "compile zellij from source"
- "zellij keyboard shortcuts"
- "zellij color scheme"

**Step 2: Commit**

```bash
git add zellij-workflow/skills/zellij/TRIGGER_EXAMPLES.md
git commit -m "Add zellij TRIGGER_EXAMPLES.md: 54+ examples across 7 domains"
```

---

### Task 4: Run quality check and bump version

**Files:**
- Modify: `zellij-workflow/.claude-plugin/plugin.json` (version 1.4.3 -> 2.0.0)

**Step 1: Run skill quality review**

```bash
./scripts/review_skill_triggers.sh zellij-workflow/zellij
```

Expected: score >= 75/100. If below, fix description/examples and re-run.

**Step 2: Bump version**

In `plugin.json`, change `"version": "1.4.3"` to `"version": "2.0.0"`.

Major bump: skill renamed, restructured, breaking changes.

**Step 3: Commit**

```bash
git add zellij-workflow/.claude-plugin/plugin.json
git commit -m "Update zellij-workflow: bump version to 2.0.0 for skill expansion"
```

---

### Task 5: Smoke test

**Step 1: Reinstall plugin**

```bash
make reinstall-plugin PLUGIN=zellij-workflow
```

**Step 2: Verify in new Claude session**

Test these 8 queries (one per domain + one extra for tabs):
1. "list zellij sessions" -> expects `zellij list-sessions` (Sessions)
2. "open new tab with npm test" -> expects `new-tab --name "npm-test" -- npm test` (Tabs: Create)
3. "go to tab api" -> expects `go-to-tab-name api` (Tabs: Navigate)
4. "list all panes as json" -> expects `list-panes --json` (Panes)
5. "toggle floating panes" -> expects `toggle-floating-panes` (Floating)
6. "dump current layout" -> expects `dump-layout` (Layout)
7. "edit src/main.rs at line 42" -> expects `zellij edit src/main.rs -l 42` (Edit)
8. "send ctrl+c to pane terminal_3" -> expects `send-keys -p terminal_3 "Ctrl c"` (I/O)

**Step 3: Fix and commit if needed**

```bash
git add zellij-workflow/
git commit -m "Fix zellij: smoke test corrections"
```

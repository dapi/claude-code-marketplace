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
  - "открой/создай вкладку/панель", "запусти/покажи [команду] в панели/вкладке"
  - "стартани/запусти задачу/issue в панели/вкладке"

  **Empty Tab/Pane**:
  - "open new tab", "create empty pane", "get a new tab"
  - "новая вкладка", "создай панель"

  **Command in Tab/Pane**:
  - "run npm test in new tab", "execute make build in pane"
  - "list files in a new pane", "show output in tab"
  - "запусти тесты в панели", "make deploy в новой вкладке"

  **Claude Session in Tab/Pane**:
  - "execute plan in new tab", "delegate to pane"
  - "run claude with prompt in tab", "launch task in pane"
  - "выполни план в вкладке", "делегируй в панель"

  **Issue Development in Tab/Pane**:
  - "start issue #123 in new tab", "launch issue in pane"
  - "run start-issue in new tab/pane", "create tab for issue #45"
  - "запусти задачу в панели", "стартани issue в вкладке"

  TRIGGERS: new tab, new pane, create tab, create pane, open tab, open pane,
  run in tab, run in pane, execute in tab, execute in pane, launch in tab,
  launch in pane, delegate to tab, delegate to pane, command in tab,
  command in pane, parallel tab, parallel pane, background tab, background pane,
  zellij tab, zellij pane, zellij panel,
  start issue tab, open issue tab, launch issue tab, create tab issue,
  run start-issue tab, run start-issue pane, zellij new tab issue,
  separate tab development, issue development tab, issue development pane,
  work on issue in tab, work on issue in pane, begin issue tab,
  start issue pane, open issue pane, launch issue pane, create pane issue,
  новая вкладка, новая панель, создай вкладку, создай панель,
  открой вкладку, открой панель, запусти в вкладке, запусти в панели,
  выполни в вкладке, выполни в панели, делегируй в вкладку, делегируй в панель,
  параллельная вкладка, параллельная панель, фоновая вкладка,
  запусти задачу в вкладке, запусти задачу в панели,
  стартани issue в вкладке, стартани issue в панели,
  разработка в вкладке, разработка в панели, вкладка для issue, панель для issue
allowed-tools: Bash
---

# Zellij Tab/Pane Skill

Open a tab or pane in zellij -- empty, with a shell command, with a Claude session, or with a GitHub issue.

## Decision Tree

```
Step 1: Container
  "pane"/"panel"/"панель" -> PANE
  "tab"/"вкладка"/default  -> TAB

Step 2: Mode
  nothing to run              -> A (empty)
  shell command               -> B (command)
  Claude prompt/plan/task     -> C (claude session)
  GitHub issue (#N / URL)     -> D (issue dev via start-issue)
```

## Mode A: Empty Tab/Pane

User just wants a new tab or pane, nothing to run.

**Tab name:** user-specified or `shell-HH:MM` (e.g. `shell-14:35`).

### TAB

```bash
timeout 5 zellij action new-tab --name "$TAB_NAME" || {
  _rc=$?
  echo "Command failed. Diagnosing..."
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif [ $_rc -eq 124 ]; then echo "Timed out -- zellij may be hanging"
  else echo "Unknown error (exit code: $_rc)"
  fi
  exit $_rc
}
```

### PANE

```bash
timeout 5 zellij action new-pane || {
  _rc=$?
  echo "Command failed. Diagnosing..."
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif [ $_rc -eq 124 ]; then echo "Timed out -- zellij may be hanging"
  else echo "Unknown error (exit code: $_rc)"
  fi
  exit $_rc
}
```

## Mode B: Command in Tab/Pane

User wants to run a shell command (npm test, make build, etc.) in a new tab or pane.

**Tab name:** derived from command (e.g. `npm-test`, `make-build`). Max 20 chars.

### TAB

```bash
TAB_NAME="<from-command>"

timeout 5 zellij action new-tab --name "$TAB_NAME" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "$CMD
" || {
  _rc=$?
  echo "Command failed. Diagnosing..."
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif [ $_rc -eq 124 ]; then echo "Timed out -- zellij may be hanging"
  else echo "Unknown error (exit code: $_rc)"
  fi
  exit $_rc
}
```

### PANE

```bash
timeout 5 zellij run -- $CMD || {
  _rc=$?
  echo "Command failed. Diagnosing..."
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif [ $_rc -eq 124 ]; then echo "Timed out -- zellij may be hanging"
  else echo "Unknown error (exit code: $_rc)"
  fi
  exit $_rc
}
```

## Mode C: Claude Session in Tab/Pane

User wants an interactive Claude Code session with instructions/plan/task.

**Tab name:** auto-generated from context (1-2 words, max 20 chars):
- Has issue reference -> `#123`
- Has plan file -> `plan-audit`
- General task -> `refactor`, `fix-tests`
- Fallback -> `claude-HH:MM`

### Step 1: Write bash launch script

```bash
SCRIPT=$(mktemp /tmp/claude-tab-XXXXXX.sh)
cat > "$SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
cd '<PROJECT_DIR>'
PROMPT='<escaped prompt -- single quotes escaped as '"'"'>'
clear
echo "Launching claude with prompt: $PROMPT"
echo ""
exec claude --dangerously-skip-permissions "$PROMPT"
SCRIPT_EOF
chmod +x "$SCRIPT"
```

**Why a script instead of inline commands:**
- `write-chars` types into the new tab's shell, which may be fish, bash, or zsh
- Inline bash syntax like `PROMPT=$(cat ...)` breaks in fish
- `bash /tmp/script.sh` works in **any** shell

### Step 2: Launch

#### TAB

```bash
TAB_NAME="<auto-generated>"

timeout 5 zellij action new-tab --name "$TAB_NAME" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "bash '$SCRIPT'
" || {
  _rc=$?
  echo "Command failed. Diagnosing..."
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif [ $_rc -eq 124 ]; then echo "Timed out -- zellij may be hanging"
  elif ! command -v claude &>/dev/null; then echo "claude not found in PATH"
  else echo "Unknown error (exit code: $_rc)"
  fi
  exit $_rc
}
```

#### PANE

```bash
timeout 5 zellij run -- bash "$SCRIPT" || {
  _rc=$?
  echo "Command failed. Diagnosing..."
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif [ $_rc -eq 124 ]; then echo "Timed out -- zellij may be hanging"
  elif ! command -v claude &>/dev/null; then echo "claude not found in PATH"
  else echo "Unknown error (exit code: $_rc)"
  fi
  exit $_rc
}
```

## Mode D: Issue Development in Tab/Pane

User wants to start development on a GitHub issue. Recognized when request contains an issue reference (number, #number, or GitHub URL).

**Tab name:** always `#NUMBER`.

### Issue Number Parsing

```bash
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
```

### Issue Argument Format

| Format | Example | Result |
|--------|---------|--------|
| Number | `123` | Issue #123 |
| With hash | `#123` | Issue #123 |
| URL | `https://github.com/owner/repo/issues/123` | Issue #123 |

### TAB

```bash
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
```

### PANE

```bash
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
```

## Examples

### Example 1: Empty tab

**User:** "open a new zellij tab"

```bash
timeout 5 zellij action new-tab --name "shell-14:35"
```

### Example 2: Command in pane

**User:** "run npm test in a pane"

```bash
timeout 5 zellij run -- npm test
```

### Example 3: Command in tab

**User:** "run make build in new tab"

```bash
timeout 5 zellij action new-tab --name "make-build" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "make build
"
```

### Example 4: Claude session in tab

**User:** "execute the plan from docs/plans/audit.md in new tab"

```bash
SCRIPT=$(mktemp /tmp/claude-tab-XXXXXX.sh)
cat > "$SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
cd '/home/danil/code/project'
PROMPT='Execute the plan from docs/plans/audit.md. Use superpowers:executing-plans.'
clear
echo "Launching claude with prompt: $PROMPT"
echo ""
exec claude --dangerously-skip-permissions "$PROMPT"
SCRIPT_EOF
chmod +x "$SCRIPT"

timeout 5 zellij action new-tab --name "plan-audit" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "bash '$SCRIPT'
"
```

### Example 5: Delegate to pane

**User:** "delegate this refactoring to a pane"

```bash
SCRIPT=$(mktemp /tmp/claude-tab-XXXXXX.sh)
cat > "$SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
cd '/home/danil/code/project'
PROMPT='Refactor the auth module: extract JWT validation into separate service'
clear
echo "Launching claude with prompt: $PROMPT"
echo ""
exec claude --dangerously-skip-permissions "$PROMPT"
SCRIPT_EOF
chmod +x "$SCRIPT"

timeout 5 zellij run -- bash "$SCRIPT"
```

### Example 6: Issue in tab

**User:** "start issue #45 in a new tab"

```bash
timeout 5 zellij action new-tab --name "#45" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "start-issue 45
"
```

### Example 7: Issue URL in pane

**User:** "start https://github.com/org/repo/issues/123 in a pane"

```bash
timeout 5 zellij run -- start-issue https://github.com/org/repo/issues/123
```

## Dependencies

- **zellij** -- terminal multiplexer (must be running)
- **claude** -- Claude Code CLI (for Mode C only)
- **start-issue** -- issue development command (for Mode D only)

## Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Timed out` | zellij hanging (exit code 124) | Restart zellij |
| `Not in zellij session` | Running outside zellij | Start zellij first |
| `claude not found` | Claude CLI not in PATH | Install Claude Code |
| `start-issue not found` | start-issue not in PATH | Install or add to PATH |
| `Invalid issue format` | Bad argument | Use number, #number, or URL |
| Script not created | /tmp not writable | Check disk space |

## Important

- Skill works **only inside zellij session**
- `sleep 0.3` is required between `new-tab` and `write-chars` (race condition)
- For Mode C, session is **interactive** (not -p print mode) -- remains a working chat

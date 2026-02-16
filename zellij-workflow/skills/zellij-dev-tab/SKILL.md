---
name: zellij-dev-tab
description: |
  **UNIVERSAL TRIGGER**: START/OPEN/LAUNCH issue development IN separate zellij TAB or PANE.

  Common patterns:
  - "start/open/launch [issue] in new tab/pane"
  - "get/show/display issue in zellij tab/panel"
  - "запусти/открой/создай [issue] в вкладке/панели"

  **Start Development**:
  - "start development in separate tab/pane"
  - "launch issue #123 in new zellij tab"
  - "check out issue in new tab/pane", "fetch issue to tab"
  - "запусти разработку в отдельной вкладке/панели"

  **Create/Open Tab**:
  - "create tab for issue #45"
  - "open new tab/pane for issue", "list and start issue in tab"
  - "создай вкладку/панель для задачи"

  **Retrieve & Run**:
  - "retrieve issue #N and start in tab/pane"
  - "run start-issue in new tab", "analyze issue in tab"
  - "start-issue в отдельной вкладке/панели"

  TRIGGERS: start issue tab, open issue tab, launch issue tab, create tab issue,
  run start-issue tab, zellij new tab issue, separate tab development, new tab issue,
  development in tab, issue development tab, work on issue in tab, begin issue tab,
  start issue pane, open issue pane, launch issue pane, create pane issue,
  run start-issue pane, issue development pane, work on issue in pane,
  запусти в вкладке, открой в вкладке, создай вкладку issue, новая вкладка задача,
  разработка в вкладке, вкладка для issue, отдельная вкладка issue, zellij вкладка,
  запусти в панели, открой в панели, создай панель issue, новая панель задача,
  разработка в панели, панель для issue, отдельная панель issue, zellij панель
allowed-tools: Bash
---

# Zellij Dev Tab Skill

Launch `start-issue` for a GitHub issue in a separate zellij tab or pane.

## Issue Argument Format

| Format | Example | Result |
|--------|---------|--------|
| Number | `123` | Issue #123 |
| With hash | `#123` | Issue #123 |
| URL | `https://github.com/owner/repo/issues/123` | Issue #123 |

## Issue Number Parsing

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

## Decision: Tab or Pane

```
"pane"/"panel"/"панель" -> PANE
"tab"/"вкладка"/default  -> TAB
```

Follows the same container selection pattern as `zellij-tab-pane` skill.

## TAB Flow

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

## PANE Flow

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

### Example 1: Issue number in tab

**User:** "Start issue 45 in a new tab"

```bash
timeout 5 zellij action new-tab --name "#45" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "start-issue 45
"
```

### Example 2: URL in tab

**User:** "Open https://github.com/dapi/project/issues/123 in new tab"

```bash
timeout 5 zellij action new-tab --name "#123" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "start-issue https://github.com/dapi/project/issues/123
"
```

### Example 3: Issue in pane

**User:** "Start issue #78 in a pane"

```bash
timeout 5 zellij run -- start-issue 78
```

### Example 4: Hash format in tab

**User:** "Create tab for #99"

```bash
timeout 5 zellij action new-tab --name "#99" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "start-issue 99
"
```

## Dependencies

- **zellij** -- terminal multiplexer (must be running)
- **start-issue** -- script/command for issue development (must be in PATH)

## Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Timed out` | zellij hanging (exit code 124) | Restart zellij |
| `Not in zellij session` | Running outside zellij | Start zellij first |
| `start-issue not found` | start-issue not in PATH | Install or add to PATH |
| `Invalid issue format` | Bad argument | Use number, #number, or URL |

## Important

- Skill works **only inside zellij session**
- `sleep 0.3` is required between `new-tab` and `write-chars` (race condition)
- Tab name is always `#NUMBER` for consistency
- For general-purpose tabs/panes (empty, command, Claude session) use `zellij-tab-pane` skill

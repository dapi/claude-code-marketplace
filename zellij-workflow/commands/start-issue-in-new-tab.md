---
description: Start issue development in new zellij tab with start-issue
argument-hint: <issue-number-or-url>
version: 1.0.0
---

# Start Issue in New Tab

Launch issue development in a new zellij tab or pane.

## Input

- **ISSUE**: `$ARGUMENTS` -- issue number, #number, or full GitHub URL

## Steps

### 1. Parse issue number

```bash
parse_issue_number() {
  local arg="$1"

  # URL: https://github.com/.../issues/123
  if [[ "$arg" =~ github\.com/.*/issues/([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  # #123 or 123
  elif [[ "$arg" =~ ^#?([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

ISSUE_NUMBER=$(parse_issue_number "$ARGUMENTS")
```

### 2. Create tab and launch start-issue

**In a new tab (default):**

```bash
timeout 5 zellij action new-tab --name "#${ISSUE_NUMBER}" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "start-issue $ARGUMENTS
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

**In a new pane:**

```bash
timeout 5 zellij run -- start-issue $ARGUMENTS || {
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

```bash
/start-issue-in-new-tab 123
/start-issue-in-new-tab #45
/start-issue-in-new-tab https://github.com/owner/repo/issues/78
```

## Result

- New zellij tab created with name `#123`
- `start-issue` runs and:
  - Creates git worktree
  - Renames tab
  - Launches Claude Code session

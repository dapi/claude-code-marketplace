# Design: Merge zellij-tab-pane + zellij-dev-tab into one skill

**Date**: 2026-02-16
**Status**: Approved

## Problem

Two separate skills (`zellij-tab-pane` and `zellij-dev-tab`) handle zellij tab/pane creation. LLM sometimes picks the wrong one (e.g. user says "panel" but `zellij-dev-tab` triggers because it mentions "issue"). One unified skill eliminates this ambiguity.

## Decision

**Approach A**: Add Mode D (issue development) to `zellij-tab-pane`, delete `zellij-dev-tab`.

## Unified Decision Tree

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

## Mode D: Issue Development

Recognized when request contains an issue reference (number, #number, or GitHub URL).

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

### TAB Flow

```bash
ISSUE_NUMBER=$(parse_issue_number "$ARG")

timeout 5 zellij action new-tab --name "#${ISSUE_NUMBER}" && \
sleep 0.3 && \
timeout 5 zellij action write-chars "start-issue $ARG
"
```

### PANE Flow

```bash
timeout 5 zellij run -- start-issue $ARG
```

### Tab name

Always `#NUMBER` for consistency.

## Changes

| Action | Path |
|--------|------|
| DELETE | `skills/zellij-dev-tab/` (entire directory) |
| MODIFY | `skills/zellij-tab-pane/SKILL.md` (add Mode D + merged triggers) |
| NO CHANGE | `commands/start-issue-in-new-tab.md` |
| NO CHANGE | `commands/run-in-new-tab.md` |

## Triggers

Merge trigger keywords from both skills into unified description. Add issue-specific patterns:
- "start/open/launch [issue] in new tab/pane"
- "start-issue in tab/pane"
- "issue #N in tab/pane"
- Russian equivalents

## Dependencies

- **zellij** -- terminal multiplexer (must be running)
- **claude** -- Claude Code CLI (for Mode C only)
- **start-issue** -- issue development command (for Mode D only)

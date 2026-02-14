# zellij-tab-claude-status: Fix Working Status Not Clearing

**Date:** 2026-02-13

## Problem

Status "working" (🤖) is set but never cleared when Claude finishes responding.

## Root Cause

- `on-stop.sh` runs `--clear` instead of setting 🟢
- `SessionEnd` hook not configured (needed for actual session exit)

## Solution

### Status Icons

| Icon | State | When |
|------|-------|------|
| 🟢 | Ready | Claude idle, waiting for input |
| 🤖 | Working | Claude processing |
| ✋ | Needs input | Permission prompt or question |

### Event → Action Mapping

| Event | Action |
|-------|--------|
| SessionStart | 🟢 + reset counter |
| UserPromptSubmit | 🤖 |
| SubagentStart | +1 counter |
| SubagentStop | -1 counter |
| Stop | 🟢 (was: --clear) |
| Notification (permission) | ✋ |
| SessionEnd | --clear (new) |

## Changes

1. **hooks/on-stop.sh** — change `--clear` to `🟢`
2. **hooks/on-session-end.sh** — create with `--clear`
3. **hooks/hooks.json** — add SessionEnd hook

## Verification

1. Start Claude Code in zellij → 🟢
2. Submit prompt → 🤖
3. Wait for response → 🟢
4. Exit session → icon cleared

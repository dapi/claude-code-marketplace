# Claude Code Hooks Reference

Developer reference for all Claude Code hook events. Use when developing or modifying plugin hooks (especially zellij-workflow).

**Last verified**: 2026-02-23 | **Source**: https://docs.anthropic.com/en/docs/claude-code/hooks

## All Hook Events (17)

### Session Lifecycle

| Event | Matcher filters by | When fires | Can block? | Hook types |
|-|-|-|-|-|
| SessionStart | start method: `startup`, `resume`, `clear`, `compact` | Session launches | No | command |
| SessionEnd | reason: `clear`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other` | Session closes | No | command |
| PreCompact | trigger: `manual`, `auto` | Before context compaction | No | command |
| ConfigChange | source: `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` | Config file changed | Yes (except policy) | command |

### User Interaction

| Event | Matcher filters by | When fires | Can block? | Hook types |
|-|-|-|-|-|
| UserPromptSubmit | ignored (always fires) | User sends a prompt | Yes (exit 2 / decision: block) | command, prompt |
| PermissionRequest | tool name | Permission dialog shown | Yes (allow/deny) | command |
| Notification | type: `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` | Notification to user | No | command |

### Tool Execution

| Event | Matcher filters by | When fires | Can block? | Hook types |
|-|-|-|-|-|
| PreToolUse | tool name: `Bash`, `Edit`, `Write`, `mcp__.*`, etc. | Before tool call | Yes (permissionDecision: deny) | command, prompt |
| PostToolUse | tool name | After successful tool call | No (tool already ran) | command, prompt |
| PostToolUseFailure | tool name | After failed tool call | No | command |

### Agent Lifecycle

| Event | Matcher filters by | When fires | Can block? | Hook types |
|-|-|-|-|-|
| Stop | ignored (always fires) | Main agent stopping | Yes (decision: block) | command, prompt |
| SubagentStart | agent type: `Bash`, `Explore`, `Plan`, custom | Subagent spawned via Task | No (can inject context) | command |
| SubagentStop | agent type | Subagent finishing | Yes (decision: block) | command, prompt |

### Team Collaboration

| Event | Matcher filters by | When fires | Can block? | Hook types |
|-|-|-|-|-|
| TeammateIdle | ignored | Teammate went idle | Yes (exit 2) | command |
| TaskCompleted | ignored | Task marked completed | Yes (exit 2) | command |

### Worktree Management

| Event | Matcher filters by | When fires | Can block? | Hook types |
|-|-|-|-|-|
| WorktreeCreate | ignored | Git worktree created | Yes (non-zero exit) | command |
| WorktreeRemove | ignored | Git worktree removed | No | command |

## Matcher Behavior

### Empty `""` vs `"*"` vs omitted

All three behave **identically** -- match all events of that type:

> Use `"*"`, `""`, or omit `matcher` entirely to match all occurrences.

### Regex syntax

Matchers use **regex**, not glob:
- `Edit|Write` -- matches Edit OR Write
- `mcp__memory__.*` -- matches all memory server tools
- `Bash` -- exact match for Bash tool
- Case-sensitive

### Events that ignore matcher

These events always fire regardless of matcher value:
`UserPromptSubmit`, `Stop`, `TeammateIdle`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`

## Hook Types

| Type | Description | Available in |
|-|-|-|
| `command` | Execute bash command | All 17 events |
| `prompt` | LLM-driven evaluation | UserPromptSubmit, PreToolUse, PostToolUse, Stop, SubagentStop |
| `agent` | Subagent with tools | Same as prompt |

## Hook Output Format

### Standard output (all hooks)

```json
{
  "continue": true,
  "suppressOutput": false,
  "systemMessage": "Message for Claude"
}
```

### PreToolUse specific

```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow|deny|ask",
    "updatedInput": {"field": "modified_value"}
  }
}
```

### Stop/SubagentStop specific

```json
{
  "decision": "approve|block",
  "reason": "Explanation"
}
```

### Exit codes

- `0` -- success (stdout shown in transcript)
- `2` -- blocking error (stderr fed back to Claude)
- Other -- non-blocking error

## Hook Input (stdin JSON)

Common fields for all events:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.txt",
  "cwd": "/current/working/dir",
  "permission_mode": "ask|allow",
  "hook_event_name": "PreToolUse"
}
```

Event-specific additions:
- **PreToolUse/PostToolUse**: `tool_name`, `tool_input`, `tool_result`
- **UserPromptSubmit**: `user_prompt`
- **Stop/SubagentStop**: `reason`
- **Notification**: notification type in matcher
- **SessionStart**: start method in matcher
- **SessionEnd**: end reason in matcher

## Environment Variables

Available in command hooks:
- `$CLAUDE_PROJECT_DIR` -- project root
- `$CLAUDE_PLUGIN_ROOT` -- plugin directory (use for portable paths)
- `$CLAUDE_ENV_FILE` -- SessionStart only: persist env vars here
- `$CLAUDE_CODE_REMOTE` -- set if running remotely

## Notification Types Reference

| Type | When | Typical use |
|-|-|-|
| `permission_prompt` | ~6 sec after permission dialog shown | Late duplicate of PermissionRequest; not useful for status |
| `idle_prompt` | Session idle, awaiting input | Show "ready" status |
| `elicitation_dialog` | AskUserQuestion dialog shown | Show "needs input" status |
| `auth_success` | Authentication completed | Logging |

## zellij-workflow State Machine

Target states for tab status indicator:

| Symbol | Meaning | Unicode |
|-|-|-|
| ○ | Ready / idle | U+25CB |
| ◉ | Working / active | U+25C9 |
| ✋ | Needs user input | U+270B |
| ◌ | Compacting context | U+25CC |

### State transitions

```
SessionStart(startup|clear) ──> ○ (ready)
SessionStart(resume|compact) ──> ◉ (active)
UserPromptSubmit ──────────────> ◉ (working)
SubagentStart ─────────────────> ◉ (working)
PostToolUse(*) ────────────────> ◉ (working, catches permission-grant recovery)
PostToolUseFailure(*) ─────────> ◉ (still working)
SubagentStop ──────────────────> ◉ (main agent continues)
PermissionRequest ─────────────> ✋ (waiting for user)
Notification(elicitation_dialog) > ✋ (waiting for user)
PreCompact ────────────────────> ◌ (compacting)
Stop ──────────────────────────> ○ (done)
Notification(idle_prompt) ─────> ○ (idle)
SessionEnd(clear) ─────────────> ○ (cleared)
SessionEnd(logout|...) ────────> --clear (remove status)
```

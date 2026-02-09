# zellij-claude-status

Zellij tab status indicator for Claude Code sessions.

## Features

Shows Claude session state directly in Zellij UI:

- **Tab name prefix**: Icon indicating current state
  - 🟢 Ready — waiting for input
  - 🤖 Working — processing request
  - ✋ Needs input — permission prompt waiting

- **Session name suffix**: Active subagent counter
  - `my-session (3)` — 3 subagents running

## Installation

```bash
/plugin install zellij-claude-status@dapi
```

## Requirements

- Zellij terminal multiplexer
- Claude Code with plugin support

## How it works

The plugin uses Claude Code hooks to track session state:

| Event | Action |
|-------|--------|
| SessionStart | Reset counter, show 🟢 |
| UserPromptSubmit | Show 🤖 (working) |
| SubagentStart | Increment counter |
| SubagentStop | Decrement counter |
| Notification (permission) | Show ✋ (needs input) |
| Stop | Show 🟢 (ready) |

## Temporary files

The plugin stores state in `/tmp/zellij-claude-*` files:
- `zellij-claude-tab-{session}-{pane}` — original tab name
- `zellij-claude-agents-{session}` — agent counter
- `zellij-claude-session-{session}` — original session name

Files older than 1 day are automatically cleaned up on session start.

## Troubleshooting

**Icons not showing**: Ensure you're running inside Zellij (`$ZELLIJ_SESSION_NAME` must be set).

**Counter stuck**: Run `/plugin reinstall zellij-claude-status@dapi` to reset state.

## License

MIT

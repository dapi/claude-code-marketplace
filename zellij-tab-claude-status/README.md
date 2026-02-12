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

## Requirements

- Zellij terminal multiplexer
- Claude Code with plugin support
- Rust with `wasm32-wasip1` target (for building dependency)

## Installation

### Quick Install (recommended)

```bash
# Clone and install everything
git clone https://github.com/dapi/claude-code-marketplace
cd claude-code-marketplace/zellij-tab-claude-status
make all
```

This will:
1. Clone and build [zellij-tab-status](https://github.com/dapi/zellij-tab-status) Zellij plugin
2. Install Claude Code plugin

### Manual Install

**Step 1: Install Zellij plugin dependency**

```bash
# Requires Rust with wasm32-wasip1 target
rustup target add wasm32-wasip1

git clone https://github.com/dapi/zellij-tab-status /tmp/zellij-tab-status
cd /tmp/zellij-tab-status
make install
```

Add to `~/.config/zellij/config.kdl`:

```kdl
load_plugins {
    "file:~/.config/zellij/plugins/zellij-tab-status.wasm"
}
```

Restart Zellij.

**Step 2: Install Claude Code plugin**

```bash
/plugin install zellij-tab-claude-status@dapi
```

## How it works

The plugin uses Claude Code hooks to track session state:

| Event | Action |
|-------|--------|
| SessionStart | Reset counter, show 🟢 |
| UserPromptSubmit | Show 🤖 (working) |
| SubagentStart | Increment counter |
| SubagentStop | Decrement counter |
| Notification (permission) | Show ✋ (needs input) |
| Stop | Remove icon, restore original tab name |

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

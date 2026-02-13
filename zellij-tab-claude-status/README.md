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

### Step 1: Install Zellij plugin dependency

```bash
# From marketplace root
git clone https://github.com/dapi/claude-code-marketplace
cd claude-code-marketplace
make install-zellij-tab-status
```

This installs:
- Zellij WASM plugin (`~/.config/zellij/plugins/zellij-tab-status.wasm`)
- CLI scripts (`~/.local/bin/zellij-tab-status`, `~/.local/bin/zellij-rename-tab`)

Or manually from [zellij-tab-status](https://github.com/dapi/zellij-tab-status) repository.

Add to `~/.config/zellij/config.kdl`:

```kdl
load_plugins {
    "file:~/.config/zellij/plugins/zellij-tab-status.wasm"
}
```

Restart Zellij.

### Step 2: Install Claude Code plugin

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
| Stop | Show 🟢 (ready) |
| Notification (permission) | Show ✋ (needs input) |
| SessionEnd | Remove icon, restore original tab name |

## Temporary files

The plugin stores agent counter state in `/tmp/zellij-claude-*` files:
- `zellij-claude-agents-{session}` — agent counter
- `zellij-claude-session-{session}` — original session name

Tab status (emoji prefix) is managed atomically by the zellij-tab-status WASM plugin.

## Troubleshooting

**Icons not showing**: Ensure you're running inside Zellij (`$ZELLIJ_SESSION_NAME` must be set).

**Counter stuck**: Run `/plugin reinstall zellij-claude-status@dapi` to reset state.

## License

MIT

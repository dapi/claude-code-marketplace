# zellij-tab-claude-status

Zellij tab status indicator for Claude Code sessions.

## Features

Shows Claude session state directly in Zellij tab:

- 🤖 Working — processing request
- 🟢 Ready — waiting for input
- ✋ Needs input — permission prompt waiting

## Requirements

- Zellij terminal multiplexer
- Claude Code with plugin support
- [zellij-tab-status](https://github.com/dapi/zellij-tab-status) plugin

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
- CLI script (`~/.local/bin/zellij-tab-status`)

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

The plugin uses Claude Code hooks to update tab status:

| Event | Script | Status |
|-------|--------|--------|
| SessionStart | on-session-start.sh | 🟢 |
| UserPromptSubmit | on-prompt-submit.sh | 🤖 |
| Notification (permission) | on-permission-prompt.sh | ✋ |
| Stop | on-stop.sh | 🟢 |
| SessionEnd | on-session-end.sh | --clear |

## Troubleshooting

**Icons not showing**: Ensure you're running inside Zellij and `zellij-tab-status` command is available.

```bash
which zellij-tab-status
zellij-tab-status 🔥  # test manually
```

## License

MIT

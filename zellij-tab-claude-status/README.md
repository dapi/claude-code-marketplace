# zellij-tab-claude-status

Zellij tab status indicator — shows Claude session state via icon prefix in tab name.

## Installation

### Step 1: Install Zellij plugin dependency

Install [zellij-tab-status](https://github.com/dapi/zellij-tab-status):

```bash
# From marketplace root
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

## Status Icons

| Icon | State | Description |
|------|-------|-------------|
| `◉` | Working | Processing request |
| `○` | Ready | Waiting for input |
| `✋` | Needs input | Permission prompt waiting |

## How It Works

The plugin uses Claude Code hooks to update tab status:

| Event | Status |
|-------|--------|
| SessionStart | `○` |
| UserPromptSubmit | `◉` |
| Notification (permission/elicitation) | `✋` |
| Notification (idle_prompt) | `○` |
| Stop | `○` |
| SessionEnd | --clear |

## Requirements

- [Zellij](https://zellij.dev) terminal multiplexer
- [zellij-tab-status](https://github.com/dapi/zellij-tab-status) plugin

## Troubleshooting

**Icons not showing**: Ensure you're running inside Zellij and `zellij-tab-status` command is available.

```bash
which zellij-tab-status
zellij-tab-status test  # test manually
```

## License

MIT

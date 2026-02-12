# zellij-tab-rename

Minimal Zellij plugin to rename tabs by pane_id. Created for Claude Code status indicator.

## Build

Requires Rust with wasm32-wasip1 target:

```bash
rustup target add wasm32-wasip1
make build
```

## Install

```bash
make install
```

Add to `~/.config/zellij/config.kdl`:

```kdl
load_plugins {
    "file:~/.config/zellij/plugins/zellij-tab-rename.wasm"
}
```

Restart zellij session.

## Usage

### Rename tab

```bash
# Rename tab containing pane
zellij pipe --name tab-rename -- '{"pane_id": "'$ZELLIJ_PANE_ID'", "name": "🤖 Working"}'
```

### Status emoji management

The `tab-status` pipe manages emoji status atomically (avoids race conditions):

```bash
# Set status emoji: "Working" -> "🤖 Working"
zellij pipe --name tab-status -- '{"pane_id": "'$ZELLIJ_PANE_ID'", "action": "set_status", "emoji": "🤖"}'

# Replace status: "🤖 Working" -> "⏳ Working"
zellij pipe --name tab-status -- '{"pane_id": "'$ZELLIJ_PANE_ID'", "action": "set_status", "emoji": "⏳"}'

# Clear status: "🤖 Working" -> "Working"
zellij pipe --name tab-status -- '{"pane_id": "'$ZELLIJ_PANE_ID'", "action": "clear_status"}'
```

**Status format:** First character + space = status. `"🤖 Working"` → status: `🤖`, base name: `Working`

### Wrapper script

Use `scripts/zellij-tab-status` for convenience:

```bash
zellij-tab-status 🤖           # Set status
zellij-tab-status --clear      # Remove status
zellij-tab-status              # Get current status emoji
zellij-tab-status --name       # Get base name (without status)
```

## Debug

Check logs:

```bash
tail -f /tmp/zellij-1000/zellij-log/zellij.log | grep tab-rename
```

## License

MIT

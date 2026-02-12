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

```bash
# Rename tab containing pane
zellij pipe --name tab-rename -- '{"pane_id": "'$ZELLIJ_PANE_ID'", "name": "🤖 Working"}'
```

## Debug

Check logs:

```bash
tail -f /tmp/zellij-1000/zellij-log/zellij.log | grep tab-rename
```

## License

MIT

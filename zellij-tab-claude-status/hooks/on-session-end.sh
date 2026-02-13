#!/usr/bin/env bash
# Clear tab status
[ -z "$ZELLIJ" ] && exit 0
PLUGIN="file:$HOME/.config/zellij/plugins/zellij-tab-status.wasm"
PAYLOAD="{\"pane_id\": \"$ZELLIJ_PANE_ID\", \"action\": \"clear_status\"}"
zellij pipe --plugin "$PLUGIN" --name tab-status -- "$PAYLOAD" &

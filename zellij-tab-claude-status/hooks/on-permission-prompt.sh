#!/usr/bin/env bash
# Set tab status to ✋ (needs input)
[ -z "$ZELLIJ" ] && exit 0
PLUGIN="file:$HOME/.config/zellij/plugins/zellij-tab-status.wasm"
PAYLOAD="{\"pane_id\": \"$ZELLIJ_PANE_ID\", \"action\": \"set_status\", \"emoji\": \"✋\"}"
zellij pipe --plugin "$PLUGIN" --name tab-status -- "$PAYLOAD" &

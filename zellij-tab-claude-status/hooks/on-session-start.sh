#!/usr/bin/env bash

# Small delay to ensure tab has focus
sleep 0.3

TAB=$(zellij action dump-layout 2>/dev/null | grep -oP 'tab name="\K[^"]+(?=".*focus=true)' | head -1)
# Strip existing icon
TAB=$(echo "$TAB" | sed -E 's/^(🤖|✋|🟢) //')

[ -n "$TAB" ] && [ -n "$ZELLIJ_PANE_ID" ] && \
  zellij pipe --name claude-tab-rename -- "{\"pane_id\": \"$ZELLIJ_PANE_ID\", \"name\": \"🤖 $TAB\"}"

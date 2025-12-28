#!/usr/bin/env bash
mise trust
git submodule init
git submodule update

# Copy .envrc from main/master worktree
BASE_DIR=$(git worktree list | grep -E '\[(main|master)\]' | head -1 | awk '{print $1}')
if [ -n "$BASE_DIR" ] && [ -f "$BASE_DIR/.envrc" ]; then
  cp "$BASE_DIR/.envrc" .envrc
  echo "Copied .envrc from $BASE_DIR"
else
  echo "Warning: Could not find .envrc in main/master worktree"
fi

direnv allow

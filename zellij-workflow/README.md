# zellij-workflow

Unified Zellij workflow plugin: tab status indicators, issue development tabs, and Claude session tabs.

## Features

### Tab Status Indicators

Automatically shows Claude session state via icon prefix in tab name:

| Icon | State | Description |
|------|-------|-------------|
| `○` | Ready | Waiting for input |
| `◉` | Working | Processing request |
| `✋` | Needs input | Permission prompt waiting |

Requires [zellij-tab-status](https://github.com/dapi/zellij-tab-status) plugin.

### Issue Development Tabs

Launch `start-issue` in a new zellij tab:

```
/start-issue-in-new-tab 123
/start-issue-in-new-tab #45
/start-issue-in-new-tab https://github.com/owner/repo/issues/78
```

Or say: "Start issue #123 in a new tab"

### Claude Session Tabs

Launch interactive Claude Code session with arbitrary instructions:

```
/run-in-new-tab Execute plan from docs/plans/audit-plan.md. Use executing-plans.
/run-in-new-tab Refactor the auth module
```

Or say:
- "Execute the plan in a new zellij tab"
- "Выполни план в новой вкладке"
- "Delegate this to a new tab"

## Installation

### Step 1: Install zellij-tab-status dependency (optional, for status icons)

Install [zellij-tab-status](https://github.com/dapi/zellij-tab-status):

```bash
make install-zellij-tab-status
```

Add to `~/.config/zellij/config.kdl`:

```kdl
load_plugins {
    "file:~/.config/zellij/plugins/zellij-tab-status.wasm"
}
```

### Step 2: Install plugin

```bash
/plugin install zellij-workflow@dapi
```

## Requirements

- [Zellij](https://zellij.dev) terminal multiplexer
- [zellij-tab-status](https://github.com/dapi/zellij-tab-status) (optional, for status icons)
- `start-issue` in PATH (for issue development tabs)
- `claude` CLI in PATH (for Claude session tabs)

## Components

| Component | File | Purpose |
|-----------|------|---------|
| Hooks | [hooks/hooks.json](./hooks/hooks.json) | Tab status indicators |
| Skill | [skills/zellij-dev-tab/SKILL.md](./skills/zellij-dev-tab/SKILL.md) | Issue development in tab |
| Skill | [skills/zellij-claude-tab/SKILL.md](./skills/zellij-claude-tab/SKILL.md) | Claude session in tab |
| Command | [commands/start-issue-in-new-tab.md](./commands/start-issue-in-new-tab.md) | `/start-issue-in-new-tab` |
| Command | [commands/run-in-new-tab.md](./commands/run-in-new-tab.md) | `/run-in-new-tab` |

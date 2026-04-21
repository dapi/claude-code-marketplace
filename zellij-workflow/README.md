# zellij-workflow

Unified Zellij workflow plugin: tab status indicators, issue development tabs, and general-purpose tabs/panes.

## Features

### Tab Status Indicators

Automatically shows Claude session state via icon prefix in tab name:

| Icon | State | Description |
|-|-|-|
| `○` | Ready | Waiting for input |
| `◉` | Working | Processing request |
| `✋` | Needs input | Permission prompt waiting |
| `◌` | Compacting | Context compaction in progress |

Requires the [zellij-tab-status](https://github.com/dapi/zellij-tab-status) CLI binary.

### Issue Development Tabs

Launch `start-issue` in a new zellij tab or pane:

```
/start-issue-in-new-tab 123
/start-issue-in-new-tab #45
/start-issue-in-new-tab https://github.com/owner/repo/issues/78
```

Or say: "Start issue #123 in a new tab" or "Start issue #45 in a pane"

### General-Purpose Tabs/Panes

Open tabs and panes for any purpose -- empty, with a shell command, or with a Claude session:

```
/run-in-new-tab Execute plan from docs/plans/audit-plan.md. Use executing-plans.
/run-in-new-tab Refactor the auth module
```

Or say:
- "Open a new tab" / "Create a pane"
- "Run npm test in a pane"
- "Execute the plan in a new zellij tab"
- "Delegate this to a pane"

## Installation

### Step 1: Install zellij-tab-status dependency (optional, for status icons)

Install the [zellij-tab-status](https://github.com/dapi/zellij-tab-status) CLI binary:

```bash
make install-zellij-tab-status
```

No `config.kdl` or `load_plugins` entry is needed. Current `zellij-tab-status`
is a native CLI tool, not a WASM plugin.

### Step 2: Install plugin

```bash
/plugin install zellij-workflow@dapi
```

## Requirements

- [Zellij](https://zellij.dev) 0.44.0+ terminal multiplexer
- [zellij-tab-status](https://github.com/dapi/zellij-tab-status) CLI in PATH (optional, for status icons)
- [`start-issue`](https://github.com/dapi/start-issue) in PATH (for issue development tabs)
- `claude` CLI in PATH (for Claude session tabs)

### Plugin Dependencies

| Plugin | Used by | Purpose |
|--------|---------|---------|
| **superpowers** | `/run-in-new-tab`, zellij-tab-pane skill | Skill `executing-plans` for plan execution in new tabs |

## Troubleshooting

| Problem | Cause | Fix |
|-|-|-|
| No status icons on tabs | zellij-tab-status CLI not installed or not in PATH | Run `make install-zellij-tab-status`; make sure `~/.local/bin` is in PATH |
| `zellij-tab-status` command not found | Binary not in PATH | Add `~/.local/bin` to PATH and restart Claude |
| zellij-tab-status exits with `list-panes`, `list-tabs`, or `rename-tab-by-id` errors | Zellij is too old or Claude is not running inside Zellij | Use Zellij 0.44.0+ and start Claude inside a Zellij pane |
| Status stuck on `✋` | Rare: PostToolUse didn't fire after permission grant | Switch to tab — any next action will reset to `◉` |
| Status stays `◉` after Claude stops | Stop hook didn't fire | Check zellij-workflow is installed: `/plugin list` |
| Icons show on wrong tab | Old WASM/script version is still active | Remove old `zellij-tab-status.wasm` `load_plugins` config and install the v0.8.1+ CLI |
| `Not in zellij session` error | Running Claude outside zellij | Start zellij first, then run Claude inside it |
| `Timed out` on tab/pane creation | Zellij is hanging or overloaded | Restart zellij session |

## Components

| Component | File | Purpose |
|-----------|------|---------|
| Hooks | [hooks/hooks.json](./hooks/hooks.json) | Tab status indicators |
| Skill | [skills/zellij-tab-pane/SKILL.md](./skills/zellij-tab-pane/SKILL.md) | Tab/pane: empty, command, Claude session, issue dev |
| Command | [commands/start-issue-in-new-tab.md](./commands/start-issue-in-new-tab.md) | `/start-issue-in-new-tab` |
| Command | [commands/run-in-new-tab.md](./commands/run-in-new-tab.md) | `/run-in-new-tab` |

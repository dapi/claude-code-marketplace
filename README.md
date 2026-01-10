# Dapi Claude Code Marketplace

Personal marketplace of Claude Code plugins for development workflows.

## Installation

```bash
# Add marketplace
/plugin marketplace add dapi/claude-code-marketplace

# Install plugin
/plugin install dev-tools@dapi
```

## Dependencies

Some skills require GitHub CLI extensions:

| Extension | Purpose | Install |
|-----------|---------|---------|
| [gh-pmu](https://github.com/rubrical-studios/gh-pmu) | Project management, sub-issues, batch ops | `gh extension install rubrical-studios/gh-pmu` |
| [gh-sub-issue](https://github.com/yahsan2/gh-sub-issue) | Parent-child issue relationships | `gh extension install yahsan2/gh-sub-issue` |

## dev-tools Plugin

### Commands

| Command | Description |
|---------|-------------|
| `/dev-tools:start-issue <url>` | Start work on GitHub issue (creates worktree + branch) |
| `/dev-tools:fix-pr` | Iterative PR review & fix cycle until clean |
| `/dev-tools:requirements <action>` | Manage requirements via Google Spreadsheet |

#### start-issue

```bash
/dev-tools:start-issue https://github.com/owner/repo/issues/123
```

Creates git worktree in `~/worktrees/<type>/<number>-<slug>` with proper branch naming (`feature/`, `fix/`, `chore/`).

#### fix-pr

```bash
/dev-tools:fix-pr                    # up to 5 iterations
/dev-tools:fix-pr --max-iterations=3
```

Runs 4 review agents in parallel (code-reviewer, pr-test-analyzer, silent-failure-hunter, comment-analyzer), fixes critical/important issues, repeats until clean.

**Requires:** `pr-review-toolkit@claude-code-plugins`

#### requirements

```bash
/dev-tools:requirements init    # Create project spreadsheet
/dev-tools:requirements status  # Show summary
/dev-tools:requirements sync    # Sync with GitHub issues
/dev-tools:requirements add "Feature title"
```

### Skills (auto-activate)

| Skill | Triggers |
|-------|----------|
| **bugsnag** | "show bugsnag errors", "list bugsnag projects", "что в bugsnag" |
| **long-running-harness** | "start multi-session project", "continue project work" |

## Development

```bash
make version        # Show current version
make release        # Release minor version (1.3.0 → 1.4.0)
make release-patch  # Release patch (1.3.0 → 1.3.1)
make update         # Update marketplace + plugin
make reinstall      # Full reinstall
```

## Structure

```
claude-code-marketplace/
├── dev-tools/
│   ├── commands/
│   │   ├── fix-pr.md
│   │   ├── requirements.md
│   │   └── start-issue.md
│   ├── skills/
│   │   ├── bugsnag/
│   │   └── long-running-harness/
│   └── README.md
├── Makefile
└── README.md
```

## License

MIT — [Danil Pismenny](https://github.com/dapi)

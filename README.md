# Dapi Claude Code Marketplace

Personal marketplace of Claude Code plugins for development workflows.

## Installation

```bash
# Add marketplace
/plugin marketplace add dapi/claude-code-marketplace

# Install plugins
/plugin install dev-tools@dapi
/plugin install bugsnag-skill@dapi
# etc.
```

## Plugins

| Plugin | Description |
|--------|-------------|
| **dev-tools** | GitHub: issues, PRs, worktrees |
| **zellij-claude-status** | Zellij tab status indicator |
| **bugsnag-skill** | Bugsnag API |
| **spec-reviewer** | Specification review (10 agents) |
| **cluster-efficiency** | Kubernetes cluster analysis (5 agents) |
| **doc-validate** | Documentation validation |
| **media-upload** | S3 media upload |
| **long-running-harness** | Long-running projects |
| **himalaya** | Himalaya CLI (IMAP/SMTP) |
| **requirements** | Requirements in Google Sheets |

## Plugin Details

### dev-tools

GitHub workflow: issues, PRs, worktrees.

**Commands:**
- `/start-issue <url>` — Start work on GitHub issue (creates worktree + branch)
- `/fix-pr` — Iterative PR review & fix cycle

**Skills:**
- `github-issues` — Read/edit issues via `gh` CLI

### zellij-claude-status

Zellij tab status indicator — shows Claude session state via icon prefix.

**Icons:** 🟢 Ready | 🤖 Working | ✋ Needs input

### bugsnag-skill

Bugsnag API integration for error monitoring.

**Triggers:** `show bugsnag errors`, `bugsnag details`, `ошибки bugsnag`

**Requires:** `BUGSNAG_DATA_API_KEY`, `BUGSNAG_PROJECT_ID`

### spec-reviewer

Specification review with 10 specialized agents.

**Command:** `/spec-review path/to/spec.md`

**Agents:** classifier, analyst, api, ux, data, infra, test, scoper, risk, ai-readiness

### cluster-efficiency

Kubernetes cluster efficiency analysis with 5 agents.

**Command:** `/cluster-efficiency`

**Agents:** orchestrator, node-analyzer, workload-analyzer, karpenter-analyzer, oom-analyzer

### doc-validate

Documentation quality validation.

**Command:** `/doc-validate`

**Checks:** broken links, orphan docs, glossary, structure

### media-upload

Upload images/media to S3. Auto-triggers after Playwright screenshots.

**Triggers:** `upload to s3`, `get shareable link`

### long-running-harness

Multi-session project management.

**Triggers:** `init project`, `continue project`, `project status`

### himalaya

Email via [Himalaya CLI](https://github.com/pimalaya/himalaya).

**Triggers:** `check email`, `send email`, `проверить почту`

### requirements

Project requirements via Google Spreadsheet with GitHub issues sync.

**Command:** `/requirements [init|status|sync|add|update]`

## Dependencies

Some plugins require external tools:

| Tool | Plugins | Install |
|------|---------|---------|
| [gh CLI](https://cli.github.com) | dev-tools, requirements | `brew install gh` |
| [Himalaya](https://github.com/pimalaya/himalaya) | himalaya | `brew install himalaya` |
| Ruby 3.0+ | bugsnag-skill, doc-validate | — |

## Scripts

### do-issue

Start work on GitHub issue: creates worktree, renames zellij tab, launches Claude.

```bash
do-issue 123
do-issue https://github.com/owner/repo/issues/123
```

See `scripts/do-issue` for details.

## Development

```bash
make version        # Show current version
make release        # Release minor version
make release-patch  # Release patch
make update-plugin  # Update plugin (after git pull)
make reinstall      # Full reinstall
```

## License

MIT — [Danil Pismenny](https://github.com/dapi)

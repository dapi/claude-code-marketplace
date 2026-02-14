# Dapi Claude Code Marketplace

Personal marketplace of Claude Code plugins for development workflows.

**[Русская версия](README.ru.md)**

## Installation

```bash
# Add marketplace
/plugin marketplace add dapi/claude-code-marketplace

# Install plugins
/plugin install github-workflow@dapi
/plugin install bugsnag-skill@dapi
# etc.
```

## Plugins

| Plugin | Description | Components |
|--------|-------------|------------|
| [bugsnag-skill](#bugsnag-skill) | Bugsnag API integration: errors, organizations, projects | 1 skill |
| [cluster-efficiency](#cluster-efficiency) | Kubernetes cluster efficiency analysis | 5 agents, 1 skill, 1 command |
| [doc-validate](#doc-validate) | Documentation quality validation | 1 skill, 1 command |
| [github-workflow](#github-workflow) | GitHub issues, PRs, worktrees, sub-issues | 1 skill, 2 commands |
| [himalaya](#himalaya) | Email via Himalaya CLI (IMAP/SMTP) | 1 skill |
| [long-running-harness](#long-running-harness) | Multi-session project management | 1 skill |
| [media-upload](#media-upload) | S3 media/image upload | 1 skill |
| [requirements](#requirements) | Requirements registry via Google Sheets | 1 command |
| [spec-reviewer](#spec-reviewer) | Specification review and analysis | 10 agents, 1 skill, 1 command |
| [zellij-dev-tab](#zellij-dev-tab) | GitHub issue dev in separate Zellij tab | 1 skill |
| [zellij-tab-claude-status](#zellij-tab-claude-status) | Claude session status in Zellij tab | hooks |

### github-workflow

GitHub workflow: issues, PRs, worktrees, sub-issues.

**Components:** skill `github-issues`, commands `/start-issue`, `/fix-pr`

```
/start-issue https://github.com/owner/repo/issues/123
"read issue #45"
"create sub-issue for #123"
```

### zellij-dev-tab

Launch GitHub issue development in a separate Zellij tab.

**Components:** skill `zellij-dev-tab`

```
"start issue #45 in new tab"
"запусти разработку в отдельной вкладке"
```

### zellij-tab-claude-status

Zellij tab status indicator — shows Claude session state via icon prefix.
Requires [zellij-tab-status](https://github.com/dapi/zellij-tab-status) plugin.

**Icons:** `◉` Working | `○` Ready | `✋` Needs input

### bugsnag-skill

Bugsnag API integration: view and manage errors, organizations, projects.

**Components:** skill `bugsnag`

**Requires:** `BUGSNAG_DATA_API_KEY`, `BUGSNAG_PROJECT_ID`

```
"show bugsnag errors"
"bugsnag details for error_123"
"ошибки bugsnag"
```

### spec-reviewer

Specification review: analyze specs for gaps, inconsistencies, and scope estimation.

**Components:** command `/spec-review`, 10 agents

**Agents:** classifier, analyst, api, ux, data, infra, test, scoper, risk, ai-readiness

```
/spec-review path/to/spec.md
"проверь спецификацию docs/spec.md"
```

### cluster-efficiency

Kubernetes cluster efficiency analysis: resource utilization, Karpenter, OOM, workloads.

**Components:** command `/cluster-efficiency`, skill `cluster-efficiency`, 5 agents

**Agents:** orchestrator, node-analyzer, workload-analyzer, karpenter-analyzer, oom-analyzer

```
/cluster-efficiency
"проанализируй эффективность кластера"
```

### doc-validate

Documentation quality validation: broken links, orphan docs, glossary, structure.

**Components:** command `/doc-validate`, skill `doc-validate`

```
/doc-validate docs/
"validate docs"
"проверь документацию"
```

### media-upload

Upload images and media files to S3. Auto-triggers after Playwright screenshots.

**Components:** skill `media-upload`

```
"upload image to s3"
"загрузить файл в s3"
```

### long-running-harness

Manage long-running development projects across multiple sessions.

**Components:** skill `long-running-harness`

```
"start new project [description]"
"continue working on [project]"
```

### himalaya

Email via [Himalaya CLI](https://github.com/pimalaya/himalaya) (IMAP/SMTP).

**Components:** skill `himalaya`

```
"check my email"
"send email to user@example.com"
"проверить почту"
```

### requirements

Project requirements registry via Google Spreadsheet with GitHub issues sync.

**Components:** command `/requirements`

```
/requirements init
/requirements status
/requirements sync
```

## Dependencies

Some plugins require external tools:

| Tool | Plugins | Install |
|------|---------|---------|
| [gh CLI](https://cli.github.com) | github-workflow, requirements | `brew install gh` |
| [Himalaya](https://github.com/pimalaya/himalaya) | himalaya | `brew install himalaya` |
| [zellij-tab-status](https://github.com/dapi/zellij-tab-status) | zellij-tab-claude-status | See plugin README |
| Ruby 3.0+ | bugsnag-skill, doc-validate | — |

## Scripts

### start-issue

Start work on GitHub issue: creates worktree, renames zellij tab, launches Claude.

```bash
start-issue 123
start-issue https://github.com/owner/repo/issues/123
```

See `scripts/start-issue` for details.

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

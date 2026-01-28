# Dev Tools

Development tools plugin for Claude Code.

## Features

### Skills

- **email** - Read/send email via [Himalaya](https://github.com/pimalaya/himalaya) CLI
- **github-issues** - Manage GitHub issues via `gh` CLI: read, edit, checkboxes, sub-issues
- **bugsnag** - Fetch data from Bugsnag: organizations, projects, errors, events, comments
- **long-running-harness** - Manage multi-session development projects with progress tracking
- **cluster-efficiency** - Kubernetes cluster resource efficiency analysis (nodes, workloads, Karpenter)

### Commands

- `/dev-tools:start-issue <url>` - Start work on GitHub issue (creates worktree, branch)
- `/dev-tools:fix-pr` - Iterative PR review and fix cycle (requires `pr-review-toolkit` plugin)
- `/dev-tools:requirements` - Manage project requirements via Google Spreadsheet
- `/dev-tools:cluster-efficiency` - Kubernetes cluster resource efficiency analysis

## Installation

### From GitHub
```bash
/plugin marketplace add dapi/claude-code-marketplace
/plugin install dev-tools@dapi
```

### Local Development
```bash
/plugin marketplace add /path/to/claude-code-marketplace
/plugin install dev-tools@dapi
```

## Dependencies

Some skills require external tools:

| Tool | Purpose | Install |
|------|---------|---------|
| [Himalaya](https://github.com/pimalaya/himalaya) | Email CLI client | `cargo install himalaya` or [releases](https://github.com/pimalaya/himalaya/releases) |
| kubectl | Kubernetes CLI | [Install kubectl](https://kubernetes.io/docs/tasks/tools/) |
| Prometheus | Historical metrics (optional) | Available in cluster via port-forward |

Some skills require GitHub CLI extensions:

| Extension | Purpose | Install |
|-----------|---------|---------|
| [gh-sub-issue](https://github.com/yahsan2/gh-sub-issue) | Sub-issue hierarchy | `gh extension install yahsan2/gh-sub-issue` |
| [gh-pmu](https://github.com/rubrical-studios/gh-pmu) | Project management | `gh extension install rubrical-studios/gh-pmu` |

Some commands require additional plugins:

| Command | Dependency | Install |
|---------|------------|---------|
| `/fix-pr` | `pr-review-toolkit` | `/plugin install pr-review-toolkit@claude-code-plugins` |

## Usage

### Start Issue
```bash
/dev-tools:start-issue https://github.com/owner/repo/issues/123
```
Creates:
- Git worktree in `../worktrees/<type>/<number>-<description>`
- Branch named by type: `feature/`, `fix/`, or `chore/`
- Runs `./init.sh` if exists

### Email Skill
Activates when you ask to read or send email:
```
"check my inbox"
"send email to user@example.com"
"проверь мою почту"
"отправь письмо"
```

**Requires:** [Himalaya](https://github.com/pimalaya/himalaya) installed and configured.

### GitHub Issues Skill
Activates automatically when you mention GitHub issue URLs or ask to work with issues:
```
"прочитай https://github.com/owner/repo/issues/123"
"read issue #45"
"отметь пункт 1 как выполненный"
"create sub-issue for #123"
```
Uses `gh` CLI instead of WebFetch. Supports atomic checkbox operations for parallel work.

### Bugsnag Skill
Activates automatically when you ask about Bugsnag data:
```
"show bugsnag errors"
"list bugsnag projects"
"что в bugsnag"
```

### Long-Running Harness Skill
Activates for multi-session project management:
```
"start new multi-session project"
"continue project work"
"продолжить работу над проектом"
```

### Fix PR
Iteratively reviews and fixes PR until no critical issues:
```bash
/dev-tools:fix-pr                    # up to 5 iterations
/dev-tools:fix-pr --max-iterations=3 # up to 3 iterations
```
Runs 4 review agents in parallel, then fixes issues, repeats until clean.

### Requirements
Manage project requirements via Google Spreadsheet:
```bash
/dev-tools:requirements init    # Create spreadsheet for project
/dev-tools:requirements status  # Show requirements summary
/dev-tools:requirements sync    # Sync with GitHub issues
/dev-tools:requirements add "Feature description"
```

### Cluster Efficiency
Analyze Kubernetes cluster resource utilization:
```bash
/dev-tools:cluster-efficiency                          # Basic analysis
/dev-tools:cluster-efficiency --context=production     # Specific cluster
/dev-tools:cluster-efficiency --namespace=app --focus=workloads
/dev-tools:cluster-efficiency --prometheus --period=7d # With historical data
/dev-tools:cluster-efficiency --deep                   # Deep analysis with subagents
/dev-tools:cluster-efficiency --save --compare         # Save and compare reports
```

**Analysis areas:**
- **Nodes** - CPU/memory utilization, over-provisioned nodes
- **Workloads** - Pod resource requests vs actual usage
- **Karpenter** - Consolidation opportunities, NodePool efficiency
- **Cost** - Potential savings from right-sizing

**Efficiency thresholds:**
| Metric | Good | Acceptable | Poor |
|--------|------|------------|------|
| CPU utilization | >70% | 40-70% | <40% |
| Memory utilization | >60% | 40-60% | <40% |
| Requests efficiency | >60% | 30-60% | <30% |

**Requires:** kubectl configured with cluster access. Prometheus optional for historical metrics.

## License

MIT License - see [LICENSE](../LICENSE)

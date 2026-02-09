# GitHub Workflow

GitHub workflow plugin for Claude Code — issues, PRs, worktrees, sub-issues.

## Features

### Skills

- **github-issues** — Manage GitHub issues via `gh` CLI: read, edit, checkboxes, sub-issues

### Commands

- `/github-workflow:start-issue <url>` — Start work on GitHub issue (creates worktree, branch)
- `/github-workflow:fix-pr` — Iterative PR review and fix cycle

## Installation

```bash
/plugin marketplace add dapi/claude-code-marketplace
/plugin install github-workflow@dapi
```

## Dependencies

GitHub CLI extensions (optional but recommended):

| Extension | Purpose | Install |
|-----------|---------|---------|
| [gh-sub-issue](https://github.com/yahsan2/gh-sub-issue) | Sub-issue hierarchy | `gh extension install yahsan2/gh-sub-issue` |

Commands dependency:

| Command | Dependency | Install |
|---------|------------|---------|
| `/fix-pr` | `pr-review-toolkit` | `/plugin install pr-review-toolkit@claude-code-plugins` |

## Usage

### GitHub Issues Skill

Activates automatically when you mention GitHub issue URLs or ask to work with issues:

```
"прочитай https://github.com/owner/repo/issues/123"
"read issue #45"
"отметь пункт 1 как выполненный"
"create sub-issue for #123"
"download images from issue"
```

Uses `gh` CLI instead of WebFetch. Supports atomic checkbox operations for parallel work.

### Start Issue

```bash
/github-workflow:start-issue https://github.com/owner/repo/issues/123
```

Creates:
- Git worktree in `../worktrees/<type>/<number>-<description>`
- Branch named by type: `feature/`, `fix/`, or `chore/`
- Runs `./init.sh` if exists

### Fix PR

Iteratively reviews and fixes PR until no critical issues:

```bash
/github-workflow:fix-pr                    # up to 5 iterations
/github-workflow:fix-pr --max-iterations=3 # up to 3 iterations
```

Runs 4 review agents in parallel, then fixes issues, repeats until clean.

## License

MIT

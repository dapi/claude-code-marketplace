# Dev Tools

Development tools plugin for Claude Code.

## Features

### Skills

- **bugsnag** - Fetch data from Bugsnag: organizations, projects, errors, events, comments
- **long-running-harness** - Manage multi-session development projects with progress tracking

### Commands

- `/dev-tools:start-issue <url>` - Start work on GitHub issue (creates worktree, branch)
- `/dev-tools:fix-pr` - Iterative PR review and fix cycle (requires `pr-review-toolkit` plugin)
- `/dev-tools:requirements` - Manage project requirements via Google Spreadsheet

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

## License

MIT License - see [LICENSE](../LICENSE)

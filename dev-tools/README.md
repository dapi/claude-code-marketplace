# Dev Tools

Development tools plugin for Claude Code.

## Features

### Skills

- **bugsnag** - Fetch data from Bugsnag: organizations, projects, errors, events, comments
- **long-running-harness** - Manage multi-session development projects with progress tracking

### Commands

- `/dev-tools:start-issue <url>` - Start work on GitHub issue (creates worktree, branch)

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

## License

MIT License - see [LICENSE](../LICENSE)

# github-workflow

GitHub workflow plugin for Claude Code — issues, PRs, worktrees, sub-issues.

## Installation

```bash
/plugin install github-workflow@dapi
```

## Components

### Skill: github-issues

Manage GitHub issues via `gh` CLI: read, edit, checkboxes, sub-issues. Activates automatically when you mention GitHub issue URLs.

### Command: /start-issue

Start work on GitHub issue — creates worktree and branch.

```
/start-issue https://github.com/owner/repo/issues/123
```

### Command: /fix-pr

Iterative PR review and fix cycle until no critical issues remain.

```
/fix-pr
/fix-pr --max-iterations=3
```

## Usage

```
"read issue #45"
"прочитай issue #45"
"create sub-issue for #123"
"отметь пункт 1 как выполненный"
"download images from issue"
```

## Requirements

- [gh CLI](https://cli.github.com)
- [gh-sub-issue](https://github.com/yahsan2/gh-sub-issue) extension (optional)
- [pr-review-toolkit](https://github.com/anthropics/claude-code-plugins) plugin (for `/fix-pr`)

## Documentation

See [skills/github-issues/SKILL.md](./skills/github-issues/SKILL.md)

## License

MIT

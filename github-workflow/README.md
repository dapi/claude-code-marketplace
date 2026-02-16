# github-workflow

GitHub workflow plugin for Claude Code — issues, PRs, worktrees, sub-issues.

## Installation

```bash
/plugin install github-workflow@dapi
```

## Components

### Skill: github-issues

Manage GitHub issues via `gh` CLI: read, edit, checkboxes, sub-issues. Activates automatically when you mention GitHub issue URLs.

### Skill: worktree-init-script

Extends `superpowers:using-git-worktrees` -- runs `./init.sh` after worktree creation if the script exists in the project. Replaces standard auto-detect (npm/cargo/etc) with project-specific initialization.

See [templates/init.sh](./templates/init.sh) for a ready-made template.

### Command: /start-issue

Start work on GitHub issue — creates worktree and branch.

```
/start-issue https://github.com/owner/repo/issues/123
```

### Command: /fix-pr

Iterative PR fix loop -- runs parallel checks (code review + local tests + CI) and fixes issues until the PR is clean.

```
/fix-pr
/fix-pr --max-iterations=5
```

**How it works:**
1. Verifies PR exists and working tree is clean
2. Activates a stop-hook loop (Ralph Loop pattern)
3. Each iteration runs 3 parallel checks: code review, local tests, CI
4. If failures found: fix subagent patches code, commits, pushes
5. Loop continues until all checks pass or max iterations reached

**Stop conditions:**
- All three checks pass (review clean + tests green + CI green)
- Max iterations reached (default: 10)
- Stall detected (3 identical failure iterations)

**To cancel:** `rm .claude/fix-pr.local.md`

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

### Plugin Dependencies

| Plugin | Used by | Purpose |
|--------|---------|---------|
| **pr-review-toolkit** | `/fix-pr` | PR review agents (code-reviewer, pr-test-analyzer, silent-failure-hunter, comment-analyzer) |
| **commit-commands** | `/start-issue` | Skill `commit-push-pr` for commit, push and PR creation |
| **superpowers** | plan-to-issue skill | Skill `executing-plans` for plan execution workflow |

## Documentation

See [skills/github-issues/SKILL.md](./skills/github-issues/SKILL.md)

## License

MIT

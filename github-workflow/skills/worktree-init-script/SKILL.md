---
name: worktree-init-script
description: |
  **UNIVERSAL TRIGGER**: Use when creating git worktrees in projects with init.sh - extends using-git-worktrees to run project-specific initialization script after worktree setup.

  **Activation**: Automatic when `using-git-worktrees` is invoked and `init.sh` exists in project root.

  **Setup**: "run init.sh", "initialize worktree", "project setup script"
  **Create**: "create worktree", "set up workspace", "new worktree"
  **Check**: "check init.sh", "verify project setup"

  TRIGGERS: init.sh, worktree init, worktree setup, project setup script,
    run init, initialize worktree, worktree initialization,
    create worktree init, setup worktree project,
    инициализация worktree, запустить init.sh, скрипт инициализации,
    настройка worktree, создать worktree с init
---

# Worktree Init Script

Extends `superpowers:using-git-worktrees` -- after creating a worktree, runs `./init.sh` if the script exists in the project root.

**Core principle:** Project-specific initialization via a single script replaces auto-detect heuristics.

## When to Use

**Automatically activates** when:
- `using-git-worktrees` is invoked
- Project root contains executable `init.sh`

## Integration with using-git-worktrees

**Modifies step "Run Project Setup":**

Instead of auto-detecting by package.json/Cargo.toml:

1. Check for `init.sh`:
   ```bash
   [ -x ./init.sh ] && echo "init.sh found"
   ```

2. If `init.sh` exists and is executable -- run it:
   ```bash
   ./init.sh
   ```

3. If `init.sh` does not exist -- fall back to standard `using-git-worktrees` logic

## Quick Reference

| Situation | Action |
|-----------|--------|
| `init.sh` exists and executable | Run `./init.sh` |
| `init.sh` does not exist | Standard setup (npm/cargo/etc) |
| `init.sh` fails | Report error, ask whether to continue |

## Template

A ready-made template is available at `templates/init.sh` in this plugin (mise, submodules, envrc, direnv).

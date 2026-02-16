# Worktree Init Script - Trigger Examples

## Should Activate

### Worktree Creation (when init.sh exists)
- "create worktree for feature-auth"
- "start work on issue #123"
- "set up isolated workspace"
- "git worktree add for new branch"
- "create new worktree for this branch"
- "initialize worktree for development"

### Explicit init.sh References
- "run init.sh in the new worktree"
- "use init.sh for project setup"
- "initialize worktree with init.sh"
- "worktree setup with project script"
- "execute project initialization script"
- "check if init.sh exists before setup"

### Project Setup in Worktree
- "set up project dependencies in worktree"
- "initialize new workspace with project setup"
- "run project setup after creating worktree"
- "configure worktree environment"

### Russian
- "создай worktree для feature"
- "начни работу над задачей в worktree"
- "запусти init.sh в новом worktree"
- "инициализируй worktree скриптом"
- "настрой окружение в worktree"
- "создай рабочее пространство для ветки"
- "запусти скрипт инициализации"
- "выполни init.sh после создания worktree"

## Should NOT Activate

- "create worktree" (no init.sh in project -- standard using-git-worktrees handles it)
- "what is init.sh" (informational question, not worktree setup)
- "delete init.sh" (file management)
- "show init.sh contents" (reading file, not running setup)
- "edit init.sh" (editing script, not creating worktree)
- "npm install in worktree" (explicit tool, not init.sh flow)

## Key Trigger Words

**Verbs**: create, run, initialize, set up, execute, configure, check, start
**Nouns**: init.sh, worktree, workspace, setup, initialization, script
**Context**: "init.sh in project", "worktree setup", "project initialization"

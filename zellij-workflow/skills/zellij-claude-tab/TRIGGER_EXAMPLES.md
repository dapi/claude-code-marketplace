# Zellij Claude Tab Trigger Examples

## [YES] Should Activate

### Execute Plan (EN)

- "execute the plan in a new zellij tab"
- "run this plan in a separate tab"
- "launch the plan from docs/plans/audit.md in new tab"
- "execute plan in a new zellij tab with instructions"
- "run plan file in separate tab"
- "start the plan execution in a new tab"
- "execute this plan in parallel tab"
- "run the migration plan in a new zellij tab"
- "launch plan from docs/plans/skill-audit-plan.md in tab"
- "execute plan for issue #20 in a separate tab"

### Выполнить план (RU)

- "выполни план в новой вкладке zellij"
- "запусти план в отдельной вкладке"
- "выполни план из docs/plans/audit.md в новой вкладке"
- "запусти выполнение плана в параллельной вкладке"
- "открой новую вкладку и выполни план"
- "выполни план миграции в отдельной вкладке"
- "запусти план в новой вкладке"
- "выполни этот план в zellij вкладке"
- "план из файла выполни в отдельной вкладке"
- "запусти план для issue #20 в новой вкладке"

### Start Session (EN)

- "open claude session in new tab"
- "start new claude in zellij tab"
- "create tab and run claude with prompt"
- "start claude session in new tab with these instructions"
- "launch claude in a separate zellij tab"
- "open a new tab with claude session"
- "start interactive claude in new tab"
- "run claude in parallel tab"
- "new claude session in separate tab"
- "open claude in new zellij tab with this prompt"

### Начать сессию (RU)

- "открой сессию claude в новой вкладке"
- "запусти claude в новой вкладке zellij"
- "создай вкладку с сессией claude"
- "новая сессия claude в отдельной вкладке"
- "запусти интерактивную сессию в новой вкладке"
- "открой claude в параллельной вкладке"
- "начни сессию claude в отдельной вкладке"
- "создай новую вкладку с claude"
- "запусти claude с этими инструкциями в новой вкладке"
- "открой новую вкладку и запусти claude"

### Delegate Work (EN)

- "delegate this to a new tab"
- "run this in background tab"
- "parallel session for this task"
- "send to new tab"
- "offload to separate tab"
- "delegate the refactoring to a new tab"
- "run this task in parallel"
- "offload this work to a new zellij tab"
- "spin up a new tab for this"
- "move this work to a separate tab"

### Делегировать (RU)

- "делегируй это в новую вкладку"
- "запусти в параллельной вкладке"
- "отправь в отдельную вкладку"
- "выполни в фоновой вкладке"
- "перенеси эту работу в новую вкладку"
- "запусти в параллельной сессии"
- "делегируй рефакторинг в отдельную вкладку"
- "отправь эту задачу в новую вкладку"
- "запусти это параллельно в другой вкладке"
- "создай параллельную сессию для этого"

### With Plan File Reference

- "execute docs/plans/2026-02-14-skill-audit-plan.md in new tab"
- "run the plan at docs/plans/migration.md in separate tab"
- "launch docs/plans/refactor-auth.md in a new zellij tab"
- "выполни docs/plans/audit.md в новой вкладке"
- "запусти план из docs/plans/deploy.md в отдельной вкладке"
- "execute the plan file docs/plans/test-plan.md in tab"
- "run docs/plans/feature-plan.md in parallel tab"

### With Issue Reference + Instructions

- "execute plan for issue #123 in new tab with full audit"
- "run instructions for #45 in separate zellij tab"
- "launch task for issue 78 with detailed review in new tab"
- "выполни инструкции для issue #123 в новой вкладке"
- "запусти задачу для #45 в отдельной вкладке"
- "execute audit for issue #20 in new tab"
- "run the review for #99 in parallel tab"

### Combined / Polite

- "можешь выполнить это в отдельной вкладке?"
- "пожалуйста запусти план в новой вкладке zellij"
- "could you run this in a new tab please?"
- "please execute the plan in a separate zellij tab"
- "I need this running in a parallel tab"
- "хочу запустить эту задачу в новой вкладке"
- "can you delegate this to a new tab?"
- "would you launch claude in a separate tab with these instructions?"
- "пожалуйста открой claude в новой вкладке"
- "I'd like to run this plan in a new zellij tab"

## [NO] Should NOT Activate

### General zellij questions

- "что такое zellij?"
- "how to install zellij?"
- "как настроить zellij?"
- "zellij documentation"
- "zellij keybindings"

### Tab management (no claude session)

- "переименуй вкладку"
- "закрой вкладку"
- "switch to tab 3"
- "список вкладок zellij"
- "how to create zellij tabs?"
- "rename this tab"

### Issue development (use zellij-dev-tab skill instead)

- "запусти разработку issue 45 в новой вкладке"
- "start issue #123 in new tab"
- "start-issue в отдельной вкладке"
- "открой issue в новой вкладке"
- "run start-issue in new tab"
- "создай вкладку для issue #78"
- "launch issue development in separate tab"
- "begin work on issue in new zellij tab"

### Issue without tab context

- "покажи issue #123"
- "read issue 45"
- "закрой issue"
- "create new issue"
- "прочитай задачу"
- "list open issues"

### Run commands (not claude session)

- "запусти тесты"
- "run npm install"
- "execute make build"
- "запусти линтер"
- "run the deployment script"

### Questions about plans

- "покажи план"
- "что в плане?"
- "read the plan file"
- "show me the plan from docs/"
- "какой план для issue #20?"

## Key Trigger Words

### Verbs

**EN:** execute, run, launch, start, open, create, delegate, offload, send, spin up
**RU:** выполни, запусти, открой, создай, делегируй, отправь, перенеси, начни

### Nouns

**EN:** tab, session, plan, instructions, prompt, task, claude
**RU:** вкладка, сессия, план, инструкции, задача, claude

### Distinguishing from zellij-dev-tab

| Pattern | This skill (zellij-claude-tab) | zellij-dev-tab |
|---------|-------------------------------|----------------|
| Core object | plan, instructions, task, prompt | issue, #number, start-issue |
| Action | execute plan, run claude, delegate | start development, work on issue |
| Purpose | Arbitrary claude session | Issue-specific development |
| Dependencies | claude CLI | start-issue script |
| Tab naming | From context (plan-audit, refactor) | Always #NUMBER |

**Rule:** If the request mentions an issue number/URL and wants to start development -- use `zellij-dev-tab`. If the request has arbitrary instructions, a plan file, or wants a claude session -- use `zellij-claude-tab`.

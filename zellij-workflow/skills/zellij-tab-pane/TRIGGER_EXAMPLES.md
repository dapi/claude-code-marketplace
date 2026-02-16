# Zellij Tab/Pane Trigger Examples

## [YES] Should Activate

### **Empty Tab (EN)**

- "open new tab"
- "create a new zellij tab"
- "new tab please"
- "open empty tab in zellij"
- "I need a new tab"

### **Empty Pane (EN)**

- "create a new pane"
- "open pane in zellij"
- "new pane please"
- "I need a new panel"
- "open empty pane"

### **Пустая вкладка (RU)**

- "открой новую вкладку"
- "создай вкладку"
- "новая вкладка в zellij"
- "мне нужна новая вкладка"
- "открой пустую вкладку"

### **Пустая панель (RU)**

- "создай панель"
- "открой новую панель"
- "новая панель в zellij"
- "мне нужна новая панель"
- "открой пустую панель"

### **Command in Tab (EN)**

- "run npm test in new tab"
- "execute make build in tab"
- "run the linter in a new zellij tab"
- "launch tests in separate tab"
- "run cargo build in new tab"
- "start webpack in a tab"

### **Command in Pane (EN)**

- "run npm test in a pane"
- "execute make build in pane"
- "run tests in new panel"
- "launch linter in a pane"
- "run cargo build in pane"

### **Команда в вкладке (RU)**

- "запусти npm test в новой вкладке"
- "запусти тесты в отдельной вкладке"
- "выполни make build в вкладке"
- "запусти линтер в вкладке zellij"
- "make deploy в новой вкладке"

### **Команда в панели (RU)**

- "запусти тесты в панели"
- "выполни make build в панели"
- "npm test в панели"
- "запусти линтер в новой панели"
- "make deploy в панели"

### **Claude Session in Tab (EN)**

- "execute the plan in a new zellij tab"
- "run this plan in a separate tab"
- "launch the plan from docs/plans/audit.md in new tab"
- "start claude session in new tab with these instructions"
- "run claude in parallel tab"
- "delegate this to a new tab"
- "offload to separate tab"
- "spin up a new tab for this"
- "run this task in parallel"
- "execute this plan in a new tab"

### **Claude Session in Pane (EN)**

- "execute plan in a pane"
- "delegate this to a pane"
- "run claude session in pane"
- "launch task in new panel"
- "offload to pane"
- "run this in a pane"
- "delegate the refactoring to a pane"

### **Сессия Claude во вкладке (RU)**

- "выполни план в новой вкладке zellij"
- "запусти план в отдельной вкладке"
- "делегируй это в новую вкладку"
- "запусти в параллельной вкладке"
- "открой сессию claude в новой вкладке"
- "создай вкладку с сессией claude"
- "выполни план из файла в отдельной вкладке"
- "запусти claude с этими инструкциями в вкладке"

### **Сессия Claude в панели (RU)**

- "выполни план в панели"
- "делегируй это в панель"
- "запусти claude в панели"
- "открой сессию claude в панели"
- "запусти задачу в новой панели"
- "выполни это в панели zellij"

### **Issue in Tab (EN)**

- "start issue #123 in new tab"
- "launch issue development in separate tab"
- "create tab for issue #45"
- "open https://github.com/org/repo/issues/78 in tab"
- "start-issue 99 in a new tab"

### **Issue in Pane (EN)**

- "start issue #123 in a pane"
- "launch issue in pane"
- "open issue #45 in panel"
- "start-issue in pane"

### **Issue во вкладке/панели (RU)**

- "стартани задачу в панели"
- "запусти issue #123 в новой вкладке"
- "создай вкладку для issue #78"
- "запусти разработку issue 45 в панели"
- "start-issue в отдельной вкладке"

### **Combined / Polite**

- "could you run this in a new tab please?"
- "please execute the plan in a separate tab"
- "can you delegate this to a pane?"
- "можешь запустить это в новой вкладке?"
- "пожалуйста выполни план в панели"
- "хочу запустить задачу в новой вкладке"

## [NO] Should NOT Activate

### General zellij questions

- "what is zellij?"
- "how to install zellij?"
- "как настроить zellij?"
- "zellij keybindings"

### Tab management (no creation)

- "rename this tab"
- "close the tab"
- "switch to tab 3"
- "list zellij tabs"

### Run commands without tab/pane context

- "run npm test"
- "execute make build"
- "запусти тесты"
- "run the deployment script"

### Questions about plans

- "show me the plan"
- "read the plan file"
- "покажи план"
- "what is in the plan?"

## Key Trigger Words

### Verbs

**EN:** open, create, run, execute, launch, start, delegate, offload, send, spin up
**RU:** открой, создай, запусти, выполни, делегируй, отправь, начни

### Nouns

**EN:** tab, pane, panel, session, command, plan, task, claude
**RU:** вкладка, панель, сессия, команда, план, задача

### Context Patterns

- "[verb] [something] in [new] tab/pane"
- "[verb] new tab/pane"
- "delegate/offload to tab/pane"
- "[verb] [что-то] в [новой] вкладке/панели"

### Mode coverage

| Mode | Core object | Example |
|------|-------------|---------|
| A (empty) | nothing | "open new tab" |
| B (command) | shell command | "run npm test in pane" |
| C (claude) | plan, task, prompt | "execute plan in tab" |
| D (issue) | issue #N, URL | "start issue #123 in pane" |

# Zellij Dev Tab Trigger Examples

## [YES] Should Activate

### **Start Development (RU)**

- "запусти разработку в отдельной вкладке"
- "начни работу над issue в новой вкладке"
- "разработка issue 45 в новой вкладке"
- "запусти issue #123 в отдельной вкладке zellij"
- "начни работу над задачей в вкладке"
- "открой разработку issue в новой вкладке"
- "работа над issue 78 в отдельной вкладке"
- "запусти работу над #99 в вкладке"

### **Start Development (EN)**

- "start development in separate tab"
- "open issue in new zellij tab"
- "launch issue #45 in new tab"
- "start working on issue in separate tab"
- "begin development in new zellij tab"
- "open issue 123 in zellij tab"
- "work on issue in new tab"
- "start issue development in tab"

### **Create Tab (RU)**

- "создай вкладку для issue #123"
- "новая вкладка для задачи 45"
- "открой вкладку для issue"
- "вкладка для #78"
- "создай zellij вкладку для issue"
- "новая вкладка zellij для задачи"
- "вкладка для работы над issue 56"

### **Create Tab (EN)**

- "new tab for issue"
- "create tab for issue #123"
- "zellij tab for #45"
- "new zellij tab for issue 78"
- "create development tab for issue"
- "tab for issue development"
- "open new tab for #99"

### **Pane (RU)**

- "запусти issue 45 в панели"
- "начни разработку в новой панели"
- "создай панель для issue #123"
- "работа над issue в панели zellij"
- "start-issue в панели"

### **Pane (EN)**

- "start issue #45 in a pane"
- "launch issue development in pane"
- "create pane for issue 78"
- "work on issue in new panel"
- "run start-issue in pane"

### **start-issue Commands (RU)**

- "start-issue в отдельной вкладке"
- "запусти start-issue в новой вкладке"
- "start-issue 45 в вкладке zellij"
- "запусти start-issue в zellij"
- "start-issue для #123 в новой вкладке"

### **start-issue Commands (EN)**

- "run start-issue in new tab"
- "start-issue in separate tab"
- "launch start-issue in zellij tab"
- "run start-issue 45 in new tab"
- "start-issue #123 in zellij"

### **With URL**

- "open https://github.com/owner/repo/issues/123 in new tab"
- "start https://github.com/dapi/project/issues/45 in zellij tab"
- "start https://github.com/org/repo/issues/78 in new tab"
- "open github issue URL in zellij tab"

### **Combined / Polite**

- "can you start issue 45 in a separate tab?"
- "please open #123 in a new zellij tab"
- "need to start issue #78 in separate zellij tab"
- "please open issue development in new tab"
- "could you launch issue #99 in a pane?"

## [NO] Should NOT Activate

### General zellij questions

- "what is zellij?"
- "how to install zellij?"
- "zellij documentation"

### General start-issue questions

- "what does start-issue do?"
- "how does start-issue work?"
- "where to get start-issue?"

### Issue without tab/pane context

- "show issue #123"
- "read issue 45"
- "close issue"
- "create new issue"

### Tab management without issues

- "rename tab"
- "close tab"
- "switch to tab"
- "list zellij tabs"

### General-purpose tab/pane requests (use zellij-tab-pane instead)

- "execute plan in a new zellij tab"
- "run claude with instructions in new tab"
- "delegate this task to a new tab"
- "open empty tab"
- "run npm test in pane"
- "create a new pane"
- "open new tab"

## Key Trigger Words

### Verbs

**RU:** запусти, начни, открой, создай, работа, разработка
**EN:** start, open, create, launch, begin, run, work

### Nouns

**RU:** вкладка, панель, tab, pane, issue, задача, разработка
**EN:** tab, pane, panel, issue, development, zellij

### Context Patterns

- "[verb] [issue] in [new] tab/pane"
- "[verb] [issue] in [new] panel"
- "start-issue in tab/pane"
- "zellij tab/pane for [issue]"

### Required Combinations

For activation, a combination is needed:
1. **Issue** (number, #number, URL, "issue", "task"/"zadacha")
2. **Tab/Pane** ("tab", "pane", "panel", "vkladka"/"panelj")
3. **Action** (start, open, create, launch, begin, run)

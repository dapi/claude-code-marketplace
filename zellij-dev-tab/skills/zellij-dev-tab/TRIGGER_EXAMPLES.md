# Zellij Dev Tab Trigger Examples

## ✅ Should Activate (положительные примеры)

### 🚀 Запуск разработки (RU)

- "запусти разработку в отдельной вкладке"
- "начни работу над issue в новой вкладке"
- "разработка issue 45 в новой вкладке"
- "запусти issue #123 в отдельной вкладке zellij"
- "начни работу над задачей в вкладке"
- "открой разработку issue в новой вкладке"
- "работа над issue 78 в отдельной вкладке"
- "запусти работу над #99 в вкладке"

### 🚀 Start Development (EN)

- "start development in separate tab"
- "open issue in new zellij tab"
- "launch issue #45 in new tab"
- "start working on issue in separate tab"
- "begin development in new zellij tab"
- "open issue 123 in zellij tab"
- "work on issue in new tab"
- "start issue development in tab"

### 📑 Создание вкладки (RU)

- "создай вкладку для issue #123"
- "новая вкладка для задачи 45"
- "открой вкладку для issue"
- "вкладка для #78"
- "создай zellij вкладку для issue"
- "новая вкладка zellij для задачи"
- "вкладка для работы над issue 56"

### 📑 Create Tab (EN)

- "new tab for issue"
- "create tab for issue #123"
- "zellij tab for #45"
- "new zellij tab for issue 78"
- "create development tab for issue"
- "tab for issue development"
- "open new tab for #99"

### 🔧 do-issue команды (RU)

- "do-issue в отдельной вкладке"
- "запусти do-issue в новой вкладке"
- "do-issue 45 в вкладке zellij"
- "запусти do-issue в zellij"
- "do-issue для #123 в новой вкладке"

### 🔧 do-issue Commands (EN)

- "run do-issue in new tab"
- "do-issue in separate tab"
- "launch do-issue in zellij tab"
- "run do-issue 45 in new tab"
- "do-issue #123 in zellij"

### 🔗 С URL

- "открой https://github.com/owner/repo/issues/123 в новой вкладке"
- "запусти https://github.com/dapi/project/issues/45 в вкладке zellij"
- "start https://github.com/org/repo/issues/78 in new tab"
- "open github issue URL in zellij tab"

### 🎯 Комбинированные запросы

- "можешь запустить issue 45 в отдельной вкладке?"
- "пожалуйста открой #123 в новой вкладке zellij"
- "хочу работать над issue в отдельной вкладке"
- "need to start issue #78 in separate zellij tab"
- "please open issue development in new tab"

## ❌ Should NOT Activate (отрицательные примеры)

### Общие вопросы о zellij

- "что такое zellij?"
- "how to install zellij?"
- "как настроить zellij?"
- "zellij documentation"

### Общие вопросы о do-issue

- "что делает do-issue?"
- "how does do-issue work?"
- "где взять do-issue?"

### Работа с issue без вкладок

- "покажи issue #123"
- "read issue 45"
- "закрой issue"
- "create new issue"
- "прочитай задачу"

### Другие операции с вкладками

- "переименуй вкладку"
- "закрой вкладку"
- "switch to tab"
- "список вкладок zellij"

### Общие вопросы о разработке

- "как начать разработку?"
- "best practices for development"
- "что такое GitHub issues?"

## 🎯 Key Trigger Words

### Verbs (действия)

**RU:** запусти, начни, открой, создай, работа, разработка
**EN:** start, open, create, launch, begin, run, work

### Nouns (объекты)

**RU:** вкладка, tab, issue, задача, разработка
**EN:** tab, issue, development, zellij

### Context Patterns

- "[verb] [issue] в [отдельной/новой] вкладке"
- "[verb] [issue] in [new/separate] tab"
- "do-issue в вкладке"
- "zellij tab for [issue]"

### Required Combinations

Для активации нужно сочетание:
1. **Issue** (номер, #номер, URL, "issue", "задача")
2. **Tab/Вкладка** ("вкладка", "tab", "zellij tab")
3. **Action** (запустить, открыть, создать, start, open, create)

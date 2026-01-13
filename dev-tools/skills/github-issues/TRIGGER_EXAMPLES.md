# GitHub Issues Skill - Trigger Examples

## ✅ Should Activate (positive examples)

### Reading Issues (URLs)

- "прочитай https://github.com/owner/repo/issues/123"
- "read issue https://github.com/dapi/myproject/issues/45"
- "open https://github.com/owner/repo/issues/1"
- "what's in https://github.com/company/app/issues/999"
- "покажи задачу https://github.com/owner/repo/issues/12"

### Reading Issues (by number)

- "прочитай issue #123"
- "read issue #45"
- "show issue #12"
- "покажи задачу #99"
- "open task #7"
- "что в issue #123"
- "посмотри issue 45"

### Reading Issues (natural language)

- "прочитай задачу"
- "покажи текущую issue"
- "read the issue"
- "show me the task"
- "открой задачу"

### Marking Checkboxes

- "отметь пункт 1 как выполненный"
- "mark step 2 as done"
- "complete checkbox 'Написать тесты'"
- "закрой этап 3"
- "пункт 'Создать API' выполнен"
- "mark 'Setup database' as completed"
- "отметь выполненным 'Рефакторинг'"
- "check off step 1"
- "выполнил пункт про тесты"

### Sub-issues

- "create sub-issue for #123"
- "создай подзадачу для issue #45"
- "add subtask to #12"
- "list sub-issues of #99"
- "покажи дочерние issues"
- "show child issues for #123"
- "link issue #456 as sub-issue to #123"
- "создай дочерний issue"

### Issue Management

- "create new issue"
- "создай issue с заголовком 'Bug fix'"
- "close issue #123"
- "закрой задачу #45"
- "reopen issue #12"
- "edit issue body"
- "add label to issue #99"
- "добавь checkbox в issue"

### Combined Operations

- "прочитай issue #123 и выполни первый пункт"
- "read task https://github.com/o/r/issues/1 and mark step 1 done"
- "открой задачу и покажи невыполненные пункты"
- "check issue #45 progress"

### Images/Attachments

- "download images from issue #123"
- "скачать картинки из issue"
- "get attachments from https://github.com/owner/repo/issues/45"
- "получи изображения из задачи"
- "save issue images locally"
- "скачай вложения из issue #12"

## ❌ Should NOT Activate (negative examples)

### General GitHub (not issues)

- "show me the repo"
- "clone the repository"
- "create a pull request"
- "review PR #123"
- "merge branch"
- "show commits"
- "git status"

### Generic Questions

- "what is GitHub?"
- "how do issues work?"
- "explain GitHub workflow"
- "что такое issue"

### Other Tools

- "check bugsnag errors"
- "show jira tickets"
- "read trello card"
- "open linear issue"

### Unrelated Commands

- "run tests"
- "build the project"
- "deploy to production"
- "fix the bug"
- "refactor this code"

### Ambiguous (without issue context)

- "mark as done" (no issue specified, no prior context)
- "create subtask" (no parent issue)
- "show checkboxes" (no issue specified)

## 🎯 Key Trigger Patterns

### URL Pattern
```
github.com/.../issues/\d+
```

### Number Pattern
```
issue #\d+
issue \d+
#\d+ (in issue context)
```

### Action Verbs (English)
- read, show, open, view, display
- mark, complete, check, close
- create, add, edit, update
- list, get, fetch
- download, save (images/attachments)

### Action Verbs (Russian)
- прочитай, покажи, открой, посмотри
- отметь, выполни, закрой, заверши
- создай, добавь, редактируй
- список, получи
- скачай, сохрани (картинки/вложения)

### Key Nouns
- issue, task, задача, задание
- checkbox, step, пункт, этап, шаг
- sub-issue, subtask, подзадача, дочерний
- images, attachments, картинки, изображения, вложения

### Context Patterns
- "from issue", "in issue", "из issue", "в задаче"
- "as done", "as completed", "как выполненный"
- "for issue #N", "для issue #N"

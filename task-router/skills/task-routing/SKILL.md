---
name: task-routing
description: |
  **UNIVERSAL TRIGGER**: ROUTE/TAKE/IMPLEMENT any task FROM a URL or issue reference

  **URLs & References**:
  - "get task from github.com/.../issues/N", "fetch spec from docs.google.com/..."
  - "retrieve task from https://..."

  **Action Triggers (EN)**:
  - "take this task", "implement this spec", "do issue #NNN"
  - "route task", "route this", "start issue #NNN"
  - "check this task", "analyze task"

  **Triggers (RU)**:
  - "возьми задачу", "сделай задачу", "реализуй по спеке"
  - "сделай issue #NNN", "возьми issue #NNN"

  **#NNN**: action-слово + "issue"/"задачу" обязательны. Голый #NNN -- НЕ триггер.

  **Should NOT activate** (handled by other skills):
  - "show/read/view issue #N" (github-issues)
  - "what does issue #N say" (github-issues)
  - "edit/close/mark done issue" (github-issues)
  - "review spec", "check spec", "analyze requirements" (spec-review)
  - bare GitHub issue URL without action verb (github-issues)

  TRIGGERS: route task, route this, возьми задачу, сделай задачу,
    take this task, implement this spec, implement this issue,
    get task from, list task, check this task, analyze task,
    retrieve spec, fetch task,
    реализуй по спеке, сделай issue, do issue, start issue,
    github.com/issues, docs.google.com/document
allowed-tools: Skill
---

# Task Routing Skill

**Version: 1.0.0**

Тонкий автотриггер: обнаруживает ссылки на задачи и issue-ссылки в сообщениях пользователя и вызывает команду `/route-task` для классификации и маршрутизации.

Перед вызовом route-task покажи пользователю: `task-routing v1.0.0`

Этот скилл НЕ выполняет классификацию сам — только определяет наличие задачи и передаёт её в route-task.

## Логика определения источника

### 1. GitHub Issue URL

**Паттерн:** `github.com/{owner}/{repo}/issues/{number}`

```
Если в сообщении есть ссылка на GitHub Issue:
-> Извлечь полный URL
-> Вызвать: Skill tool -> skill: "task-router:route-task", args: "{URL}"
```

### 2. Google Doc URL

**Паттерн:** `docs.google.com/document/d/{DOCUMENT_ID}`

```
Если в сообщении есть ссылка на Google Doc:
-> Извлечь полный URL
-> Вызвать: Skill tool -> skill: "task-router:route-task", args: "{URL}"
```

### 3. Issue-ссылка (#NNN)

**Паттерн:** `issue #123`, `задачу #123` — ОБЯЗАТЕЛЬНО с action-словом И словом `issue`/`задачу`

**ВАЖНО:** Голый `#NNN` без контекста НЕ является триггером. `#NNN` часто встречается в коммитах, PR-ах, заголовках и не означает задачу. Активируй ТОЛЬКО при наличии ОБОИХ условий:
1. Action-слово: "сделай", "возьми", "реализуй", "take", "implement", "do", "start"
2. Слово-контекст: "issue", "задачу", "задачи", "task"

```
Если в сообщении есть action-слово + "issue"/"задачу" + #NNN:
-> Извлечь номер
-> Вызвать: Skill tool -> skill: "task-router:route-task", args: "#NNN"

Примеры ДА: "сделай issue #123", "take issue #42", "возьми задачу #99"
Примеры НЕТ: "see #123", "fixed in #42", "PR #99", "step #3"
```

### 4. Произвольный URL

```
Если в сообщении есть другой URL (https://...) в контексте задачи:
-> Извлечь URL
-> Вызвать: Skill tool -> skill: "task-router:route-task", args: "{URL}"
```

## Примеры активации

### Пример 1: GitHub Issue
```
User: Возьми задачу https://github.com/org/repo/issues/42
Assistant: [Вызывает Skill tool: task-router:route-task с args: "https://github.com/org/repo/issues/42"]
```

### Пример 2: Google Doc
```
User: Реализуй спеку https://docs.google.com/document/d/1abc/edit
Assistant: [Вызывает Skill tool: task-router:route-task с args: "https://docs.google.com/document/d/1abc/edit"]
```

### Пример 3: Issue по номеру
```
User: Сделай issue #123
Assistant: [Вызывает Skill tool: task-router:route-task с args: "#123"]
```

### Пример 4: Английский триггер
```
User: Take this task https://github.com/org/repo/issues/99
Assistant: [Вызывает Skill tool: task-router:route-task с args: "https://github.com/org/repo/issues/99"]
```

## Когда НЕ активировать

Не активируй автоматически если пользователь:
- Просто обсуждает или упоминает ссылку в разговоре без action-слова ("посмотри issue #42", "что говорит эта спека")
- Делает code review или обсуждает PR
- Упоминает ссылку в контексте другой задачи
- Использует `#NNN` без слова "issue"/"задачу" — это может быть коммит, PR, заголовок, шаг инструкции
- Отправляет голый GitHub issue URL без action-слова — это github-issues (чтение), не task-routing
- Запрашивает ревью/проверку спеки — "review spec", "check spec", "проверь спеку" — это spec-review

**Правило для `#NNN`:** Голый `#NNN` без action-слова И без "issue"/"задачу" — НИКОГДА не триггер. Примеры НЕ-триггеров: "see #123", "fixed in #42", "PR #99", "step #3", "commit #abc123".

**Правило для bare URL:** `https://github.com/org/repo/issues/42` без action-слова — это github-issues. task-routing активируется ТОЛЬКО при наличии action-слов: "возьми", "сделай", "реализуй", "take", "implement", "do", "start", "route".

**Правило для check/analyze:** Глаголы "check" и "analyze" требуют контекст "task"/"задачу". "check this task" — task-routing. "check spec"/"analyze requirements" — spec-review.

## Обработка ошибок

- Если вызов Skill tool для "task-router:route-task" завершился ошибкой — покажи: "Не удалось запустить маршрутизацию задачи. Команда /route-task может быть недоступна."
- Если в сообщении несколько URL — спроси пользователя какой именно маршрутизировать.
- Если триггер сработал ложно — извинись и продолжи обычный разговор.

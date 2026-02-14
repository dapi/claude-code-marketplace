---
name: task-routing
description: |
  **AUTO-TRIGGER**: Обнаруживает ссылки на задачи и упоминания issue в сообщениях пользователя и автоматически запускает маршрутизацию через /route-task.

  Используй когда:
  - "возьми задачу", "сделай задачу", "take this task"
  - "реализуй по спеке", "implement this spec", "implement this issue"
  - "route task", "route this", "/route-task"
  - "сделай issue #NNN", "do issue #NNN" (ОБЯЗАТЕЛЬНО action-слово + "issue"/"задачу" для #NNN)
  - пользователь вставил ссылку на GitHub Issue: `github.com/.../issues/N`
  - пользователь вставил ссылку на Google Doc: `docs.google.com/document/d/...`

  TRIGGERS: возьми задачу, сделай задачу, take this task,
  реализуй по спеке, implement this spec, implement this issue,
  route task, route this,
  сделай issue, do issue,
  github.com/issues, docs.google.com/document
allowed-tools: Skill
---

# Task Routing Skill

Тонкий автотриггер: обнаруживает ссылки на задачи и issue-ссылки в сообщениях пользователя и вызывает команду `/route-task` для классификации и маршрутизации.

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

**Правило для `#NNN`:** Голый `#NNN` без action-слова И без "issue"/"задачу" — НИКОГДА не триггер. Примеры НЕ-триггеров: "see #123", "fixed in #42", "PR #99", "step #3", "commit #abc123".

Активируй только когда сообщение явно указывает на намерение **начать работу** над задачей (содержит action-слова: "возьми", "сделай", "реализуй", "take", "implement", "do", "start", "route").

## Обработка ошибок

- Если вызов Skill tool для "task-router:route-task" завершился ошибкой — покажи: "Не удалось запустить маршрутизацию задачи. Команда /route-task может быть недоступна."
- Если в сообщении несколько URL — спроси пользователя какой именно маршрутизировать.
- Если триггер сработал ложно — извинись и продолжи обычный разговор.

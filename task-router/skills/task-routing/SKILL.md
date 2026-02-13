---
name: task-routing
description: |
  **AUTO-TRIGGER**: Обнаруживает ссылки на задачи и упоминания issue в сообщениях пользователя и автоматически запускает маршрутизацию через /route-task.

  Используй когда:
  - "возьми задачу", "сделай задачу", "take this task"
  - "реализуй по спеке", "implement this spec", "implement this issue"
  - "route task", "route this", "/route-task"
  - "сделай issue #NNN", "do issue #NNN"
  - пользователь вставил ссылку на GitHub Issue: `github.com/.../issues/N`
  - пользователь вставил ссылку на Google Doc: `docs.google.com/document/d/...`

  TRIGGERS: возьми задачу, сделай задачу, take this task,
  реализуй по спеке, implement this spec, implement this issue,
  route task, route this, /route-task,
  сделай issue, do issue,
  github.com/issues, docs.google.com/document
tools: Skill
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

**Паттерн:** `#123`, `issue #123`, `issue #NNN`

```
Если в сообщении есть ссылка на issue через #:
-> Извлечь номер
-> Вызвать: Skill tool -> skill: "task-router:route-task", args: "#NNN"
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

### Пример 5: Явная команда
```
User: /route-task https://github.com/org/repo/issues/7
Assistant: [Вызывает Skill tool: task-router:route-task с args: "https://github.com/org/repo/issues/7"]
```

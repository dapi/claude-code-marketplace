# Task Routing Trigger Examples

Примеры запросов, которые **должны активировать** task-routing skill.

## ✅ GitHub Issue (ДОЛЖНЫ СРАБОТАТЬ)

### По ссылке
- "возьми задачу https://github.com/org/repo/issues/42"
- "сделай https://github.com/org/repo/issues/123"
- "take this task https://github.com/org/repo/issues/99"
- "implement https://github.com/org/repo/issues/7"
- "реализуй https://github.com/org/repo/issues/55"
- "start working on https://github.com/org/repo/issues/10"

### По номеру
- "сделай issue #123"
- "do issue #42"
- "возьми задачу #99"
- "take issue #7"
- "реализуй issue #55"

---

## ✅ Google Doc (ДОЛЖНЫ СРАБОТАТЬ)

- "реализуй по спеке https://docs.google.com/document/d/1abc/edit"
- "implement this spec https://docs.google.com/document/d/1abc/edit"
- "возьми задачу https://docs.google.com/document/d/1xyz/edit"
- "сделай задачу по этому доку https://docs.google.com/document/d/2def/edit"
- "take this task https://docs.google.com/document/d/3ghi/edit"

---

## ✅ Произвольный URL (ДОЛЖНЫ СРАБОТАТЬ)

- "реализуй по спеке https://notion.so/my-workspace/task-spec-123"
- "implement this spec https://example.com/specs/feature.md"
- "возьми задачу https://linear.app/team/issue/ENG-123"
- "сделай задачу https://jira.company.com/browse/PROJ-456"

---

## ✅ Команды маршрутизации (ДОЛЖНЫ СРАБОТАТЬ)

- "route task https://github.com/org/repo/issues/42"
- "route this https://docs.google.com/document/d/1abc/edit"
- "маршрутизируй задачу https://github.com/org/repo/issues/7"

---

## ❌ НЕ должны активировать (другие контексты)

- "посмотри issue #42 и скажи что там" (просмотр, не реализация)
- "сколько открытых issues в репозитории?" (статистика)
- "сравни два подхода из https://docs.google.com/..." (обсуждение, не задача)
- "what does issue #123 say?" (чтение, не работа над задачей)
- "create a new GitHub issue" (создание issue, не реализация)
- "I found a bug described in https://github.com/..." (упоминание, без action-слова)

### #NNN без контекста (НЕ должны активировать)
- "see #123" (нет action-слова и нет "issue")
- "fixed in #42" (прошедшее время, отчёт, не задача)
- "PR #99" (ссылка на PR, не на issue)
- "step #3 in the plan" (шаг инструкции, не issue)
- "commit #abc123" (ссылка на коммит)
- "check #42" (просмотр, не реализация)
- "#123 looks interesting" (обсуждение, без action-слова)

---

## 🎯 Ключевые триггерные слова

### Действия (verbs)
**EN**: take, implement, do, start, route, build, work on
**RU**: возьми, сделай, реализуй, начни, маршрутизируй

### Контекст (nouns)
**EN**: task, issue, spec, feature
**RU**: задачу, issue, спеку, фичу

### Источники (patterns)
- `github.com/.../issues/N`
- `docs.google.com/document/d/...`
- `#NNN` (ТОЛЬКО с action-словом + "issue"/"задачу": "сделай issue #123", "take issue #42")

---

## 🧪 Тестирование

1. **GitHub Issue**: "возьми задачу https://github.com/org/repo/issues/42"
2. **Google Doc**: "реализуй спеку https://docs.google.com/document/d/1abc/edit"
3. **Issue по номеру**: "сделай issue #123"
4. **Английский**: "take this task https://github.com/org/repo/issues/99"
5. **Произвольный URL**: "implement spec https://notion.so/task-123"

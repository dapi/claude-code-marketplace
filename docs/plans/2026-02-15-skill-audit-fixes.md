# Skill Audit Fixes — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Реализовать исправления из аудита issue #20 — устранить конфликты между skills, улучшить описания агентов и повысить quality gate.

**Architecture:** Точечные правки в description/TRIGGERS секциях SKILL.md файлов и frontmatter агентов. Без изменений в логике skills — только улучшение метаданных для корректной активации.

**Tech Stack:** Markdown (YAML frontmatter), shell (review script validation)

**Issue:** https://github.com/dapi/claude-code-marketplace/issues/20

---

## Статус выводов аудита vs реальность

| # | Вывод аудита | Текущее состояние | Действие |
|---|-------------|-------------------|----------|
| 1 | "show issue" конфликтует в task-routing и github-issues | task-routing не содержит "show issue" явно, но имеет "list what in this issue", "display task" | Усилить boundary в description |
| 2 | himalaya: нет "folder/folders" в TRIGGERS | УЖЕ ЕСТЬ: строка 31-33 содержит "folder, folders" | Не требует исправлений |
| 3 | 5 cluster-efficiency агентов без `tools: Bash` | Только orchestrator без `tools:`, остальные 4 уже имеют | Добавить `tools:` только orchestrator |
| 4-8 | Suggested improvements | Актуальны | Реализовать |

---

## Task 1: Усилить boundary между task-routing и github-issues

**Files:**
- Modify: `task-router/skills/task-routing/SKILL.md` (description block, строки 1-27)
- Modify: `task-router/skills/task-routing/TRIGGER_EXAMPLES.md` (негативные примеры)

**Проблема:** task-routing может ложно активироваться на запросы вроде "show issue #42", "what does issue #123 say?" которые должны идти в github-issues. Причина — в description есть "list what in this issue", "check this task", "display task" и в TRIGGERS "what in this issue".

**Step 1: Отредактировать description в SKILL.md**

Убрать из Action Triggers (EN) строку 13 фразы, которые конфликтуют с github-issues:
- Убрать: `"list what in this issue"`, `"display task"`
- Оставить: `"check this task"` (context "task" отличает от github-issues)

Из TRIGGERS (строка 21-26) убрать:
- Убрать: `display task`, `what in this issue`
- Оставить: `list task` (task context)

Добавить в description явный блок **Should NOT activate** (по аналогии с himalaya):

```
**Should NOT activate** (github-issues handles these):
- "show issue #42", "read issue", "view issue" (reading issue content)
- "what does issue #123 say", "what in issue" (issue inspection)
- "edit issue", "close issue", "mark done" (issue management)
```

**Step 2: Обновить TRIGGER_EXAMPLES.md**

Добавить в секцию `[NO]` дополнительные негативные примеры, явно разделяющие github-issues и task-routing:
- "display issue #42" (отображение -- github-issues)
- "list what in this issue" (инспекция -- github-issues)
- "what's in issue #42?" (чтение -- github-issues)

**Step 3: Запустить review script**

Run: `./scripts/review_skill_triggers.sh task-router/task-routing`
Expected: score >= 75/100

**Step 4: Коммит**

```bash
git add task-router/skills/task-routing/SKILL.md task-router/skills/task-routing/TRIGGER_EXAMPLES.md
git commit -m "Fix task-routing triggers: remove github-issues conflicts (issue #20)"
```

---

## Task 2: Добавить `tools` в cluster-orchestrator agent

**Files:**
- Modify: `cluster-efficiency/agents/cluster-orchestrator.md` (frontmatter)

**Проблема:** Единственный агент из 5 в cluster-efficiency без явного `tools:` поля. Остальные 4 подагента уже имеют `tools: Bash`.

**Step 1: Добавить tools в frontmatter**

В `cluster-efficiency/agents/cluster-orchestrator.md` после `description:` блока добавить:

```yaml
tools: Bash, Task
```

Orchestrator использует Bash для kubectl и Task для запуска подагентов — оба инструмента должны быть объявлены.

**Step 2: Коммит**

```bash
git add cluster-efficiency/agents/cluster-orchestrator.md
git commit -m "Add explicit tools field to cluster-orchestrator agent (issue #20)"
```

---

## Task 3: Определить владельца для bare GitHub issue URL

**Files:**
- Modify: `github-workflow/skills/github-issues/SKILL.md` (description block)
- Modify: `task-router/skills/task-routing/SKILL.md` (description block)

**Проблема:** Когда пользователь отправляет голый URL `https://github.com/org/repo/issues/42` без action-слова, неясно какой skill должен активироваться: github-issues (для чтения) или task-routing (для маршрутизации).

**Решение:** github-issues должен быть владельцем bare URL, т.к. чтение — более безопасное default-действие. task-routing активируется только при наличии action-слова.

**Step 1: Добавить в task-routing SKILL.md явное правило**

В секцию "Когда НЕ активировать" добавить:

```
- Голый GitHub issue URL без action-слова ("https://github.com/org/repo/issues/42" без "сделай", "возьми", "implement" и т.д.) — это github-issues
```

**Step 2: Добавить в github-issues SKILL.md указание на ownership**

В description добавить строку:

```
**Default handler**: Bare GitHub issue URL without action verb -> github-issues (read mode)
```

**Step 3: Коммит**

```bash
git add github-workflow/skills/github-issues/SKILL.md task-router/skills/task-routing/SKILL.md
git commit -m "Clarify bare GitHub URL ownership: github-issues is default (issue #20)"
```

---

## Task 4: Добавить domain-noun requirement для "check"/"analyze" в task-routing

**Files:**
- Modify: `task-router/skills/task-routing/SKILL.md` (description block)

**Проблема:** Глаголы "check" и "analyze" используются и в task-routing, и в spec-review. Без domain-noun ("task"/"задачу" vs "spec"/"спеку") возникает неоднозначность.

**Step 1: В description task-routing уточнить контекст для check/analyze**

Изменить в Action Triggers (EN):
```
- "check this task", "analyze task"  (requires "task"/"задачу" context)
```

Добавить в **Should NOT activate**:
```
- "check spec", "analyze spec", "check requirements" (spec-review handles these)
```

**Step 2: Коммит**

```bash
git add task-router/skills/task-routing/SKILL.md
git commit -m "Add domain-noun requirement for check/analyze in task-routing (issue #20)"
```

---

## Task 5: Усилить guard для #NNN в spec-review

**Files:**
- Modify: `spec-reviewer/skills/spec-review/SKILL.md` (description block и body)

**Проблема:** spec-review активируется на `issue #123` и `#123` менее строго чем task-routing. Нужно требовать spec/review контекст.

**Step 1: Уточнить в description**

В секции "GitHub Issue" (строки 30-32) уточнить:

```
**GitHub Issue**:
- "проанализируй issue #123" (с ревью-контекстом: "проверь", "ревью", "проанализируй", "найди гапы")
- "проверь спецификацию github.com/.../issues/456"
- голый "issue #123" без ревью-контекста -- НЕ триггер (это github-issues или task-routing)
```

**Step 2: Добавить в body SKILL.md правило**

В секции "Логика определения источника → 2. GitHub Issue" добавить guard:

```
**ВАЖНО:** Активируй на issue #NNN ТОЛЬКО при наличии ревью-контекста:
- Слова: "проверь", "ревью", "review", "analyze", "найди гапы", "нестыковки"
- Без ревью-контекста issue #NNN обрабатывается github-issues (чтение) или task-routing (реализация)
```

**Step 3: Коммит**

```bash
git add spec-reviewer/skills/spec-review/SKILL.md
git commit -m "Strengthen #NNN guard in spec-review: require review context (issue #20)"
```

---

## Task 6: Перевести task-classifier agent на русский

**Files:**
- Modify: `task-router/agents/task-classifier.md` (description в frontmatter)

**Проблема:** Все 15 остальных агентов имеют description на русском, task-classifier — единственный на английском. Это инконсистентность.

**Step 1: Перевести description**

Заменить:
```yaml
description: |
  Lightweight task classifier and router (haiku).
  DO NOT call directly — used by the /route-task command to classify tasks.

  Fetches task content from a URL (GitHub issue, Google Doc, or any URL),
  saves the full spec to /tmp/task-router/, classifies complexity and routing
  signals, and returns a compact JSON routing decision.
```

На:
```yaml
description: |
  Легковесный классификатор и маршрутизатор задач (haiku).
  НЕ вызывай напрямую — используется командой /route-task для классификации.

  Получает контент задачи по URL (GitHub issue, Google Doc, или любой URL),
  сохраняет полную спеку в /tmp/task-router/, классифицирует сложность и
  сигналы маршрутизации, возвращает компактный JSON с решением.
```

**ВАЖНО:** Тело агента (инструкции) оставить на английском — это системный промпт для haiku-модели, который лучше работает на английском.

**Step 2: Коммит**

```bash
git add task-router/agents/task-classifier.md
git commit -m "Translate task-classifier description to Russian for consistency (issue #20)"
```

---

## Task 7: Обновить TRIGGER_EXAMPLES.md для всех затронутых skills

**Files:**
- Modify: `task-router/skills/task-routing/TRIGGER_EXAMPLES.md` (если не обновлён в Task 1)

**Step 1: Добавить cross-skill conflict examples**

Добавить новую секцию в TRIGGER_EXAMPLES.md:

```markdown
## [NO] Конфликтные запросы (обрабатываются другими skills)

### github-issues (чтение/управление)
- "show issue #42" (отображение содержимого -- github-issues)
- "read issue #42" (чтение -- github-issues)
- "edit issue #42" (редактирование -- github-issues)
- "close issue #42" (закрытие -- github-issues)
- "mark step 1 done in issue #42" (checkbox -- github-issues)
- "https://github.com/org/repo/issues/42" (голый URL без action -- github-issues)

### spec-review (ревью спецификаций)
- "review spec in issue #42" (ревью -- spec-review)
- "check spec docs.google.com/..." (проверка спеки -- spec-review)
- "find gaps in issue #42" (анализ гапов -- spec-review)
- "analyze requirements" (анализ требований -- spec-review)
```

**Step 2: Запустить review script**

Run: `./scripts/review_skill_triggers.sh task-router/task-routing`
Expected: score >= 75/100, negative examples count >= 15

**Step 3: Коммит**

```bash
git add task-router/skills/task-routing/TRIGGER_EXAMPLES.md
git commit -m "Add cross-skill conflict examples to task-routing TRIGGER_EXAMPLES (issue #20)"
```

---

## Task 8: Lint и финальная валидация

**Files:** Все изменённые файлы

**Step 1: Lint emoji**

Run: `make lint-emoji`
Expected: No supplementary plane emoji found

**Step 2: Review all changed skills**

Run:
```bash
./scripts/review_skill_triggers.sh task-router/task-routing
./scripts/review_skill_triggers.sh spec-reviewer/spec-review
```
Expected: Оба >= 75/100

**Step 3: Проверить JSON validity для plugin.json**

Run:
```bash
for f in */. claude-plugin/plugin.json; do python3 -c "import json; json.load(open('$f'))" && echo "OK: $f" || echo "FAIL: $f"; done
```

**Step 4: Отметить чеклист в issue #20**

Атомарно отметить все checkboxes:
```bash
gh issue view 20 -R dapi/claude-code-marketplace --json body -q .body | sed 's/- \[ \] 50 positive activation tests/- [x] 50 positive activation tests/' | gh issue edit 20 -R dapi/claude-code-marketplace --body-file -
```
И так для каждого пункта.

---

## Порядок выполнения

```
Task 1 (task-routing boundary) ─┐
Task 2 (orchestrator tools)     ├─ независимые, можно параллельно
Task 6 (task-classifier i18n)   ┘
         │
Task 3 (bare URL ownership)     ── зависит от Task 1 (task-routing уже изменён)
Task 4 (domain-noun requirement)── зависит от Task 1
Task 5 (spec-review #NNN guard) ── независимый
         │
Task 7 (TRIGGER_EXAMPLES)       ── зависит от Tasks 1, 3, 4
Task 8 (lint + validation)      ── зависит от всех предыдущих
```

## Не требует исправлений

- **himalaya "folder/folders"**: Уже в TRIGGERS (строки 31-33 SKILL.md)
- **4 подагента cluster-efficiency**: Уже имеют `tools: Bash`
- **plugin.json**: 11/12 полностью консистентны, zellij-tab-claude-status версия 1.0.23 ожидаема для часто-обновляемого hooks-плагина
- **Compound request handling** (п.8 из аудита): Не реализуемо на уровне skill description — это фундаментальное ограничение Claude Code skill routing. Документировать как known limitation.

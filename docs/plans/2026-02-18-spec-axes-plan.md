# Spec Axes Agent Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `spec-axes` agent to spec-reviewer plugin that checks coverage of specifications across three axes (What/How/Verify) per feature.

**Architecture:** New agent `spec-axes` runs in parallel with existing agents during Phase 2. It extracts features from specs and checks each against three axes. Results appear as AXS-* issues and a coverage matrix in the report.

**Tech Stack:** Markdown agent definition, follows existing spec-reviewer agent patterns.

---

### Task 1: Create spec-axes agent

**Files:**
- Create: `spec-reviewer/agents/spec-axes.md`

**Step 1: Create the agent file**

Create `spec-reviewer/agents/spec-axes.md` following the pattern from `spec-reviewer/agents/spec-risk.md` (frontmatter + role + methodology + format + examples):

```markdown
---
name: spec-axes
description: |
  Субагент для проверки покрытия спецификации по трём осям.
  НЕ вызывай напрямую -- используется через /spec-review команду.

  Анализирует: для каждой фичи/функции -- есть ли описание
  что строим (PRD, User Story), как строим (ERD, API, C4),
  как проверяем (Test Plan, AC).
---

# Spec Axes Agent

Проверка полноты покрытия спецификации по трём осям для каждой фичи.

## Задача

Для каждой функции/фичи в спецификации проверить наличие описания по 3 осям:
1. **Что строим** (What) -- User Story, требования, Acceptance Criteria, бизнес-контекст
2. **Как строим** (How) -- архитектура, модели данных (ERD), API контракт, компоненты (C4)
3. **Как проверяем** (Verify) -- Test Plan, тестовые сценарии, AC с метриками, edge cases

## Методология анализа

### 1. Извлечение фич

Прочитай спецификацию и составь список отдельных фич/функций.
Фича -- это отдельная единица функционала с самостоятельной ценностью.

Признаки отдельной фичи:
- Описана как отдельный раздел или User Story
- Имеет своего пользователя/актора
- Может быть реализована и протестирована независимо
- Имеет самостоятельную бизнес-ценность

Если спецификация описывает одну фичу -- всё равно проверяй все 3 оси.

### 2. Проверка каждой оси

Для каждой фичи проверь наличие артефактов:

#### Ось 1: ЧТО СТРОИМ (What)

| Артефакт | Что ищем |
|----------|----------|
| User Story / требование | Описание с точки зрения пользователя |
| Acceptance Criteria | Конкретные критерии приёмки (Given/When/Then) |
| Бизнес-контекст | Зачем это нужно, какую проблему решаем |
| Граничные условия | Что входит и не входит в scope |

**covered = true** если есть хотя бы User Story/требование + AC или чёткие критерии.

#### Ось 2: КАК СТРОИМ (How)

| Артефакт | Что ищем |
|----------|----------|
| Модели данных (ERD) | Описание сущностей, полей, связей |
| API контракт | Endpoints, request/response, коды ответов |
| Архитектура (C4) | Компоненты, взаимодействия, sequence diagrams |
| Технические решения | Выбор технологий, паттерны, ограничения |

**covered = true** если есть описание хотя бы одного технического аспекта реализации (ERD, API, или архитектура).

#### Ось 3: КАК ПРОВЕРЯЕМ (Verify)

| Артефакт | Что ищем |
|----------|----------|
| Test Plan | Стратегия тестирования, уровни тестов |
| Test Cases | Конкретные тестовые сценарии |
| Acceptance Criteria с метриками | Количественные критерии (время, %, кол-во) |
| Edge Cases | Граничные и негативные сценарии |

**covered = true** если есть тестовые сценарии или AC с проверяемыми метриками.

### 3. Определение severity

| Условие | Severity |
|---------|----------|
| 2 из 3 осей отсутствуют | critical |
| 1 из 3 осей отсутствует | high |
| Ось присутствует, но неполная (напр. US есть, AC нет) | medium |

## Формат вывода

**КРИТИЧЕСКИ ВАЖНО:** Вернуть результат СТРОГО в формате JSON:

\```json
{
  "agent": "axes",
  "features": [
    {
      "name": "Регистрация пользователя",
      "location": "Раздел 3",
      "axes": {
        "what": {"covered": true, "artifacts": ["US-001", "AC-001"], "notes": ""},
        "how": {"covered": true, "artifacts": ["ERD секция 4", "POST /users"], "notes": ""},
        "verify": {"covered": false, "artifacts": [], "notes": "Нет тестовых сценариев"}
      }
    }
  ],
  "coverage_matrix": {
    "total_features": 5,
    "fully_covered": 2,
    "partially_covered": 2,
    "not_covered": 1
  },
  "summary": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0
  },
  "issues": [
    {
      "id": "AXS-VRF-001",
      "type": "axis_gap",
      "severity": "high",
      "title": "Нет Test Plan для 'Регистрация пользователя'",
      "description": "Фича описана (US-001) и спроектирована (ERD, API), но отсутствуют тестовые сценарии и acceptance criteria с метриками",
      "feature": "Регистрация пользователя",
      "missing_axis": "verify",
      "present_axes": ["what", "how"],
      "location": "Раздел 3",
      "recommendation": "Добавить: acceptance tests, edge cases (невалидный email, дублирование, пустые поля), негативные сценарии"
    }
  ]
}
\```

### ID Format: `AXS-{AXIS}-{XXX}`

| Ось | Prefix | Описание |
|-----|--------|----------|
| what | `AXS-WHAT-` | Нет описания "что строим" |
| how | `AXS-HOW-` | Нет описания "как строим" |
| verify | `AXS-VRF-` | Нет описания "как проверяем" |

### Типы проблем (type)
- `axis_gap` -- полное отсутствие оси для фичи

### Уровни критичности (severity)
- `critical` -- 2 оси отсутствуют (фича почти не описана)
- `high` -- 1 ось отсутствует
- `medium` -- ось присутствует, но неполная
- `low` -- рекомендация по улучшению покрытия

## Примеры анализа

### Пример 1: Фича без тестов

**Спека:** "Регистрация: пользователь вводит email/пароль, система создаёт аккаунт. Данные хранятся в PostgreSQL, POST /api/users."

**Анализ:**
- What: [OK] есть описание (User Story), нет AC
- How: [OK] POST /api/users, PostgreSQL
- Verify: [FAIL] нет тестовых сценариев

**Issue:**
\```json
{
  "id": "AXS-VRF-001",
  "type": "axis_gap",
  "severity": "high",
  "title": "Нет тестовых сценариев для 'Регистрация'",
  "description": "Фича описана и спроектирована, но нет тестовых сценариев и AC с метриками",
  "feature": "Регистрация",
  "missing_axis": "verify",
  "present_axes": ["what", "how"],
  "location": "Раздел Регистрация",
  "recommendation": "Добавить test cases: успешная регистрация, дубль email, невалидный пароль, SQL injection"
}
\```

### Пример 2: Фича без архитектуры

**Спека:** "Как пользователь, я хочу получать уведомления о новых заказах. AC: уведомление приходит в течение 5 минут."

**Анализ:**
- What: [OK] User Story + AC
- How: [FAIL] нет описания реализации (push? email? websocket?)
- Verify: [OK] AC с метрикой (5 минут)

**Issue:**
\```json
{
  "id": "AXS-HOW-001",
  "type": "axis_gap",
  "severity": "high",
  "title": "Нет архитектуры для 'Уведомления о заказах'",
  "description": "Фича имеет User Story и AC, но не описана реализация: канал доставки, хранение, retry стратегия",
  "feature": "Уведомления о заказах",
  "missing_axis": "how",
  "present_axes": ["what", "verify"],
  "location": "US Уведомления",
  "recommendation": "Описать: канал (push/email/ws), модель данных уведомлений, API для подписки, retry при сбое"
}
\```

### Пример 3: Фича с 2 пропущенными осями

**Спека:** "Нужна интеграция с 1С для обмена данными о товарах."

**Анализ:**
- What: [FAIL] нет User Story, нет AC, только упоминание
- How: [FAIL] нет описания: протокол, формат, частота, направление обмена
- Verify: [OK -- нет, тоже FAIL]

**Issue:**
\```json
{
  "id": "AXS-WHAT-001",
  "type": "axis_gap",
  "severity": "critical",
  "title": "Интеграция с 1С: отсутствуют 2 из 3 осей (what + how)",
  "description": "Упомянута интеграция с 1С, но нет ни требований (кто, что, зачем), ни архитектуры (протокол, формат, частота)",
  "feature": "Интеграция с 1С",
  "missing_axis": "what",
  "present_axes": [],
  "location": "Упоминание в разделе интеграций",
  "recommendation": "Добавить: US (кто использует, зачем), описание обмена (направление, формат, частота), план тестирования"
}
\```

## Чеклист анализа

- [ ] Все фичи/функции идентифицированы
- [ ] Для каждой фичи проверены все 3 оси
- [ ] Severity корректно отражает количество пропущенных осей
- [ ] Рекомендации конкретны (не "добавить тесты", а "добавить test cases для X, Y, Z")
- [ ] Coverage matrix заполнена

## Инструкции

1. Внимательно прочитай спецификацию
2. Составь список всех фич/функций
3. Для каждой фичи проверь наличие артефактов по 3 осям
4. Для пропущенных осей сформулируй issue с конкретной рекомендацией
5. Заполни coverage_matrix
6. **Верни ТОЛЬКО JSON** -- без markdown, без пояснений
```

**Step 2: Verify no supplementary-plane emoji in the file**

Run: `./scripts/lint_no_emoji.sh spec-reviewer`
Expected: PASS (no emoji found)

**Step 3: Commit**

```bash
git add spec-reviewer/agents/spec-axes.md
git commit -m "Add spec-axes agent: three-axes coverage check (what/how/verify)"
```

---

### Task 2: Update orchestrator (spec-review.md) -- Phase 2 agent launch

**Files:**
- Modify: `spec-reviewer/commands/spec-review.md:466-484` (agent lists)
- Modify: `spec-reviewer/commands/spec-review.md:488-515` (mandatory agents section)

**Step 1: Add spec-axes to the agent launch conditions**

In `spec-reviewer/commands/spec-review.md`, after line 471 (before `---`), add:

```markdown
**Условный standard+ (не зависит от classifier):**
- spec-axes -- проверка покрытия по трём осям (standard, deep, exhaustive)
```

Update line 483:
```
- 2 обязательных агента (всегда)
- 0-1 условных standard+ агентов (spec-axes, если depth_level != "quick")
- 0-5 условных агентов (по результатам classifier)
- spec-scoper (только если quick_scope != "fits")
```

**Step 2: Add spec-axes Task block after mandatory agents (after line 515)**

Insert before "#### Условные агенты":

```markdown
---

#### Условные standard+ агенты (запускать если depth_level >= standard):

\```
Task: spec-axes (если depth_level != "quick")
  subagent_type: "spec-reviewer:spec-axes"
  description: "Проверка покрытия по трём осям"
  prompt: |
    Проанализируй спецификацию и для каждой фичи/функции
    проверь покрытие по трём осям:
    1. Что строим (User Story, AC, бизнес-контекст)
    2. Как строим (ERD, API, архитектура, C4)
    3. Как проверяем (Test Plan, test cases, AC с метриками)
    Верни результат в формате JSON.

    === СПЕЦИФИКАЦИЯ ===
    {полный текст спецификации}
    === КОНЕЦ СПЕЦИФИКАЦИИ ===
\```
```

**Step 3: Update the examples table (lines 614-623)**

Add spec-axes to the examples:

```markdown
| Quick Scope | Classification | Запускаемые агенты | Всего |
|-------------|----------------|-------------------|-------|
| fits, всё false | - | analyst, test | 2 |
| fits, всё false, standard | - | analyst, test, **axes** | 3 |
| fits, has_api=true, standard | - | analyst, test, **axes**, api | 4 |
| fits, has_data+api, standard | - | analyst, test, **axes**, data, api | 5 |
| borderline, всё true, standard | нужен breakdown | analyst, test, **axes**, data, api, infra, risk, ux, ai-readiness, **scoper** | 10 |
```

**Step 4: Commit**

```bash
git add spec-reviewer/commands/spec-review.md
git commit -m "Add spec-axes to Phase 2 agent launch in orchestrator"
```

---

### Task 3: Update orchestrator -- Phase 3 result parsing

**Files:**
- Modify: `spec-reviewer/commands/spec-review.md:631-656` (Phase 3 parsing and merging)

**Step 1: Add axes_result to parsing (after line 642)**

Add line:
```
axes_result = JSON.parse(axes_output)     # AXS-TYPE-XXX issues (если запускался)
```

**Step 2: Add axes_result to issue merging (after line 655)**

Add line:
```
           + (axes_result.issues если запускался spec-axes)
```

**Step 3: Commit**

```bash
git add spec-reviewer/commands/spec-review.md
git commit -m "Add spec-axes results to Phase 3 parsing and merging"
```

---

### Task 4: Update orchestrator -- Phase 5 report presentation

**Files:**
- Modify: `spec-reviewer/commands/spec-review.md:793-834` (Phase 5 report format)

**Step 1: Update agents count (line 805)**

Change from `из 9` to `из 10`:
```
**Агентов запущено:** {agents_count} из 10
```

**Step 2: Add axes coverage section after scope section (after line 818, before quality table)**

Insert new section:

```markdown
###  Покрытие по трём осям (если запускался spec-axes)

| Фича | Что (PRD/US/AC) | Как (ERD/API/C4) | Проверка (Tests/AC) |
|------|-----------------|-------------------|---------------------|
| {feature.name} | {[OK]/[!]} {artifacts} | {[OK]/[!]} {artifacts} | {[OK]/[!]} {artifacts} |

**Полностью покрыты:** {fully_covered}/{total_features} ({percent}%)
**Частично:** {partially_covered}/{total_features}
**Без покрытия:** {not_covered}/{total_features}

---
```

**Step 3: Add Axes row to quality summary table (after line 831)**

Add row before `| **Итого** |`:
```
| Axes (AXS-*) | N | N | N | N |
```

Add to note after table:
```
*Axes показывается только если depth_level >= standard*
```

**Step 4: Commit**

```bash
git add spec-reviewer/commands/spec-review.md
git commit -m "Add axes coverage section and AXS row to Phase 5 report"
```

---

### Task 5: Update orchestrator -- ID format docs and checklist

**Files:**
- Modify: `spec-reviewer/commands/spec-review.md:1109-1195` (ID format section)
- Modify: `spec-reviewer/commands/spec-review.md:1326-1391` (checklist)

**Step 1: Add spec-axes to agent prefix table (after line 1122)**

Add row:
```
| spec-axes | `AXS-` | Покрытие по осям |
```

**Step 2: Add axis_gap type to problem types (after line 1176)**

Add section:

```markdown
**spec-axes специфичные:**

| Тип | Prefix | Описание |
|-----|--------|----------|
| axis_gap_what | `-WHAT-` | Нет описания "что строим" |
| axis_gap_how | `-HOW-` | Нет описания "как строим" |
| axis_gap_verify | `-VRF-` | Нет описания "как проверяем" |
```

**Step 3: Add ID examples (after line 1195)**

```
AXS-WHAT-001  # Axes: нет User Story/требований для фичи
AXS-HOW-001   # Axes: нет архитектуры/ERD/API для фичи
AXS-VRF-001   # Axes: нет тестов/AC для фичи
```

**Step 4: Add to checklist section (around line 1356-1363)**

After the agents checklist item, add:
```
- [ ] Если depth_level >= standard → spec-axes запущен
```

In Phase 5 section of checklist, add:
```
- [ ] Матрица покрытия по осям показана (если spec-axes запускался)
```

**Step 5: Commit**

```bash
git add spec-reviewer/commands/spec-review.md
git commit -m "Add AXS ID format, type docs, and checklist items for spec-axes"
```

---

### Task 6: Update READMEs

**Files:**
- Modify: `spec-reviewer/README.md`
- Modify: `spec-reviewer/README.ru.md`

**Step 1: Update README.md agent table**

Add row to the agents table (after `spec-ai-readiness`):
```
| `spec-axes` | Three-axes coverage check |
```

Update description: "11 specialized agents" (was "10").

**Step 2: Update README.ru.md agent table**

Add row:
```
| `spec-axes` | Проверка покрытия по трём осям |
```

Update description: "11 специализированными агентами" (was "10").

**Step 3: Commit**

```bash
git add spec-reviewer/README.md spec-reviewer/README.ru.md
git commit -m "Add spec-axes to README agent lists"
```

---

### Task 7: Update CLAUDE.md agent count

**Files:**
- Modify: `CLAUDE.md` (root project CLAUDE.md, agent counts)

**Step 1: Update spec-reviewer row in Current State table**

Change: `| spec-reviewer | 10 agents, 1 skill, 1 command |`
To: `| spec-reviewer | 11 agents, 1 skill, 1 command |`

**Step 2: Update totals**

Change: `**Totals**: 16 agents, 10 skills, 10 commands`
To: `**Totals**: 17 agents, 10 skills, 10 commands`

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "Update agent counts in CLAUDE.md for spec-axes"
```

---

### Task 8: Run emoji lint and verify

**Step 1: Run emoji lint on spec-reviewer**

Run: `./scripts/lint_no_emoji.sh spec-reviewer`
Expected: PASS

**Step 2: Verify agent file exists and is well-formed**

Run: `head -10 spec-reviewer/agents/spec-axes.md`
Expected: YAML frontmatter with name: spec-axes

**Step 3: Final commit if any fixes needed**

If emoji lint fails, fix and commit:
```bash
./scripts/lint_no_emoji.sh --fix spec-reviewer
git add -A && git commit -m "Fix emoji lint issues in spec-axes"
```

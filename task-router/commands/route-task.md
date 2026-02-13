---
description: Классифицировать задачу и запустить подходящий workflow (feature-dev / subagent-driven-dev / hybrid)
argument-hint: <GitHub Issue URL | Google Doc URL | любой URL>
---

# /route-task — Маршрутизация задачи в workflow

Получает ссылку на задачу, классифицирует её через haiku-агента и запускает подходящий workflow разработки.

---

## Фаза 1: Валидация входных данных

Проверь `$ARGUMENTS`:

- Если пусто — спроси пользователя: "Укажи ссылку на задачу (GitHub Issue URL, Google Doc URL, или любой URL)"
- Если указано — переходи к Фазе 2.

---

## Фаза 2: Классификация задачи

Запусти субагент-классификатор через Task tool:

```
Task:
  subagent_type: "task-router:task-classifier"
  model: "haiku"
  description: "Classify task for routing"
  prompt: "Classify this task and determine the best workflow route: $ARGUMENTS"
```

Дождись результата. Ожидаемый формат — JSON:

```json
{
  "route": "feature-dev" | "subagent-driven-dev" | "hybrid",
  "complexity": "S" | "M" | "L" | "XL",
  "title": "...",
  "summary": "...",
  "reasoning": "...",
  "spec_file": "/tmp/task-router/spec-...",
  "source": "github" | "google-doc" | "url",
  "signals": {
    "needs_exploration": true | false,
    "has_clear_tasks": true | false,
    "architecture_unclear": true | false
  }
}
```

---

## Фаза 3: Обработка ошибок

- Если JSON не парсится — покажи: "Не удалось классифицировать задачу. Попробуй ещё раз или укажи другую ссылку." и **останови выполнение**.
- Если `route` == `"error"` — покажи: "Ошибка: {reasoning}" и **останови выполнение**.

---

## Фаза 4: Презентация результата

Покажи пользователю результат классификации в таком формате:

```
## 📋 {title}

| | |
|---|---|
| **Complexity** | {complexity} |
| **Route** | {route_display_name} |
| **Source** | {source} |

{summary}

**Reasoning:** {reasoning}

**Signals:** exploration={needs_exploration}, clear_tasks={has_clear_tasks}, unclear_arch={architecture_unclear}
**Spec saved:** {spec_file}
```

**Маппинг route → display name:**

| route | display name |
|-------|-------------|
| feature-dev | feature-dev (исследование + реализация) |
| subagent-driven-dev | writing-plans → subagent-driven-dev (план + реализация по задачам) |
| hybrid | feature-dev (фазы 1-4) → subagent-driven-dev (реализация) |

---

## Фаза 5: Подтверждение и выбор маршрута

Спроси пользователя через AskUserQuestion с вариантами:

1. **Да, запускай {route}** (Рекомендуется)
2. **Использовать feature-dev**
3. **Использовать subagent-driven-dev**
4. **Отмена**

Если пользователь выбрал "Отмена" — останови выполнение.

---

## Фаза 6: Запуск выбранного workflow

### Вариант: feature-dev

Вызови Skill tool:
- skill: `"feature-dev:feature-dev"`
- Передай в prompt: "Спека задачи сохранена в {spec_file}. Используй её как входные данные. Начни с фазы 2 (Codebase Exploration), спека уже получена."

### Вариант: subagent-driven-dev

Шаг 1 — вызови Skill tool:
- skill: `"superpowers:writing-plans"`
- Передай в prompt: "Спека задачи сохранена в {spec_file}. Используй её как входные данные для написания плана."

Шаг 2 — после завершения writing-plans, вызови Skill tool:
- skill: `"superpowers:subagent-driven-development"`

### Вариант: hybrid

Вызови Skill tool:
- skill: `"feature-dev:feature-dev"`
- Передай в prompt: "Спека задачи в {spec_file}. Выполни фазы 1-4 (Discovery, Exploration, Questions, Architecture). После одобрения архитектуры ОСТАНОВИ feature-dev и запусти writing-plans + subagent-driven-development для реализации."

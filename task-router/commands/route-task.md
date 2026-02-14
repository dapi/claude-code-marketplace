---
description: Классифицировать задачу и запустить подходящий workflow (feature-dev / subagent-driven-dev)
argument-hint: <GitHub Issue URL | Google Doc URL | любой URL>
---

# /route-task — Маршрутизация задачи в workflow

Получает ссылку на задачу, классифицирует её через haiku-агента и запускает подходящий workflow разработки.

---

## Фаза 1: Валидация входных данных

Проверь `$ARGUMENTS`:

1. Если пусто — спроси пользователя: "Укажи ссылку на задачу (GitHub Issue URL, Google Doc URL, или любой URL)"
2. Обрезать пробелы. Если несколько аргументов — использовать первый.
3. Если аргумент начинается с `github.com` или `docs.google.com` (без протокола) — добавить `https://`.
4. Если не похоже на URL (`http://`, `https://`) и не является ссылкой на issue (`#NNN`) — покажи: "Неверный формат. Укажи URL (http:// или https://) или ссылку на issue (#123)." и **останови выполнение**.
5. Если формат корректный — переходи к Фазе 2.

---

## Фаза 2: Классификация задачи

Запусти субагент-классификатор через Task tool:

```
Task:
  subagent_type: "task-router:task-classifier"
  description: "Classify task for routing"
  prompt: "Classify this task and determine the best workflow route: $ARGUMENTS"
  model: haiku
  max_turns: 10
```

**Если Task tool завершился ошибкой** (таймаут, crash, модель недоступна) — покажи: "Не удалось классифицировать задачу. Агент-классификатор не запустился. Попробуй позже: /route-task {url}" и **останови выполнение**.

Дождись результата. Ожидаемый формат — JSON:

```json
{
  "route": "feature-dev" | "subagent-driven-dev" | "needs-spec",
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

1. Если результат содержит markdown code fences (` ``` ` или ` ```json `) — удалить их.
2. Извлечь первый `{ ... }` JSON-блок из результата.
3. Попробовать распарсить JSON.
4. Если JSON не парсится — покажи: "Не удалось классифицировать задачу. Попробуй ещё раз или укажи другую ссылку." и **останови выполнение**.
5. Если `route` == `"error"` — покажи: "Ошибка: {title}. {summary}\n\nДетали: {reasoning}" и **останови выполнение**.
6. Если `route` == `"needs-spec"` — переходи к Фазе 4-NS (вместо обычной Фазы 4).

---

## Фаза 4: Презентация результата

Покажи пользователю результат классификации в таком формате:

```
## {title}

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

### Предварительная проверка

**Проверка spec-файла:**
Проверь существование `{spec_file}` через Read tool. Если файл не найден или пуст — покажи: "Файл спеки {spec_file} не найден. Запусти /route-task заново." и **останови выполнение**.

После проверки — **сразу переходи к Фазе 5** (запуск workflow). Подтверждение у пользователя не требуется — классификатор уже определил маршрут.

---

## Фаза 4-NS: Задача требует полноценной спеки (needs-spec)

Эта фаза вызывается ВМЕСТО обычных Фаз 4-5, когда классификатор определил `route = "needs-spec"`.

Покажи пользователю:

```
## {title}

| | |
|---|---|
| **Complexity** | {complexity} |
| **Source** | {source} |

{summary}

**Reasoning:** {reasoning}

**Signals:** exploration={needs_exploration}, clear_tasks={has_clear_tasks}, unclear_arch={architecture_unclear}
**Spec saved:** {spec_file}

---

### Задача требует полноценной спеки

Задача слишком большая и неопределённая для прямого запуска workflow:
- Нужно исследование кодовой базы и/или архитектура не определена
- Без проработки спеки автоматический workflow будет неэффективен

**Рекомендация:** запустить brainstorming для исследования и проектирования. После этого создать спеку (Google Doc или GitHub Issue) и повторно вызвать `/route-task` со ссылкой на готовую спеку.
```

Спроси пользователя через AskUserQuestion:

1. **Запустить brainstorming** (Рекомендуется) — исследование + проектирование архитектуры
2. **Всё равно запустить feature-dev** — полный цикл разработки как есть
3. **Всё равно запустить subagent-driven-dev** — план + реализация по задачам
4. **Отмена**

**Если выбрано "Запустить brainstorming":**
- Вызови Skill tool: skill: `"superpowers:brainstorming"`, args: "Спека задачи в {spec_file}. Используй её как входные данные. Исследуй кодовую базу, задай уточняющие вопросы, определи архитектуру решения. Результат — готовая спека для передачи в /route-task."
- После завершения brainstorming покажи: "Brainstorming завершён. Создай спеку на основе результатов и запусти `/route-task <url спеки>`."
- **Останови выполнение.**

**Если выбрано "feature-dev" или "subagent-driven-dev"** — переходи к Фазе 5 с выбранным вариантом.

**Если выбрано "Отмена"** — останови выполнение.

---

## Фаза 5: Запуск выбранного workflow

> Проверка spec-файла уже выполнена в Фазе 4.

### Вариант: feature-dev

Вызови Skill tool:
- skill: `"feature-dev:feature-dev"`
- args: "Спека задачи сохранена в {spec_file}. Используй её как входные данные. Начни с фазы 2 (Codebase Exploration), спека уже получена."

### Вариант: subagent-driven-dev

Шаг 1 — вызови Skill tool:
- skill: `"superpowers:writing-plans"`
- args: "Спека задачи сохранена в {spec_file}. Используй её как входные данные для написания плана."

Шаг 2 — после завершения writing-plans, вызови Skill tool:
- skill: `"superpowers:subagent-driven-development"`
- args: "Выполни план реализации, созданный на предыдущем шаге."

### Обработка ошибок запуска

Если Skill tool вернул ошибку (skill не найден) — покажи:

```
Skill "{skill_name}" не найден. Убедись, что необходимый плагин установлен:
- feature-dev — для workflow feature-dev
- superpowers — для workflow subagent-driven-dev (writing-plans + subagent-driven-development)
```

И **останови выполнение**.


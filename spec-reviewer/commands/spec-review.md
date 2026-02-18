---
description: Ревью спецификации или ТЗ на гапы, нестыковки, противоречия и оценку объёма
argument-hint: [--quick|-q|--deep|-d|--exhaustive|-e|--no-ask] [Google Doc URL | GitHub Issue URL | file path]
version: "1.9.0"
---

# Spec Review Command

Комплексное ревью спецификации с параллельным техническим, бизнес и scope-анализом.
**Итеративный процесс** до устранения всех критичных и высоких замечаний.

```
┌───────────────────────────────────────────────────────────────────────────┐
│                              /spec-review                                  │
│                    [--quick|-q|--deep|-d|--exhaustive|-e|--no-ask]         │
└─────────────────────────────────┬─────────────────────────────────────────┘
                                  │
                                  ▼
                       ┌─────────────────────┐
                       │   Фаза 0.5:         │
                       │   Уровень глубины   │
                       │   (flags/keywords)  │
                       └──────────┬──────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             ▼             ▼
             ┌───────────┐ ┌───────────┐ ┌───────────┐
             │  quick    │ │ standard/ │ │exhaustive │
             │ 2 агента  │ │   deep    │ │ 9 агентов │
             │ skip cls  │ │ classifier│ │ все безусл│
             └─────┬─────┘ └─────┬─────┘ └─────┬─────┘
                   │             │             │
                   └─────────────┼─────────────┘
                                 │
                                 ▼
                       ┌─────────────────────┐
                       │   Фаза 1.5:         │
                       │   spec-classifier   │
                       │   (haiku, ~500 tok) │
                       │   [skip if quick]   │
                       └──────────┬──────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │  1. Какие агенты нужны    │
                    │  2. Quick scope: влезает? │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │   too_large/borderline?   │
                    └─────────────┬─────────────┘
                           ДА    │    НЕТ
                    ┌────────────┴────────────┐
                    ▼                         ▼
          ┌─────────────────┐      ┌─────────────────┐
          │ Спросить юзера: │      │ Продолжить      │
          │ разбить/продолж │      │ Фазу 2          │
          └─────────────────┘      └─────────────────┘
                                  │
    ┌─────────┬─────────┬─────────┼─────────┬─────────┬─────────┬─────────┐
    │         │         │         │         │         │         │         │
    ▼         ▼         ▼         ▼         ▼         ▼         ▼         ▼
┌───────┐┌───────┐┌───────┐┌───────┐┌───────┐┌───────┐┌───────┐┌─────────┐
│ data  ││  api  ││ infra ││analyst││scoper ││ test  ││ risk  ││   ux    │
│ DAT-* ││ API-* ││ INF-* ││ BIZ-* ││ scope ││ TST-* ││ RSK-* ││  UX-*   │
│ усл.  ││ усл.  ││ усл.  ││ВСЕГДА ││ВСЕГДА ││ВСЕГДА ││ усл.  ││  усл.   │
└───┬───┘└───┬───┘└───┬───┘└───┬───┘└───┬───┘└───┬───┘└───┬───┘└────┬────┘
    │        │        │        │        │        │        │         │
    │        │   ПАРАЛЛЕЛЬНО (3 обязат. + 0-5 условных)   │         │
    └────────┴────────┴────────┴────────┴────────┴────────┴─────────┘
                                     │
                                     ▼
                          ┌─────────────────┐
                          │   Объединение   │
                          │   результатов   │
                          └────────┬────────┘
                                   │
          ┌────────────────────────┴────────────────────────┐
          │                                                 │
          ▼                                                 ▼
   ┌─────────────┐                                  ┌─────────────┐
   │  Проблемы   │                                  │   Scope     │
   │  качества   │                                  │  (разбиение)│
   └──────┬──────┘                                  └──────┬──────┘
          │                                                │
          └────────────────────┬───────────────────────────┘
                               │
                               ▼
                    ┌─────────────────┐
                    │    Фаза 6:      │◄──────────────────────────┐
                    │    Аппрув       │                           │
                    └────────┬────────┘                           │
                             │                                    │
                             ▼                                    │
                    ┌─────────────────┐                           │
                    │   GATE CHECK    │                           │
                    │ critical/high?  │                           │
                    └────────┬────────┘                           │
                             │                                    │
               ┌─────────────┴─────────────┐                      │
               │                           │                      │
               ▼                           ▼                      │
        ┌───────────┐              ┌───────────┐                  │
        │  ✅ НЕТ   │              │  ⚠️ ДА    │                  │
        │  (чисто)  │              │  (есть)   │                  │
        └─────┬─────┘              └─────┬─────┘                  │
              │                          │                        │
              ▼                          ▼                        │
        ┌───────────┐         ┌──────────────────┐                │
        │  Фаза 7   │         │  AskUserQuestion │                │
        │  ФИНАЛ    │         │  4 варианта      │                │
        └───────────┘         └────────┬─────────┘                │
                                       │                          │
              ┌────────────────┬───────┴───────┬──────────────┐   │
              │                │               │              │   │
              ▼                ▼               ▼              ▼   │
        ┌───────────┐   ┌───────────┐   ┌───────────┐  ┌─────────┐│
        │ Обработ.│   │ Полный  │   │✅ Принять │  │❌ Отмена││
        │индивидуал.│   │ре-анализ  │   │ как есть  │  │         ││
        └─────┬─────┘   └─────┬─────┘   └─────┬─────┘  └─────────┘│
              │               │               │                   │
              │               │               ▼                   │
              │               │         ┌───────────┐             │
              │               │         │  Фаза 7   │             │
              │               │         │ + warning │             │
              │               │         └───────────┘             │
              │               │                                   │
              │               └──────► Фаза 2 ◄───────────────────┘
              │                      (re-analyze)
              │
              └──────────────────────────► Фаза 6 ─────────────────┘
                                         (для каждой проблемы)
```

## Критерии качества

| Критерий | Символ | Что проверяем |
|----------|--------|---------------|
| **Гапы** | ️ | Отсутствующая информация |
| **Нестыковки** | ⚡ | Противоречия между разделами |
| **Неоднозначность** |  | Двойные толкования |
| **Непроверяемость** |  | Субъективные критерии |
| **Нереализуемость** |  | Технически невозможно |
| **Нетестируемость** |  | Невозможно написать тесты |

---

## Переменные состояния

```
VERSION = "1.9.0"                # Версия команды (синхронизирована с frontmatter)
iteration = 1                    # Текущая итерация (начинаем с 1)
spec_content = ""                # Текст спецификации
issues_history = []              # История проблем по итерациям

# Уровни глубины (NEW in 1.9.0)
depth_level = "standard"         # quick | standard | deep | exhaustive
min_severity = "high"            # critical | high | medium | low
no_ask = False                   # True если указан --no-ask
max_iterations = {               # Зависит от уровня
  "quick": 1,
  "standard": 2,
  "deep": 3,
  "exhaustive": 3
}

# Маппинг уровней
DEPTH_CONFIG = {
  "quick": {
    "min_severity": "critical",
    "max_iterations": 1,
    "run_classifier": False,
    "gate_check": False,
    "scope_analysis": False,
    "agents": "mandatory_only"  # 2 агента
  },
  "standard": {
    "min_severity": "high",
    "max_iterations": 2,
    "run_classifier": True,
    "gate_check": True,
    "scope_analysis": True,
    "agents": "by_classifier"
  },
  "deep": {
    "min_severity": "medium",
    "max_iterations": 3,
    "run_classifier": True,
    "gate_check": True,
    "scope_analysis": True,
    "agents": "by_classifier"
  },
  "exhaustive": {
    "min_severity": "low",
    "max_iterations": 3,
    "run_classifier": True,
    "gate_check": True,
    "scope_analysis": True,
    "agents": "all"  # все 9 агентов
  }
}
```

---

## Фаза 0.5: Определение уровня глубины (NEW in 1.9.0)

### Парсинг аргументов

```python
# $ARGUMENTS = "--quick https://docs.google.com/..." или "-d #42" и т.д.

# 1. Извлечь флаги уровня
flags = extract_flags($ARGUMENTS)  # --quick, -q, --deep, -d, --exhaustive, -e, --no-ask

# 2. Проверить флаги
if unknown_flag in flags:
    # EH-1: Неизвестный флаг
    error("❌ Неизвестный уровень {flag}. Доступные: --quick, --standard, --deep, --exhaustive")
    if levenshtein_distance(flag, known_flags) <= 2:
        hint(" Возможно вы имели в виду {closest_flag}?")
    return

if multiple_depth_flags(flags):
    # EH-1: Несколько флагов
    warning("⚠️ Указано несколько уровней, используется {deepest_flag}")
    depth_level = get_deepest(flags)  # quick < standard < deep < exhaustive

# 3. Проверить --no-ask
no_ask = "--no-ask" in flags

# 4. Убрать флаги из аргументов, оставить только источник
source_arg = remove_flags($ARGUMENTS)
```

### Определение уровня

```python
# Приоритет 1: Явный флаг
if "--quick" in flags or "-q" in flags:
    depth_level = "quick"
elif "--standard" in flags or "-s" in flags:
    depth_level = "standard"
elif "--deep" in flags or "-d" in flags:
    depth_level = "deep"
elif "--exhaustive" in flags or "-e" in flags:
    depth_level = "exhaustive"

# Приоритет 2: Ключевые слова в промпте (если нет флага)
elif depth_level is None:
    keywords_quick = ["быстро", "quick", "только критичное", "блокеры", "только блокеры"]
    keywords_deep = ["тщательно", "подробно", "deep", "детально", "глубоко", "глубокий анализ"]
    keywords_exhaustive = ["полный аудит", "exhaustive", "исчерпывающий", "всё проверить", "проверить всё"]

    prompt_text = user_message.lower()

    if any(kw in prompt_text for kw in keywords_exhaustive):
        depth_level = "exhaustive"
    elif any(kw in prompt_text for kw in keywords_deep):
        depth_level = "deep"
    elif any(kw in prompt_text for kw in keywords_quick):
        depth_level = "quick"
    elif has_conflicting_keywords(prompt_text):
        # EH-4: "быстро и тщательно" → спросить
        depth_level = None  # будет AskUserQuestion

# Приоритет 3: AskUserQuestion (если не определено и не --no-ask)
if depth_level is None and not no_ask:
    depth_level = ask_depth_level()  # см. ниже

# Приоритет 4: Default (если --no-ask или timeout)
if depth_level is None:
    depth_level = "standard"
    if no_ask:
        info(" Используется стандартный уровень (--no-ask)")
```

### AskUserQuestion: Выбор уровня глубины

```markdown
## Выбери уровень глубины ревью
```

**Варианты:**

1. **⚡ Быстрый** — только критические блокеры (~2 мин, 2 агента)
2. ** Стандартный (рекомендуется)** — критические + высокие
3. ** Глубокий** — все проблемы включая средние
4. ** Исчерпывающий** — полный аудит с рекомендациями (все 9 агентов)

**Обработка ответа:**
- Таймаут 60 сек → использовать standard
- Невалидный ответ → переспросить до 2 раз → standard
- Отмена/закрытие → standard с warning

### Применение конфигурации уровня

```python
config = DEPTH_CONFIG[depth_level]
min_severity = config["min_severity"]
max_iterations = config["max_iterations"]
run_classifier = config["run_classifier"]
gate_check_enabled = config["gate_check"]
scope_analysis_enabled = config["scope_analysis"]
agent_mode = config["agents"]

# Показать выбранный уровень
info(f"️ Уровень: {depth_level} | Показываются: severity ≥ {min_severity}")
```

---

## Фаза 1: Получение спецификации

### Источники

| Источник | Как получить |
|----------|--------------|
| **Google Doc** | MCP: `mcp__google_workspace__get_doc_content` |
| **Google Spreadsheet** | MCP: `mcp__google_workspace__read_sheet_values` |
| **GitHub Issue** | CLI: `gh issue view <number> --json body,title` |
| **Локальный файл** | Tool: `Read` |

**Аргумент команды:** `$ARGUMENTS`
- Если пусто — спроси: "Укажи ссылку на Google Doc, номер GitHub issue или путь к файлу"

**Извлечение ID:**
- Google Doc: `https://docs.google.com/document/d/{DOCUMENT_ID}/edit` → `{DOCUMENT_ID}`
- GitHub Issue: `https://github.com/{owner}/{repo}/issues/{number}` → `gh issue view {number}`

---

## Фаза 1.5: Классификация + Quick Scope (haiku)

**Цель:**
1. Определить какие субагенты нужны
2. Быстро оценить объём — влезает ли в одну сессию

**Экономия:** Вместо 8 агентов запускаем 2-7 в среднем.

### Условие запуска (зависит от depth_level)

```python
if depth_level == "quick":
    # Пропустить classifier полностью
    agents_to_run = ["spec-analyst", "spec-test"]  # только 2 обязательных
    skip_to_phase_2()

elif depth_level == "exhaustive":
    # Запустить classifier для scope analysis, но агенты = все
    run_classifier_for_scope_only = True
    agents_to_run = ALL_9_AGENTS  # все агенты безусловно

else:  # standard или deep
    # Полный classifier
    run_classifier()
```

### Запуск classifier

```
Task:
  subagent_type: "dev-tools:spec-classifier"
  model: "haiku"
  description: "Классификация спецификации"
  prompt: |
    Проанализируй спецификацию и определи:
    1. Какие аспекты присутствуют (для выбора агентов)
    2. Предварительную оценку объёма (quick scope)

    Верни ТОЛЬКО JSON без markdown formatting.

    Критерии классификации:
    - has_data_model: есть модели данных, БД, сущности, миграции
    - has_api: есть API, endpoints, интеграции, webhooks
    - has_infra_requirements: есть требования к deployment, безопасности, производительности
    - has_risks: критичная фича, миграции, внешние зависимости, новые технологии
    - has_ui: есть UI, экраны, формы, user flows

    Критерии оценки объёма:
    - verdict: "fits" (1-3 модели), "borderline" (4-6), "too_large" (7+)
    - complexity: S/M/L/XL

    При сомнении в классификации — ставь true.
    При сомнении в объёме — ставь более крупный verdict.

    === СПЕЦИФИКАЦИЯ ===
    {spec_content}
    === КОНЕЦ ===
```

### Результат классификации

```json
{
  "classification": {
    "has_data_model": true,
    "has_api": true,
    "has_infra_requirements": false,
    "has_risks": true,
    "has_ui": false
  },
  "quick_scope": {
    "verdict": "fits",
    "complexity": "M",
    "estimated_elements": { "models": 2, "endpoints": 5 },
    "scope_reasoning": "Две модели с CRUD — стандартная задача"
  },
  "agents_to_run": ["spec-data", "spec-api", "spec-risk"]
}
```

### Обработка Quick Scope

```
IF quick_scope.verdict == "too_large":
    → Показать пользователю оценку
    → AskUserQuestion: разбить на части или продолжить?
    → Если разбить → запустить spec-scoper (sonnet) для детального breakdown
    → Если продолжить → добавить warning и перейти к Фазе 2

ELIF quick_scope.verdict == "borderline":
    → Показать предупреждение
    → Спросить: нужен ли детальный breakdown?
    → Если да → запустить spec-scoper
    → Если нет → продолжить Фазу 2

ELSE (verdict == "fits"):
    → Сразу перейти к Фазе 2
    → НЕ запускать spec-scoper
```

### AskUserQuestion: Scope слишком большой

```markdown
## ⚠️ Спецификация слишком большая для одной сессии

**Оценка:** {complexity} ({estimated_elements.models} моделей, {estimated_elements.endpoints} endpoints)
**Причина:** {scope_reasoning}
```

**Варианты:**

1. ** Получить детальный breakdown и разбить**
   → Запустить spec-scoper (sonnet) для детального анализа
   → Предложить план разбиения на части

2. **⚡ Продолжить без разбиения (риск!)**
   → Добавить warning в отчёт
   → Продолжить ревью целиком

3. **❌ Отменить ревью**
   → Пользователь сам разобьёт спецификацию

### Маппинг classification → agents

| Флаг | Агент | Когда true |
|------|-------|------------|
| `has_data_model` | spec-data | Модели, БД, миграции |
| `has_api` | spec-api | API, endpoints, интеграции |
| `has_infra_requirements` | spec-infra | Deployment, безопасность |
| `has_risks` | spec-risk | Критичность, зависимости |
| `has_ui` | spec-ux | UI, экраны, формы |
| `has_ai_execution` | spec-ai-readiness | AI/LLM агенты, боты, автоматизация |

**Всегда запускаются (не зависят от классификации):**
- spec-analyst — бизнес-логика есть в любой спеке
- spec-test — тестируемость универсально полезна

**Опционально (только по запросу):**
- spec-scoper — детальный breakdown (если quick_scope != "fits")

**Условный standard+ (не зависит от classifier):**
- spec-axes -- проверка покрытия по трём осям (standard, deep, exhaustive)

---

## Фаза 2: Параллельный анализ

### КРИТИЧЕСКИ ВАЖНО: Запуск субагентов

**Используй Task tool для запуска агентов ОДНОВРЕМЕННО в ОДНОМ сообщении.**

**Запускать на основе результатов Фазы 1.5:**
- 2 обязательных агента (всегда)
- 0-1 условных standard+ (spec-axes, если depth_level != "quick")
- 0-5 условных агентов (по результатам classifier)
- spec-scoper (только если quick_scope != "fits")

---

#### Обязательные агенты (ВСЕГДА запускать — 2 штуки):

```
Task: spec-analyst (ОБЯЗАТЕЛЬНЫЙ)
  subagent_type: "dev-tools:spec-analyst"
  description: "Бизнес-анализ спецификации"
  prompt: |
    Проанализируй спецификацию с бизнес точки зрения:
    user stories, acceptance criteria, роли, права доступа.
    Верни результат в формате JSON.

    === СПЕЦИФИКАЦИЯ ===
    {полный текст спецификации}
    === КОНЕЦ СПЕЦИФИКАЦИИ ===

Task: spec-test (ОБЯЗАТЕЛЬНЫЙ)
  subagent_type: "dev-tools:spec-test"
  description: "Анализ тестируемости спецификации"
  prompt: |
    Проанализируй спецификацию с точки зрения тестируемости:
    можно ли написать тесты, какие test cases очевидны,
    что сложно протестировать, где неоднозначности.
    Верни результат в формате JSON.

    === СПЕЦИФИКАЦИЯ ===
    {полный текст спецификации}
    === КОНЕЦ СПЕЦИФИКАЦИИ ===
```

---

#### Условный standard+ агент (запускать если depth_level >= standard):

```
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
```

---

#### Условные агенты (запускать по результатам classifier):

```
Task: spec-data (если has_data_model == true)
  subagent_type: "dev-tools:spec-data"
  description: "Анализ данных спецификации"
  prompt: |
    Проанализируй спецификацию с точки зрения данных:
    модели, схемы БД, миграции, связи, валидация.
    Верни результат в формате JSON.

    === СПЕЦИФИКАЦИЯ ===
    {полный текст спецификации}
    === КОНЕЦ СПЕЦИФИКАЦИИ ===

Task: spec-api (если has_api == true)
  subagent_type: "dev-tools:spec-api"
  description: "Анализ API спецификации"
  prompt: |
    Проанализируй спецификацию с точки зрения API:
    endpoints, контракты, интеграции, webhooks, error handling.
    Верни результат в формате JSON.

    === СПЕЦИФИКАЦИЯ ===
    {полный текст спецификации}
    === КОНЕЦ СПЕЦИФИКАЦИИ ===

Task: spec-infra (если has_infra_requirements == true)
  subagent_type: "dev-tools:spec-infra"
  description: "Анализ инфраструктуры спецификации"
  prompt: |
    Проанализируй спецификацию с точки зрения инфраструктуры:
    безопасность, производительность, deployment, мониторинг.
    Верни результат в формате JSON.

    === СПЕЦИФИКАЦИЯ ===
    {полный текст спецификации}
    === КОНЕЦ СПЕЦИФИКАЦИИ ===

Task: spec-risk (если has_risks == true)
  subagent_type: "dev-tools:spec-risk"
  description: "Анализ рисков спецификации"
  prompt: |
    Проанализируй спецификацию с точки зрения рисков:
    технические, бизнес, операционные риски,
    что может пойти не так, mitigation strategies.
    Верни результат в формате JSON.

    === СПЕЦИФИКАЦИЯ ===
    {полный текст спецификации}
    === КОНЕЦ СПЕЦИФИКАЦИИ ===

Task: spec-ux (если has_ui == true)
  subagent_type: "dev-tools:spec-ux"
  description: "UX/UI анализ спецификации"
  prompt: |
    Проанализируй спецификацию с точки зрения UX/UI:
    user flows, UI states, edge cases в интерфейсе,
    accessibility, responsive design.
    Верни результат в формате JSON.

    === СПЕЦИФИКАЦИЯ ===
    {полный текст спецификации}
    === КОНЕЦ СПЕЦИФИКАЦИИ ===

Task: spec-ai-readiness (если has_ai_execution == true)
  subagent_type: "dev-tools:spec-ai-readiness"
  description: "Анализ готовности спецификации для AI-агентов"
  prompt: |
    Проанализируй спецификацию с точки зрения готовности
    к выполнению AI-агентами: достаточность контекста,
    наличие примеров, границы автономности, точки эскалации,
    критерии успеха, обработка ошибок.
    Верни результат в формате JSON.

    === СПЕЦИФИКАЦИЯ ===
    {полный текст спецификации}
    === КОНЕЦ СПЕЦИФИКАЦИИ ===

Task: spec-scoper (если quick_scope.verdict != "fits")
  subagent_type: "dev-tools:spec-scoper"
  description: "Детальный breakdown спецификации"
  prompt: |
    Оцени объём работы по спецификации.
    Предложи разбиение на части с зависимостями.
    Верни результат в формате JSON.

    === СПЕЦИФИКАЦИЯ ===
    {полный текст спецификации}
    === КОНЕЦ СПЕЦИФИКАЦИИ ===
```

**Все Task вызовы должны быть в ОДНОМ сообщении для параллельного выполнения!**
**Минимум 2 агента (обязательные), максимум 9 (все).**

### Пример: какие агенты запускать

| Quick Scope | Classification | Запускаемые агенты | Всего |
|-------------|----------------|-------------------|-------|
| fits, всё false | - | analyst, test | 2 |
| fits, has_api=true | - | analyst, test, api | 3 |
| fits, has_data+api | - | analyst, test, data, api | 4 |
| fits, has_ai_execution | - | analyst, test, ai-readiness | 3 |
| borderline, всё true | нужен breakdown | analyst, test, data, api, infra, risk, ux, ai-readiness, **scoper** | 9 |
| too_large, всё true | нужен breakdown | analyst, test, data, api, infra, risk, ux, ai-readiness, **scoper** | 9 |

---

## Фаза 3: Объединение результатов

После получения JSON от всех запущенных субагентов (3-8):

### 3.1 Парсинг результатов

```
data_result = JSON.parse(data_output)       # DAT-TYPE-XXX issues
api_result = JSON.parse(api_output)         # API-TYPE-XXX issues
infra_result = JSON.parse(infra_output)     # INF-TYPE-XXX issues
analyst_result = JSON.parse(analyst_output) # BIZ-TYPE-XXX issues
scoper_result = JSON.parse(scoper_output)   # scope analysis
test_result = JSON.parse(test_output)       # TST-TYPE-XXX issues
risk_result = JSON.parse(risk_output)       # RSK-TYPE-XXX issues
ux_result = JSON.parse(ux_output)           # UX-TYPE-XXX issues (если запускался)
ai_result = JSON.parse(ai_output)           # AI-TYPE-XXX issues (если запускался)
axes_result = JSON.parse(axes_output)     # AXS-TYPE-XXX issues (если запускался)
```

### 3.2 Объединение issues (качество)

```
all_issues = data_result.issues
           + api_result.issues
           + infra_result.issues
           + analyst_result.issues
           + test_result.issues
           + risk_result.issues
           + (ux_result.issues если запускался spec-ux)
           + (ai_result.issues если запускался spec-ai-readiness)
           + (axes_result.issues если запускался spec-axes)
```

### 3.3 Сортировка по severity

```
Порядок: critical → high → medium → low
```

### 3.3.1 Фильтрация по уровню глубины (NEW in 1.9.0)

```python
# Фильтрация по min_severity
severity_order = ["critical", "high", "medium", "low"]
min_index = severity_order.index(min_severity)

# Разделение на показываемые и скрытые
filtered_issues = [i for i in all_issues
                   if severity_order.index(i.severity) <= min_index]
hidden_issues = [i for i in all_issues
                 if severity_order.index(i.severity) > min_index]

# Подсчёт скрытых по severity
hidden_by_severity = {
    sev: count(hidden_issues where severity == sev)
    for sev in severity_order[min_index + 1:]
}
```

### 3.4 Формирование сводки качества

```
quality_summary = {
  critical: count(severity == "critical"),
  high: count(severity == "high"),
  medium: count(severity == "medium"),
  low: count(severity == "low")
}
```

### 3.5 Анализ scope

```
scope_verdict = scoper_result.verdict  // "fits" | "borderline" | "too_large"
breakdown = scoper_result.breakdown
suggested_plan = scoper_result.suggested_plan
```

---

## Фаза 4: Обработка Scope (если too_large/borderline)

### Если `verdict: "too_large"` или `verdict: "borderline"`

Показать пользователю breakdown и запросить решение:

```markdown
##  Оценка объёма спецификации

**Verdict:** ⚠️ Слишком большая / ⚡ На грани
**Estimated complexity:** XL
**Элементы:** N моделей, M endpoints, K компонентов

### Предлагаемое разбиение

| # | Часть | Сложность | Зависит от | Рекомендация |
|---|-------|-----------|------------|--------------|
| 1 | {title} | M | - | ✅ Фаза 1 |
| 2 | {title} | L | #1 | ✅ Фаза 2 |
| 3 | {title} | XL | #1, #2 |  Sub-issue |

### Граф зависимостей

PART-001 ──► PART-002 ──► PART-003
                └──────────► PART-004
```

### AskUserQuestion: Что делать со scope?

1. **✅ Принять разбиение**
   → Создать sub-issues для out_of_scope частей
   → Обновить спецификацию с планом фаз

2. ** Скорректировать вручную**
   → Запросить какие части перенести/оставить

3. **⏭️ Игнорировать (риск!)**
   → Продолжить без разбиения
   → Добавить warning в отчёт

### Создание Sub-issues для out_of_scope частей

Для каждой части с `recommendation: "out_of_scope_subissue"`:

```bash
gh issue create \
  --repo {owner}/{repo} \
  --title "[Part {id}] {title}" \
  --body "$(cat <<'EOF'
## Контекст
Выделено из спецификации: {ссылка на основную спеку}
Parent issue: #{parent_issue_number}

## Scope
{список элементов из scope}

## Сложность: {complexity}

## Зависимости
{depends_on или "Нет"}

## Описание
{description}

---
_Spec Review | {дата}_
EOF
)"
```

### Обновление основной спецификации

Если пользователь принял разбиение, добавить в документ:

```markdown
## План реализации

### Фаза 1 (текущая задача)
- [ ] {PART-001 title}
- [ ] {PART-002 title}

### Вынесено в отдельные задачи
- [ ] {PART-003 title} → #{issue_number}
- [ ] {PART-004 title} → #{issue_number}
```

---

## Фаза 5: Презентация результатов

### Формат отчёта

```markdown
##  Результаты ревью спецификации

**Документ:** [название/ссылка]
**Дата ревью:** [дата]
**Уровень:** ⚡ Quick |  Standard |  Deep |  Exhaustive
**Показаны проблемы:** severity ≥ {min_severity}
**Итерация:** {iteration} из {max_iterations}
**Агентов запущено:** {agents_count} из 10
**Статус:** ⏳ Требует доработки / ✅ Готова к аппруву

---

###  Оценка объёма

| Verdict | Complexity | Модели | Endpoints | Компоненты |
|---------|------------|--------|-----------|------------|
| ✅ Влезает / ⚠️ На грани / ❌ Слишком большая | S/M/L/XL | N | N | N |

**План реализации:** [Фаза 1: X, Фаза 2: Y] | [Sub-issues: #N, #M]

---

### Покрытие по трём осям (если запускался spec-axes)

| Фича | Что (PRD/US/AC) | Как (ERD/API/C4) | Проверка (Tests/AC) |
|------|-----------------|-------------------|---------------------|
| {feature.name} | {[OK]/[!]} {artifacts} | {[OK]/[!]} {artifacts} | {[OK]/[!]} {artifacts} |

**Полностью покрыты:** {fully_covered}/{total_features} ({percent}%)
**Частично:** {partially_covered}/{total_features}
**Без покрытия:** {not_covered}/{total_features}

---

###  Качество спецификации

| Источник |  Крит. |  Выс. |  Сред. |  Низ. |
|----------|----------|---------|----------|---------|
| ️ Data (DAT-*) | N | N | N | N |
|  API (API-*) | N | N | N | N |
| ️ Infra (INF-*) | N | N | N | N |
|  Analyst (BIZ-*) | N | N | N | N |
|  Test (TST-*) | N | N | N | N |
| ⚠️ Risk (RSK-*) | N | N | N | N |
|  UX (UX-*) | N | N | N | N |
|  AI-Readiness (AI-*) | N | N | N | N |
| Axes (AXS-*) | N | N | N | N |
| **Итого** | **N** | **N** | **N** | **N** |

*UX и AI-Readiness показываются только если соответствующие агенты были запущены*
*Axes показывается только если depth_level >= standard*

###  Критичные проблемы
[список]

###  Высокие проблемы
[список]

###  Средние проблемы
[список]

###  Рекомендации
[список]

### ℹ️ Скрыто на текущем уровне (если есть hidden_issues)
-  Medium: {N} проблем
-  Low: {M} рекомендаций

<details>
<summary>Заголовки скрытых проблем</summary>

- [{id}] {title}
- ...
</details>

> Для полного списка используй `--deep` или `--exhaustive`
```

### Empty state (если filtered_issues пуст)

```markdown
✅ На уровне {depth_level} проблем категории {min_severity} и выше не найдено.

Для более детального анализа используйте:
- `--standard` — покажет высокие проблемы
- `--deep` — покажет все проблемы включая средние
- `--exhaustive` — полный аудит с рекомендациями
```

### Если iteration > 1: Показать прогресс

```markdown
---

###  Прогресс между итерациями

| Итерация |  Крит. |  Выс. |  Сред. |  Низ. | Δ |
|----------|----------|---------|----------|---------|---|
| #1 | 3 | 5 | 4 | 2 | - |
| #2 | 1 | 2 | 4 | 2 | ✅ -5 |
| #3 (текущая) | 0 | 0 | 3 | 2 | ✅ -3 |

**Устранено за все итерации:** 8 критичных/высоких проблем
```

---

## Фаза 6: Процесс аппрува

### Для каждого замечания (начиная с критичных)

Используй **AskUserQuestion** с вариантами:

1. **✅ Принять и учесть в ТЗ**
   → Сформулировать изменения → внести в документ

2. ** Вынести в отдельную задачу**
   → Создать GitHub issue через `gh issue create`

3. **⏭️ Отклонить**
   → Запросить причину → добавить комментарий в спецификацию

### Создание GitHub issue для отложенного замечания

```bash
gh issue create \
  --repo {owner}/{repo} \
  --title "[Spec Review] {title}" \
  --body "$(cat <<'EOF'
## Контекст
Выявлено в ходе ревью: {ссылка на спеку}

## Тип: {type_emoji} {type}
## Severity: {severity_emoji} {severity}

## Описание
{description}

## Рекомендация
{recommendation}

---
_Spec Review | {дата}_
EOF
)"
```

---

## Фаза 6.5: Gate Check (ИТЕРАТИВНЫЙ ЦИКЛ)

После обработки всех замечаний в Фазе 6, выполни проверку.

### Условие запуска Gate Check (зависит от depth_level)

```python
if depth_level == "quick":
    # Пропустить gate check, сразу к финализации
    skip_to_phase_7()
else:
    # Выполнить gate check как обычно
    run_gate_check()
```

### Условия для повторной итерации

```python
# Подсчитай оставшиеся critical/high
remaining_critical = count(issues where severity == "critical" AND status != "fixed")
remaining_high = count(issues where severity == "high" AND status != "fixed")

has_blocking_issues = (remaining_critical > 0) OR (remaining_high > 0)
can_iterate = iteration < max_iterations
```

### Логика принятия решения

```
IF NOT has_blocking_issues:
    → Перейти к Фазе 7 (Финализация)

ELIF has_blocking_issues:
    → Показать оставшиеся критические/высокие
    → Спросить пользователя что делать (см. варианты ниже)
```

### Если остались критические/высокие проблемы

Используй **AskUserQuestion** с вариантами:

```markdown
## ⚠️ Остались нерешённые проблемы

| ID | Severity | Описание | Комментарий |
|----|----------|----------|-------------|
| {id} |  Critical | {description} | {comment} |
| ... | ... | ... | ... |

**Итерация:** {iteration} из {max_iterations}
```

**Варианты:**

1. ** Обработать оставшиеся индивидуально**
   → Вернуться к Фазе 6 для каждой оставшейся проблемы
   → Для каждой: принять/отложить/отклонить/переклассифицировать
   → После обработки — снова Gate Check

2. ** Полный ре-анализ спецификации**
   → Перечитать спецификацию (могла измениться)
   → Перейти к Фазе 2 (запуск всех 5 субагентов)
   → iteration += 1
   → ⚠️ Доступно только если iteration < max_iterations

3. **✅ Принять спецификацию как есть**
   → Добавить warning о нерешённых проблемах
   → Перейти к Фазе 7

4. **❌ Отменить ревью**
   → Завершить без аппрува

### Обработка индивидуальных проблем (вариант 1)

Для каждой оставшейся критической/высокой проблемы спросить:

```markdown
## Проблема: {id}

**Severity:** {severity_emoji} {severity}
**Тип:** {type_emoji} {type}
**Описание:** {description}
**Рекомендация:** {recommendation}
```

**Варианты:**

1. **✅ Принять и учесть в ТЗ**
   → Сформулировать изменения → внести в документ
   → Пометить как fixed

2. ** Вынести в отдельную задачу**
   → Создать GitHub issue
   → Пометить как deferred

3. **⬇️ Понизить severity**
   → Запросить новый уровень (medium/low)
   → Добавить обоснование в комментарий
   → Пометить как reclassified

4. **⏭️ Отклонить**
   → Запросить причину
   → Добавить комментарий в спецификацию
   → Пометить как rejected

После обработки всех → вернуться к Gate Check

### Сообщение при переходе к полному ре-анализу (вариант 2)

```markdown
---

##  Итерация {iteration} → {iteration + 1}

**Причина:** Остались критичные/высокие замечания

| Тип | Осталось | Исправлено в этой итерации |
|-----|----------|---------------------------|
|  Критичные | {N} | {M} |
|  Высокие | {N} | {M} |

**Перечитываю спецификацию и запускаю повторный анализ...**

---
```

Затем:
1. Перечитай спецификацию (она могла измениться)
2. Вернись к Фазе 2 (параллельный анализ)

---

## Фаза 7: Финализация

### Если нет критичных и высоких

```markdown
## ✅ Спецификация готова к аппруву

**Итераций потребовалось:** {iteration}
**Критичных и высоких замечаний:** 0

### Статистика ревью:
| Метрика | Значение |
|---------|----------|
| Всего выявлено проблем | N |
| Исправлено | M |
| Отложено (GitHub issues) | K |
| Отклонено | L |

### Несущественные рекомендации:
- [список оставшихся medium/low]

Принять спецификацию?
```

### При принятии

1. Добавь `[APPROVED]` в заголовок
2. Добавь метку аппрува:
   ```
   > **[Approved by @{github_username} {YYYY-MM-DD HH:MM}]**
   > Спецификация прошла архитектурное и бизнес-ревью.
   > Итераций: {iteration}. Исправлено проблем: {total_fixed}.
   ```

3. Получи username: `gh api user --jq '.login'`

4. В конце отчёта добавь футер с версией:
   ```
   ---
   _Spec Review v{VERSION} | {YYYY-MM-DD}_
   ```

---

## ID формат: `АГЕНТ-ТИП-XXX`

### Префиксы агентов

| Агент | Prefix | Фокус |
|-------|--------|-------|
| spec-data | `DAT-` | Модели данных, схемы БД |
| spec-api | `API-` | Endpoints, контракты |
| spec-infra | `INF-` | Безопасность, deployment |
| spec-analyst | `BIZ-` | Бизнес-логика, AC |
| spec-test | `TST-` | Тестируемость |
| spec-risk | `RSK-` | Риски |
| spec-ux | `UX-` | UX/UI (опционально) |
| spec-ai-readiness | `AI-` | Готовность для AI-агентов (опционально) |
| spec-axes | `AXS-` | Покрытие по осям |

### Префиксы типов проблем

**Общие типы (все агенты):**

| Тип | Prefix | Описание |
|-----|--------|----------|
| gap | `-GAP-` | Пропущенная информация |
| inconsistency | `-INC-` | Противоречие |
| ambiguity | `-AMB-` | Неоднозначность |
| infeasibility | `-FEA-` | Нереализуемость |
| unverifiability | `-VER-` | Непроверяемость |

**spec-test специфичные:**

| Тип | Prefix | Описание |
|-----|--------|----------|
| untestable | `-UNT-` | Невозможно написать тест |
| missing_edge_case | `-EDG-` | Не описан edge case |
| missing_precondition | `-PRE-` | Не определено начальное состояние |
| undefined_error | `-ERR-` | Не описано поведение при ошибке |

**spec-risk специфичные:**

| Тип | Prefix | Описание |
|-----|--------|----------|
| technical | `-TEC-` | Технический риск |
| business | `-BIZ-` | Бизнес-риск |
| operational | `-OPS-` | Операционный риск |
| schedule | `-SCH-` | Риск расписания |
| security | `-SEC-` | Риск безопасности |

**spec-ux специфичные:**

| Тип | Prefix | Описание |
|-----|--------|----------|
| flow | `-FLW-` | Неполный user flow |
| state | `-STA-` | Неописанное UI state |
| edge_case | `-EDG-` | Edge case в UI |
| accessibility | `-A11Y-` | Проблема доступности |
| responsive | `-RSP-` | Проблема responsive |

**spec-ai-readiness специфичные:**

| Тип | Prefix | Описание |
|-----|--------|----------|
| incomplete_context | `-CTX-` | Недостаточно контекста для AI |
| missing_examples | `-EXM-` | Нет примеров входа/выхода |
| undefined_boundary | `-BND-` | Не определены границы автономности |
| missing_escalation | `-ESC-` | Нет точек эскалации к человеку |
| unclear_success | `-SUC-` | Неясны критерии успеха |
| no_error_recovery | `-REC-` | Нет стратегии восстановления |
| context_overflow | `-OVF-` | Информация не влезет в контекст |

**spec-axes специфичные:**

| Тип | Prefix | Описание |
|-----|--------|----------|
| axis_gap_what | `-WHAT-` | Нет описания "что строим" |
| axis_gap_how | `-HOW-` | Нет описания "как строим" |
| axis_gap_verify | `-VRF-` | Нет описания "как проверяем" |

### Примеры ID

```
DAT-GAP-001   # Data: пропущено описание модели
API-INC-001   # API: противоречие в форматах
INF-AMB-001   # Infra: неоднозначное требование
BIZ-VER-001   # Business: непроверяемый критерий
TST-UNT-001   # Test: нетестируемое требование
TST-EDG-001   # Test: пропущенный edge case
RSK-TEC-001   # Risk: технический риск
RSK-BIZ-001   # Risk: бизнес-риск
UX-FLW-001    # UX: неполный user flow
UX-STA-001    # UX: неописанное UI state
AI-CTX-001    # AI: недостаточно контекста
AI-EXM-001    # AI: нет примеров для few-shot
AI-BND-001    # AI: не определены границы автономности
AI-ESC-001    # AI: нет точек эскалации
AI-SUC-001    # AI: неясны критерии успеха
AXS-WHAT-001  # Axes: нет User Story/требований для фичи
AXS-HOW-001   # Axes: нет архитектуры/ERD/API для фичи
AXS-VRF-001   # Axes: нет тестов/AC для фичи
```

## Символы для типов проблем

| Тип | Символ |
|-----|--------|
| gap | ️ |
| inconsistency | ⚡ |
| ambiguity |  |
| unverifiability |  |
| infeasibility |  |
| untestability |  |

## Символы для severity

| Severity | Символ |
|----------|--------|
| critical |  |
| high |  |
| medium |  |
| low |  |

---

## Error Handling (NEW in 1.9.0)

### EH-1: Ошибки парсинга флагов

| Ситуация | Поведение |
|----------|-----------|
| Неизвестный флаг (`--medium`) | Ошибка: "❌ Неизвестный уровень --medium. Доступные: --quick, --standard, --deep, --exhaustive" |
| Опечатка (`--quik`) | Ошибка + подсказка: " Возможно вы имели в виду --quick?" (Levenshtein distance ≤ 2) |
| Несколько флагов (`--quick --deep`) | Warning + использовать более глубокий: "⚠️ Указано несколько уровней, используется --deep" |

### EH-2: Ошибки источника

| Ситуация | Поведение |
|----------|-----------|
| Google Doc недоступен | Ошибка: "❌ Не удалось получить документ. Проверьте права доступа." |
| GitHub issue не найден | Ошибка: "❌ Issue #N не найден в репозитории." |
| Файл не существует | Ошибка: "❌ Файл {path} не найден." |
| Пустой документ (< 100 слов) | Warning: "⚠️ Документ слишком короткий для полного анализа. Использую --quick." |
| Сетевая ошибка | Ошибка: "❌ Сетевая ошибка. Попробуйте позже." |

### EH-3: Ошибки агентов

| Ситуация | Поведение |
|----------|-----------|
| Агент упал с ошибкой | Продолжить с остальными. В отчёте: "⚠️ Агент {name} недоступен, результаты неполные" |
| Все агенты упали | Ошибка: "❌ Не удалось выполнить анализ. Попробуйте позже." |
| Агент вернул невалидный severity | Преобразовать в medium, добавить warning в лог |
| Таймаут агента | Как ошибка агента — продолжить с остальными |

### EH-4: Конфликт ключевых слов

| Ситуация | Поведение |
|----------|-----------|
| "быстро и тщательно" | Спросить уровень через AskUserQuestion |
| Флаг + противоречащее слово | Флаг приоритетнее |

---

## Help (NEW in 1.9.0)

При вызове `/spec-review --help` показать:

```markdown
## /spec-review — Ревью спецификаций

### Уровни глубины

| Флаг | Короткий | Описание |
|------|----------|----------|
| --quick | -q | Только критические блокеры (2 агента, 1 итерация) |
| --standard | -s | Критические + высокие (default) |
| --deep | -d | Все проблемы включая средние |
| --exhaustive | -e | Полный аудит (все 9 агентов) |
| --no-ask | | Использовать standard без вопроса (для CI/CD) |

### Примеры

/spec-review --quick https://docs.google.com/document/d/xxx
/spec-review -d #42
/spec-review --no-ask docs/spec.md
/spec-review --exhaustive https://github.com/owner/repo/issues/123

### Ключевые слова в промпте

- "быстро проверь", "только блокеры" → --quick
- "тщательно", "подробно", "глубоко" → --deep
- "полный аудит", "исчерпывающий" → --exhaustive
```

---

## Интеграции

### GitHub Issues (gh CLI)

**Чтение:**
```bash
gh issue view <number> --repo owner/repo --json title,body
```

**Создание:**
```bash
gh issue create --repo owner/repo --title "..." --body "..."
```

**Комментарий:**
```bash
gh issue comment <number> --repo owner/repo --body "..."
```

### Google Docs (MCP)

**Чтение:**
```
mcp__google_workspace__get_doc_content
  documentId: "{DOCUMENT_ID}"
```

**Редактирование:**
```
mcp__google_workspace__modify_doc_text
  documentId: "{DOCUMENT_ID}"
  operations: [{"action": "insert", "text": "[APPROVED] ", "index": 1}]
```

---

## Чеклист

### Инициализация
- [ ] `iteration = 1` установлен
- [ ] `issues_history = []` инициализирован

### Фаза 0.5: Определение уровня глубины (NEW)
- [ ] Проверены флаги в $ARGUMENTS (--quick/-q, --deep/-d, --exhaustive/-e, --no-ask)
- [ ] Если неизвестный флаг → показана ошибка (EH-1)
- [ ] Если несколько флагов → warning + используется более глубокий
- [ ] Если нет флага → проверены ключевые слова в промпте
- [ ] Если конфликт ключевых слов → AskUserQuestion
- [ ] Если не определено и не --no-ask → AskUserQuestion (timeout 60s)
- [ ] `depth_level` и `min_severity` установлены
- [ ] Показано сообщение о выбранном уровне

### Фаза 1: Получение спецификации
- [ ] Спецификация получена
- [ ] Если ошибка доступа → показана ошибка (EH-2)
- [ ] Если документ < 100 слов → warning + переключение на quick

### Фаза 1.5: Классификация + Quick Scope (пропускается для quick)
- [ ] Если depth_level == "quick" → пропустить к Фазе 2
- [ ] Если depth_level == "exhaustive" → agents_to_run = все 9
- [ ] Иначе → запустить spec-classifier (haiku)
- [ ] Получен JSON с classification + quick_scope
- [ ] Если verdict = "too_large" или "borderline" — спрошен пользователь
- [ ] Если нужен breakdown — добавлен spec-scoper в список агентов

### Цикл анализа (повторяется до iteration <= max_iterations[depth_level])
- [ ] Если depth_level == "quick" → только 2 агента (spec-analyst, spec-test)
- [ ] Если depth_level == "exhaustive" → все 9 агентов
- [ ] Иначе → 2 обязательных + условные по classifier
- [ ] Если depth_level >= standard -> spec-axes запущен параллельно с остальными
- [ ] Все агенты запущены ПАРАЛЛЕЛЬНО в одном сообщении
- [ ] Результаты получены и распарсены
- [ ] Если ошибка агента → продолжить с остальными + warning (EH-3)
- [ ] Результаты отфильтрованы по min_severity
- [ ] Скрытые проблемы подсчитаны (hidden_by_severity)
- [ ] **Scope обработан (только на iteration == 1, если scope_analysis_enabled):**
  - [ ] Если too_large/borderline — показан breakdown
  - [ ] Пользователь выбрал стратегию
  - [ ] Sub-issues созданы для out_of_scope частей
  - [ ] План фаз добавлен в спецификацию
- [ ] Отчёт сформирован с номером итерации
- [ ] Показан прогресс (если iteration > 1)
- [ ] Критичные и высокие замечания обработаны
- [ ] GitHub issues созданы для отложенных задач
- [ ] Причины отклонений задокументированы

### Gate Check (после каждой итерации, пропускается для quick)
- [ ] Если depth_level == "quick" → пропустить к Фазе 7
- [ ] Подсчитаны оставшиеся critical/high (в пределах min_severity)
- [ ] Если есть — показана таблица оставшихся проблем
- [ ] Пользователь выбрал действие:
  - [ ]  Индивидуальная обработка → Фаза 6 для каждой → Gate Check
  - [ ]  Полный ре-анализ → Фаза 2 (если iteration < max)
  - [ ] ✅ Принять как есть → Фаза 7 с warning
  - [ ] ❌ Отмена → завершение
- [ ] `issues_history.push(current_issues)` для отслеживания прогресса

### Финализация
- [ ] Все critical/high устранены ИЛИ пользователь принял как есть
- [ ] Матрица покрытия по осям показана (если spec-axes запускался)
- [ ] Статистика ревью показана
- [ ] Спецификация помечена [APPROVED] (если применимо)
- [ ] Указано количество итераций и исправленных проблем

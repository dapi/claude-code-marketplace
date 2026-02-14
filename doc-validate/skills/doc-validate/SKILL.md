---
name: doc-validate
description: |
  **UNIVERSAL TRIGGER**: Validate/check/lint documentation quality.

   **Formatting**: "validate docs", "doc lint", "проверь документацию"
   **Links**: "broken links", "orphan docs", "битые ссылки"
   **Terms**: "check glossary", "терминология", "synonyms"
   **Viewpoints**: "check artifacts", "state diagrams", "threat model"
  ⚡ **Contradictions**: "find conflicts", "противоречия"
  ️ **Gaps**: "missing coverage", "пробелы", "completeness"
   **Review**: "full audit", "полный аудит", "/doc:review"

  TRIGGERS: doc lint, validate docs, проверь документацию, broken links,
  orphan, glossary, viewpoints, contradictions, gaps, coverage,
  /doc:lint, /doc:links, /doc:terms, /doc:viewpoints,
  /doc:contradictions, /doc:gaps, /doc:review
allowed-tools: Bash, Read, Glob, Grep, Write, Edit
---

# Documentation Validation Skill

Комплекс команд `/doc:*` для автоматической и интерактивной проверки качества проектной документации.

## Быстрый старт

```bash
# Быстрая проверка перед коммитом
/doc:lint

# Проверка графа связей
/doc:links

# Полный аудит (все проверки)
/doc:review
```

## Команды

### `/doc:lint` — Проверка форматирования

**Модель**: haiku (быстро, дёшево)
**Время**: < 30 сек для 100 файлов

**Проверки**:
- Битые внутренние ссылки `[text](file.md)`
- Несуществующие файлы в навигации
- Нарушения naming conventions (`NN_TITLE.md` для корневых)
- Пустые секции (## без контента)
- TODO/FIXME без ссылки на issue
- Отсутствие обязательных секций

**Пример вывода**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 [LINT-001] Битая ссылка
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 03_REQUIREMENTS.md:45
   > [см. архитектуру](architecture/MISSING.md)

❌ Файл не существует: architecture/MISSING.md

[f]ix  [s]kip  [i]gnore  [e]dit  [g]ithub issue  [x]plain
> _
```

### `/doc:links` — Граф связей

**Модель**: haiku
**Время**: < 30 сек для 100 файлов

**Проверки**:
- Orphan-документы (без входящих ссылок)
- Dead-ends (без исходящих ссылок)
- Циклические зависимости
- Полнота навигации в README

**Исключения** (не считаются orphans/dead-ends):
- README.md, CHANGELOG.md
- **/GLOSSARY.md, **/INDEX.md
- Конфигурируется в `.docvalidate.yml`

**Пример вывода**:
```
 Граф документации
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Всего документов: 35
Связей: 128

⚠️ Orphans (нет входящих ссылок):
  - research/old_analysis.md
  - data/transaction-analysis.md

⚠️ Dead-ends (нет исходящих ссылок):
  - architecture/wallet/COMPONENTS.md

✅ README навигация: 28/35 документов (80%)
```

### `/doc:terms` — Терминология ✅

**Модель**: sonnet (или haiku для базовых проверок)
**Требует**: глоссарий в `02_GLOSSARY.md`

**Проверки**:
- Термины из глоссария используются единообразно
- Обнаружение запрещённых синонимов (кошелёк/wallet/бумажник)
- Новые термины не в глоссарии (выделенные **bold**)
- Покрытие глоссария (% используемых терминов)

**Пример вывода**:
```
 Загружен глоссарий: 16 терминов
 Запрещённых синонимов: 5 групп

Сканирование 24 файлов...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 [TERM-001] Запрещённый синоним
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 08_KEY_SECURITY.md:82
   Запрещённый синоним: "wallet" → используйте "кошелёк"

 Покрытие глоссария
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Используется: 14/16 терминов (87%)
```

### `/doc:viewpoints` — Артефакты ✅

**Модель**: sonnet

**Проверки по viewpoints**:

| Viewpoint | Артефакт | Приоритет |
|-----------|----------|-----------|
| Data | STATE_MACHINES.md |  must |
| Data | DATA_FLOWS.md |  should |
| Business Rules | BUSINESS_RULES.md |  must |
| Security | THREAT_MODEL.md |  must (критично для крипто) |
| Integration | EVENT_CATALOG.md |  should |
| Traceability | RTM.md |  should |

**Пример вывода**:
```
## Покрытие Viewpoints

| Viewpoint | Артефакт | Статус | Файл |
|-----------|----------|--------|------|
| Data | STATE_MACHINES | ✅ | architecture/STATE_MACHINES.md |
| Data | DATA_FLOWS | ❌ | architecture/DATA_FLOWS.md |
| Security | THREAT_MODEL | ✅ | architecture/THREAT_MODEL.md |

 Общее покрытие viewpoints: 3/6 (50%)

 Security viewpoint не полностью покрыт — критично для крипто-системы!
```

### `/doc:contradictions` — Противоречия ✅

**Модель**: sonnet (локальный анализ)
**Время**: < 60 сек для 100 файлов

**Проверки**:
- Конфликтующие значения (разные числа для одного параметра)
- Взаимоисключающие требования
- Решения противоречащие ограничениям
- Числовые параметры с разными значениями в разных документах

**Пример вывода**:
```
⚡ /doc:contradictions — Поиск противоречий

 Извлечение параметров из документации...
   Найдено 194 параметров в 25 файлах

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 КРИТИЧНЫЕ ПРОТИВОРЕЧИЯ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 [CONTRADICTION-001] Параметр "confirmations" имеет разные значения
    03_REQUIREMENTS.md:45 → 3
    architecture/FLOWS.md:128 → 6
   ⚠️ Разница: 100%

 [CONTRADICTION-002] Параметр "hot_wallet_limit" имеет разные значения
    03_REQUIREMENTS.md:52 → 10%
    08_KEY_SECURITY.md:23 → 5%
   ⚠️ Разница: 100%

 Итого: 8 критичных, 10 предупреждений
```

### `/doc:gaps` — Полнота ✅

**Модель**: sonnet (локальный анализ)
**Время**: < 60 сек для 100 файлов

**Проверки**:
- Упомянутые но не раскрытые темы
- Требования без acceptance criteria
- Сущности без полного описания артефактов
- Интеграции без Event Catalog

**Пример вывода**:
```
️ /doc:gaps — Анализ полноты покрытия

 Сканирование документации на гапы...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ПРЕДУПРЕЖДЕНИЯ (требуют внимания)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 [GAP-001] Найдены интеграции (69), но нет Event Catalog
    architecture/EVENT_CATALOG.md — отсутствует
    Рекомендация: создайте EVENT_CATALOG.md для документирования событий

 Итого: 0 критичных, 1 предупреждение
```

### `/doc:review` — Полный аудит ✅

**Модель**: все (каскад)
**Время**: < 5 мин для 100 файлов

Запускает все проверки в оптимальном порядке:
1. lint + links (Phase 1: базовые)
2. terms + viewpoints (Phase 2: семантические)
3. contradictions + gaps (Phase 3: глубокий анализ)

**Функции**:
- Агрегация результатов всех команд
- Сводная таблица по категориям
- Сравнение с предыдущим запуском
- Рекомендации по приоритетам
- Общая оценка качества (0-100)

**Пример вывода**:
```
╔══════════════════════════════════════════════════════════════╗
║                ИТОГОВЫЙ ОТЧЁТ DOC:REVIEW                   ║
╚══════════════════════════════════════════════════════════════╝

┌────────────────┬──────────┬──────────┬──────────┐
│ Команда        │  Крит. │  Важн. │  Инфо  │
├────────────────┼──────────┼──────────┼──────────┤
│ lint           │        0 │        6 │       92 │
│ links          │        0 │        0 │        0 │
│ terms          │        0 │      194 │       10 │
│ viewpoints     │        0 │        3 │        0 │
│ contradictions │        8 │       10 │        0 │
│ gaps           │        0 │        1 │        0 │
├────────────────┼──────────┼──────────┼──────────┤
│ ИТОГО          │        8 │      214 │      102 │
└────────────────┴──────────┴──────────┴──────────┘

 Покрытие viewpoints: 3/6 (50%)
 Покрытие глоссария: 94%

⏱️  Время выполнения: 0.4 сек

 Рекомендации:
  •  Исправьте 8 критических проблем в первую очередь
  • ⚡ Разрешите противоречия в числовых параметрах
  •  Увеличьте покрытие viewpoints (сейчас 50%)

╔══════════════════════════════════════╗
║      ОБЩАЯ ОЦЕНКА: 85/100 (B)      ║
╚══════════════════════════════════════╝
```

## CLI режимы

```bash
# Стандартный режим (вывод без интерактива)
./doc_validate.rb lint

# Интерактивный режим (промпт для каждой проблемы)
./doc_validate.rb lint --interactive

# Batch режим для CI/CD (без вывода, с exit codes)
./doc_validate.rb lint --batch
# Exit codes: 0=ok, 1=warnings, 2=critical
```

## Интерактивный режим

Активация: `--interactive` или `-i`

При обнаружении проблемы:

| Клавиша | Действие | Описание |
|---------|----------|----------|
| `f` | fix | Применить автоисправление (если доступно) |
| `s` | skip | Пропустить, не исправлять сейчас |
| `i` | ignore | Добавить в `.docignore` |
| `e` | edit | Открыть файл в $EDITOR |
| `x` | explain | Подробнее объяснить проблему |

### Доступные автоисправления

| Тип проблемы | Действие fix |
|--------------|--------------|
| broken_link | Fuzzy search похожих файлов или удаление ссылки |
| synonym | Замена на canonical термин |
| empty_section | Удаление пустой секции (с подтверждением) |

### Edge Cases

| Ситуация | Поведение |
|----------|-----------|
| fix недоступен | Показать "(fix unavailable)" |
| Ctrl+C | Сохранить прогресс в session.json |

## Конфигурация

Файл `.docvalidate.yml` в корне проекта:

```yaml
version: 1

# Глоссарий
glossary:
  file: "02_GLOSSARY.md"
  forbidden_synonyms:
    - ["кошелёк", "wallet", "бумажник"]
    - ["транзакция", "tx", "перевод"]

# Scope проверки
scope:
  strict:
    - "*.md"
    - "architecture/**/*.md"
  relaxed:
    - "research/**/*.md"
    trigger: on_change
  ignore:
    - "claudedocs/**"

# Исключения для orphan/dead-end
link_exceptions:
  not_orphans:
    - "README.md"
    - "CHANGELOG.md"
    - "**/GLOSSARY.md"

# Naming conventions
formatting:
  root_naming: "^[0-9]{2}_[A-Z_]+\\.md$"
```

## Data Model

### `.docvalidate/.docignore` — игнорируемые проблемы

Формат: JSON Lines

```jsonl
{"id": "LINT-001", "file": "research/old.md", "reason": "Архивный", "created": "2025-01-30"}
```

### `.docvalidate/history.json` — история метрик

```json
{
  "runs": [{
    "timestamp": "2025-01-30T10:30:00Z",
    "metrics": {"critical": 2, "warning": 5, "info": 8}
  }]
}
```

## Error Handling

### Fallback chain для AI

```
opus (недоступен) → sonnet → haiku → native (без AI)
```

### Offline mode

При `--offline` или отсутствии сети:
- ✅ `/doc:lint` — работает полностью
- ✅ `/doc:links` — работает полностью
- ⚠️ `/doc:terms` — только forbidden_synonyms
- ❌ `/doc:contradictions` — недоступна
- ❌ `/doc:gaps` — недоступна

## Приоритеты проблем

| Приоритет | Категории |
|-----------|-----------|
|  Критичные | contradictions, gaps, missing_threat_model |
|  Важные | duplicates, terms, missing_state_diagrams |
|  Информация | broken_links, formatting, orphans |

## Ограничения текущей версии (v1.1.0)

| Функция | Статус | Примечание |
|---------|--------|------------|
| Интерактивный режим | ✅ | f/s/i/e/x работают |
| Batch mode + exit codes | ✅ | Для CI/CD |
| Автоисправления | ✅ | broken_link, synonym, empty_section |
| Mermaid граф | ❌ Roadmap | Визуализация link graph |
| Session recovery | ❌ Roadmap | Возобновление после Ctrl+C |
| Unit-тесты | ❌ Roadmap | Покрытие 0% |

## Связанная документация

- [Issue #7](https://github.com/BrandyMint/WalletSystem/issues/7) — Основная спецификация
- [Issue #12](https://github.com/BrandyMint/WalletSystem/issues/12) — План доработок

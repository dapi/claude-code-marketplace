# spec-reviewer

Плагин ревью спецификаций для Claude Code.
Ищет гапы, противоречия, неоднозначности, проблемы тестируемости и риски scope до начала реализации.

## Установка

```bash
/plugin install spec-reviewer@dapi
```

## Быстрый старт

```bash
/spec-review docs/spec.md
/spec-review --quick #42
/spec-review --deep https://docs.google.com/document/d/<DOC_ID>/edit
/spec-review --standard https://docs.company.com/p/<PAGE_ID>
```

## Поддерживаемые источники

- Google Docs URL
- GitHub Issue URL или `#number`
- URL страницы Docmost (чтение приоритетно через MCP Docmost)
- локальный путь к файлу
- вставленный в чат текст спецификации

## Уровни ревью: чем отличаются

| Уровень | Флаги | Что показываем | Classifier | Стратегия агентов | Gate Check | Итераций |
|---|---|---|---|---|---|---|
| Quick | `--quick`, `-q` | только `critical` | пропускается | только `spec-analyst` + `spec-test` | нет | 1 |
| Standard (default) | `--standard`, `-s` | `critical` + `high` | да | базовые + `spec-axes` + условные доменные (+`spec-scoper` при необходимости) | да | 2 |
| Deep | `--deep`, `-d` | `critical` + `high` + `medium` | да | как в Standard, но с более широким окном severity | да | 3 |
| Exhaustive | `--exhaustive`, `-e` | полный аудит, включая `low` | да (только для scope) | базовые + `spec-axes` + все доменные (+`spec-scoper` при необходимости) | да | 3 |

Дополнительно:
- `--no-ask` — пропустить вопрос выбора уровня и сразу запускать `standard`.
  Это не режим автопилота: спецификация не меняется сама.

### Что именно меняется между уровнями

Таблица выше уже объединяет все параметры: порог severity, число итераций, classifier, gate-check и стратегию подскиллов.

### Комбинация подскиллов

База:
- `spec-analyst`
- `spec-test`

Начиная со Standard:
- `spec-axes`

Доменные агенты:
- в `standard/deep` выбираются classifier-ом по содержимому спеки;
- в `exhaustive` включаются все: `spec-data`, `spec-api`, `spec-infra`, `spec-risk`, `spec-ux`, `spec-ai-readiness`.

`spec-scoper`:
- включается при `borderline` или `too_large`.

## Диаграмма процесса ревью

```mermaid
flowchart TD
    A["/spec-review"] --> B["Выбор глубины<br/>(flags -> keywords -> ask -> default)"]

    B -->|"quick"| C["Subagents для quick:<br/>spec-analyst + spec-test"]
    B -->|"standard / deep / exhaustive"| D["Запустить spec-classifier<br/>+ quick scope"]

    D --> E{"Вердикт scope"}
    E -->|"fits"| F{"Режим глубины"}
    E -->|"borderline / too_large"| G["Спросить стратегию декомпозиции<br/>+ запустить spec-scoper"]
    G --> F

    F -->|"standard / deep"| H["Subagents:<br/>база: spec-analyst + spec-test + spec-axes<br/>доменные (по classifier): spec-data/spec-api/spec-infra/spec-risk/spec-ux/spec-ai-readiness"]
    F -->|"exhaustive"| I["Subagents:<br/>база: spec-analyst + spec-test + spec-axes<br/>все доменные: spec-data + spec-api + spec-infra + spec-risk + spec-ux + spec-ai-readiness"]

    C --> J["Параллельный запуск выбранных subagents"]
    H --> J
    I --> J

    J --> K["Агрегация замечаний<br/>+ фильтр по уровню глубины"]
    K --> L["Решение по каждому замечанию:<br/>fixed / deferred / reclassified / rejected / custom->mapped"]
    L --> M["Gate check"]

    M -->|"Нет blocking critical/high"| N["Финализация / аппрув"]
    M -->|"Остались blocking + iter < max"| O["Следующая итерация"]
    O --> J
    M -->|"Принять как есть или отменить"| P["Завершение с warning/отменой"]
```

## Короткая диаграмма жизненного цикла замечания

```mermaid
flowchart LR
    A["Замечание найдено subagent-ом<br/>(spec-analyst/spec-test/spec-axes/<br/>spec-data/spec-api/spec-infra/spec-risk/spec-ux/spec-ai-readiness)"] --> B{"Решение"}

    B -->|"fixed"| C["Внести правку в спецификацию"]
    B -->|"deferred"| D["Создать GitHub issue"]
    B -->|"reclassified"| E["Понизить severity и оставить tracked item"]
    B -->|"rejected"| F["Пометить rejected + зафиксировать причину"]
    B -->|"custom"| G["Смаппить в fixed/deferred/reclassified/rejected"]

    G --> C
    G --> D
    G --> E
    G --> F

    C --> H["Gate check"]
    D --> H
    E --> H
    F --> H

    H --> I{"Есть blocking<br/>critical/high?"}
    I -->|"да"| J["Доработка / новая итерация"]
    I -->|"нет"| K["Финализация"]
```

## Агенты

| Агент | Назначение |
|---|---|
| `spec-classifier` | маршрутизация агентов + quick оценка объёма |
| `spec-analyst` | бизнес-логика, AC, роли |
| `spec-test` | тестируемость и edge-cases |
| `spec-axes` | покрытие по осям What/How/Verify |
| `spec-data` | модели данных и миграции |
| `spec-api` | API/контракты/интеграции |
| `spec-infra` | security/NFR/deploy |
| `spec-risk` | тех/бизнес/операционные риски |
| `spec-ux` | UX/UI состояния и флоу |
| `spec-ai-readiness` | готовность спецификации для AI-агентов |
| `spec-scoper` | декомпозиция большого scope |

## Документация

- [Workflow команды](./commands/spec-review.md)
- [Описание skill](./skills/spec-review/SKILL.md)
- [Альтернативы](./ALTERNATIVES.md)

## Лицензия

MIT

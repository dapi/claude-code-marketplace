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

| Уровень | Флаги | Что показываем | Итераций |
|---|---|---|---|
| Quick | `--quick`, `-q` | только `critical` | 1 |
| Standard (default) | `--standard`, `-s` | `critical` + `high` | 2 |
| Deep | `--deep`, `-d` | `critical` + `high` + `medium` | 3 |
| Exhaustive | `--exhaustive`, `-e` | полный аудит, включая `low` | 3 |

Дополнительно:
- `--no-ask` — не задавать вопрос про уровень, запускать `standard`.

### Что именно меняется между уровнями

Уровень влияет на:
1. порог severity в отчёте,
2. число итераций,
3. включённость classifier/gate-check/scope-analysis,
4. набор запускаемых подскиллов.

| Уровень | Classifier | Стратегия агентов | Gate Check |
|---|---|---|---|
| Quick | пропускается | только `spec-analyst` + `spec-test` | нет |
| Standard | да | базовые + `spec-axes` + условные доменные (+`spec-scoper` при необходимости) | да |
| Deep | да | как в Standard, но с более широким окном severity | да |
| Exhaustive | да (только для scope) | базовые + `spec-axes` + все доменные (+`spec-scoper` при необходимости) | да |

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

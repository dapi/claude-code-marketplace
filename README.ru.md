# Dapi Claude Code Marketplace

Персональный маркетплейс плагинов Claude Code для рабочих процессов разработки.

**[English version](README.md)**

## Установка

```bash
# Добавить маркетплейс
/plugin marketplace add dapi/claude-code-marketplace

# Установить плагины
/plugin install github-workflow@dapi
/plugin install bugsnag-skill@dapi
# и т.д.
```

## Плагины

| Плагин | Описание | Компоненты |
|--------|----------|------------|
| [bugsnag-skill](#bugsnag-skill) | Интеграция с Bugsnag API: ошибки, организации, проекты | 1 навык |
| [cluster-efficiency](#cluster-efficiency) | Анализ эффективности ресурсов Kubernetes кластера | 5 агентов, 1 навык, 1 команда |
| [doc-validate](#doc-validate) | Валидация качества документации | 1 навык, 1 команда |
| [github-workflow](#github-workflow) | GitHub issues, PR, worktrees, sub-issues | 1 навык, 2 команды |
| [himalaya](#himalaya) | Email через Himalaya CLI (IMAP/SMTP) | 1 навык |
| [long-running-harness](#long-running-harness) | Управление проектами между сессиями | 1 навык |
| [media-upload](#media-upload) | Загрузка медиа/изображений в S3 | 1 навык |
| [requirements](#requirements) | Реестр требований через Google Sheets | 1 команда |
| [spec-reviewer](#spec-reviewer) | Ревью и анализ спецификаций | 10 агентов, 1 навык, 1 команда |
| [task-router](#task-router) | Классификация задач и маршрутизация в workflow | 1 агент, 1 навык, 1 команда |
| [zellij-dev-tab](#zellij-dev-tab) | Разработка issue в отдельной вкладке Zellij | 1 навык |
| [zellij-tab-claude-status](#zellij-tab-claude-status) | Статус сессии Claude во вкладке Zellij | хуки |

### github-workflow

Рабочий процесс GitHub: issues, PR, worktrees, sub-issues.

**Компоненты:** навык `github-issues`, команды `/start-issue`, `/fix-pr`

```
/start-issue https://github.com/owner/repo/issues/123
"прочитай issue #45"
"создай sub-issue для #123"
```

### zellij-dev-tab

Запуск разработки GitHub issue в отдельной вкладке Zellij.

**Компоненты:** навык `zellij-dev-tab`

```
"запусти разработку issue #45 в новой вкладке"
"start issue in new tab"
```

### zellij-tab-claude-status

Индикатор статуса Claude в заголовке вкладки Zellij.
Требуется плагин [zellij-tab-status](https://github.com/dapi/zellij-tab-status).

**Иконки:** `◉` Работает | `○` Готов | `✋` Ждёт ввода

### bugsnag-skill

Интеграция с Bugsnag API: просмотр и управление ошибками, организациями, проектами.

**Компоненты:** навык `bugsnag`

**Требуется:** `BUGSNAG_DATA_API_KEY`, `BUGSNAG_PROJECT_ID`

```
"показать bugsnag ошибки"
"bugsnag детали для error_123"
"show bugsnag errors"
```

### spec-reviewer

Ревью спецификаций: анализ на гапы, нестыковки, противоречия и оценка объёма.

**Компоненты:** команда `/spec-review`, 10 агентов

**Агенты:** classifier, analyst, api, ux, data, infra, test, scoper, risk, ai-readiness

```
/spec-review path/to/spec.md
"проверь спецификацию docs/spec.md"
```

### task-router

Классификация задач и маршрутизация в workflow. Получает задачу по URL, определяет сложность и направляет в оптимальный workflow разработки.

**Компоненты:** команда `/route-task`, навык `task-routing`, агент `task-classifier`

**Требуются:** плагины `feature-dev`, `superpowers`

| Сложность | Маршрут |
|-----------|---------|
| S/M | feature-dev |
| L/XL (архитектура ясна) | subagent-driven-dev |
| L/XL (нужно исследование) | needs-spec + brainstorming |

```
/route-task https://github.com/org/repo/issues/42
/route-task https://docs.google.com/document/d/1abc/edit
"возьми задачу #123"
"реализуй по спеке https://..."
```

### cluster-efficiency

Анализ эффективности ресурсов Kubernetes кластера: утилизация, Karpenter, OOM, workloads.

**Компоненты:** команда `/cluster-efficiency`, навык `cluster-efficiency`, 5 агентов

**Агенты:** orchestrator, node-analyzer, workload-analyzer, karpenter-analyzer, oom-analyzer

```
/cluster-efficiency
"проанализируй эффективность кластера"
```

### doc-validate

Валидация качества документации: битые ссылки, orphan-документы, глоссарий, структура.

**Компоненты:** команда `/doc-validate`, навык `doc-validate`

```
/doc-validate docs/
"проверь документацию"
"validate docs"
```

### media-upload

Загрузка изображений и медиафайлов в S3. Автоматически активируется после скриншотов Playwright.

**Компоненты:** навык `media-upload`

```
"загрузить файл в s3"
"upload image to s3"
```

### long-running-harness

Управление долгосрочными проектами разработки между сессиями.

**Компоненты:** навык `long-running-harness`

```
"начать новый проект [описание]"
"продолжить работу над проектом"
```

### himalaya

Email через [Himalaya CLI](https://github.com/pimalaya/himalaya) (IMAP/SMTP).

**Компоненты:** навык `himalaya`

```
"проверить почту"
"отправить письмо на user@example.com"
"check my email"
```

### requirements

Реестр требований проекта через Google Spreadsheet с синхронизацией GitHub issues.

**Компоненты:** команда `/requirements`

```
/requirements init
/requirements status
/requirements sync
```

## Зависимости

Некоторые плагины требуют внешних инструментов:

| Инструмент | Плагины | Установка |
|------------|---------|-----------|
| [gh CLI](https://cli.github.com) | github-workflow, requirements | `brew install gh` |
| [Himalaya](https://github.com/pimalaya/himalaya) | himalaya | `brew install himalaya` |
| [zellij-tab-status](https://github.com/dapi/zellij-tab-status) | zellij-tab-claude-status | См. README плагина |
| Ruby 3.0+ | bugsnag-skill, doc-validate | — |

## Скрипты

### start-issue

Начало работы над GitHub issue: создаёт worktree, переименовывает вкладку zellij, запускает Claude.

```bash
start-issue 123
start-issue https://github.com/owner/repo/issues/123
```

Подробности в `scripts/start-issue`.

## Разработка

```bash
make version        # Показать текущую версию
make release        # Релиз minor-версии
make release-patch  # Релиз patch-версии
make update-plugin  # Обновить плагин (после git pull)
make reinstall      # Полная переустановка
```

## Лицензия

MIT — [Danil Pismenny](https://github.com/dapi)

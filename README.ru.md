# Dapi Claude Code Marketplace

Персональный маркетплейс плагинов Claude Code для рабочих процессов разработки.

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

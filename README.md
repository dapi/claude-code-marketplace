# Dapi Claude Code Marketplace

Personal marketplace of Claude Code plugins for development workflows.

## Installation

```bash
# Add marketplace
/plugin marketplace add dapi/claude-code-marketplace

# Install plugin
/plugin install dev-tools@dapi
```

## Dependencies

Some skills require GitHub CLI extensions:

| Extension | Purpose | Install |
|-----------|---------|---------|
| [gh-pmu](https://github.com/rubrical-studios/gh-pmu) | Project management, sub-issues, batch ops | `gh extension install rubrical-studios/gh-pmu` |
| [gh-sub-issue](https://github.com/yahsan2/gh-sub-issue) | Parent-child issue relationships | `gh extension install yahsan2/gh-sub-issue` |

## dev-tools Plugin

### Commands

| Command | Description |
|---------|-------------|
| `/dev-tools:start-issue <url>` | Start work on GitHub issue (creates worktree + branch) |
| `/dev-tools:fix-pr` | Iterative PR review & fix cycle until clean |
| `/dev-tools:requirements <action>` | Manage requirements via Google Spreadsheet |

#### start-issue

```bash
/dev-tools:start-issue https://github.com/owner/repo/issues/123
```

Creates git worktree in `~/worktrees/<type>/<number>-<slug>` with proper branch naming (`feature/`, `fix/`, `chore/`).

#### fix-pr

```bash
/dev-tools:fix-pr                    # up to 5 iterations
/dev-tools:fix-pr --max-iterations=3
```

Runs 4 review agents in parallel (code-reviewer, pr-test-analyzer, silent-failure-hunter, comment-analyzer), fixes critical/important issues, repeats until clean.

**Requires:** `pr-review-toolkit@claude-code-plugins`

#### requirements

```bash
/dev-tools:requirements init    # Create project spreadsheet
/dev-tools:requirements status  # Show summary
/dev-tools:requirements sync    # Sync with GitHub issues
/dev-tools:requirements add "Feature title"
```

### Skills (auto-activate)

Skills автоматически активируются когда Claude распознаёт соответствующий контекст в запросе пользователя.

#### bugsnag

Полная интеграция с Bugsnag API для мониторинга и управления ошибками в продакшене.

**Возможности:**
- 📊 Просмотр организаций и проектов
- 🐛 Получение списка ошибок с фильтрацией по severity
- 🔍 Детальный контекст ошибки (stack trace, события, timeline)
- 💬 Просмотр комментариев к ошибкам
- 📈 Анализ паттернов и статистика
- ✅ Управление статусами (mark as resolved)

**Триггеры:** `show bugsnag errors`, `list bugsnag projects`, `bugsnag details for <id>`, `что в bugsnag`, `ошибки bugsnag`, `закрыть ошибку`

**Требует:** `BUGSNAG_DATA_API_KEY` и `BUGSNAG_PROJECT_ID` в переменных окружения.

---

#### github-issues

Управление GitHub issues через `gh` CLI с поддержкой sub-issues и атомарных операций над checkboxes.

**Возможности:**
- 📖 Чтение issues (body, comments, labels)
- ✅ Атомарная отметка checkboxes (безопасно для параллельной работы)
- 🔗 Работа с sub-issues (create, link, list)
- 📝 Редактирование issues (title, body, labels)
- 🖼️ Скачивание прикреплённых изображений

**Триггеры:** любой URL вида `github.com/.../issues/...`, `read issue #N`, `mark checkbox done`, `create sub-issue`, `прочитай issue`, `отметь пункт выполненным`

**Важно:** Использует только `gh` CLI, никогда WebFetch. Поддерживает атомарные операции для безопасной параллельной работы нескольких агентов.

---

#### long-running-harness

Управление долгосрочными проектами через несколько сессий Claude. Основан на [исследовании Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

**Решает проблемы:**
- ❌ Потеря контекста между сессиями
- ❌ Попытки сделать всё за одну сессию
- ❌ Преждевременное объявление проекта готовым
- ❌ Недокументированный прогресс

**Режимы работы:**
- 🚀 `init` — Создание структуры проекта (features.json, progress.md, init.sh)
- 🔄 `continue` — Продолжение работы с автоматическим startup checklist
- 📊 `status` — Просмотр прогресса и оставшихся фич

**Артефакты:**
- `.claude/features.json` — 30-200 фич с verification steps
- `.claude/progress.md` — Лог всех сессий
- `scripts/init.sh` — Setup окружения + smoke test

**Триггеры:** `init long-running project`, `continue project`, `продолжить работу`, `статус проекта`, `next feature`

## Development

```bash
make version        # Show current version
make release        # Release minor version (1.3.0 → 1.4.0)
make release-patch  # Release patch (1.3.0 → 1.3.1)
make update         # Update marketplace + plugin
make reinstall      # Full reinstall
```

## Structure

```
claude-code-marketplace/
├── dev-tools/
│   ├── commands/
│   │   ├── fix-pr.md
│   │   ├── requirements.md
│   │   └── start-issue.md
│   ├── skills/
│   │   ├── bugsnag/           # Bugsnag API интеграция
│   │   ├── github-issues/     # GitHub issues через gh CLI
│   │   └── long-running-harness/  # Multi-session проекты
│   └── README.md
├── Makefile
└── README.md
```

## License

MIT — [Danil Pismenny](https://github.com/dapi)

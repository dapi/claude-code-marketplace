# zellij-workflow

[English](./README.md) | [Русский](./README.ru.md)

Единый плагин рабочего процесса Zellij: индикаторы статуса вкладок, вкладки/панели общего назначения и вкладки разработки issue.

## Возможности

### Индикаторы статуса вкладки

Автоматически показывает состояние Claude-сессии через префикс в имени вкладки:

| Иконка | Состояние | Описание |
|-|-|-|
| `○` | Готов | Ждёт ввода |
| `◉` | Работает | Обрабатывает запрос |
| `✋` | Нужен ввод | Ждёт подтверждения запроса разрешения |
| `◌` | Сжатие | Идёт сжатие контекста |

Требуется CLI-бинарь [zellij-tab-status](https://github.com/dapi/zellij-tab-status).

Индикаторы управляются Claude Code hooks из
[hooks/hooks.json](./hooks/hooks.json). Хуки переводят события жизненного цикла
Claude-сессии в префиксы имени вкладки:

| Событие hook | Matcher | Статус | Смысл |
|-|-|-|-|
| `SessionStart` | `startup|clear` | `○` | Новая или очищенная сессия готова к вводу |
| `SessionStart` | `resume|compact` | `◉` | Возобновлённая сессия может быть ещё активной |
| `UserPromptSubmit` | любой | `◉` | Пользователь отправил задачу; Claude работает |
| `SubagentStart` | любой | `◉` | Запущена делегированная работа |
| `PermissionRequest` | любой | `✋` | Claude заблокирован на запросе разрешения |
| `PostToolUse` / `PostToolUseFailure` | любой | `◉` | Работа с инструментом завершилась, основной агент продолжает |
| `PreCompact` | любой | `◌` | Идёт сжатие контекста |
| `Stop` | любой | `○` | Claude завершил текущий ход |
| `SessionEnd` | `clear` | `○` | Очищенная сессия возвращается в состояние готовности |
| `SessionEnd` | `logout|prompt_input_exit|bypass_permissions_disabled|other` | clear | Убрать статусный префикс |

Каждый hook работает по принципу best-effort: он проверяет наличие `zellij-tab-status`,
подавляет вывод hook-команды и заканчивается на `|| true`, чтобы Claude
нормально работал, даже если CLI не установлен или сессия запущена не внутри
Zellij.

### Вкладки и панели общего назначения

Открывает вкладки и панели для любых задач: пустые, с shell-командой или с Claude-сессией:

```
/run-in-new-tab Execute plan from docs/plans/audit-plan.md. Use executing-plans.
/run-in-new-tab Refactor the auth module
```

Или попроси:
- "Открой новую вкладку" / "Создай панель"
- "Запусти npm test в панели"
- "Выполни план в новой вкладке zellij"
- "Делегируй это в панель"

### Вкладки разработки issue

Запускает `start-issue` в новой вкладке или панели Zellij:

```
/start-issue-in-new-tab 123
/start-issue-in-new-tab #45
/start-issue-in-new-tab https://github.com/owner/repo/issues/78
```

Или попроси: "Запусти issue #123 в новой вкладке" или "Запусти issue #45 в панели"

## Установка

### Шаг 1: установи zellij-tab-status (опционально, для иконок статуса)

Установи CLI-бинарь [zellij-tab-status](https://github.com/dapi/zellij-tab-status):

```bash
make install-zellij-tab-status
```

Запись в `config.kdl` или `load_plugins` не нужна. Текущий `zellij-tab-status` -
это нативный CLI-инструмент, а не WASM-плагин.

### Шаг 2: установи плагин

```bash
/plugin install zellij-workflow@dapi
```

## Требования

- [Zellij](https://zellij.dev) 0.44.0+ терминальный мультиплексор
- CLI [zellij-tab-status](https://github.com/dapi/zellij-tab-status) в PATH (опционально, для иконок статуса)
- [`start-issue`](https://github.com/dapi/start-issue) в PATH (для вкладок разработки issue)
- `claude` CLI в PATH (для вкладок Claude-сессий)

### Зависимости от других плагинов

| Plugin | Где используется | Назначение |
|--------|------------------|------------|
| **superpowers** | `/run-in-new-tab`, skill `zellij-tab-pane` | Skill `executing-plans` для выполнения планов в новых вкладках |

## Устранение неполадок

| Проблема | Причина | Решение |
|-|-|-|
| На вкладках нет иконок статуса | `zellij-tab-status` CLI не установлен или не находится в PATH | Запусти `make install-zellij-tab-status`; убедись, что `~/.local/bin` есть в PATH |
| `zellij-tab-status` command not found | Бинарь не находится в PATH | Добавь `~/.local/bin` в PATH и перезапусти Claude |
| zellij-tab-status падает с ошибками `list-panes`, `list-tabs` или `rename-tab-by-id` | Zellij слишком старый или Claude запущен не внутри Zellij | Используй Zellij 0.44.0+ и запускай Claude внутри панели Zellij |
| Статус завис на `✋` | Редко: `PostToolUse` не сработал после выдачи разрешения | Переключись на вкладку; следующее действие сбросит статус на `◉` |
| Статус остаётся `◉` после остановки Claude | Не сработал `Stop` hook | Проверь, что `zellij-workflow` установлен: `/plugin list` |
| Иконки появляются на неправильной вкладке | Всё ещё активна старая WASM/script-версия | Удали старый `zellij-tab-status.wasm` из конфигурации `load_plugins` и установи CLI v0.8.1+ |
| Ошибка `Not in zellij session` | Claude запущен вне Zellij | Сначала запусти Zellij, затем Claude внутри него |
| `Timed out` при создании вкладки/панели | Zellij завис или перегружен | Перезапусти Zellij-сессию |

## Компоненты

| Компонент | Файл | Назначение |
|-----------|------|------------|
| Hooks | [hooks/hooks.json](./hooks/hooks.json) | Индикаторы статуса вкладки |
| Skill | [skills/zellij-tab-pane/SKILL.md](./skills/zellij-tab-pane/SKILL.md) | Вкладка/панель: пустая, команда, Claude-сессия, разработка issue |
| Command | [commands/start-issue-in-new-tab.md](./commands/start-issue-in-new-tab.md) | `/start-issue-in-new-tab` |
| Command | [commands/run-in-new-tab.md](./commands/run-in-new-tab.md) | `/run-in-new-tab` |

# zellij-dev-tab

Плагин для запуска разработки GitHub issue в отдельной вкладке zellij.

## Назначение

Автоматизирует создание изолированной вкладки терминала для работы над конкретным issue:

1. Создаёт новую вкладку zellij с именем `#ISSUE_NUMBER`
2. Запускает `do-issue` с переданным номером/URL

## Установка

```bash
/plugin install zellij-dev-tab@dapi
```

## Использование

Просто скажите Claude что хотите работать над issue в отдельной вкладке:

```
Запусти разработку issue #45 в отдельной вкладке

Start development of issue 123 in new zellij tab

Открой https://github.com/owner/repo/issues/78 в новой вкладке
```

## Поддерживаемые форматы

| Формат | Пример |
|--------|--------|
| Число | `45` |
| С решёткой | `#45` |
| URL | `https://github.com/owner/repo/issues/45` |

## Prerequisites

### zellij

Терминальный мультиплексор. Установка:

```bash
cargo install zellij
# или через пакетный менеджер
```

### do-issue

Скрипт для работы с GitHub issues через git worktree и Claude Code. Создаёт изолированный worktree для issue и запускает Claude Code сессию.

**Установка**: скопируйте скрипт в `~/.local/bin/` и сделайте исполняемым:

```bash
# do-issue должен быть в PATH
chmod +x ~/.local/bin/do-issue
```

**Что делает do-issue**:
1. Парсит номер issue из URL или числа
2. Создаёт git worktree для работы над issue
3. Запускает Claude Code в worktree директории
4. Опционально выполняет `init.sh` для настройки окружения

## Структура

```
zellij-dev-tab/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── zellij-dev-tab/
│       ├── SKILL.md
│       └── TRIGGER_EXAMPLES.md
└── README.md
```

## Примеры триггеров

**Русский:**
- "запусти разработку в отдельной вкладке"
- "создай вкладку для issue #123"
- "do-issue в новой вкладке"

**English:**
- "start development in separate tab"
- "new zellij tab for issue"
- "run do-issue in new tab"

## Лицензия

MIT

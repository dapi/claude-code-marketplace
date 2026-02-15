---
name: zellij-dev-tab
description: |
  **UNIVERSAL TRIGGER**: START/OPEN/LAUNCH issue development IN separate zellij TAB.

  Common patterns:
  - "start/open/launch [issue] in new tab"
  - "get/show/display issue in zellij tab"
  - "запусти/открой/создай [issue] в вкладке"

  **Start Development**:
  - "start development in separate tab"
  - "launch issue #123 in new zellij tab"
  - "check out issue in new tab", "fetch issue to tab"
  - "запусти разработку в отдельной вкладке"

  **Create/Open Tab**:
  - "create tab for issue #45"
  - "open new tab for issue", "list and start issue in tab"
  - "создай вкладку для задачи"

  **Retrieve & Run**:
  - "retrieve issue #N and start in tab"
  - "run start-issue in new tab", "analyze issue in tab"
  - "start-issue в отдельной вкладке"

  TRIGGERS: start issue tab, open issue tab, launch issue tab, create tab issue,
  run start-issue tab, zellij new tab issue, separate tab development, new tab issue,
  development in tab, issue development tab, work on issue in tab, begin issue tab,
  запусти в вкладке, открой в вкладке, создай вкладку issue, новая вкладка задача,
  разработка в вкладке, вкладка для issue, отдельная вкладка issue, zellij вкладка
allowed-tools: Bash
---

# Zellij Dev Tab Skill

Запуск разработки GitHub issue в отдельной вкладке zellij с автоматическим вызовом `start-issue`.

## Назначение

Когда пользователь хочет начать работу над issue в изолированной вкладке терминала, этот skill:

1. Парсит номер issue из аргумента
2. Создаёт новую вкладку zellij с именем `#ISSUE_NUMBER`
3. Запускает `start-issue` с переданным аргументом

## Формат аргумента

Skill принимает номер issue в любом из форматов:

| Формат | Пример | Результат |
|--------|--------|-----------|
| Число | `123` | Issue #123 |
| С решёткой | `#123` | Issue #123 |
| URL | `https://github.com/owner/repo/issues/123` | Issue #123 |

## Алгоритм парсинга

```bash
# Извлечение номера issue из аргумента
parse_issue_number() {
  local arg="$1"

  # URL формат
  if [[ "$arg" =~ github\.com/.*/issues/([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  # #число формат
  elif [[ "$arg" =~ ^#?([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}
```

## Команда выполнения

**В новой вкладке:**

```bash
# EAFP: выполняем сразу, диагностируем при ошибке
ISSUE_NUMBER=$(parse_issue_number "$ARG")
zellij action new-tab --name "#${ISSUE_NUMBER}" && \
zellij action write-chars "start-issue $ARG
" || {
  echo "Command failed. Diagnosing..."
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif ! command -v start-issue &>/dev/null; then echo "start-issue not found in PATH"
  else echo "Unknown error"
  fi
}
```

**В новой панели (альтернатива):**

```bash
zellij run -- start-issue $ARG
```

## Примеры использования

### Пример 1: Номер issue

**Пользователь:** "Запусти разработку issue 45 в отдельной вкладке"

**Claude выполняет:**
```bash
zellij action new-tab --name "#45" && \
zellij action write-chars "start-issue 45
"
```

### Пример 2: URL

**Пользователь:** "Открой https://github.com/dapi/project/issues/123 в новой вкладке zellij"

**Claude выполняет:**
```bash
zellij action new-tab --name "#123" && \
zellij action write-chars "start-issue https://github.com/dapi/project/issues/123
"
```

### Пример 3: С решёткой

**Пользователь:** "Создай вкладку для #78"

**Claude выполняет:**
```bash
zellij action new-tab --name "#78" && \
zellij action write-chars "start-issue 78
"
```

### Пример 4: В новой панели

**Пользователь:** "Запусти start-issue 45 в новой панели"

**Claude выполняет:**
```bash
zellij run -- start-issue 45
```

## Зависимости

- **zellij** -- терминальный мультиплексор (должен быть запущен)
- **start-issue** -- скрипт/команда для работы с issue (должен быть в PATH)

## Ошибки

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `zellij: command not found` | zellij не установлен | `cargo install zellij` |
| `Zellij not running` | Команда запущена вне zellij | Запустить zellij |
| `start-issue: command not found` | start-issue не в PATH | Добавить в PATH или установить |
| `Invalid issue format` | Неверный формат аргумента | Использовать число, #число или URL |

## Важно

- Skill работает **только внутри zellij сессии**
- `start-issue` должен быть доступен в новой вкладке (наследует PATH)
- Имя вкладки всегда в формате `#NUMBER` для единообразия

---
description: Start issue development in new zellij tab with start-issue
argument-hint: <issue-number-or-url>
version: 1.0.0
---

# Start Issue in New Tab

Запусти разработку issue в новой вкладке zellij.

## Входные данные

- **ISSUE**: `$ARGUMENTS` -- номер issue, #номер, или полный GitHub URL

## Шаги

### 1. Извлеки номер issue

```bash
parse_issue_number() {
  local arg="$1"

  # URL: https://github.com/.../issues/123
  if [[ "$arg" =~ github\.com/.*/issues/([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  # #123 или 123
  elif [[ "$arg" =~ ^#?([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

ISSUE_NUMBER=$(parse_issue_number "$ARGUMENTS")
```

### 2. Создай вкладку и запусти start-issue

```bash
# EAFP: выполняем сразу, диагностируем при ошибке
zellij action new-tab --name "#${ISSUE_NUMBER}" && \
zellij action write-chars "start-issue $ARGUMENTS
" || {
  echo "Command failed. Diagnosing..."
  if [ -z "$ZELLIJ" ]; then echo "Not in zellij session"
  elif ! command -v start-issue &>/dev/null; then echo "start-issue not found in PATH"
  else echo "Unknown error"
  fi
}
```

**Как это работает:**
1. `new-tab --name` -- создаёт вкладку с заданным именем
2. `write-chars` -- вводит команду в shell новой вкладки

## Примеры

```bash
/start-issue-in-new-tab 123
/start-issue-in-new-tab #45
/start-issue-in-new-tab https://github.com/owner/repo/issues/78
```

## Результат

- Создаётся новая вкладка zellij с именем `#123`
- В ней запускается `start-issue` который:
  - Создаёт git worktree
  - Переименовывает вкладку
  - Запускает Claude Code сессию

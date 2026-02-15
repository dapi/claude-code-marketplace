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

### 1. Проверь окружение

```bash
# Проверить что мы в zellij
if [ -z "$ZELLIJ" ]; then
  echo "[FAIL] Not in zellij session. Run zellij first."
  exit 1
fi

# Проверить что start-issue доступен
if ! command -v start-issue &> /dev/null; then
  echo "[FAIL] start-issue not found in PATH"
  echo "Install: make install-scripts (from claude-code-marketplace)"
  exit 1
fi
```

**Если проверки не прошли** -- сообщи пользователю и НЕ продолжай.

### 2. Извлеки номер issue

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

### 3. Создай вкладку и запусти start-issue

```bash
# Создаём вкладку, запускаем команду, убираем пустую панель
zellij action go-to-tab-name --create "#${ISSUE_NUMBER}" && \
zellij action new-pane -- start-issue $ARGUMENTS && \
zellij action focus-previous-pane && \
zellij action close-pane
```

**Как это работает:**
1. `go-to-tab-name --create` -- создаёт вкладку (или переключается если существует)
2. `new-pane -- command` -- запускает команду в новой панели
3. `focus-previous-pane` + `close-pane` -- убирает пустую shell-панель

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

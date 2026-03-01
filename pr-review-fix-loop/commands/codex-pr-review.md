---
description: "Code review текущей ветки через OpenAI Codex CLI"
argument-hint: "[--base BRANCH]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*:*)"]
---

# Codex PR Review

Запустить code review текущей ветки относительно base branch через встроенную подкоманду `codex review`.

## Парсинг аргументов

Разобрать `$ARGUMENTS`:
- `--base BRANCH` — base branch для сравнения (по умолчанию: автодетект или master)

## Детект проекта

Получить env wrapper:

```bash
PROJECT_JSON=$("${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh")
if [[ $? -ne 0 ]] || [[ -z "$PROJECT_JSON" ]]; then
  echo "Error: Failed to detect project" >&2
  # stop execution
fi
ENV_EXEC=$(echo "$PROJECT_JSON" | jq -r '.env_exec // empty')
```

Если `PROJECT_JSON` пуст или скрипт вернул ненулевой exit code — вывести ошибку и прекратить выполнение.
Если `ENV_EXEC` пуст (jq вернул empty) — продолжить без env wrapper.

## Определение base branch

Запустить detect-base-branch.sh с env wrapper:

```bash
BASE=$("${CLAUDE_PLUGIN_ROOT}/scripts/detect-base-branch.sh" --base "${user_base:-}" ${ENV_EXEC:+--env-exec "$ENV_EXEC"})
# NOTE: quote $BASE in all subsequent commands to handle branch names safely
```

Если скрипт вернул ошибку — вывести сообщение об ошибке и прекратить выполнение.

## Проверки перед запуском

Убедиться что codex CLI установлен:
```bash
${ENV_EXEC:+$ENV_EXEC }which codex
```
Если не установлен — сообщить пользователю и прекратить выполнение.

Убедиться что есть изменения:
```bash
${ENV_EXEC:+$ENV_EXEC }git diff "$BASE"...HEAD --stat
```
Если diff пустой — сообщить что нет изменений для ревью и прекратить.

## Запуск Codex

Использовать встроенную подкоманду `codex review`:

```bash
${ENV_EXEC:+$ENV_EXEC }codex review --base "$BASE"
```

**Важно:** Подкоманда `review` и свободный промпт взаимоисключающие — нельзя передать и `--base`, и текст промпта одновременно. Codex сам получит diff, проанализирует изменения и выведет структурированный отчёт.

## После завершения

1. Вывести результат ревью пользователю
2. Если codex завершился с ошибкой — сообщить об ошибке, показать stderr

## Примеры использования

```
/codex-pr-review
/codex-pr-review --base develop
/codex-pr-review --base HEAD~3
```

---
description: "Code review текущей ветки через OpenAI Codex CLI"
argument-hint: "[--base BRANCH]"
---

# Codex PR Review

Запустить code review текущей ветки относительно base branch через встроенную подкоманду `codex review`.

## Парсинг аргументов

Разобрать `$ARGUMENTS`:
- `--base BRANCH` — base branch для сравнения (по умолчанию: автодетект или master)

## Определение base branch

**Примечание:** Эта логика дублируется в `pr-review-fix-loop.md`. При изменении — обновить оба файла.

В порядке приоритета:
1. Если указан `--base` — использовать его
2. Попробовать автодетект из PR: сначала проверить `direnv exec . which gh`, если gh не установлен — предупредить и перейти к следующему шагу. Если установлен — выполнить `direnv exec . gh pr view --json baseRefName -q .baseRefName`. Если команда вернула ненулевой exit code — предупредить и перейти к следующему шагу
3. Использовать main branch из CLAUDE.md проекта (уже загружен в контекст — найти строку "Main branch" или аналогичную)
4. Fallback — `master`

Проверить что base branch существует: `direnv exec . git rev-parse --verify {base} 2>/dev/null`
Если base branch не существует — сообщить пользователю: "Base branch '{base}' не найден. Укажите существующую ветку через --base" и прекратить выполнение.

## Проверки перед запуском

Убедиться что codex CLI установлен:
```bash
direnv exec . which codex
```
Если не установлен — сообщить пользователю и прекратить выполнение.

Убедиться что есть изменения:
```bash
direnv exec . git diff {base}...HEAD --stat
```
Если diff пустой — сообщить что нет изменений для ревью и прекратить.

## Запуск Codex

Использовать встроенную подкоманду `codex review`:

```bash
direnv exec . codex review --base {base}
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

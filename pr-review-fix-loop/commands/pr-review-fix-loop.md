---
description: "Iterative PR review + autofix loop (built-in iteration engine + pr-review-toolkit)"
argument-hint: "[--max-iterations N] [--aspects ASPECTS] [--min-criticality N] [--lint] [--codex] [--base BRANCH]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*:*)"]
---

# PR Review Fix Loop

Итеративный цикл: запустить PR review, исправить критические и важные замечания, повторить до чистого отчёта.

## Парсинг аргументов

Разобрать `$ARGUMENTS`:
- `--max-iterations N` — максимум итераций (по умолчанию 20)
- `--aspects ASPECTS` — аспекты ревью (по умолчанию `code errors tests`)
- `--min-criticality N` — минимальный уровень criticality для исправления, 1-10 (по умолчанию 5)
- `--lint` — запускать линтер с автофиксом после исправлений (по умолчанию выключен). Линтер определяется автоматически по типу проекта
- `--codex` — параллельно запускать ревью через Codex CLI (по умолчанию выключен)
- `--base BRANCH` — base branch для Codex diff (по умолчанию: автодетект из PR или main branch из CLAUDE.md)

Доступные аспекты: `code`, `errors`, `tests`, `comments`, `types`, `simplify`, `all`

## Валидация аргументов

- `--max-iterations` должен быть целым числом >= 1. Если значение невалидно — сообщить пользователю ошибку и прекратить.
- `--min-criticality` должен быть целым числом от 1 до 10 включительно. Если меньше 1 — установить 1, если больше 10 — установить 10, сообщить пользователю об автокоррекции.
- `--aspects` — каждый указанный аспект должен входить в список доступных. Если найден неизвестный аспект — сообщить пользователю ошибку со списком доступных аспектов и прекратить. При парсинге убрать обрамляющие кавычки, если они есть.
- Если `--base` указан без `--codex` — предупредить пользователю что `--base` используется только вместе с `--codex` и будет проигнорирован.

## Проверки перед запуском

### Детект проекта

Запустить detect-project.sh и получить JSON с параметрами проекта:

```bash
PROJECT_JSON=$("${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh")
if [[ $? -ne 0 ]] || [[ -z "$PROJECT_JSON" ]]; then
  echo "Error: Failed to detect project" >&2
  # stop execution
fi
STACK=$(echo "$PROJECT_JSON" | jq -r '.stack // empty')
ENV_EXEC=$(echo "$PROJECT_JSON" | jq -r '.env_exec // empty')
TEST_CMD=$(echo "$PROJECT_JSON" | jq -r '.test_cmd // empty')
LINT_CMD=$(echo "$PROJECT_JSON" | jq -r '.lint_cmd // empty')
```

Если `PROJECT_JSON` пуст или скрипт вернул ненулевой exit code — вывести ошибку и прекратить выполнение.

Если STACK пустой — записать предупреждение "Тип проекта не определён, TDD и тесты будут в generic-режиме" в отчёт и продолжить.

Если `--lint` указан но LINT_CMD пустой — записать предупреждение "Линтер не найден для стека $STACK" и продолжить без линтера.

### Детект base branch (если --codex)

Если `--codex` указан:

```bash
BASE=$("${CLAUDE_PLUGIN_ROOT}/scripts/detect-base-branch.sh" --base "${user_base:-}" --env-exec "$ENV_EXEC")
```

Если скрипт вернул ошибку — сообщить пользователю и прекратить выполнение.

Также проверить что codex CLI установлен:

```bash
${ENV_EXEC:+$ENV_EXEC }which codex
```

Если не установлен — сообщить пользователю и прекратить выполнение.

## Создание файла отчёта

Перед запуском loop создать файл `.claude/pr-review-loop-report.local.md` с заголовком:

```markdown
# PR Review Fix Loop Report

Дата: {текущая дата}
Параметры: aspects={aspects}, min-criticality={min_criticality}, lint={yes/no}, codex={yes/no}

---

ИТЕРАЦИЯ 1 НАЧАЛО

```

Ожидаемая структура секций для каждой итерации:

- **Issues** — количество и список issues выше порога с источником, criticality, файлом
- **Exploration** — для каждой группы: область, паттерны, ключевые файлы (от code-explorer)
- **Исправления** — для TDD-issues: spec-файл, red/green статусы; для остальных: краткое описание фикса
- **Linter** (если включен) — количество авто-исправленных файлов

## Запуск iteration loop

### Сборка промпта

Запустить assemble-prompt.sh с параметрами:

```bash
PROMPT=$("${CLAUDE_PLUGIN_ROOT}/scripts/assemble-prompt.sh" \
  --aspects "$ASPECTS" \
  --min-criticality "$MIN_CRITICALITY" \
  ${CODEX:+--codex} \
  ${LINT:+--lint} \
  ${BASE:+--base "$BASE"} \
  ${TEST_CMD:+--test-cmd "$TEST_CMD"} \
  ${LINT_CMD:+--lint-cmd "$LINT_CMD"} \
  ${ENV_EXEC:+--env-exec "$ENV_EXEC"})
```

### Запуск setup-loop.sh

Передать собранный промпт в setup-loop.sh через heredoc:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" --max-iterations $MAX_ITERATIONS --completion-promise "REVIEW CLEAN" --completion-promise "REVIEW STAGNANT" <<LOOP_PROMPT
$PROMPT
LOOP_PROMPT
```

После запуска setup-loop.sh выполнить шаги из промпта. Stop hook автоматически подаст тот же промпт при завершении каждой итерации.

## После завершения loop

Когда loop завершился:

### 0. Диагностика завершения

Прочитать `.claude/pr-review-loop-report.local.md` и определить причину завершения по маркерам:

| Маркеры в отчёте | Причина | Действие |
|-|-|-|
| `[OK] [EXIT:SUCCESS]` | REVIEW CLEAN | Продолжить с шагом 1 |
| `[!!] [EXIT:STAGNANT]` | Issues не уменьшаются 5+ итераций | Перейти к шагу 4a |
| `[!!] [EXIT:LIMIT]` | Лимит итераций исчерпан | Перейти к шагу 4 |
| `[XX] [EXIT:ERROR]` с описанием | Ошибка iteration engine | Сообщить ошибку из маркера |
| Последняя итерация имеет `НАЧАЛО` но нет `ЗАВЕРШЕНА` и нет `[EXIT:*]` | ПРЕРВАНО на итерации N | Сообщить: loop прерван, вероятная причина - переполнение контекста |
| Нет маркеров | ОШИБКА СТАРТА | Сообщить: loop не запустился |

Вывести пользователю строку диагноза: причина завершения, номер последней итерации, количество завершённых итераций.

### 1. Вывести компактную сводку

НЕ выводить полный файл отчёта. Вместо этого извлечь из `.claude/pr-review-loop-report.local.md` данные и вывести пользователю компактную сводку в формате:

```
## PR Review Fix Loop - {STATUS}

Итераций: {N}
Время: {M} мин
Найдено issues: {total} (выше порога: {above_threshold})
Исправлено: {fixed}
Пропущено (FP/enhancements): {skipped}
Коммиты: {count} ({hashes через запятую})

Полный отчёт: .claude/pr-review-loop-report.local.md
pr-review-fix-loop v{VERSION}
```

Где:
- `{STATUS}` — REVIEW CLEAN, REVIEW STAGNANT, LIMIT REACHED, или INTERRUPTED
- Время — разница между `started_at` из `.claude/pr-review-fix-loop.local.md` (или `Дата:` из report) и текущим временем, в целых минутах
- Версию получить: `jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"`
- Количество коммитов и хеши — из `${ENV_EXEC:+$ENV_EXEC }git log --oneline` за время работы loop (коммиты с "iteration" в сообщении)

При статусе STAGNANT — добавить строку `Тренд issues: {последние 5 значений issues_count}`.
При статусе LIMIT REACHED — добавить строку `Оставшиеся issues: {count}`.

### 2. Финальная проверка через feature-dev:code-reviewer

После завершения loop (независимо от результата) запустить агент `feature-dev:code-reviewer` через Task tool (subagent_type: "feature-dev:code-reviewer") для финальной валидации всех сделанных исправлений против CLAUDE.md и coding standards проекта. Этот reviewer использует confidence scoring и сообщает только issues с confidence >= 80, что снижает ложные срабатывания. Это одноразовая проверка, не итеративная. Результат вывести пользователю и дописать в `.claude/pr-review-loop-report.local.md` секцию "Финальная проверка (code-reviewer)".

Если `feature-dev:code-reviewer` недоступен (subagent_type не найден) — записать в отчёт "Финальная проверка: пропущена (code-reviewer недоступен)" и продолжить с шагом 3. Если code-reviewer запустился, но завершился с ошибкой — записать в отчёт "Финальная проверка: code-reviewer завершился с ошибкой" с текстом ошибки и продолжить с шагом 3.

### 3. Проверка незакоммиченных изменений

Коммиты создаются внутри каждой итерации (шаг 4.5 в промпте). После завершения loop проверить, остались ли незакоммиченные изменения:
- Запустить `${ENV_EXEC:+$ENV_EXEC }git diff --name-only` и `${ENV_EXEC:+$ENV_EXEC }git diff --cached --name-only`
- Если есть незакоммиченные файлы (кроме `*.local.md`) — создать финальный коммит аналогично шагу 4.5 с сообщением `fix: address PR review issues (final)`
- Если нет незакоммиченных файлов — ничего не делать

### 4. Если loop достиг max-iterations без REVIEW CLEAN

- Вывести предупреждение что лимит итераций исчерпан
- Показать оставшиеся нерешённые issues из последней итерации отчёта
- Предложить пользователю увеличить max-iterations или исправить issues вручную

### 4a. Если loop завершился со STAGNANT

- Вывести предупреждение: обнаружена стагнация, issue count не уменьшается 5+ итераций
- Показать тренд значений issues_count из последних итераций
- Запустить Task tool (subagent_type: "general-purpose") с промптом: "Прочитай файл .claude/pr-review-loop-report.local.md. Проанализируй нерешённые issues из последних итераций. Определи корневые причины стагнации. Выведи: 1) ROOT CAUSES - группировка issues по корневым причинам; 2) RECOMMENDATIONS - для каждой группы что исправить вручную и подход; 3) AFFECTED FILES - список файлов. Формат plain text, маркеры [MANUAL] [APPROACH] [SKIP]."
- Если Task tool вернул ошибку -- записать "Recommendation agent unavailable" в отчёт и продолжить
- Результат вывести пользователю и дописать в отчёт секцию "STAGNATION ANALYSIS"

## Очистка

Временные файлы (`.codex-review.md`, `.codex-review.stderr`, старый отчёт) удаляются автоматически при старте loop в `setup-loop.sh`.

Файл `.claude/pr-review-loop-report.local.md` НЕ удалять после завершения — это артефакт для пользователя.

## Значения по умолчанию

| Параметр | По умолчанию |
|-|-|
| max-iterations | 20 |
| aspects | code errors tests |
| min-criticality | 5 |
| lint | выключен |
| codex | выключен |
| base | автодетект / main branch из CLAUDE.md |

## Примеры использования

```
/pr-review-fix-loop
/pr-review-fix-loop --max-iterations 5
/pr-review-fix-loop --aspects "code errors"
/pr-review-fix-loop --min-criticality 7
/pr-review-fix-loop --lint
/pr-review-fix-loop --codex
/pr-review-fix-loop --codex --base develop
/pr-review-fix-loop --codex --lint --aspects all
/pr-review-fix-loop --max-iterations 15 --aspects "code errors" --min-criticality 3 --codex --lint
```

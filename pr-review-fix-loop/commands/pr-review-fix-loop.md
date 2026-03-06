---
description: "Iterative PR review + autofix loop. Reviews code, fixes issues above criticality threshold, repeats until clean. Supports Ruby, Node, Python, Go, Rust with auto-detected test/lint commands."
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

### Проверка .gitignore

Перед всеми остальными проверками запустить `"${CLAUDE_PLUGIN_ROOT}/scripts/check-gitignore.sh"`. Если `action_needed` равно `true`, добавить отсутствующие файлы в `.gitignore` немедленно. Продолжить с остальными проверками.

### Версия и детект проекта

Получить версию и параметры проекта **одним вызовом**:

```bash
VERSION=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json") && PROJECT_JSON=$("${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh") && echo "pr-review-fix-loop v${VERSION}" && echo "$PROJECT_JSON"
```

Из вывода извлечь:
- Первая строка — версия для отображения пользователю (`pr-review-fix-loop v{version}`)
- JSON — параметры проекта: `STACK`, `ENV_EXEC`, `TEST_CMD`, `LINT_CMD` (через `jq -r`)

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

## Файл отчёта

Файл `.claude/pr-review-loop-report.local.md` создаётся автоматически скриптом `setup-loop.sh` (через `--report-params`). НЕ создавать его вручную.

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
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" --max-iterations $MAX_ITERATIONS --completion-promise "REVIEW CLEAN" --completion-promise "REVIEW STAGNANT" --report-params "aspects=$ASPECTS, min-criticality=$MIN_CRITICALITY, lint=${LINT:-no}, codex=${CODEX:-no}" <<'LOOP_PROMPT'
$PROMPT
LOOP_PROMPT
```

После запуска setup-loop.sh выполнить шаги из промпта. Stop hook автоматически подаст тот же промпт при завершении каждой итерации.

## После завершения loop

> **NOTE:** Post-loop шаги (сводка, анализ, коммит/push) теперь выполняются автоматически через block response из stop-hook (`scripts/post-loop-prompt.sh`). Инструкции ниже служат справочником для промптов, генерируемых этим скриптом.

Когда loop завершился:

### 0. Диагностика завершения

Прочитать `.claude/pr-review-loop-report.local.md` и определить причину завершения по маркерам:

| Маркеры в отчёте | Причина | Действие |
|-|-|-|
| `[OK] [EXIT:SUCCESS]` | REVIEW CLEAN | Продолжить с шагом 1 |
| `[!!] [EXIT:STAGNANT]` | Issues не уменьшаются 5+ итераций | Перейти к шагу 4a |
| `[!!] [EXIT:LIMIT]` | Лимит итераций исчерпан | Перейти к шагу 4 |
| `[XX] [EXIT:ERROR]` с описанием | Ошибка iteration engine | Сообщить ошибку из маркера |
| Последняя итерация имеет `START` но нет `COMPLETED` и нет `[EXIT:*]` | ПРЕРВАНО на итерации N | Сообщить: loop прерван, вероятная причина - переполнение контекста |
| Нет маркеров | ОШИБКА СТАРТА | Сообщить: loop не запустился |

Вывести пользователю строку диагноза: причина завершения, номер последней итерации, количество завершённых итераций.

### 1. Вывести компактную сводку

НЕ выводить полный файл отчёта. Вместо этого извлечь из `.claude/pr-review-loop-report.local.md` данные и вывести пользователю компактную сводку.

Версию получить: `jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"`
Время — разница между `started_at` из `.claude/pr-review-fix-loop.local.md` (или `Дата:` из report) и текущим временем, в целых минутах.

Формат сводки по статусам:

**REVIEW CLEAN:**
```
---

## PR Review Fix Loop v{VERSION} — **REVIEW CLEAN** ✅

Итераций: **{N}**
Время: **{M} мин**
Найдено issues: **{total}** (выше порога: **{above_threshold}**)
Исправлено: **{fixed}**
```

**REVIEW STAGNANT:**
```
---

## PR Review Fix Loop v{VERSION} — **REVIEW STAGNANT** ⚠️

Итераций: **{N}**
Время: **{M} мин**
Найдено issues: **{total}** (выше порога: **{above_threshold}**)
Исправлено: **{fixed}**
Тренд issues: {последние 5 значений через →}
```

**LIMIT REACHED:**
```
---

## PR Review Fix Loop v{VERSION} — **LIMIT REACHED** ❌

Итераций: **{N}**
Время: **{M} мин**
Найдено issues: **{total}** (выше порога: **{above_threshold}**)
Исправлено: **{fixed}**
Оставшиеся issues:
- {criticality} {source}: {описание} ({файл})
- ...
```

**INTERRUPTED:**
```
---

## PR Review Fix Loop v{VERSION} — **INTERRUPTED** ⚠️

Итераций: **{N}** (последняя не завершена)
Время: **{M} мин**
Найдено issues: **{total}** (выше порога: **{above_threshold}**)
Исправлено: **{fixed}**
```

При LIMIT REACHED список оставшихся issues извлечь из последней итерации отчёта — каждый issue с его criticality, источником (review-pr/codex), описанием и файлом.

### 2. Финальная проверка через feature-dev:code-reviewer

После завершения loop (независимо от результата) запустить агент `feature-dev:code-reviewer` через Task tool (subagent_type: "feature-dev:code-reviewer") для финальной валидации всех сделанных исправлений против CLAUDE.md и coding standards проекта. Этот reviewer использует confidence scoring и сообщает только issues с confidence >= 80, что снижает ложные срабатывания. Это одноразовая проверка, не итеративная. Результат вывести пользователю и дописать в `.claude/pr-review-loop-report.local.md` секцию "Финальная проверка (code-reviewer)".

Если `feature-dev:code-reviewer` недоступен (subagent_type не найден) — записать в отчёт "Финальная проверка: пропущена (code-reviewer недоступен)" и продолжить с шагом 3. Если code-reviewer запустился, но завершился с ошибкой — записать в отчёт "Финальная проверка: code-reviewer завершился с ошибкой" с текстом ошибки и продолжить с шагом 3.

### 3. Коммит, тесты и push (только при REVIEW CLEAN)

Коммиты создаются внутри каждой итерации (шаг 4.5 в промпте). После завершения loop:

#### 3a. Финальный коммит

- Запустить `${ENV_EXEC:+$ENV_EXEC }git diff --name-only` и `${ENV_EXEC:+$ENV_EXEC }git diff --cached --name-only`
- Если есть незакоммиченные файлы (кроме `*.local.md`) — создать финальный коммит с сообщением `fix: address PR review issues (final)` и `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

#### 3b. Pre-push тесты

Запустить тесты для файлов, изменённых в ходе loop:

1. Получить список изменённых файлов относительно base branch: `${ENV_EXEC:+$ENV_EXEC }git diff --name-only $(${ENV_EXEC:+$ENV_EXEC }git merge-base HEAD origin/$(${ENV_EXEC:+$ENV_EXEC }git rev-parse --abbrev-ref HEAD@{upstream} 2>/dev/null | sed 's|origin/||' || echo master))..HEAD`
2. Если `TEST_CMD` определён — запустить его для затронутых файлов (или полный suite если тест-раннер не поддерживает фильтр по файлам)
3. Если тесты **прошли** — перейти к шагу 3c
4. Если тесты **упали**:
   - Определить являются ли падения pre-existing (существовали до наших изменений) или вызваны нашими фиксами
   - Для этого: проверить `${ENV_EXEC:+$ENV_EXEC }git stash && ${ENV_EXEC:+$ENV_EXEC }git stash pop` не поможет — вместо этого посмотреть какие тест-файлы упали и связаны ли они с нашими изменёнными файлами
   - **Если падения вызваны нашими фиксами**: записать в отчёт "Pre-push тесты упали, перезапуск loop", перезапустить весь цикл с шага "Запуск iteration loop" (setup-loop.sh заново)
   - **Если падения pre-existing** (тесты упали в файлах, не связанных с нашими изменениями): спросить пользователя через AskUserQuestion: "Обнаружены pre-existing падения тестов (не связаны с нашими изменениями). Что делать?" с вариантами: "Исправить и перезапустить loop" / "Игнорировать и продолжить push"

#### 3c. Push

- Запустить `${ENV_EXEC:+$ENV_EXEC }git push`
- Если push не удался — сообщить пользователю ошибку (возможно нужен `--set-upstream` или есть конфликт с remote)

#### 3d. Post-push: ожидание CI

После push дождаться результатов CI:

1. Получить URL текущего PR: `${ENV_EXEC:+$ENV_EXEC }gh pr view --json url -q .url`
2. Дождаться завершения CI checks: `${ENV_EXEC:+$ENV_EXEC }gh pr checks --watch --fail-fast`
3. Если CI **прошёл**:
   - Вывести пользователю: "CI прошёл. PR готов к merge: {PR_URL}"
   - Спросить через AskUserQuestion: "CI прошёл. Влить PR?" с вариантами: "Да, merge" / "Нет, ознакомлюсь сам"
   - Если пользователь выбрал "Да, merge": выполнить `${ENV_EXEC:+$ENV_EXEC }gh pr merge --squash --delete-branch`
   - Если "Нет" — сообщить ссылку на PR и завершить
4. Если CI **упал**:
   - Получить детали: `${ENV_EXEC:+$ENV_EXEC }gh pr checks`
   - Определить связаны ли падения с нашими изменениями или pre-existing
   - **Если наши изменения виноваты**: записать в отчёт "CI упал, перезапуск loop", перезапустить весь цикл
   - **Если pre-existing**: спросить пользователя через AskUserQuestion: "CI упал на тестах, не связанных с нашими изменениями. Что делать?" с вариантами: "Исправить и перезапустить loop" / "Игнорировать, merge вручную"
5. Если `gh` недоступен или нет PR — пропустить CI ожидание, сообщить пользователю что push выполнен, CI проверить вручную

При STAGNANT или LIMIT — НЕ пушить (не все issues решены).

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

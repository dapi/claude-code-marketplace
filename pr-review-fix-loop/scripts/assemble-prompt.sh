#!/bin/bash
# Assembles the iteration prompt for pr-review-fix-loop
# Output: single-line prompt to stdout

set -euo pipefail

ASPECTS="code errors tests"
MIN_CRITICALITY=5
CODEX=false
LINT=false
BASE=""
TEST_CMD=""
LINT_CMD=""
ENV_EXEC=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --aspects) ASPECTS="$2"; shift 2 ;;
    --min-criticality) MIN_CRITICALITY="$2"; shift 2 ;;
    --codex) CODEX=true; shift ;;
    --lint) LINT=true; shift ;;
    --base) BASE="$2"; shift 2 ;;
    --test-cmd) TEST_CMD="$2"; shift 2 ;;
    --lint-cmd) LINT_CMD="$2"; shift 2 ;;
    --env-exec) ENV_EXEC="$2"; shift 2 ;;
    *) echo "Error: Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Warn if --codex without --base
if [[ "$CODEX" == "true" ]] && [[ -z "$BASE" ]]; then
  echo "Warning: --codex specified without --base, codex steps will be skipped" >&2
fi

# Build env-exec prefix for commands
CMD_PREFIX=""
if [[ -n "$ENV_EXEC" ]]; then
  CMD_PREFIX="$ENV_EXEC "
fi

# Build conditional steps
CODEX_BG_STEP=""
CODEX_COLLECT_STEP=""
CODEX_REPORT_NOTE=""
if [[ "$CODEX" == "true" ]] && [[ -n "$BASE" ]]; then
  CODEX_BG_STEP="Шаг 0: Только на ПЕРВОЙ итерации - запустить в фоне через Bash с таймаутом 5 минут команду ${CMD_PREFIX}codex review --base $BASE, перенаправить stdout в файл .codex-review.md и stderr в файл .codex-review.stderr. На последующих итерациях пропустить шаг 0 и использовать результат codex из первой итерации. "
  CODEX_COLLECT_STEP="Шаг 1.5: Только на ПЕРВОЙ итерации - дождаться завершения фоновой задачи codex, но не более 5 минут. Если codex не завершился за 5 минут - убить фоновый процесс, записать в отчёт Codex превысил таймаут 5 минут и был остановлен, продолжить без codex. Если codex завершился - проверить exit code. Если ненулевой exit code - прочитать .codex-review.stderr, записать в отчёт Codex завершился с ошибкой и текст ошибки, продолжить без codex. Если codex завершился успешно и файл .codex-review.md существует и не пуст - прочитать его. Если файл пуст - записать что Codex не нашёл замечаний. На последующих итерациях пропустить шаг 1.5. "
  CODEX_REPORT_NOTE="Если codex вернул результат - добавить issues от codex с пометкой codex отдельным списком. При подсчёте и отчёте НЕ дедуплицировать с review-pr, но при исправлении в Шаге 3 пропускать issues которые уже были исправлены ранее. "
fi

LINT_STEP=""
if [[ "$LINT" == "true" ]] && [[ -n "$LINT_CMD" ]]; then
  LINT_STEP="Шаг 3.5: Запустить $LINT_CMD для изменённых файлов. Если линтер изменил файлы, дописать это в .claude/pr-review-loop-report.local.md. "
fi

# Assemble prompt
PROMPT="КАЖДУЮ итерацию ВСЕГДА выполняй ВСЕ шаги по порядку. НЕ пропускай шаги, даже если в прошлой итерации ты уже исправил issues. ШАГИ -- ${CODEX_BG_STEP}Шаг 1: Запустить /pr-review-toolkit:review-pr $ASPECTS и дождаться результата. ${CODEX_COLLECT_STEP}Шаг 2: Собрать все issues. Из review-pr взять issues с пометкой review-pr. ${CODEX_REPORT_NOTE}Отфильтровать только issues с criticality от $MIN_CRITICALITY из 10 и выше. Issues с criticality ниже $MIN_CRITICALITY игнорировать. Добавить в файл .claude/pr-review-loop-report.local.md секцию текущей итерации - номер итерации, количество найденных issues выше порога, для каждого issue его источник и criticality и краткое описание с указанием файла. Шаг 3a: Если найдены issues выше порога - сгруппировать их по затронутому файлу или области кода. Для каждой уникальной группы запустить агент feature-dev:code-explorer через Task tool с задачей проанализировать архитектуру этой области кода, найти похожие реализации и паттерны, вернуть список ключевых файлов. Запускать explorer-агентов параллельно. Дождаться завершения всех. Шаг 3b: Прочитать ключевые файлы возвращённые каждым explorer-агентом для понимания контекста и паттернов. Дописать в .claude/pr-review-loop-report.local.md секцию EXPLORATION с результатами - область, найденные паттерны, ключевые файлы."

if [[ -n "$TEST_CMD" ]]; then
  PROMPT="$PROMPT Шаг 3c: Для каждого issue с criticality от 7 и выше применить TDD подход - ПЕРЕД исправлением написать фокусный spec в соответствующем spec-файле который воспроизводит проблему, запустить его через $TEST_CMD чтобы подтвердить что он ПАДАЕТ, затем исправить код минимально и точечно используя контекст из exploration, затем запустить spec снова чтобы подтвердить что он ПРОХОДИТ."
else
  PROMPT="$PROMPT Шаг 3c: Для каждого issue с criticality от 7 и выше применить TDD подход - ПЕРЕД исправлением написать фокусный тест который воспроизводит проблему, запустить его чтобы подтвердить что он ПАДАЕТ, затем исправить код минимально и точечно используя контекст из exploration, затем запустить тест снова чтобы подтвердить что он ПРОХОДИТ."
fi

PROMPT="$PROMPT Шаг 3d: Для каждого issue с criticality ниже 7 но выше порога - прочитать файл и строку, понять причину используя контекст из exploration, исправить минимально и точечно. НЕ рефакторить окружающий код, НЕ добавлять комментарии и docstrings, НЕ делать косметических правок. Шаг 3e: После всех исправлений дописать в .claude/pr-review-loop-report.local.md что было исправлено - для TDD-issues указать имя spec-файла и результаты red-green, для остальных краткое описание фикса. ${LINT_STEP}"

if [[ -n "$TEST_CMD" ]]; then
  PROMPT="$PROMPT Шаг 4: Если были исправления - запустить тесты $TEST_CMD для затронутых spec-файлов. Если падают - исправить."
else
  PROMPT="$PROMPT Шаг 4: Если были исправления - запустить тесты для затронутых файлов. Если падают - исправить."
fi

PROMPT="$PROMPT Шаг 5 - РЕШЕНИЕ И СТАТУС: Дописать в .claude/pr-review-loop-report.local.md маркер ИТЕРАЦИЯ N ЗАВЕРШЕНА issues_count=K где K это количество issues выше порога найденных в шаге 2 текущей итерации. Затем прочитать файл .claude/pr-review-loop-report.local.md и извлечь значения K из всех строк вида ИТЕРАЦИЯ M ЗАВЕРШЕНА issues_count=K. Построить массив counts по порядку итераций. РЕШЕНИЕ -- Вариант А ЧИСТО: Если K текущей итерации равно 0 - дописать статус ЧИСТО, добавить секцию ИТОГО с общим количеством итераций и исправленных issues, вывести <promise>REVIEW CLEAN</promise>. Вариант Б СТАГНАЦИЯ: Если массив counts содержит 5 или более значений И значение последнего элемента больше или равно значению элемента на позиции 5 с конца - дописать статус СТАГНАЦИЯ с трендом последних 5 значений, вывести <promise>REVIEW STAGNANT</promise>. Вариант В ПРОДОЛЖИТЬ: Иначе дописать статус ПРОДОЛЖИТЬ с количеством исправленных issues и завершить итерацию БЕЗ promise, loop продолжится."

# Append env-exec note only if CMD_PREFIX is set
if [[ -n "$CMD_PREFIX" ]]; then
  PROMPT="$PROMPT Все команды запускать через ${CMD_PREFIX%% }."
fi

# Validate: no template placeholders remain
if echo "$PROMPT" | grep -qE '\{[a-z_]+\}'; then
  echo "Error: Template placeholders remain in prompt" >&2
  echo "$PROMPT" | grep -oE '\{[a-z_]+\}' | sort -u >&2
  exit 1
fi

echo "$PROMPT"

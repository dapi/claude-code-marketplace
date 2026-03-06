#!/bin/bash
# Generate post-loop block response with prompt for Claude
# Usage: post-loop-prompt.sh --exit-type SUCCESS|STAGNANT|LIMIT|ERROR --message TEXT
#
# Outputs JSON: {"decision": "block", "reason": "<prompt>", "systemMessage": "<msg>"}

set -euo pipefail

EXIT_TYPE=""
MESSAGE=""
REPORT_FILE=".claude/pr-review-loop-report.local.md"
STATS_FILE=".claude/pr-review-loop-stats.local.json"

while [[ $# -gt 0 ]]; do
  case $1 in
    --exit-type) EXIT_TYPE="${2:-}"; shift; [[ $# -gt 0 ]] && shift ;;
    --message)   MESSAGE="${2:-}"; shift; [[ $# -gt 0 ]] && shift ;;
    *)           shift ;;
  esac
done

if [[ -z "$EXIT_TYPE" ]]; then
  echo '{"decision":"block","reason":"Error: post-loop-prompt called without --exit-type"}'
  exit 0
fi

# Read version from plugin.json (relative to this script)
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(jq -r '.version // "unknown"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "unknown")

# Build prompt based on exit type
case "$EXIT_TYPE" in
  SUCCESS)
    PROMPT="Review loop завершился: REVIEW CLEAN. Все issues исправлены.

Выполни следующие шаги:

1. Прочитай файл $REPORT_FILE и выведи компактную сводку в формате:
---
## PR Review Fix Loop v${VERSION} -- REVIEW CLEAN

Итераций: **N**
Время: **M мин**
Найдено issues: **total** (выше порога: **above_threshold**)
Исправлено: **fixed**
---

2. Запусти финальную проверку через Agent tool (subagent_type: 'superpowers:code-reviewer') для валидации всех сделанных исправлений. Если агент недоступен -- пропусти, запиши в отчёт 'Финальная проверка: пропущена (code-reviewer недоступен)'.

3. Сделай финальный коммит если есть незакоммиченные файлы (кроме *.local.md). Сообщение: 'fix: address PR review issues (final)'.

4. Запусти git push. Если есть PR -- дождись CI через gh pr checks --watch --fail-fast."
    SYS_MSG="Post-loop: REVIEW CLEAN. Execute summary, review, commit, push."
    ;;

  STAGNANT)
    PROMPT="Review loop завершился: СТАГНАЦИЯ. Issues не уменьшаются -- исправление одних порождает новые.

Выполни следующие шаги:

1. Прочитай файл $REPORT_FILE и выведи компактную сводку в формате:
---
## PR Review Fix Loop v${VERSION} -- СТАГНАЦИЯ

Итераций: **N**
Время: **M мин**
Найдено issues: **total** (выше порога: **above_threshold**)
Исправлено: **fixed**
Тренд issues: последние 5 значений через стрелку
---

2. Покажи пользователю объяснение: 'Стагнация означает что loop крутится вхолостую: исправляет одни проблемы, но при этом создаёт новые. Количество issues колеблется без устойчивого снижения.'

3. Запусти Agent tool (subagent_type: 'general-purpose') с промптом: 'Прочитай файл $REPORT_FILE. Проанализируй нерешённые issues из последних итераций. Определи корневые причины стагнации. Выведи: 1) ROOT CAUSES - группировка issues по корневым причинам; 2) RECOMMENDATIONS - для каждой группы что исправить вручную и подход; 3) AFFECTED FILES - список файлов. Формат plain text, маркеры [MANUAL] [APPROACH] [SKIP]. Final response under 2000 characters.'
Если Agent вернул ошибку -- запиши в отчёт 'Recommendation agent unavailable' и продолжи.

4. Результат выведи пользователю и допиши в $REPORT_FILE секцию 'STAGNATION ANALYSIS'.

5. НЕ пушить (не все issues решены). Предложи пользователю: увеличить --min-criticality или исправить оставшиеся issues вручную."
    SYS_MSG="Post-loop: STAGNATION detected. Execute summary, root-cause analysis, recommendations."
    ;;

  LIMIT)
    PROMPT="Review loop завершился: ЛИМИТ ИТЕРАЦИЙ. Максимальное количество итераций исчерпано, но issues остались.

Выполни следующие шаги:

1. Прочитай файл $REPORT_FILE и выведи компактную сводку в формате:
---
## PR Review Fix Loop v${VERSION} -- ЛИМИТ ИТЕРАЦИЙ

Итераций: **N**
Время: **M мин**
Найдено issues: **total** (выше порога: **above_threshold**)
Исправлено: **fixed**
Оставшиеся issues:
- criticality source: описание (файл)
---
Оставшиеся issues извлеки из последней итерации отчёта.

2. НЕ пушить (не все issues решены). Предложи пользователю: увеличить --max-iterations или исправить issues вручную."
    SYS_MSG="Post-loop: LIMIT REACHED. Execute summary, show remaining issues."
    ;;

  ERROR)
    PROMPT="Review loop завершился с ошибкой: ${MESSAGE}

Сообщи пользователю об ошибке и предложи:
1. Проверить файл .claude/pr-review-loop-debug.local.log
2. Перезапустить loop"
    SYS_MSG="Post-loop: ERROR. Report error to user."
    ;;

  *)
    PROMPT="Review loop завершился с неизвестным статусом: ${EXIT_TYPE}. Сообщение: ${MESSAGE}"
    SYS_MSG="Post-loop: Unknown exit type."
    ;;
esac

jq -n \
  --arg reason "$PROMPT" \
  --arg msg "$SYS_MSG" \
  '{
    "decision": "block",
    "reason": $reason,
    "systemMessage": $msg
  }'

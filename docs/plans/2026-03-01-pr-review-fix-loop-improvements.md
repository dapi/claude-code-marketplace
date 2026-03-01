# pr-review-fix-loop Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 6 review issues (7th rejected as harmful), make plugin multi-language, add 20 tests (unit + smoke).

**Architecture:** Extract testable bash scripts (detect-base-branch, detect-project, assemble-prompt) from prompt text. Commands call scripts instead of describing algorithms inline. Tests validate each script independently + smoke-test prompt assembly.

**Tech Stack:** Bash, jq, YAML frontmatter, JSONL transcripts.

**Review fixes applied:**
- P1: Removed Task 5 (`|| true` in Stop hook would break iteration engine)
- P2: Removed `run()` function from detect-project.sh, use `command -v` consistently
- P3: Fixed trailing "Все команды через ." — conditional inclusion only when CMD_PREFIX non-empty
- P4: Added `--env-exec` to detect-base-branch.sh for gh calls through direnv
- P5: Added concrete markdown template for Task 6 (command files)
- P6: Test 7 (.envrc) skips if direnv not installed
- P7: Simplified Test 25 cleanup assertion
- P8: Added warning when `--codex` without `--base` in assemble-prompt.sh

---

### Task 1: detect-project.sh + tests

**Files:**
- Create: `pr-review-fix-loop/scripts/detect-project.sh`
- Create: `pr-review-fix-loop/tests/test-detect-project.sh`

**Step 1: Write detect-project.sh**

```bash
#!/bin/bash
# Autodetects project stack, env wrapper, test command, lint command
# Output: JSON to stdout

set -euo pipefail

# Detect env wrapper
if [[ -f .envrc ]] && command -v direnv &>/dev/null; then
  ENV_EXEC="direnv exec ."
else
  ENV_EXEC=""
fi

STACK=""
TEST_CMD=""
LINT_CMD=""

if [[ -f Gemfile ]]; then
  STACK="ruby"
  TEST_CMD="bundle exec rspec"
  LINT_CMD="bundle exec rubocop -a"
elif [[ -f package.json ]]; then
  STACK="node"
  if jq -e '.scripts.test' package.json &>/dev/null; then
    TEST_CMD="npm test"
  else
    TEST_CMD=""
  fi
  if jq -e '.scripts.lint' package.json &>/dev/null; then
    LINT_CMD="npm run lint -- --fix"
  elif command -v eslint &>/dev/null; then
    LINT_CMD="npx eslint --fix ."
  elif command -v prettier &>/dev/null; then
    LINT_CMD="npx prettier --write ."
  else
    LINT_CMD=""
  fi
elif [[ -f pyproject.toml ]] || [[ -f requirements.txt ]]; then
  STACK="python"
  TEST_CMD="pytest"
  if command -v ruff &>/dev/null; then
    LINT_CMD="ruff check --fix ."
  elif command -v black &>/dev/null; then
    LINT_CMD="black ."
  else
    LINT_CMD=""
  fi
elif [[ -f go.mod ]]; then
  STACK="go"
  TEST_CMD="go test ./..."
  LINT_CMD="gofmt -w ."
elif [[ -f Cargo.toml ]]; then
  STACK="rust"
  TEST_CMD="cargo test"
  LINT_CMD="cargo clippy --fix --allow-dirty"
fi

# Prepend env_exec to commands if detected
if [[ -n "$ENV_EXEC" ]]; then
  [[ -n "$TEST_CMD" ]] && TEST_CMD="$ENV_EXEC $TEST_CMD"
  [[ -n "$LINT_CMD" ]] && LINT_CMD="$ENV_EXEC $LINT_CMD"
fi

jq -n \
  --arg stack "$STACK" \
  --arg env_exec "$ENV_EXEC" \
  --arg test_cmd "$TEST_CMD" \
  --arg lint_cmd "$LINT_CMD" \
  '{stack: $stack, env_exec: $env_exec, test_cmd: $test_cmd, lint_cmd: $lint_cmd}'
```

**Step 2: Write test-detect-project.sh**

```bash
#!/bin/bash
# Tests for detect-project.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DETECT_SCRIPT="$SCRIPT_DIR/scripts/detect-project.sh"

PASSED=0
FAILED=0
SKIPPED=0
TMPDIR=""

setup() {
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

pass() { PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  FAIL: $1"; [[ -n "${2:-}" ]] && echo "        $2"; }
skip() { SKIPPED=$((SKIPPED + 1)); echo "  SKIP: $1 ($2)"; }

echo "=== detect-project.sh ==="

# Test 1: Gemfile -> ruby
setup
touch Gemfile
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | jq -e '.stack == "ruby"' &>/dev/null && \
   echo "$OUTPUT" | jq -e '.test_cmd == "bundle exec rspec"' &>/dev/null && \
   echo "$OUTPUT" | jq -e '.lint_cmd == "bundle exec rubocop -a"' &>/dev/null; then
  pass "Gemfile -> ruby stack"
else
  fail "Gemfile -> ruby stack" "output=$OUTPUT"
fi
teardown

# Test 2: package.json -> node
setup
echo '{"scripts":{"test":"jest","lint":"eslint ."}}' > package.json
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | jq -e '.stack == "node"' &>/dev/null && \
   echo "$OUTPUT" | jq -e '.test_cmd == "npm test"' &>/dev/null && \
   echo "$OUTPUT" | jq -e '.lint_cmd == "npm run lint -- --fix"' &>/dev/null; then
  pass "package.json -> node stack"
else
  fail "package.json -> node stack" "output=$OUTPUT"
fi
teardown

# Test 3: pyproject.toml -> python
setup
touch pyproject.toml
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | jq -e '.stack == "python"' &>/dev/null && \
   echo "$OUTPUT" | jq -e '.test_cmd == "pytest"' &>/dev/null; then
  pass "pyproject.toml -> python stack"
else
  fail "pyproject.toml -> python stack" "output=$OUTPUT"
fi
teardown

# Test 4: go.mod -> go
setup
touch go.mod
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | jq -e '.stack == "go"' &>/dev/null && \
   echo "$OUTPUT" | jq -e '.test_cmd == "go test ./..."' &>/dev/null && \
   echo "$OUTPUT" | jq -e '.lint_cmd == "gofmt -w ."' &>/dev/null; then
  pass "go.mod -> go stack"
else
  fail "go.mod -> go stack" "output=$OUTPUT"
fi
teardown

# Test 5: Cargo.toml -> rust
setup
touch Cargo.toml
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | jq -e '.stack == "rust"' &>/dev/null && \
   echo "$OUTPUT" | jq -e '.test_cmd == "cargo test"' &>/dev/null; then
  pass "Cargo.toml -> rust stack"
else
  fail "Cargo.toml -> rust stack" "output=$OUTPUT"
fi
teardown

# Test 6: No markers -> empty
setup
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | jq -e '.stack == ""' &>/dev/null && \
   echo "$OUTPUT" | jq -e '.test_cmd == ""' &>/dev/null && \
   echo "$OUTPUT" | jq -e '.lint_cmd == ""' &>/dev/null; then
  pass "no markers -> empty values"
else
  fail "no markers -> empty values" "output=$OUTPUT"
fi
teardown

# Test 7: .envrc exists -> direnv exec . in env_exec (requires direnv)
if command -v direnv &>/dev/null; then
  setup
  touch Gemfile .envrc
  OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
  if echo "$OUTPUT" | jq -e '.env_exec == "direnv exec ."' &>/dev/null; then
    pass ".envrc exists -> direnv exec ."
  else
    fail ".envrc exists -> direnv exec ." "output=$OUTPUT"
  fi
  teardown
else
  skip ".envrc exists -> direnv exec ." "direnv not installed"
fi

# Test 8: No .envrc -> empty env_exec
setup
touch Gemfile
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | jq -e '.env_exec == ""' &>/dev/null; then
  pass "no .envrc -> empty env_exec"
else
  fail "no .envrc -> empty env_exec" "output=$OUTPUT"
fi
teardown

# Test 9: Multiple markers -> first wins (Gemfile over package.json)
setup
touch Gemfile
echo '{"scripts":{"test":"jest"}}' > package.json
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | jq -e '.stack == "ruby"' &>/dev/null; then
  pass "multiple markers -> first wins (ruby over node)"
else
  fail "multiple markers -> first wins (ruby over node)" "output=$OUTPUT"
fi
teardown

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed, $SKIPPED skipped"
echo "================================"
[[ $FAILED -gt 0 ]] && exit 1 || exit 0
```

**Step 3: Run tests**

Run: `bash pr-review-fix-loop/tests/test-detect-project.sh`
Expected: 8-9 passed (1 may skip if no direnv), 0 failed

**Step 4: Make scripts executable and commit**

```bash
chmod +x pr-review-fix-loop/scripts/detect-project.sh
chmod +x pr-review-fix-loop/tests/test-detect-project.sh
git add pr-review-fix-loop/scripts/detect-project.sh pr-review-fix-loop/tests/test-detect-project.sh
git commit -m "feat(pr-review-fix-loop): add detect-project.sh with 9 tests"
```

---

### Task 2: detect-base-branch.sh + tests

**Files:**
- Create: `pr-review-fix-loop/scripts/detect-base-branch.sh`
- Create: `pr-review-fix-loop/tests/test-detect-base-branch.sh`

**Step 1: Write detect-base-branch.sh**

```bash
#!/bin/bash
# Detects base branch for PR review
# Output: branch name to stdout, exit 1 on failure

set -euo pipefail

BASE=""
ENV_EXEC=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --base) BASE="${2:-}"; shift 2 ;;
    --env-exec) ENV_EXEC="${2:-}"; shift 2 ;;
    *) echo "Error: Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Helper: run command with optional env wrapper
run() {
  if [[ -n "$ENV_EXEC" ]]; then
    $ENV_EXEC "$@"
  else
    "$@"
  fi
}

# If --base provided, validate and use it
if [[ -n "$BASE" ]]; then
  if run git rev-parse --verify "$BASE" &>/dev/null; then
    echo "$BASE"
    exit 0
  else
    echo "Error: Base branch '$BASE' not found" >&2
    exit 1
  fi
fi

# Try autodetect from PR (gh may need env wrapper for direnv projects)
if command -v gh &>/dev/null || ($ENV_EXEC command -v gh &>/dev/null 2>&1); then
  PR_BASE=$(run gh pr view --json baseRefName -q .baseRefName 2>/dev/null || echo "")
  if [[ -n "$PR_BASE" ]] && run git rev-parse --verify "$PR_BASE" &>/dev/null; then
    echo "$PR_BASE"
    exit 0
  fi
fi

# Fallback: master
if run git rev-parse --verify master &>/dev/null; then
  echo "master"
  exit 0
fi

# Last resort: main
if run git rev-parse --verify main &>/dev/null; then
  echo "main"
  exit 0
fi

echo "Error: No base branch found (tried PR autodetect, master, main)" >&2
exit 1
```

**Step 2: Write test-detect-base-branch.sh**

```bash
#!/bin/bash
# Tests for detect-base-branch.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DETECT_SCRIPT="$SCRIPT_DIR/scripts/detect-base-branch.sh"

PASSED=0
FAILED=0
TMPDIR=""

setup_git() {
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  git init -b master -q
  git commit --allow-empty -m "init" -q
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

pass() { PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  FAIL: $1"; [[ -n "${2:-}" ]] && echo "        $2"; }

echo "=== detect-base-branch.sh ==="

# Test 1: --base flag returns specified branch
setup_git
OUTPUT=$(bash "$DETECT_SCRIPT" --base master 2>/dev/null)
if [[ "$OUTPUT" == "master" ]]; then
  pass "--base flag returns specified branch"
else
  fail "--base flag returns specified branch" "output='$OUTPUT'"
fi
teardown

# Test 2: --base with nonexistent branch -> exit 1
setup_git
if bash "$DETECT_SCRIPT" --base nonexistent 2>/dev/null; then
  fail "nonexistent --base -> exit 1" "expected failure"
else
  pass "nonexistent --base -> exit 1"
fi
teardown

# Test 3: No args, master exists -> fallback to master
setup_git
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if [[ "$OUTPUT" == "master" ]]; then
  pass "no args -> fallback to master"
else
  fail "no args -> fallback to master" "output='$OUTPUT'"
fi
teardown

# Test 4: No args, only main exists -> fallback to main
setup_git
git branch -m master main -q
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
if [[ "$OUTPUT" == "main" ]]; then
  pass "only main exists -> fallback to main"
else
  fail "only main exists -> fallback to main" "output='$OUTPUT'"
fi
teardown

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"
[[ $FAILED -gt 0 ]] && exit 1 || exit 0
```

**Step 3: Run tests**

Run: `bash pr-review-fix-loop/tests/test-detect-base-branch.sh`
Expected: 4 passed, 0 failed

**Step 4: Make executable and commit**

```bash
chmod +x pr-review-fix-loop/scripts/detect-base-branch.sh
chmod +x pr-review-fix-loop/tests/test-detect-base-branch.sh
git add pr-review-fix-loop/scripts/detect-base-branch.sh pr-review-fix-loop/tests/test-detect-base-branch.sh
git commit -m "feat(pr-review-fix-loop): add detect-base-branch.sh with 4 tests"
```

---

### Task 3: assemble-prompt.sh + smoke tests

**Files:**
- Create: `pr-review-fix-loop/scripts/assemble-prompt.sh`
- Create: `pr-review-fix-loop/tests/test-prompt-assembly.sh`

**Step 1: Write assemble-prompt.sh**

```bash
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

# Assemble prompt (single line, no template placeholders)
PROMPT="КАЖДУЮ итерацию ВСЕГДА выполняй ВСЕ шаги по порядку. НЕ пропускай шаги, даже если в прошлой итерации ты уже исправил issues. ШАГИ -- ${CODEX_BG_STEP}Шаг 1: Запустить /pr-review-toolkit:review-pr $ASPECTS и дождаться результата. ${CODEX_COLLECT_STEP}Шаг 2: Собрать все issues. Из review-pr взять issues с пометкой review-pr. ${CODEX_REPORT_NOTE}Отфильтровать только issues с criticality от $MIN_CRITICALITY из 10 и выше. Issues с criticality ниже $MIN_CRITICALITY игнорировать. Добавить в файл .claude/pr-review-loop-report.local.md секцию текущей итерации - номер итерации, количество найденных issues выше порога, для каждого issue его источник и criticality и краткое описание с указанием файла. Шаг 3a: Если найдены issues выше порога - сгруппировать их по затронутому файлу или области кода. Для каждой уникальной группы запустить агент feature-dev:code-explorer через Task tool с задачей проанализировать архитектуру этой области кода, найти похожие реализации и паттерны, вернуть список ключевых файлов. Запускать explorer-агентов параллельно. Дождаться завершения всех. Шаг 3b: Прочитать ключевые файлы возвращённые каждым explorer-агентом для понимания контекста и паттернов. Дописать в .claude/pr-review-loop-report.local.md секцию EXPLORATION с результатами - область, найденные паттерны, ключевые файлы."

# TDD step: use detected test command or generic instruction
if [[ -n "$TEST_CMD" ]]; then
  PROMPT="$PROMPT Шаг 3c: Для каждого issue с criticality от 7 и выше применить TDD подход - ПЕРЕД исправлением написать фокусный spec в соответствующем spec-файле который воспроизводит проблему, запустить его через $TEST_CMD чтобы подтвердить что он ПАДАЕТ, затем исправить код минимально и точечно используя контекст из exploration, затем запустить spec снова чтобы подтвердить что он ПРОХОДИТ."
else
  PROMPT="$PROMPT Шаг 3c: Для каждого issue с criticality от 7 и выше применить TDD подход - ПЕРЕД исправлением написать фокусный тест который воспроизводит проблему, запустить его чтобы подтвердить что он ПАДАЕТ, затем исправить код минимально и точечно используя контекст из exploration, затем запустить тест снова чтобы подтвердить что он ПРОХОДИТ."
fi

PROMPT="$PROMPT Шаг 3d: Для каждого issue с criticality ниже 7 но выше порога - прочитать файл и строку, понять причину используя контекст из exploration, исправить минимально и точечно. НЕ рефакторить окружающий код, НЕ добавлять комментарии и docstrings, НЕ делать косметических правок. Шаг 3e: После всех исправлений дописать в .claude/pr-review-loop-report.local.md что было исправлено - для TDD-issues указать имя spec-файла и результаты red-green, для остальных краткое описание фикса. ${LINT_STEP}"

# Test step: use detected test command
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
if echo "$PROMPT" | grep -qP '\{[a-z_]+\}'; then
  echo "Error: Template placeholders remain in prompt" >&2
  echo "$PROMPT" | grep -oP '\{[a-z_]+\}' | sort -u >&2
  exit 1
fi

echo "$PROMPT"
```

**Step 2: Write test-prompt-assembly.sh**

```bash
#!/bin/bash
# Smoke tests for prompt assembly

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSEMBLE_SCRIPT="$SCRIPT_DIR/scripts/assemble-prompt.sh"

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  FAIL: $1"; [[ -n "${2:-}" ]] && echo "        $2"; }

echo "=== prompt assembly smoke tests ==="

# Test 1: Default args - no template placeholders
OUTPUT=$(bash "$ASSEMBLE_SCRIPT" 2>/dev/null)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]] && \
   ! echo "$OUTPUT" | grep -qP '\{[a-z_]+\}'; then
  pass "default args: no template placeholders"
else
  fail "default args: no template placeholders" "exit=$EXIT_CODE"
fi

# Test 2: --codex flag includes codex steps
OUTPUT=$(bash "$ASSEMBLE_SCRIPT" --codex --base master 2>/dev/null)
if echo "$OUTPUT" | grep -q 'codex review --base master' && \
   echo "$OUTPUT" | grep -q 'Шаг 0:' && \
   echo "$OUTPUT" | grep -q 'Шаг 1.5:'; then
  pass "--codex: codex steps present"
else
  fail "--codex: codex steps present"
fi

# Test 3: --lint with lint command
OUTPUT=$(bash "$ASSEMBLE_SCRIPT" --lint --lint-cmd "bundle exec rubocop -a" 2>/dev/null)
if echo "$OUTPUT" | grep -q 'Шаг 3.5:' && \
   echo "$OUTPUT" | grep -q 'bundle exec rubocop -a'; then
  pass "--lint: lint step with command"
else
  fail "--lint: lint step with command"
fi

# Test 4: --codex --lint combined
OUTPUT=$(bash "$ASSEMBLE_SCRIPT" --codex --base main --lint --lint-cmd "rubocop -a" 2>/dev/null)
if echo "$OUTPUT" | grep -q 'Шаг 0:' && \
   echo "$OUTPUT" | grep -q 'Шаг 3.5:'; then
  pass "--codex --lint: both steps present"
else
  fail "--codex --lint: both steps present"
fi

# Test 5: Single line (no newlines)
OUTPUT=$(bash "$ASSEMBLE_SCRIPT" 2>/dev/null)
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
if [[ $LINE_COUNT -eq 1 ]]; then
  pass "output is single line"
else
  fail "output is single line" "got $LINE_COUNT lines"
fi

# Test 6: --codex without --base warns on stderr, no codex steps in output
STDERR=$(bash "$ASSEMBLE_SCRIPT" --codex 2>&1 >/dev/null)
OUTPUT=$(bash "$ASSEMBLE_SCRIPT" --codex 2>/dev/null)
if echo "$STDERR" | grep -q 'Warning.*--codex.*--base' && \
   ! echo "$OUTPUT" | grep -q 'Шаг 0:'; then
  pass "--codex without --base: warns, no codex steps"
else
  fail "--codex without --base: warns, no codex steps" "stderr='$STDERR'"
fi

# Test 7: No env-exec -> no "Все команды" suffix
OUTPUT=$(bash "$ASSEMBLE_SCRIPT" 2>/dev/null)
if ! echo "$OUTPUT" | grep -q 'Все команды запускать через'; then
  pass "no env-exec: no command prefix suffix"
else
  fail "no env-exec: no command prefix suffix"
fi

# Test 8: With env-exec -> "Все команды" suffix present
OUTPUT=$(bash "$ASSEMBLE_SCRIPT" --env-exec "direnv exec ." 2>/dev/null)
if echo "$OUTPUT" | grep -q 'Все команды запускать через direnv exec .'; then
  pass "env-exec: command prefix suffix present"
else
  fail "env-exec: command prefix suffix present"
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"
[[ $FAILED -gt 0 ]] && exit 1 || exit 0
```

**Step 3: Run smoke tests**

Run: `bash pr-review-fix-loop/tests/test-prompt-assembly.sh`
Expected: 8 passed, 0 failed

**Step 4: Commit**

```bash
chmod +x pr-review-fix-loop/scripts/assemble-prompt.sh
chmod +x pr-review-fix-loop/tests/test-prompt-assembly.sh
git add pr-review-fix-loop/scripts/assemble-prompt.sh pr-review-fix-loop/tests/test-prompt-assembly.sh
git commit -m "feat(pr-review-fix-loop): add assemble-prompt.sh with 8 smoke tests"
```

---

### Task 4: Extend existing tests (+2)

**Files:**
- Modify: `pr-review-fix-loop/tests/test-loop-scripts.sh` (append after test 24)

**Step 1: Add tests 25-26**

Append before the `# --- Summary ---` line:

```bash
# Test 25: Setup cleans previous artifacts
setup
# Create stale artifacts
echo "stale report" > .claude/pr-review-loop-report.local.md
echo "stale codex" > .codex-review.md
echo "stale stderr" > .codex-review.stderr
echo "test prompt" | bash "$SETUP_SCRIPT" >/dev/null
ok=true
[[ ! -f .claude/pr-review-loop-report.local.md ]] || ok=false
[[ ! -f .codex-review.md ]] || ok=false
[[ ! -f .codex-review.stderr ]] || ok=false
if $ok; then
  pass "setup cleans previous artifacts"
else
  fail "setup cleans previous artifacts" "report=$(test -f .claude/pr-review-loop-report.local.md && echo exists || echo gone) codex=$(test -f .codex-review.md && echo exists || echo gone)"
fi
teardown

# Test 26: Setup outputs version
setup
OUTPUT=$(echo "test prompt" | bash "$SETUP_SCRIPT" 2>/dev/null)
if echo "$OUTPUT" | grep -qP '^pr-review-fix-loop v\d+\.\d+\.\d+$'; then
  pass "setup outputs version"
else
  fail "setup outputs version" "output='$(echo "$OUTPUT" | head -1)'"
fi
teardown
```

**Step 2: Run all tests**

Run: `bash pr-review-fix-loop/tests/test-loop-scripts.sh`
Expected: 26 passed, 0 failed

**Step 3: Commit**

```bash
git add pr-review-fix-loop/tests/test-loop-scripts.sh
git commit -m "test(pr-review-fix-loop): add cleanup and version output tests"
```

---

### Task 5: Update commands to use new scripts

**Files:**
- Modify: `pr-review-fix-loop/commands/pr-review-fix-loop.md`
- Modify: `pr-review-fix-loop/commands/codex-pr-review.md`

**Step 1: Update pr-review-fix-loop.md**

Replace the command with this structure (preserving argument docs and examples):

```markdown
---
description: "Iterative PR review + autofix loop (built-in iteration engine + pr-review-toolkit)"
argument-hint: "[--max-iterations N] [--aspects ASPECTS] [--min-criticality N] [--lint] [--codex] [--base BRANCH]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*:*)"]
---

# PR Review Fix Loop

Итеративный цикл: запустить PR review, исправить критические и важные замечания, повторить до чистого отчёта.

## Парсинг аргументов

[KEEP existing argument parsing section unchanged]

## Валидация аргументов

[KEEP existing validation section unchanged]

## Проверки перед запуском

### Детект проекта

Запустить detect-project.sh и получить JSON с параметрами проекта:

\```bash
PROJECT_JSON=$("${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh")
STACK=$(echo "$PROJECT_JSON" | jq -r '.stack')
ENV_EXEC=$(echo "$PROJECT_JSON" | jq -r '.env_exec')
TEST_CMD=$(echo "$PROJECT_JSON" | jq -r '.test_cmd')
LINT_CMD=$(echo "$PROJECT_JSON" | jq -r '.lint_cmd')
\```

Если STACK пустой — записать предупреждение "Тип проекта не определён, TDD и тесты будут в generic-режиме" в отчёт и продолжить.

Если `--lint` указан но LINT_CMD пустой — записать предупреждение "Линтер не найден для стека $STACK" и продолжить без линтера.

### Детект base branch (если --codex)

Если `--codex` указан:

\```bash
BASE=$("${CLAUDE_PLUGIN_ROOT}/scripts/detect-base-branch.sh" --base "${user_base:-}" --env-exec "$ENV_EXEC")
\```

Если скрипт вернул ошибку — сообщить пользователю и прекратить выполнение.

Если `--codex` НЕ указан:
1. Проверить что codex CLI установлен: `${ENV_EXEC:+$ENV_EXEC }which codex`
2. Если не установлен — сообщить пользователю и прекратить выполнение.

## Создание файла отчёта

[KEEP existing report creation section unchanged]

## Запуск iteration loop

### Сборка промпта

Запустить assemble-prompt.sh с параметрами:

\```bash
PROMPT=$("${CLAUDE_PLUGIN_ROOT}/scripts/assemble-prompt.sh" \
  --aspects "$ASPECTS" \
  --min-criticality "$MIN_CRITICALITY" \
  ${CODEX:+--codex} \
  ${LINT:+--lint} \
  ${BASE:+--base "$BASE"} \
  ${TEST_CMD:+--test-cmd "$TEST_CMD"} \
  ${LINT_CMD:+--lint-cmd "$LINT_CMD"} \
  ${ENV_EXEC:+--env-exec "$ENV_EXEC"})
\```

### Запуск setup-loop.sh

Передать собранный промпт в setup-loop.sh через heredoc:

\```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" --max-iterations $MAX_ITERATIONS --completion-promise "REVIEW CLEAN" --completion-promise "REVIEW STAGNANT" <<'LOOP_PROMPT'
$PROMPT
LOOP_PROMPT
\```

После запуска setup-loop.sh выполнить шаги из промпта. Stop hook автоматически подаст тот же промпт при завершении каждой итерации.

## После завершения loop

[KEEP existing post-loop section unchanged]

## Значения по умолчанию

[KEEP existing defaults table unchanged]

## Примеры использования

[KEEP existing examples unchanged]
```

Key changes summary:
1. `allowed-tools`: `scripts/setup-loop.sh:*` -> `scripts/*:*`
2. Removed inline "Автодетект линтера" table and algorithm (40+ lines) -> call to `detect-project.sh`
3. Removed inline base branch detection algorithm (10+ lines) -> call to `detect-base-branch.sh`
4. Removed inline prompt template with `{placeholders}` (30+ lines) -> call to `assemble-prompt.sh`
5. Removed all hardcoded `direnv exec .` and `bundle exec rspec`
6. Removed "Связь с /codex-pr-review" duplicate logic note (no longer needed, logic is in scripts)

**Step 2: Update codex-pr-review.md**

Replace the "Определение base branch" section with:

```markdown
## Определение base branch

Запустить detect-base-branch.sh:

\```bash
BASE=$("${CLAUDE_PLUGIN_ROOT}/scripts/detect-base-branch.sh" --base "${user_base:-}")
\```

Если скрипт вернул ошибку — вывести сообщение об ошибке и прекратить выполнение.
```

Replace "Проверки перед запуском" section — remove inline `direnv exec . which codex`, use detect-project.sh env_exec:

```markdown
## Проверки перед запуском

Получить env wrapper:

\```bash
ENV_EXEC=$("${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh" | jq -r '.env_exec')
\```

Убедиться что codex CLI установлен:
\```bash
${ENV_EXEC:+$ENV_EXEC }which codex
\```
Если не установлен — сообщить пользователю и прекратить выполнение.

Убедиться что есть изменения:
\```bash
${ENV_EXEC:+$ENV_EXEC }git diff $BASE...HEAD --stat
\```
Если diff пустой — сообщить что нет изменений для ревью и прекратить.
```

Replace "Запуск Codex" section — use env_exec:

```markdown
## Запуск Codex

\```bash
${ENV_EXEC:+$ENV_EXEC }codex review --base $BASE
\```
```

Also update `allowed-tools` in frontmatter:
```yaml
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*:*)"]
```

**Step 3: Verify no hardcoded paths remain**

Run: `grep -n 'direnv exec\|bundle exec rspec' pr-review-fix-loop/commands/*.md`
Expected: no matches

**Step 4: Commit**

```bash
git add pr-review-fix-loop/commands/pr-review-fix-loop.md pr-review-fix-loop/commands/codex-pr-review.md
git commit -m "refactor(pr-review-fix-loop): use detect scripts instead of inline logic"
```

---

### Task 6: Update README + plugin.json + keywords

**Files:**
- Modify: `pr-review-fix-loop/README.md`
- Modify: `pr-review-fix-loop/.claude-plugin/plugin.json`

**Step 1: Update README.md**

Change first line:
```
- Iterative PR review + autofix loop for Ruby/Rails projects.
+ Multi-language iterative PR review + autofix loop.
```

Add after "Uses a built-in iteration engine..." paragraph:

```markdown
**Supported stacks** (auto-detected):
- Ruby (rspec, rubocop)
- Node.js (npm test, eslint/prettier)
- Python (pytest, ruff/black)
- Go (go test, gofmt)
- Rust (cargo test, cargo clippy)
```

Update Dependencies section — remove "Ruby/Rails stack" as required, make it one of supported:

```markdown
## Dependencies

**Required plugins:**
\```
/plugin install pr-review-toolkit
/plugin install feature-dev
\```

**Required tools:**
- **gh** CLI -- for auto-detecting base branch from PR

**Auto-detected per stack:**
- Ruby: `bundle`, `rspec`, `rubocop`
- Node.js: `npm`, `eslint`/`prettier`
- Python: `pytest`, `ruff`/`black`
- Go: `go`, `gofmt`
- Rust: `cargo`, `clippy`

**Optional:**
- **direnv** -- auto-detected if `.envrc` exists
- **codex** CLI -- OpenAI Codex, for `--codex` flag (`npm install -g @openai/codex`)
```

**Step 2: Update plugin.json**

```json
{
  "name": "pr-review-fix-loop",
  "description": "Multi-language iterative PR review + autofix loop (built-in iteration engine + pr-review-toolkit + optional Codex)",
  "version": "1.5.0",
  "author": {
    "name": "Danil Pismenny",
    "email": "danilpismenny@gmail.com"
  },
  "homepage": "https://github.com/dapi/claude-code-marketplace",
  "repository": "https://github.com/dapi/claude-code-marketplace",
  "license": "MIT",
  "keywords": ["pr-review", "code-review", "autofix", "iteration-loop", "codex", "multi-language", "ruby", "node", "python", "go", "rust"]
}
```

**Step 3: Run all tests**

```bash
bash pr-review-fix-loop/tests/test-loop-scripts.sh && \
bash pr-review-fix-loop/tests/test-detect-project.sh && \
bash pr-review-fix-loop/tests/test-detect-base-branch.sh && \
bash pr-review-fix-loop/tests/test-prompt-assembly.sh
```
Expected: all pass

**Step 4: Run emoji lint**

Run: `./scripts/lint_no_emoji.sh pr-review-fix-loop`
Expected: no supplementary plane characters found

**Step 5: Commit**

```bash
git add pr-review-fix-loop/README.md pr-review-fix-loop/.claude-plugin/plugin.json
git commit -m "feat(pr-review-fix-loop): multi-language support, bump to v1.5.0"
```

---

### Summary

| Task | Files | Tests | Commit |
|-|-|-|-|
| 1 | detect-project.sh | 9 unit | feat: detect-project |
| 2 | detect-base-branch.sh | 4 unit | feat: detect-base-branch |
| 3 | assemble-prompt.sh | 8 smoke | feat: assemble-prompt |
| 4 | test-loop-scripts.sh | +2 unit | test: cleanup+version |
| 5 | 2 command .md files | - | refactor: use scripts |
| 6 | README + plugin.json | full suite | feat: multi-language v1.5.0 |

Total: 6 commits, 3 new scripts, 4 test files, 23 new tests.

**Removed from plan:** Task 5 (hooks.json `|| true`) — would break Stop hook iteration engine. The hook MUST return JSON with `"decision": "block"` to continue the loop; `|| true` would suppress that on failure and silently exit the session.

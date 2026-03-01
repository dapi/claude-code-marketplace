#!/bin/bash
# Autodetects project stack, env wrapper, test command, lint command
# Output: JSON to stdout

set -euo pipefail

command -v jq &>/dev/null || { echo "Error: jq is required but not installed" >&2; exit 1; }

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

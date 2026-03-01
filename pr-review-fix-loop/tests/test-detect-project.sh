#!/bin/bash

# Tests for detect-project.sh
# Usage: ./pr-review-fix-loop/tests/test-detect-project.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DETECT_SCRIPT="$SCRIPT_DIR/scripts/detect-project.sh"

PASSED=0
FAILED=0
SKIPPED=0
TMPDIR=""

# --- Helpers ---

setup() {
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

pass() {
  PASSED=$((PASSED + 1))
  echo "  PASS: $1"
}

fail() {
  FAILED=$((FAILED + 1))
  echo "  FAIL: $1"
  if [[ -n "${2:-}" ]]; then
    echo "        $2"
  fi
}

skip() {
  SKIPPED=$((SKIPPED + 1))
  echo "  SKIP: $1 ($2)"
}

# --- Tests ---

echo "=== detect-project.sh ==="

# Test 1: Gemfile -> ruby
setup
touch Gemfile
OUTPUT=$(bash "$DETECT_SCRIPT")
ok=true
echo "$OUTPUT" | jq -e '.stack == "ruby"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.test_cmd == "bundle exec rspec"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.lint_cmd == "bundle exec rubocop -a"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "Gemfile -> ruby (stack, test_cmd, lint_cmd)"
else
  fail "Gemfile -> ruby (stack, test_cmd, lint_cmd)" "output=$OUTPUT"
fi
teardown

# Test 2: package.json with scripts.test + scripts.lint -> node
setup
cat > package.json <<'EOF'
{"scripts": {"test": "jest", "lint": "eslint ."}}
EOF
OUTPUT=$(bash "$DETECT_SCRIPT")
ok=true
echo "$OUTPUT" | jq -e '.stack == "node"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.test_cmd == "npm test"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.lint_cmd == "npm run lint -- --fix"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "package.json with scripts.test+scripts.lint -> node"
else
  fail "package.json with scripts.test+scripts.lint -> node" "output=$OUTPUT"
fi
teardown

# Test 3: pyproject.toml -> python
setup
touch pyproject.toml
OUTPUT=$(bash "$DETECT_SCRIPT")
ok=true
echo "$OUTPUT" | jq -e '.stack == "python"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.test_cmd == "pytest"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "pyproject.toml -> python"
else
  fail "pyproject.toml -> python" "output=$OUTPUT"
fi
teardown

# Test 3b: requirements.txt -> python
setup
touch requirements.txt
OUTPUT=$(bash "$DETECT_SCRIPT")
ok=true
echo "$OUTPUT" | jq -e '.stack == "python"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.test_cmd == "pytest"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "requirements.txt -> python"
else
  fail "requirements.txt -> python" "output=$OUTPUT"
fi
teardown

# Test 4: go.mod -> go
setup
touch go.mod
OUTPUT=$(bash "$DETECT_SCRIPT")
ok=true
echo "$OUTPUT" | jq -e '.stack == "go"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.test_cmd == "go test ./..."' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.lint_cmd == "gofmt -w ."' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "go.mod -> go"
else
  fail "go.mod -> go" "output=$OUTPUT"
fi
teardown

# Test 5: Cargo.toml -> rust
setup
touch Cargo.toml
OUTPUT=$(bash "$DETECT_SCRIPT")
ok=true
echo "$OUTPUT" | jq -e '.stack == "rust"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.test_cmd == "cargo test"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.lint_cmd == "cargo clippy --fix --allow-dirty"' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "Cargo.toml -> rust"
else
  fail "Cargo.toml -> rust" "output=$OUTPUT"
fi
teardown

# Test 6: No markers -> empty values
setup
OUTPUT=$(bash "$DETECT_SCRIPT")
ok=true
echo "$OUTPUT" | jq -e '.stack == ""' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.test_cmd == ""' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.lint_cmd == ""' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.env_exec == ""' >/dev/null 2>&1 || ok=false
if $ok; then
  pass "no markers -> empty values"
else
  fail "no markers -> empty values" "output=$OUTPUT"
fi
teardown

# Test 7: .envrc + Gemfile -> env_exec="direnv exec ." (SKIP if no direnv)
if command -v direnv &>/dev/null; then
  setup
  touch .envrc Gemfile
  OUTPUT=$(bash "$DETECT_SCRIPT")
  ok=true
  echo "$OUTPUT" | jq -e '.env_exec == "direnv exec ."' >/dev/null 2>&1 || ok=false
  echo "$OUTPUT" | jq -e '.test_cmd == "direnv exec . bundle exec rspec"' >/dev/null 2>&1 || ok=false
  echo "$OUTPUT" | jq -e '.lint_cmd == "direnv exec . bundle exec rubocop -a"' >/dev/null 2>&1 || ok=false
  if $ok; then
    pass ".envrc + Gemfile -> env_exec with direnv"
  else
    fail ".envrc + Gemfile -> env_exec with direnv" "output=$OUTPUT"
  fi
  teardown
else
  skip ".envrc + Gemfile -> env_exec with direnv" "direnv not installed"
fi

# Test 8: No .envrc + Gemfile -> env_exec=""
setup
touch Gemfile
OUTPUT=$(bash "$DETECT_SCRIPT")
if echo "$OUTPUT" | jq -e '.env_exec == ""' >/dev/null 2>&1; then
  pass "no .envrc + Gemfile -> env_exec empty"
else
  fail "no .envrc + Gemfile -> env_exec empty" "output=$OUTPUT"
fi
teardown

# Test 9: Gemfile + package.json -> ruby wins (first marker priority)
setup
touch Gemfile
cat > package.json <<'EOF'
{"scripts": {"test": "jest", "lint": "eslint ."}}
EOF
OUTPUT=$(bash "$DETECT_SCRIPT")
if echo "$OUTPUT" | jq -e '.stack == "ruby"' >/dev/null 2>&1; then
  pass "Gemfile + package.json -> ruby wins (first marker priority)"
else
  fail "Gemfile + package.json -> ruby wins (first marker priority)" "output=$OUTPUT"
fi
teardown

# --- Summary ---

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed, $SKIPPED skipped"
echo "================================"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi

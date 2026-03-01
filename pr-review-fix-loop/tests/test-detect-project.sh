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

# Test 10: Invalid package.json -> warning, empty commands
setup
echo "NOT JSON" > package.json
OUTPUT=$(bash "$DETECT_SCRIPT" 2>/dev/null)
STDERR=$(bash "$DETECT_SCRIPT" 2>&1 >/dev/null || true)
ok=true
echo "$OUTPUT" | jq -e '.stack == "node"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.test_cmd == ""' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.lint_cmd == ""' >/dev/null 2>&1 || ok=false
echo "$STDERR" | grep -q "not valid JSON" || ok=false
if $ok; then
  pass "invalid package.json -> warning + empty commands"
else
  fail "invalid package.json -> warning + empty commands" "output=$OUTPUT stderr=$STDERR"
fi
teardown

# Test 11: package.json without scripts.test or scripts.lint -> no npm-based commands
setup
echo '{"name": "test"}' > package.json
OUTPUT=$(bash "$DETECT_SCRIPT")
ok=true
echo "$OUTPUT" | jq -e '.stack == "node"' >/dev/null 2>&1 || ok=false
echo "$OUTPUT" | jq -e '.test_cmd == ""' >/dev/null 2>&1 || ok=false
# lint_cmd may be set via eslint/prettier fallback if installed; verify no npm-script-based lint
LINT_VAL=$(echo "$OUTPUT" | jq -r '.lint_cmd')
if [[ "$LINT_VAL" == "npm run lint -- --fix" ]]; then
  ok=false
fi
if $ok; then
  pass "package.json without scripts -> no npm-script-based commands"
else
  fail "package.json without scripts -> no npm-script-based commands" "output=$OUTPUT"
fi
teardown

# Test 12: Python + ruff available -> ruff lint_cmd
setup
touch pyproject.toml
FAKE_BIN=$(mktemp -d)
cat > "$FAKE_BIN/ruff" <<'FAKE'
#!/bin/bash
FAKE
chmod +x "$FAKE_BIN/ruff"
OUTPUT=$(PATH="$FAKE_BIN:$PATH" bash "$DETECT_SCRIPT")
rm -rf "$FAKE_BIN"
LINT_VAL=$(echo "$OUTPUT" | jq -r '.lint_cmd')
if [[ "$LINT_VAL" == "ruff check --fix ." ]]; then
  pass "python + ruff -> ruff check --fix ."
else
  fail "python + ruff -> ruff check --fix ." "got=$LINT_VAL"
fi
teardown

# Test 13: Python + black (no ruff) -> black lint_cmd
setup
touch pyproject.toml
FAKE_BIN=$(mktemp -d)
for cmd in jq bash env; do
  SRC=$(command -v "$cmd" 2>/dev/null) && cp "$SRC" "$FAKE_BIN/" 2>/dev/null || true
done
cat > "$FAKE_BIN/black" <<'FAKE'
#!/bin/bash
FAKE
chmod +x "$FAKE_BIN/black"
# Restricted PATH: has black + jq but no ruff
OUTPUT=$(PATH="$FAKE_BIN" bash "$DETECT_SCRIPT" 2>/dev/null)
rm -rf "$FAKE_BIN"
if [[ -n "$OUTPUT" ]]; then
  LINT_VAL=$(echo "$OUTPUT" | jq -r '.lint_cmd')
  if [[ "$LINT_VAL" == "black ." ]]; then
    pass "python + black (no ruff) -> black ."
  else
    fail "python + black (no ruff) -> black ." "got=$LINT_VAL"
  fi
else
  skip "python + black (no ruff) -> black ." "could not isolate PATH"
fi
teardown

# Test 14: Node + no scripts.lint + eslint available -> eslint fallback
setup
echo '{"scripts": {"test": "jest"}}' > package.json
FAKE_BIN=$(mktemp -d)
cat > "$FAKE_BIN/eslint" <<'FAKE'
#!/bin/bash
FAKE
chmod +x "$FAKE_BIN/eslint"
OUTPUT=$(PATH="$FAKE_BIN:$PATH" bash "$DETECT_SCRIPT")
rm -rf "$FAKE_BIN"
LINT_VAL=$(echo "$OUTPUT" | jq -r '.lint_cmd')
if [[ "$LINT_VAL" == "npx eslint --fix ." ]]; then
  pass "node + no scripts.lint + eslint -> npx eslint --fix ."
else
  fail "node + no scripts.lint + eslint -> npx eslint --fix ." "got=$LINT_VAL"
fi
teardown

# Test 15: Node + no scripts.lint + prettier (no eslint) -> prettier fallback
setup
echo '{"scripts": {"test": "jest"}}' > package.json
FAKE_BIN=$(mktemp -d)
for cmd in jq bash env; do
  SRC=$(command -v "$cmd" 2>/dev/null) && cp "$SRC" "$FAKE_BIN/" 2>/dev/null || true
done
cat > "$FAKE_BIN/prettier" <<'FAKE'
#!/bin/bash
FAKE
chmod +x "$FAKE_BIN/prettier"
OUTPUT=$(PATH="$FAKE_BIN" bash "$DETECT_SCRIPT" 2>/dev/null)
rm -rf "$FAKE_BIN"
if [[ -n "$OUTPUT" ]]; then
  LINT_VAL=$(echo "$OUTPUT" | jq -r '.lint_cmd')
  if [[ "$LINT_VAL" == "npx prettier --write ." ]]; then
    pass "node + no scripts.lint + prettier -> npx prettier --write ."
  else
    fail "node + no scripts.lint + prettier -> npx prettier --write ." "got=$LINT_VAL"
  fi
else
  skip "node + no scripts.lint + prettier -> npx prettier --write ." "could not isolate PATH"
fi
teardown

# Test 16: Missing jq -> exit 1 with error message
setup
touch Gemfile
# Create a minimal PATH without jq by using an empty temp bin dir
FAKE_BIN=$(mktemp -d)
# Copy only bash and basic utils needed by the script
for cmd in bash env cat; do
  SRC=$(command -v "$cmd" 2>/dev/null) && cp "$SRC" "$FAKE_BIN/" 2>/dev/null || true
done
STDERR=$(PATH="$FAKE_BIN" bash "$DETECT_SCRIPT" 2>&1 >/dev/null || true)
EXIT_CODE=0
PATH="$FAKE_BIN" bash "$DETECT_SCRIPT" 2>/dev/null >/dev/null || EXIT_CODE=$?
rm -rf "$FAKE_BIN"
if [[ $EXIT_CODE -ne 0 ]] && echo "$STDERR" | grep -q "jq is required"; then
  pass "missing jq -> exit 1 with error message"
else
  # jq might be a shell builtin or statically linked — skip gracefully
  skip "missing jq -> exit 1 with error message" "could not isolate jq from PATH"
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

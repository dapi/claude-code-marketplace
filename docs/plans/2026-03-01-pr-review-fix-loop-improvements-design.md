# pr-review-fix-loop Improvements Design

Date: 2026-03-01
Status: Approved

## Problem Statement

7 issues found during plugin review:
1. Race condition in sed update (minor, accepted)
2. `direnv exec .` hardcoded -- breaks non-direnv projects
3. Base branch logic duplicated between two command files
4. README says "Ruby/Rails" but linter autodetect covers 5 stacks
5. hooks.json missing `|| true` for graceful degradation
6. `allowed-tools` too narrow for new scripts
7. No test for setup-loop.sh cleanup of previous artifacts

Plus: plugin is complex enough to need more tests and smoke validation.

## Design Decisions

- **Universality**: Full autodetect of env wrapper, test command, lint command
- **Testing**: Unit + smoke tests (no CI workflow changes)
- **Race condition (#1)**: Accept as-is (Stop hook is synchronous)

## New Scripts

### scripts/detect-base-branch.sh

Eliminates duplication between pr-review-fix-loop.md and codex-pr-review.md.

Input: `--base BRANCH` (optional), reads git/gh context
Output: branch name to stdout, exit 1 on failure

Priority:
1. `--base` argument if provided
2. `gh pr view --json baseRefName` (if gh installed and PR exists)
3. Fallback: `master`

env_exec detection: uses `direnv exec .` if `.envrc` exists, otherwise runs commands directly.

### scripts/detect-project.sh

Autodetects project stack by marker files.

Output: JSON to stdout:
```json
{
  "stack": "ruby",
  "env_exec": "direnv exec .",
  "test_cmd": "bundle exec rspec",
  "lint_cmd": "bundle exec rubocop -a"
}
```

Marker priority: Gemfile > package.json > pyproject.toml > go.mod > Cargo.toml

env_exec: `direnv exec .` only if `.envrc` exists, otherwise empty string.

### scripts/assemble-prompt.sh

Builds the one-line prompt from template with variable substitution.

Input: flags via arguments (--aspects, --min-criticality, --codex, --lint, --base, etc.) + detect-project.sh output
Output: single-line prompt to stdout

Validates: no `{}`, `[]`, `<>`, quotes remain in output.

## File Changes

| File | Change |
|-|-|
| scripts/detect-base-branch.sh | New |
| scripts/detect-project.sh | New |
| scripts/assemble-prompt.sh | New |
| commands/pr-review-fix-loop.md | Call scripts instead of inline logic |
| commands/codex-pr-review.md | Call detect-base-branch.sh |
| hooks/hooks.json | Add `\|\| true` |
| README.md | Multi-language description |
| .claude-plugin/plugin.json | Bump version (minor) |
| tests/test-loop-scripts.sh | +2 tests (cleanup, version output) |
| tests/test-detect-base-branch.sh | New, 4 tests |
| tests/test-detect-project.sh | New, 9 tests |
| tests/test-prompt-assembly.sh | New, 5 smoke tests |

## Test Plan

### Unit tests for detect-base-branch.sh (4 tests)
- --base flag returns specified branch
- git rev-parse fail -> error
- No args, no PR -> fallback to master
- gh not installed -> graceful skip

### Unit tests for detect-project.sh (9 tests)
- Each of 5 stacks detected correctly
- No markers -> empty values
- .envrc exists -> direnv exec .
- No .envrc -> empty env_exec
- Multiple markers -> first wins

### Smoke tests for prompt assembly (5 tests)
- Default args: no template placeholders remain
- --codex: codex steps present
- --lint: lint step present with real command
- --codex --lint: both steps, no conflicts
- Single line: no newlines in output

### Existing tests extended (+2)
- setup-loop.sh cleanup of previous artifacts
- setup-loop.sh version output

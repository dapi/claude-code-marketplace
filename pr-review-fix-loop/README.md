# pr-review-fix-loop

Iterative PR review + autofix loop for Ruby/Rails projects.

## Commands

### /pr-review-fix-loop

Iterative cycle: run PR review, fix critical issues, repeat until clean report.

Uses a built-in iteration engine (Stop hook + state file), pr-review-toolkit for code review, and optionally OpenAI Codex CLI for additional review.

**Features:**
- TDD approach for high-criticality issues (writes spec first, then fixes)
- code-explorer for context analysis before fixes
- code-reviewer for final validation
- Configurable criticality threshold and review aspects
- Auto-detect linter (RuboCop, ESLint, Ruff, gofmt, cargo clippy)
- Auto-commit on clean review
- Markdown report generation
- Smart stagnation detection (auto-exit if issues stop decreasing over 5 iterations)
- Recommendation agent on stagnation (analyzes root causes, suggests manual fixes)
- Exit tracking with machine-readable markers: `[OK] [EXIT:SUCCESS]`, `[!!] [EXIT:STAGNANT]`, `[!!] [EXIT:LIMIT]`, `[XX] [EXIT:ERROR]`

**Usage:**
```
/pr-review-fix-loop
/pr-review-fix-loop --max-iterations 5
/pr-review-fix-loop --aspects "code errors"
/pr-review-fix-loop --min-criticality 7
/pr-review-fix-loop --lint
/pr-review-fix-loop --codex
/pr-review-fix-loop --codex --base develop
```

**Arguments:**
| Argument | Default | Description |
|-|-|-|
| --max-iterations N | 20 | Max loop iterations |
| --aspects ASPECTS | code errors tests | Review aspects |
| --min-criticality N | 5 | Min criticality level (1-10) |
| --lint | off | Run auto-detected linter after fixes |
| --codex | off | Also run Codex CLI review |
| --base BRANCH | auto-detect | Base branch for Codex diff |

### /codex-pr-review

Standalone code review via OpenAI Codex CLI.

**Usage:**
```
/codex-pr-review
/codex-pr-review --base develop
/codex-pr-review --base HEAD~3
```

## Dependencies

**Required plugins:**
```
/plugin install pr-review-toolkit
/plugin install feature-dev
```

**Required tools:**
- **direnv** -- project environment wrapper
- **Ruby/Rails** stack -- `bundle exec rspec`, `bundle exec rubocop`
- **gh** CLI -- for auto-detecting base branch from PR

**Optional:**
- **codex** CLI -- OpenAI Codex, for `--codex` flag (`npm install -g @openai/codex`)

## Install

```
/plugin install pr-review-fix-loop@dapi
```

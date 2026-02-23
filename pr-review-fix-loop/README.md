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
- Optional RuboCop auto-fix
- Optional auto-commit
- Markdown report generation

**Usage:**
```
/pr-review-fix-loop
/pr-review-fix-loop --max-iterations 5
/pr-review-fix-loop --aspects "code errors"
/pr-review-fix-loop --min-criticality 7
/pr-review-fix-loop --rubocop --auto-commit
/pr-review-fix-loop --codex
/pr-review-fix-loop --codex --base develop
```

**Arguments:**
| Argument | Default | Description |
|-|-|-|
| --max-iterations N | 10 | Max loop iterations |
| --aspects ASPECTS | code errors tests | Review aspects |
| --min-criticality N | 5 | Min criticality level (1-10) |
| --auto-commit | off | Auto-commit after clean review |
| --rubocop | off | Run RuboCop -a after fixes |
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

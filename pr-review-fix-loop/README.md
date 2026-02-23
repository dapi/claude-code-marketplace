# pr-review-fix-loop

Iterative PR review + autofix loop for Ruby/Rails projects.

## Commands

### /pr-review-fix-loop

Iterative cycle: run PR review, fix critical issues, repeat until clean report.

Uses Ralph Loop as the iteration engine, pr-review-toolkit for code review, and optionally OpenAI Codex CLI for additional review.

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
|----------|---------|-------------|
| --max-iterations N | 10 | Max Ralph Loop iterations |
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

- **ralph-loop** plugin (iteration engine)
- **pr-review-toolkit** plugin (code review)
- **feature-dev** agents (code-explorer, code-reviewer)
- **codex** CLI (optional, for --codex flag)
- **direnv** (project environment)
- **Ruby/Rails** stack (rspec, rubocop)

## Install

```
/plugin install pr-review-fix-loop@dapi
```

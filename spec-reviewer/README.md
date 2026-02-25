# spec-reviewer

Specification review plugin for Claude Code.
It helps you find gaps, contradictions, ambiguity, testability problems, and scope risks before implementation.

## Why Use It

Use `spec-reviewer` when you want to:
- reduce rework before coding starts,
- detect blockers early (critical/high issues),
- split oversized specs into implementable phases,
- keep a transparent decision trail for each remark.

## Install

```bash
/plugin install spec-reviewer@dapi
```

## Quick Start

```bash
/spec-review docs/spec.md
/spec-review --quick #42
/spec-review --deep https://docs.google.com/document/d/<DOC_ID>/edit
/spec-review --standard https://docs.company.com/p/<PAGE_ID>
```

## Inputs Supported

- Google Docs URL
- GitHub Issue URL or `#number`
- Docmost page URL (read via Docmost MCP)
- local file path
- large spec text pasted into chat

## Review Levels

| Level | Flags | Focus | Iterations |
|---|---|---|---|
| Quick | `--quick`, `-q` | critical blockers only | 1 |
| Standard (default) | `--standard`, `-s` | critical + high | 2 |
| Deep | `--deep`, `-d` | critical + high + medium | 3 |
| Exhaustive | `--exhaustive`, `-e` | full audit incl. low | 3 |

Extra flag:
- `--no-ask` — skip depth selection question and run `standard`.

### What Actually Changes Between Levels

`spec-reviewer` changes four things by level:
1. issue visibility threshold (`critical/high/medium/low`),
2. max iteration count,
3. whether classifier/gate-check/scope analysis are used,
4. which subskills are run.

| Level | Classifier | Agent Strategy | Visible Severity | Gate Check | Max Iterations |
|---|---|---|---|---|---|
| Quick | skipped | only `spec-analyst` + `spec-test` | `critical` | no | 1 |
| Standard | yes | base + `spec-axes` + classifier-selected domain agents (+`spec-scoper` if needed) | `critical`, `high` | yes | 2 |
| Deep | yes | same as Standard, but deeper reporting window | `critical`, `high`, `medium` | yes | 3 |
| Exhaustive | yes (scope-only) | base + `spec-axes` + all domain agents (+`spec-scoper` if needed) | all, incl. `low` | yes | 3 |

### Subskill Combination Logic

Base set (always in non-classifier phase):
- `spec-analyst`
- `spec-test`

Added in `standard/deep/exhaustive`:
- `spec-axes` (What/How/Verify coverage check)

Domain agents:
- `standard/deep`: selected by `spec-classifier` based on spec content
- `exhaustive`: all domain agents forced on (`spec-data`, `spec-api`, `spec-infra`, `spec-risk`, `spec-ux`, `spec-ai-readiness`)

Scope agent:
- `spec-scoper` runs when quick scope is `borderline` or `too_large`.

### Practical Difference (Examples)

1. Quick on UI-heavy spec:
- runs only `spec-analyst` + `spec-test` for blockers.
- fastest, but skips dedicated UX/infra/API deep checks.

2. Standard on typical product spec:
- usually runs `analyst + test + axes`, then only relevant domain agents.
- best default tradeoff for sprint planning.

3. Exhaustive before high-risk release:
- forces full domain coverage regardless of classifier routing.
- best before architecture freeze or major integration launch.

## Components

### Command: `/spec-review`

Main orchestration command. It runs a multi-phase review flow:
1. detect depth,
2. read the spec source,
3. classify required agents,
4. run parallel analysis,
5. aggregate issues,
6. process decisions,
7. perform gate check and finalize.

### Skill: `spec-review`

Auto-router skill that triggers on requests like:
- "review spec",
- "проверь спецификацию",
- "найди нестыковки в требованиях",
- and similar requirement-review intents.

## Subskills (Agents)

`spec-reviewer` includes 11 specialized agents:

| Agent | Role | Trigger |
|---|---|---|
| `spec-classifier` | Detects which agents to run + quick scope estimate | standard/deep/exhaustive |
| `spec-analyst` | Business requirements quality | always |
| `spec-test` | Testability and edge cases | always |
| `spec-axes` | Coverage by What/How/Verify axes | standard/deep/exhaustive |
| `spec-data` | Data model/schema/migration review | conditional |
| `spec-api` | API/contracts/integrations review | conditional |
| `spec-infra` | Security/NFR/deployment review | conditional |
| `spec-risk` | Technical/business/schedule risk review | conditional |
| `spec-ux` | UX states, flows, accessibility | conditional |
| `spec-ai-readiness` | AI-agent execution readiness | conditional |
| `spec-scoper` | Detailed decomposition of oversized scope | when scope is borderline/too_large |

Note:
- In parallel phase, the command runs from 2 to 10 agents.
- `spec-classifier` is run earlier as a separate phase.

## Run Subskills Separately (Advanced)

Primary usage is `/spec-review`.

If you need a focused analysis, you can call specific subagents directly through Task (advanced workflow):

```text
Task:
  subagent_type: "spec-reviewer:spec-api"
  description: "API-only review"
  prompt: |
    Analyze this spec for API contracts, endpoints, and integration risks.
    Return JSON only.
```

Common standalone targets:
- `spec-reviewer:spec-data`
- `spec-reviewer:spec-api`
- `spec-reviewer:spec-infra`
- `spec-reviewer:spec-risk`
- `spec-reviewer:spec-ux`
- `spec-reviewer:spec-ai-readiness`
- `spec-reviewer:spec-scoper`

## Issue Handling Logic

Each issue gets a decision path:

1. `fixed`
- accepted and applied to the source spec.

2. `deferred`
- moved to a separate GitHub issue/sub-issue for later execution.

3. `reclassified`
- severity is lowered (with rationale), e.g. from `high` to `medium`.
  The issue severity value must be updated to the new level.

4. `rejected`
- explicitly declined (with rationale), documented in review artifacts.

5. `custom`
- user-defined handling strategy, then mapped to one of:
  `fixed | deferred | reclassified | rejected`.

### Reclassified vs Rejected

- `reclassified` means the issue is still valid, but no longer treated as a blocker at the current gate level. It can appear in deeper reports and remains visible in history.
- `rejected` means the team decides not to act on this issue. It should not block gate checks anymore, but the rejection reason must stay documented.
- Gate-check blockers are unresolved `critical/high` issues only. `fixed`, `deferred`, and `rejected` do not block.

Rule for NFR:
- if an NFR is release-critical (security/compliance/SLO contract), do **not** use `reclassified`; use `fixed` (or explicitly `deferred` with release blocked).
- use `reclassified` only when impact is accepted for the current milestone and rationale is documented.

### Where Decisions Are Recorded

- in the review output/report,
- in spec comments/notes,
- in GitHub issues (for deferred items),
- in issue history across review iterations.

## Scope Splitting Logic

If quick scope says `borderline` or `too_large`, `spec-scoper` proposes:
- phased breakdown (`PART-001`, `PART-002`, ...),
- dependency graph,
- what stays in current scope vs what becomes new sub-issues.

This allows safe delivery instead of forcing a single oversized implementation batch.

## Example Scenarios

1. Sprint planning gate
- Run `--standard` on new PRD/ТЗ before engineering pickup.
- Fix critical/high, defer non-blockers.

2. High-risk integration launch
- Run `--exhaustive` on payment/auth/third-party integration spec.
- Focus on API, infra, risk, and testability outputs.

3. Oversized feature decomposition
- Run review on a large epic.
- Accept `spec-scoper` breakdown and create phased sub-issues.

4. AI automation project
- Run with AI-readiness enabled.
- Ensure boundaries, escalation points, and success criteria are explicit.

## Best Practices

- Keep acceptance criteria measurable.
- Resolve critical/high before implementation approval.
- Use `deferred` only with created tracking issues.
- Require rationale for `reclassified` and `rejected` decisions.
- Prefer phased delivery for `borderline`/`too_large` scope.

## Documentation

- [Command workflow](./commands/spec-review.md)
- [Skill definition](./skills/spec-review/SKILL.md)
- [Alternatives & related skills](./ALTERNATIVES.md)

## License

MIT

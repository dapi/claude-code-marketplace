# spec-reviewer

Specification review plugin for Claude Code — analyze specs for gaps, inconsistencies, and scope estimation with 10 specialized agents.

## Installation

```bash
/plugin install spec-reviewer@dapi
```

## Components

### Command: /spec-review

Launch a comprehensive specification review.

```
/spec-review path/to/spec.md
```

### Skill: spec-review

Activates automatically when you ask to review specifications or requirements.

### Agents

| Agent | Purpose |
|-------|---------|
| `spec-classifier` | Classification and routing |
| `spec-analyst` | Business analysis |
| `spec-api` | API and integrations |
| `spec-ux` | UX/UI analysis |
| `spec-data` | Data models and schemas |
| `spec-infra` | Infrastructure and security |
| `spec-test` | Testability |
| `spec-scoper` | Scope estimation |
| `spec-risk` | Risk analysis |
| `spec-ai-readiness` | AI agent readiness |

## Usage

```
/spec-review path/to/spec.md
"review spec docs/spec.md"
"проверь спецификацию docs/spec.md"
"найди нестыковки в требованиях"
"оцени объём спецификации"
```

## Documentation

See [skills/spec-review/SKILL.md](./skills/spec-review/SKILL.md)

## License

MIT

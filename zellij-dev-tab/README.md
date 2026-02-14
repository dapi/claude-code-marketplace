# zellij-dev-tab

Launch GitHub issue development in a separate Zellij tab.

## Installation

```bash
/plugin install zellij-dev-tab@dapi
```

## Components

### Skill: zellij-dev-tab

Creates a new Zellij tab named `#ISSUE_NUMBER` and runs `start-issue` inside it.

## Usage

```
"start issue #45 in new tab"
"launch issue 123 in separate tab"
"запусти разработку issue #45 в новой вкладке"
"открой issue в новой вкладке"
```

Supported formats: `45`, `#45`, `https://github.com/owner/repo/issues/45`

## Requirements

- [Zellij](https://zellij.dev) terminal multiplexer
- `start-issue` script in PATH (see `scripts/start-issue`)

## Documentation

See [skills/zellij-dev-tab/SKILL.md](./skills/zellij-dev-tab/SKILL.md)

## License

MIT

# Testing Tools

Testing tools plugin for Claude Code with agents and skills for TDD, test strategies, and coverage analysis.

## Features

### Agents
- **TDD Coach** - Test-driven development guidance
- **Test Strategist** - Test strategy design and implementation
- **Coverage Analyzer** - Test coverage analysis and optimization

### Skills
- **Test-Driven Development** - RED-GREEN-REFACTOR TDD workflow
- **Test Strategy Planning** - Comprehensive test planning methodology
- **Coverage Optimization** - Systematic coverage improvement

### Commands
- `/tdd` - Start TDD workflow for feature implementation
- `/test-strategy` - Design test strategy for component
- `/coverage` - Analyze and improve test coverage

## Installation

### From GitHub (after publishing)
```bash
/plugin marketplace add dapi/claude-code-marketplace
/plugin install testing-tools@dapi
```

### Local Development
```bash
/plugin marketplace add /home/danil/code/claude-code-marketplace
/plugin install testing-tools@dapi
```

## Usage

Once installed, agents are available through `/agents` command and skills activate automatically when relevant tasks are detected.

### Example: TDD Workflow
```
"Implement user authentication using TDD"
→ test-driven-development skill activates
→ tdd-coach agent guides RED-GREEN-REFACTOR cycle
```

### Example: Test Strategy
```
"Design test strategy for payment processing module"
→ test-strategy-planning skill activates
→ test-strategist agent creates comprehensive plan
```

### Example: Coverage Analysis
```
"Improve test coverage for API endpoints"
→ coverage-optimization skill activates
→ coverage-analyzer agent identifies gaps and suggests tests
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on adding new agents and skills.

## License

MIT License - see [LICENSE](../LICENSE)

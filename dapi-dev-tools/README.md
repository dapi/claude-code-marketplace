# Dapi Dev Tools

Development tools plugin for Claude Code with agents and skills for coding, refactoring, and architecture.

## Features

### Agents
- **Code Architect** - System design and architectural analysis
- **Code Refactorer** - Code refactoring and optimization
- **Pattern Detector** - Design pattern recognition and application

### Skills
- **Systematic Refactoring** - Step-by-step refactoring methodology
- **Architecture Analysis** - System architecture evaluation
- **Code Quality Assessment** - Comprehensive code review framework

### Commands
- `/refactor` - Intelligent code refactoring
- `/architect` - System architecture analysis
- `/patterns` - Design pattern identification

## Installation

### From GitHub (after publishing)
```bash
/plugin marketplace add dapi/claude-code-marketplace
/plugin install dapi-dev-tools@dapi
```

### Local Development
```bash
/plugin marketplace add /home/danil/code/claude-code-marketplace
/plugin install dapi-dev-tools@dapi
```

## Usage

Once installed, agents are available through `/agents` command and skills activate automatically when relevant tasks are detected.

### Example: Code Refactoring
```
"Refactor this authentication module to use dependency injection"
→ systematic-refactoring skill activates
→ code-refactorer agent assists with implementation
```

### Example: Architecture Review
```
"Review the microservices architecture for this system"
→ architecture-analysis skill activates
→ code-architect agent provides comprehensive analysis
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on adding new agents and skills.

## License

MIT License - see [LICENSE](../LICENSE)

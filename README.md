# Dapi Claude Code Marketplace

Personal marketplace of Claude Code plugins with specialized agents and skills for development workflows.

## Available Plugins

### 🛠️ dev-tools
Development tools for coding, refactoring, and architecture.

**Features:**
- Code architecture analysis
- Intelligent refactoring workflows
- Design pattern recognition and application
- Systematic code quality improvement

[View Documentation](./dev-tools/README.md)

### 🧪 testing-tools
Testing tools for TDD, test strategies, and coverage analysis.

**Features:**
- Test-driven development (TDD) workflows
- Comprehensive test strategy planning
- Test coverage analysis and optimization
- Quality assurance automation

[View Documentation](./testing-tools/README.md)

## Installation

### Quick Start

1. **Add the marketplace:**
   ```bash
   /plugin marketplace add dapi/claude-code-marketplace
   ```

2. **Install desired plugins:**
   ```bash
   # Install development tools
   /plugin install dev-tools@dapi

   # Install testing tools
   /plugin install testing-tools@dapi

   # Install all plugins
   /plugin install dev-tools@dapi dapi-testing-tools@dapi
   ```

### Local Development

For local development and testing:

```bash
# Add local marketplace
/plugin marketplace add /home/danil/code/claude-code-marketplace

# Install plugins locally
/plugin install dev-tools@dapi
/plugin install testing-tools@dapi
```

## Usage

Once installed, plugins provide:

### Agents
Access specialized agents through `/agents` command:
- Architecture and design agents
- Testing and quality agents
- Refactoring and optimization agents

### Skills
Skills activate automatically based on task context:
- **Systematic workflows** for complex operations
- **Best practice patterns** from industry standards
- **Quality gates** ensuring thorough implementation

### Commands
Custom slash commands for common workflows:
- `/refactor` - Intelligent code refactoring
- `/architect` - System architecture analysis
- `/tdd` - Test-driven development workflow
- `/test-strategy` - Test planning and design

## Repository Structure

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace configuration
├── dev-tools/                     # Development tools plugin
│   ├── .claude-plugin/
│   ├── agents/                    # Specialized agents
│   ├── skills/                    # Reusable skills
│   ├── commands/                  # Slash commands
│   └── README.md
├── testing-tools/                 # Testing tools plugin
│   ├── .claude-plugin/
│   ├── agents/
│   ├── skills/
│   ├── commands/
│   └── README.md
├── README.md                      # This file
├── CONTRIBUTING.md                # Contribution guidelines
└── LICENSE                        # MIT License
```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on:
- Adding new agents and skills
- Creating new plugins
- Testing and quality standards
- Pull request process

## Philosophy

This marketplace follows these principles:

**🎯 Practical over Theoretical**
- Agents and skills solve real development problems
- Focus on actionable guidance over abstract concepts

**🔧 Systematic over Ad-hoc**
- Structured workflows for complex operations
- Repeatable patterns for consistency

**📊 Evidence over Assumptions**
- Data-driven recommendations
- Measurable quality improvements

**🚀 Efficiency over Verbosity**
- Concise, actionable output
- Token-optimized communication

## Roadmap

### Planned Plugins
- **code-quality** - Code review, security, and performance analysis
- **workflows** - CI/CD, deployment, and automation workflows
- **documentation** - Technical writing and documentation generation

### Upcoming Features
- Integration with MCP servers
- Cross-plugin agent collaboration
- Enhanced skill discovery and activation

## License

MIT License - see [LICENSE](./LICENSE)

## Author

**Danil Pismenny**
- Email: danilpismenny@gmail.com
- GitHub: [@dapi](https://github.com/dapi)

## Support

- 🐛 [Report Issues](https://github.com/dapi/claude-code-marketplace/issues)
- 💡 [Request Features](https://github.com/dapi/claude-code-marketplace/issues/new)
- 📖 [Documentation](https://github.com/dapi/claude-code-marketplace/wiki)

---

**Built for [Claude Code](https://www.anthropic.com/claude/code)**

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **Claude Code plugin marketplace** for personal development workflows. The repository contains multiple plugins, each providing specialized agents, skills, and commands for different development domains.

## Architecture

### Marketplace Structure

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace metadata and plugin registry
├── dev-tools/                     # Plugin: Development tools
│   ├── .claude-plugin/
│   │   └── plugin.json           # Plugin metadata
│   ├── agents/                    # Specialized AI agents (currently empty)
│   ├── skills/                    # Auto-activating skills (currently empty)
│   └── commands/                  # Slash commands (currently empty)
├── testing-tools/                 # Plugin: Testing tools
│   └── [same structure as dev-tools]
└── [standard repo files]
```

### Plugin System

**Plugins** are self-contained directories with:
- **Agents**: Markdown files defining specialized AI assistants for specific tasks
- **Skills**: Model-initiated capabilities that activate automatically based on context
- **Commands**: Slash commands for common workflows
- **plugin.json**: Metadata including name, version, author, keywords

**Marketplace**: The `.claude-plugin/marketplace.json` file registers all plugins and their locations.

## Development Workflows

### Adding a New Plugin

1. Create plugin directory structure:
   ```bash
   mkdir -p new-plugin-name/{.claude-plugin,agents,skills,commands}
   ```

2. Create `new-plugin-name/.claude-plugin/plugin.json`:
   - Required fields: name, description, version, author, license
   - Optional: homepage, repository, keywords
   - Follow existing plugin.json format exactly

3. Register in `.claude-plugin/marketplace.json`:
   - Add entry to `plugins` array
   - Include name, source path, description

4. Create plugin README.md following existing format

### Creating Agents

Agents are markdown files in `plugin-name/agents/` with YAML frontmatter:

```markdown
---
name: agent-name
description: |
  When to use this agent and what it does.
  Maximum 1024 characters.
---

[Agent definition and behavior]
```

**Critical**: The `description` field determines when the agent is discovered and invoked.

### Creating Skills

Skills are directories in `plugin-name/skills/` with a `SKILL.md` file:

```markdown
---
name: skill-name
description: |
  CRITICAL: When should Claude use this skill?
  Include triggering scenarios and keywords.
allowed-tools: Read, Grep, Glob, Bash  # Optional tool restrictions
---

[Skill definition and methodology]
```

**Critical**: The `description` must clearly state triggering scenarios for automatic activation.

### Creating Slash Commands

Commands are markdown files in `plugin-name/commands/` that expand to full prompts when invoked.

## Testing Locally

### Install Marketplace Locally

```bash
# Add local marketplace
/plugin marketplace add /home/danil/code/claude-code-marketplace

# Install specific plugin
/plugin install dev-tools@dapi
/plugin install testing-tools@dapi

# Verify installation
/plugin list
```

### Testing Agents
- Invoke manually through `/agents` command
- Verify behavior matches description
- Test with realistic scenarios

### Testing Skills
- Create scenarios that should trigger automatic activation
- Verify skill activates based on description keywords
- Test with different contexts

## Quality Standards

### Naming Conventions
- **Plugins**: `plugin-name` (lowercase with hyphens)
- **Agents**: `agent-name` (lowercase with hyphens, max 64 chars)
- **Skills**: `skill-name` (lowercase with hyphens)
- **Commands**: `command-name` (lowercase with hyphens)

### Documentation Requirements
- All plugins must have README.md
- Agent descriptions must be clear and trigger-focused
- Skill descriptions must explicitly state activation criteria
- Include concrete examples, not vague generalizations

### JSON Validity
- All `plugin.json` files must be valid JSON
- YAML frontmatter must be properly formatted
- Test locally before committing

## Philosophy and Principles

**From README.md:**
- **Practical over Theoretical**: Solve real development problems
- **Systematic over Ad-hoc**: Structured, repeatable workflows
- **Evidence over Assumptions**: Data-driven recommendations
- **Efficiency over Verbosity**: Concise, token-optimized output

## Git Workflow

```bash
# Create feature branch
git checkout -b feature/new-agent-name

# Commit with descriptive message
git commit -m "Add agent-name: brief description"
# OR
git commit -m "Add skill-name: brief description"
# OR
git commit -m "Add plugin-name: brief description"
```

**Commit message formats**:
- `Add [item]: description`
- `Fix [item]: issue description`
- `Update docs: changes description`

## Current State

**Plugins**: 2 plugins defined (dev-tools, testing-tools)
**Status**: Infrastructure complete, agents/skills/commands directories empty
**Next**: Populate agents, skills, and commands based on planned features in README.md

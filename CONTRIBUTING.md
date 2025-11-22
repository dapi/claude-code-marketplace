# Contributing to Dapi Marketplace

Thank you for your interest in contributing! This guide will help you add new agents, skills, and plugins to the marketplace.

## Table of Contents

- [Creating New Agents](#creating-new-agents)
- [Creating New Skills](#creating-new-skills)
- [Creating New Plugins](#creating-new-plugins)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)

## Creating New Agents

Agents are specialized AI assistants for specific development tasks.

### Agent File Structure

Create a new markdown file in the plugin's `agents/` directory:

```
plugin-name/agents/agent-name.md
```

### Agent Template

```markdown
---
name: agent-name
description: |
  Clear description of when to use this agent and what it does.
  Include specific use cases and triggering scenarios.
  Maximum 1024 characters.
---

You are a specialized agent for [specific domain].

Your expertise includes:
- [Specific capability 1]
- [Specific capability 2]
- [Specific capability 3]

When invoked, you should:
1. [Step-by-step process]
2. [Clear methodology]
3. [Expected output format]

Key principles:
- [Important guideline 1]
- [Important guideline 2]
- [Important guideline 3]
```

### Agent Best Practices

**Naming Conventions:**
- Use lowercase with hyphens: `code-architect`, `test-strategist`
- Be descriptive and specific
- Maximum 64 characters

**Description Guidelines:**
- Start with "Use when..." to clearly define triggers
- Include specific keywords for discovery
- Mention the agent's unique value proposition
- Keep under 1024 characters

**Content Quality:**
- Define clear scope and boundaries
- Provide systematic methodology
- Include concrete examples
- Avoid vague generalizations

## Creating New Skills

Skills are model-initiated capabilities that Claude uses automatically.

### Skill Directory Structure

Create a new directory in the plugin's `skills/` folder:

```
plugin-name/skills/skill-name/
├── SKILL.md              # Required: Main skill definition
├── reference.md          # Optional: Detailed documentation
├── examples.md           # Optional: Usage examples
└── templates/            # Optional: Code templates
```

### Skill Template (SKILL.md)

```markdown
---
name: skill-name
description: |
  Critical: When should Claude use this skill?
  Include triggering scenarios and keywords.
  This determines automatic activation.
allowed-tools: Read, Grep, Glob, Bash  # Optional: Restrict tools
---

# Skill Name

## When to Use

This skill activates when:
- [Specific scenario 1]
- [Specific scenario 2]
- [Triggering keywords or patterns]

## Methodology

### Phase 1: [First Phase Name]

[Step-by-step instructions]
- Concrete actions
- Expected outcomes
- Quality gates

### Phase 2: [Second Phase Name]

[Detailed process]

### Phase 3: [Final Phase Name]

[Completion criteria]

## Quality Standards

- [Standard 1]
- [Standard 2]
- [Standard 3]

## Anti-Patterns to Avoid

- ❌ [Common mistake 1]
- ❌ [Common mistake 2]
- ✅ [Correct approach instead]
```

### Skill Best Practices

**Activation Criteria:**
- **Critical**: Description must clearly state when to use
- Include specific triggering keywords
- Define clear boundaries (when NOT to use)

**Tool Restrictions:**
- Use `allowed-tools` to limit available tools
- Ensures security and focused execution
- Example: Testing skills shouldn't modify production code

**Systematic Workflows:**
- Break complex tasks into phases
- Provide clear decision criteria
- Include validation checkpoints

## Creating New Plugins

### 1. Create Plugin Directory Structure

```bash
mkdir -p new-plugin-name/{.claude-plugin,agents,skills,commands}
```

### 2. Create plugin.json

```json
{
  "name": "plugin-name",
  "description": "Clear description of plugin purpose",
  "version": "1.0.0",
  "author": {
    "name": "Your Name",
    "email": "your.email@example.com"
  },
  "homepage": "https://github.com/dapi/claude-code-marketplace",
  "repository": {
    "type": "git",
    "url": "https://github.com/dapi/claude-code-marketplace.git",
    "directory": "new-plugin-name"
  },
  "license": "MIT",
  "keywords": ["keyword1", "keyword2", "keyword3"]
}
```

### 3. Create README.md

Follow the structure in existing plugins:
- Overview and features
- Installation instructions
- Usage examples
- Contributing guidelines

### 4. Update Marketplace Configuration

Add your plugin to `.claude-plugin/marketplace.json`:

```json
{
  "name": "new-plugin-name",
  "source": "./new-plugin-name",
  "description": "Brief plugin description"
}
```

## Testing Guidelines

### Local Testing

1. **Add marketplace locally:**
   ```bash
   /plugin marketplace add /home/danil/code/claude-code-marketplace
   ```

2. **Install your plugin:**
   ```bash
   /plugin install your-plugin-name@dapi
   ```

3. **Test agents:**
   - Invoke agents manually through `/agents`
   - Verify agent behavior matches description

4. **Test skills:**
   - Create scenarios that should trigger skills
   - Verify automatic activation
   - Test with different contexts

### Quality Checklist

Before submitting:

- [ ] Agent/skill names follow naming conventions
- [ ] Descriptions are clear and trigger-focused
- [ ] YAML frontmatter is valid JSON
- [ ] No syntax errors in markdown
- [ ] Examples are concrete and realistic
- [ ] Documentation is complete
- [ ] Local testing completed successfully

## Pull Request Process

### 1. Fork and Branch

```bash
git checkout -b feature/new-agent-name
```

### 2. Make Changes

- Add agents/skills following templates above
- Update relevant README.md files
- Test thoroughly locally

### 3. Commit

```bash
git add .
git commit -m "Add [agent/skill name]: [brief description]"
```

**Commit Message Format:**
- `Add agent-name: brief description`
- `Add skill-name: brief description`
- `Add plugin-name: brief description`
- `Fix agent-name: issue description`
- `Update docs: changes description`

### 4. Push and Create PR

```bash
git push origin feature/new-agent-name
```

Create pull request on GitHub with:
- Clear title describing the addition
- Description of what the agent/skill does
- Testing steps you performed
- Any special considerations

### 5. PR Review

- Maintainers will review for quality and consistency
- Address feedback and update as needed
- Once approved, changes will be merged

## Code of Conduct

- Be respectful and professional
- Focus on constructive feedback
- Collaborate openly
- Credit others' contributions

## Questions?

- Open an issue for questions
- Tag maintainers for guidance
- Check existing agents/skills as examples

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Dapi Marketplace!

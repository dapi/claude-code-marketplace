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
├── bugsnag-skill/                 # Bugsnag API integration
├── cluster-efficiency/            # Kubernetes cluster analysis (5 agents)
├── doc-validate/                  # Documentation validation
├── github-workflow/               # GitHub issues, PRs, worktrees
├── himalaya/                      # Email via Himalaya CLI
├── long-running-harness/          # Multi-session project management
├── media-upload/                  # S3 media upload
├── requirements/                  # Requirements in Google Sheets
├── spec-reviewer/                 # Specification review (11 agents)
├── zellij-workflow/                # Zellij workflow: status, dev tabs, claude tabs
└── [standard repo files]

# Each plugin has structure:
plugin-name/
├── .claude-plugin/
│   └── plugin.json               # Plugin metadata
├── agents/                        # Specialized AI agents (optional)
├── skills/                        # Auto-activating skills (optional)
├── commands/                      # Slash commands (optional)
├── hooks/                         # Event hooks (optional)
└── README.md                      # Plugin documentation
```

### Plugin System

**Plugins** are self-contained directories with:
- **Agents**: Markdown files defining specialized AI assistants for specific tasks
- **Skills**: Model-initiated capabilities that activate automatically based on context
- **Commands**: Slash commands for common workflows
- **plugin.json**: Metadata including name, version, author, keywords

**Marketplace**: The `.claude-plugin/marketplace.json` file registers all plugins and their locations.

## Marketplace Plugin Requirements

### 🚨 Critical: Plugins Are Installed Separately

**Key Concept**: Plugins are NOT used directly from this repository. They are:
1. **Source**: This repo is the marketplace source
2. **Installation**: Users run `/plugin install plugin-name@dapi`
3. **Isolation**: Installed plugin is copied to Claude Code's plugin directory
4. **Independence**: Plugin must work without access to this repository

### Path Conventions

**ABSOLUTE REQUIREMENT**: All paths must be relative to plugin root.

✅ **Correct Paths**:
```markdown
./agents/bugsnag.md
skills/debugging/SKILL.md
../commands/bugsnag:list.md
commands/command-name.md
```

❌ **FORBIDDEN Paths**:
```markdown
/home/danil/code/claude-code-marketplace/plugin-name/agents/...
/absolute/path/to/anything
../../.claude-plugin/marketplace.json  # Outside plugin!
```

**Why**: After installation, the plugin exists in an isolated directory. Absolute paths will break. References to parent marketplace structure will fail.

### Self-Sufficiency Checklist

Every plugin MUST be completely self-contained:

- [ ] All files needed are inside `plugin-name/` directory
- [ ] No references to `../.claude-plugin/marketplace.json`
- [ ] No references to other plugins in marketplace
- [ ] `README.md` is in plugin root: `plugin-name/README.md`
- [ ] All internal links use relative paths
- [ ] `plugin.json` only references files within plugin directory

**Test Question**: "Will this work if the plugin is installed alone, without the marketplace repo?"

### Installation Flow

```
Development Repository:
claude-code-marketplace/
└── github-workflow/
    ├── .claude-plugin/plugin.json
    ├── skills/
    ├── commands/
    └── templates/

                ↓  /plugin install github-workflow@dapi

Installed Plugin (isolated location):
~/.config/claude-code/plugins/github-workflow@dapi/
├── .claude-plugin/plugin.json
├── skills/
├── commands/
└── templates/
```

After installation, the plugin has NO access to:
- Original marketplace repository
- Other plugins
- Marketplace metadata
- Parent directory structure

### Path Reference Examples

**In Agent Files** (`agents/bugsnag.md`):
```markdown
See also:
- [Commands](../commands/bugsnag:list.md)
- [Skills](../skills/debugging/SKILL.md)
```

**In Skill Files** (`skills/debugging/SKILL.md`):
```markdown
Related:
- Agent: [Bugsnag Agent](../../agents/bugsnag.md)
- Commands: [List Errors](../../commands/bugsnag:list.md)
```

**In README.md** (`plugin-name/README.md`):
```markdown
## Agents
- [Bugsnag](./agents/bugsnag.md)

## Skills
- [Debugging](./skills/debugging/SKILL.md)
```

### Critical Validation Rules

Before committing ANY agent/skill/command:

1. **Path Check**: No absolute paths anywhere
2. **Reference Check**: All links use relative paths
3. **Isolation Test**: Would this work if plugin folder was moved?
4. **Self-Sufficiency**: All required files are in plugin directory
5. **No Parent References**: No `../../.claude-plugin/` or similar

**Automated Check**:
```bash
# From plugin directory
grep -r "^/" agents/ skills/ commands/ README.md
# Should return NOTHING (no absolute paths)

grep -r "\.\./\.\./\.claude-plugin" .
# Should return NOTHING (no marketplace references)
```

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

## Quality Tools for Skill Development

### Skill Trigger Quality Review System

**Purpose**: Ensure skills activate correctly with high-quality trigger configurations.

#### Automated Review Tool

**Location**: `scripts/review_skill_triggers.sh`

**Usage**:
```bash
# Review single skill
./scripts/review_skill_triggers.sh bugsnag-skill/bugsnag

# Review all skills in marketplace
./scripts/review_skill_triggers.sh --all
```

**What it checks** (100-point system):
1. **File Structure** (10 pts) - YAML frontmatter, required fields
2. **Universal Trigger** (15 pts) - Defined universal pattern
3. **Keyword Count** (15 pts) - Optimal 15-50 keywords
4. **Categorization** (10 pts) - Visual categories with emoji
5. **Multilingual Support** (10 pts) - EN + RU triggers
6. **Action Verb Diversity** (10 pts) - 5+ verbs (get, show, list...)
7. **Context Patterns** (10 pts) - "what in", "check", "from" patterns
8. **Test Documentation** (10 pts) - TRIGGER_EXAMPLES.md exists
9. **Description Length** (5 pts) - Optimal 300-1200 chars
10. **Negative Examples** (10 pts) - Documented what NOT to activate

**Rating Bands**:
- 90-100: ⭐⭐⭐⭐⭐ Excellent (production ready)
- 75-89: ⭐⭐⭐⭐ Good (minor improvements)
- 60-74: ⭐⭐⭐ Acceptable (needs refinement)
- <60: ⭐⭐ Poor (major rework required)

**Example Output**:
```
╔════════════════════════════════════════════╗
║  Skill Trigger Quality Review Tool        ║
╔════════════════════════════════════════════╗

Reviewing skill: bugsnag-skill/bugsnag
File: bugsnag-skill/skills/bugsnag/SKILL.md

[1/10] File Structure          ✅ 10/10
[2/10] Universal Trigger        ✅ 15/15
[3/10] Keyword Count           ✅ 15/15
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FINAL SCORE: 93/100
RATING: Excellent ⭐⭐⭐⭐⭐
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 RECOMMENDATIONS:
  ✅ No major improvements needed!
```

#### Documentation Resources

**For comprehensive manual review**:
- `SKILL_TRIGGER_REVIEW_CHECKLIST.md` - 50+ page complete guide
  - 10-phase review process
  - Scoring methodology
  - Best practices
  - Templates and examples

**For quick reference**:
- `SKILL_TRIGGER_QUICK_REFERENCE.md` - One-page cheat sheet
  - 10-point checklist
  - Copy-paste templates
  - Action verb cheatsheet
  - Common mistakes

**For examples**:
- `bugsnag-skill/skills/bugsnag/TRIGGER_EXAMPLES.md` - Reference implementation
  - 76 test examples (60+ positive, 5+ negative)
  - Bilingual (EN + RU)
  - Comprehensive coverage
  - 93/100 quality score

#### Universal Trigger Pattern (mandatory for all skills)

**Formula**:
```
[ACTION_VERB] + [DATA_TYPE] + from/in [TOOL_NAME]
```

**Example from bugsnag skill**:
```yaml
description: |
  **UNIVERSAL TRIGGER**: GET/FETCH/RETRIEVE any data FROM Bugsnag

  Common patterns:
  - "get/show/list [data] from bugsnag"
  - "получить/показать [данные] из bugsnag"

  Specific data types supported:

  📊 **Organizations & Projects**:
  - "list bugsnag organizations/projects"
  - "список проектов bugsnag"

  🐛 **Errors**:
  - "show/list bugsnag errors"
  - "открытые ошибки bugsnag"

  TRIGGERS: bugsnag, получить из bugsnag, показать bugsnag,
    bugsnag data, check bugsnag, what in bugsnag, ...
```

**Action Verbs to Include** (minimum 5):
- **Viewing**: get, show, list, display, view, retrieve, fetch
- **Checking**: check, verify, validate
- **Analyzing**: analyze, examine, inspect
- **Russian**: показать, получить, вывести, список, проверить

**Context Patterns** (highly recommended):
- "what [data] in [tool]"
- "check [tool]"
- "get [data] from [tool]"
- "что в [tool]"

#### CI/CD Integration ✅ ENABLED

**GitHub Actions workflows** automatically check skill quality:

**1. Skill Quality Check** (`.github/workflows/skill-quality-check.yml`)
- **Triggers**: PRs and pushes touching `SKILL.md` or `TRIGGER_EXAMPLES.md`
- **Actions**: Reviews changed skills, posts results as PR comment
- **Quality Gate**: ❌ Blocks merge if any skill <60/100
- **Output**: Detailed review in PR comment + downloadable artifact

**2. Full Skill Review** (`.github/workflows/full-skill-review.yml`)
- **Triggers**: Changes to review script/docs, or manual workflow dispatch
- **Actions**: Reviews ALL skills in marketplace
- **Quality Gate**: Reports if any skill <60/100
- **Output**: Comprehensive statistics + full report artifact (90-day retention)

**See**: [.github/workflows/README.md](./.github/workflows/README.md) for complete CI/CD documentation.

#### Quality Gate for Pull Requests

**Automated**: ✅ CI checks run automatically on all PRs
**Minimum requirement**: 60/100 score (blocks merge)
**Recommended**: 75/100 score for production-ready skills

**Pre-commit workflow** (optional local validation):
```bash
# Before committing skill changes
./scripts/review_skill_triggers.sh <plugin>/<skill>

# Aim for ≥75/100
# Fix issues based on recommendations
# Re-run until passing
```

#### TRIGGER_EXAMPLES.md Template

**Required file**: `plugin-name/skills/skill-name/TRIGGER_EXAMPLES.md`

**Minimum content**:
```markdown
# [Skill Name] Trigger Examples

## ✅ Should Activate (minimum 20 examples)

### Category 1
- "example query 1"
- "example query 2"

### Category 2
- "example query 3"

## ❌ Should NOT Activate (minimum 5 examples)

- "general question about tool"
- "installation query"
- "comparison query"

## 🎯 Key Trigger Words

**Verbs**: [list]
**Nouns**: [list]
**Context**: [patterns]
```

#### Development Workflow with Quality Tools

**Step-by-step process**:

1. **Create skill structure**
   ```bash
   mkdir -p plugin-name/skills/skill-name
   touch plugin-name/skills/skill-name/SKILL.md
   ```

2. **Use template from SKILL_TRIGGER_QUICK_REFERENCE.md**
   - Copy description template
   - Fill in universal trigger pattern
   - Add 3+ categories with examples
   - List 15+ trigger keywords

3. **Create TRIGGER_EXAMPLES.md**
   - Add 20+ positive examples
   - Add 5+ negative examples
   - Cover all functional categories

4. **Run automated review**
   ```bash
   ./scripts/review_skill_triggers.sh plugin-name/skill-name
   ```

5. **Iterate until ≥75/100**
   - Read recommendations
   - Apply fixes
   - Re-run review
   - Commit when passing

6. **Manual testing**
   - Pick 5 random examples from TRIGGER_EXAMPLES.md
   - Test in new Claude Code session
   - Verify skill activates correctly
   - Document any failures → fix triggers

**Time estimate**: 10-15 minutes per skill (with templates)

#### Integration with Git Workflow

**Pre-commit hook** (optional):
```bash
#!/bin/bash
# .git/hooks/pre-commit

for file in $(git diff --cached --name-only | grep "SKILL.md"); do
  skill_path=$(dirname "$file" | sed 's|/skills/|/|')
  ./scripts/review_skill_triggers.sh "$skill_path" || {
    echo "❌ Skill quality check failed. Fix issues and retry."
    exit 1
  }
done
```

**Commit message format**:
```bash
# Good examples:
git commit -m "Improve bugsnag skill triggers: add projects/orgs support (93/100)"
git commit -m "Add new skill: jira integration (85/100)"
git commit -m "Fix skill triggers: expand verb diversity (78/100 → 88/100)"

# Include score for transparency
```

## Testing Locally

### Install Marketplace Locally

```bash
# Add local marketplace
/plugin marketplace add /home/danil/code/claude-code-marketplace

# Install specific plugin
/plugin install github-workflow@dapi
/plugin install spec-reviewer@dapi

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

### Encoding Safety (NO EMOJI in plugin files)

**CRITICAL**: Plugin files (.md, .json) must NOT contain supplementary plane Unicode characters (U+10000+). This includes all emoji like `U+1F680` etc. These characters require UTF-16 surrogate pairs and cause `"no low surrogate in string"` API errors when Claude Code serializes large payloads.

**What to use instead:**
- Categories: `**Bold Headers**` instead of emoji prefixes
- Status markers: `[YES]`, `[NO]`, `[OK]`, `[FAIL]` instead of checkmarks/crosses
- Bullets: `- `, `* `, `>` instead of decorative emoji

**Validation:**
```bash
make lint-emoji           # Check all plugins
make lint-emoji-fix       # Auto-remove emoji
./scripts/lint_no_emoji.sh task-router  # Check single plugin
```

**CI enforced**: The `skill-quality-check` workflow blocks merge if emoji are found.

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

## Makefile Targets

Используй `make` для типовых операций с плагинами и релизами.

### Установка / переустановка плагинов

```bash
# Переустановить все плагины (default target, идемпотентный)
# Работает одинаково на чистом Claude и с уже установленным marketplace
make

# То же, но для ВСЕХ Claude-профилей
make reinstall-all

# Один конкретный плагин
make install-plugin PLUGIN=zellij-workflow
make uninstall-plugin PLUGIN=zellij-workflow
make reinstall-plugin PLUGIN=zellij-workflow
```

Список плагинов для установки задаётся переменной `PLUGINS` в Makefile.

**`make` (= `make reinstall`) делает:**
1. Uninstall всех `PLUGINS` (игнорирует ошибки если не установлены)
2. Remove marketplace dapi (игнорирует если не зарегистрирован)
3. Add marketplace dapi
4. Install всех `PLUGINS`

**Суффикс `-all`** означает "для всех Claude-аккаунтов", а не "все плагины".

### Линтинг

```bash
make lint-emoji       # Проверить на запрещённые emoji
make lint-emoji-fix   # Авто-удалить emoji
```

### Релизы

```bash
make version          # Показать текущую версию
make release-patch    # 1.5.2 -> 1.5.3
make release-minor    # 1.5.2 -> 1.6.0 (= make release)
make release-major    # 1.5.2 -> 2.0.0
make release VERSION=2.0.0  # Конкретная версия
```

**Что делает `make release-*`:**
1. Обновляет версию в `plugin.json`
2. Коммитит изменение
3. Создаёт git tag
4. Пушит в origin с тегами

**ВАЖНО:** После `make release-*` НЕ создаётся GitHub Release — только tag. Для полного релиза используй `gh release create`.

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

**Plugins**: 13 active plugins in marketplace

| Plugin | Components |
|--------|------------|
| bugsnag-skill | 1 skill |
| cluster-efficiency | 5 agents, 1 skill, 1 command |
| doc-validate | 1 skill, 1 command |
| github-workflow | 1 skill, 1 command |
| himalaya | 1 skill |
| long-running-harness | 1 skill |
| media-upload | 1 skill |
| pr-review-fix-loop | 2 commands |
| requirements | 1 command |
| skill-finder | 1 command |
| spec-reviewer | 11 agents, 1 skill, 1 command |
| task-router | 1 agent, 1 skill, 1 command |
| zellij-workflow | 1 skill, 2 commands, hooks |

**Totals**: 17 agents, 10 skills, 11 commands

## zellij-workflow Plugin

Special rules for this plugin:

1. **NO `async: true`** in hooks -- hooks must run synchronously so the tab has focus when getting its name
2. **All hook commands must end with `|| true`** -- graceful degradation if zellij-tab-status is not installed
3. **Requires zellij-tab-status plugin** (optional) -- install from https://github.com/dapi/zellij-tab-status

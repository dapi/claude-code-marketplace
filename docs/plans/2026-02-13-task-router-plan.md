# Task Router Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Plugin that classifies task URLs via haiku subagent and routes to feature-dev or subagent-driven-dev

**Architecture:** Command `/route-task` + auto-trigger skill + haiku classifier agent. Classifier fetches content, saves to file, returns compact JSON. Main context only sees routing decision.

**Tech Stack:** Claude Code plugin (markdown-based), haiku model for classifier

---

### Task 1: Scaffold plugin structure

**Files:**
- Create: `task-router/.claude-plugin/plugin.json`

**Step 1: Create plugin manifest**

```json
{
  "name": "task-router",
  "description": "Smart task routing: classifies specs and routes to feature-dev or subagent-driven-dev",
  "version": "1.0.0",
  "author": {
    "name": "Danil Pismenny",
    "email": "danilpismenny@gmail.com"
  },
  "homepage": "https://github.com/dapi/claude-code-marketplace",
  "repository": "https://github.com/dapi/claude-code-marketplace",
  "license": "MIT",
  "keywords": ["routing", "task", "workflow", "feature-dev", "subagent-driven-development"]
}
```

**Step 2: Verify structure**

```bash
ls -la task-router/.claude-plugin/plugin.json
```

**Step 3: Commit**

```bash
git add task-router/.claude-plugin/plugin.json
git commit -m "feat(task-router): scaffold plugin structure"
```

---

### Task 2: Create task-classifier agent

**Files:**
- Create: `task-router/agents/task-classifier.md`

This is the core component — haiku agent that:
1. Detects source type (GitHub/Google Doc/URL)
2. Fetches content using appropriate tool
3. Saves spec to /tmp/task-router/spec-<id>.md
4. Classifies using routing signals
5. Returns compact JSON

**Step 1: Write the agent**

The agent frontmatter should specify:
- `name: task-classifier`
- `description`: when to use (triggered by route-task command)
- `model: haiku` for fast/cheap classification
- Tools needed: Bash (for gh CLI, mkdir), WebFetch, Read, Write, Glob

The agent prompt body should include:

**Source detection logic:**

```
GitHub Issue patterns:
  - github.com/{owner}/{repo}/issues/{number}
  - #{number} (in repo context)
  → Fetch: gh issue view {number} --json title,body,labels,comments

Google Doc patterns:
  - docs.google.com/document/d/{DOCUMENT_ID}
  → Fetch: mcp__google_workspace__get_doc_content with user_google_email=danilpismenny@gmail.com

Any other URL:
  → Fetch: WebFetch
```

**Save spec to file:**

```bash
mkdir -p /tmp/task-router
# Save to /tmp/task-router/spec-{source}-{id}.md
# Example: /tmp/task-router/spec-github-org-repo-42.md
```

**Classification signals to extract:**

| Signal | Detection criteria |
|--------|-------------------|
| `needs_exploration` | References existing code, "change/update/refactor/fix" vs "create/build/new" |
| `architecture_unclear` | No clear architecture, "suggest approach", "how best", multiple options |
| `has_clear_tasks` | Numbered steps, task breakdown, checklist items, "Step 1/2/3" |
| `complexity` | S: <3 entities, M: 3-5, L: 5-10, XL: 10+ (models + endpoints + components) |

**Routing decision matrix:**

```
S/M complexity → "feature-dev"
L/XL + has_clear_tasks + NOT needs_exploration → "subagent-driven-dev"
L/XL + (needs_exploration OR architecture_unclear) → "hybrid"
L/XL + NOT has_clear_tasks → "subagent-driven-dev" (writing-plans will break it down)
```

**Response format (MUST return ONLY this JSON):**

```json
{
  "route": "feature-dev" | "subagent-driven-dev" | "hybrid",
  "complexity": "S" | "M" | "L" | "XL",
  "title": "Short task title",
  "summary": "1-2 sentence summary",
  "reasoning": "Why this route (1 sentence)",
  "spec_file": "/tmp/task-router/spec-...",
  "source": "github" | "google-doc" | "url",
  "signals": {
    "needs_exploration": true | false,
    "has_clear_tasks": true | false,
    "architecture_unclear": true | false
  }
}
```

**Step 2: Commit**

```bash
git add task-router/agents/task-classifier.md
git commit -m "feat(task-router): add task-classifier haiku agent"
```

---

### Task 3: Create /route-task command

**Files:**
- Create: `task-router/commands/route-task.md`

The command is the explicit entry point. It:
1. Receives URL as $ARGUMENTS
2. Dispatches task-classifier agent (haiku)
3. Presents result to user
4. Asks confirmation
5. Invokes chosen workflow

**Step 1: Write the command**

Frontmatter:
```yaml
---
description: Route a task to the optimal workflow (feature-dev or subagent-driven-dev)
argument-hint: <GitHub Issue URL | Google Doc URL | any URL>
---
```

Command body should define the orchestration flow:

```
Phase 1: Validate input
  - If $ARGUMENTS is empty → ask user for URL
  - If URL doesn't look valid → error message

Phase 2: Dispatch classifier
  - Launch Task tool with:
    - subagent_type: "task-router:task-classifier"
    - model: haiku
    - prompt: "Classify this task: {$ARGUMENTS}"
  - Wait for JSON result

Phase 3: Present result
  Show to user:
  ───────────────────────────────────
  📋 {title}
  Complexity: {complexity} | Route: {route}

  {summary}

  Reasoning: {reasoning}
  Signals: exploration={needs_exploration}, clear_tasks={has_clear_tasks}, unclear_arch={architecture_unclear}
  Spec saved: {spec_file}
  ───────────────────────────────────

Phase 4: Confirm and route
  AskUserQuestion:
    "Запускаю {route}?"
    Options:
    1. "Да, запускай {route}" → invoke appropriate skill
    2. "Нет, используй feature-dev" → invoke feature-dev
    3. "Нет, используй subagent-driven-dev" → invoke writing-plans + subagent-driven-dev
    4. "Отмена" → stop

Phase 5: Invoke workflow
  Based on choice:

  feature-dev:
    → Skill("feature-dev:feature-dev")
    → "Спека сохранена в {spec_file}, используй её как входные данные"

  subagent-driven-dev:
    → First: Skill("superpowers:writing-plans") with spec from {spec_file}
    → Then: Skill("superpowers:subagent-driven-development")

  hybrid:
    → Skill("feature-dev:feature-dev") but stop after phase 4 (architecture)
    → Save architecture as plan
    → Skill("superpowers:subagent-driven-development") with the plan
```

**Step 2: Commit**

```bash
git add task-router/commands/route-task.md
git commit -m "feat(task-router): add /route-task command"
```

---

### Task 4: Create task-routing auto-trigger skill

**Files:**
- Create: `task-router/skills/task-routing/SKILL.md`

The skill auto-triggers when user pastes task URLs or mentions issues.

**Step 1: Write the skill**

Frontmatter:
```yaml
---
name: task-routing
description: |
  Auto-trigger when user pastes task URLs or mentions issues.

  Triggers:
  - "возьми задачу", "сделай issue", "take issue"
  - GitHub issue URLs: github.com/.../issues/N
  - Google Doc URLs: docs.google.com/document/d/...
  - "реализуй по спеке", "implement this spec"
  - "route task", "route this"

  TRIGGERS: route task, возьми задачу, сделай issue, take issue,
  реализуй спеку, implement spec, github.com/issues,
  docs.google.com/document
tools: Skill
---
```

Skill body:
```
# Task Routing Skill

Auto-router for task URLs. Detects source and invokes /route-task command.

## Detection logic

1. Extract URL or issue reference from user message
2. Call: Skill tool → skill: "task-router:route-task", args: "{URL}"

## Examples

User: "Возьми задачу https://github.com/org/repo/issues/42"
→ Skill("task-router:route-task", args: "https://github.com/org/repo/issues/42")

User: "Реализуй спеку https://docs.google.com/document/d/1abc/edit"
→ Skill("task-router:route-task", args: "https://docs.google.com/document/d/1abc/edit")

User: "Сделай issue #123"
→ Skill("task-router:route-task", args: "#123")
```

**Step 2: Commit**

```bash
git add task-router/skills/task-routing/SKILL.md
git commit -m "feat(task-router): add auto-trigger skill"
```

---

### Task 5: Test the plugin end-to-end

**Step 1: Verify plugin structure**

```bash
find task-router/ -type f | sort
```

Expected:
```
task-router/.claude-plugin/plugin.json
task-router/agents/task-classifier.md
task-router/commands/route-task.md
task-router/skills/task-routing/SKILL.md
```

**Step 2: Verify plugin.json is valid JSON**

```bash
python3 -c "import json; json.load(open('task-router/.claude-plugin/plugin.json'))"
```

**Step 3: Manual test**

Install plugin and test with a real GitHub issue:
```
/route-task https://github.com/dapi/claude-code-marketplace/issues/1
```

Verify:
- [ ] Classifier agent is dispatched on haiku
- [ ] Spec is saved to /tmp/task-router/
- [ ] JSON result is returned
- [ ] User sees routing decision
- [ ] Confirmation prompt appears
- [ ] Chosen skill is invoked

**Step 4: Final commit**

```bash
git add -A task-router/
git commit -m "feat(task-router): complete plugin with tests"
```

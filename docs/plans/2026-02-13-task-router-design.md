# Task Router Plugin Design

## Goal

Plugin that takes a task URL (GitHub issue, Google Doc, any URL), classifies it without polluting main context, and routes to the optimal workflow: `feature-dev`, `writing-plans + subagent-driven-dev`, or advises to create a proper spec first.

## Architecture

### Flow

```
User: /route-task <url>
  │
  ├─→ Task(haiku): task-classifier agent
  │     ├─ Fetch content (gh CLI / Google Workspace MCP / WebFetch)
  │     ├─ Save spec → /tmp/task-router/spec-<id>.md
  │     ├─ Classify (complexity, signals)
  │     └─ Return compact JSON
  │
  ├─→ Display to user: task summary + routing decision + reasoning
  │
  └─→ Ask confirmation → invoke chosen skill
```

### Plugin Structure

```
task-router/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   └── route-task.md        # /route-task <url> — explicit invocation
├── skills/
│   └── task-routing/
│       └── SKILL.md          # Auto-trigger on task URLs in messages
└── agents/
    └── task-classifier.md    # haiku agent — fetch + classify
```

### Components

**Command: `/route-task <url>`**
- Explicit entry point
- Accepts: GitHub issue URL, Google Doc URL, any URL
- Dispatches task-classifier agent (haiku)
- Presents result, asks for confirmation
- Invokes chosen workflow skill

**Skill: `task-routing`**
- Auto-trigger when user pastes task URLs
- Triggers: "take issue #123", "do this task", GitHub/Google Docs links
- Same logic as command

**Agent: `task-classifier` (haiku)**
- Fetches URL content (gh CLI for GitHub, Google Workspace MCP for Docs, WebFetch for others)
- Saves full spec to /tmp/task-router/spec-<id>.md
- Classifies using routing signals
- Returns JSON (not full spec content)

### Routing Logic

#### Signals extracted from spec

| Signal | How detected |
|--------|-------------|
| `needs_exploration` | Mentions existing code, refactoring, "change", "update" (vs "create from scratch") |
| `architecture_unclear` | No clear architecture, multiple approaches possible, "suggest", "how best" |
| `has_clear_tasks` | Spec already broken into numbered steps/tasks/requirements |
| `complexity` | S/M/L/XL based on count of distinct entities, endpoints, components, integrations: S (<=2), M (3-5), L (6-10), XL (10+) |

#### Decision matrix

| Complexity | needs_exploration OR architecture_unclear | Route |
|------------|---------------------------------------------|-------|
| S/M | any | **feature-dev** |
| L/XL | no | **subagent-driven-dev** |
| L/XL | yes | **needs-spec** (advisory + brainstorming offer) |

> **Note:** Route values in JSON are `"feature-dev"`, `"subagent-driven-dev"`, `"needs-spec"`. The `/route-task` command orchestrates the actual workflow: for `subagent-driven-dev` it invokes `writing-plans` first, then `subagent-driven-development`.

#### Route descriptions

- **feature-dev**: Full workflow — exploration, questions, architecture, implementation, review
- **subagent-driven-dev**: Command invokes writing-plans first, then fresh subagent per task with two-stage review
- **needs-spec**: Task is too large and underspecified. Advises user to create a full spec, offers to launch brainstorming for exploration and architecture. After brainstorming, user creates a spec and re-runs `/route-task`.

### Agent Response Format

```json
{
  "route": "feature-dev" | "subagent-driven-dev" | "needs-spec",
  "complexity": "S" | "M" | "L" | "XL",
  "title": "Short task title",
  "summary": "1-2 sentence summary of what needs to be built",
  "reasoning": "Why this route was chosen (1 sentence)",
  "spec_file": "/tmp/task-router/spec-org-repo-42.md",
  "source": "github" | "google-doc" | "url",
  "signals": {
    "needs_exploration": true | false,
    "has_clear_tasks": true | false,
    "architecture_unclear": true | false
  }
}
```

### Source Detection

| Source | Pattern | Fetch method |
|--------|---------|-------------|
| GitHub Issue | `github.com/{owner}/{repo}/issues/{n}` or `#N` | `gh issue view N --json title,body,labels,comments` |
| Google Doc | `docs.google.com/document/d/{ID}` | `mcp__google_workspace__get_doc_content` |
| Any URL | `http(s)://...` | `WebFetch` |

### Key Design Decisions

1. **haiku for classifier** — fast, cheap, sufficient for classification
2. **Spec saved to file** — downstream skill reads file, not re-fetches URL
3. **User confirmation before routing** — user sees decision and can override
4. **Compact JSON return** — only ~200 tokens in main context vs thousands for full spec

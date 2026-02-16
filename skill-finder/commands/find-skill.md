---
name: find-skill
description: Search for agent skills in online catalogs (skills.sh, skyll.app)
argument-hint: <search query>
---

# Find Skill

Search for agent skills in online catalogs and optionally install them.

## Input

- **QUERY**: `$ARGUMENTS` -- search keywords (e.g. "debugging", "kubernetes helm", "code review")

If no arguments provided, ask the user what kind of skill they are looking for.

## Steps

### 1. Search via Skyll API

Run the search query:

```bash
curl -s "https://api.skyll.app/search?q=$(echo '$ARGUMENTS' | tr ' ' '+')&limit=10"
```

### 2. Parse and present results

From the JSON response, extract for each skill:
- `title` -- skill name
- `description` -- what it does (truncate to 1-2 sentences)
- `source` -- GitHub repo (e.g. `vercel-labs/agent-skills`)
- `install_count` -- number of installations
- `refs.skills_sh` -- link to skills.sh page

Present results as a numbered list:

```
Found N skills for "<query>":

1. **skill-name** (owner/repo) -- 12,450 installs
   Description of what the skill does...
   https://skills.sh/owner/repo/skill-name

2. **another-skill** (owner/repo) -- 3,200 installs
   Description...
   https://skills.sh/owner/repo/another-skill
```

If no results found, suggest refining the query with different keywords.

### 3. Offer installation

After showing results, ask the user:
- Which skill(s) to install (by number)
- Or "none" to skip

### 4. Install selected skill

For each selected skill, run:

```bash
npx skills add <source> -g -y
```

Where `<source>` is the GitHub repo from the `source` field (e.g. `vercel-labs/agent-skills`).

If `npx` is not available, show the manual installation alternative:
```bash
git clone https://github.com/<source>.git /tmp/skill-install && cp -r /tmp/skill-install/skills/<skill-name> ~/.claude/commands/
```

### 5. Confirm installation

After installation, confirm success and suggest the user restart their session or check `/skills` to see the new skill.

## Examples

```
/find-skill debugging
/find-skill react performance optimization
/find-skill code review PR
/find-skill kubernetes deployment
/find-skill git workflow
```

## Notes

- Search is powered by [Skyll API](https://api.skyll.app) which aggregates skills from multiple sources
- Skills follow the open SKILL.md standard compatible with Claude Code, Cursor, Codex CLI and others
- Installation via `npx skills add` requires Node.js

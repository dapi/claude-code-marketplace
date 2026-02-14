# Skill Audit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Conduct analytical audit of all marketplace skills, agents, and plugins; post results as comment on GitHub issue #20.

**Architecture:** 4 parallel subagents (A-D) each produce a markdown section. Results saved to `/tmp/skill-audit/`. Main agent assembles sections into final report and posts to GitHub.

**Tech Stack:** Claude Code subagents (general-purpose), `gh` CLI for GitHub comment posting.

---

## Task 1: Create output directory and verify file inventory

**Files:**
- Read: All SKILL.md, TRIGGER_EXAMPLES.md, agent .md, plugin.json (verification only)

**Step 1: Create temp output directory**

Run: `mkdir -p /tmp/skill-audit`

**Step 2: Verify all 10 skills have both files**

Run Glob for `**/skills/*/SKILL.md` and `**/skills/*/TRIGGER_EXAMPLES.md` (exclude `.worktrees/`).
Expected: 10 SKILL.md + 10 TRIGGER_EXAMPLES.md in main tree.

**Step 3: Verify all 16 agents exist**

Run Glob for `**/agents/*.md` (exclude `.worktrees/`).
Expected: 16 agent files (5 cluster + 10 spec + 1 task).

**Step 4: Verify all 12 plugin.json files exist**

Run Glob for `**/.claude-plugin/plugin.json` (exclude `.worktrees/`).
Expected: 12 plugin.json files.

---

## Task 2: Launch Agent A - Skills Trigger Analysis (PARALLEL with Tasks 3-5)

Launch as background Task subagent with `run_in_background: true`. Save output to `/tmp/skill-audit/section1-triggers.md`.

**Subagent prompt:**

```
You are auditing skill trigger quality for a Claude Code plugin marketplace.

For EACH of the 10 skills below, do:
1. Read SKILL.md — extract the `description` field from YAML frontmatter (these are the trigger keywords)
2. Read TRIGGER_EXAMPLES.md — find positive and negative examples
3. Pick exactly 5 positive examples (spread across categories)
4. Analytically evaluate each: does the example text contain keywords from the description?
   - PASS: trigger keywords clearly present in example AND in description
   - WARN: weak keyword overlap, skill might not activate
   - FAIL: example not covered by any keyword in description
5. Pick 3+ negative examples
6. Check: could any negative example accidentally match description keywords?
   - PASS: no keyword match, skill correctly won't activate
   - FAIL: false positive likely (keywords overlap)

Skills and their file paths (all relative to /home/danil/code/claude-code-marketplace/):

1. bugsnag: bugsnag-skill/skills/bugsnag/SKILL.md + TRIGGER_EXAMPLES.md
2. cluster-efficiency: cluster-efficiency/skills/cluster-efficiency/SKILL.md + TRIGGER_EXAMPLES.md
3. doc-validate: doc-validate/skills/doc-validate/SKILL.md + TRIGGER_EXAMPLES.md
4. github-issues: github-workflow/skills/github-issues/SKILL.md + TRIGGER_EXAMPLES.md
5. himalaya: himalaya/skills/himalaya/SKILL.md + TRIGGER_EXAMPLES.md
6. long-running-harness: long-running-harness/skills/long-running-harness/SKILL.md + TRIGGER_EXAMPLES.md
7. media-upload: media-upload/skills/media-upload/SKILL.md + TRIGGER_EXAMPLES.md
8. spec-review: spec-reviewer/skills/spec-review/SKILL.md + TRIGGER_EXAMPLES.md
9. task-routing: task-router/skills/task-routing/SKILL.md + TRIGGER_EXAMPLES.md
10. zellij-dev-tab: zellij-dev-tab/skills/zellij-dev-tab/SKILL.md + TRIGGER_EXAMPLES.md

OUTPUT FORMAT (write to /tmp/skill-audit/section1-triggers.md):

## Section 1: Skills Trigger Analysis

**Summary:** X/50 positive PASS, Y/30 negative PASS

### 1. bugsnag (X/5 positive, Y/3 negative)

**Positive tests:**
| # | Example | Result | Keywords matched |
|---|---------|--------|-----------------|
| 1 | "show bugsnag errors" | PASS | "show" + "bugsnag" + "errors" |
| 2 | ... | ... | ... |

**Negative tests:**
| # | Example | Result | Notes |
|---|---------|--------|-------|
| 1 | "install bugsnag gem" | PASS | no action keyword match |

[repeat for all 10 skills]

### Issues Found
- [list any WARN or FAIL results with recommendations]

IMPORTANT: Write the COMPLETE output to /tmp/skill-audit/section1-triggers.md using the Write tool. Do NOT return the content as text — save it to the file.
```

---

## Task 3: Launch Agent B - Conflict Matrix (PARALLEL with Tasks 2, 4-5)

Launch as background Task subagent with `run_in_background: true`. Save output to `/tmp/skill-audit/section2-conflicts.md`.

**Subagent prompt:**

```
You are analyzing inter-skill trigger conflicts in a Claude Code plugin marketplace.

Read the SKILL.md files for these 4 skills (extract full `description` field from YAML frontmatter):

1. task-routing: /home/danil/code/claude-code-marketplace/task-router/skills/task-routing/SKILL.md
2. spec-review: /home/danil/code/claude-code-marketplace/spec-reviewer/skills/spec-review/SKILL.md
3. github-issues: /home/danil/code/claude-code-marketplace/github-workflow/skills/github-issues/SKILL.md
4. zellij-dev-tab: /home/danil/code/claude-code-marketplace/zellij-dev-tab/skills/zellij-dev-tab/SKILL.md

For each skill, extract ALL trigger keywords and patterns from the description.

Then analyze 3 conflict pairs:

**Pair 1: task-routing vs spec-review**
- Both handle GitHub issue URLs and Google Doc URLs
- Find overlapping keywords
- Create 5+ test queries that could trigger both
- For each, determine which skill SHOULD win and why

**Pair 2: github-issues vs task-routing**
- Both handle #NNN issue references
- Find overlapping keywords
- Create 5+ test queries
- Determine correct winner for each

**Pair 3: zellij-dev-tab vs github-issues**
- Both reference GitHub issues
- Find overlapping keywords
- Create 5+ test queries
- Determine correct winner for each

OUTPUT FORMAT (write to /tmp/skill-audit/section2-conflicts.md):

## Section 2: Inter-Skill Conflict Matrix

### Keyword Overlap Analysis

| Keyword/Pattern | task-routing | spec-review | github-issues | zellij-dev-tab |
|----------------|-------------|-------------|---------------|----------------|
| github.com/issues | YES | YES | YES | YES |
| ... | ... | ... | ... | ... |

### Conflict Test Queries

| # | Query | task-routing | spec-review | github-issues | zellij-dev-tab | Expected Winner | Correct? |
|---|-------|-------------|-------------|---------------|----------------|----------------|----------|
| 1 | "review spec from github.com/org/repo/issues/42" | weak | strong | weak | none | spec-review | YES |
| ... | ... | ... | ... | ... | ... | ... | ... |

Match strength: strong / weak / none

### Conflict Resolution Summary

**Pair 1 (task-routing vs spec-review):** [assessment]
**Pair 2 (github-issues vs task-routing):** [assessment]
**Pair 3 (zellij-dev-tab vs github-issues):** [assessment]

### Issues Found
- [list any unresolvable conflicts or ambiguous cases]

IMPORTANT: Write the COMPLETE output to /tmp/skill-audit/section2-conflicts.md using the Write tool.
```

---

## Task 4: Launch Agent C - Agent Descriptions Review (PARALLEL with Tasks 2-3, 5)

Launch as background Task subagent with `run_in_background: true`. Save output to `/tmp/skill-audit/section3-agents.md`.

**Subagent prompt:**

```
You are reviewing agent description quality for a Claude Code plugin marketplace.

Read the YAML frontmatter from each of these 16 agent files. Check:
1. `description` field length (must be <= 1024 characters)
2. Clarity: does description clearly state WHEN the agent should be invoked?
3. `tools` field: are tool restrictions present and reasonable?
4. No dead references to nonexistent tools or files

Agent files (all under /home/danil/code/claude-code-marketplace/):

**cluster-efficiency (5 agents):**
- cluster-efficiency/agents/cluster-karpenter-analyzer.md
- cluster-efficiency/agents/cluster-orchestrator.md
- cluster-efficiency/agents/cluster-oom-analyzer.md
- cluster-efficiency/agents/cluster-node-analyzer.md
- cluster-efficiency/agents/cluster-workload-analyzer.md

**spec-reviewer (10 agents):**
- spec-reviewer/agents/spec-classifier.md
- spec-reviewer/agents/spec-ai-readiness.md
- spec-reviewer/agents/spec-ux.md
- spec-reviewer/agents/spec-test.md
- spec-reviewer/agents/spec-scoper.md
- spec-reviewer/agents/spec-risk.md
- spec-reviewer/agents/spec-analyst.md
- spec-reviewer/agents/spec-api.md
- spec-reviewer/agents/spec-data.md
- spec-reviewer/agents/spec-infra.md

**task-router (1 agent):**
- task-router/agents/task-classifier.md

OUTPUT FORMAT (write to /tmp/skill-audit/section3-agents.md):

## Section 3: Agent Description Quality

**Summary:** X/16 OK, Y warnings, Z issues

| # | Agent | Plugin | Desc Length | Clarity | Tools | Issues |
|---|-------|--------|-------------|---------|-------|--------|
| 1 | cluster-karpenter-analyzer | cluster-efficiency | 450 chars | OK | Bash, Read | none |
| 2 | ... | ... | ... | ... | ... | ... |

### Detailed Issues
- [list each issue with agent name, problem, and recommendation]

IMPORTANT: Write the COMPLETE output to /tmp/skill-audit/section3-agents.md using the Write tool.
```

---

## Task 5: Launch Agent D - plugin.json Consistency (PARALLEL with Tasks 2-4)

Launch as background Task subagent with `run_in_background: true`. Save output to `/tmp/skill-audit/section4-plugins.md`.

**Subagent prompt:**

```
You are auditing plugin.json consistency for a Claude Code plugin marketplace.

Read each of the 12 plugin.json files and check:
1. Valid JSON (parseable)
2. Required fields present: name, description, version, author, license
3. Optional but expected: homepage, repository, keywords
4. Keywords relevance: do keywords match actual skills/agents in the plugin?
5. Version format: semver (X.Y.Z)

Also check cross-plugin consistency:
- Are naming conventions consistent?
- Are versions reasonable (not wildly different)?

Plugin.json files (all under /home/danil/code/claude-code-marketplace/):

1. bugsnag-skill/.claude-plugin/plugin.json
2. cluster-efficiency/.claude-plugin/plugin.json
3. doc-validate/.claude-plugin/plugin.json
4. github-workflow/.claude-plugin/plugin.json
5. himalaya/.claude-plugin/plugin.json
6. long-running-harness/.claude-plugin/plugin.json
7. media-upload/.claude-plugin/plugin.json
8. requirements/.claude-plugin/plugin.json
9. spec-reviewer/.claude-plugin/plugin.json
10. task-router/.claude-plugin/plugin.json
11. zellij-tab-claude-status/.claude-plugin/plugin.json
12. zellij-dev-tab/.claude-plugin/plugin.json

For keywords check, also verify by listing actual files:
- Glob: {plugin}/agents/*.md
- Glob: {plugin}/skills/*/SKILL.md
- Glob: {plugin}/commands/*.md

OUTPUT FORMAT (write to /tmp/skill-audit/section4-plugins.md):

## Section 4: plugin.json Consistency Audit

**Summary:** X/12 fully consistent, Y with issues

| # | Plugin | Version | Required Fields | Keywords | Issues |
|---|--------|---------|----------------|----------|--------|
| 1 | bugsnag-skill | 1.0.0 | OK | 3 keywords, match | none |
| 2 | ... | ... | ... | ... | ... |

### Cross-Plugin Consistency
- Version range: [min] to [max]
- Naming convention: [assessment]
- Missing optional fields: [list]

### Detailed Issues
- [list each issue with plugin name, problem, and recommendation]

IMPORTANT: Write the COMPLETE output to /tmp/skill-audit/section4-plugins.md using the Write tool.
```

---

## Task 6: Collect and verify all 4 section outputs

**Files:**
- Read: `/tmp/skill-audit/section1-triggers.md`
- Read: `/tmp/skill-audit/section2-conflicts.md`
- Read: `/tmp/skill-audit/section3-agents.md`
- Read: `/tmp/skill-audit/section4-plugins.md`

**Step 1: Wait for all background agents to complete**

Check each output file exists and has content.

**Step 2: Verify completeness**

- Section 1: must have 10 skills x 5 positive + 3 negative = 50 positive + 30 negative tests
- Section 2: must have conflict matrix with 15+ test queries (5 per pair)
- Section 3: must have 16 agent rows
- Section 4: must have 12 plugin rows

**Step 3: Note any gaps for manual follow-up**

---

## Task 7: Assemble final report and post to GitHub issue #20

**Step 1: Build report header**

```markdown
# Qualitative Audit: Skill Activation & Conflict Check

**Date:** 2026-02-14
**Methodology:** Analytical audit (description keyword matching, not runtime testing)
**Scope:** 10 skills, 16 agents, 12 plugins, 3 conflict pairs

## Executive Summary

| Audit Area | Total | Pass | Warn | Fail |
|-----------|-------|------|------|------|
| Positive trigger tests | 50 | X | Y | Z |
| Negative trigger tests | 30+ | X | Y | Z |
| Conflict queries | 15+ | X | - | Z |
| Agent descriptions | 16 | X | Y | Z |
| plugin.json files | 12 | X | - | Z |
```

**Step 2: Concatenate sections 1-4 after the header**

**Step 3: Add recommendations section at the end**

```markdown
## Recommendations

### Critical (must fix)
- [FAIL items]

### Suggested (nice to have)
- [WARN items]

### Next Steps
- [ ] Runtime testing in clean sessions (manual)
- [ ] Fix identified trigger gaps
- [ ] Resolve conflict ambiguities
```

**Step 4: Post to GitHub issue**

Run:
```bash
gh issue comment 20 --repo dapi/claude-code-marketplace --body-file /tmp/skill-audit/final-report.md
```

Expected: Comment posted successfully.

---

## Execution Notes

- **Tasks 2-5 are PARALLEL** — launch all 4 background agents simultaneously
- **Task 6 depends on Tasks 2-5** — wait for all to complete
- **Task 7 depends on Task 6** — assemble and post
- Total subagents: 4 (general-purpose, running in background)
- Estimated total agent turns: ~40-60 across all 4 agents

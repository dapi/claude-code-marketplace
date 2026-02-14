# Skill Audit Design: Qualitative Activation Testing & Conflict Check

**Issue**: https://github.com/dapi/claude-code-marketplace/issues/20
**Date**: 2026-02-14
**Approach**: Analytical audit (no runtime testing)
**Output**: Comment in GitHub issue #20

## Overview

Parallel audit using 4 subagents, each responsible for one section of the issue.
Results assembled into a single GitHub issue comment.

## Scope

| Component | Count |
|-----------|-------|
| Skills (with TRIGGER_EXAMPLES.md) | 10 |
| Agents | 16 (5 cluster + 10 spec + 1 task) |
| Plugins (plugin.json) | 12 |
| Conflict pairs | 3 |

### Skills to audit
1. bugsnag
2. cluster-efficiency
3. doc-validate
4. github-issues
5. himalaya
6. long-running-harness
7. media-upload
8. spec-review
9. task-routing
10. zellij-dev-tab

### Conflict pairs
1. task-routing vs spec-review (both handle GitHub issues/specs)
2. github-issues vs task-routing (both handle #NNN references)
3. zellij-dev-tab vs github-issues (both handle issue references)

## Section 1: Skills Trigger Analysis (Agent A)

**Input**: SKILL.md + TRIGGER_EXAMPLES.md for each of 10 skills.

**Process**:
1. Read SKILL.md description/triggers
2. Read TRIGGER_EXAMPLES.md
3. Pick 5 positive examples per skill
4. Analytically evaluate: do example keywords match description keywords?
   - PASS: trigger keywords clearly present in both example and description
   - WARN: example may not activate skill (weak keyword match)
   - FAIL: example not covered by description keywords
5. Pick 3+ negative examples per skill
6. Check for accidental matches with description
   - PASS: skill should not activate (no keyword match)
   - FAIL: false positive likely

**Output format**:
```
### skill-name (X/5 pass, Y/3 negative pass)
| # | Example | Result | Notes |
|---|---------|--------|-------|
| 1 | "example query" | PASS | matches "keyword1" + "keyword2" |
```

**Target**: 50 positive tests + 30 negative tests.

## Section 2: Inter-Skill Conflict Matrix (Agent B)

**Input**: SKILL.md for 4 conflicting skills.

**Process**:
1. Extract all trigger keywords from each skill
2. Find keyword intersections between conflict pairs
3. For each intersection, evaluate: who "wins" and is it correct?
4. Build conflict matrix with test queries

**Output format**:
```
| Query | task-routing | spec-review | github-issues | zellij-dev-tab | Winner | Correct? |
|-------|-------------|-------------|---------------|----------------|--------|----------|
```

Plus: overlapping keywords table with resolution strategy.

## Section 3: Agent Descriptions Review (Agent C)

**Input**: 16 agent markdown files with frontmatter.

**Process**:
For each agent check:
1. Description length <= 1024 chars
2. Clarity of invocation criteria
3. Tools field: restrictions correct and complete
4. No dead references to tools/files

**Output format**: Table with agent | status | issues.

## Section 4: plugin.json Consistency (Agent D)

**Input**: 12 plugin.json files.

**Process**:
For each plugin.json:
1. Valid JSON
2. Required fields present (name, description, version, author, license)
3. Keywords match actual skills/agents
4. Versions consistent across marketplace

**Output format**: Table with plugin | version | fields | issues.

## Deliverable

Single GitHub issue comment on #20 containing:
1. Executive summary with pass/fail counts
2. Section 1: Skills trigger analysis tables
3. Section 2: Conflict matrix
4. Section 3: Agent review table
5. Section 4: plugin.json audit table
6. Recommendations and next steps

## Definition of Done mapping

| Issue checkbox | Covered by |
|---------------|------------|
| 50 positive activation tests | Section 1 (5 per skill x 10) |
| 30+ negative activation tests | Section 1 (3+ per skill x 10) |
| Conflict matrix documented | Section 2 |
| Agent description issues logged | Section 3 |
| plugin.json audit complete | Section 4 |

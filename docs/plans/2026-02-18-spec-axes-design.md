# Spec Axes Agent Design

**Date:** 2026-02-18
**Status:** Approved
**Plugin:** spec-reviewer

## Problem

Specifications should cover three axes for every feature:
1. **What we build** (PRD, User Story, AC)
2. **How we build** (C4, ERD, API Spec, architecture)
3. **How we verify** (Test Plan, Acceptance Criteria, test cases)

Current spec-reviewer agents check **quality within domains** (data, api, infra, etc.) but nobody checks **coverage completeness** across all three axes per feature.

## Solution

New agent `spec-axes` that:
1. Extracts list of features/functions from the specification
2. For each feature, checks if all 3 axes are covered
3. Generates `AXS-*` issues for missing coverage
4. Produces a coverage matrix

## Agent: spec-axes

### File
`spec-reviewer/agents/spec-axes.md`

### Algorithm

```
1. Extract features from spec → [{name, description, location}]

2. For each feature, check 3 axes:

   AXIS 1 — WHAT (what we build):
   - User Story / requirement description?
   - Acceptance Criteria?
   - Business context (why)?
   → Artifacts: PRD, User Story, AC, Use Case

   AXIS 2 — HOW (how we build):
   - Architecture / design description?
   - Data models (ERD)?
   - API contract?
   - Components (C4)?
   → Artifacts: ERD, API Spec, C4, Sequence Diagram

   AXIS 3 — VERIFY (how we verify):
   - Test Plan / test scenarios?
   - AC with measurable metrics?
   - Edge cases?
   → Artifacts: Test Plan, AC, Test Cases, NFR metrics

3. Generate AXS-{AXIS}-{XXX} issues for each gap
4. Build coverage matrix (feature x axis)
```

### Launch Condition
- depth_level >= standard (skip on quick)
- Does NOT depend on classifier flags — always runs on standard+

### ID Format: `AXS-{AXIS}-{XXX}`

| Axis | Prefix | Description |
|------|--------|-------------|
| what | `AXS-WHAT-` | Missing "what we build" (User Story, PRD, AC) |
| how | `AXS-HOW-` | Missing "how we build" (ERD, API, architecture) |
| verify | `AXS-VRF-` | Missing "how we verify" (Test Plan, AC) |

### Severity Rules

| Condition | Severity |
|-----------|----------|
| 2 of 3 axes missing | critical |
| 1 of 3 axes missing | high |
| Axis present but incomplete | medium |

### Output Format

```json
{
  "agent": "axes",
  "features": [
    {
      "name": "User Registration",
      "location": "Section 3",
      "axes": {
        "what": {"covered": true, "artifacts": ["US-001", "AC-001"]},
        "how": {"covered": true, "artifacts": ["ERD section 4", "POST /users"]},
        "verify": {"covered": false, "artifacts": []}
      }
    }
  ],
  "coverage_matrix": {
    "total_features": 5,
    "fully_covered": 2,
    "partially_covered": 2,
    "not_covered": 1
  },
  "issues": [
    {
      "id": "AXS-VRF-001",
      "type": "axis_gap",
      "severity": "high",
      "title": "No Test Plan for 'User Registration'",
      "description": "Feature described (US-001) and designed (ERD, API), but no test scenarios",
      "feature": "User Registration",
      "missing_axis": "verify",
      "present_axes": ["what", "how"],
      "recommendation": "Add: acceptance tests, edge cases, negative scenarios"
    }
  ]
}
```

## Integration into Orchestrator (spec-review.md)

### Phase 2 Changes

Add spec-axes to the parallel agent launch:
- **Mandatory agents (always):** spec-analyst, spec-test
- **Conditional standard+ (NEW):** spec-axes
- **Conditional by classifier:** spec-data, spec-api, spec-infra, spec-risk, spec-ux, spec-ai-readiness

### Report Changes

New section **before** issue list:

```markdown
### Axes Coverage (Three Axes)

| Feature | What (PRD/US/AC) | How (ERD/API/C4) | Verify (Tests/AC) |
|---------|-------------------|-------------------|---------------------|
| Registration | [OK] US-001, AC | [OK] ERD, POST /users | [!] No test plan |
| Payment | [OK] US-002 | [!] No API spec | [!] No tests |
| Notifications | [!] No User Story | [!] No architecture | [!] No tests |

**Fully covered:** 1/3 (33%)
**Partially:** 1/3
**No coverage:** 1/3
```

### Summary Table

Add row for AXS-* in the quality summary:

```
| Source | Crit. | High | Med. | Low |
|--------|-------|------|------|-----|
| Axes (AXS-*) | N | N | N | N |
```

## Files to Create/Modify

1. **CREATE** `spec-reviewer/agents/spec-axes.md` — new agent definition
2. **MODIFY** `spec-reviewer/commands/spec-review.md` — add spec-axes to Phase 2, add axes coverage report section
3. **MODIFY** `spec-reviewer/agents/spec-classifier.md` — add `has_multiple_features` flag (optional optimization)
4. **MODIFY** `spec-reviewer/.claude-plugin/plugin.json` — register new agent
5. **MODIFY** `spec-reviewer/README.md` — add spec-axes to agent list

# Skill Trigger Quick Reference Card

**One-page guide** для быстрого создания качественных триггеров.

---

## 🎯 Golden Rule

```
[ACTION_VERB] + [DATA_TYPE] + from/in [TOOL_NAME]
```

**Примеры**:
- `get projects from bugsnag`
- `show error details in bugsnag`
- `list organizations for jira`

---

## ✅ 10-Point Checklist

Используйте перед коммитом:

```
[ ] 1. UNIVERSAL TRIGGER в начале description
[ ] 2. 15-50 ключевых слов в TRIGGERS
[ ] 3. Минимум 5 action verbs (get, show, list, check, analyze)
[ ] 4. Категории с emoji (📊, 🔍, ✅)
[ ] 5. Мультиязычность (EN + RU)
[ ] 6. Context patterns ("what in", "check", "from")
[ ] 7. TRIGGER_EXAMPLES.md с 20+ примерами
[ ] 8. Negative examples ("should NOT activate")
[ ] 9. Description 300-1200 chars
[ ] 10. Протестировано вручную
```

**Цель**: 90+/100 баллов

---

## 📋 Description Template (Copy-Paste)

```yaml
---
name: tool-name
description: |
  **UNIVERSAL TRIGGER**: [action verb] + [data type] + from/in [tool]

  Common patterns:
  - "[natural query 1]"
  - "[natural query 2]"

  Specific data types supported:

  📊 **[Category 1]**:
  - "[example EN]", "[пример RU]"

  🔍 **[Category 2]**:
  - "[example EN]", "[пример RU]"

  ✅ **[Category 3]**:
  - "[example EN]", "[пример RU]"

  TRIGGERS: [tool-name], [key], [words], [comma], [separated],
  [include], [all], [synonyms], [english], [russian]

  [Brief 1-2 sentence functionality description]
allowed-tools: [Bash, Read, ...]
---
```

---

## 🔤 Action Verbs Cheatsheet

### Viewing/Reading (обязательно)
**EN**: get, show, list, display, view, retrieve, fetch
**RU**: показать, получить, вывести, список, посмотреть

### Checking/Verifying
**EN**: check, verify, validate, test
**RU**: проверить, проверка, валидация

### Analyzing
**EN**: analyze, examine, inspect, review
**RU**: анализ, проанализировать, изучить

### Managing/Writing
**EN**: create, update, delete, modify, add, remove
**RU**: создать, обновить, удалить, изменить, добавить

### Questioning (context patterns)
**EN**: "what [data] in [tool]", "what's happening"
**RU**: "что [данные] в [tool]", "что происходит"

---

## 📊 Data Type Patterns

### Plural/Singular
- `project` / `projects`
- `error` / `errors`
- `organization` / `orgs`

### Abbreviations
- `organization` = `org` = `orgs`
- `repository` = `repo` = `repos`
- `configuration` = `config` = `configs`

### Synonyms
- `error` = `issue` = `problem` = `failure`
- `detail` = `info` = `information` = `data`

---

## 🧪 Testing Protocol (3 minutes)

### Quick Test
```bash
# Run automated check
./scripts/review_skill_triggers.sh <plugin>/<skill>

# Goal: ≥90/100 score
```

### Manual Test (pick 5 random from TRIGGER_EXAMPLES.md)
1. Open new Claude Code session
2. Type example query
3. Verify skill activates
4. Document failures → fix → retest

---

## ❌ Common Mistakes

| Mistake | Example | Fix |
|---------|---------|-----|
| Too narrow | "Use when user wants to see errors" | Add: projects, orgs, analysis, etc. |
| No synonyms | Only "show" | Add: get, list, display, view |
| English only | No Russian triggers | Add: показать, список, получить |
| No context | Just tool name triggers | Add: "what in", "check", "from" |
| Too general | "[tool]" alone activates | Require: [action] + [tool] |
| No negatives | Only positive examples | Document what should NOT activate |
| No testing | Ship without verification | Test 5+ examples manually |

---

## 🎯 Category Icons (standard set)

Use consistent emoji for similar categories:

```
📊 Organizations/Projects/Resources
🐛 Errors/Issues/Problems
🔍 Details/Analysis/Deep-dive
💬 Comments/Discussion
📈 Analytics/Statistics/Trends
✅ Management/Actions/Write-ops
🔐 Security/Permissions/Auth
⚙️ Configuration/Settings
📦 Deployment/Releases
🧪 Testing/QA
```

---

## 🚀 Automated Review

```bash
# Single skill
./scripts/review_skill_triggers.sh dev-tools/bugsnag

# All skills
./scripts/review_skill_triggers.sh --all
```

**Scoring**:
- 90-100: ⭐⭐⭐⭐⭐ Excellent
- 75-89:  ⭐⭐⭐⭐ Good
- 60-74:  ⭐⭐⭐ Acceptable
- <60:    ⭐⭐ Needs work

---

## 📝 TRIGGER_EXAMPLES.md Skeleton

```markdown
# [Skill] Trigger Examples

## ✅ Should Activate

### English
- "get [data] from [tool]"
- "show [resource] in [tool]"

### Russian
- "получить [данные] из [tool]"
- "показать [ресурс] в [tool]"

## ❌ Should NOT Activate

- "what is [tool]" (general question)
- "install [tool]" (installation)
- "[tool] vs [competitor]" (comparison)

## 🎯 Key Words

**Verbs**: [list]
**Nouns**: [list]
**Context**: [patterns]
```

---

## 🔄 Improvement Workflow

```
1. Create skill → 2. Add basic triggers
                     ↓
3. Run review script → 4. Score < 90?
                     ↓ YES
5. Check recommendations → 6. Apply fixes
                     ↓
7. Retest → 8. Score ≥ 90? → 9. Commit
```

---

## 💡 Pro Tips

1. **Start universal**: Begin with broad pattern, then narrow
2. **Think user**: How would YOU ask for this data?
3. **Test early**: Don't wait until commit to test
4. **Iterate fast**: Small improvements → retest → improve
5. **Copy patterns**: Good skills are templates for new ones
6. **Document as you go**: Don't leave TRIGGER_EXAMPLES.md for later
7. **Get feedback**: Ask others to try activating your skill
8. **Monitor usage**: Track which triggers actually get used

---

## 📚 Resources

- **Full Checklist**: `SKILL_TRIGGER_REVIEW_CHECKLIST.md` (comprehensive guide)
- **Review Script**: `scripts/review_skill_triggers.sh` (automated testing)
- **Example Skill**: `dev-tools/skills/bugsnag/` (93/100 reference implementation)

---

## 🎓 Learning Path

### Beginner (0-60 score)
Focus: Basic structure, UNIVERSAL TRIGGER, 15+ keywords

### Intermediate (60-75 score)
Focus: Multilingual support, categorization, examples documentation

### Advanced (75-90 score)
Focus: Context patterns, verb diversity, negative examples

### Expert (90-100 score)
Focus: Optimization, cross-skill validation, comprehensive testing

---

## ⚡ Speed Run (5 minutes to basic skill)

```bash
# 1. Copy template (30 sec)
cp SKILL_TRIGGER_QUICK_REFERENCE.md new-skill/SKILL.md

# 2. Fill in (2 min)
# - name, tool-name
# - 3 categories with examples
# - 15 trigger keywords

# 3. Create examples (2 min)
# - 10 positive examples
# - 3 negative examples

# 4. Test (30 sec)
./scripts/review_skill_triggers.sh plugin/new-skill

# Goal: ≥60/100 on first try
```

---

**Version**: 1.0
**Last Updated**: 2025-11-22
**Maintainer**: Claude Code Marketplace

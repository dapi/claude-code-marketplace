# Marketplace Scripts

Утилиты для разработки и проверки качества plugins в Claude Code Marketplace.

---

## 📋 Available Scripts

### review_skill_triggers.sh

Автоматизированный анализ качества триггеров в skills.

**Функциональность**:
- Проверяет структуру SKILL.md (YAML frontmatter, required fields)
- Анализирует наличие универсального триггера
- Подсчитывает и оценивает количество trigger keywords
- Проверяет категоризацию контента (emoji)
- Валидирует мультиязычность (EN + RU)
- Оценивает разнообразие action verbs
- Проверяет контекстные паттерны ("what in", "check", "from")
- Валидирует наличие TRIGGER_EXAMPLES.md
- Анализирует длину description
- Проверяет документацию negative examples

**Оценка**: 100-балльная система с рейтингом ⭐⭐⭐⭐⭐

---

## 🚀 Usage

### Проверка одного skill

```bash
./scripts/review_skill_triggers.sh <plugin-name>/<skill-name>

# Примеры:
./scripts/review_skill_triggers.sh dev-tools/bugsnag
./scripts/review_skill_triggers.sh testing-tools/playwright
```

**Вывод**:
```
╔════════════════════════════════════════════╗
║  Skill Trigger Quality Review Tool        ║
╔════════════════════════════════════════════╗

Reviewing skill: dev-tools/bugsnag
File: dev-tools/skills/bugsnag/SKILL.md

[1/10] File Structure
  ✅ YAML frontmatter present
  ✅ Required fields (name, description) present

[2/10] Universal Trigger Pattern
  ✅ Universal trigger pattern defined

[3/10] Trigger Keyword Count
  ℹ️  Trigger keyword count: 20
  ✅ Optimal keyword count (15-50)

...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FINAL SCORE: 93/100
RATING: Excellent ⭐⭐⭐⭐⭐
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 RECOMMENDATIONS:
  ✅ No major improvements needed!
```

### Проверка всех skills

```bash
./scripts/review_skill_triggers.sh --all
```

Проверяет все SKILL.md файлы в marketplace и выводит отчет по каждому.

---

## 📊 Scoring System

### Breakdown (100 points total)

| Category | Points | Description |
|----------|--------|-------------|
| File Structure | 10 | YAML frontmatter, required fields |
| Universal Trigger | 15 | Defined universal pattern |
| Keyword Count | 15 | Optimal range 15-50 keywords |
| Categorization | 10 | Visual categories with emoji |
| Multilingual | 10 | EN + RU support |
| Verb Diversity | 10 | 5+ action verbs |
| Context Patterns | 10 | "what in", "check", "from" |
| Test Examples | 10 | TRIGGER_EXAMPLES.md exists |
| Description Length | 5 | Optimal 300-1200 chars |
| Negative Examples | 10 | Documented what NOT to activate |

### Rating Bands

- **90-100**: ⭐⭐⭐⭐⭐ Excellent - production ready
- **75-89**: ⭐⭐⭐⭐ Good - minor improvements needed
- **60-74**: ⭐⭐⭐ Acceptable - needs refinement
- **<60**: ⭐⭐ Poor - major rework required

---

## 🔧 Requirements

**System**:
- Bash 4.0+
- GNU grep
- Standard Unix utilities (sed, wc, etc.)

**No external dependencies** - uses only built-in Unix tools.

---

## 💡 Integration with Development Workflow

### Pre-commit Check

```bash
# In .git/hooks/pre-commit
#!/bin/bash

# Check all modified skills
for file in $(git diff --cached --name-only | grep "SKILL.md"); do
  skill_path=$(dirname "$file" | sed 's|/skills/|/|')
  ./scripts/review_skill_triggers.sh "$skill_path" || exit 1
done
```

### CI/CD Pipeline

```yaml
# In .github/workflows/skill-quality.yml
- name: Review Skill Triggers
  run: ./scripts/review_skill_triggers.sh --all
```

### Development Iteration

```bash
# Rapid iteration loop
while true; do
  # Edit SKILL.md
  vim dev-tools/skills/bugsnag/SKILL.md

  # Test
  ./scripts/review_skill_triggers.sh dev-tools/bugsnag

  # Check score
  read -p "Continue editing? (y/n) " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && break
done
```

---

## 📖 See Also

- **SKILL_TRIGGER_REVIEW_CHECKLIST.md** - Comprehensive manual review guide
- **SKILL_TRIGGER_QUICK_REFERENCE.md** - One-page quick reference card
- **dev-tools/skills/bugsnag/** - Reference implementation (93/100)

---

## 🐛 Troubleshooting

### "Skill file not found"

```bash
# Ensure correct path format
./scripts/review_skill_triggers.sh <plugin>/<skill>

# Not:
./scripts/review_skill_triggers.sh <plugin>/skills/<skill>
```

### "grep: Invalid range end"

Ignore this warning - it's from emoji detection in older grep versions. Doesn't affect scoring.

### Low Score on First Run

**Normal!** Use recommendations to improve:

```bash
# Run review
./scripts/review_skill_triggers.sh dev-tools/new-skill

# Read recommendations
# Apply fixes to SKILL.md
# Re-run review
# Repeat until ≥90/100
```

---

## 🚀 Future Enhancements

- [ ] JSON output format for CI integration
- [ ] Automatic fix suggestions (patch generation)
- [ ] Cross-skill conflict detection
- [ ] Performance metrics (activation speed)
- [ ] Usage analytics integration
- [ ] Comparative scoring across skills

---

**Version**: 1.0
**Last Updated**: 2025-11-22
**Author**: Claude Code Marketplace Team

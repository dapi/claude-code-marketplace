# Skill Trigger Review Checklist

Чеклист для проверки и улучшения триггеров в Claude Code skills.

## 📋 Quick Assessment

Используйте этот быстрый чеклист для каждого skill:

```
Skill: _______________
Date: _______________
Reviewer: _______________

[ ] 1. Универсальный триггер определен
[ ] 2. Покрывает ВСЮ функциональность tool/скрипта
[ ] 3. Естественные формулировки включены
[ ] 4. Мультиязычность (если нужна)
[ ] 5. Вариации глаголов (get/show/list/fetch...)
[ ] 6. Контекстные запросы ("что в...", "check...")
[ ] 7. Категоризация по типам данных
[ ] 8. Негативные примеры (что НЕ активирует)
[ ] 9. Тестовые примеры документированы
[ ] 10. Нет дублирования с другими skills

Score: ___/10
Status: [ ] PASS [ ] NEEDS IMPROVEMENT [ ] FAIL
```

---

## 🔍 Detailed Review Process

### Phase 1: Coverage Analysis

**Цель**: Убедиться, что триггеры покрывают ВСЮ функциональность skill.

#### 1.1 Инвентаризация функций

```bash
# Для Ruby скриптов
grep -E "when |def " skill_script.rb | grep -v private

# Для Bash скриптов
grep -E "^[a-z_]+\(\)|case.*in" skill_script.sh

# Для Python скриптов
grep -E "^def |^class " skill_script.py
```

**Чеклист**:
- [ ] Составлен список ВСЕХ доступных команд/функций
- [ ] Каждая функция имеет триггер в description
- [ ] Триггеры включают синонимы для каждой функции

**Пример плохого покрытия**:
```yaml
# ❌ Skill имеет 10 команд, description упоминает только 3
description: "Use when user wants to list errors or show details"
# Функции: list, details, resolve, comment, analyze, orgs, projects...
```

**Пример хорошего покрытия**:
```yaml
# ✅ Все 10 команд представлены в description
description: |
  UNIVERSAL TRIGGER: Any operation with [tool_name]

  Supported operations:
  - List/show data (errors, projects, orgs)
  - Details/analysis (error details, patterns)
  - Management (resolve, comment)
```

---

### Phase 2: Pattern Analysis

**Цель**: Проверить естественность формулировок триггеров.

#### 2.1 Универсальный паттерн

**Формула**:
```
[ACTION_VERB] + [DATA_TYPE] + [CONTEXT]

Examples:
- get [projects] from [bugsnag]
- show [error details] in [bugsnag]
- list [organizations] for [bugsnag]
```

**Чеклист**:
- [ ] Определен универсальный паттерн для skill
- [ ] Паттерн документирован в начале description
- [ ] Паттерн покрывает 80%+ реальных запросов

#### 2.2 Глаголы действий

**Обязательные категории**:

| Категория | Примеры EN | Примеры RU |
|-----------|-----------|-----------|
| Viewing | get, show, list, display, view | показать, вывести, список, посмотреть |
| Retrieving | fetch, retrieve, pull, extract | получить, извлечь, достать |
| Checking | check, verify, validate | проверить, проверка |
| Analyzing | analyze, examine, inspect | анализ, проанализировать, изучить |
| Managing | create, update, delete, modify | создать, обновить, удалить, изменить |

**Чеклист**:
- [ ] Минимум 3 глагола для каждой основной функции
- [ ] Включены синонимы (show/display, list/enumerate)
- [ ] Естественные формулировки ("what's in X", "check X")

#### 2.3 Типы данных

**Чеклист**:
- [ ] Все типы данных из функционала перечислены
- [ ] Включены множественное и единственное число (project/projects)
- [ ] Включены аббревиатуры (organization/org/orgs)
- [ ] Включены синонимы (error/issue/problem)

---

### Phase 3: Language Support

**Цель**: Обеспечить мультиязычность (если требуется).

#### 3.1 Английский + Русский

**Чеклист**:
- [ ] Все глаголы имеют русские эквиваленты
- [ ] Все типы данных переведены
- [ ] Контекстные фразы переведены
- [ ] Тестовые примеры на обоих языках

**Паттерны перевода**:
```yaml
EN:
  - "show bugsnag projects"
  - "list available organizations"
  - "what's in bugsnag"

RU:
  - "показать проекты bugsnag"
  - "список доступных организаций"
  - "что в bugsnag"
```

#### 3.2 Смешанные запросы

**Чеклист**:
- [ ] Триггеры работают с mixed language ("показать bugsnag projects")
- [ ] Документированы примеры смешанных запросов

---

### Phase 4: Context Patterns

**Цель**: Включить контекстные и вопросительные запросы.

#### 4.1 Вопросительные формы

**Обязательные паттерны**:
```
- "what [data] in [tool]?"
- "what's happening in [tool]?"
- "how many [items] in [tool]?"
- "что [данные] в [tool]?"
- "что происходит в [tool]?"
```

**Чеклист**:
- [ ] "What" запросы включены
- [ ] "How" запросы включены (если применимо)
- [ ] "Show me" / "покажи" запросы включены
- [ ] "Check" / "проверь" запросы включены

#### 4.2 Неявные триггеры

**Чеклист**:
- [ ] Название tool само по себе - триггер
- [ ] "[tool] status" активирует skill
- [ ] "[tool] info/data/information" активирует skill

---

### Phase 5: Categorization

**Цель**: Структурировать триггеры по категориям для читаемости.

#### 5.1 Рекомендуемые категории

```yaml
description: |
  UNIVERSAL TRIGGER: [общий паттерн]

  Common patterns: [частые формулировки]

  📊 [Category 1]: [Reading/Viewing operations]
  - [examples]

  🔍 [Category 2]: [Detail operations]
  - [examples]

  ✅ [Category 3]: [Management operations]
  - [examples]

  TRIGGERS: [ключевые слова списком]
```

**Чеклист**:
- [ ] Триггеры сгруппированы по логическим категориям
- [ ] Каждая категория имеет emoji для визуальной навигации
- [ ] Примеры конкретные, не абстрактные
- [ ] Секция TRIGGERS содержит flat список всех ключевых слов

---

### Phase 6: Specificity vs Generality

**Цель**: Найти баланс между широким покрытием и избежанием false positives.

#### 6.1 False Positive Prevention

**Должны НЕ активировать skill**:

| Запрос | Почему НЕ активировать |
|--------|------------------------|
| "what is [tool]?" | Общий вопрос о продукте |
| "install [tool]" | Установка, не использование |
| "[tool] vs [competitor]" | Сравнение продуктов |
| "[tool] pricing" | Коммерческий вопрос |
| "how does [tool] work" | Архитектурный вопрос |

**Чеклист**:
- [ ] Документированы негативные примеры
- [ ] Триггеры достаточно специфичны (не просто название tool)
- [ ] Требуется контекст: [action] + [tool], не просто [tool]

#### 6.2 Граничные случаи

**Чеклист**:
- [ ] "[tool]" одно слово → НЕ активирует (слишком общо)
- [ ] "[action] [tool]" → АКТИВИРУЕТ
- [ ] "[action] [data] from [tool]" → АКТИВИРУЕТ
- [ ] "tell me about [tool]" → зависит от контекста (документировать)

---

### Phase 7: Documentation Quality

**Цель**: Обеспечить качество документации триггеров.

#### 7.1 Description Structure

**Обязательные секции**:
```yaml
description: |
  **UNIVERSAL TRIGGER**: [широкий паттерн]

  Common patterns: [естественные формулировки]

  Specific data types supported:
  [категоризированный список с примерами]

  TRIGGERS: [flat список ключевых слов]

  [краткое описание функциональности]
```

**Чеклист**:
- [ ] Начинается с UNIVERSAL TRIGGER (если применимо)
- [ ] Common patterns показывают естественные запросы
- [ ] Категории с emoji для навигации
- [ ] TRIGGERS секция содержит исчерпывающий список
- [ ] Общее описание в конце (1-2 предложения)

#### 7.2 Test Examples

**Обязательный файл**: `TRIGGER_EXAMPLES.md`

**Структура**:
```markdown
# [Skill Name] Trigger Examples

## ✅ Should Activate

### [Category 1]
- [example 1]
- [example 2]

### [Category 2]
- [example 3]

## ❌ Should NOT Activate

- [negative example 1]
- [negative example 2]

## 🎯 Key Trigger Words

[comprehensive list]
```

**Чеклист**:
- [ ] Создан файл TRIGGER_EXAMPLES.md
- [ ] Минимум 20 позитивных примеров
- [ ] Минимум 5 негативных примеров
- [ ] Примеры на всех поддерживаемых языках
- [ ] Примеры покрывают все категории функциональности

---

### Phase 8: Cross-Skill Validation

**Цель**: Избежать конфликтов между skills.

#### 8.1 Overlap Detection

**Процесс**:
1. Составить список всех TRIGGERS из всех skills
2. Найти дублирующиеся ключевые слова
3. Убедиться, что context disambiguation присутствует

**Чеклист**:
- [ ] Нет 100% совпадения TRIGGERS с другими skills
- [ ] Если есть overlap, описание различает контекст
- [ ] Документированы сценарии, когда оба skills могут активироваться

**Пример правильного overlap**:
```yaml
# Skill A: bugsnag
TRIGGERS: bugsnag, errors, error tracking, production errors

# Skill B: error-analysis
TRIGGERS: errors, error patterns, log analysis, error debugging

# ✅ Disambiguation по контексту:
"bugsnag errors" → Skill A (explicit tool name)
"analyze error patterns in logs" → Skill B (log context)
"production errors in bugsnag" → Skill A (tool context)
```

---

### Phase 9: Performance Considerations

**Цель**: Оптимизация для скорости активации.

#### 9.1 Trigger Keyword Count

**Рекомендации**:
- ✅ Оптимально: 15-30 ключевых слов в TRIGGERS
- ⚠️ Приемлемо: 30-50 ключевых слов
- ❌ Избыточно: >50 ключевых слов (дробление на примеры)

**Чеклист**:
- [ ] TRIGGERS секция содержит 15-50 ключевых слов
- [ ] Детальные примеры вынесены в body description
- [ ] Длинные фразы в examples, короткие слова в TRIGGERS

#### 9.2 Description Length

**Рекомендации**:
- ✅ Оптимально: 300-800 символов (без examples)
- ⚠️ Приемлемо: 800-1200 символов
- ❌ Избыточно: >1200 символов

**Чеклист**:
- [ ] Description читается за 30 секунд
- [ ] Структура скан-friendly (категории, bullet points)
- [ ] Примеры конкретные, не verbose

---

## 🧪 Testing Protocol

### Automated Testing

**Создайте тестовый скрипт**:

```bash
#!/bin/bash
# test_skill_triggers.sh

SKILL_NAME="bugsnag"
SKILL_FILE="skills/$SKILL_NAME/SKILL.md"

echo "Testing triggers for: $SKILL_NAME"
echo "=================================="

# Extract TRIGGERS section
TRIGGERS=$(sed -n '/^  TRIGGERS:/,/^$/p' "$SKILL_FILE" | tail -n +2)

# Count keywords
KEYWORD_COUNT=$(echo "$TRIGGERS" | tr ',' '\n' | wc -l)
echo "Keyword count: $KEYWORD_COUNT"

if [ "$KEYWORD_COUNT" -lt 15 ]; then
  echo "❌ FAIL: Too few trigger keywords (min: 15)"
elif [ "$KEYWORD_COUNT" -gt 50 ]; then
  echo "⚠️  WARN: Many trigger keywords (>50), consider simplification"
else
  echo "✅ PASS: Keyword count optimal"
fi

# Check for UNIVERSAL TRIGGER
if grep -q "UNIVERSAL TRIGGER" "$SKILL_FILE"; then
  echo "✅ PASS: Universal trigger defined"
else
  echo "❌ FAIL: No universal trigger pattern"
fi

# Check for multilingual support (EN + RU)
if grep -qE "[а-яА-Я]+" "$SKILL_FILE"; then
  echo "✅ PASS: Multilingual support detected"
else
  echo "⚠️  WARN: Consider adding Russian triggers"
fi

# Check for TRIGGER_EXAMPLES.md
if [ -f "skills/$SKILL_NAME/TRIGGER_EXAMPLES.md" ]; then
  echo "✅ PASS: Test examples documented"
else
  echo "❌ FAIL: Missing TRIGGER_EXAMPLES.md"
fi

echo ""
echo "Review complete!"
```

### Manual Testing

**Process**:
1. Выберите 5 random примеров из TRIGGER_EXAMPLES.md
2. Введите каждый в новой сессии Claude Code
3. Проверьте: активировался ли нужный skill?
4. Документируйте failures для исправления

**Test Log Template**:
```
Skill: _______
Date: _______

Test 1: "example query here"
Result: [ ] PASS [ ] FAIL
Notes: ___________

Test 2: ...
```

---

## 📊 Scoring System

### Quantitative Metrics

```yaml
Coverage Score (0-30 points):
  - All functions have triggers: 15 pts
  - Synonyms for each function: 10 pts
  - Context patterns included: 5 pts

Quality Score (0-30 points):
  - Universal pattern defined: 10 pts
  - Natural formulations: 10 pts
  - Multilingual support: 5 pts
  - Negative examples: 5 pts

Documentation Score (0-20 points):
  - Structured description: 10 pts
  - TRIGGER_EXAMPLES.md exists: 5 pts
  - 20+ test examples: 5 pts

Specificity Score (0-20 points):
  - No false positives: 10 pts
  - Context disambiguation: 5 pts
  - No cross-skill conflicts: 5 pts

Total: ___/100 points
```

### Rating Bands

- **90-100**: Excellent - production ready
- **75-89**: Good - minor improvements needed
- **60-74**: Acceptable - needs refinement
- **<60**: Poor - major rework required

---

## 🎯 Action Items Template

После review создайте action items:

```markdown
# Skill Trigger Improvements: [Skill Name]

Date: _______
Reviewer: _______
Score: ___/100

## High Priority (блокеры)
- [ ] Issue 1: Description
- [ ] Issue 2: Description

## Medium Priority (улучшения)
- [ ] Issue 3: Description
- [ ] Issue 4: Description

## Low Priority (опционально)
- [ ] Issue 5: Description

## Timeline
- High priority: [date]
- Medium priority: [date]
- Low priority: [date]
```

---

## 📚 Best Practices Summary

### ✅ DO:
1. Start with UNIVERSAL TRIGGER pattern
2. Include 3+ action verbs per function
3. Categorize by data types
4. Add multilingual support (EN + RU minimum)
5. Document negative examples
6. Create TRIGGER_EXAMPLES.md with 20+ examples
7. Test manually with real queries
8. Keep description scannable (categories, bullets)
9. Use emoji for visual navigation
10. Include context patterns ("what in", "check")

### ❌ DON'T:
1. List only narrow triggers (e.g., only "errors")
2. Forget synonyms (show = display = list = view)
3. Ignore multilingual users
4. Skip negative examples
5. Make description >1200 chars
6. Use only tool name as trigger ("bugsnag" alone)
7. Overlap 100% with other skills without context
8. Skip testing phase
9. Use abstract examples ("do something")
10. Forget to update after adding new functions

---

## 🔄 Continuous Improvement

### Monthly Review Cycle

```
Week 1: Review all skills with this checklist
Week 2: Implement high-priority improvements
Week 3: Test updated triggers
Week 4: Document learnings, update checklist
```

### Feedback Loop

**Collect data**:
- Which skills rarely activate (low usage)
- False positive reports from users
- New natural formulations from user queries
- Cross-skill activation conflicts

**Iterate**:
- Update TRIGGERS based on real usage
- Add new patterns discovered in practice
- Refine negative examples
- Improve documentation

---

## 📎 Appendix: Templates

### A. Minimal Skill Description Template

```yaml
---
name: tool-name
description: |
  UNIVERSAL TRIGGER: [action verb] + [data type] + from/in [tool]

  Common patterns:
  - "get [data] from [tool]"
  - "show [resource] in [tool]"

  Supported operations:
  📊 [Category 1]: [examples]
  🔍 [Category 2]: [examples]

  TRIGGERS: [tool-name], [key], [words], [here]

  [Brief functionality description]
allowed-tools: [Bash, Read, etc.]
---
```

### B. Comprehensive Skill Description Template

```yaml
---
name: tool-name
description: |
  **UNIVERSAL TRIGGER**: [detailed pattern explanation]

  Common patterns:
  - "[natural formulation 1]"
  - "[natural formulation 2]"
  - "[natural formulation 3]"

  Specific data types supported:

  📊 **[Category 1 Name]**:
  - "[example query 1]"
  - "[example query 2]"

  🔍 **[Category 2 Name]**:
  - "[example query 3]"
  - "[example query 4]"

  ✅ **[Category 3 Name]**:
  - "[example query 5]"

  TRIGGERS: [comprehensive], [comma], [separated], [list],
  [of], [all], [trigger], [keywords], [english], [and],
  [russian], [supported]

  [2-3 sentence functionality description]
allowed-tools: [tool list]
---
```

### C. TRIGGER_EXAMPLES.md Template

```markdown
# [Skill Name] Trigger Examples

Examples of queries that **should** activate [skill-name] skill.

## ✅ Should Activate

### [Category 1]
**English**:
- "query example 1"
- "query example 2"

**Russian**:
- "пример запроса 1"
- "пример запроса 2"

### [Category 2]
- "query example 3"
- "query example 4"

## ❌ Should NOT Activate

- "general question about tool"
- "installation query"
- "comparison query"

## 🎯 Key Trigger Words

### Actions (verbs)
**EN**: [list]
**RU**: [list]

### Data Types (nouns)
**EN**: [list]
**RU**: [list]

### Context
**EN**: [patterns]
**RU**: [patterns]

## 🧪 Testing

Minimum test coverage:
1. [test query 1]
2. [test query 2]
3. [test query 3]
4. [test query 4]
5. [test query 5]
```

---

## End of Checklist

**Version**: 1.0
**Last Updated**: 2025-11-22
**Based on**: Bugsnag skill trigger improvements
**Maintained by**: Claude Code Marketplace Team

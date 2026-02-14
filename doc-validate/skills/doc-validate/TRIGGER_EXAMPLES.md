# Trigger Examples for doc-validate skill

## ✅ Should Activate

###  Formatting & Structure (lint)

**English:**
- "validate docs"
- "doc lint"
- "lint documentation"
- "check doc formatting"
- "check documentation structure"
- "verify markdown files"
- "find formatting issues"
- "naming conventions check"
- "check empty sections"
- "find TODO without issue"

**Russian:**
- "проверь документацию"
- "проверь форматирование"
- "проверить структуру документов"
- "валидация документации"
- "найди проблемы в документации"
- "проверь naming conventions"
- "найди пустые секции"
- "найди TODO без issue"

**Commands:**
- "/doc:lint"
- "/doc:lint --interactive"
- "/doc:lint --batch"

###  Links & Navigation (links)

**English:**
- "find broken links"
- "check dead links"
- "find orphan documents"
- "orphan docs check"
- "dead-end documents"
- "check navigation graph"
- "build doc link graph"
- "check README navigation"
- "generate mermaid graph"

**Russian:**
- "найди битые ссылки"
- "проверь навигацию"
- "найди сиротские документы"
- "проверь граф документации"
- "найди dead-end документы"
- "построй граф связей"

**Commands:**
- "/doc:links"
- "/doc:links --mermaid"

###  Terminology & Glossary (terms)

**English:**
- "check terminology"
- "glossary check"
- "check glossary consistency"
- "find synonyms"
- "forbidden synonyms check"
- "terminology consistency"
- "check term usage"
- "glossary coverage"

**Russian:**
- "проверь терминологию"
- "проверь глоссарий"
- "найди синонимы"
- "проверь консистентность терминов"
- "покрытие глоссария"
- "найди запрещённые синонимы"

**Commands:**
- "/doc:terms"

###  Viewpoints & Artifacts (viewpoints)

**English:**
- "check viewpoints"
- "check modeling standards"
- "BABOK artifacts check"
- "missing state diagrams"
- "threat model check"
- "check artifact coverage"
- "viewpoints coverage"
- "check decision tables"

**Russian:**
- "проверь артефакты"
- "проверь viewpoints"
- "покрытие viewpoints"
- "проверь state diagrams"
- "проверь threat model"
- "проверь моделирование"

**Commands:**
- "/doc:viewpoints"

### ⚡ Contradictions (contradictions)

**English:**
- "find contradictions"
- "find conflicts in docs"
- "conflicting requirements"
- "conflicting values"
- "find parameter conflicts"
- "logical conflicts"
- "check for inconsistencies"

**Russian:**
- "найди противоречия"
- "найди конфликты"
- "конфликтующие требования"
- "проверь на противоречия"
- "найди несоответствия"

**Commands:**
- "/doc:contradictions"

### ️ Gaps & Completeness (gaps)

**English:**
- "find gaps in docs"
- "missing coverage"
- "incomplete documentation"
- "check completeness"
- "missing acceptance criteria"
- "find incomplete sections"
- "missing artifacts"

**Russian:**
- "найди пробелы"
- "проверь полноту"
- "неполная документация"
- "проверь покрытие"
- "отсутствующие критерии"
- "найди недостающее"

**Commands:**
- "/doc:gaps"

###  Full Audit (review)

**English:**
- "full doc review"
- "complete documentation audit"
- "validate all docs"
- "run all doc checks"
- "documentation quality check"
- "doc review with score"

**Russian:**
- "полный аудит документации"
- "проверь всю документацию"
- "полный ревью"
- "оценка качества документации"
- "запусти все проверки"

**Commands:**
- "/doc:review"
- "/doc:review --batch"

###  Interactive & Batch Modes

**English:**
- "lint docs interactively"
- "fix doc issues"
- "doc lint for CI"
- "batch doc check"

**Russian:**
- "проверь документацию интерактивно"
- "исправь проблемы в документации"
- "проверка для CI/CD"

###  Contextual Triggers

**English:**
- "before commit check docs"
- "prepare docs for release"
- "what's wrong with docs?"
- "any issues in documentation?"

**Russian:**
- "проверь доки перед коммитом"
- "подготовь документацию к релизу"
- "что не так с документацией?"
- "какие проблемы в документации?"

---

## ❌ Should NOT Activate

### General Questions (not doc validation)
- "how to write documentation?"
- "what is ADR?"
- "documentation best practices"
- "как писать документацию?"
- "что такое глоссарий?"

### Code Documentation (not project docs)
- "generate code comments"
- "add JSDoc to function"
- "document this API"
- "создай комментарии к коду"

### Other Tools
- "check code formatting"
- "lint JavaScript"
- "run eslint"
- "проверь код"

### Vague Requests
- "check something"
- "validate"
- "проверь"

---

##  Key Trigger Words

### Action Verbs
| English | Russian |
|---------|---------|
| validate | валидировать |
| check | проверить |
| lint | линтить |
| find | найти |
| review | ревью |
| audit | аудит |

### Nouns
| English | Russian |
|---------|---------|
| documentation | документация |
| docs | доки |
| links | ссылки |
| glossary | глоссарий |
| terms | термины |
| viewpoints | viewpoints |
| contradictions | противоречия |
| gaps | пробелы |
| coverage | покрытие |

### Context Patterns
- "X in docs" / "X в документации"
- "doc X" / "проверь документацию на X"
- "/doc:X" (explicit commands)
- "before commit/release" + docs

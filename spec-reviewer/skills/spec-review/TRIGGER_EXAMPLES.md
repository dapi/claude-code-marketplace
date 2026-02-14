# Spec Review — Trigger Examples

## ✅ Should Activate

### Google Doc спецификации
- "проверь спеку docs.google.com/document/d/1abc123"
- "review spec https://docs.google.com/document/d/xxx/edit"
- "ревью этого ТЗ docs.google.com/document/d/xxx"
- "analyze specification in google doc"
- "check this doc for gaps"

### GitHub Issue спецификации
- "проверь спецификацию в issue #42"
- "review spec github.com/owner/repo/issues/123"
- "проанализируй требования в issue"
- "найди гапы в issue #100"
- "check requirements in this issue"

### Локальные файлы
- "проверь спеку в docs/spec.md"
- "review specification in requirements.txt"
- "сделай ревью файла SPEC.md"
- "analyze spec file ./docs/requirements.md"
- "найди противоречия в docs/spec.md"

### Текст спецификации
- "проверь это ТЗ: [большой текст]"
- "найди гапы в этой спеке: [текст]"
- "review this specification: [text]"
- "проанализируй требования: [текст]"

### С флагами глубины
- "/spec-review --quick #42"
- "/spec-review --deep docs.google.com/document/d/xxx"
- "/spec-review --exhaustive #100"
- "/spec-review -q github.com/owner/repo/issues/1"
- "/spec-review --no-ask #42"

### Ключевые слова глубины
- "быстро проверь спеку #42" → --quick
- "тщательно проанализируй ТЗ" → --deep
- "полный аудит спецификации" → --exhaustive
- "глубокий анализ требований" → --deep
- "только критичные проблемы в спеке" → --quick

### Общие паттерны
- "найди нестыковки в спецификации"
- "найди противоречия в ТЗ"
- "check for gaps in requirements"
- "analyze acceptance criteria"
- "review user stories"
- "проверь техническое задание"

### Bilingual (RU)
- "сделай ревью спеки"
- "проверь требования"
- "проанализируй ТЗ на гапы"
- "найди проблемы в спецификации"
- "ревью технического задания"

### Bilingual (EN)
- "review this specification"
- "check spec for inconsistencies"
- "analyze requirements document"
- "find gaps in spec"
- "validate acceptance criteria"

---

## ❌ Should NOT Activate

### Общие вопросы о спецификациях
- "что такое спецификация?"
- "как писать хорошие требования?"
- "what is a good spec?"
- "best practices for requirements"

### Создание спецификаций
- "напиши спецификацию для фичи"
- "create a spec for login"
- "generate requirements document"
- "write user stories"

### Работа с кодом
- "проверь код на соответствие спеке"
- "implement this specification"
- "напиши код по ТЗ"

### Другие ревью
- "review this PR"
- "сделай code review"
- "проверь документацию"

---

##  Key Trigger Words

### Verbs (действия)
- **RU**: проверь, проанализируй, найди, ревью, сделай ревью
- **EN**: review, check, analyze, find, validate

### Nouns (объекты)
- **RU**: спецификация, спека, ТЗ, требования, техническое задание
- **EN**: spec, specification, requirements, acceptance criteria

### Targets (проблемы)
- **RU**: гапы, нестыковки, противоречия, проблемы
- **EN**: gaps, inconsistencies, contradictions, issues

### Sources (источники)
- Google Doc: `docs.google.com/document/d/`
- GitHub Issue: `github.com/.../issues/`, `#123`, `issue #`
- Files: `.md`, `.txt`, `docs/`, `spec`

### Depth flags (глубина)
- `--quick`, `-q`, "быстро", "только блокеры"
- `--deep`, `-d`, "тщательно", "глубоко", "детально"
- `--exhaustive`, `-e`, "полный аудит", "исчерпывающий"
- `--no-ask` — skip depth selection prompt

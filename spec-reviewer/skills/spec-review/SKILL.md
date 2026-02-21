---
name: spec-review-router
description: |
  **UNIVERSAL TRIGGER**: Ревью спецификаций и ТЗ на гапы, нестыковки и противоречия.

  Используй когда:
  - "get/show/list/display spec issues", "retrieve spec analysis"
  - "check/analyze/fetch spec review", "review spec"
  - "проверь спецификацию/ТЗ", "ревью спеки", "проанализируй ТЗ"
  - "найди гапы в требованиях", "найди нестыковки/противоречия"
  - пользователь дал ссылку на Google Doc или GitHub issue со спецификацией
  - пользователь вставил текст спецификации и просит проверить

  ️ **Уровни глубины**:
  - `--quick` / `-q` — только критические блокеры (быстро)
  - `--standard` / `-s` — критические + высокие (по умолчанию)
  - `--deep` / `-d` — все проблемы включая средние
  - `--exhaustive` / `-e` — полный аудит с рекомендациями
  - `--no-ask` — использовать standard без вопроса (для CI/CD)

  ⚡ **Ключевые слова для уровней**:
  - "быстро проверь", "только блокеры" → quick
  - "тщательно", "подробно", "глубоко" → deep
  - "полный аудит", "исчерпывающий" → exhaustive

   **Google Doc**:
  - "проверь спеку docs.google.com/document/d/XXX"
  - "ревью этого ТЗ [ссылка на Google Doc]"

   **GitHub Issue** (ТОЛЬКО с ревью-контекстом!):
  - "проанализируй issue #123" (ревью-слово: "проанализируй")
  - "проверь спецификацию github.com/.../issues/456" (ревью-слово: "проверь")
  - голый "issue #123" без ревью-контекста -- НЕ триггер (github-issues или task-routing)

   **Текст в сообщении**:
  - "проверь это ТЗ: [текст спецификации]"
  - пользователь вставил большой текст и просит ревью

   **Локальный файл**:
  - "проверь спеку в docs/spec.md"
  - "сделай ревью файла requirements.txt"

  TRIGGERS: спецификация, ТЗ, spec, specification, requirements,
  проверь спеку, ревью спеки, review spec, analyze spec,
  найди гапы, найди противоречия, найди нестыковки,
  docs.google.com/document, github.com/issues,
  техническое задание, требования, acceptance criteria,
  проанализируй требования, check requirements,
  --quick, -q, --deep, -d, --exhaustive, -e, --no-ask,
  быстро проверь, тщательно проанализируй, полный аудит,
  только блокеры, глубокий анализ, исчерпывающий
tools: Skill
---

# Spec Review Skill

Автоактивируемый роутер для ревью спецификаций.
Определяет источник и уровень глубины, затем вызывает команду `/spec-review`.

## Логика определения уровня глубины (NEW in 1.9.0)

### Шаг 1: Проверить явные флаги в сообщении

```python
flags_map = {
    "--quick": "--quick", "-q": "--quick",
    "--standard": "--standard", "-s": "--standard",
    "--deep": "--deep", "-d": "--deep",
    "--exhaustive": "--exhaustive", "-e": "--exhaustive",
    "--no-ask": "--no-ask"
}

depth_flag = None
extra_flags = []

for flag in flags_map:
    if flag in user_message:
        if flag == "--no-ask":
            extra_flags.append("--no-ask")
        else:
            depth_flag = flags_map[flag]

# Если флаг найден — добавить в args
```

### Шаг 2: Проверить ключевые слова (если нет флага)

```python
if not depth_flag:
    keywords_quick = ["быстро", "только критичное", "только блокеры"]
    keywords_deep = ["тщательно", "подробно", "глубоко", "глубокий анализ", "детально"]
    keywords_exhaustive = ["полный аудит", "исчерпывающий", "всё проверить", "проверить всё"]

    if any(kw in user_message.lower() for kw in keywords_exhaustive):
        depth_flag = "--exhaustive"
    elif any(kw in user_message.lower() for kw in keywords_deep):
        depth_flag = "--deep"
    elif any(kw in user_message.lower() for kw in keywords_quick):
        depth_flag = "--quick"
```

### Шаг 3: Формировать args с флагом

```python
# Если флаг определён — добавить его перед источником
args = ""
if depth_flag:
    args += depth_flag + " "
if extra_flags:
    args += " ".join(extra_flags) + " "
args += source  # URL, #number, или path
```

## Логика определения источника

### 1. Google Doc

**Паттерн:** `docs.google.com/document/d/{DOCUMENT_ID}`

```
Если в сообщении есть ссылка на Google Doc:
→ Извлечь DOCUMENT_ID
→ Вызвать: Skill tool → skill: "spec-review", args: "{URL}"
```

### 2. GitHub Issue

**Паттерны:**
- `github.com/{owner}/{repo}/issues/{number}`
- `#123` (в контексте репозитория)
- `issue #123`

**ВАЖНО:** Активируй на issue #NNN ТОЛЬКО при наличии ревью-контекста:
- Слова: "проверь", "ревью", "review", "analyze", "проанализируй", "найди гапы", "нестыковки", "spec", "спеку", "ТЗ"
- Без ревью-контекста issue #NNN обрабатывается github-issues (чтение) или task-routing (реализация)

```
Если в сообщении есть ссылка/номер GitHub issue С РЕВЬЮ-КОНТЕКСТОМ:
→ Вызвать: Skill tool → skill: "spec-review", args: "{URL или #number}"
```

### 3. Текст спецификации

**Признаки:**
- Большой блок текста (>500 символов)
- Содержит ключевые слова: "требования", "функционал", "user story", "acceptance criteria"
- Пользователь явно просит проверить этот текст

```
Если пользователь вставил текст спецификации:
→ Сохранить текст во временный файл или передать напрямую
→ Вызвать: Skill tool → skill: "spec-review", args: ""
→ В следующем сообщении передать текст спецификации
```

### 4. Локальный файл

**Паттерны:**
- Путь к файлу: `docs/spec.md`, `./requirements.txt`
- "файл X", "в файле X"

```
Если указан путь к файлу:
→ Вызвать: Skill tool → skill: "spec-review", args: "{path}"
```

## Примеры активации

### Пример 1: Google Doc (без флага — будет AskUserQuestion)
```
User: Проверь спеку https://docs.google.com/document/d/1abc123/edit
Assistant: [Вызывает Skill tool: spec-review с args: "https://docs.google.com/document/d/1abc123/edit"]
```

### Пример 2: GitHub Issue с флагом глубины
```
User: Сделай быстрое ревью issue #42
Assistant: [Вызывает Skill tool: spec-review с args: "--quick #42"]
```

### Пример 3: Явный флаг
```
User: /spec-review --deep https://github.com/owner/repo/issues/123
Assistant: [Вызывает Skill tool: spec-review с args: "--deep https://github.com/owner/repo/issues/123"]
```

### Пример 4: Ключевое слово в промпте
```
User: Тщательно проанализируй спеку в docs/spec.md
Assistant: [Вызывает Skill tool: spec-review с args: "--deep docs/spec.md"]
```

### Пример 5: Флаг --no-ask для CI/CD
```
User: /spec-review --no-ask #42
Assistant: [Вызывает Skill tool: spec-review с args: "--no-ask #42"]
```

### Пример 6: Полный аудит
```
User: Сделай полный аудит этой спецификации https://docs.google.com/document/d/xxx
Assistant: [Вызывает Skill tool: spec-review с args: "--exhaustive https://docs.google.com/document/d/xxx"]
```

### Пример 7: Текст спецификации
```
User: Проверь это ТЗ:
## Функционал
1. Пользователь может регистрироваться
2. Пользователь может логиниться
...
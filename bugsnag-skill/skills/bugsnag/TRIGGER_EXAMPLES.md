# Bugsnag Skill Trigger Examples

Примеры запросов, которые **должны активировать** bugsnag skill.

## ✅ Универсальные паттерны (ДОЛЖНЫ СРАБОТАТЬ)

### Английский
- "get data from bugsnag"
- "show me bugsnag information"
- "list bugsnag resources"
- "retrieve bugsnag data"
- "display bugsnag status"
- "what's in bugsnag"
- "check bugsnag"
- "fetch bugsnag info"

### Русский
- "получить данные из bugsnag"
- "показать информацию bugsnag"
- "вывести список bugsnag"
- "что в bugsnag"
- "проверить bugsnag"
- "данные из bugsnag"

---

## ✅ Организации и проекты (ДОЛЖНЫ СРАБОТАТЬ)

### Организации
- "list bugsnag organizations"
- "show bugsnag orgs"
- "get organizations from bugsnag"
- "список организаций bugsnag"
- "организации в bugsnag"
- "показать организации bugsnag"

### Проекты
- "list bugsnag projects"
- "show available projects in bugsnag"
- "get bugsnag projects"
- "выведи список доступных проектов в bugsnag" ← **твой исходный запрос**
- "список проектов bugsnag"
- "проекты в bugsnag"
- "показать проекты bugsnag"

---

## ✅ Ошибки - просмотр (ДОЛЖНЫ СРАБОТАТЬ)

### Общий список
- "show bugsnag errors"
- "list errors from bugsnag"
- "what errors in bugsnag"
- "показать ошибки bugsnag"
- "список ошибок bugsnag"
- "что в bugsnag"
- "ошибки в bugsnag"

### Открытые ошибки
- "show open bugsnag errors"
- "list open errors"
- "открытые ошибки bugsnag"
- "показать открытые ошибки"

### С фильтрацией
- "show errors with severity error"
- "list bugsnag warnings"
- "filter bugsnag errors by severity"

---

## ✅ Детали ошибки (ДОЛЖНЫ СРАБОТАТЬ)

### Детальная информация
- "bugsnag details for ERROR_123"
- "show error details ERROR_123"
- "get error information ERROR_123"
- "детали ошибки ERROR_123"
- "показать детали ошибки ERROR_123"

### Stack trace
- "show stack trace for error ERROR_123"
- "error context ERROR_123"
- "what happened in error ERROR_123"
- "stack trace ошибки ERROR_123"

### События
- "show events for error ERROR_123"
- "error timeline ERROR_123"
- "события ошибки ERROR_123"
- "timeline для ошибки ERROR_123"

---

## ✅ Комментарии (ДОЛЖНЫ СРАБОТАТЬ)

- "show comments for error ERROR_123"
- "list bugsnag comments ERROR_123"
- "error discussion ERROR_123"
- "комментарии ошибки ERROR_123"
- "показать комментарии ERROR_123"
- "что говорят об ошибке ERROR_123"

---

## ✅ Анализ и статистика (ДОЛЖНЫ СРАБОТАТЬ)

- "analyze bugsnag errors"
- "show error patterns in bugsnag"
- "bugsnag statistics"
- "error trends in bugsnag"
- "what's happening in bugsnag"
- "анализ ошибок bugsnag"
- "паттерны ошибок в bugsnag"
- "статистика bugsnag"
- "что происходит в bugsnag"

---

## ✅ Управление (ДОЛЖНЫ СРАБОТАТЬ)

### Пометка как исправлено (fix/resolve/close - синонимы)
- "mark bugsnag error ERROR_123 as fixed"
- "fix error ERROR_123"
- "resolve error ERROR_123"
- "close bugsnag error ERROR_123"
- "отметить ошибку ERROR_123 как решенную"
- "закрыть ошибку ERROR_123"
- "исправить ошибку ERROR_123"
- NOTE: Fix, Resolve, Close - всё это одна операция в Bugsnag

### Добавление комментария
- "add comment to bugsnag error ERROR_123"
- "comment on error ERROR_123"
- "добавить комментарий к ошибке ERROR_123"

---

## ❌ НЕ должны активировать (другие контексты)

- "create a bug tracking system" (создание системы, не использование bugsnag)
- "what is bugsnag" (общий вопрос, не запрос данных)
- "install bugsnag" (установка, не получение данных)
- "bugsnag pricing" (коммерческий вопрос)
- "compare bugsnag with sentry" (сравнение продуктов)

---

##  Ключевые триггерные слова

### Действия (verbs)
**EN**: get, show, list, display, retrieve, fetch, check, analyze, view
**RU**: получить, показать, вывести, список, проверить, анализ, посмотреть

### Типы данных (nouns)
**EN**: organizations, orgs, projects, errors, details, events, comments, analysis, patterns, trends, statistics
**RU**: организации, проекты, ошибки, детали, события, комментарии, анализ, паттерны, статистика

### Контекст
**EN**: from bugsnag, in bugsnag, bugsnag [noun]
**RU**: из bugsnag, в bugsnag, bugsnag [существительное]

---

##  Тестирование

Для проверки активации skill попробуйте:

1. **Минимальный запрос**: "check bugsnag"
2. **Специфичный**: "list bugsnag projects"
3. **Русский**: "что в bugsnag"
4. **С ID**: "details for error 12345"
5. **Аналитический**: "analyze error patterns in bugsnag"

Каждый из этих запросов **должен активировать** bugsnag skill автоматически.

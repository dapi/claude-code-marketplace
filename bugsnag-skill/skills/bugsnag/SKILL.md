---
name: bugsnag
description: |
  **UNIVERSAL TRIGGER**: Use when user wants to GET/FETCH/RETRIEVE any data FROM Bugsnag.

  Common patterns:
  - "get/show/list/display [something] from bugsnag"
  - "получить/показать/вывести [что-то] из bugsnag"
  - "bugsnag [organizations/projects/errors/details/events/comments/stats]"
  - "what [data] in bugsnag", "check bugsnag [resource]"

  Specific data types supported:

   **Organizations & Projects**:
  - "list bugsnag organizations/orgs", "show organizations"
  - "list bugsnag projects", "available projects", "проекты bugsnag"

   **Errors (viewing)**:
  - "show/list bugsnag errors", "что в bugsnag", "check bugsnag"
  - "open errors", "error list", "ошибки bugsnag", "открытые ошибки"
  - "errors with severity error/warning", "filter bugsnag errors"

   **Error Details**:
  - "bugsnag details for <id>", "error details", "детали ошибки"
  - "show stack trace", "error context", "what happened in error"
  - "events for error", "error timeline", "события ошибки"

   **Comments**:
  - "show comments for error", "error comments", "комментарии ошибки"
  - "bugsnag discussion", "what comments on error"

   **Analysis**:
  - "analyze bugsnag errors", "error patterns", "анализ ошибок"
  - "bugsnag statistics", "error trends", "что происходит в bugsnag"

  ✅ **Management** (write operations):
  - "mark as fixed/resolved", "fix error", "resolve error", "close error"
  - "закрыть ошибку", "отметить как решенную", "исправить ошибку"
  - "add comment to error", "comment on bugsnag error"
  - NOTE: Fix/Resolve/Close are synonyms - all mark error as resolved in Bugsnag

  TRIGGERS: bugsnag, получить из bugsnag, показать bugsnag, список bugsnag,
  bugsnag data, bugsnag info, check bugsnag, what in bugsnag, bugsnag status,
  error tracking, error monitoring, production errors, stack trace,
  bugsnag organizations, bugsnag projects, bugsnag errors, bugsnag details,
  bugsnag events, bugsnag comments, bugsnag analysis, ошибки в bugsnag,
  что в bugsnag, проверить bugsnag, данные bugsnag, fix error, resolve error,
  close error, закрыть ошибку, исправить ошибку, отметить как решенную

  This skill provides complete Bugsnag API integration for viewing and managing
  error tracking data via Ruby helper scripts.
allowed-tools: Bash, Read
---

Skill для интеграции с Bugsnag API, позволяющий просматривать и управлять ошибками в проекте.

**⚠️ PATH RESOLUTION**: Этот skill использует Ruby скрипты из своей директории.
НИКОГДА не вызывай `./bugsnag.rb` из текущей рабочей директории пользователя.

**ПРАВИЛЬНО**: `find ~ -name "bugsnag.rb" -type f | head -1 | xargs dirname` → получим путь к skill
**НЕПРАВИЛЬНО**: `./bugsnag.rb` из текущей директории → ошибка "no such file or directory"

**ВАЖНО:** Используй ТОЛЬКО команды, описанные в этом файле. НЕ анализируй код bugsnag.rb - следуй документации ниже.

Вызывает скрипт ./bugsnag.rb находающийся в каталого этого skill с целью выполнить пользовательский запрос.

## Path Resolution для Claude

**КРИТИЧЕСКИ ВАЖНО**: При выполнении команд НЕ ИСПОЛЬЗУЙ `./bugsnag.rb` из текущей директории пользователя.
Всегда определяй директорию где находится skill и выполняй скрипт оттуда.

### Проблема
Когда пользователь говорит "покажи ошибки из bugsnag", выполнение `./bugsnag.rb` из текущей директории не работает.

### Решение
1. Определи директорию skill
2. Перейди в неё
3. Выполни скрипт

**Команда для Claude**: Используй `bash -c "cd [path_to_skill] && ./bugsnag.rb [args]"`

Где `[path_to_skill]` - это путь к директории skill. Определи его с помощью:
1. `find ~/.claude -name "bugsnag.rb" -type f` (если установлен)
2. или используй `pwd` если ты уже в директории skill
3. или попробуй стандартные пути установки плагинов

## Возможности

-  **Управление организациями** - Просмотр списка доступных организаций в Bugsnag
-  **Управление проектами** - Просмотр списка доступных проектов
-  **Просмотр текущих ошибок** - Получение списка активных ошибок из Bugsnag
-  **Детальный контекст ошибки** - Просмотр полной информации об ошибке включая stack trace
- ✅ **Управление статусами** - Пометка ошибок как выполненные (resolved)
-  **Безопасная авторизация** - Использование API ключей из переменных окружения

## Команды bugsnag.rb

### Обзор
- `organizations` / `orgs` / `организации` - Список всех организаций
- `projects` / `проекты` - Список всех проектов

### Просмотр ошибок
- `list` / `show` / `показать` - Список всех ошибок
- `open` / `открыть` / `открытые` - Только открытые ошибки
- `list --limit 50` - Показать до 50 ошибок
- `list --severity error` - Только ошибки (без предупреждений)

### Детализация
- `details <error_id>` / `детали <id>` - Полная информация об ошибке
- `events <error_id> [limit]` / `события <id> [лимит]` - Показать события ошибки

### Управление
- `resolve <error_id>` / `отметить <id>` - Отметить как выполненную

### Анализ
- `analyze` / `анализ` - Анализ паттернов ошибок

### Справка
- `help` / `помощь` / `h` - Показать справку

## ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ

**FOR CLAUDE**: Используй `bash -c "cd [skill_directory] && ./bugsnag.rb [command]"`

```bash
# Показать организации
bash -c "cd [skill_dir] && ./bugsnag.rb organizations"

# Показать проекты
bash -c "cd [skill_dir] && ./bugsnag.rb projects"

# Показать открытые ошибки
bash -c "cd [skill_dir] && ./bugsnag.rb open --limit 20"

# Показать все ошибки (лимит 50)
bash -c "cd [skill_dir] && ./bugsnag.rb list --limit 50"

# Детали конкретной ошибки
bash -c "cd [skill_dir] && ./bugsnag.rb details ERROR_ID"

# Показать справку
bash -c "cd [skill_dir] && ./bugsnag.rb help"
```

**Примечание**: `[skill_dir]` - это путь к директории где установлен skill bugsnag.

## ЗАПРЕЩЕННЫЕ КОМАНДЫ

❌ `list-errors` - такой команды НЕ существует
❌ `--help` - используется `help` без дефисов
�️ Использовать команды не описанные выше

## Переменные окружения

```bash
# Обязательные
export BUGSNAG_DATA_API_KEY="your_api_key_here"
export BUGSNAG_PROJECT_ID="your_project_id_here"

# Опциональные
export BUGSNAG_HTTP_PROXY="http://proxy.example.com:8080"  # HTTP прокси для всех запросов
```

## Безопасность

- API ключи хранятся только в переменных окружения
- Все запросы выполняются через HTTPS (или через прокси при наличии BUGSNAG_HTTP_PROXY)
- Минимальные необходимые права доступа к API
- Логирование чувствительных данных отключено

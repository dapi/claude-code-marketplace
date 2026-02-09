# Bugsnag Skill Plugin

Plugin для интеграции с Bugsnag API - просмотр и управление ошибками в проектах.

## Возможности

- **Управление организациями** - Просмотр списка доступных организаций
- **Управление проектами** - Просмотр списка проектов
- **Просмотр ошибок** - Получение списка активных ошибок
- **Детальный контекст** - Полная информация об ошибке включая stack trace
- **Управление статусами** - Пометка ошибок как resolved
- **Анализ паттернов** - Автоматический анализ повторяющихся ошибок

## Установка

```bash
/plugin install bugsnag-skill@dapi
```

## Настройка

### Получение API ключа

1. Перейдите в [Bugsnag Dashboard](https://app.bugsnag.com)
2. Настройки → Organization → API Authentication
3. Создайте Personal Access Token
4. Получите ID проекта из настроек проекта

### Переменные окружения

```bash
export BUGSNAG_DATA_API_KEY="your_api_key_here"
export BUGSNAG_PROJECT_ID="your_project_id_here"

# Опционально
export BUGSNAG_HTTP_PROXY="http://proxy.example.com:8080"
```

## Использование

### Естественный язык

```
"показать bugsnag ошибки"
"bugsnag открытые ошибки"
"bugsnag детали для error_123"
"список проектов bugsnag"
"проанализируй bugsnag ошибки"
```

### Команды скрипта

```bash
./bugsnag.rb organizations   # Список организаций
./bugsnag.rb projects        # Список проектов
./bugsnag.rb list            # Список всех ошибок
./bugsnag.rb open            # Только открытые ошибки
./bugsnag.rb details ERROR_ID # Детали ошибки
./bugsnag.rb analyze         # Анализ паттернов
```

## Подробная документация

См. [skills/bugsnag/SKILL.md](./skills/bugsnag/SKILL.md)

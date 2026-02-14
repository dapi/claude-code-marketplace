# bugsnag-skill

Интеграция с Bugsnag API для Claude Code — просмотр и управление ошибками, организациями, проектами.

## Установка

```bash
/plugin install bugsnag-skill@dapi
```

## Компоненты

### Навык: bugsnag

Активируется автоматически при запросе данных из Bugsnag: ошибки, проекты, организации.

## Использование

```
"показать bugsnag ошибки"
"bugsnag детали для error_123"
"список проектов bugsnag"
"show bugsnag errors"
"analyze bugsnag errors"
```

### CLI команды

```bash
./bugsnag.rb organizations   # Список организаций
./bugsnag.rb projects        # Список проектов
./bugsnag.rb list            # Список всех ошибок
./bugsnag.rb open            # Только открытые ошибки
./bugsnag.rb details ERROR_ID # Детали ошибки
./bugsnag.rb analyze         # Анализ паттернов
```

## Настройка

### API ключ

1. Перейдите в [Bugsnag Dashboard](https://app.bugsnag.com)
2. Settings → Organization → API Authentication
3. Создайте Personal Access Token
4. Получите ID проекта из настроек проекта

### Переменные окружения

```bash
export BUGSNAG_DATA_API_KEY="your_api_key_here"
export BUGSNAG_PROJECT_ID="your_project_id_here"

# Опционально
export BUGSNAG_HTTP_PROXY="http://proxy.example.com:8080"
```

## Документация

См. [skills/bugsnag/SKILL.md](./skills/bugsnag/SKILL.md)

## Лицензия

MIT

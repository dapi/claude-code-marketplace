# requirements

Реестр требований проекта через Google Spreadsheet с синхронизацией GitHub issues.

## Установка

```bash
/plugin install requirements@dapi
```

## Компоненты

### Команда: /requirements

Управление требованиями проекта с подкомандами.

```
/requirements init          # Создать таблицу из шаблона
/requirements status        # Статус требований
/requirements sync          # Синхронизация с GitHub issues
/requirements add <title>   # Добавить требование
/requirements update <ID> <col> <val>  # Обновить поле
```

## Использование

```
/requirements status
/requirements sync
/requirements add "Аутентификация пользователей"
```

## Требования

- Google Workspace MCP
- [gh CLI](https://cli.github.com)

## Документация

См. [commands/requirements.md](./commands/requirements.md)

## Лицензия

MIT

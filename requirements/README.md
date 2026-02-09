# Requirements Plugin

Управление реестром требований проекта через Google Spreadsheet с синхронизацией GitHub issues.

## Установка

```bash
/plugin install requirements@dapi
```

## Использование

```bash
/requirements init          # Создать таблицу из шаблона
/requirements status        # Статус требований
/requirements sync          # Синхронизация с GitHub issues
/requirements add <title>   # Добавить требование
/requirements update <ID> <col> <val>  # Обновить поле
```

## Требования

- Google Workspace MCP
- GitHub CLI (`gh`)

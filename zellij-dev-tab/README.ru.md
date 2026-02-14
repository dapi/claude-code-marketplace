# zellij-dev-tab

Запуск разработки GitHub issue в отдельной вкладке Zellij.

## Установка

```bash
/plugin install zellij-dev-tab@dapi
```

## Компоненты

### Навык: zellij-dev-tab

Создаёт новую вкладку Zellij с именем `#ISSUE_NUMBER` и запускает `start-issue` внутри неё.

## Использование

```
"запусти разработку issue #45 в новой вкладке"
"открой issue в новой вкладке"
"start issue #45 in new tab"
"launch issue 123 in separate tab"
```

Поддерживаемые форматы: `45`, `#45`, `https://github.com/owner/repo/issues/45`

## Требования

- [Zellij](https://zellij.dev) терминальный мультиплексор
- Скрипт `start-issue` в PATH (см. `scripts/start-issue`)

## Документация

См. [skills/zellij-dev-tab/SKILL.md](./skills/zellij-dev-tab/SKILL.md)

## Лицензия

MIT

---
description: "Работа с Telegram через tgcli CLI. Чтение, поиск, отправка, файлы, форумы, архив. Примеры: /tgcli read -1002907861552, /tgcli search ИИшница Claude"
---

# tgcli — Telegram CLI для AI-агентов

CLI-инструмент (`@kfastov/tgcli` v2.0.8) для чтения, поиска и анализа Telegram. Вызов через Bash.

## Когда использовать tgcli vs telegram-mcp

| Задача | Инструмент |
|-|-|
| Прочитать/поиск по истории | **tgcli** — FTS, regex, архив, чистый JSON |
| Отправить текст/файл | **tgcli** — проще, с `--json` и `--timeout` |
| Отправить в тему форума | **tgcli** — нативный `--topic` |
| Reply/edit/delete/forward | **telegram-mcp** — tgcli не поддерживает |
| Inline buttons (боты) | **telegram-mcp** — tgcli не поддерживает |
| Реакции | **telegram-mcp** — tgcli не поддерживает |
| Админ-операции | **telegram-mcp** — tgcli не поддерживает |

## Глобальные флаги

ВСЕГДА добавлять к каждой команде:
- `--json` — машиночитаемый вывод (включая ошибки: `{"ok":false,"error":"..."}`)
- `--timeout 30s` — защита от зависания (рекомендуется для автоматизации)

## Аргументы

Формат: `/tgcli <action> [chat] [параметры]`

- `read <chat> [limit]` — прочитать последние сообщения
- `search <chat> <запрос>` — полнотекстовый поиск
- `send <chat> <текст>` — отправить сообщение
- `analyze <chat> [задание]` — анализ истории чата (sync + read + LLM)
- `info <chat>` — информация о канале/группе
- `topics <chat>` — список тем форума
- `channels [запрос]` — поиск каналов/групп
- Без аргументов — показать справку по командам

## Команды: Чтение сообщений

### Последние сообщения канала

```bash
tgcli messages list --chat <id|@username> --limit 20 --json --timeout 30s
```

Опции:
- `--topic <id>` — фильтр по теме форума
- `--source archive|live|both` — источник данных (default: live)
- `--after <ISO>` / `--before <ISO>` — фильтр по дате

### Конкретное сообщение

```bash
tgcli messages show --chat <id> --id <msgId> --json --timeout 30s
```

### Контекст вокруг сообщения

```bash
tgcli messages context --chat <id> --id <msgId> --before 5 --after 5 --json --timeout 30s
```

## Команды: Поиск

### Полнотекстовый поиск (FTS)

```bash
tgcli messages search --query "Claude Code" --chat <id> --json --timeout 30s
```

### Regex-поиск (уникальная фича)

```bash
tgcli messages search --regex "claude\s+(code|agent)" --chat <id> --json --timeout 30s
```

### Расширенный поиск

```bash
tgcli messages search --query "..." --chat <id> --after 2026-01-01 --before 2026-02-01 --source archive --limit 50 --json --timeout 30s
```

Дополнительные фильтры: `--tag <tag>`, `--tags <a,b>`, `--case-sensitive`, `--topic <id>`

## Команды: Отправка

### Текст

```bash
tgcli send text --to <id|@username> --message "Привет!" --json --timeout 30s
```

С темой форума:

```bash
tgcli send text --to <id> --topic <topicId> --message "Ответ в тему" --json --timeout 30s
```

### Файл

```bash
tgcli send file --to <id> --file /path/to/file --caption "Описание" --json --timeout 30s
```

Опции: `--filename <name>` — переопределить имя файла, `--topic <id>` — в тему форума.

## Команды: Медиа

### Скачать медиа из сообщения

```bash
tgcli media download --chat <id> --id <msgId> --output /path/to/save --timeout 30s
```

## Команды: Каналы и группы

### Поиск каналов

```bash
tgcli channels list --query "ИИ" --limit 10 --json --timeout 30s
```

### Информация о канале

```bash
tgcli channels show --chat <id|@username> --json --timeout 30s
```

### Список групп

```bash
tgcli groups list --query "..." --limit 10 --json --timeout 30s
```

### Информация о группе

```bash
tgcli groups info --chat <id> --json --timeout 30s
```

## Команды: Форум-топики

### Список тем

```bash
tgcli topics list --chat <id> --json --timeout 30s
```

### Поиск тем

```bash
tgcli topics search --chat <id> --query "..." --json --timeout 30s
```

## Команды: Контакты и CRM

### Поиск контактов

```bash
tgcli contacts search "Иван" --json --timeout 30s
```

### Профиль контакта

```bash
tgcli contacts show --user <id> --json --timeout 30s
```

### Алиасы (локальные дружественные имена)

```bash
tgcli contacts alias set --user <id> --alias "Ваня"
tgcli contacts alias rm --user <id>
```

### Теги контактов

```bash
tgcli contacts tags add --user <id> --tags "коллега,разработчик"
tgcli contacts tags rm --user <id> --tags "разработчик"
```

### Заметки о контакте

```bash
tgcli contacts notes set --user <id> --notes "CTO в компании X"
```

## Команды: Теги каналов

```bash
tgcli tags set --chat <id> --tags "ai,research"
tgcli tags list --json
tgcli tags search --tag "ai" --json
tgcli tags auto --chat <id> --json        # авто-теги на основе контента
```

## Анализ истории чата

Паттерн для "выгрузи историю", "проанализируй чат", "о чём говорили за неделю":

### Шаг 1: Резолвинг чата

Порядок поиска чата по имени:
1. `tgcli channels list --query "имя" --json` — поиск среди подписок
2. `tgcli groups list --query "имя" --json` — поиск среди групп
3. Если передан `@username` или числовой ID — использовать напрямую

### Шаг 2: Включить sync и обеспечить сервис

```bash
# Включить sync для канала и добавить backfill job
tgcli channels sync --chat <id> --enable
tgcli sync jobs add --chat <id> --depth 500

# Обеспечить что systemd-сервис запущен (EAFP: try start, if fails — install + start)
tgcli service start 2>&1 || { tgcli service install 2>&1 && tgcli service start 2>&1; }
```

Сервис в фоне обрабатывает jobs, flood wait, rate limits. НЕ использовать `sync --once` — он зависнет при flood wait.

### Шаг 3: Читать из архива

```bash
# Последние N сообщений
tgcli messages list --chat <id> --source archive --limit 200 --json --timeout 30s

# За конкретный период
tgcli messages list --chat <id> --source archive --after 2026-02-01 --before 2026-02-20 --limit 500 --json --timeout 30s

# Поиск по теме
tgcli messages search --query "Claude" --chat <id> --source archive --json --timeout 30s
```

### Шаг 4: Анализ

Прочитать JSON-ответ и выполнить анализ согласно заданию пользователя:
- Основные темы обсуждений
- Активность участников
- Ключевые ссылки и ресурсы
- Резюме обсуждения конкретной темы
- Тренды и повторяющиеся паттерны

Если сообщений слишком много для контекста — работать по частям (по дням/неделям).

## Команды: Архив и синхронизация

### Включить sync для канала

Перед использованием `--source archive` нужно **включить sync** и **запустить сервис**:

```bash
# Включить sync для канала + добавить backfill job
tgcli channels sync --chat <id> --enable
tgcli sync jobs add --chat <id> --depth 1000

# Обеспечить что сервис запущен (EAFP)
tgcli service start 2>&1 || { tgcli service install 2>&1 && tgcli service start 2>&1; }
```

Сервис сам обработает jobs, flood wait, rate limits в фоне.

### Статус синхронизации

```bash
tgcli sync status --json
tgcli sync jobs list --json
```

### Управление сервисом (systemd user scope)

```bash
# Обеспечить запуск (идемпотентно, EAFP)
tgcli service start 2>&1 || { tgcli service install 2>&1 && tgcli service start 2>&1; }

# Проверить статус
tgcli service status

# Логи
tgcli service logs

# Остановить (только по явному запросу пользователя)
tgcli service stop

# Переустановить (если unit-файл повреждён)
tgcli service stop 2>/dev/null; tgcli service install 2>&1 && tgcli service start 2>&1
```

**Когда запускать сервис:**
- При `channels sync --enable` + `sync jobs add` (всегда)
- При "следи за каналом", "синкай", "выгрузи историю"
- При явном "запусти tgcli сервис"

**Когда останавливать:** только по явному запросу пользователя.

### Fallback при пустом архиве

Если архив ещё не наполнился (сервис только запущен), использовать `--source live`:

```bash
tgcli messages list --chat <id> --source live --limit 500 --json --timeout 90s
```

## JSON Output

Все команды с `--json` возвращают чистый JSON:

**Успех (messages list):**
```json
{
  "source": "live",
  "returned": 2,
  "messages": [
    {
      "channelId": "-1002907861552",
      "messageId": 122,
      "date": "2026-02-20T09:12:14.000Z",
      "fromDisplayName": "Жизнь стартапа в стране ИИ",
      "text": "...",
      "media": null,
      "topicId": null
    }
  ]
}
```

**Успех (channels list):**
```json
[
  {"id": "-1003808194627", "type": "channel", "title": "...", "username": null, "chatType": "supergroup", "isForum": false}
]
```

**Ошибка:**
```json
{"ok": false, "error": "Chat not found"}
```

## Source selection

- `--source live` (default) — свежие данные из Telegram API
- `--source archive` — из локального SQLite (быстро, offline, не тратит rate limits)
- `--source both` — объединение и дедупликация обоих источников

Для `archive` необходимо: 1) включить sync для канала (`channels sync --enable`), 2) запустить sync.

## Архитектура SQLite

Локальная БД `~/.local/share/tgcli/messages.db`:

| Таблица | Назначение |
|-|-|
| channels | Реестр диалогов: ID, название, тип, sync_enabled |
| messages | Архив сообщений |
| message_search | FTS5 виртуальная таблица (автосинхронизация триггерами) |
| message_links | Извлечённые URL из сообщений (индекс по домену) |
| message_media | Метаданные медиафайлов |
| jobs | Очередь backfill-задач |
| topics | Forum topics для супергрупп |
| users / contacts / contact_tags | Контакты с алиасами, заметками, тегами |
| channel_tags / channel_metadata | Теги и метаданные каналов |

## LOCK файл — НИКОГДА не удалять

Если tgcli выдаёт ошибку о заблокированной БД (`LOCK`, `database is locked`, `another instance`):
- **ЗАПРЕЩЕНО** выполнять `rm -f ~/.local/share/tgcli/LOCK` или удалять любые lock-файлы
- Лок означает, что другой процесс tgcli (sync daemon, другой агент) сейчас работает с БД
- **Правильное действие**: подождать 10-30 секунд и повторить команду
- При повторной ошибке — сообщить пользователю, что tgcli занят другим процессом

## Ограничения tgcli

- **Нет reply** — невозможно ответить на конкретное сообщение
- **Нет edit/delete** — невозможно редактировать/удалять сообщения
- **Нет реакций** — невозможно ставить/читать реакции
- **Нет inline buttons** — невозможно взаимодействовать с ботами
- **Нет forward/pin** — невозможно пересылать/закреплять
- **Нет admin ops** — невозможно банить, промоутить, управлять правами
- **Нет Markdown** — отправка только plain text

Для этих операций использовать **telegram-mcp**.

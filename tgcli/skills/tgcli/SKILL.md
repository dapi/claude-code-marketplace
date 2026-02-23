---
name: tgcli-telegram
description: >
  **UNIVERSAL TRIGGER**: Use when user wants to READ/SEND/SEARCH/ANALYZE Telegram messages.

  Common patterns:
  - "read/check/show messages in [channel]", "what's new in [chat]"
  - "search [query] in telegram", "find messages about [topic]"
  - "send message to [channel]", "post to my channel"
  - "analyze/summarize chat history", "what was discussed this week"
  - "прочитай сообщения", "что обсуждали в ИИшнице", "отправь в канал"
  - "выгрузи историю", "проанализируй чат", "найди в телеграме"

  News & events:
  - "какие новости/события в [канале]?", "what happened in [channel]?"
  - "последние важные события", "latest news from [chat]"
  - "что нового в [канале]?", "дайджест [канала]"

  Summaries & digests:
  - "сводка по [каналу]", "дай сводку", "summary of [channel]"
  - "что было с последней сводки?", "since last summary"
  - "о чём говорили за неделю/вчера/сегодня?"

  Mentions & people:
  - "покажи упоминания меня", "show my mentions", "кто меня упоминал?"
  - "найди сообщения от [имя]", "messages from [user]"
  - "что писал [имя] в [канале]?"

  For reply/edit/delete/reactions/inline buttons/admin — use telegram-mcp tools instead.

  TRIGGERS: telegram, tgcli, messages, channel, chat, group, send, search, read,
    analyze, summarize, digest, news, mentions, history, archive, sync, topics,
    contacts, прочитай, найди, отправь, покажи, проанализируй, выгрузи, сводка,
    дайджест, новости, упоминания, телеграм, канал, чат, группа, сообщения
---

# tgcli — Telegram CLI для AI-агентов

CLI-инструмент `tgcli` для чтения, поиска, отправки и анализа Telegram через Bash.
Для полной справки по всем командам использовать `/tgcli`.

## Когда tgcli, когда telegram-mcp

| tgcli | telegram-mcp |
|-|-|
| Чтение, поиск, FTS, regex | Reply, edit, delete, forward |
| Отправка текста/файлов | Inline buttons (боты) |
| Forum topics (`--topic`) | Реакции |
| Локальный SQLite архив | Админ-операции |
| Чистый JSON output | Папки, черновики, privacy |

## Обязательные флаги

ВСЕГДА добавлять: `--json --timeout 30s`

## Быстрые паттерны

### Прочитать последние сообщения

```bash
tgcli messages list --chat <id|@username> --limit 20 --json --timeout 30s
```

### Поиск (FTS + regex)

```bash
tgcli messages search --query "Claude Code" --chat <id> --json --timeout 30s
tgcli messages search --regex "claude\s+(code|agent)" --chat <id> --json --timeout 30s
```

### Отправить сообщение

```bash
tgcli send text --to <id> --message "Текст" --json --timeout 30s
tgcli send text --to <id> --topic <topicId> --message "В тему" --json --timeout 30s
```

### Отправить файл

```bash
tgcli send file --to <id> --file /path/to/file --caption "Описание" --json --timeout 30s
```

### Найти канал/группу

```bash
tgcli channels list --query "ИИ" --json --timeout 30s
tgcli groups list --query "..." --json --timeout 30s
```

## Анализ истории чата

Для "проанализируй чат", "о чём говорили за неделю", "выгрузи историю":

1. **Резолвинг чата**: `tgcli channels list --query`
2. **Синхронизация** (если нужен архив):
   ```bash
   tgcli channels sync --chat <id> --enable
   tgcli sync jobs add --chat <id> --depth 500
   tgcli sync --once --timeout 120s
   ```
3. **Чтение**: `tgcli messages list --chat <id> --source archive --limit 500 --json`
4. **Fallback при FloodWait**: `tgcli messages list --chat <id> --source live --limit 500 --json --timeout 90s`
5. **Анализ**: обработать JSON, сгруппировать по дням/авторам/темам

## Новости и события канала

Для "какие новости в канале?", "что нового?", "последние важные события":

1. Загрузить последние 200-500 сообщений через `messages list --limit 200`
2. Отфильтровать шум (приветствия, реакции, короткие реплики)
3. Выделить ключевые темы, ссылки, анонсы, важные дискуссии
4. Представить как дайджест с краткими описаниями каждой темы

## Инкрементальные сводки

Для "сводка с последней сводки", "что нового с прошлого раза":

1. Проверить файл состояния: `./tmp/telegram-summaries/<chat-slug>-last.json`
2. Если файл есть — прочитать `lastMessageId` и `lastDate`
3. Загрузить сообщения новее `lastDate` через `--after <lastDate>`
4. Если файла нет — загрузить последние 200 сообщений как первую сводку
5. После анализа сохранить состояние:
   ```json
   {"chatId":"<id>","lastMessageId":<id>,"lastDate":"<ISO>","summaryDate":"<ISO>"}
   ```
6. Директория: `mkdir -p ./tmp/telegram-summaries/`

## Поиск упоминаний

### Упоминания пользователя
```bash
tgcli messages search --query "Данил" --chat <id> --json --timeout 30s
tgcli messages search --regex "Данил|Danil|@username" --chat <id> --json --timeout 30s
```

### Сообщения конкретного автора
Загрузить сообщения и отфильтровать по `fromDisplayName` в JSON:
```bash
tgcli messages list --chat <id> --limit 500 --json --timeout 90s
```

## Source selection

- `--source live` (default) — свежие из Telegram API
- `--source archive` — из SQLite (требует предварительный `channels sync --enable` + `sync`)
- `--source both` — объединение и дедупликация

## JSON Output

Успех: `{"source":"live","returned":N,"messages":[...]}`
Ошибка: `{"ok":false,"error":"..."}`

## LOCK файл — НИКОГДА не удалять

Если tgcli выдаёт ошибку о заблокированной БД (`LOCK`, `database is locked`, `another instance`):
- **ЗАПРЕЩЕНО** удалять `~/.local/share/tgcli/LOCK` или любые lock-файлы
- Лок означает, что другой процесс tgcli (sync daemon, другой агент) сейчас работает
- **Правильное действие**: подождать 10-30 секунд и повторить команду
- При повторной ошибке — сообщить пользователю, что tgcli занят другим процессом

## Ограничения tgcli

Нет reply, edit, delete, forward, pin, реакций, inline buttons, admin ops, Markdown-форматирования.
Для этих операций использовать **telegram-mcp** (MCP tools).

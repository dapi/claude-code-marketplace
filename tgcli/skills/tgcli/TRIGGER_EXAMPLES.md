# tgcli Trigger Examples

## [YES] Should Activate

### **Reading Messages**
- "read messages in ИИшница"
- "show last 20 messages from channel"
- "what's new in my Telegram channel?"
- "прочитай последние сообщения в канале"
- "покажи сообщения из группы"
- "что нового в телеграм-канале?"

### **Search**
- "search for Claude Code in telegram"
- "find messages about AI agents"
- "найди в телеграме сообщения про деплой"
- "поиск по каналу ИИшница"
- "search regex pattern in chat history"
- "grep telegram for kubernetes errors"

### **Sending Messages**
- "send message to my channel"
- "отправь в канал текст 'Привет!'"
- "post update to telegram group"
- "send file to telegram chat"
- "отправь файл в группу"

### **Chat Analysis & Digests**
- "analyze chat history for last week"
- "summarize what was discussed in ИИшница"
- "о чём говорили в канале за неделю?"
- "проанализируй чат"
- "выгрузи историю канала"
- "дайджест канала за вчера"
- "give me a digest of the channel"
- "сводка по каналу"
- "что было с последней сводки?"

### **News & Events**
- "какие новости в канале?"
- "what happened in telegram channel today?"
- "последние важные события в группе"
- "что нового в ИИшнице?"
- "latest news from my channel"

### **Mentions & People**
- "покажи упоминания меня в канале"
- "show my mentions in telegram"
- "кто меня упоминал в ИИшнице?"
- "найди сообщения от Ивана"
- "что писал Данил в канале?"
- "messages from user in chat"

### **Channels & Groups**
- "list my telegram channels"
- "find channel about AI"
- "найди канал про ИИ"
- "info about telegram group"
- "show forum topics"

### **Contacts & CRM**
- "search telegram contacts for Ivan"
- "add tag to telegram contact"
- "set alias for telegram user"

### **Sync & Archive**
- "sync telegram channel history"
- "enable archive for channel"
- "sync status for telegram"

## [NO] Should NOT Activate

- "install tgcli" (installation question, not usage)
- "how does tgcli compare to telethon?" (comparison, not operation)
- "reply to message in telegram" (reply = telegram-mcp, not tgcli)
- "edit my telegram message" (edit = telegram-mcp)
- "delete message in telegram" (delete = telegram-mcp)
- "react to telegram message" (reactions = telegram-mcp)
- "ban user in telegram group" (admin ops = telegram-mcp)
- "forward message to another chat" (forward = telegram-mcp)
- "click inline button in bot" (inline buttons = telegram-mcp)

## Key Trigger Words

**Verbs (EN)**: read, search, find, send, post, analyze, summarize, list, show, check, get, fetch, sync
**Verbs (RU)**: прочитай, найди, отправь, покажи, проанализируй, выгрузи, поищи, проверь, дай сводку
**Nouns**: telegram, channel, chat, group, messages, history, digest, mentions, contacts, topics, archive
**Context patterns**: "in telegram", "from channel", "в телеграме", "из канала", "в канале"

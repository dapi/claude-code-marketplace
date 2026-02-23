# tgcli — Telegram CLI Plugin

Telegram integration for Claude Code via [tgcli](https://github.com/kfastov/tgcli) CLI.

## Features

- **Read** messages from channels, groups, and DMs
- **Search** with full-text search (FTS5) and regex
- **Send** text messages and files (with forum topic support)
- **Sync** chat history to local SQLite archive
- **Analyze** chat history with AI-powered summaries and digests
- **CRM** — contacts, aliases, tags, notes

## Requirements

- `tgcli` CLI installed (`npm install -g @kfastov/tgcli`)
- Telegram account authorized in tgcli (`tgcli auth`)

## Components

| Component | Description |
|-|-|
| `skills/tgcli/SKILL.md` | Auto-trigger skill for Telegram operations |
| `commands/tgcli.md` | `/tgcli` slash command with full CLI reference |

## Limitations

tgcli handles read/search/send operations. For reply, edit, delete, reactions, inline buttons, and admin operations — use **telegram-mcp** MCP server.

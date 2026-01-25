---
name: email
description: |
  **UNIVERSAL TRIGGER**: Use when user wants to READ/SEND email.

  Common patterns:
  - "check my email/inbox", "show unread"
  - "send email to [recipient]"
  - "проверить почту", "отправить письмо"

  📥 **Reading**:
  - "check inbox", "show unread emails", "what's in my mail"
  - "read email from [sender]", "find emails about [topic]"
  - "проверить входящие", "непрочитанные", "что в почте"

  📤 **Sending**:
  - "send email to [address]", "compose email"
  - "reply to email", "forward email"
  - "отправить письмо", "ответить на письмо", "написать письмо"

  📋 **Accounts**:
  - "list email accounts", "switch to work email"
  - "список почтовых аккаунтов", "использовать рабочую почту"

  ❌ **Should NOT activate**:
  - "what is SMTP protocol" (general question)
  - "email regex validation" (programming)
  - "install himalaya" (setup)

  TRIGGERS: email, mail, inbox, send, check, read, show, list, get,
  compose, reply, forward, unread, fetch, view, display,
  отправить, проверить, прочитать, показать, получить, письмо, почта
allowed-tools: Bash
---

# Email Skill

CLI-based email management using [Himalaya](https://github.com/pimalaya/himalaya).

## Prerequisites

Himalaya must be installed and configured by the user. Check availability:

```bash
himalaya account list
```

If this fails, inform the user they need to install and configure himalaya first.

## Reading Emails

### List messages

```bash
# Last 20 messages from INBOX
himalaya envelope list -f INBOX -s 20

# Unread only
himalaya envelope list "not flag seen"

# From specific sender
himalaya envelope list "from boss@company.com"

# By subject
himalaya envelope list "subject meeting"

# By date
himalaya envelope list "after 2025-01-20"

# Combined filters
himalaya envelope list "from support@example.com and after 2025-01-01"

# Different account
himalaya envelope list -a "work@company.com" -s 10
```

### Read a message

```bash
# Read by ID (from envelope list)
himalaya message read <id>

# Preview without marking as read
himalaya message read -p <id>
```

### List folders

```bash
himalaya folder list
```

## Sending Emails

**IMPORTANT**: Before sending, ASK the user:
1. From: which account to send from (use `himalaya account list` to show options)
2. To: recipient email address
3. Subject: email subject
4. Body: where to get the text (type now / from file / describe what to write)

### Send new email

```bash
# From is REQUIRED - use email from account list
himalaya template send <<'EOF'
From: sender@example.com
To: recipient@example.com
Subject: Email subject

Body text here.
Unicode supported.
EOF
```

### With CC/BCC

```bash
himalaya template send <<'EOF'
From: me@example.com
To: main@example.com
Cc: copy@example.com
Bcc: hidden@example.com
Subject: Important message

Message body.
EOF
```

### From specific account

```bash
# Use -a flag AND matching From header
himalaya template send -a "work@company.com" <<'EOF'
From: work@company.com
To: client@example.com
Subject: Project update

Status report.
EOF
```

## Account Management

```bash
# List configured accounts
himalaya account list

# Use specific account (add -a flag to any command)
himalaya envelope list -a "personal@gmail.com" -s 10
himalaya template send -a "work@company.com" <<'EOF'
...
EOF
```

## Query Syntax Reference

### Operators
- `not <condition>` - negation
- `<cond> and <cond>` - both conditions
- `<cond> or <cond>` - either condition

### Conditions
- `date <yyyy-mm-dd>` - exact date
- `before <yyyy-mm-dd>` - before date
- `after <yyyy-mm-dd>` - after date
- `from <pattern>` - sender contains
- `to <pattern>` - recipient contains
- `subject <pattern>` - subject contains
- `body <pattern>` - body contains
- `flag <flag>` - has flag (seen, answered, flagged, deleted, draft)

### Examples
```bash
# Unread from last week
himalaya envelope list "not flag seen and after 2025-01-18"

# From boss OR urgent in subject
himalaya envelope list "from boss@company.com or subject urgent"
```

## Error Handling

If himalaya returns an error, show it to the user. Common errors:

- `himalaya: command not found` — himalaya not installed
- `no account found` — no configured accounts
- `connection refused` — IMAP/SMTP server unreachable
- `authentication failed` — wrong password/credentials

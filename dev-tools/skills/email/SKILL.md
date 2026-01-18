---
name: email
description: |
  **UNIVERSAL TRIGGER**: Use when user wants to READ/SEND/MANAGE email via IMAP/SMTP.

  Common patterns:
  - "read/check/show my email/mail/inbox"
  - "send email/mail to [recipient]"
  - "проверить/показать/прочитать почту"
  - "отправить письмо [кому]"

  📥 **Reading**:
  - "check my inbox", "show unread emails", "what's in my mail"
  - "read email from [sender]", "search emails about [topic]"
  - "проверить входящие", "показать непрочитанные", "что в почте"

  📤 **Sending**:
  - "send email to [address]", "compose email", "write mail"
  - "reply to email", "forward email to [address]"
  - "отправить письмо", "написать письмо", "ответить на письмо"

  🔍 **Search & Folders**:
  - "find emails from [sender]", "search emails with [subject]"
  - "show sent folder", "list drafts", "check spam"
  - "найти письма от", "показать отправленные"

  📎 **Attachments**:
  - "download attachments", "send with attachment"
  - "скачать вложения", "отправить с файлом"

  ❌ **Should NOT activate**:
  - "what is SMTP protocol" (general question)
  - "email regex validation" (programming)
  - "gmail vs outlook" (comparison)

  TRIGGERS: email, mail, inbox, send email, check email, read mail,
  отправить письмо, проверить почту, входящие, написать письмо,
  compose, reply, forward, attachment, unread, new messages,
  outbox, sent, drafts, trash, spam, непрочитанные, исходящие,
  черновики, вложение, письма, почтовый ящик, imap, smtp,
  check my mail, what's in my inbox, any new emails,
  есть ли письма, что в почте, новые письма
allowed-tools: Bash, Read, Write
---

# Email Skill

CLI-based email management using Himalaya email client with IMAP/SMTP support.

## Path Resolution

**CRITICAL**: Always locate email.sh before executing commands.

```bash
# Find email.sh location (use latest version via sort -V)
SKILL_DIR=$(find ~/.claude -name "email.sh" -path "*/skills/email/*" -type f 2>/dev/null | sort -V | tail -1 | xargs dirname)

# Execute commands
bash "$SKILL_DIR/email.sh" <command> [options]
```

## Required Environment Variables

Before using email commands, ensure these are set in the user's environment:

### Single Account (minimum required)
```bash
EMAIL_ADDRESS="user@example.com"
EMAIL_USER="user@example.com"
EMAIL_PASSWORD="app_password"
IMAP_HOST="imap.example.com"
SMTP_HOST="smtp.example.com"
# Optional: IMAP_PORT (993), SMTP_PORT (587)
```

### Multi-Account (pattern: EMAIL_{NAME}_*)
```bash
EMAIL_WORK_ADDRESS="work@company.com"
EMAIL_WORK_USER="work@company.com"
EMAIL_WORK_PASSWORD="..."
EMAIL_WORK_IMAP_HOST="imap.company.com"
EMAIL_WORK_SMTP_HOST="smtp.company.com"
```

## Commands Reference

### Reading Emails

```bash
# Show inbox (default 50 messages)
./email.sh inbox [--limit N] [--unread] [--account NAME]

# List messages in folder
./email.sh list <folder> [--limit N] [--account NAME]

# Read specific message
./email.sh read <id> [--raw] [--account NAME]

# Search messages (IMAP query syntax)
./email.sh search <query> [--account NAME]
# Examples: "FROM:boss@company.com", "SUBJECT:meeting", "UNSEEN"

# List folders
./email.sh folders [--account NAME]
```

### Sending Emails

```bash
# Send new email
./email.sh send \
  --to <emails>              # comma-separated
  [--cc <emails>] \
  [--bcc <emails>] \
  --subject <text> \
  --body <text> | --body-file <path> \
  [--attach <file>] \        # multiple allowed
  [--account NAME]

# Reply to message
./email.sh reply <id> --body <text> [--account NAME]

# Reply to all
./email.sh reply-all <id> --body <text> [--account NAME]

# Forward message
./email.sh forward <id> --to <email> [--body <text>] [--account NAME]

# Save as draft
./email.sh draft --to <email> --subject <text> --body <text> [--account NAME]
```

### Message Management

```bash
# Mark as read/unread
./email.sh mark-read <id> [--account NAME]
./email.sh mark-unread <id> [--account NAME]

# Move to folder
./email.sh move <id> <folder> [--account NAME]

# Delete (soft - move to Trash)
./email.sh delete <id> [--account NAME]

# Delete (permanent - EXPUNGE)
./email.sh delete <id> --permanent [--account NAME]

# Download attachments
./email.sh download <id> [--account NAME]
# Files saved to: ~/Downloads/email-attachments/
```

### Account Information

```bash
# List configured accounts
./email.sh accounts

# Show help
./email.sh help
```

## Usage Examples

### Check inbox for unread messages
```bash
SKILL_DIR=$(find ~/.claude -name "email.sh" -path "*/skills/email/*" -type f 2>/dev/null | head -1 | xargs dirname)
bash "$SKILL_DIR/email.sh" inbox --unread --limit 10
```

### Send email with attachment
```bash
SKILL_DIR=$(find ~/.claude -name "email.sh" -path "*/skills/email/*" -type f 2>/dev/null | head -1 | xargs dirname)
bash "$SKILL_DIR/email.sh" send \
  --to "recipient@example.com" \
  --subject "Report" \
  --body "Please find the report attached." \
  --attach "/path/to/report.pdf"
```

### Search for emails from specific sender
```bash
SKILL_DIR=$(find ~/.claude -name "email.sh" -path "*/skills/email/*" -type f 2>/dev/null | head -1 | xargs dirname)
bash "$SKILL_DIR/email.sh" search "FROM:support@company.com"
```

### Work with multiple accounts
```bash
SKILL_DIR=$(find ~/.claude -name "email.sh" -path "*/skills/email/*" -type f 2>/dev/null | head -1 | xargs dirname)

# Check work inbox
bash "$SKILL_DIR/email.sh" inbox --account work

# Send from personal account
bash "$SKILL_DIR/email.sh" send --to "friend@mail.com" --subject "Hi" --body "Hello!" --account personal
```

## Error Handling

### Missing environment variables
```
Error: EMAIL_ADDRESS is not set.

Required environment variables:
  EMAIL_ADDRESS   - Your email address
  EMAIL_USER      - IMAP/SMTP login
  EMAIL_PASSWORD  - App password
  IMAP_HOST       - IMAP server hostname
  SMTP_HOST       - SMTP server hostname
```

### Invalid account
```
Error: Account 'xyz' not found.
Available accounts: default, work

Use './email.sh accounts' to see configured accounts.
```

## Provider-Specific Notes

### Gmail
- Use App Passwords (not regular password)
- IMAP_HOST: imap.gmail.com
- SMTP_HOST: smtp.gmail.com
- Enable "Less secure app access" or use OAuth

### Yandex
- Use App Passwords
- IMAP_HOST: imap.yandex.com
- SMTP_HOST: smtp.yandex.com
- Folder names may be in Russian (Отправленные, Черновики)

### Office 365 / Outlook
- IMAP_HOST: outlook.office365.com
- SMTP_HOST: smtp.office365.com

## Technical Details

- **CLI Tool**: Himalaya (Rust, auto-installed if missing)
- **Protocols**: IMAP for reading, SMTP for sending
- **Config**: Auto-generated from env vars (temporary, secure)
- **Limits**: Default 50 messages, max 500
- **Attachments**: Downloaded to ~/Downloads/email-attachments/

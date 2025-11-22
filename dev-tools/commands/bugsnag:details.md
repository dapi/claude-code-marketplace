---
name: details
description: Show detailed information about a specific Bugsnag error
---

Display comprehensive details about a specific error including context, timeline, and recent events.

## Usage

```
/bugsnag:details <error_id>
```

## Parameters

- `error_id` - **Required**. The ID of the error to inspect

## Output

Shows:
- **Basic info**: ID, status, severity, event count, affected users
- **Timeline**: First occurrence, last occurrence
- **Context**: App version, release stage, language, framework
- **Message**: Error message (if available)
- **Recent events**: Last 3 events with details
- **URL**: Direct link to Bugsnag dashboard

## Examples

**Get error details:**
```
/bugsnag:details 5f8a9b2c
```

**Typical workflow:**
```
/bugsnag:open              # Find error_id from list
/bugsnag:details abc123    # Get full details
/bugsnag:comments abc123   # Check existing comments
/bugsnag:fix abc123        # Mark as fixed when done
```

## Example Output

```
🔍 **Детали ошибки:** NullPointerException

**Основная информация:**
• ID: `abc123`
• Статус: open
• Критичность: error
• Событий: 42
• Пользователи затронуто: 15

**Временные рамки:**
• Первое появление: 2024-01-15T10:30:00Z
• Последнее: 2024-01-22T14:15:00Z

**Контекст:**
• App Version: 1.2.3
• Release Stage: production
• Language: ruby
• Framework: rails

**URL:** https://app.bugsnag.com/my-company/my-project/errors/abc123

**Сообщение:**
```
undefined method `foo' for nil:NilClass
```

📊 **Последние события:** (3)
...
```

## Use Cases

- Investigate error before fixing
- Understand error context and frequency
- Review error timeline and affected users
- Get stack trace information for debugging

## Related Commands

- `/bugsnag:open` - Find error IDs
- `/bugsnag:comments ERROR_ID` - View discussion
- `/bugsnag:fix ERROR_ID` - Mark as fixed

## Execution

```bash
cd dev-tools/skills/bugsnag && ./bugsnag.rb details "$@"
```

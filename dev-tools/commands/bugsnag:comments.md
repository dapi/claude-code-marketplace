---
name: comments
description: View all comments for a Bugsnag error
---

Display all comments associated with a specific error.

## Usage

```
/bugsnag:comments <error_id>
```

## Parameters

- `error_id` - **Required**. The ID of the error

## Output

For each comment shows:
- Comment number
- Comment ID
- Author name/email
- Timestamp
- Comment text

## Example Output

**With comments:**
```
💬 Комментарии (3):

**Комментарий 1:**
• ID: `comment_abc`
• Автор: john@company.com
• Время: 2024-01-22T10:30:00Z
• Текст: Investigating this issue

**Комментарий 2:**
• ID: `comment_def`
• Автор: Sarah Smith
• Время: 2024-01-22T14:15:00Z
• Текст: Fixed in PR #456

**Комментарий 3:**
• ID: `comment_ghi`
• Автор: mike@company.com
• Время: 2024-01-22T16:45:00Z
• Текст: Deployed to production, monitoring
```

**No comments:**
```
💬 Комментарии (0):

Нет комментариев для этой ошибки.
```

## Examples

**View comments:**
```
/bugsnag:comments 5f8a9b2c
```

**Typical workflow:**
```
/bugsnag:details abc123      # Get error details
/bugsnag:comments abc123     # Check discussion history
/bugsnag:comment abc123 "..." # Add your comment
/bugsnag:comments abc123     # Verify comment added
```

## Use Cases

- Review investigation history
- Check team discussion
- See fix status and deployment notes
- Understand error context from team
- Verify your comment was added
- Track who worked on the error

## Workflow Example

```bash
# 1. Find error needing attention
/bugsnag:open

# 2. Check if anyone already investigating
/bugsnag:comments abc123

# 3. Add your own comment
/bugsnag:comment abc123 "I'll handle this one"

# 4. After fixing, check all comments
/bugsnag:comments abc123

# 5. Add final comment and close
/bugsnag:comment abc123 "Fixed and deployed"
/bugsnag:fix abc123
```

## Related Commands

- `/bugsnag:comment ERROR_ID "text"` - Add new comment
- `/bugsnag:details ERROR_ID` - Get error details
- `/bugsnag:fix ERROR_ID` - Mark as fixed

## Execution

```bash
cd dev-tools/skills/bugsnag && ./bugsnag.rb comments "$@"
```

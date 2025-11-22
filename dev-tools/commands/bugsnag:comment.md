---
name: comment
description: Add a comment to a Bugsnag error
---

Add a text comment to a specific error for tracking notes, investigation status, or team coordination.

## Usage

```
/bugsnag:comment <error_id> "comment text"
```

## Parameters

- `error_id` - **Required**. The ID of the error
- `comment text` - **Required**. Comment message (use quotes if contains spaces)

## Examples

**Basic comment:**
```
/bugsnag:comment 5f8a9b2c "Investigating this issue"
```

**Status update:**
```
/bugsnag:comment abc123 "Fixed in PR #456, deploying to staging"
```

**Cannot reproduce:**
```
/bugsnag:comment def789 "Cannot reproduce locally, requesting more info from user"
```

**Multi-word comments:**
```
/bugsnag:comment 5f8a9b2c "This error only occurs on iOS 14. Working on fix."
```

**Team coordination:**
```
/bugsnag:comment abc123 "Assigned to @john, related to recent DB migration"
```

## Output

**Success:**
```
✅ Комментарий успешно добавлен к ошибке `5f8a9b2c`
```

**Error (invalid ID):**
```
❌ Ошибка при добавлении комментария: ошибка клиента API - Not found
```

**Error (missing parameters):**
```
❌ Укажите ID ошибки и текст комментария
Пример: bugsnag.rb comment 5f8a9b2c 'Investigating this issue'
```

## Use Cases

- Document investigation progress
- Coordinate with team members
- Track fix status and deployment
- Add reproduction steps or additional context
- Link to related PRs or issues
- Mark when fix is deployed to environments

## Workflow Example

```bash
# 1. Find the error
/bugsnag:open

# 2. Get details
/bugsnag:details abc123

# 3. Add initial comment
/bugsnag:comment abc123 "Investigating - looks like timeout issue"

# 4. Update progress
/bugsnag:comment abc123 "Fixed in PR #789"

# 5. Final update
/bugsnag:comment abc123 "Deployed to production, monitoring"
/bugsnag:fix abc123
```

## Related Commands

- `/bugsnag:comments ERROR_ID` - View all comments
- `/bugsnag:details ERROR_ID` - Get error details first
- `/bugsnag:fix ERROR_ID` - Mark as fixed after commenting

## Execution

```bash
cd dev-tools/skills/bugsnag && ./bugsnag.rb comment "$@"
```

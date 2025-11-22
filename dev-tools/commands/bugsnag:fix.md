---
name: fix
description: Mark a Bugsnag error as resolved/fixed
---

Mark a specific Bugsnag error as resolved (fixed).

## Usage

```
/bugsnag:fix <error_id>
```

## Parameters

- `error_id` - **Required**. The ID of the error to mark as resolved

## Examples

**Basic usage:**
```
/bugsnag:fix 5f8a9b2c
```
Marks error `5f8a9b2c` as resolved.

**Get error ID first:**
```
/bugsnag:open
```
Find the error ID from the list, then:
```
/bugsnag:fix <error_id_from_list>
```

## Behavior

1. Attempts to update error status to "resolved" via Bugsnag API
2. If API update fails, adds a resolution comment to the error
3. Returns confirmation message with result

## Output Examples

**Success (direct resolution):**
```
✅ Ошибка `5f8a9b2c` успешно отмечена как выполненная!
```

**Fallback (via comment):**
```
✅ Ошибка `5f8a9b2c` помечена как выполненная через комментарий.
Пожалуйста, закройте ошибку вручную в Bugsnag dashboard.
```

**Error:**
```
❌ Ошибка при пометки ошибки как выполненной: ошибка клиента API - Not found
```

## Use Cases

- Mark error as fixed after deploying a fix
- Clean up resolved errors from error list
- Track resolution progress in Bugsnag

## Related Commands

- `/bugsnag:open` - See currently open errors
- `/bugsnag:list` - View all errors
- Use skill for details: "bugsnag details ERROR_ID"

## Execution

```bash
cd dev-tools/skills/bugsnag && ./bugsnag.rb resolve "$@"
```

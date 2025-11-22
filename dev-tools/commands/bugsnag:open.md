---
name: open
description: Display only open (unresolved) Bugsnag errors
---

Show currently open (unresolved) errors from Bugsnag project.

## Usage

```
/bugsnag:open
/bugsnag:open --limit 30
/bugsnag:open --severity error
```

## Parameters

- `--limit N` - Maximum errors to show (default: 20)
- `--severity error|warning` - Filter by severity level

## Examples

**Basic usage:**
```
/bugsnag:open
```
Shows 20 most recent open errors.

**Limit results:**
```
/bugsnag:open --limit 50
```
Shows up to 50 open errors.

**Only critical errors:**
```
/bugsnag:open --severity error
```
Shows only open errors with error severity (excludes warnings).

**Combined:**
```
/bugsnag:open --severity error --limit 10
```
Shows up to 10 most critical open errors.

## Output

For each error displays:
- Error class and event count
- Error ID for further investigation
- Severity level (error/warning)
- First and last occurrence timestamps
- Direct URL to Bugsnag dashboard

## Execution

```bash
cd dev-tools/skills/bugsnag && ./bugsnag.rb open "$@"
```

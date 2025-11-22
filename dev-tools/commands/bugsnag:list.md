---
name: list
description: Display list of Bugsnag errors with optional filtering
---

List errors from Bugsnag project with optional filters.

## Usage

```
/bugsnag:list
/bugsnag:list --limit 50
/bugsnag:list --status open
/bugsnag:list --severity error
```

## Parameters

- `--limit N` - Maximum errors to show (default: 20)
- `--status open|resolved|ignored` - Filter by status
- `--severity error|warning` - Filter by severity level

## Examples

**Basic usage:**
```
/bugsnag:list
```
Shows 20 most recent errors from the configured Bugsnag project.

**Limit results:**
```
/bugsnag:list --limit 50
```
Shows up to 50 errors.

**Filter by status:**
```
/bugsnag:list --status open
```
Shows only unresolved (open) errors.

**Filter by severity:**
```
/bugsnag:list --severity error
```
Shows only errors (excludes warnings).

**Combined filters:**
```
/bugsnag:list --status open --severity error --limit 30
```
Shows up to 30 open errors with error severity.

## Execution

Execute the bugsnag.rb script with list command:

```bash
cd dev-tools/skills/bugsnag && ./bugsnag.rb list "$@"
```

---
name: orgs
description: List all available Bugsnag organizations
---

Display all Bugsnag organizations accessible with current API credentials.

## Usage

```
/bugsnag:orgs
```

## Output

Shows for each organization:
- **Organization name and ID** - Unique identifier
- **Creation date** - When the organization was created
- **Collaborators** - Total number of team members
- **Projects** - Total number of monitored projects
- **Dashboard URL** - Direct link to organization in Bugsnag

## Example Output

```
🏢 Доступные организации: 2

1. **My Company** (ID: `org_abc123`)
   Создана: 2023-01-15
   Коллабораторов: 25
   Проектов: 12
   URL: https://app.bugsnag.com/my-company

2. **Client Org** (ID: `org_def456`)
   Создана: 2024-02-20
   Коллабораторов: 8
   Проектов: 5
   URL: https://app.bugsnag.com/client-org
```

## Use Cases

- Get overview of all organizations you have access to
- Find organization IDs for API configuration
- Check team size and project count
- Quick access to organization dashboards

## Execution

```bash
cd dev-tools/skills/bugsnag && ./bugsnag.rb organizations
```

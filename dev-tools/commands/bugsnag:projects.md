---
name: projects
description: List all available Bugsnag projects
---

Display all Bugsnag projects accessible with current API credentials.

## Usage

```
/bugsnag:projects
```

## Output

Shows for each project:
- **Project name and ID** - Unique identifier for the project
- **Project type** - Technology stack (rails, js, python, etc.)
- **Open error count** - Number of unresolved errors
- **Collaborators** - Number of team members with access
- **Release stages** - Environments (production, staging, development)
- **Dashboard URL** - Direct link to project in Bugsnag web interface

## Example Output

```
📦 Доступные проекты: 3

1. **My Rails App** (ID: `proj_abc123`)
   Тип: rails
   Открытых ошибок: 42
   Коллабораторов: 5
   Стадии: production, staging
   URL: https://app.bugsnag.com/my-company/my-rails-app

2. **Frontend App** (ID: `proj_def456`)
   Тип: js
   Открытых ошибок: 15
   Коллабораторов: 3
   Стадии: production
   URL: https://app.bugsnag.com/my-company/frontend-app
```

## Use Cases

- Get overview of all monitored projects
- Find project IDs for configuration
- Check error counts across projects
- Quick access to project dashboards

## Execution

```bash
cd dev-tools/skills/bugsnag && ./bugsnag.rb projects
```

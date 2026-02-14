# bugsnag-skill

Bugsnag API integration for Claude Code — view and manage errors, organizations, projects.

## Installation

```bash
/plugin install bugsnag-skill@dapi
```

## Components

### Skill: bugsnag

Activates automatically when you ask about Bugsnag data: errors, projects, organizations.

## Usage

```
"show bugsnag errors"
"bugsnag details for error_123"
"list bugsnag projects"
"проанализируй bugsnag ошибки"
"показать bugsnag ошибки"
```

### CLI Commands

```bash
./bugsnag.rb organizations   # List organizations
./bugsnag.rb projects        # List projects
./bugsnag.rb list            # List all errors
./bugsnag.rb open            # Open errors only
./bugsnag.rb details ERROR_ID # Error details
./bugsnag.rb analyze         # Pattern analysis
```

## Configuration

### API Key

1. Go to [Bugsnag Dashboard](https://app.bugsnag.com)
2. Settings → Organization → API Authentication
3. Create a Personal Access Token
4. Get project ID from project settings

### Environment Variables

```bash
export BUGSNAG_DATA_API_KEY="your_api_key_here"
export BUGSNAG_PROJECT_ID="your_project_id_here"

# Optional
export BUGSNAG_HTTP_PROXY="http://proxy.example.com:8080"
```

## Documentation

See [skills/bugsnag/SKILL.md](./skills/bugsnag/SKILL.md)

## License

MIT

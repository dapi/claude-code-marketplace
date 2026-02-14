# requirements

Project requirements registry via Google Spreadsheet with GitHub issues sync.

## Installation

```bash
/plugin install requirements@dapi
```

## Components

### Command: /requirements

Manage project requirements with subcommands.

```
/requirements init          # Create spreadsheet from template
/requirements status        # Requirements status
/requirements sync          # Sync with GitHub issues
/requirements add <title>   # Add requirement
/requirements update <ID> <col> <val>  # Update field
```

## Usage

```
/requirements status
/requirements sync
/requirements add "User authentication"
```

## Requirements

- Google Workspace MCP
- [gh CLI](https://cli.github.com)

## Documentation

See [commands/requirements.md](./commands/requirements.md)

## License

MIT

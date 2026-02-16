# skill-finder

Search and install agent skills from online catalogs.

## Commands

### /find-skill

Search for skills by keyword via [Skyll API](https://api.skyll.app) and optionally install them with `npx skills add`.

```
/find-skill debugging
/find-skill react performance
/find-skill kubernetes helm
```

**Output**: Numbered list of matching skills with name, description, install count, and link. Option to install selected skills.

## Requirements

- `curl` -- for API requests (available on all platforms)
- `npx` (Node.js) -- optional, for installing found skills

## Data Source

Powered by [Skyll API](https://api.skyll.app) which aggregates skills from:
- [skills.sh](https://skills.sh/) (Vercel)
- GitHub repositories
- Other skill catalogs

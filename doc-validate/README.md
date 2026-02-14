# doc-validate

Documentation quality validation plugin for Claude Code — broken links, orphan docs, glossary, structure.

## Installation

```bash
/plugin install doc-validate@dapi
```

## Components

### Command: /doc-validate

Run documentation validation with interactive fixes.

```
/doc-validate
/doc-validate docs/
```

### Skill: doc-validate

Activates automatically when you ask to validate or check documentation.

## Usage

```
/doc-validate docs/
"validate docs"
"check for broken links"
"find orphan documents"
"проверь документацию"
"найди битые ссылки"
```

## Checks

- **Links** — find broken markdown links
- **Orphan docs** — files without incoming links
- **Glossary** — terminology and synonym consistency
- **Structure** — documentation structure analysis

## Requirements

- Ruby 3.0+
- Bundler

## Documentation

See [skills/doc-validate/SKILL.md](./skills/doc-validate/SKILL.md)

## License

MIT

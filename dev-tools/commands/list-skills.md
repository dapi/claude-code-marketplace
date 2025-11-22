# List Available Skills

Display all available skills from installed plugins in the current workspace.

## Instructions

Search for all SKILL.md files in the project and display their information in a structured format.

For each skill found, show:
- **Plugin**: Which plugin it belongs to
- **Name**: Skill name from frontmatter
- **Description**: When to use this skill (from frontmatter)
- **Allowed Tools**: Tools the skill can use (if specified)
- **Location**: File path for reference

Format the output as a clean, easy-to-read list with clear sections for each plugin.

If no skills are found, inform the user and suggest checking:
1. Plugin installation status with `/plugin list`
2. Plugin directory structure
3. Whether plugins have skills directories with SKILL.md files

## Example Output Format

```
📚 Available Skills

🔧 dev-tools Plugin:

  • bugsnag
    When to use: User mentions Bugsnag errors, error tracking, or asks to show/analyze errors
    Allowed tools: Bash, Read
    Location: dev-tools/skills/bugsnag/SKILL.md

🧪 testing-tools Plugin:

  [No skills found]

💡 Superpowers Framework:

  [List of superpowers skills if accessible]
```

Execute the search now and present the results.

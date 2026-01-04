---
description: Manage project requirements registry (status, sync, add, update)
argument-hint: [status|sync|add|update|init] [args...]
---

# Requirements Manager

Manage project requirements registry via Google Spreadsheet.

## Configuration

- **Template:** https://docs.google.com/spreadsheets/d/18PAEXIvcRTyyP1THm60NiqmfTQEnuljc8obcpGOfx8c
- **Google Email:** danilpismenny@gmail.com

### Getting Spreadsheet ID

1. Find the `# Requirements Management` section with `spreadsheet_id:` field in project's CLAUDE.md
2. If section is missing — tell user to run `/requirements init` for initialization

## Command: $ARGUMENTS

Execute action based on argument:

### If `init`

1. Tell the user to:
   - Open template: https://docs.google.com/spreadsheets/d/18PAEXIvcRTyyP1THm60NiqmfTQEnuljc8obcpGOfx8c
   - File → Make a copy
   - Rename the copy (e.g., "ProjectName Requirements")
   - Copy ID from the copy's URL (between `/d/` and `/edit`)
2. Ask user for the copied spreadsheet ID
3. Add section to project's CLAUDE.md:
   ```markdown
   # Requirements Management

   - **spreadsheet_id:** <ID>
   - **spreadsheet_url:** https://docs.google.com/spreadsheets/d/<ID>
   ```

### If `status` or empty

1. Get Spreadsheet ID from project's CLAUDE.md
2. Read spreadsheet "Requirements" sheet via MCP
3. Display summary:
   - Total requirements
   - By Development status (Complete, In Progress, Planned)
   - By Compliance (Full, Partial, None)
4. Show requirements In Progress if any

### If `sync`

1. Get Spreadsheet ID from project's CLAUDE.md
2. Read spreadsheet
3. Get GitHub issues list: `gh issue list --state all --json number,title,state`
4. Compare statuses and suggest changes
5. Ask for confirmation before updating spreadsheet

### If `add <title>`

1. Get Spreadsheet ID from project's CLAUDE.md
2. Create GitHub issue: `gh issue create --title "<title>"`
3. Add row to spreadsheet with HYPERLINK to issue
4. Set: Type=FR, Discovery=Proposed

### If `update <ID> <column> <value>`

1. Get Spreadsheet ID from project's CLAUDE.md
2. Find row by ID in spreadsheet
3. Update specified column
4. Comment in linked GitHub issue

## Rules

- Always ask for confirmation before making changes to spreadsheet
- GitHub repo: determine from `git remote get-url origin`
- If Spreadsheet ID not found in CLAUDE.md — redirect to `/requirements init`

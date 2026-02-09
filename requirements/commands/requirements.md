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

**Step 1: Determine project name**
- Extract from `git remote get-url origin` (repo name)
- Or use current directory name as fallback

**Step 2: Automatically create spreadsheet copy**

Try to create a copy programmatically using Google Workspace MCP:

1. Create new spreadsheet via `create_spreadsheet`:
   - Title: "{ProjectName} Requirements"
   - Sheets: ["Requirements", "Changelog"]

2. Read template data via `read_sheet_values`:
   - Template ID: `18PAEXIvcRTyyP1THm60NiqmfTQEnuljc8obcpGOfx8c`
   - Read "Requirements" sheet (A1:Z1000)
   - Read "Changelog" sheet (A1:Z100)

3. Write data to new spreadsheet via `modify_sheet_values`:
   - Copy all data preserving structure
   - Apply header formatting via `format_sheet_range` (bold, background color)

4. Share spreadsheet via `share_drive_file`:
   - Share with user's email as owner (already owner by default)

**Step 3: On success**
- Save to project's CLAUDE.md:
  ```markdown
  # Requirements Management

  - **spreadsheet_id:** <NEW_ID>
  - **spreadsheet_url:** https://docs.google.com/spreadsheets/d/<NEW_ID>
  ```
- Show success message with link to new spreadsheet

**Step 4: On failure (fallback to manual)**

If automatic creation fails, instruct the user:
1. Open template: https://docs.google.com/spreadsheets/d/18PAEXIvcRTyyP1THm60NiqmfTQEnuljc8obcpGOfx8c
2. File → Make a copy
3. Rename the copy (e.g., "ProjectName Requirements")
4. Provide the copied spreadsheet ID (between `/d/` and `/edit` in URL)
5. Then save to CLAUDE.md as above

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

# Bugsnag Skill - Testing Guide

## Auto-Activation Test Scenarios

This document contains test scenarios to verify the bugsnag skill activates correctly based on user input.

### ✅ SHOULD Activate

These phrases should trigger automatic skill activation:

1. **Direct Bugsnag mentions**:
   - "показать ошибки в bugsnag"
   - "show bugsnag errors"
   - "check bugsnag"
   - "what's in bugsnag?"

2. **Error details requests**:
   - "bugsnag details for ERROR_123"
   - "show error stack trace for ERROR_456"
   - "get bugsnag error context"
   - "покажи стектрейс ошибки ERROR_789"

3. **Error management**:
   - "resolve bugsnag error ERROR_123"
   - "mark bugsnag error as fixed"
   - "close bugsnag error ERROR_456"
   - "отметить ошибку ERROR_789 как решенную"

4. **Error analysis**:
   - "analyze bugsnag errors"
   - "bugsnag error patterns"
   - "проанализировать ошибки в bugsnag"
   - "what error patterns in production?"

5. **Generic error monitoring mentions**:
   - "check production errors"
   - "show error tracking"
   - "what's happening in error monitoring?"

### ❌ Should NOT Activate

These phrases should NOT trigger bugsnag skill:

1. **Code errors (not monitoring)**:
   - "найти ошибку в коде"
   - "this code has a bug"
   - "review this function for errors"

2. **Application logs (not Bugsnag)**:
   - "показать логи приложения"
   - "show server logs"
   - "check nginx logs"

3. **Generic debugging**:
   - "debug this issue"
   - "why is this not working?"
   - "help me fix this"

4. **Other monitoring tools**:
   - "check sentry errors"
   - "show datadog alerts"
   - "rollbar notifications"

## Testing Procedure

### 1. Install Plugin Locally

```bash
# From repository root
/plugin marketplace add /home/danil/code/claude-code-marketplace
/plugin install dev-tools@dapi
```

### 2. Verify Skill Discovery

```bash
# Check skill is registered
/skills list
# Should show: bugsnag (dev-tools)
```

### 3. Test Auto-Activation

Start new conversation and try phrases from "SHOULD Activate" section:

```
User: "show bugsnag errors"
Expected: Claude should mention using bugsnag skill or invoke ./bugsnag.rb
```

```
User: "bugsnag details for ERROR_123"
Expected: Claude should invoke ./bugsnag.rb details ERROR_123
```

### 4. Test Non-Activation

Try phrases from "Should NOT Activate" section:

```
User: "найти ошибку в коде"
Expected: Claude uses code analysis, NOT bugsnag skill
```

## Environment Setup for Testing

Before testing, ensure environment variables are set:

```bash
export BUGSNAG_DATA_API_KEY='your_actual_api_key'
export BUGSNAG_PROJECT_ID='your_actual_project_id'
```

To get these values:
1. Visit https://app.bugsnag.com
2. Settings → Organization → API Authentication
3. Create Personal Access Token
4. Get Project ID from project settings

## Expected Behavior

### Correct Activation Flow

1. User mentions "bugsnag errors"
2. Claude recognizes trigger keywords
3. Claude invokes bugsnag skill
4. Skill executes `./bugsnag.rb <command>`
5. Results displayed to user

### Correct Non-Activation Flow

1. User asks about code errors (no "bugsnag" mention)
2. Claude uses native code analysis
3. Bugsnag skill does NOT activate
4. Standard debugging workflow proceeds

## Success Criteria

- ✅ Skill activates for all "SHOULD Activate" scenarios
- ✅ Skill does NOT activate for "Should NOT Activate" scenarios
- ✅ Commands execute correctly when activated
- ✅ Environment variables validated before execution
- ✅ Error messages are clear when API keys missing
- ✅ Help command works: `./bugsnag.rb help`

## Troubleshooting

### Skill Not Activating

1. Check skill is installed: `/skills list`
2. Verify SKILL.md frontmatter has proper YAML
3. Check description contains trigger keywords
4. Restart Claude Code session

### Commands Not Working

1. Verify script is executable: `chmod +x bugsnag.rb`
2. Check environment variables are set
3. Test script directly: `./bugsnag.rb help`
4. Check Ruby dependencies installed

### Permission Errors

1. Verify API key has correct permissions in Bugsnag
2. Check project ID is correct
3. Test API access with curl first

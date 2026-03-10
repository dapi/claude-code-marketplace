# Zellij Skill Expansion Design

**Date:** 2026-03-10
**Plugin:** zellij-workflow
**Zellij version:** 0.44.0

## Goal

Expand `zellij-tab-pane` skill from ~5 commands (new-tab, new-pane, write-chars, run) to ~38 commands covering 7 domains. Single mega-skill approach (variant A).

## Architecture Decision

**Variant A: one mega-skill** chosen over variant C (skill + reference files) because:
- ~600 lines / ~2k tokens is negligible in 200k context window
- Eliminates extra `Read` tool calls per invocation
- More reliable — Claude sees exact syntax immediately
- Simpler to maintain and test

## Domains (7 included, 4 excluded)

### Included

1. **Sessions** (~6 commands): list-sessions, attach, kill-session, delete-session, switch-session, rename-session
2. **Tabs** (~8 commands): new-tab, list-tabs, go-to-tab-name, go-to-next/previous-tab, move-tab, close-tab, rename-tab
3. **Panes** (~10 commands): new-pane, list-panes, close-pane, rename-pane, move-focus, move-pane, resize, focus-next/previous-pane, stack-panes
4. **Floating/Fullscreen** (~5 commands): toggle-floating-panes, show/hide-floating-panes, toggle-fullscreen, toggle-pane-embed-or-floating
5. **Layout** (~3 commands): dump-layout, override-layout, next/previous-swap-layout
6. **Edit** (~2 commands): edit (file in $EDITOR pane), edit-scrollback
7. **Input/Output** (~4 commands): send-keys, paste, dump-screen, clear

### Excluded

- **Scrolling** (scroll-up/down, page-scroll, etc.) — Claude rarely scrolls for user
- **Plugins** (plugin, launch-plugin, pipe, list-aliases) — niche use case
- **Web** (web server start/stop/tokens) — one-time setup
- **Monitoring** (subscribe, list-clients, save-session) — plugin development only

## SKILL.md Structure

```
1. YAML frontmatter — triggers (~15 lines)
2. Decision Tree — domain routing (~30 lines)
3. Domain sections:
   3.1 Sessions (~80 lines)
   3.2 Tabs (~100 lines)
   3.3 Panes (~120 lines)
   3.4 Floating/Fullscreen (~40 lines)
   3.5 Layout (~40 lines)
   3.6 Edit (~40 lines)
   3.7 Input/Output (~50 lines)
4. Error diagnostics (~30 lines)
5. Dependencies & constraints (~15 lines)
```

**Estimated total: ~550-600 lines**

## Key Changes from Current Skill

### Simplification: new-tab -- COMMAND (zellij 0.44)

Zellij 0.44 supports `new-tab -- COMMAND` natively. Current Mode B uses a `write-chars` hack with `sleep 0.3` race condition workaround. New approach:

```bash
# Old (current)
zellij action new-tab --name "npm-test" && sleep 0.3 && zellij action write-chars "npm test\n"

# New (0.44)
zellij action new-tab --name "npm-test" -- npm test
```

Mode C (Claude session) still needs the script approach because `exec claude` requires interactive shell.

### Restructuring: Modes → Domains

Current 4 modes (Empty, Command, Claude, Issue) become part of Tabs/Panes sections:
- Mode A (empty) → Tabs: new-tab / Panes: new-pane (basic usage)
- Mode B (command) → Tabs: new-tab -- CMD / Panes: zellij run CMD
- Mode C (claude) → Tabs/Panes: claude session subsection
- Mode D (issue) → Tabs/Panes: start-issue subsection

### New capabilities

- **Introspection**: list-tabs --json, list-panes --json, current-tab-info --json
- **Navigation**: go-to-tab-name, move-focus, focus-next/previous-pane
- **Management**: close-tab, close-pane, rename-tab, rename-pane, resize
- **Session control**: switch-session, list-sessions, kill-session
- **Layout**: dump-layout (save), override-layout (restore)
- **Edit**: open files in $EDITOR pane with line number support
- **Floating**: toggle, show/hide, pin floating panes
- **Input**: send-keys for keyboard shortcuts, paste, dump-screen

## Version Bump

Plugin version: 1.4.3 -> 2.0.0 (major — skill restructured, commands renamed conceptually)

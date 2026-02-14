#!/bin/bash
# lint_no_emoji.sh — Check plugin files for supplementary plane characters (emoji U+10000+)
#
# These characters cause "no low surrogate in string" API errors when
# Claude Code serializes large payloads containing surrogate pairs.
#
# Usage:
#   ./scripts/lint_no_emoji.sh                    # Check all plugins
#   ./scripts/lint_no_emoji.sh task-router         # Check one plugin
#   ./scripts/lint_no_emoji.sh --fix task-router   # Auto-remove emoji
#
# Exit codes:
#   0 — no emoji found
#   1 — emoji found (or error)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FIX_MODE=false
TARGET=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --fix) FIX_MODE=true; shift ;;
    *) TARGET="$1"; shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

python3 -u - "$FIX_MODE" "$TARGET" <<'PYTHON_SCRIPT'
import os
import sys
import unicodedata

fix_mode = sys.argv[1].lower() == "true"
target = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else ""

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
NC = "\033[0m"

# Find plugin directories (contain .claude-plugin/plugin.json)
plugins = []
for entry in sorted(os.listdir(".")):
    plugin_json = os.path.join(entry, ".claude-plugin", "plugin.json")
    if os.path.isfile(plugin_json):
        if target and entry != target:
            continue
        plugins.append(entry)

if target and not plugins:
    print(f"{RED}Plugin not found: {target}{NC}")
    sys.exit(1)

total_issues = 0
total_files = 0
total_fixed = 0
failed_plugins = 0

EXTENSIONS = {".md", ".json", ".yaml", ".yml", ".txt"}

for plugin in plugins:
    plugin_issues = []

    for root, dirs, files in os.walk(plugin):
        # Skip hidden dirs except .claude-plugin
        dirs[:] = [d for d in dirs if not d.startswith(".") or d == ".claude-plugin"]
        for fname in sorted(files):
            _, ext = os.path.splitext(fname)
            if ext.lower() not in EXTENSIONS:
                continue

            filepath = os.path.join(root, fname)
            total_files += 1

            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()

            file_issues = []
            for i, ch in enumerate(content):
                cp = ord(ch)
                # Supplementary plane: U+10000 and above (require surrogate pairs in UTF-16)
                if cp >= 0x10000:
                    line_num = content[:i].count("\n") + 1
                    col = i - content[:i].rfind("\n")
                    name = unicodedata.name(ch, "UNKNOWN")
                    file_issues.append({
                        "pos": i,
                        "line": line_num,
                        "col": col,
                        "char": ch,
                        "codepoint": cp,
                        "name": name,
                    })

            if file_issues:
                plugin_issues.append((filepath, file_issues))
                total_issues += len(file_issues)

    if plugin_issues:
        failed_plugins += 1
        print(f"\n{RED}[FAIL]{NC} {plugin}/")
        for filepath, issues in plugin_issues:
            relpath = os.path.relpath(filepath)
            for issue in issues:
                print(
                    f"  {relpath}:{issue['line']}:{issue['col']} "
                    f"U+{issue['codepoint']:04X} {issue['name']} ({issue['char']})"
                )

            if fix_mode:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
                cleaned = "".join(ch for ch in content if ord(ch) < 0x10000)
                if cleaned != content:
                    with open(filepath, "w", encoding="utf-8") as f:
                        f.write(cleaned)
                    total_fixed += len(issues)
                    print(f"  {GREEN}-> fixed: removed {len(issues)} character(s){NC}")
    else:
        print(f"{GREEN}[OK]{NC}   {plugin}/")

# Summary
print(f"\n{BLUE}{'=' * 50}{NC}")
print(f"Plugins checked: {len(plugins)}")
print(f"Files scanned:   {total_files}")

if total_issues == 0:
    print(f"{GREEN}No supplementary plane characters found.{NC}")
    sys.exit(0)
else:
    print(f"{RED}Found {total_issues} supplementary plane character(s) in {failed_plugins} plugin(s).{NC}")
    if fix_mode:
        print(f"{GREEN}Fixed {total_fixed} character(s).{NC}")
        sys.exit(0)
    else:
        print(f"{YELLOW}Run with --fix to auto-remove them.{NC}")
        sys.exit(1)
PYTHON_SCRIPT

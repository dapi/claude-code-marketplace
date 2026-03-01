#!/bin/bash
# lint_no_surrogates.sh — Check bash scripts for bytes that could produce unpaired surrogates
#
# Claude Code has a known bug (#16294) where unpaired UTF-16 surrogates in
# tool output crash the session with "no low surrogate in string" API error.
#
# Valid UTF-8 files should never contain surrogate codepoints (U+D800-U+DFFF).
# This script checks all .sh files in plugins for invalid UTF-8 sequences
# that encode surrogate codepoints.
#
# Usage:
#   ./scripts/lint_no_surrogates.sh              # Check all plugins
#   ./scripts/lint_no_surrogates.sh plugin-name   # Check one plugin
#
# Exit codes:
#   0 — no issues found
#   1 — issues found (or error)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET="${1:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

total_issues=0
total_files=0
failed_plugins=0

# Find plugin directories
for entry in $(ls -d */); do
  entry="${entry%/}"
  [[ -f "$entry/.claude-plugin/plugin.json" ]] || continue
  [[ -z "$TARGET" || "$entry" == "$TARGET" ]] || continue

  plugin_issues=0

  while IFS= read -r -d '' shfile; do
    total_files=$((total_files + 1))

    # Check for invalid UTF-8 (includes surrogate codepoints)
    # iconv will fail on invalid UTF-8 sequences
    if ! iconv -f UTF-8 -t UTF-8 "$shfile" >/dev/null 2>&1; then
      echo -e "  ${RED}[FAIL]${NC} $shfile — contains invalid UTF-8 (possible surrogate codepoints)"
      plugin_issues=$((plugin_issues + 1))
      total_issues=$((total_issues + 1))
      continue
    fi

    # Check for literal surrogate codepoints encoded as UTF-8 (3-byte sequences ED A0-BF xx)
    # U+D800..U+DFFF encoded in UTF-8: ED [A0-BF] [80-BF]
    if LC_ALL=C grep -Pn $'\\xED[\\xA0-\\xBF][\\x80-\\xBF]' "$shfile" >/dev/null 2>&1; then
      echo -e "  ${RED}[FAIL]${NC} $shfile — contains UTF-8 encoded surrogate codepoints (U+D800-U+DFFF)"
      plugin_issues=$((plugin_issues + 1))
      total_issues=$((total_issues + 1))
      continue
    fi
  done < <(find "$entry" -name '*.sh' -type f -print0)

  if [[ $plugin_issues -gt 0 ]]; then
    failed_plugins=$((failed_plugins + 1))
  else
    echo -e "${GREEN}[OK]${NC}   $entry/"
  fi
done

if [[ -n "$TARGET" && $total_files -eq 0 ]]; then
  echo -e "${RED}Plugin not found: $TARGET${NC}"
  exit 1
fi

# Summary
echo ""
echo -e "${BLUE}==================================================${NC}"
echo "Plugins checked: $((failed_plugins + $(ls -d */  2>/dev/null | while read d; do d="${d%/}"; [[ -f "$d/.claude-plugin/plugin.json" ]] && [[ -z "$TARGET" || "$d" == "$TARGET" ]] && echo ok; done | wc -l)))"
echo "Shell scripts scanned: $total_files"

if [[ $total_issues -eq 0 ]]; then
  echo -e "${GREEN}No invalid UTF-8 or surrogate codepoints found.${NC}"
  exit 0
else
  echo -e "${RED}Found $total_issues issue(s) in $failed_plugins plugin(s).${NC}"
  exit 1
fi

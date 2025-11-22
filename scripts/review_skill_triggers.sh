#!/bin/bash
# review_skill_triggers.sh
# Automated skill trigger quality checker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Scoring variables
SCORE=0
MAX_SCORE=100

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Skill Trigger Quality Review Tool        ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo ""

# Usage
if [ $# -eq 0 ]; then
  echo "Usage: $0 <plugin-name>/<skill-name>"
  echo "Example: $0 dev-tools/bugsnag"
  echo ""
  echo "Options:"
  echo "  --all    Review all skills in marketplace"
  exit 1
fi

# Review all skills if --all flag
if [ "$1" == "--all" ]; then
  echo "Reviewing all skills..."
  SKILLS=$(find . -type f -name "SKILL.md" -not -path "*/node_modules/*")

  for SKILL_FILE in $SKILLS; do
    SKILL_PATH=$(dirname "$SKILL_FILE" | sed 's|^\./||')
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    bash "$0" "$SKILL_PATH"
  done
  exit 0
fi

# Parse arguments
PLUGIN_SKILL=$1
PLUGIN=$(echo "$PLUGIN_SKILL" | cut -d'/' -f1)
SKILL=$(echo "$PLUGIN_SKILL" | cut -d'/' -f2)

SKILL_FILE="$PLUGIN/skills/$SKILL/SKILL.md"
EXAMPLES_FILE="$PLUGIN/skills/$SKILL/TRIGGER_EXAMPLES.md"

# Check if skill exists
if [ ! -f "$SKILL_FILE" ]; then
  echo -e "${RED}❌ Skill file not found: $SKILL_FILE${NC}"
  exit 1
fi

echo -e "${BLUE}Reviewing skill: ${GREEN}$PLUGIN/$SKILL${NC}"
echo -e "${BLUE}File: $SKILL_FILE${NC}"
echo ""

# ============================================================
# TEST 1: File Structure (10 points)
# ============================================================
echo -e "${YELLOW}[1/10] File Structure${NC}"

if grep -q "^---$" "$SKILL_FILE"; then
  echo -e "  ${GREEN}✅ YAML frontmatter present${NC}"
  SCORE=$((SCORE + 5))
else
  echo -e "  ${RED}❌ Missing YAML frontmatter${NC}"
fi

if grep -q "^name:" "$SKILL_FILE" && grep -q "^description:" "$SKILL_FILE"; then
  echo -e "  ${GREEN}✅ Required fields (name, description) present${NC}"
  SCORE=$((SCORE + 5))
else
  echo -e "  ${RED}❌ Missing required fields${NC}"
fi

# ============================================================
# TEST 2: Universal Trigger (15 points)
# ============================================================
echo -e "${YELLOW}[2/10] Universal Trigger Pattern${NC}"

if grep -qi "UNIVERSAL TRIGGER" "$SKILL_FILE"; then
  echo -e "  ${GREEN}✅ Universal trigger pattern defined${NC}"
  SCORE=$((SCORE + 15))
elif grep -qi "Common patterns" "$SKILL_FILE"; then
  echo -e "  ${YELLOW}⚠️  Partial: Common patterns present but no UNIVERSAL TRIGGER${NC}"
  SCORE=$((SCORE + 8))
else
  echo -e "  ${RED}❌ No universal trigger pattern${NC}"
fi

# ============================================================
# TEST 3: Trigger Keyword Count (15 points)
# ============================================================
echo -e "${YELLOW}[3/10] Trigger Keyword Count${NC}"

# Extract TRIGGERS section
TRIGGERS=$(sed -n '/^  TRIGGERS:/,/^$/p' "$SKILL_FILE" | tail -n +2 | head -n -1)

if [ -n "$TRIGGERS" ]; then
  # Count keywords (comma-separated)
  KEYWORD_COUNT=$(echo "$TRIGGERS" | tr ',' '\n' | grep -v '^$' | wc -l)

  echo -e "  ${BLUE}ℹ️  Trigger keyword count: $KEYWORD_COUNT${NC}"

  if [ "$KEYWORD_COUNT" -ge 15 ] && [ "$KEYWORD_COUNT" -le 50 ]; then
    echo -e "  ${GREEN}✅ Optimal keyword count (15-50)${NC}"
    SCORE=$((SCORE + 15))
  elif [ "$KEYWORD_COUNT" -gt 50 ]; then
    echo -e "  ${YELLOW}⚠️  High keyword count (>50), consider simplification${NC}"
    SCORE=$((SCORE + 10))
  else
    echo -e "  ${RED}❌ Too few keywords (<15)${NC}"
    SCORE=$((SCORE + 5))
  fi
else
  echo -e "  ${RED}❌ TRIGGERS section not found or empty${NC}"
fi

# ============================================================
# TEST 4: Categorization (10 points)
# ============================================================
echo -e "${YELLOW}[4/10] Content Categorization${NC}"

# Check for emoji categories (📊, 🔍, ✅, etc.)
EMOJI_COUNT=$(grep -oE '[\x{1F300}-\x{1F9FF}]' "$SKILL_FILE" | wc -l || echo "0")

if [ "$EMOJI_COUNT" -ge 3 ]; then
  echo -e "  ${GREEN}✅ Content categorized with emoji (${EMOJI_COUNT} found)${NC}"
  SCORE=$((SCORE + 10))
elif [ "$EMOJI_COUNT" -gt 0 ]; then
  echo -e "  ${YELLOW}⚠️  Some categorization (${EMOJI_COUNT} emoji)${NC}"
  SCORE=$((SCORE + 5))
else
  echo -e "  ${RED}❌ No visual categorization${NC}"
fi

# ============================================================
# TEST 5: Multilingual Support (10 points)
# ============================================================
echo -e "${YELLOW}[5/10] Multilingual Support${NC}"

if grep -qE '[а-яА-Я]+' "$SKILL_FILE"; then
  echo -e "  ${GREEN}✅ Russian language support detected${NC}"
  SCORE=$((SCORE + 10))
else
  echo -e "  ${YELLOW}⚠️  English only (consider adding Russian)${NC}"
  SCORE=$((SCORE + 5))
fi

# ============================================================
# TEST 6: Action Verb Diversity (10 points)
# ============================================================
echo -e "${YELLOW}[6/10] Action Verb Diversity${NC}"

DESCRIPTION=$(sed -n '/^description:/,/^[a-z-]*:/p' "$SKILL_FILE")

# Count common action verbs
VERB_COUNT=0
for VERB in "get" "show" "list" "display" "retrieve" "fetch" "check" "analyze"; do
  if echo "$DESCRIPTION" | grep -qi "$VERB"; then
    VERB_COUNT=$((VERB_COUNT + 1))
  fi
done

echo -e "  ${BLUE}ℹ️  Action verbs found: $VERB_COUNT/8${NC}"

if [ "$VERB_COUNT" -ge 5 ]; then
  echo -e "  ${GREEN}✅ Good verb diversity (≥5)${NC}"
  SCORE=$((SCORE + 10))
elif [ "$VERB_COUNT" -ge 3 ]; then
  echo -e "  ${YELLOW}⚠️  Moderate diversity (3-4)${NC}"
  SCORE=$((SCORE + 5))
else
  echo -e "  ${RED}❌ Low verb diversity (<3)${NC}"
fi

# ============================================================
# TEST 7: Context Patterns (10 points)
# ============================================================
echo -e "${YELLOW}[7/10] Context Patterns${NC}"

CONTEXT_PATTERNS=0

# Check for "what in", "check", "from", etc.
if echo "$DESCRIPTION" | grep -qi "what.*in"; then
  CONTEXT_PATTERNS=$((CONTEXT_PATTERNS + 1))
fi
if echo "$DESCRIPTION" | grep -qi "check"; then
  CONTEXT_PATTERNS=$((CONTEXT_PATTERNS + 1))
fi
if echo "$DESCRIPTION" | grep -qi "from"; then
  CONTEXT_PATTERNS=$((CONTEXT_PATTERNS + 1))
fi

echo -e "  ${BLUE}ℹ️  Context patterns found: $CONTEXT_PATTERNS/3${NC}"

if [ "$CONTEXT_PATTERNS" -ge 2 ]; then
  echo -e "  ${GREEN}✅ Context patterns included${NC}"
  SCORE=$((SCORE + 10))
elif [ "$CONTEXT_PATTERNS" -eq 1 ]; then
  echo -e "  ${YELLOW}⚠️  Limited context patterns${NC}"
  SCORE=$((SCORE + 5))
else
  echo -e "  ${RED}❌ No context patterns${NC}"
fi

# ============================================================
# TEST 8: Test Examples Documentation (10 points)
# ============================================================
echo -e "${YELLOW}[8/10] Test Examples Documentation${NC}"

if [ -f "$EXAMPLES_FILE" ]; then
  echo -e "  ${GREEN}✅ TRIGGER_EXAMPLES.md exists${NC}"

  # Count examples
  EXAMPLE_COUNT=$(grep -cE '^-\s+".*"$' "$EXAMPLES_FILE" || echo "0")

  echo -e "  ${BLUE}ℹ️  Example count: $EXAMPLE_COUNT${NC}"

  if [ "$EXAMPLE_COUNT" -ge 20 ]; then
    echo -e "  ${GREEN}✅ Comprehensive examples (≥20)${NC}"
    SCORE=$((SCORE + 10))
  elif [ "$EXAMPLE_COUNT" -ge 10 ]; then
    echo -e "  ${YELLOW}⚠️  Moderate examples (10-19)${NC}"
    SCORE=$((SCORE + 7))
  else
    echo -e "  ${YELLOW}⚠️  Few examples (<10)${NC}"
    SCORE=$((SCORE + 4))
  fi
else
  echo -e "  ${RED}❌ TRIGGER_EXAMPLES.md not found${NC}"
fi

# ============================================================
# TEST 9: Description Length (5 points)
# ============================================================
echo -e "${YELLOW}[9/10] Description Length${NC}"

DESC_LENGTH=$(echo "$DESCRIPTION" | wc -c)

echo -e "  ${BLUE}ℹ️  Description length: $DESC_LENGTH chars${NC}"

if [ "$DESC_LENGTH" -ge 300 ] && [ "$DESC_LENGTH" -le 1200 ]; then
  echo -e "  ${GREEN}✅ Optimal length (300-1200 chars)${NC}"
  SCORE=$((SCORE + 5))
elif [ "$DESC_LENGTH" -gt 1200 ]; then
  echo -e "  ${YELLOW}⚠️  Long description (>1200 chars)${NC}"
  SCORE=$((SCORE + 3))
else
  echo -e "  ${RED}❌ Too short (<300 chars)${NC}"
fi

# ============================================================
# TEST 10: Negative Examples (10 points)
# ============================================================
echo -e "${YELLOW}[10/10] Negative Examples${NC}"

if [ -f "$EXAMPLES_FILE" ]; then
  if grep -q "Should NOT Activate" "$EXAMPLES_FILE" || grep -q "НЕ должны активировать" "$EXAMPLES_FILE"; then
    echo -e "  ${GREEN}✅ Negative examples documented${NC}"
    SCORE=$((SCORE + 10))
  else
    echo -e "  ${YELLOW}⚠️  No negative examples in TRIGGER_EXAMPLES.md${NC}"
    SCORE=$((SCORE + 5))
  fi
else
  echo -e "  ${RED}❌ Cannot check (TRIGGER_EXAMPLES.md missing)${NC}"
fi

# ============================================================
# FINAL SCORE
# ============================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}FINAL SCORE: ${GREEN}$SCORE/$MAX_SCORE${NC}"

# Rating
if [ "$SCORE" -ge 90 ]; then
  RATING="Excellent ⭐⭐⭐⭐⭐"
  COLOR=$GREEN
elif [ "$SCORE" -ge 75 ]; then
  RATING="Good ⭐⭐⭐⭐"
  COLOR=$GREEN
elif [ "$SCORE" -ge 60 ]; then
  RATING="Acceptable ⭐⭐⭐"
  COLOR=$YELLOW
else
  RATING="Needs Improvement ⭐⭐"
  COLOR=$RED
fi

echo -e "${BLUE}RATING: ${COLOR}$RATING${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Recommendations
echo ""
echo -e "${YELLOW}📝 RECOMMENDATIONS:${NC}"

if [ "$SCORE" -lt 90 ]; then
  if ! grep -qi "UNIVERSAL TRIGGER" "$SKILL_FILE"; then
    echo -e "  ${YELLOW}→ Add UNIVERSAL TRIGGER pattern to description${NC}"
  fi

  if [ "$KEYWORD_COUNT" -lt 15 ]; then
    echo -e "  ${YELLOW}→ Add more trigger keywords (target: 15-50)${NC}"
  fi

  if [ ! -f "$EXAMPLES_FILE" ]; then
    echo -e "  ${YELLOW}→ Create TRIGGER_EXAMPLES.md with 20+ examples${NC}"
  fi

  if ! grep -qE '[а-яА-Я]+' "$SKILL_FILE"; then
    echo -e "  ${YELLOW}→ Add Russian language support${NC}"
  fi

  if [ "$VERB_COUNT" -lt 5 ]; then
    echo -e "  ${YELLOW}→ Add more action verbs (get, show, list, etc.)${NC}"
  fi
else
  echo -e "  ${GREEN}✅ No major improvements needed!${NC}"
fi

echo ""
echo -e "${BLUE}For detailed guidelines, see:${NC}"
echo -e "${BLUE}  SKILL_TRIGGER_REVIEW_CHECKLIST.md${NC}"
echo ""

# Exit code based on score
if [ "$SCORE" -ge 60 ]; then
  exit 0
else
  exit 1
fi

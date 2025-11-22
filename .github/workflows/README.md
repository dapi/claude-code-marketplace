# GitHub Actions Workflows

Automated quality checks for Claude Code marketplace skills.

---

## 📋 Available Workflows

### 1. Skill Quality Check (`skill-quality-check.yml`)

**Triggers:**
- Pull requests that modify `SKILL.md` or `TRIGGER_EXAMPLES.md`
- Pushes to `master`/`main` branch with skill changes

**What it does:**
1. Detects changed skill files
2. Runs `review_skill_triggers.sh` on each changed skill
3. Posts results as PR comment (for PRs)
4. Blocks merge if any skill scores <60/100

**Quality Gate:**
- ✅ Pass: All skills ≥60/100
- ❌ Fail: Any skill <60/100 (blocks merge)

**Example Output:**
```
## 🔍 Skill Quality Review

## dev-tools/bugsnag

Score: 93/100 | Rating: ⭐⭐⭐⭐⭐ Excellent | Status: ✅ PASS

<details>
<summary>Review Details</summary>

[Full review output...]
</details>

✅ Score 93/100 meets quality standards
```

---

### 2. Full Skill Review (`full-skill-review.yml`)

**Triggers:**
- Changes to review script or documentation:
  - `scripts/review_skill_triggers.sh`
  - `SKILL_TRIGGER_REVIEW_CHECKLIST.md`
  - `SKILL_TRIGGER_QUICK_REFERENCE.md`
- Manual trigger via GitHub UI

**What it does:**
1. Finds ALL skills in marketplace
2. Reviews each skill with quality checker
3. Generates comprehensive statistics
4. Uploads full report as artifact
5. Fails if any skill <60/100

**Statistics Generated:**
- Total skills reviewed
- Pass/fail breakdown
- Quality distribution (Excellent/Good/Acceptable/Poor)

**Example Summary:**
```
| Metric | Count |
|--------|-------|
| Total Skills | 3 |
| ✅ Passed (≥60) | 3 |
| ❌ Failed (<60) | 0 |
| ⭐⭐⭐⭐⭐ Excellent | 2 |
| ⭐⭐⭐⭐ Good | 1 |
| ⭐⭐⭐ Acceptable | 0 |
| ⭐⭐ Needs Work | 0 |
```

---

## 🎯 Quality Standards

### Rating Bands

- **90-100**: ⭐⭐⭐⭐⭐ Excellent (production ready)
- **75-89**: ⭐⭐⭐⭐ Good (minor improvements recommended)
- **60-74**: ⭐⭐⭐ Acceptable (needs refinement)
- **<60**: ⭐⭐ Needs improvement (blocks merge)

### Quality Metrics (100 points total)

1. **File Structure** (10 pts) - Valid YAML frontmatter
2. **Universal Trigger** (15 pts) - Defined universal pattern
3. **Keyword Count** (15 pts) - 15-50 optimal keywords
4. **Categorization** (10 pts) - Visual categories with emoji
5. **Multilingual** (10 pts) - EN + RU support
6. **Verb Diversity** (10 pts) - 5+ action verbs
7. **Context Patterns** (10 pts) - "what in", "check", "from"
8. **Test Examples** (10 pts) - TRIGGER_EXAMPLES.md exists
9. **Description Length** (5 pts) - 300-1200 chars optimal
10. **Negative Examples** (10 pts) - What NOT to activate

---

## 🚀 Usage

### For Pull Requests

**Automatic**: Quality check runs on every PR touching skills.

**Manual Fix Workflow**:
```bash
# 1. Make changes to skill
vim dev-tools/skills/my-skill/SKILL.md

# 2. Test locally
./scripts/review_skill_triggers.sh dev-tools/my-skill

# 3. Iterate until score ≥60 (ideally ≥75)

# 4. Commit and push
git add dev-tools/skills/my-skill/SKILL.md
git commit -m "Improve my-skill triggers (75/100)"
git push

# 5. Check PR - quality check runs automatically
# 6. Review bot comment for results
# 7. Merge when all checks pass ✅
```

### Manual Full Review

**Trigger via GitHub UI**:
1. Go to Actions tab
2. Select "Full Skill Review"
3. Click "Run workflow"
4. Wait for results
5. Download `full-skill-review-results.txt` artifact

**Or via `gh` CLI**:
```bash
# Trigger workflow
gh workflow run full-skill-review.yml

# Wait and check status
gh run list --workflow=full-skill-review.yml

# Download results
gh run download <run-id> -n full-skill-review-results
```

---

## 📊 Artifacts

### PR Comment (skill-quality-check)

Posted automatically on PRs with:
- Individual skill scores
- Expandable review details
- Quality standards reference
- Links to documentation

**Retention**: Until PR is closed/merged

### Review Results File (both workflows)

**Format**: Markdown file with:
- Per-skill review details
- Scores and ratings
- Recommendations
- Summary statistics

**Retention**:
- PR artifacts: 30 days
- Full review: 90 days

**Download**:
```bash
# Via GitHub UI
Actions → Workflow run → Artifacts section

# Via gh CLI
gh run download <run-id>
```

---

## 🔧 Configuration

### Minimum Score Threshold

**Current**: 60/100

**To change**: Edit workflow files
```yaml
MIN_SCORE=60  # Change this value
```

**Recommendations**:
- **60**: Minimum viable quality (current)
- **75**: Production-ready standard (recommended)
- **90**: Excellence standard (strict)

### Triggers

**skill-quality-check.yml**:
```yaml
on:
  pull_request:
    paths:
      - '**/skills/**/SKILL.md'
      - '**/skills/**/TRIGGER_EXAMPLES.md'
```

**full-skill-review.yml**:
```yaml
on:
  push:
    paths:
      - 'scripts/review_skill_triggers.sh'
      - 'SKILL_TRIGGER_REVIEW_CHECKLIST.md'
```

Add/remove paths as needed.

---

## 🐛 Troubleshooting

### Workflow Not Triggering

**Check**:
1. File path matches trigger patterns
2. Branch is `master` or `main`
3. GitHub Actions enabled in repo settings

**Debug**:
```bash
# View workflow files
cat .github/workflows/*.yml

# Check recent runs
gh run list
```

### Review Script Fails

**Common issues**:
1. Script not executable → `chmod +x scripts/review_skill_triggers.sh`
2. Skill path incorrect → Use `plugin-name/skill-name` format
3. Missing files → Ensure SKILL.md exists

**Debug locally**:
```bash
# Test script directly
./scripts/review_skill_triggers.sh dev-tools/bugsnag

# Check script permissions
ls -l scripts/review_skill_triggers.sh

# Verify skill file exists
ls -l dev-tools/skills/bugsnag/SKILL.md
```

### Low Score Investigation

**Steps**:
1. Read review output in PR comment or artifact
2. Check "RECOMMENDATIONS" section
3. Follow guidance in SKILL_TRIGGER_REVIEW_CHECKLIST.md
4. Re-run locally after fixes

**Quick wins** (easiest improvements):
- Add TRIGGER_EXAMPLES.md (+10 pts)
- Add multilingual triggers (+10 pts)
- Add universal trigger pattern (+15 pts)
- Add 2-3 more action verbs (+5-10 pts)

---

## 📚 Related Documentation

- [SKILL_TRIGGER_REVIEW_CHECKLIST.md](../../SKILL_TRIGGER_REVIEW_CHECKLIST.md) - Comprehensive review guide
- [SKILL_TRIGGER_QUICK_REFERENCE.md](../../SKILL_TRIGGER_QUICK_REFERENCE.md) - Quick reference card
- [scripts/README.md](../../scripts/README.md) - Review script documentation
- [CLAUDE.md](../../CLAUDE.md) - Developer guidelines

---

## 🎓 Best Practices

### Before Creating PR

```bash
# 1. Review locally
./scripts/review_skill_triggers.sh my-plugin/my-skill

# 2. Aim for ≥75/100 (Good or better)

# 3. Create TRIGGER_EXAMPLES.md if missing

# 4. Test manually with 5 examples

# 5. Commit only when passing
```

### During PR Review

1. **Check bot comment** for automated feedback
2. **Download artifact** for full details if needed
3. **Fix issues** based on recommendations
4. **Re-push** to trigger re-check
5. **Iterate** until all checks pass

### After Merge

- Monitor full review workflow results
- Track quality trends over time
- Update standards if needed

---

## 🚧 Future Enhancements

Planned improvements:

- [ ] JSON output format for programmatic parsing
- [ ] Slack/Discord notifications for failed reviews
- [ ] Trend analysis (score history tracking)
- [ ] Auto-fix suggestions via PR comments
- [ ] Custom quality gates per plugin
- [ ] Integration with semantic versioning

---

## 📞 Support

**Issues with workflows?**
- Check [Troubleshooting](#-troubleshooting) section
- Review [GitHub Actions logs](../../actions)
- Open issue with `ci` label

**Questions about quality standards?**
- See [SKILL_TRIGGER_REVIEW_CHECKLIST.md](../../SKILL_TRIGGER_REVIEW_CHECKLIST.md)
- Review reference implementation: [dev-tools/skills/bugsnag](../../dev-tools/skills/bugsnag)

---

**Version**: 1.0
**Last Updated**: 2025-11-22
**Maintained by**: Claude Code Marketplace Team

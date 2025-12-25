---
name: repo-recap
description: Generate a 2025 year-in-review visualization for a repository. Use when user asks for "repo recap", "年間レポート", "yearly summary", "2025 recap", or wants to see repository statistics and contributions. (user)
---

# Repo Recap 2025 - Repository Year in Review Generator

You are generating a beautiful, interactive HTML visualization summarizing a repository's 2025 activity.

## Overview

This skill creates a standalone HTML file with:
- Contribution heatmap (GitHub-style calendar)
- Cumulative contribution graphs
- Time-of-day analysis (when do you code?)
- Commit message analysis (word cloud, emoji ranking)
- Achievement badges
- Hot moments (popular PRs/Issues)
- Top contributors with GitHub avatars
- Fun statistics

## Step 1: Gather Repository Data

Run these commands to collect all necessary data:

```bash
# Basic info
REPO_NAME=$(basename $(git rev-parse --show-toplevel))
YEAR="2025"

# Daily commits for heatmap
git log --since="${YEAR}-01-01" --until="${YEAR}-12-31" --format="%ad" --date=short 2>/dev/null | sort | uniq -c | awk '{print "{\"date\":\"" $2 "\",\"count\":" $1 "}"}' | paste -sd "," - | sed 's/^/[/' | sed 's/$/]/'

# Hourly distribution
git log --since="${YEAR}-01-01" --until="${YEAR}-12-31" --format="%H" 2>/dev/null | sort | uniq -c | awk '{print "{\"hour\":" $2 ",\"count\":" $1 "}"}' | paste -sd "," - | sed 's/^/[/' | sed 's/$/]/'

# Day of week distribution
git log --since="${YEAR}-01-01" --until="${YEAR}-12-31" --format="%u" 2>/dev/null | sort | uniq -c | awk '{print "{\"day\":" $2 ",\"count\":" $1 "}"}' | paste -sd "," - | sed 's/^/[/' | sed 's/$/]/'

# Contributors with commit counts
git shortlog -sne --since="${YEAR}-01-01" --until="${YEAR}-12-31" 2>/dev/null | head -20 | awk -F'\t' '{gsub(/^[ \t]+/, "", $1); split($2, a, " <"); print "{\"commits\":" $1 ",\"name\":\"" a[1] "\",\"email\":\"" a[2] }' | sed 's/<$/"}/' | paste -sd "," - | sed 's/^/[/' | sed 's/$/]/'

# Commit messages for analysis
git log --since="${YEAR}-01-01" --until="${YEAR}-12-31" --format="%s" 2>/dev/null

# Lines added/removed per month
for month in $(seq -w 1 12); do
  added=$(git log --since="${YEAR}-${month}-01" --until="${YEAR}-${month}-31" --numstat 2>/dev/null | awk '{add+=$1} END {print add+0}')
  removed=$(git log --since="${YEAR}-${month}-01" --until="${YEAR}-${month}-31" --numstat 2>/dev/null | awk '{del+=$2} END {print del+0}')
  commits=$(git log --since="${YEAR}-${month}-01" --until="${YEAR}-${month}-31" --oneline 2>/dev/null | wc -l | tr -d ' ')
  echo "{\"month\":${month},\"added\":${added},\"removed\":${removed},\"commits\":${commits}}"
done | paste -sd "," - | sed 's/^/[/' | sed 's/$/]/'

# Most changed files
git log --since="${YEAR}-01-01" --until="${YEAR}-12-31" --name-only --format="" 2>/dev/null | sort | uniq -c | sort -rn | head -10

# File types/languages
git ls-files 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -10

# Streak calculation (longest consecutive days)
git log --since="${YEAR}-01-01" --until="${YEAR}-12-31" --format="%ad" --date=short 2>/dev/null | sort -u

# PR and Issue stats (if gh CLI available)
gh pr list --state all --search "created:${YEAR}-01-01..${YEAR}-12-31" --json number,title,author,comments,additions,deletions,changedFiles --limit 100 2>/dev/null || echo "[]"
gh issue list --state all --search "created:${YEAR}-01-01..${YEAR}-12-31" --json number,title,author,comments --limit 100 2>/dev/null || echo "[]"
```

## Step 2: Generate HTML

Create a file named `repo-recap-2025.html` in the repository root using the template below. Replace the placeholder data with actual collected data.

### HTML Template Structure

The HTML should include:

1. **Head Section**
   - Tailwind CSS via CDN
   - Chart.js via CDN
   - canvas-confetti via CDN
   - Custom CSS for animations and glass morphism

2. **Hero Section**
   - Repository name with gradient text
   - Year badge
   - Top 3 contributors with GitHub avatars
   - Confetti animation on load

3. **Stats Cards**
   - Total commits
   - Total PRs
   - Total Issues
   - Contributors count
   - Lines added/removed
   - Files changed

4. **Contribution Heatmap**
   - GitHub-style calendar grid
   - Color gradient from light to dark
   - Tooltip on hover showing date and count

5. **Time Analysis**
   - 24-hour radial chart
   - Day of week bar chart
   - Night owl / Early bird badge

6. **Cumulative Graph**
   - Monthly commits line chart
   - Lines added/removed area chart
   - Animated on scroll

7. **Commit Message Analysis**
   - Word frequency visualization
   - Emoji ranking
   - Conventional commits breakdown (feat/fix/docs/etc)
   - Longest/shortest message

8. **Achievement Badges**
   - Unlocked achievements with icons
   - Locked achievements grayed out
   - Hover effects

9. **Hot Moments**
   - Most commented PRs/Issues
   - Biggest changes
   - Most reactions

10. **Leaderboard**
    - Top contributors with avatars
    - Commit counts and bars
    - Rank badges (gold/silver/bronze)

11. **Fun Stats**
    - Weekend warrior percentage
    - Late night commits
    - Longest streak
    - Coffee cup equivalent

## Step 3: Template Reference

Use the template from: `skills/repo-recap/templates/recap.html`

Read the template file and replace the following placeholders with actual data:

- `{{REPO_NAME}}` - Repository name
- `{{YEAR}}` - Year (2025)
- `{{TOTAL_COMMITS}}` - Total commit count
- `{{TOTAL_PRS}}` - Total PR count
- `{{TOTAL_ISSUES}}` - Total issue count
- `{{CONTRIBUTORS_COUNT}}` - Number of contributors
- `{{LINES_ADDED}}` - Total lines added
- `{{LINES_REMOVED}}` - Total lines removed
- `{{DAILY_COMMITS_JSON}}` - JSON array of daily commits
- `{{HOURLY_DATA_JSON}}` - JSON array of hourly distribution
- `{{WEEKLY_DATA_JSON}}` - JSON array of day-of-week distribution
- `{{MONTHLY_DATA_JSON}}` - JSON array of monthly stats
- `{{CONTRIBUTORS_JSON}}` - JSON array of contributors
- `{{TOP_FILES_JSON}}` - JSON array of most changed files
- `{{LANGUAGES_JSON}}` - JSON array of language distribution
- `{{COMMIT_MESSAGES_JSON}}` - JSON array of commit messages for analysis
- `{{PRS_JSON}}` - JSON array of PRs
- `{{ISSUES_JSON}}` - JSON array of issues
- `{{ACHIEVEMENTS_JSON}}` - JSON array of unlocked achievements
- `{{LONGEST_STREAK}}` - Longest consecutive commit days
- `{{NIGHT_OWL_PERCENT}}` - Percentage of commits between 0-4am
- `{{EARLY_BIRD_PERCENT}}` - Percentage of commits between 5-8am
- `{{WEEKEND_PERCENT}}` - Percentage of weekend commits

## Step 4: Open in Browser

After generating the HTML file, inform the user:

```
repo-recap-2025.html を生成しました！

ブラウザで開く:
  open repo-recap-2025.html   # macOS
  xdg-open repo-recap-2025.html   # Linux
  start repo-recap-2025.html   # Windows

お楽しみください！ 🎉
```

## Notes

- GitHub avatars are fetched from `https://github.com/{username}.png`
- For private repos without gh CLI, PR/Issue sections will show "Data not available"
- All data is embedded in the HTML - no external API calls needed after generation
- The HTML works offline once generated

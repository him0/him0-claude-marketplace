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

**重要**: 以下の3つのコマンドを**並列で**実行してください。これにより実行時間を大幅に短縮できます。

```bash
# === コマンド1: 基本コミットデータ (1回のgit logで全データ取得) ===
git log --since="2025-01-01" --until="2025-12-31" --format="COMMIT_START%n%ad%n%aN%n%s%nCOMMIT_END" --date=format:"%Y-%m-%d %H %u" 2>/dev/null

# === コマンド2: PR/Issue データ (並列実行可) ===
gh pr list --state all --search "created:2025-01-01..2025-12-31" --json number,title,author,comments,additions,deletions,changedFiles --limit 100 2>/dev/null || echo "[]"
gh issue list --state all --search "created:2025-01-01..2025-12-31" --json number,title,author,comments --limit 100 2>/dev/null || echo "[]"

# === コマンド3: リポジトリ名 ===
basename $(git rev-parse --show-toplevel)
```

### データ取得

git logでパイプ区切りのシンプルな形式で取得:

```bash
git log --since="2025-01-01" --until="2025-12-31" --format="%ad|%aN|%s" --date=format:"%Y-%m-%d|%H|%u" 2>/dev/null
```

出力例:
```
2025-12-25|14|4|Hiroki|fix: bug
2025-12-24|09|3|Jane|feat: new feature
```

### データ変換

上記の出力をClaude Codeが以下のJSON形式に変換:

```json
[
  {"date": "2025-12-25", "hour": 14, "day": 4, "name": "Hiroki", "message": "fix: bug"},
  ...
]
```

**重要**: awkやsedを使わず、Claude Code自身がこの変換を行ってください。

テンプレート内のJavaScriptが `rawCommits` から以下を自動計算:
- dailyCommits, hourlyData, weeklyData, monthlyData
- contributors, contributorCommits, commitMessages
- longestStreak, stats

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
   - Each achievement shows contributor avatars who earned it
   - Achievements without earners are grayed out
   - Hover effects with contributor names

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

**プレースホルダーは4つだけ！** テンプレート内で全データを自動計算します:

- `{{REPO_NAME}}` - リポジトリ名
- `{{YEAR}}` - 年 (2025)
- `{{RAW_COMMITS_JSON}}` - コミットデータ配列 `[{date, hour, day, name, message}, ...]`
- `{{PRS_JSON}}` - PRデータ (gh pr listの出力)
- `{{ISSUES_JSON}}` - Issueデータ (gh issue listの出力、なければ `[]`)

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

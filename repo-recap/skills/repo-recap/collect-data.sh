#!/bin/bash
# Repo Recap Data Collector
# Usage: ./collect-data.sh [year] [full|h1|h2] > recap-data.json
#   full: 通年 (デフォルト) / h1: 上半期 (1-6月) / h2: 下半期 (7-12月)
#
# git のコミットログ、GitHub の PR/Issue、コントリビューター名寄せマップを
# 1つの JSON にまとめて標準出力に出す。generate-recap.sh にパイプして使う。
set -euo pipefail

YEAR="${1:-$(date +%Y)}"
PERIOD="${2:-full}"

case "$PERIOD" in
  h1|H1)   SINCE="${YEAR}-01-01"; UNTIL="${YEAR}-06-30"; LABEL="First Half Review" ;;
  h2|H2)   SINCE="${YEAR}-07-01"; UNTIL="${YEAR}-12-31"; LABEL="Second Half Review" ;;
  full)    SINCE="${YEAR}-01-01"; UNTIL="${YEAR}-12-31"; LABEL="Year in Review" ;;
  *) echo "Error: unknown period '$PERIOD' (use full, h1, or h2)" >&2; exit 1 ;;
esac

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required" >&2; exit 1; }
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "Error: not a git repository" >&2; exit 1; }

REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

# --- コミットログ収集 ---
# フィールド区切りに ASCII unit separator (0x1f) を使う。コミットメッセージには現れない。
US=$(printf '\037')
COMMITS_JSON=$(git log --since="$SINCE" --until="${UNTIL} 23:59:59" \
    --format="%ad${US}%aN${US}%aE${US}%s" --date=format:"%Y-%m-%d${US}%H${US}%u" 2>/dev/null |
  jq -R -s --arg us "$US" '
    split("\n") | map(select(length > 0) | split($us) | {
      date:    .[0],
      hour:    (.[1] | tonumber),
      day:     (.[2] | tonumber),
      name:    .[3],
      email:   .[4],
      message: .[5]
    })')
COMMITS_JSON=${COMMITS_JSON:-[]}

# --- PR / Issue 収集 (gh が使えない・GitHub リポジトリでない場合は空配列) ---
# comments は gh のバージョンによって配列で返るため件数に正規化する
PRS_RAW=$(gh pr list --state all --search "created:${SINCE}..${UNTIL}" \
    --json number,title,author,comments,additions,deletions,changedFiles,createdAt \
    --limit 500 2>/dev/null || echo "[]")
PRS_JSON=$(printf '%s' "$PRS_RAW" | jq 'map(.comments = ((.comments // []) | if type == "array" then length else . end))' 2>/dev/null || echo "[]")

ISSUES_RAW=$(gh issue list --state all --search "created:${SINCE}..${UNTIL}" \
    --json number,title,author,comments,createdAt --limit 500 2>/dev/null || echo "[]")
ISSUES_JSON=$(printf '%s' "$ISSUES_RAW" | jq 'map(.comments = ((.comments // []) | if type == "array" then length else . end))' 2>/dev/null || echo "[]")

# --- 名寄せマップ (git author name -> GitHub username) ---
# 1) noreply メールアドレスからローカルで解決 (API 不要・高速)
EMAIL_ALIASES=$(printf '%s' "$COMMITS_JSON" | jq '
  [ .[] | select(.email | endswith("@users.noreply.github.com")) |
    { (.name): (.email | sub("@users\\.noreply\\.github\\.com$"; "") | sub("^[0-9]+\\+"; "")) } ]
  | add // {}')

# 2) 残りは GitHub API 1ページ分 (100件) だけで補完。全ページ取得はしない
API_ALIASES="{}"
NWO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [ -n "$NWO" ]; then
  API_ALIASES=$(gh api "repos/${NWO}/commits?since=${SINCE}T00:00:00Z&until=${UNTIL}T23:59:59Z&per_page=100" \
    --jq '[ .[] | select(.author.login != null) | { (.commit.author.name): .author.login } ] | add // {}' \
    2>/dev/null || echo "{}")
fi

ALIASES=$(jq -n --argjson a "$EMAIL_ALIASES" --argjson b "$API_ALIASES" '$a + $b')

# email は名寄せにしか使わないので出力からは落とす
COMMITS_JSON=$(printf '%s' "$COMMITS_JSON" | jq 'map(del(.email))')

jq -n \
  --arg repoName "$REPO_NAME" \
  --arg year "$YEAR" \
  --arg ptype "$PERIOD" \
  --arg since "$SINCE" \
  --arg until "$UNTIL" \
  --arg plabel "$LABEL" \
  --argjson rawCommits "$COMMITS_JSON" \
  --argjson prs "$PRS_JSON" \
  --argjson issues "$ISSUES_JSON" \
  --argjson contributorAliases "$ALIASES" \
  '{
    repoName: $repoName,
    year: $year,
    period: { type: $ptype, since: $since, until: $until, label: $plabel },
    rawCommits: $rawCommits,
    prs: $prs,
    issues: $issues,
    contributorAliases: $contributorAliases
  }'

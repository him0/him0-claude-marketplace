#!/usr/bin/env bash
# PR の状態・CI チェック・レビューコメントを一括取得して JSON で出力する
# Usage: check-pr.sh [--ci-only] [--reviews-only]
#
# 出力 JSON:
# {
#   "pr": { "number": 123, "branch": "feat/x", "state": "OPEN", "url": "..." },
#   "git_clean": true,
#   "ci": { "failed": [...], "pending": [...], "passed": [...] },
#   "reviews": { "comments": [...], "changes_requested": [...] },
#   "summary": { "status": "ACTION_NEEDED|PENDING|ALL_CLEAR", "ci_failed": 1, "ci_pending": 0, "review_comments": 2, "changes_requested": 0 }
# }

set -euo pipefail

CI_ONLY=false
REVIEWS_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --ci-only) CI_ONLY=true ;;
    --reviews-only) REVIEWS_ONLY=true ;;
  esac
done

# PR 情報
pr_json=$(gh pr view --json number,headRefName,state,url 2>/dev/null || echo "")
if [ -z "$pr_json" ] || [ "$pr_json" = "" ]; then
  echo '{"error": "no_pr", "message": "No PR found for current branch"}'
  exit 0
fi

pr_number=$(echo "$pr_json" | jq -r '.number')
owner_repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

# git status
if git diff --quiet && git diff --cached --quiet; then
  git_clean=true
else
  git_clean=false
fi

# CI チェック
ci_json="[]"
if [ "$REVIEWS_ONLY" = false ]; then
  ci_json=$(gh pr checks "$pr_number" --json name,state,link 2>/dev/null || echo "[]")
fi

ci_failed=$(echo "$ci_json" | jq '[.[] | select(.state == "FAILURE")]')
ci_pending=$(echo "$ci_json" | jq '[.[] | select(.state == "PENDING")]')
ci_passed=$(echo "$ci_json" | jq '[.[] | select(.state == "SUCCESS")]')

# レビューコメント
review_comments="[]"
changes_requested="[]"
if [ "$CI_ONLY" = false ]; then
  # インラインレビューコメント (トップレベルのみ)
  review_comments=$(gh api "repos/${owner_repo}/pulls/${pr_number}/comments" \
    --jq '[.[] | select(.in_reply_to_id == null) | {id, path, line, body, user: .user.login, created_at}]' 2>/dev/null || echo "[]")

  # CHANGES_REQUESTED レビュー
  changes_requested=$(gh pr view "$pr_number" --json reviews \
    --jq '[.reviews[] | select(.state == "CHANGES_REQUESTED") | {author: .author.login, body, state}]' 2>/dev/null || echo "[]")
fi

# サマリー計算
n_ci_failed=$(echo "$ci_failed" | jq 'length')
n_ci_pending=$(echo "$ci_pending" | jq 'length')
n_review_comments=$(echo "$review_comments" | jq 'length')
n_changes_requested=$(echo "$changes_requested" | jq 'length')

if [ "$n_ci_failed" -gt 0 ] || [ "$n_review_comments" -gt 0 ] || [ "$n_changes_requested" -gt 0 ]; then
  status="ACTION_NEEDED"
elif [ "$n_ci_pending" -gt 0 ]; then
  status="PENDING"
else
  status="ALL_CLEAR"
fi

# JSON 出力
jq -n \
  --argjson pr "$pr_json" \
  --argjson git_clean "$git_clean" \
  --argjson ci_failed "$ci_failed" \
  --argjson ci_pending "$ci_pending" \
  --argjson ci_passed "$ci_passed" \
  --argjson review_comments "$review_comments" \
  --argjson changes_requested "$changes_requested" \
  --arg status "$status" \
  --argjson n_ci_failed "$n_ci_failed" \
  --argjson n_ci_pending "$n_ci_pending" \
  --argjson n_review_comments "$n_review_comments" \
  --argjson n_changes_requested "$n_changes_requested" \
  '{
    pr: $pr,
    git_clean: $git_clean,
    ci: { failed: $ci_failed, pending: $ci_pending, passed: $ci_passed },
    reviews: { comments: $review_comments, changes_requested: $changes_requested },
    summary: { status: $status, ci_failed: $n_ci_failed, ci_pending: $n_ci_pending, review_comments: $n_review_comments, changes_requested: $n_changes_requested }
  }'

#!/usr/bin/env bash
# PR の状態・CI チェック・レビューコメントを一括取得して JSON で出力する
# Usage: check-pr.sh [--ci-only] [--reviews-only]
#
# 出力 JSON 構造:
# {
#   "pr": { "number": 123, "branch": "feat/x", "base": "main", "state": "OPEN", "url": "...", "auto_merge_enabled": false, "mergeable": "MERGEABLE|CONFLICTING|UNKNOWN" },
#   "git_clean": true,
#   "ci": {
#     "failed":  [{ "name": "...", "state": "FAILURE", "link": "...", "provider": "github-actions|circleci|other" }, ...],
#     "pending": [...],
#     "passed":  [...]
#   },
#   "reviews": {
#     "inline_comments":   [{ "id", "in_reply_to_id", "path", "line", "body", "user", "created_at", "claude_marker" }, ...],
#     "pr_reviews":        [{ "id", "author", "state", "body", "submitted_at", "claude_marker" }, ...],
#     "issue_comments":    [{ "id", "user", "body", "created_at", "claude_marker" }, ...],
#     "changes_requested": [{ "author", "state", "body" }, ...]
#   },
#   "summary": {
#     "status": "ACTION_NEEDED|PENDING|ALL_CLEAR",
#     "ci_failed": N, "ci_pending": N,
#     "inline_comments": N, "pr_reviews": N, "issue_comments": N, "changes_requested": N
#   }
# }
#
# pr.mergeable は GitHub が非同期で算出する merge 可能性。UNKNOWN は計算待ちで
# 一時的に返る (= ACTION_NEEDED にしない)。CONFLICTING は base branch との競合発生中。
#
# `claude_marker`: コメント本文の末尾が `<!-- claude-code:auto-fix -->` の場合 true。
# Claude 自身の返信判定に使う。最終的なスレッド単位の対応済み判定はスキル本体で行う。

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
pr_json=$(gh pr view --json number,headRefName,baseRefName,state,url,autoMergeRequest,mergeable 2>/dev/null || echo "")
if [ -z "$pr_json" ]; then
  echo '{"error": "no_pr", "message": "No PR found for current branch", "summary": {"status": "error"}}'
  exit 0
fi

pr_number=$(echo "$pr_json" | jq -r '.number')
owner_repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

# auto_merge_enabled / mergeable / base を露出した形に整形
pr_json=$(echo "$pr_json" | jq '{
  number,
  branch: .headRefName,
  base: .baseRefName,
  state,
  url,
  auto_merge_enabled: (.autoMergeRequest != null),
  mergeable: (.mergeable // "UNKNOWN")
}')

mergeable=$(echo "$pr_json" | jq -r '.mergeable')

# git status
if git diff --quiet && git diff --cached --quiet; then
  git_clean=true
else
  git_clean=false
fi

# CI チェック (provider を付与)
ci_json="[]"
if [ "$REVIEWS_ONLY" = false ]; then
  raw_ci=$(gh pr checks "$pr_number" --json name,state,link 2>/dev/null || echo "[]")
  ci_json=$(echo "$raw_ci" | jq '[
    .[] | . + {
      provider: (
        if (.link // "" | test("github.com/.+/actions/runs/")) then "github-actions"
        elif (.link // "" | test("circleci.com/")) then "circleci"
        else "other"
        end
      )
    }
  ]')
fi

ci_failed=$(echo "$ci_json"  | jq '[.[] | select(.state == "FAILURE")]')
ci_pending=$(echo "$ci_json" | jq '[.[] | select(.state == "PENDING")]')
ci_passed=$(echo "$ci_json"  | jq '[.[] | select(.state == "SUCCESS")]')

# レビュー / コメント 3 surface
inline_comments="[]"
pr_reviews="[]"
issue_comments="[]"
changes_requested="[]"

if [ "$CI_ONLY" = false ]; then
  # マーカー判定を JSON 側で付与する jq filter
  marker_filter='. + { claude_marker: ((.body // "") | sub("[[:space:]]+$"; "") | endswith("<!-- claude-code:auto-fix -->")) }'

  # インラインレビューコメント (スレッド情報含めて全件)
  inline_comments=$(gh api --paginate "repos/${owner_repo}/pulls/${pr_number}/comments" \
    --jq '[.[] | {id, in_reply_to_id, path, line, body, user: .user.login, created_at}]' 2>/dev/null \
    | jq "[.[] | $marker_filter]" 2>/dev/null || echo "[]")

  # PR レベルのレビュー (approve / request changes / 全体コメント)
  pr_reviews=$(gh pr view "$pr_number" --json reviews \
    --jq '[.reviews[] | {id, author: .author.login, state, body, submitted_at: .submittedAt}]' 2>/dev/null \
    | jq "[.[] | $marker_filter]" 2>/dev/null || echo "[]")

  # PR 会話コメント (issue comments)
  issue_comments=$(gh api --paginate "repos/${owner_repo}/issues/${pr_number}/comments" \
    --jq '[.[] | {id, user: .user.login, body, created_at}]' 2>/dev/null \
    | jq "[.[] | $marker_filter]" 2>/dev/null || echo "[]")

  # CHANGES_REQUESTED レビュー
  changes_requested=$(echo "$pr_reviews" | jq '[.[] | select(.state == "CHANGES_REQUESTED")]')
fi

# サマリー計算 (Claude マーカー付きはカウントから除外)
n_ci_failed=$(echo "$ci_failed" | jq 'length')
n_ci_pending=$(echo "$ci_pending" | jq 'length')
n_inline=$(echo "$inline_comments"  | jq '[.[] | select(.claude_marker | not)] | length')
n_pr_reviews=$(echo "$pr_reviews"   | jq '[.[] | select(.claude_marker | not) | select((.body // "") != "" or .state == "CHANGES_REQUESTED")] | length')
n_issue=$(echo "$issue_comments"    | jq '[.[] | select(.claude_marker | not)] | length')
n_changes_requested=$(echo "$changes_requested" | jq 'length')

if [ "$mergeable" = "CONFLICTING" ] || [ "$n_ci_failed" -gt 0 ] || [ "$n_inline" -gt 0 ] || [ "$n_pr_reviews" -gt 0 ] || [ "$n_issue" -gt 0 ] || [ "$n_changes_requested" -gt 0 ]; then
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
  --argjson inline_comments "$inline_comments" \
  --argjson pr_reviews "$pr_reviews" \
  --argjson issue_comments "$issue_comments" \
  --argjson changes_requested "$changes_requested" \
  --arg status "$status" \
  --argjson n_ci_failed "$n_ci_failed" \
  --argjson n_ci_pending "$n_ci_pending" \
  --argjson n_inline "$n_inline" \
  --argjson n_pr_reviews "$n_pr_reviews" \
  --argjson n_issue "$n_issue" \
  --argjson n_changes_requested "$n_changes_requested" \
  '{
    pr: $pr,
    git_clean: $git_clean,
    ci: { failed: $ci_failed, pending: $ci_pending, passed: $ci_passed },
    reviews: {
      inline_comments: $inline_comments,
      pr_reviews: $pr_reviews,
      issue_comments: $issue_comments,
      changes_requested: $changes_requested
    },
    summary: {
      status: $status,
      ci_failed: $n_ci_failed,
      ci_pending: $n_ci_pending,
      inline_comments: $n_inline,
      pr_reviews: $n_pr_reviews,
      issue_comments: $n_issue,
      changes_requested: $n_changes_requested
    }
  }'

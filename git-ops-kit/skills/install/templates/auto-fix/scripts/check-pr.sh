#!/usr/bin/env bash
# PR の状態・CI チェック・レビューコメントを一括取得して JSON で出力する
# Usage: check-pr.sh [--ci-only] [--reviews-only]
#
# 出力 JSON 構造:
# {
#   "pr": { "number": 123, "branch": "feat/x", "base": "main", "state": "OPEN", "url": "...", "auto_merge_enabled": false, "mergeable": "MERGEABLE|CONFLICTING|UNKNOWN", "merge_state_status": "..." },
#   "git_clean": true,
#   "ci": {
#     "failed":  [{ "name": "...", "state": "FAILURE", "link": "...", "provider": "github-actions|circleci|other" }, ...],
#     "pending": [...],
#     "passed":  [...]
#   },
#   "reviews": {
#     "unresolved_threads": [{ "thread_id", "path", "line", "comments": [{ "id", "user", "body", "claude_marker" }] }, ...],
#     "pr_reviews":        [{ "id", "author", "state", "body", "submitted_at", "claude_marker", "meta_marker" }, ...],
#     "issue_comments":    [{ "id", "user", "body", "created_at", "claude_marker", "meta_marker" }, ...],
#     "changes_requested": [{ "author", "state", "body" }, ...]
#   },
#   "summary": {
#     "status": "ACTION_NEEDED|PENDING|ALL_CLEAR",
#     "ci_failed": N, "ci_pending": N,
#     "unresolved_threads": N, "pr_reviews": N, "issue_comments": N, "changes_requested": N
#   }
# }
#
# pr.mergeable は GitHub が非同期で算出する merge 可能性。UNKNOWN は計算待ちで
# 一時的に返る (= ACTION_NEEDED にしない)。CONFLICTING は base branch との競合発生中。
#
# 未対応判定 (watch-pr.sh と同じ基準):
# - インラインレビュースレッド: isResolved == false かつ最後のコメントが
#   auto-fix マーカー / 持続的メタコメントマーカーを含まないスレッドのみカウント
# - PR レビュー本体 / 会話コメント: 本文にマーカーを含むものを除外してカウント
#
# `claude_marker`: 本文に `<!-- ClaudeCode:auto-fix -->` を含む場合 true (= auto-fix 自身の返信)。
# `meta_marker`: 本文に persistent_meta_markers_json のいずれかを含む場合 true。

set -euo pipefail

CI_ONLY=false
REVIEWS_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --ci-only) CI_ONLY=true ;;
    --reviews-only) REVIEWS_ONLY=true ;;
  esac
done

# auto-fix の返信マーカー。文言を変更する場合は SKILL.md と watch-pr.sh も同時に更新すること。
auto_fix_marker="<!-- ClaudeCode:auto-fix -->"

# bot / CI の持続的メタコメントマーカー (watch-pr.sh の同名変数と同期させる)
persistent_meta_markers_json='["<!-- This is an auto-generated comment: summarize by coderabbit.ai -->"]'

# PR 情報
pr_json=$(gh pr view --json number,headRefName,baseRefName,state,url,autoMergeRequest,mergeable,mergeStateStatus 2>/dev/null || echo "")
if [ -z "$pr_json" ]; then
  echo '{"error": "no_pr", "message": "No PR found for current branch", "summary": {"status": "error"}}'
  exit 0
fi

pr_number=$(echo "$pr_json" | jq -r '.number')
owner_repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
owner=$(echo "$owner_repo" | cut -d/ -f1)
repo_name=$(echo "$owner_repo" | cut -d/ -f2)

# auto_merge_enabled / mergeable / base を露出した形に整形
pr_json=$(echo "$pr_json" | jq '{
  number,
  branch: .headRefName,
  base: .baseRefName,
  state,
  url,
  auto_merge_enabled: (.autoMergeRequest != null),
  mergeable: (.mergeable // "UNKNOWN"),
  merge_state_status: (.mergeStateStatus // "UNKNOWN")
}')

mergeable=$(echo "$pr_json" | jq -r '.mergeable')
merge_state_status=$(echo "$pr_json" | jq -r '.merge_state_status')

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

ci_failed=$(echo "$ci_json"  | jq '[.[] | select(.state == "FAILURE" or .state == "ERROR")]')
ci_pending=$(echo "$ci_json" | jq '[.[] | select(.state == "PENDING" or .state == "IN_PROGRESS" or .state == "QUEUED")]')
ci_passed=$(echo "$ci_json"  | jq '[.[] | select(.state == "SUCCESS")]')

# レビュー / コメント
unresolved_threads="[]"
pr_reviews="[]"
issue_comments="[]"
changes_requested="[]"

if [ "$CI_ONLY" = false ]; then
  marker_filter=". + { claude_marker: ((.body // \"\") | contains(\$marker)), meta_marker: ((.body // \"\") | . as \$b | any(\$metas[]?; . as \$n | \$b | contains(\$n))) }"

  # インラインレビュースレッド (GraphQL。isResolved を見るには GraphQL が必須)
  thread_json=$(gh api graphql -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviewThreads(first: 100) {
            nodes {
              id
              isResolved
              path
              line
              comments(first: 50) {
                nodes { databaseId body author { login } }
              }
            }
          }
        }
      }
    }' -F owner="$owner" -F repo="$repo_name" -F number="$pr_number" 2>/dev/null \
    || echo '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}')

  # 未解決スレッドのうち、最後のコメントが auto-fix / メタコメントでないもののみ
  unresolved_threads=$(echo "$thread_json" | jq --arg marker "$auto_fix_marker" --argjson metas "$persistent_meta_markers_json" '
    def contains_any($needles): . as $body | any($needles[]?; . as $n | $body | contains($n));
    [
      .data.repository.pullRequest.reviewThreads.nodes[]?
        | select(.isResolved == false)
        | select(((.comments.nodes[-1].body) // "") | contains($marker) | not)
        | select(((.comments.nodes[-1].body) // "") | contains_any($metas) | not)
        | {
            thread_id: .id,
            path,
            line,
            comments: [.comments.nodes[] | {
              id: .databaseId,
              user: .author.login,
              body,
              claude_marker: ((.body // "") | contains($marker))
            }]
          }
    ]')

  # PR レベルのレビュー (approve / request changes / 全体コメント)
  pr_reviews=$(gh pr view "$pr_number" --json reviews \
    --jq '[.reviews[] | {id, author: .author.login, state, body, submitted_at: .submittedAt}]' 2>/dev/null \
    | jq --arg marker "$auto_fix_marker" --argjson metas "$persistent_meta_markers_json" "[.[] | $marker_filter]" 2>/dev/null || echo "[]")

  # PR 会話コメント (issue comments)
  issue_comments=$(gh api --paginate "repos/${owner_repo}/issues/${pr_number}/comments" \
    --jq '[.[] | {id, user: .user.login, body, created_at}]' 2>/dev/null \
    | jq --arg marker "$auto_fix_marker" --argjson metas "$persistent_meta_markers_json" "[.[] | $marker_filter]" 2>/dev/null || echo "[]")

  # CHANGES_REQUESTED レビュー
  changes_requested=$(echo "$pr_reviews" | jq '[.[] | select(.state == "CHANGES_REQUESTED")]')
fi

# サマリー計算 (auto-fix 自身の返信・メタコメントはカウントから除外)
n_ci_failed=$(echo "$ci_failed" | jq 'length')
n_ci_pending=$(echo "$ci_pending" | jq 'length')
n_threads=$(echo "$unresolved_threads" | jq 'length')
n_pr_reviews=$(echo "$pr_reviews"   | jq '[.[] | select((.claude_marker or .meta_marker) | not) | select((.body // "") != "" or .state == "CHANGES_REQUESTED")] | length')
n_issue=$(echo "$issue_comments"    | jq '[.[] | select((.claude_marker or .meta_marker) | not)] | length')
n_changes_requested=$(echo "$changes_requested" | jq 'length')

has_conflict=false
if [ "$mergeable" = "CONFLICTING" ] || [ "$merge_state_status" = "DIRTY" ]; then
  has_conflict=true
fi

if [ "$has_conflict" = true ] || [ "$n_ci_failed" -gt 0 ] || [ "$n_threads" -gt 0 ] || [ "$n_pr_reviews" -gt 0 ] || [ "$n_issue" -gt 0 ] || [ "$n_changes_requested" -gt 0 ]; then
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
  --argjson unresolved_threads "$unresolved_threads" \
  --argjson pr_reviews "$pr_reviews" \
  --argjson issue_comments "$issue_comments" \
  --argjson changes_requested "$changes_requested" \
  --arg status "$status" \
  --argjson n_ci_failed "$n_ci_failed" \
  --argjson n_ci_pending "$n_ci_pending" \
  --argjson n_threads "$n_threads" \
  --argjson n_pr_reviews "$n_pr_reviews" \
  --argjson n_issue "$n_issue" \
  --argjson n_changes_requested "$n_changes_requested" \
  '{
    pr: $pr,
    git_clean: $git_clean,
    ci: { failed: $ci_failed, pending: $ci_pending, passed: $ci_passed },
    reviews: {
      unresolved_threads: $unresolved_threads,
      pr_reviews: $pr_reviews,
      issue_comments: $issue_comments,
      changes_requested: $changes_requested
    },
    summary: {
      status: $status,
      ci_failed: $n_ci_failed,
      ci_pending: $n_ci_pending,
      unresolved_threads: $n_threads,
      pr_reviews: $n_pr_reviews,
      issue_comments: $n_issue,
      changes_requested: $n_changes_requested
    }
  }'

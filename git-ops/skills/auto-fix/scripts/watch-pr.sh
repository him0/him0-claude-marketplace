#!/usr/bin/env bash
# auto-fix Monitor用ポーリングスクリプト
# Usage: watch-pr.sh <owner/repo> <pr-number> [interval_sec]
#
# stdout に1行ずつステータスを出力する。
# Monitor が各行を通知としてクロードに届ける。
#
# Events:
#   MERGED            - PR がマージされた。監視終了
#   CLOSED            - PR がクローズされた。監視終了
#   ACTION_NEEDED     - CI 失敗 or レビューコメントあり。修正が必要
#   NEW_COMMENTS      - 前回チェック以降に新しいコメントが追加された
#   PENDING           - CI 実行中。待機
#   ALL_CLEAR         - 問題なし

set -euo pipefail

OWNER_REPO="${1:?Usage: watch-pr.sh <owner/repo> <pr-number> [interval_sec]}"
PR_NUMBER="${2:?Usage: watch-pr.sh <owner/repo> <pr-number> [interval_sec]}"
INTERVAL="${3:-60}"

# 前回チェック時のコメント数を記録
# 初回は 0 で開始し、既存コメントも新規として検出する
prev_review_comments=0
prev_pr_comments=0

while true; do
  # PR の状態を確認 (マージ/クローズ検出)
  pr_state=$(gh pr view "$PR_NUMBER" --repo "$OWNER_REPO" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")

  if [ "$pr_state" = "MERGED" ]; then
    echo "MERGED pr=#${PR_NUMBER}"
    exit 0
  fi

  if [ "$pr_state" = "CLOSED" ]; then
    echo "CLOSED pr=#${PR_NUMBER}"
    exit 0
  fi

  # CI チェック状況
  checks_json=$(gh pr checks "$PR_NUMBER" --repo "$OWNER_REPO" --json name,state 2>/dev/null || echo "[]")
  failed=$(echo "$checks_json" | jq '[.[] | select(.state == "FAILURE")] | length')
  pending=$(echo "$checks_json" | jq '[.[] | select(.state == "PENDING")] | length')

  # インラインレビューコメント数 (トップレベルのみ)
  review_comments=$(gh api "repos/${OWNER_REPO}/pulls/${PR_NUMBER}/comments" \
    --jq '[.[] | select(.in_reply_to_id == null)] | length' 2>/dev/null || echo "0")

  # PR レベルのコメント数
  pr_comments=$(gh pr view "$PR_NUMBER" --repo "$OWNER_REPO" --json comments \
    --jq '.comments | length' 2>/dev/null || echo "0")

  # PR レベルのレビュー (CHANGES_REQUESTED のみ)
  changes_requested=$(gh pr view "$PR_NUMBER" --repo "$OWNER_REPO" --json reviews \
    --jq '[.reviews[] | select(.state == "CHANGES_REQUESTED")] | length' 2>/dev/null || echo "0")

  # 新しいコメントの検出
  new_comments=0
  delta_review=$((review_comments - prev_review_comments))
  delta_pr=$((pr_comments - prev_pr_comments))
  if [ "$delta_review" -gt 0 ] || [ "$delta_pr" -gt 0 ]; then
    new_comments=1
  fi
  prev_review_comments=$review_comments
  prev_pr_comments=$pr_comments

  # イベント出力
  if [ "$failed" -gt 0 ] || [ "$changes_requested" -gt 0 ]; then
    echo "ACTION_NEEDED ci_failed=${failed} ci_pending=${pending} review_comments=${review_comments} changes_requested=${changes_requested}"
  elif [ "$new_comments" -gt 0 ]; then
    echo "NEW_COMMENTS review_comments=${review_comments} pr_comments=${pr_comments}"
  elif [ "$pending" -gt 0 ]; then
    echo "PENDING ci_pending=${pending}"
  else
    echo "ALL_CLEAR"
  fi

  sleep "$INTERVAL"
done

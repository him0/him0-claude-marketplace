#!/usr/bin/env bash
# auto-fix スキルの --watch モード用ポーリングスクリプト。
# Monitor ツールから起動され、PR の CI ステータスとレビュー / コメントを
# 監視して、状態変化時のみ stdout に 1 行イベントを出力する。
#
# 出力イベント:
#   CI_FAILED:<check_name>,<run_id>          失敗しているチェックを検出
#   NEW_REVIEW:count=<n>                     未対応のレビュー本体・PR トップレベルコメントあり
#   NEW_REVIEW_COMMENT:count=<n>             未対応のインラインレビューコメントあり
#   MERGE_CONFLICT:<mergeable>,<state>       base ブランチとの conflict を検出（要 merge & 解消）
#   ALL_PASSED                               CI 全通過かつ未対応コメントなし（非終了。クリーン化のたびに通知し監視は継続）
#   MERGED                                   PR がマージされた（終了）
#   CLOSED                                   PR が未マージでクローズされた（終了）
#   ERROR:<message>                          ポーリング自体の障害（連続 3 回で終了）
#
# Usage:
#   watch-pr.sh [poll_interval_seconds]
#   デフォルト poll_interval: 60。PR はカレントブランチから解決する。

set -uo pipefail

interval="${1:-60}"
prev=""
error_streak=0

# auto-fix の返信に付ける識別子（HTML コメントとして本文末尾に埋め込む）。
# GitHub UI 上には表示されず、API レスポンスの body には含まれるため、
# 返信済みコメントを判別する用途に使う。
# マーカー文言を変更する場合は SKILL.md と check-pr.sh も同時に更新すること。
auto_fix_marker="<!-- ClaudeCode:auto-fix -->"

# bot / CI が PR に自動投稿する「持続的メタコメント」のマーカー一覧（JSON 配列）。
# 人手レビューではなく auto-fix が対応するアクションも存在しないため、未対応カウントから除外する。
# プロジェクト固有の bot コメント（例: issue トラッカーのリンクバック、CI の進捗通知）が
# あれば、その本文に含まれる HTML コメントマーカーをここに追加する。
# 例: '["<!-- linear-linkback -->","<!-- some-ci-progress -->"]'
persistent_meta_markers_json='[]'

# リポジトリ名はセッション中に変わらないため、ループ前に 1 回だけ解決する。
repo_full=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
if [ -z "$repo_full" ]; then
  echo "ERROR:failed to resolve repository (gh repo view)"
  exit 1
fi
owner=$(echo "$repo_full" | cut -d/ -f1)
repo_name=$(echo "$repo_full" | cut -d/ -f2)

while true; do
  pr_json=$(gh pr view --json number,state,url,mergeable,mergeStateStatus 2>/dev/null || echo "")
  if [ -z "$pr_json" ]; then
    error_streak=$((error_streak + 1))
    echo "ERROR:gh pr view failed (streak=${error_streak})"
    if [ "$error_streak" -ge 3 ]; then
      exit 1
    fi
    sleep "$interval"
    continue
  fi
  error_streak=0

  pr_number=$(echo "$pr_json" | jq -r '.number // empty')
  if [ -z "$pr_number" ]; then
    error_streak=$((error_streak + 1))
    echo "ERROR:failed to resolve PR number (streak=${error_streak})"
    if [ "$error_streak" -ge 3 ]; then
      exit 1
    fi
    sleep "$interval"
    continue
  fi
  state=$(echo "$pr_json" | jq -r '.state // empty')
  case "$state" in
    OPEN) ;;
    MERGED) echo "MERGED"; exit 0 ;;
    CLOSED) echo "CLOSED"; exit 0 ;;
    *) echo "ERROR:unknown PR state: ${state}"; exit 1 ;;
  esac

  # base ブランチとの conflict 検知。
  # mergeable は GitHub が非同期計算するため、未確定時は "UNKNOWN" になりうる。
  # CONFLICTING / DIRTY のいずれかが立った時のみ MERGE_CONFLICT を発火し、
  # UNKNOWN や MERGEABLE/CLEAN は無視する。
  mergeable=$(echo "$pr_json" | jq -r '.mergeable // empty')
  merge_state_status=$(echo "$pr_json" | jq -r '.mergeStateStatus // empty')
  if [ "$mergeable" = "CONFLICTING" ] || [ "$merge_state_status" = "DIRTY" ]; then
    merge_conflict="1"
  else
    merge_conflict="0"
  fi

  checks=$(gh pr checks --json name,state,link 2>/dev/null || echo "[]")
  failed=$(echo "$checks" | jq -r '.[] | select(.state == "FAILURE" or .state == "ERROR") | "\(.name)|\(.link)"')
  pending=$(echo "$checks" | jq -r '.[] | select(.state == "PENDING" or .state == "IN_PROGRESS" or .state == "QUEUED") | .name')

  # PR トップレベルコメント + レビュー本体
  # auto-fix 自身が付けた返信 ($marker) と bot 持続的メタコメント ($metas のいずれかを含むもの) は除外
  pr_comments_json=$(gh pr view --json comments,reviews 2>/dev/null || echo "{}")
  reviews=$(echo "$pr_comments_json" | jq -r --arg marker "$auto_fix_marker" --argjson metas "$persistent_meta_markers_json" '
    def contains_any($needles): . as $body | any($needles[]?; . as $n | $body | contains($n));
    [
      ((.comments // [])[]?    | select(.isMinimized != true) | select((.body // "") | contains($marker) | not) | select((.body // "") | contains_any($metas) | not)),
      ((.reviews // [])[]?     | select(((.body // "") | length) > 0) | select((.body // "") | contains($marker) | not) | select((.body // "") | contains_any($metas) | not))
    ] | length
  ')

  # インラインレビュースレッド（GraphQL）
  # - resolved されたスレッドは除外
  # - 最後のコメントが auto-fix 自身（marker 含む）のスレッドも除外
  #   （= 「修正/修正しない」で resolve 済 or 「追加質問」で人間の応答待ち）
  thread_json=$(gh api graphql -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviewThreads(first: 100) {
            nodes {
              isResolved
              comments(last: 1) { nodes { body } }
            }
          }
        }
      }
    }' -F owner="$owner" -F repo="$repo_name" -F number="$pr_number" 2>/dev/null \
    || echo '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}')
  inline_count=$(echo "$thread_json" | jq -r --arg marker "$auto_fix_marker" --argjson metas "$persistent_meta_markers_json" '
    def contains_any($needles): . as $body | any($needles[]?; . as $n | $body | contains($n));
    [
      .data.repository.pullRequest.reviewThreads.nodes[]?
        | select(.isResolved == false)
        | select(((.comments.nodes[0].body) // "") | contains($marker) | not)
        | select(((.comments.nodes[0].body) // "") | contains_any($metas) | not)
    ] | length
  ')

  # クリーン状態（CI 全通過・pending なし・未対応コメントなし・conflict なし）を
  # boolean フラグ化して snapshot に含める。
  # pending を raw で snapshot に入れると PENDING → IN_PROGRESS → SUCCESS の遷移ごとに
  # snapshot が変わり reviews / inline_count が同じでも NEW_REVIEW が再発火するが、
  # clean は pending 中ずっと 0 のままなので途中遷移では変化せず、
  # pending が空へ遷移した瞬間に 0→1 となり ALL_PASSED を 1 度だけ発火できる。
  if [ -z "$failed" ] && [ -z "$pending" ] && [ "$reviews" = "0" ] && [ "$inline_count" = "0" ] && [ "$merge_conflict" = "0" ]; then
    clean="1"
  else
    clean="0"
  fi

  snapshot="${failed}::${reviews}::${inline_count}::${merge_conflict}::${clean}"
  if [ "$snapshot" != "$prev" ]; then
    if [ -n "$failed" ]; then
      while IFS='|' read -r name link; do
        [ -z "$name" ] && continue
        run_id=$(echo "$link" | grep -oE '[0-9]+$' || echo "")
        echo "CI_FAILED:${name},${run_id}"
      done <<< "$failed"
    fi
    if [ "$reviews" != "0" ] && [ -n "$reviews" ]; then
      echo "NEW_REVIEW:count=${reviews}"
    fi
    if [ "$inline_count" != "0" ] && [ -n "$inline_count" ]; then
      echo "NEW_REVIEW_COMMENT:count=${inline_count}"
    fi
    if [ "$merge_conflict" = "1" ]; then
      echo "MERGE_CONFLICT:${mergeable:-UNKNOWN},${merge_state_status:-UNKNOWN}"
    fi
    # ALL_PASSED は「今クリーンになった」ことを伝える非終了イベント。
    # ここで exit せず監視を継続し、終了は MERGED / CLOSED（PR state）に一本化する。
    # これにより approve 後・マージ前に発生する新規コメントや conflict も拾い続けられる。
    # クリーン → 指摘発生 → 解消で再びクリーン、のたびに 1 度ずつ再発火する。
    if [ "$clean" = "1" ]; then
      echo "ALL_PASSED"
    fi
    prev="$snapshot"
  fi

  sleep "$interval"
done

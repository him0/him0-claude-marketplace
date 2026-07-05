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
error_streak=0

# 各サブ状態の前回値。個別に追跡し、変化したサブ状態のイベントだけを発火する
# (複合 snapshot 方式だと、他のサブ状態の変化で未変化の CI 失敗などが再発火してしまう)
prev_failed=""
prev_review_ids=""
prev_inline_ids=""
prev_conflict=""
prev_clean=""

# マーカー定義 (auto_fix_marker / persistent_meta_markers_json) は共通定義から読み込む
. "$(dirname "$0")/markers.sh"

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
    *)
      # 一時的な API 異常で不明な state が返ることがあるため、他の障害と同じ 3 ストライク方式にする
      error_streak=$((error_streak + 1))
      echo "ERROR:unknown PR state: ${state:-<empty>} (streak=${error_streak})"
      if [ "$error_streak" -ge 3 ]; then
        exit 1
      fi
      sleep "$interval"
      continue
      ;;
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
  # 除外するもの:
  # - auto-fix 自身が付けた返信 ($marker)
  # - bot 持続的メタコメント ($metas のいずれかを含むもの)
  # - auto-fix の最後の返信より古いもの (トップレベルコメント / レビュー本体には resolve の
  #   概念がないため、「auto-fix が返信した時点までのものは対応済み」とみなすヒューリスティック)
  # 空本文でも CHANGES_REQUESTED のレビューは未対応として数える (check-pr.sh と同一基準)
  # 変化検知は件数ではなく ID 集合で行う (件数だと同一間隔内の「1件解消 + 1件新規」が相殺されて
  # イベントを見逃すため)
  pr_comments_json=$(gh pr view --json comments,reviews 2>/dev/null || echo "{}")
  review_ids=$(echo "$pr_comments_json" | jq -c --arg marker "$auto_fix_marker" --argjson metas "$persistent_meta_markers_json" '
    def contains_any($needles): . as $body | any($needles[]?; . as $n | $body | contains($n));
    ([ (.comments // [])[]? | select((.body // "") | contains($marker)) | .createdAt ] | max // "") as $af_ts
    | [
        ((.comments // [])[]?
          | select(.isMinimized != true)
          | select((.body // "") | contains($marker) | not)
          | select((.body // "") | contains_any($metas) | not)
          | select((.createdAt // "") > $af_ts)
          | .id),
        ((.reviews // [])[]?
          | select((.body // "") | contains($marker) | not)
          | select((.body // "") | contains_any($metas) | not)
          | select((((.body // "") | length) > 0) or .state == "CHANGES_REQUESTED")
          | select((.submittedAt // "") > $af_ts)
          | .id)
      ] | sort
  ')
  reviews=$(echo "$review_ids" | jq -r 'length')

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
              id
              isResolved
              comments(last: 1) { nodes { body } }
            }
          }
        }
      }
    }' -F owner="$owner" -F repo="$repo_name" -F number="$pr_number" 2>/dev/null \
    || echo '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}')
  inline_ids=$(echo "$thread_json" | jq -c --arg marker "$auto_fix_marker" --argjson metas "$persistent_meta_markers_json" '
    def contains_any($needles): . as $body | any($needles[]?; . as $n | $body | contains($n));
    [
      .data.repository.pullRequest.reviewThreads.nodes[]?
        | select(.isResolved == false)
        | select(((.comments.nodes[0].body) // "") | contains($marker) | not)
        | select(((.comments.nodes[0].body) // "") | contains_any($metas) | not)
        | .id
    ] | sort
  ')
  inline_count=$(echo "$inline_ids" | jq -r 'length')

  # クリーン状態（CI 全通過・pending なし・未対応コメントなし・conflict なし）。
  # pending は clean の判定にのみ使う (PENDING → IN_PROGRESS → SUCCESS の途中遷移では
  # clean は 0 のまま変化せず、pending が空へ遷移した瞬間に 0→1 となり ALL_PASSED を
  # 1 度だけ発火できる)。
  if [ -z "$failed" ] && [ -z "$pending" ] && [ "$reviews" = "0" ] && [ "$inline_count" = "0" ] && [ "$merge_conflict" = "0" ]; then
    clean="1"
  else
    clean="0"
  fi

  # サブ状態ごとに前回値と比較し、変化したものだけイベントを発火する
  if [ -n "$failed" ] && [ "$failed" != "$prev_failed" ]; then
    while IFS='|' read -r name link; do
      [ -z "$name" ] && continue
      # run_id は /runs/ 直後の数字を抽出する (末尾の数字だと .../runs/<run>/job/<job> 形式で
      # job_id を拾ってしまう。get-ci-logs.sh と同一ロジック)
      run_id=$(echo "$link" | grep -oE '/runs/[0-9]+' | grep -oE '[0-9]+' | head -1 || echo "")
      echo "CI_FAILED:${name},${run_id}"
    done <<< "$failed"
  fi
  if [ "$reviews" != "0" ] && [ "$review_ids" != "$prev_review_ids" ]; then
    echo "NEW_REVIEW:count=${reviews}"
  fi
  if [ "$inline_count" != "0" ] && [ "$inline_ids" != "$prev_inline_ids" ]; then
    echo "NEW_REVIEW_COMMENT:count=${inline_count}"
  fi
  if [ "$merge_conflict" = "1" ] && [ "$prev_conflict" != "1" ]; then
    echo "MERGE_CONFLICT:${mergeable:-UNKNOWN},${merge_state_status:-UNKNOWN}"
  fi
  # ALL_PASSED は「今クリーンになった」ことを伝える非終了イベント。
  # ここで exit せず監視を継続し、終了は MERGED / CLOSED（PR state）に一本化する。
  # これにより approve 後・マージ前に発生する新規コメントや conflict も拾い続けられる。
  # クリーン → 指摘発生 → 解消で再びクリーン、のたびに 1 度ずつ再発火する。
  if [ "$clean" = "1" ] && [ "$prev_clean" != "1" ]; then
    echo "ALL_PASSED"
  fi

  prev_failed="$failed"
  prev_review_ids="$review_ids"
  prev_inline_ids="$inline_ids"
  prev_conflict="$merge_conflict"
  prev_clean="$clean"

  sleep "$interval"
done

#!/usr/bin/env bash
# auto-fix テンプレートの判定ロジック (jq フィルタ・差集合) のフィクスチャテスト
#
# check-pr.sh / watch-pr.sh に埋め込まれた jq フィルタと同等のプログラムを
# モック JSON に適用し、期待値と比較する。フィルタ本体はスクリプト内に埋め込まれて
# いるため、ここでの複製がスクリプト側の変更と乖離しないよう、フィルタを変更した
# 場合は本テストも同時に更新すること。
#
# Usage: bash git-ops-kit/tests/watch-logic-test.sh

set -uo pipefail

cd "$(dirname "$0")"

# テンプレートの markers.sh をそのまま読み込む (マーカー文言の乖離を防ぐ)
. ../skills/install/templates/auto-fix/scripts/markers.sh

fail=0
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok: ${name}"
  else
    echo "NG: ${name}"
    echo "  expected: ${expected}"
    echo "  actual:   ${actual}"
    fail=1
  fi
}

# --- 1. marker_filter: claude_marker / meta_marker の付与 ---

input='[{"id":1,"body":"looks wrong"},{"id":2,"body":"done\n\n<!-- ClaudeCode:auto-fix -->"},{"id":3,"body":"summary <!-- This is an auto-generated comment: summarize by coderabbit.ai -->"}]'
marker_filter=". + { claude_marker: ((.body // \"\") | contains(\$marker)), meta_marker: ((.body // \"\") | . as \$b | any(\$metas[]?; . as \$n | \$b | contains(\$n))) }"
actual=$(printf '%s' "$input" | jq -c --arg marker "$auto_fix_marker" --argjson metas "$persistent_meta_markers_json" "[.[] | $marker_filter | {id, claude_marker, meta_marker}]")
assert_eq "marker_filter" \
  '[{"id":1,"claude_marker":false,"meta_marker":false},{"id":2,"claude_marker":true,"meta_marker":false},{"id":3,"claude_marker":false,"meta_marker":true}]' \
  "$actual"

# --- 2. unresolved_threads: resolve 済み / auto-fix 応答済み / メタコメントの除外 ---

threads='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[
 {"id":"T1","isResolved":false,"comments":{"nodes":[{"body":"fix this"}]}},
 {"id":"T2","isResolved":false,"comments":{"nodes":[{"body":"nit"},{"body":"done <!-- ClaudeCode:auto-fix -->"}]}},
 {"id":"T3","isResolved":true,"comments":{"nodes":[{"body":"old"}]}},
 {"id":"T4","isResolved":false,"comments":{"nodes":[{"body":"note <!-- This is an auto-generated comment: summarize by coderabbit.ai -->"}]}}
]}}}}}'
actual=$(printf '%s' "$threads" | jq -c --arg marker "$auto_fix_marker" --argjson metas "$persistent_meta_markers_json" '
  def contains_any($needles): . as $body | any($needles[]?; . as $n | $body | contains($n));
  [
    .data.repository.pullRequest.reviewThreads.nodes[]?
      | select(.isResolved == false)
      | select(((.comments.nodes[-1].body) // "") | contains($marker) | not)
      | select(((.comments.nodes[-1].body) // "") | contains_any($metas) | not)
      | .id
  ]')
assert_eq "unresolved_threads" '["T1"]' "$actual"

# --- 3. review_ids: af_ts ヒューリスティック + 空本文 CHANGES_REQUESTED ---

pr='{
 "comments":[
  {"id":"C1","body":"please fix","createdAt":"2026-01-01T09:00:00Z","isMinimized":false},
  {"id":"C2","body":"done\n<!-- ClaudeCode:auto-fix -->","createdAt":"2026-01-01T09:10:00Z","isMinimized":false},
  {"id":"C3","body":"new comment after reply","createdAt":"2026-01-01T09:20:00Z","isMinimized":false}
 ],
 "reviews":[
  {"id":"R1","body":"","state":"CHANGES_REQUESTED","submittedAt":"2026-01-01T09:05:00Z"},
  {"id":"R2","body":"","state":"CHANGES_REQUESTED","submittedAt":"2026-01-01T09:15:00Z"},
  {"id":"R3","body":"","state":"APPROVED","submittedAt":"2026-01-01T09:16:00Z"},
  {"id":"R4","body":"lgtm with nits","state":"COMMENTED","submittedAt":"2026-01-01T09:25:00Z"}
 ]}'
actual=$(printf '%s' "$pr" | jq -c --arg marker "$auto_fix_marker" --argjson metas "$persistent_meta_markers_json" '
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
    ] | sort')
assert_eq "review_ids (af_ts + empty CHANGES_REQUESTED)" '["C3","R2","R4"]' "$actual"

# --- 4. 差集合: 新規追加のみ発火、解消のみでは発火しない ---

assert_eq "set-diff additions"    "1" "$(jq -n --argjson prev '["A","B"]' --argjson cur '["B","C"]' '($cur - $prev) | length')"
assert_eq "set-diff removal-only" "0" "$(jq -n --argjson prev '["A","B"]' --argjson cur '["B"]'     '($cur - $prev) | length')"

# --- 5. new_failed: 既知の失敗は再送せず、新規失敗のみ ---

prev_failed="lint|https://github.com/x/y/actions/runs/111/job/222"
failed=$'lint|https://github.com/x/y/actions/runs/111/job/222\ntest|https://github.com/x/y/actions/runs/333/job/444'
actual=$(comm -13 <(printf '%s\n' "$prev_failed" | sort -u) <(printf '%s\n' "$failed" | sort -u) | grep -v '^$' || true)
assert_eq "new_failed diff" "test|https://github.com/x/y/actions/runs/333/job/444" "$actual"

# --- 6. run_id 抽出: job_id を拾わない ---

link="https://github.com/x/y/actions/runs/12345/job/67890"
actual=$(echo "$link" | grep -oE '/runs/[0-9]+' | grep -oE '[0-9]+' | head -1)
assert_eq "run_id extraction" "12345" "$actual"

# --- 7. handled: af_ts 以前のコメントは対応済み ---

comments='[{"id":1,"created_at":"2026-01-01T09:00:00Z","claude_marker":false,"meta_marker":false},{"id":2,"created_at":"2026-01-01T09:20:00Z","claude_marker":false,"meta_marker":false}]'
actual=$(printf '%s' "$comments" | jq -c --arg af_ts "2026-01-01T09:10:00Z" '[.[] | . + {handled: ((.created_at // "") <= $af_ts)}] | [.[] | select((.claude_marker or .meta_marker or .handled) | not) | .id]')
assert_eq "handled heuristic" '[2]' "$actual"

echo
if [ "$fail" = "0" ]; then
  echo "all tests passed"
else
  echo "some tests FAILED"
  exit 1
fi

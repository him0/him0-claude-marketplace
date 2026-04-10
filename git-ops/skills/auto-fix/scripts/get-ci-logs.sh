#!/usr/bin/env bash
# 失敗した CI チェックのログを取得する
# Usage: get-ci-logs.sh <check-link> [tail-lines]
#
# check-link: gh pr checks --json link で取得した URL (例: https://github.com/owner/repo/actions/runs/12345)
# tail-lines: 各失敗ステップから取得する末尾行数 (デフォルト: 100)
#
# 出力: 失敗ログのテキスト (末尾 tail-lines 行に絞る)

set -euo pipefail

CHECK_LINK="${1:?Usage: get-ci-logs.sh <check-link> [tail-lines]}"
TAIL_LINES="${2:-100}"

# URL から run ID を抽出
run_id=$(echo "$CHECK_LINK" | grep -oE '[0-9]+$')

if [ -z "$run_id" ]; then
  echo "ERROR: Could not extract run ID from: $CHECK_LINK"
  exit 1
fi

# 失敗ログ取得 (末尾に絞る)
gh run view "$run_id" --log-failed 2>/dev/null | tail -n "$TAIL_LINES"

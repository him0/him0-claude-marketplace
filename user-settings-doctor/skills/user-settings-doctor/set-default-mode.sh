#!/bin/bash
# Claude Code user settings updater (permissions.defaultMode)
# Usage: ./set-default-mode.sh <mode>
#   mode: default | manual | acceptEdits | plan | auto | dontAsk | bypassPermissions
#
# ~/.claude/settings.json (CLAUDE_CONFIG_DIR があればそちら) の
# permissions.defaultMode だけを書き換える。他のキーは保持し、書き換え前に .bak を作る。
set -uo pipefail

MODE="${1:-}"

case "$MODE" in
  default|manual|acceptEdits|plan|auto|dontAsk|bypassPermissions) ;;
  "")
    echo "Usage: $0 <default|manual|acceptEdits|plan|auto|dontAsk|bypassPermissions>" >&2
    exit 1 ;;
  *)
    echo "Error: unknown mode '$MODE'" >&2
    echo "Valid: default, manual, acceptEdits, plan, auto, dontAsk, bypassPermissions" >&2
    exit 1 ;;
esac

command -v jq >/dev/null 2>&1 || {
  echo "Error: jq is required (brew install jq / apt install jq)" >&2
  exit 1
}

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CONFIG_DIR/settings.json"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
  echo "created: $SETTINGS"
fi

if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  echo "Error: $SETTINGS is not valid JSON. 手で直してから再実行すること" >&2
  exit 1
fi

BEFORE=$(jq -r '.permissions.defaultMode // "-"' "$SETTINGS")

# set -e を使っていないので、書き換え系は毎回明示的に失敗を見る。
# バックアップに失敗した状態で本体を置き換えないこと。
if ! cp "$SETTINGS" "$SETTINGS.bak"; then
  echo "Error: failed to back up $SETTINGS. 設定は変更していない" >&2
  exit 1
fi

TMP=$(mktemp "$SETTINGS.XXXXXX") || {
  echo "Error: failed to create a temporary file next to $SETTINGS" >&2
  exit 1
}

if ! jq --arg mode "$MODE" '.permissions.defaultMode = $mode' "$SETTINGS" > "$TMP"; then
  rm -f "$TMP"
  echo "Error: failed to update $SETTINGS. 設定は変更していない" >&2
  exit 1
fi

if ! mv "$TMP" "$SETTINGS"; then
  rm -f "$TMP"
  echo "Error: failed to replace $SETTINGS. $SETTINGS.bak から復元すること" >&2
  exit 1
fi

if ! chmod 644 "$SETTINGS"; then
  echo "Error: updated $SETTINGS but failed to set its permissions to 644" >&2
  exit 1
fi

AFTER=$(jq -r '.permissions.defaultMode // "-"' "$SETTINGS")

echo "updated: $SETTINGS"
echo "backup : $SETTINGS.bak"
echo "permissions.defaultMode: $BEFORE -> $AFTER"

echo
if [ "$MODE" = "auto" ]; then
  echo "Note: auto は user / managed スコープでのみ有効"
fi

# defaultMode はセッション開始時のモードを決める設定なので、
# ファイルが再読み込みされても実行中のセッションのモードは切り替わらない。
echo "Note: 実行中のセッションのモードは変わらない。切り替えるには CLI なら Shift+Tab を使う"

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

cp "$SETTINGS" "$SETTINGS.bak"

TMP=$(mktemp "$SETTINGS.XXXXXX")
if ! jq --arg mode "$MODE" '.permissions.defaultMode = $mode' "$SETTINGS" > "$TMP"; then
  rm -f "$TMP"
  echo "Error: failed to update $SETTINGS" >&2
  exit 1
fi
mv "$TMP" "$SETTINGS"
chmod 644 "$SETTINGS"

AFTER=$(jq -r '.permissions.defaultMode // "-"' "$SETTINGS")

echo "updated: $SETTINGS"
echo "backup : $SETTINGS.bak"
echo "permissions.defaultMode: $BEFORE -> $AFTER"

if [ "$MODE" = "auto" ]; then
  echo
  echo "Note: auto は user / managed スコープでのみ有効。次のセッションから適用される"
fi

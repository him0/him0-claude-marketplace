#!/bin/bash
# Claude Code user settings checker
# Usage: ./check-settings.sh
#
# 各スコープの settings.json を読み、permissions.defaultMode が auto かどうかを
# 中心に現在の設定内容を標準出力にレポートする。設定の書き換えはしない。
#
# exit code: 0 = チェック実行成功 (auto かどうかは RESULT 行で判定する) / 1 = 実行エラー
set -uo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "Error: jq is required (brew install jq / apt install jq)" >&2
  exit 1
}

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
USER_SETTINGS="$CONFIG_DIR/settings.json"

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_SETTINGS="$PROJECT_ROOT/.claude/settings.json"
LOCAL_SETTINGS="$PROJECT_ROOT/.claude/settings.local.json"

case "$(uname -s)" in
  Darwin) MANAGED_SETTINGS="/Library/Application Support/ClaudeCode/managed-settings.json" ;;
  *)      MANAGED_SETTINGS="/etc/claude-code/managed-settings.json" ;;
esac

# ファイルの状態を返す: missing / invalid / ok
file_state() {
  local f="$1"
  [ -f "$f" ] || { echo "missing"; return; }
  jq -e . "$f" >/dev/null 2>&1 && echo "ok" || echo "invalid"
}

# jq のパスを読む。ファイルが無い/壊れている/キーが無い場合は "-"
read_key() {
  local f="$1" path="$2" v
  [ -f "$f" ] || { echo "-"; return; }
  v=$(jq -r "$path // empty" "$f" 2>/dev/null)
  echo "${v:--}"
}

label_of() {
  case "$1" in
    default|manual)     echo "Manual (毎回確認)" ;;
    acceptEdits)        echo "編集は自動承認" ;;
    plan)               echo "Plan モード" ;;
    auto)               echo "Auto (classifier が背後で安全確認)" ;;
    dontAsk)            echo "許可済みのみ実行、他は自動拒否" ;;
    bypassPermissions)  echo "全確認スキップ (隔離環境専用)" ;;
    -)                  echo "未設定 (既定は Manual)" ;;
    *)                  echo "不明な値" ;;
  esac
}

USER_STATE=$(file_state "$USER_SETTINGS")
PROJECT_STATE=$(file_state "$PROJECT_SETTINGS")
LOCAL_STATE=$(file_state "$LOCAL_SETTINGS")
MANAGED_STATE=$(file_state "$MANAGED_SETTINGS")

USER_MODE=$(read_key "$USER_SETTINGS" '.permissions.defaultMode')
PROJECT_MODE=$(read_key "$PROJECT_SETTINGS" '.permissions.defaultMode')
LOCAL_MODE=$(read_key "$LOCAL_SETTINGS" '.permissions.defaultMode')
MANAGED_MODE=$(read_key "$MANAGED_SETTINGS" '.permissions.defaultMode')

echo "=== Claude Code settings check ==="
echo
echo "[設定ファイル]"
printf -- "- managed : %s (%s)\n" "$MANAGED_SETTINGS" "$MANAGED_STATE"
printf -- "- local   : %s (%s)\n" "$LOCAL_SETTINGS" "$LOCAL_STATE"
printf -- "- project : %s (%s)\n" "$PROJECT_SETTINGS" "$PROJECT_STATE"
printf -- "- user    : %s (%s)\n" "$USER_SETTINGS" "$USER_STATE"
echo "  優先度: managed > local > project > user"
echo

echo "[permissions.defaultMode]"
printf -- "- managed : %s\n" "$MANAGED_MODE"
printf -- "- local   : %s\n" "$LOCAL_MODE"
printf -- "- project : %s\n" "$PROJECT_MODE"
printf -- "- user    : %s  -> %s\n" "$USER_MODE" "$(label_of "$USER_MODE")"
echo

# --- auto mode の判定 ---
# auto は user / managed スコープでのみ有効。project / local の auto は無視される。
AUTO_DEFAULT="no"
[ "$USER_MODE" = "auto" ] && AUTO_DEFAULT="yes"
[ "$MANAGED_MODE" = "auto" ] && AUTO_DEFAULT="yes"

# disableAutoMode がどこかで "disable" なら auto 自体が使えない
AUTO_DISABLED="no"
for f in "$MANAGED_SETTINGS" "$LOCAL_SETTINGS" "$PROJECT_SETTINGS" "$USER_SETTINGS"; do
  [ "$(read_key "$f" '.permissions.disableAutoMode')" = "disable" ] && AUTO_DISABLED="yes"
done

# user が auto でも、より優先度の高いスコープが別の値を持つと上書きされる
OVERRIDE="-"
for scope_pair in "managed:$MANAGED_MODE" "local:$LOCAL_MODE" "project:$PROJECT_MODE"; do
  scope="${scope_pair%%:*}"
  mode="${scope_pair#*:}"
  if [ "$mode" != "-" ] && [ "$mode" != "auto" ] && [ "$OVERRIDE" = "-" ]; then
    OVERRIDE="$scope=$mode"
  fi
done

echo "[判定]"
if [ "$AUTO_DEFAULT" = "yes" ]; then
  echo "- デフォルトパーミッション auto: 設定済み"
else
  echo "- デフォルトパーミッション auto: 未設定"
fi

if [ "$AUTO_DISABLED" = "yes" ]; then
  echo "- 警告: permissions.disableAutoMode が \"disable\" になっているため auto は使えない"
fi

if [ "$PROJECT_MODE" = "auto" ] || [ "$LOCAL_MODE" = "auto" ]; then
  echo "- 警告: project/local の settings.json にある defaultMode: \"auto\" は無視される (リポジトリが自身に auto を許可できないため)。~/.claude/settings.json に書くこと"
fi

if [ "$AUTO_DEFAULT" = "yes" ] && [ "$OVERRIDE" != "-" ]; then
  echo "- 警告: 優先度の高いスコープが上書きしている ($OVERRIDE)。このディレクトリでは user の auto は効かない"
fi

if [ "$USER_STATE" = "invalid" ]; then
  echo "- エラー: $USER_SETTINGS が不正な JSON。設定全体が読み込まれない"
fi
echo

echo "[permissions ルール件数 (user)]"
if [ "$USER_STATE" = "ok" ]; then
  printf -- "- allow: %s / ask: %s / deny: %s / additionalDirectories: %s\n" \
    "$(jq '.permissions.allow // [] | length' "$USER_SETTINGS")" \
    "$(jq '.permissions.ask // [] | length' "$USER_SETTINGS")" \
    "$(jq '.permissions.deny // [] | length' "$USER_SETTINGS")" \
    "$(jq '.permissions.additionalDirectories // [] | length' "$USER_SETTINGS")"
else
  echo "- (user settings を読めないためスキップ)"
fi
echo

echo "[その他の user 設定]"
if [ "$USER_STATE" = "ok" ]; then
  for k in model effortLevel outputStyle statusLine alwaysThinkingEnabled autoCompactEnabled includeCoAuthoredBy; do
    v=$(jq -c --arg k "$k" '.[$k] // empty' "$USER_SETTINGS" 2>/dev/null)
    printf -- "- %s: %s\n" "$k" "${v:--}"
  done
  printf -- "- env キー: %s\n" "$(jq -r '.env // {} | keys | join(", ") | if . == "" then "-" else . end' "$USER_SETTINGS")"
  printf -- "- hooks イベント: %s\n" "$(jq -r '.hooks // {} | keys | join(", ") | if . == "" then "-" else . end' "$USER_SETTINGS")"
  printf -- "- トップレベルキー: %s\n" "$(jq -r 'keys | join(", ")' "$USER_SETTINGS")"
else
  echo "- (user settings を読めないためスキップ)"
fi
echo

echo "RESULT: default_mode_auto=$AUTO_DEFAULT auto_mode_disabled=$AUTO_DISABLED user_mode=$USER_MODE user_settings_state=$USER_STATE override=$OVERRIDE"

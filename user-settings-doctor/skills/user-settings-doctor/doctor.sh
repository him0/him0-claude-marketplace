#!/bin/bash
# Claude Code user settings doctor
# Usage: ./doctor.sh [--fix]
#
#   (引数なし)  診断のみ。設定ファイルは一切変更しない
#   --fix       期待値と違う項目を user settings に書き込んで揃える
#
# 診断項目・期待値・説明はこのファイルの CHECKS だけで定義する。
# 呼び出し側 (SKILL.md) は個々の項目を知らないので、項目を増減するときはここだけ触ればよい。
#
# exit code: 0 = 診断を実行できた (内容は RESULT 行で判定する) / 1 = 実行エラー
set -uo pipefail

# --- 診断項目の定義 ---------------------------------------------------------
# 1行1項目。フィールドは | 区切りで:
#   <id>|<jq パス>|<期待値>|<ラベル>|<なぜその値が良いか>
#
# --fix は user settings の <jq パス> に <期待値> を文字列として書き込む。
# 項目固有の補足を出したい場合は notes_<id の - を _ に置換したもの>() を定義する。
# その関数は診断結果に関わらず呼ばれ、ITEM_FIXABLE=no を設定すると
# 「user settings を直しても解決しない項目」として扱われる。
CHECKS="
default-mode|.permissions.defaultMode|auto|デフォルトパーミッション (permissions.defaultMode)|classifier が背後で安全性を確認するため、確認プロンプトがほぼ出なくなる
"

# --- 引数 -------------------------------------------------------------------
FIX="no"
for arg in "$@"; do
  case "$arg" in
    --fix) FIX="yes" ;;
    -h|--help)
      echo "Usage: $0 [--fix]"
      echo "  (引数なし)  診断のみ。設定ファイルは変更しない"
      echo "  --fix       期待値と違う項目を user settings に書き込んで揃える"
      exit 0 ;;
    *)
      echo "Error: unknown option '$arg'" >&2
      echo "Usage: $0 [--fix]" >&2
      exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || {
  echo "Error: jq is required (brew install jq / apt install jq)" >&2
  exit 1
}

# --- 対象ファイル -----------------------------------------------------------
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
USER_SETTINGS="$CONFIG_DIR/settings.json"

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_SETTINGS="$PROJECT_ROOT/.claude/settings.json"
LOCAL_SETTINGS="$PROJECT_ROOT/.claude/settings.local.json"

case "$(uname -s)" in
  Darwin) MANAGED_SETTINGS="/Library/Application Support/ClaudeCode/managed-settings.json" ;;
  *)      MANAGED_SETTINGS="/etc/claude-code/managed-settings.json" ;;
esac

# --- 共通ヘルパ -------------------------------------------------------------
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

# --- 項目固有の補足: default-mode -------------------------------------------
# defaultMode はスコープの優先度と auto 固有の制約があるので、
# 単純な期待値比較だけでは「なぜ効かないか」が分からない。ここで補う。
notes_default_mode() {
  local m_mode l_mode p_mode u_mode
  m_mode=$(read_key "$MANAGED_SETTINGS" '.permissions.defaultMode')
  l_mode=$(read_key "$LOCAL_SETTINGS" '.permissions.defaultMode')
  p_mode=$(read_key "$PROJECT_SETTINGS" '.permissions.defaultMode')
  u_mode=$(read_key "$USER_SETTINGS" '.permissions.defaultMode')

  echo "    各スコープの値: managed=$m_mode local=$l_mode project=$p_mode user=$u_mode"

  # project / local に書いた "auto" は Claude Code 側で無視される
  if [ "$p_mode" = "auto" ] || [ "$l_mode" = "auto" ]; then
    echo "    ! project/local の defaultMode: \"auto\" は無視される (リポジトリが自身に auto を許可できないため)"
  fi

  # 優先度 (managed > local > project > user) を解決して実際に効く値を出す。
  # 上記のとおり project/local の auto は読み飛ばす。
  local eff_mode="-" eff_scope="-" scope mode pair
  for pair in "managed:$m_mode" "local:$l_mode" "project:$p_mode" "user:$u_mode"; do
    scope="${pair%%:*}"
    mode="${pair#*:}"
    [ "$mode" = "-" ] && continue
    case "$scope:$mode" in
      local:auto|project:auto) continue ;;
    esac
    eff_mode="$mode"
    eff_scope="$scope"
    break
  done
  if [ "$eff_mode" = "-" ]; then
    eff_mode="default"
    eff_scope="none"
  fi
  echo "    実際に効くのは $eff_scope スコープの $eff_mode"

  # user settings を直しても、より優先度の高いスコープが上書きしていれば効かない
  if [ "$eff_scope" != "user" ] && [ "$eff_scope" != "none" ] && [ "$eff_scope" != "managed" ]; then
    echo "    ! $eff_scope スコープが上書きしているため、user settings を直しても解決しない"
    ITEM_FIXABLE="no"
  fi
  if [ "$eff_scope" = "managed" ]; then
    echo "    ! managed 設定が上書きしている。変更には管理者権限が必要"
    ITEM_FIXABLE="no"
  fi

  # disableAutoMode はどのスコープに書いても効く (managed だと上書きされないだけ)
  local f
  for pair in "managed:$MANAGED_SETTINGS" "local:$LOCAL_SETTINGS" "project:$PROJECT_SETTINGS" "user:$USER_SETTINGS"; do
    scope="${pair%%:*}"
    f="${pair#*:}"
    if [ "$(read_key "$f" '.permissions.disableAutoMode')" = "disable" ]; then
      echo "    ! $scope の permissions.disableAutoMode が \"disable\" のため auto は使えない"
      ITEM_FIXABLE="no"
    fi
  done

  echo "    defaultMode が決めるのはセッション開始時のモード。実行中のセッションは切り替わらない (CLI なら Shift+Tab)"
}

# --- 診断エンジン -----------------------------------------------------------
# CHECKS を1件ずつ評価して表示する。項目固有の知識はここには置かない。
# 結果は OK_COUNT / NG_COUNT / FIXABLE_COUNT / FIX_TARGETS に入る。
diagnose() {
  OK_COUNT=0
  NG_COUNT=0
  FIXABLE_COUNT=0
  FIX_TARGETS=""

  local id path expected label why current notes_fn
  while IFS='|' read -r id path expected label why; do
    [ -z "${id:-}" ] && continue

    current=$(read_key "$USER_SETTINGS" "$path")
    ITEM_FIXABLE="yes"

    if [ "$current" = "$expected" ]; then
      OK_COUNT=$((OK_COUNT + 1))
      printf -- "- [OK] %s\n" "$label"
      printf -- "    現在: %s (期待どおり)\n" "$current"
    else
      NG_COUNT=$((NG_COUNT + 1))
      printf -- "- [NG] %s\n" "$label"
      printf -- "    現在: %s / 期待: %s\n" "$current" "$expected"
      printf -- "    %s\n" "$why"
    fi

    # 項目固有の補足 (定義されていれば)
    notes_fn="notes_$(echo "$id" | tr '-' '_')"
    if declare -f "$notes_fn" >/dev/null 2>&1; then
      "$notes_fn"
    fi

    if [ "$current" != "$expected" ]; then
      if [ "$ITEM_FIXABLE" = "yes" ]; then
        FIXABLE_COUNT=$((FIXABLE_COUNT + 1))
        FIX_TARGETS="${FIX_TARGETS}${id}|${path}|${expected}|${label}
"
      else
        printf -- "    → --fix では解決しない項目\n"
      fi
    fi
    echo
  done <<EOF
$CHECKS
EOF
}

# --- 修正 -------------------------------------------------------------------
# FIX_TARGETS の各項目を user settings に書き込む。
# set -e を使っていないので、書き込み系は毎回明示的に失敗を見る。
apply_fixes() {
  local id path expected label before tmp

  mkdir -p "$CONFIG_DIR" || {
    echo "Error: failed to create $CONFIG_DIR" >&2
    return 1
  }

  if [ ! -f "$USER_SETTINGS" ]; then
    echo '{}' > "$USER_SETTINGS" || {
      echo "Error: failed to create $USER_SETTINGS" >&2
      return 1
    }
    echo "- created: $USER_SETTINGS"
  fi

  if ! jq -e . "$USER_SETTINGS" >/dev/null 2>&1; then
    echo "Error: $USER_SETTINGS が不正な JSON。手で直してから再実行すること" >&2
    return 1
  fi

  # バックアップに失敗した状態で本体を置き換えない
  if ! cp "$USER_SETTINGS" "$USER_SETTINGS.bak"; then
    echo "Error: failed to back up $USER_SETTINGS. 設定は変更していない" >&2
    return 1
  fi
  echo "- backup : $USER_SETTINGS.bak"

  while IFS='|' read -r id path expected label; do
    [ -z "${id:-}" ] && continue

    before=$(read_key "$USER_SETTINGS" "$path")

    tmp=$(mktemp "$USER_SETTINGS.XXXXXX") || {
      echo "Error: failed to create a temporary file next to $USER_SETTINGS" >&2
      return 1
    }
    # true / false / null / 数値は JSON リテラルとして書く。それ以外は文字列。
    # (期待値を "false" のような真偽値にした項目で文字列を書き込まないため)
    case "$expected" in
      true|false|null|[0-9]|[0-9]*[0-9]|-[0-9]*)
        jq --argjson v "$expected" "$path = \$v" "$USER_SETTINGS" > "$tmp" ;;
      *)
        jq --arg v "$expected" "$path = \$v" "$USER_SETTINGS" > "$tmp" ;;
    esac
    if [ $? -ne 0 ]; then
      rm -f "$tmp"
      echo "Error: failed to update $path in $USER_SETTINGS" >&2
      return 1
    fi
    if ! mv "$tmp" "$USER_SETTINGS"; then
      rm -f "$tmp"
      echo "Error: failed to replace $USER_SETTINGS. $USER_SETTINGS.bak から復元すること" >&2
      return 1
    fi
    if ! chmod 644 "$USER_SETTINGS"; then
      echo "Error: updated $USER_SETTINGS but failed to set its permissions to 644" >&2
      return 1
    fi

    printf -- "- %s: %s -> %s\n" "$label" "$before" "$expected"
    FIXED_COUNT=$((FIXED_COUNT + 1))
  done <<EOF
$FIX_TARGETS
EOF
}

# --- 実行 -------------------------------------------------------------------
USER_STATE=$(file_state "$USER_SETTINGS")

echo "=== Claude Code settings doctor ==="
echo
echo "[設定ファイル]"
printf -- "- managed : %s (%s)\n" "$MANAGED_SETTINGS" "$(file_state "$MANAGED_SETTINGS")"
printf -- "- local   : %s (%s)\n" "$LOCAL_SETTINGS" "$(file_state "$LOCAL_SETTINGS")"
printf -- "- project : %s (%s)\n" "$PROJECT_SETTINGS" "$(file_state "$PROJECT_SETTINGS")"
printf -- "- user    : %s (%s)  <- --fix の書き込み先\n" "$USER_SETTINGS" "$USER_STATE"
echo "  優先度: managed > local > project > user"
echo

if [ "$USER_STATE" = "invalid" ]; then
  echo "[診断]"
  echo "- [ERROR] $USER_SETTINGS が不正な JSON。設定全体が読み込まれない"
  echo "  先に JSON を修復すること。--fix も実行できない"
  echo
  echo "RESULT: ok=0 ng=0 fixable=0 fixed=0 user_settings_state=invalid"
  exit 0
fi

FIXED_COUNT=0

echo "[診断]"
diagnose

if [ "$FIX" = "yes" ] && [ -n "$FIX_TARGETS" ]; then
  echo "[修正]"
  if ! apply_fixes; then
    echo
    echo "RESULT: ok=$OK_COUNT ng=$NG_COUNT fixable=$FIXABLE_COUNT fixed=$FIXED_COUNT user_settings_state=$(file_state "$USER_SETTINGS") fix_error=yes"
    exit 1
  fi
  echo
  echo "[修正後の再診断]"
  diagnose
elif [ "$FIX" = "yes" ]; then
  echo "[修正]"
  echo "- --fix で直せる項目はない"
  echo
fi

echo "[サマリ]"
printf -- "- OK: %s / NG: %s\n" "$OK_COUNT" "$NG_COUNT"
if [ "$FIX" = "yes" ]; then
  printf -- "- 修正した項目: %s\n" "$FIXED_COUNT"
elif [ "$FIXABLE_COUNT" -gt 0 ]; then
  printf -- "- --fix で直せる項目: %s\n" "$FIXABLE_COUNT"
fi
echo

echo "RESULT: ok=$OK_COUNT ng=$NG_COUNT fixable=$FIXABLE_COUNT fixed=$FIXED_COUNT user_settings_state=$(file_state "$USER_SETTINGS")"

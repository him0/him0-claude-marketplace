#!/usr/bin/env bash
# auto-fix のマーカー定義 (watch-pr.sh / check-pr.sh から source される共通定義)
#
# auto_fix_marker:
#   auto-fix の返信に付ける識別子 (HTML コメントとして本文末尾に埋め込む)。
#   GitHub UI 上には表示されず、API レスポンスの body には含まれるため、
#   返信済みコメントを判別する用途に使う。
#   マーカー文言を変更する場合は SKILL.md の記載も同時に更新すること。
#
# persistent_meta_markers_json:
#   bot / CI が PR に自動投稿する「持続的メタコメント」のマーカー一覧 (JSON 配列)。
#   人手レビューではなく auto-fix が対応するアクションも存在しないため、未対応カウントから除外する。
#   デフォルトは CodeRabbit のサマリーコメントのみ (指摘はインラインコメントとして別途届くため、
#   サマリー本体は対応アクションのないメタコメント)。
#   プロジェクト固有の bot コメント (例: issue トラッカーのリンクバック、CI の進捗通知) が
#   あれば、その本文に含まれる HTML コメントマーカーをここに追加する。

# shellcheck disable=SC2034  # 参照は source 元スクリプト側
auto_fix_marker="<!-- ClaudeCode:auto-fix -->"

# shellcheck disable=SC2034
persistent_meta_markers_json='["<!-- This is an auto-generated comment: summarize by coderabbit.ai -->"]'

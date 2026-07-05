---
name: repo-recap
description: Generate a year-in-review or half-year visualization for a repository. Use when user asks for "repo recap", "年間レポート", "上半期レポート", "下半期レポート", "yearly summary", "recap", or wants to see repository statistics and contributions.
---

# Repo Recap - Repository Year in Review Generator

リポジトリの1年 (または半期) を振り返る HTML レポートを生成します。
データ収集から HTML 生成まで全てシェルスクリプトで完結するため、Read/Write ツールやデータの手動変換は不要です。

## 手順

1. 対象年と期間を決める。ユーザーの指定がなければ年は現在の年、期間は通年 (`full`)。
   - 「上半期」と言われたら `h1` (1-6月)、「下半期」と言われたら `h2` (7-12月)
2. スクリプトのディレクトリを解決する:
   - `$CLAUDE_PLUGIN_ROOT` が設定されていれば `$CLAUDE_PLUGIN_ROOT/skills/repo-recap`
   - 無ければこの SKILL.md が置かれているディレクトリ
3. 以下を1コマンドで実行する (YEAR は対象年に置き換え):

```bash
SKILL_DIR="${CLAUDE_PLUGIN_ROOT}/skills/repo-recap"

# 通年
"$SKILL_DIR/collect-data.sh" YEAR | "$SKILL_DIR/generate-recap.sh" > repo-recap-YEAR.html

# 上半期 (h1) / 下半期 (h2)
"$SKILL_DIR/collect-data.sh" YEAR h1 | "$SKILL_DIR/generate-recap.sh" > repo-recap-YEAR-h1.html
```

4. ブラウザで開く:

```bash
open repo-recap-YEAR.html   # macOS
```

## スクリプトの役割

- `collect-data.sh <year> [full|h1|h2]`: git log・GitHub PR/Issue・コントリビューター名寄せマップを収集し、期間情報つきの JSON を標準出力に出す
- `generate-recap.sh [data.json]`: JSON (省略時は標準入力) をテンプレートに埋め込み、HTML を標準出力に出す。ヒートマップや月次チャートは JSON の期間に合わせて描画される

## Notes

- 依存: `git`, `jq` (必須)、`gh` (任意。無い場合や GitHub リポジトリでない場合は PR/Issue が空になるだけで動作する)
- 名寄せ: noreply メールアドレスからローカルで解決し、GitHub API は1ページ (100件) だけ補完に使う。全コミットのページネーションはしない
- GitHub avatar は `https://github.com/{username}.png` から取得。取得できない場合は ui-avatars.com にフォールバック
- 失敗時のデバッグ: `collect-data.sh YEAR > /tmp/recap-data.json` で中間 JSON を確認できる

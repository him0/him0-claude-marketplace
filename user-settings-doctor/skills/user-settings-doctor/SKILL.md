---
name: user-settings-doctor
description: "Diagnose and fix Claude Code user settings (~/.claude/settings.json). Use when the user asks about settings.json, permission mode, デフォルトパーミッション, auto mode, 設定確認, 設定診断, or wants their Claude Code settings checked or corrected."
---

# Claude Code User Settings Doctor

`doctor.sh` が Claude Code の user settings を診断し、`--fix` を付けると期待値に揃えます。

どの項目をどの値にすべきかは全て `doctor.sh` 側に定義されています。
この手順書は個々の設定項目を知らないので、項目が増減しても手順は変わりません。

## 手順

1. スクリプトのディレクトリ `SKILL_DIR` を決める:
   - `$CLAUDE_PLUGIN_ROOT` が設定されていれば `$CLAUDE_PLUGIN_ROOT/skills/user-settings-doctor`
   - 設定されていなければ、この SKILL.md が置かれているディレクトリそのもの

2. 診断する。`--fix` を付けない限り設定ファイルは一切変更されない。
   `<SKILL_DIR>` は手順1で決めた実際のパスに置き換えてから実行する:

```bash
SKILL_DIR="<手順1で決めたパス>"
"$SKILL_DIR/doctor.sh"
```

3. 出力末尾の `RESULT:` 行で分岐する:
   - `ng=0` → 問題なし。`[診断]` の内容を要約して報告し、終了
   - `ng>0` かつ `fixable>0` → 直せる項目がある。`[NG]` の項目名・現在値・期待値と、
     なぜその値が良いかをユーザーに伝え、`--fix` を実行してよいか確認する
   - `ng>0` かつ `fixable=0` → user settings を直しても解決しない。
     `[診断]` の `!` 行に理由が出ているので、それをそのまま伝える
   - `user_settings_state=invalid` → JSON が壊れていて設定全体が読み込まれない。
     `--fix` も実行できないので、先に手で修復する

4. ユーザーが同意した項目がある場合のみ書き換える:

```bash
"$SKILL_DIR/doctor.sh" --fix
```

5. `--fix` の出力に含まれる `[修正後の再診断]` と `RESULT:` で反映を確認し、結果を報告する。

## 出力の読み方

- `[設定ファイル]`: 各スコープのパスと状態 (`ok` / `missing` / `invalid`)。
  `<- --fix の書き込み先` が付いている行が更新対象
- `[診断]`: 項目ごとに `[OK]` または `[NG]`。インデントされた行が現在値・期待値・理由で、
  `!` で始まる行は注意点、`→` で始まる行は `--fix` では解決しないことを示す
- `[修正]` / `[修正後の再診断]`: `--fix` を付けたときだけ出る
- `RESULT:`: 機械可読なサマリ (`ok` / `ng` / `fixable` / `fixed` / `user_settings_state`)

## 診断項目を増やす・期待値を変える

`doctor.sh` 冒頭の `CHECKS` に1行足す (または既存行の期待値を変える) だけでよい。
項目固有の注意書きが必要なら、同ファイルに `notes_<id>()` を定義する。
この SKILL.md を変更する必要はない。

## その他の設定を手で変更する場合

`doctor.sh` が扱うのは `CHECKS` に定義された項目だけ。
それ以外のキーを変えるときは、`[設定ファイル]` の `user` の行に出ているパスを対象にする
(`CLAUDE_CONFIG_DIR` があれば `$CLAUDE_CONFIG_DIR/settings.json`、無ければ `~/.claude/settings.json`)。

そのパスを Read してから Edit する。バックアップを取ってから編集し、編集後に
`jq . "<そのパス>"` で JSON が壊れていないか確認すること。

## Notes

- 依存: `jq` (必須)、`git` (任意。プロジェクト設定のパス解決に使う)
- `--fix` は設定ファイルを書き換える。ユーザーに確認せず勝手に実行しない
- `--fix` は書き換え前に `.bak` を作り、対象キー以外は保持する
- `~/.claude/` は保護パスなので、書き込み時は permission プロンプトが出る。これは正常な挙動

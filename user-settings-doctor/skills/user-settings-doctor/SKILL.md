---
name: user-settings-doctor
description: "Diagnose and configure Claude Code user settings (~/.claude/settings.json), especially whether the default permission mode is auto. Use when the user asks about settings.json, permission mode, デフォルトパーミッション, auto mode, 設定確認, 設定診断, or wants to change defaultMode / model / statusLine / permissions rules."
---

# Claude Code User Settings Doctor

`~/.claude/settings.json` の内容を診断し、必要なら書き換えます。
主目的は「デフォルトパーミッションが auto になっているか」の確認と設定です。

## 手順

1. スクリプトのディレクトリ `SKILL_DIR` を決める:
   - `$CLAUDE_PLUGIN_ROOT` が設定されていれば `$CLAUDE_PLUGIN_ROOT/skills/user-settings-doctor`
   - 設定されていなければ、この SKILL.md が置かれているディレクトリそのもの

2. 現状を確認する (読み取りのみ。書き換えはしない)。
   `<SKILL_DIR>` は手順1で決めた実際のパスに置き換えてから実行する:

```bash
SKILL_DIR="<手順1で決めたパス>"
"$SKILL_DIR/check-settings.sh"
```

3. 出力末尾の `RESULT:` 行で判定する。`effective_` 系がそのディレクトリで実際に効く値:
   - `effective_auto=yes` → auto が実際に効いている。ユーザーに報告して終了
   - `effective_auto=no` かつ `default_mode_auto=yes` → user/managed に auto はあるが効いていない。
     `effective_scope` と `effective_mode` (優先度の高いスコープによる上書き) か `auto_mode_disabled=yes` が原因。
     どちらかを伝える。上書きが原因の場合、user settings を書き換えても解決しない
   - `effective_auto=no` かつ `default_mode_auto=no` → 未設定。現在の `effective_mode` を伝え、
     auto にするかどうかをユーザーに確認する
   - `auto_mode_disabled=yes` → `disableAutoMode` により auto が封じられている。設定変更しても効かない
   - `user_settings_state=invalid` → JSON が壊れている。先に修復する

4. ユーザーが auto を望む場合のみ書き換える:

```bash
"$SKILL_DIR/set-default-mode.sh" auto
```

5. 書き換え後にもう一度 `check-settings.sh` を実行し、`effective_auto=yes` になったことを確認する。
   `effective_auto=no` のままなら上書きか `disableAutoMode` が残っているので、その原因を伝える。
   `defaultMode` はセッションの開始時モードを決める設定なので、実行中のセッションのモードは
   これを書き換えても切り替わらない。今のセッションで切り替えるには CLI なら `Shift+Tab` を使う、
   と伝えること。

## permissions.defaultMode の値

- `default` (別名 `manual`): 毎回確認する。未設定時の既定
- `acceptEdits`: ファイル編集と `mkdir` `mv` `cp` 等を自動承認
- `plan`: 調査と計画のみ。ソースは編集しない
- `auto`: classifier が背後で安全性を確認し、確認プロンプトをほぼ出さない
- `dontAsk`: 許可済みのツールだけ実行し、他は自動拒否
- `bypassPermissions`: 確認を全てスキップ。隔離環境専用

## auto を設定する際の注意

- auto は user スコープ (`~/.claude/settings.json`) か managed 設定でのみ有効。
  `.claude/settings.json` や `.claude/settings.local.json` に書いた `"auto"` は無視される
  (リポジトリが自分自身に auto を与えられないようにするため)
- 優先度は managed > local > project > user。project/local が `defaultMode` に別の値を持つと、
  そのディレクトリでは user の auto は上書きされる
- `permissions.disableAutoMode: "disable"` が入っていると auto は選べない。
  これはどのスコープの settings.json に書いても効く (managed に置くと上書きされないだけ)
- auto はプロンプトを減らすだけで安全を保証するものではない。ユーザーに確認せず勝手に設定しない

設定される JSON はこの形:

```json
{
  "permissions": {
    "defaultMode": "auto"
  }
}
```

## 確認だけしたい場合

`check-settings.sh` は読み取り専用で、以下も併せて表示する:

- 各スコープの settings.json の存在と JSON の妥当性
- 各スコープの `permissions.defaultMode`
- 優先度を解決した結果、実際に効く `defaultMode` とそのスコープ
- user の `allow` / `ask` / `deny` / `additionalDirectories` の件数
- `model`, `effortLevel`, `outputStyle`, `statusLine`, `env` のキー, `hooks` のイベント名, トップレベルキー一覧

## その他の設定を変更する場合

`set-default-mode.sh` は `permissions.defaultMode` 専用。
他のキー (`model`, `statusLine`, `env`, `hooks`, `permissions.allow` など) を変えるときは、
対象ファイルを自分で編集する。

対象ファイルは `check-settings.sh` / `set-default-mode.sh` と同じ解決規則で決めること。
`check-settings.sh` の出力の `[設定ファイル]` にある `user` の行がそのパスなので、それを使う
(`CLAUDE_CONFIG_DIR` があれば `$CLAUDE_CONFIG_DIR/settings.json`、無ければ `~/.claude/settings.json`)。

そのパスを Read してから Edit する。バックアップを取ってから編集し、編集後に
`jq . "<そのパス>"` で JSON が壊れていないか確認すること。

## Notes

- 依存: `jq` (必須)、`git` (任意。プロジェクト設定のパス解決に使う)
- `CLAUDE_CONFIG_DIR` が設定されている環境では、そのディレクトリの `settings.json` を対象にする
- `~/.claude/` は保護パスなので、書き込み時は permission プロンプトが出る。これは正常な挙動
- 設定の反映: `permissions` を含むほとんどの設定は保存時に再読み込みされる
  (`model` と `outputStyle` は再起動が必要)。ただし `defaultMode` が決めるのは
  セッションの開始時モードなので、再読み込みされても実行中のセッションのモードは変わらない

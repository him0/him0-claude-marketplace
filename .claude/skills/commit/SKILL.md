---
name: "commit"
description: "変更を git リポジトリにコミットし、必要に応じて push する"
argument-hint: "[--push | -p] [--main | -m]"
allowed-tools: TodoWrite Bash(gh *) Bash(git switch *) Bash(git add *) Bash(git commit *) Bash(git push *) Bash(git rev-parse *) Bash(git log *) Bash(git diff *)
---

# Quick Reference

```bash
/commit
/commit --push  # コミットして push する
/commit --main  # ブランチを作らずデフォルトブランチに直接コミットする
/commit -m -p   # デフォルトブランチに直接コミットして push する
```

# Workflow

以下のコマンドを並列実行して情報を集める:

- `git status`
- `git diff`
- `git log --oneline -5`
- `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` (デフォルトブランチの取得)

`--main` または `-m` が指定された場合は、ブランチを作らずデフォルトブランチに直接コミットする。

それ以外の場合、現在のブランチがデフォルトブランチで差分があるなら、新しいブランチを作成する。
ブランチ名は `<type>/<kebab-case-topic>` 形式にする (例: `feat/git-ops-kit`, `refactor/auto-fix-monitor-scripts`)。

プラグイン配下のファイル (`<plugin-name>/` ディレクトリ) を変更するコミットでは、対応する `.claude-plugin/plugin.json` の `version` が上がっているかを確認する。上がっていなければ同じコミットでインクリメントする (バージョンを上げないと `claude plugin update` でキャッシュが更新されないため)。

`--push` または `-p` が指定された場合は、ブランチをリモートリポジトリに push する。

# コミットメッセージ

Conventional Commits 形式を使用する:

```
<type>(<scope>)!: <subject>
(空行)
<body>
(空行)
<footer / BREAKING CHANGE / 関連 issue など>
```

必須: type, subject
任意: scope, ! (breaking change), body, footer

このリポジトリの慣習:

- subject は英語で書く (例: `fix(git-ops-kit): emit only additions in watch events`)
- scope にはプラグイン名またはコンポーネント名を使う (例: `git-ops-kit`, `status-line`, `skills`, `codex`)

## type 一覧

feat : 新機能
fix : バグ修正
docs : ドキュメントのみ
style : フォーマット (空白、セミコロンなど)
refactor : リファクタリング (機能追加でもバグ修正でもない)
perf : パフォーマンス改善
test : テストの追加・修正
build : ビルドシステム / 依存関係 / 配布物
ci : CI の設定 / スクリプト
chore : 雑務 (src / test 以外)
revert : 以前のコミットの取り消し

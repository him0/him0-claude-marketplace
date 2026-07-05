---
name: "pull-request"
description: "Pull Request を作成する。既に作成済みの場合はコミットを push し、最新の変更に基づいて PR のタイトルと説明を更新する"
argument-hint: "[--draft | -d] [--base <branch>] [<Ticket-URL>]"
allowed-tools: TodoWrite Bash(gh *) Bash(git switch *) Bash(git add *) Bash(git commit *) Bash(git push *) Bash(git rev-parse *) Bash(git log *) Bash(git diff *) Bash(gh pr *) Skill(commit)
---

# Quick Reference

```bash
/pull-request                 # PR を作成
/pull-request --draft         # draft PR を作成する
/pull-request --base feat/foo # base ブランチを指定して PR を作成 (スタック PR)
/pull-request <Ticket-URL>    # チケット URL を含めて PR 作成
```

## オプション

- `--draft` / `-d`: draft PR として作成する
- `--base <branch>`: PR の base ブランチを指定する (未指定時はデフォルトブランチ)。先行 PR のブランチを指定すればスタック PR になる
- `<Ticket-URL>` (任意): PR の説明にチケット URL を含める

# Workflow

## 最初に行う分岐判定

`gh pr view --json number,state,baseRefName` を 1 回実行し (結果は後段でも使う)、処理モードを決める:

- 現在のブランチに open PR が存在する → 「既存 PR 更新」
- open PR が無い → 「新規 PR 作成」。`gh pr view` がエラーになる場合 (`no pull requests found for branch ...` = PR 未作成) も open PR なしとみなし、停止せずこちらに倒す

## 新規 PR 作成

1. `/commit --push` で変更をコミット・push する (現在のブランチがデフォルトブランチの場合の新ブランチ自動作成は commit skill 側が行う)
2. `.github/pull_request_template.md` に従って PR を作成する (`--base <branch>` 指定時は `gh pr create --base <branch>`。未指定時はデフォルトブランチが base になる)
3. テンプレートが日本語の場合、本文も日本語で書く
4. `--base` で先行 PR のブランチを指定した場合 (スタック PR) は、PR description の冒頭に「Stacked on #<先行PR番号>」を明記する
5. <Ticket-URL> が指定された場合は、`.github/pull_request_template.md` のガイドラインに従って PR の説明で使用する (参照リンクや auto-close キーワードなど)

## 既存 PR 更新

1. 最新のコミットをリモートブランチに push する
2. `git log <base>..HEAD` で PR に含まれる全コミットを確認する (`<base>` は分岐判定で取得済みの `baseRefName` を使い、デフォルトブランチ固定にしない — スタック PR の更新時に先行ブランチ分のコミットが説明へ混入するのを防ぐため)
3. `gh pr edit` で PR のタイトルと説明を更新する
4. 説明は全コミットに基づいて書き直す。冗長にならないよう追記はしない

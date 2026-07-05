---
name: "pull-request"
description: "Pull Request を作成する。既に作成済みの場合はコミットを push し、最新の変更に基づいて PR のタイトルと説明を更新する"
argument-hint: "[--draft | -d] [--stack] [<Ticket-URL>]"
allowed-tools: TodoWrite Bash(gh *) Bash(git switch *) Bash(git add *) Bash(git commit *) Bash(git push *) Bash(git rev-parse *) Bash(git log *) Bash(git diff *) Bash(gh pr *) Skill(commit)
---

# Quick Reference

```bash
/pull-request
/pull-request --draft  # draft PR を作成する
/pull-request --stack  # 現在のブランチを base にした stacked PR を作成する
```

# Workflow

変更のコミットと push には `/commit --push` を使う。
現在のブランチがデフォルトブランチの場合は、新しいブランチが自動で作成される。

## 新規 Pull Request の作成

Pull Request が存在しない場合、`.github/pull_request_template.md` に従って作成する。
テンプレートが日本語を含む場合は本文を日本語で書く。
`--draft` または `-d` が指定された場合は draft Pull Request として作成する。

<Ticket-URL> (任意)。指定された場合は `.github/pull_request_template.md` の指示に従って PR の説明などで使用する (参照リンクや auto-close キーワードなど)。

## 既存 Pull Request の更新

Pull Request が既に存在する場合:

1. 最新のコミットをリモートブランチに push する
2. PR に含まれる全コミットを確認する (`git log <default-branch>..HEAD` を使う)
3. `gh pr edit` で PR のタイトルと説明を更新する
4. 説明は全コミットに基づいて書き直す。冗長にならないよう追記はしない

## Stacked Pull Request の作成

`--stack` が指定された場合:

1. 現在のブランチ名を取得する (これが新しい PR の base ブランチになる)
2. 自動生成した名前で新しいブランチを作成する (例: `<current-branch>-part2`, `<current-branch>-part3`)
3. 新しいブランチに変更をコミットして push する
4. `gh pr create --base <current-branch>` で新しい PR を作成する

大きな PR をレビューしやすい単位に分割する際に有用。

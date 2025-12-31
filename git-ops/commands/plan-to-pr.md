---
description: "Plan を立案・実行し、PR を作成する"
argument-hint: [--draft | -d] [<task-description>]
allowed-tools:
  - EnterPlanMode
  - ExitPlanMode
  - TodoWrite
  - AskUserQuestion
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - "Bash(git *)"
  - "SlashCommand(/him0-git-ops:pull-request)"
---

# Quick Reference

```bash
/plan-to-pr Add user authentication feature
/plan-to-pr --draft Fix pagination bug in API
```

# Workflow

## 1. タスク受け取り

引数 `<task-description>` から実装するタスクの説明を取得する。

## 2. Plan Mode に入る

`EnterPlanMode` ツールを使用して Plan mode に入る。

Plan mode では:
1. コードベースを探索して関連するファイルを特定
2. 変更が必要なファイルをリストアップ
3. 実装手順を詳細に計画
4. プランファイル (`~/.claude/plans/`) に計画を記述

## 3. プラン確認・承認

プランが完成したら `ExitPlanMode` を呼び出してユーザーの承認を求める。
ユーザーが承認するまで実装には進まない。

## 4. 実装実行

承認後、プランに基づいてコード変更を実行する:

- 必要なファイルの作成・編集
- テストの追加・更新（必要な場合）
- 関連するドキュメントの更新（必要な場合）

## 5. 変更確認

実装完了後、変更内容をユーザーに提示して確認を取る。
`git diff` で変更箇所を表示し、問題がないか確認する。

## 6. PR 作成

確認後、`/him0-git-ops:pull-request` を呼び出して PR を作成する。
`--draft` オプションが指定されている場合は、そのまま引き継ぐ。

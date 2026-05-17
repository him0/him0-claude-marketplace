---
name: "ship"
description: "実装から PR 作成、CI/レビュー対応までを一気通貫で行う"
argument-hint: "[--plan | -p] [--draft | -d] <task-description>"
allowed-tools: TodoWrite Read Write Edit Glob Grep Bash(git *) Skill(him0-git-ops:pull-request) Skill(him0-git-ops:auto-fix) EnterPlanMode ExitPlanMode
---

# Quick Reference

```bash
/ship Add dark mode toggle to settings
/ship --draft Fix typo in README
/ship --plan Redesign authentication flow
```

# Workflow

## 0. Plan モード

`--plan` または `-p` が指定された場合、`EnterPlanMode` を呼び出して Plan モードに入る。

<task-description> をもとに設計・実装計画を作成し、ユーザーの承認を得る。Plan が承認されたらステップ 1 へ進む。

## 1. 実装

`git status` でクリーンなブランチであることを確認し、<task-description> (Plan モードの場合は承認された計画) に基づいて実装する。

複雑なタスクの場合は `TodoWrite` で進捗を管理する。

## 2. PR 作成

`/him0-git-ops:pull-request` を呼び出す（`--draft` 指定時はそのまま渡す）。

## 3. CI/レビュー対応

`/him0-git-ops:auto-fix --watch` を呼び出して CI 失敗とレビューコメントの継続監視・自動修正モードに入る。

# PR コメント投稿に関する注意

PR コメントとして投稿すると外部ワークフローを起動する特殊コマンドがある。以下のルールを守ること。

## `@claude approve-with-followup <理由>` は投稿禁止

このコマンドは「未解消の指摘を follow-up に倒した上で直接 approve する」明示オーバーライドであり、**人間の判断が必要な場面で承認がかかってしまうリスクがある**。ship / auto-fix のフローからは絶対に投稿しない。

- `gh pr comment` 等でこの文字列を含むコメントを自動投稿してはならない
- レビュー指摘の対応が難しい / ループから抜けられない場合の逃げ道として使わない
- ユーザーから明示指示があった場合のみ、コマンド文字列を提示してユーザー自身に投稿してもらう

## `@claude review` は必要に応じて投稿してよい

`@claude review` / `@claude review <追加指示>` は CI レビューを再起動するためのコマンド。修正 push 後に再レビューが必要なタイミング等では、必要に応じて投稿して構わない。

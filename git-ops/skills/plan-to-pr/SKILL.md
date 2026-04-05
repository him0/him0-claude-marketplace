---
name: "plan-to-pr"
description: "プランを作成し、実装して PR を作成する"
argument-hint: "[--draft | -d] [<task-description>]"
allowed-tools: EnterPlanMode ExitPlanMode TodoWrite AskUserQuestion Read Write Edit Glob Grep Bash(git *) Skill(him0-git-ops:pull-request) Skill(him0-git-ops:auto-fix)
---

# Quick Reference

```bash
/plan-to-pr Add user authentication feature
/plan-to-pr --draft Fix pagination bug in API
```

# Workflow

## 0. 準備

最重要: ファイル探索を行う前に、必ず `EnterPlanMode` を呼び出す。

## 1. プラン

<task-description> を確認し、必要な変更をプランニングする。

プラン完了後、`ExitPlanMode` を呼び出してユーザーの承認を得る。

## 2. 実装

`git status` でクリーンなブランチであることを確認し、承認されたプランに基づいてコードを変更する。

## 3. PR 作成

`git diff` で変更を確認し、`/him0-git-ops:pull-request` を呼び出す（`--draft` 指定時はそのまま渡す）。

## 4. CI とレビューの自動修正

PR 作成後、`/him0-git-ops:auto-fix --watch` を呼び出して CI 失敗とレビューコメントの継続監視・自動修正モードに入る。

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

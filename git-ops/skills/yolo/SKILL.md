---
name: "yolo"
description: "プランニングをスキップし、即座に実装して PR を作成する"
argument-hint: "[--draft | -d] <task-description>"
allowed-tools: TodoWrite Read Write Edit Glob Grep Bash(git *) Skill(him0-git-ops:pull-request) Skill(him0-git-ops:auto-fix)
---

# Quick Reference

```bash
/yolo Add dark mode toggle to settings
/yolo --draft Fix typo in README
```

# Workflow

## 1. 実装

`git status` でクリーンなブランチであることを確認し、<task-description> をプランニングなしで直接実装する。

複雑なタスクの場合は `TodoWrite` で進捗を管理する。

## 2. PR 作成

`git diff` で変更を確認し、`/him0-git-ops:pull-request` を呼び出す（`--draft` 指定時はそのまま渡す）。

## 3. CI とレビューの自動修正

PR 作成後、`/him0-git-ops:auto-fix --watch` を呼び出して CI 失敗とレビューコメントの継続監視・自動修正モードに入る。

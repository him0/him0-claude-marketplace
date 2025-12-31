---
description: "Create a plan, execute it, and create a PR"
argument-hint: "[--draft | -d] [<task-description>]"
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

## 0. Preparation

CRITICAL: Immediately call `EnterPlanMode` before doing ANY file exploration.

## 1. Plan

Review the <task-description> and plan the necessary changes.

After planning, call `ExitPlanMode` for user approval.

## 2. Implement

Verify clean branch with `git status`, then execute code changes based on the approved plan.

## 3. Create PR

Review changes with `git diff`, then call `/him0-git-ops:pull-request` (pass `--draft` if specified).

## 4. Report and Iterate

Report to user: implementation summary, modified files, PR link.
If additional changes requested, implement and call `/him0-git-ops:pull-request` again. Repeat until satisfied.

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

## 1. Pre-check

Verify clean branch state with `git status`. If uncommitted changes exist, prompt user to commit or stash first.

## 2. Plan

CRITICAL: Immediately call `EnterPlanMode` before doing ANY file exploration.
After planning, call `ExitPlanMode` for user approval.

## 3. Implement

Execute code changes based on the approved plan (create/edit files, tests, docs as needed).

## 4. Create PR

Review changes with `git diff`, then call `/him0-git-ops:pull-request` (pass `--draft` if specified).

## 5. Report and Iterate

Report to user: implementation summary, modified files, PR link.
If additional changes requested, implement and call `/him0-git-ops:pull-request` again. Repeat until satisfied.

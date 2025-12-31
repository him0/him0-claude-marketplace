---
description: "Skip planning, implement directly, and create a PR immediately"
argument-hint: "[--draft | -d] <task-description>"
allowed-tools:
  - TodoWrite
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
/yolo Add dark mode toggle to settings
/yolo --draft Fix typo in README
```

# Workflow

## 1. Implement

Verify clean branch with `git status`, then directly implement the <task-description> without planning phase.

Use `TodoWrite` to track implementation progress for complex tasks.

## 2. Create PR

Review changes with `git diff`, then call `/him0-git-ops:pull-request` (pass `--draft` if specified).

## 3. Iterate

If additional changes requested, implement and call `/him0-git-ops:pull-request` again. Repeat until satisfied.

---
description: "Create a plan, execute it, and create a PR"
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

## 1. Pre-check

Verify that the branch is in a clean state (no uncommitted changes) using `git status`.
If there are uncommitted changes, prompt the user to commit or stash them first.

## 2. Receive Task

Get the task description from the `<task-description>` argument.

## 3. Enter Plan Mode

Use the `EnterPlanMode` tool to enter Plan mode.

In Plan mode:
1. Explore the codebase to identify related files
2. List files that need to be modified
3. Plan the implementation steps in detail
4. Write the plan to a plan file (`~/.claude/plans/`)

## 4. Plan Review and Approval

Once the plan is complete, call `ExitPlanMode` to request user approval.
Do not proceed with implementation until the user approves.

## 5. Execute Implementation

After approval, execute code changes based on the plan:

- Create/edit necessary files
- Add/update tests (if needed)
- Update related documentation (if needed)

## 6. Verify Changes

After implementation is complete, present the changes to the user for verification.
Display the changes using `git diff` and confirm there are no issues.

## 7. Create PR

After verification, call `/him0-git-ops:pull-request` to create the PR.
If the `--draft` option was specified, pass it along.

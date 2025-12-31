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

## 6. Verify and Create PR

After implementation is complete:

1. Use `git diff` to review the changes internally
2. If there are no issues, proceed to create the PR
3. Call `/him0-git-ops:pull-request` to create the PR
   - If the `--draft` option was specified, pass it along

## 7. Report and Confirm

After the PR is created:

1. Report to the user:
   - Summary of what was implemented
   - List of modified files
   - PR link
2. Ask the user if there are any additional implementations needed

## 8. Additional Implementation (if needed)

If the user requests additional changes:

1. Implement the requested changes
2. Update the PR by calling `/him0-git-ops:pull-request` again
3. Report the updates and ask if there are more changes needed
4. Repeat until the user is satisfied

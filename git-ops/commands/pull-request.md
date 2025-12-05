---
description: "Create a Pull Request. If one has already been created, push the commit and update the PR title and description based on the latest changes."
argument-hint: [--draft | -d] [--stack] [<Ticket-URL>]
allowed-tools:
  - TodoWrite
  - "Bash(gh *)"
  - "Bash(git switch *)"
  - "Bash(git add *)"
  - "Bash(git commit *)"
  - "Bash(git push *)"
  - "Bash(git rev-parse *)"
  - "Bash(git log *)"
  - "Bash(git diff *)"
  - "Bash(gh pr *)"
  - "SlashCommand(/him0-git-ops:commit)"
---

# Quick Reference

```bash
/pull-request
/pull-request --draft  # Create a draft PR
/pull-request --stack  # Create stacked PR with current branch as base
```

# Workflow

Use `/him0-git-ops:commit --push` to commit and push changes.
If the current branch is the default branch, a new branch will be created automatically.

## Creating a New Pull Request

If no Pull Request exists, create one following the `.github/pull_request_template.md`.
If the template includes Japanese, write the body in Japanese.
If the `--draft` or `-d` option is provided, create a draft Pull Request instead.

<Ticket-URL> (optional). If supplied, use it in the PR description (and elsewhere as directed) following the `.github/pull_request_template.md` guidelines (e.g., reference or auto-close keywords).

## Updating an Existing Pull Request

If a Pull Request already exists:

1. Push the latest commits to the remote branch
2. Review all commits in the PR (use `git log <default-branch>..HEAD`)
3. Update the PR title and description using `gh pr edit`
4. Rewrite the description based on all commits - do not append to avoid redundancy

## Creating a Stacked Pull Request

If `--stack` option is provided:

1. Get the current branch name (this will be the base branch for the new PR)
2. Create a new branch with auto-generated name (e.g., `<current-branch>-part2`, `<current-branch>-part3`)
3. Commit and push changes to the new branch
4. Create a new PR with `gh pr create --base <current-branch>`

This is useful for splitting a large PR into smaller, reviewable pieces.

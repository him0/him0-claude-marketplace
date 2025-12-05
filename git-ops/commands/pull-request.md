---
description: "Create a Pull Request. If one has already been created, push the commit and update the PR title and description based on the latest changes."
argument-hint: [--draft | -d] [<Ticket-URL>]
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
/_git-pull-request
/_git-pull-request --draft # Create a draft PR
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

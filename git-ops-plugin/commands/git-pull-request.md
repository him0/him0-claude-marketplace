---
allowed-tools: TodoWrite, "Bash(gh *)", "Bash(git switch *)", "Bash(git add *)", "Bash(git commit *)", "Bash(git push *)",SlashCommand(/_git-commit)
description: "Create a Pull Request. If one has already been created, push the commit to proceed with the PR."
argument-hint: [--draft | -d] [<Ticket-URL>]
---

# Quick Reference

```basho
/_git-pull-request
/_git-pull-request --draft # Create a draft PR
```

# Workflow

Use `/_git-commit --push` to commit and push changes.
If the current branch is `main`, a new branch will be created automatically.

If no Pull Request exists, create one following the `.github/PULL_REQUEST_TEMPLATE`.
If the template includes Japanese, write the body in Japanese.
If the `--draft` or `-d` option is provided, create a draft Pull Request instead.

<Ticket-URL> (optional). If supplied, use it in the PR description (and elsewhere as directed) following the .github/PULL_REQUEST_TEMPLATE guidelines (e.g., reference or auto-close keywords).

---
allowed-tools: TodoWrite, "Bash(gh *)", "Bash(git switch *)", "Bash(git add *)", "Bash(git commit *)", "Bash(git push *)", "Bash(gh pr *)", "SlashCommand(/him0-git-ops-plugin:commit)"
description: "Create a Pull Request. If one has already been created, push the commit and update the PR title and description based on the latest changes."
argument-hint: [--draft | -d] [<Ticket-URL>]
---

# Quick Reference

```basho
/_git-pull-request
/_git-pull-request --draft # Create a draft PR
```

# Workflow

Use `/him0-git-ops-plugin:commit --push` to commit and push changes.
If the current branch is `main`, a new branch will be created automatically.

## Creating a New Pull Request

If no Pull Request exists, create one following the `.github/pull_request_template.md`.
If the template includes Japanese, write the body in Japanese.
If the `--draft` or `-d` option is provided, create a draft Pull Request instead.

<Ticket-URL> (optional). If supplied, use it in the PR description (and elsewhere as directed) following the `.github/pull_request_template.md` guidelines (e.g., reference or auto-close keywords).

## Updating an Existing Pull Request

If a Pull Request already exists for the current branch:

1. Push the latest commits to the remote branch
2. Review all commits in the PR (use `git log main..HEAD` or equivalent to see all commits since the branch diverged)
3. Update the PR title and description using `gh pr edit` to reflect the current state of changes
4. **IMPORTANT**: When updating the description, completely rewrite it based on all commits in the PR - do NOT append to the existing description
5. Analyze the full scope of changes and create a cohesive, well-structured description that accurately represents the entire PR
6. Avoid redundancy and duplication in the description - each point should be mentioned once

### Key Guidelines for PR Updates

- **Rewrite, don't append**: Always generate a fresh description that encompasses all changes, rather than adding new content to the existing description
- **Prevent description bloat**: Keep the description concise and avoid redundant information that may accumulate from multiple updates
- **Reflect current state**: The title and description should accurately represent the complete set of changes in the PR, not just the latest commits
- **Maintain consistency**: Follow the same template and style as new PR creation

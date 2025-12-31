---
description: "Fetch and merge the default branch into current branch with auto conflict resolution"
argument-hint: "[--rebase | -r] [--no-auto-resolve]"
allowed-tools:
  - TodoWrite
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
  - "Bash(gh repo view *)"
  - "Bash(git fetch *)"
  - "Bash(git merge *)"
  - "Bash(git rebase *)"
  - "Bash(git status *)"
  - "Bash(git diff *)"
  - "Bash(git log *)"
  - "Bash(git rev-parse *)"
  - "Bash(git branch *)"
  - "Bash(git checkout *)"
  - "Bash(git add *)"
  - "Bash(git reset *)"
---

# Quick Reference

```bash
/merge-main                    # Merge default branch into current branch
/merge-main --rebase           # Rebase onto default branch
/merge-main --no-auto-resolve  # Skip auto conflict resolution
```

# Workflow

1. **Pre-check**: Ensure working tree is clean and not on default branch
2. **Fetch and merge**: `git fetch` then `git merge` (or `git rebase` with `-r`)
3. **Conflict resolution**: Auto-resolve conflicts unless `--no-auto-resolve`
   - If auto-resolution fails, ask user for guidance
4. **Report**: Summary of merged commits and resolved conflicts

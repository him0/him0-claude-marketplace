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
/merge-main --rebase           # Rebase current branch onto default branch
/merge-main --no-auto-resolve  # Ask user for guidance on any conflicts
```

# Workflow

## 1. Pre-merge Checks

Run these commands in parallel:
- `git status` - Ensure working tree is clean
- `git rev-parse --abbrev-ref HEAD` - Get current branch name
- `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` - Get default branch

**Abort conditions:**
- Working tree has uncommitted changes: Inform user to commit or stash first
- Current branch is the default branch: Inform user they are already on default branch

## 2. Fetch and Merge

1. Fetch latest changes:
   ```bash
   git fetch origin <default-branch>
   ```

2. Show commits to be merged:
   ```bash
   git log --oneline HEAD..origin/<default-branch>
   ```

3. Execute merge or rebase:
   - Default: `git merge origin/<default-branch>`
   - With `--rebase` or `-r`: `git rebase origin/<default-branch>`

## 3. Conflict Resolution

If merge succeeds without conflicts, report success and skip to step 4.

If conflicts occur:
1. List conflicted files: `git status`
2. For each conflicted file (unless `--no-auto-resolve`):
   - Read the file content using Read tool
   - Identify conflict markers: `<<<<<<<`, `=======`, `>>>>>>>`
   - Analyze both versions and attempt intelligent resolution:
     - Both sides add non-overlapping content: combine both
     - Both sides add same imports/dependencies: deduplicate
     - Both sides modify different parts: apply both
     - Identical changes: keep one
   - If resolvable: write resolved content using Edit tool, then `git add <file>`
   - If not resolvable: ask user for guidance using AskUserQuestion

3. After all files resolved:
   - For merge: Git auto-creates merge commit
   - For rebase: `git rebase --continue`

If user wants to abort:
- For merge: `git merge --abort`
- For rebase: `git rebase --abort`

## 4. Completion Report

Report to user:
- Number of commits merged/rebased
- List of files with conflicts resolved (if any)
- Resolution method per file (auto/manual)
- Current branch status

---
allowed-tools: TodoWrite, "Bash(gh *)", "Bash(gh pr edit *)", "Bash(git switch *)", "Bash(git add *)", "Bash(git commit *)", "Bash(git push *)"
description: "commit changes to git repository and push if needed"
argument-hint: [--push | -p]
---

# Quick Reference

```bash
/commit
/commit --push # Commit and push changes
```

# Workflow

If the current branch is `main` and there are differences, create a new branch.
Give the branch an appropriate name and commit the changes.

If `--push` or `-p` option is given, push the branch to the remote repository.

If a Pull Request already exists for the current branch, after pushing new commits, update the PR's title and description to reflect the latest changes using `gh pr edit`.

# Commit Message

Use the Conventional Commits format for commit messages:

```
<type>(<scope>)!: <subject>
(blank line)
<body>
(blank line)
<footer / BREAKING CHANGE / related issue(s) etc.>
```

Required: type, subject
Optional: scope, ! (breaking change), body, footer

## type list

feat : New feature
fix : Bug fix
docs : Documentation only
style : Formatting (whitespace, semicolons, etc.)
refactor : Refactoring (not a feature, not a bug fix)
perf : Performance improvement
test : Add/modify tests
build : Build system / dependencies / distribution
ci : CI configuration / scripts
chore : Chore (other than src / test)
revert : Revert previous commit

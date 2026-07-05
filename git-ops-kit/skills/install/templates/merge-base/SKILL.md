---
name: "merge-base"
description: "Fetch and merge the PR base branch (or repo default branch) into current branch with auto conflict resolution"
argument-hint: "[--rebase | -r] [--no-auto-resolve] [--branch <ref>]"
allowed-tools: TodoWrite Read Write Edit Grep Glob AskUserQuestion Bash(gh repo view *) Bash(gh pr view *) Bash(git fetch *) Bash(git merge *) Bash(git rebase *) Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git rev-parse *) Bash(git branch *) Bash(git checkout *) Bash(git add *) Bash(git reset *)
---

# Quick Reference

```bash
/merge-base                    # Merge PR base (or default branch) into current branch
/merge-base --rebase           # Rebase onto base instead of merging
/merge-base --no-auto-resolve  # Skip auto conflict resolution
/merge-base --branch develop   # Force a specific branch as the merge target
```

# Workflow

1. Pre-check: ワーキングツリーがクリーンで、現在ブランチが取り込み対象ブランチ自身でないことを確認
2. 取り込み対象ブランチの決定:
   - `--branch <ref>` が指定されたらそれを使う
   - そうでなければ `gh pr view --json baseRefName` で現在ブランチに紐づく PR の base を取得
   - PR が見つからなければ `gh repo view --json defaultBranchRef` のデフォルトブランチにフォールバック
   - 決定したブランチを 1 行で報告する (例: "Merging origin/release-1.2 (PR base) into feat/foo")
3. Fetch and merge: `git fetch origin <target>` → `git merge origin/<target>` (`-r` の場合は `git rebase origin/<target>`)
4. Conflict resolution: `--no-auto-resolve` でなければ自動解消を試みる。残コンフリクトがあればファイル一覧と要約を報告してユーザー判断を仰ぐ
5. Report: 取り込んだコミット数、解消したコンフリクトファイル、最終 HEAD を要約

---
name: "auto-fix"
description: "CI ステータスと PR レビューコメントを確認し、問題を自動修正してコミット＆プッシュする"
argument-hint: "[--watch | -w] [--ci-only] [--reviews-only]"
allowed-tools: TodoWrite Read Write Edit Glob Grep Bash(git *) Bash(gh *) Skill(him0-git-ops:commit) Skill(loop)
---

# Quick Reference

```bash
/auto-fix                    # CI 失敗とレビューコメントを1回修正
/auto-fix --ci-only          # CI 失敗のみ対象
/auto-fix --reviews-only     # レビューコメントのみ対象
/auto-fix --watch            # /loop で5分間隔の継続監視モード
```

# Workflow

## 0. Watch モード

`--watch` または `-w` が指定された場合、`/loop 5m /him0-git-ops:auto-fix` を呼び出して継続監視モードに入る。以降のステップは実行しない。

## 1. PR の確認

以下のコマンドを並列実行:
- `gh pr view --json number,headRefName,state,url` で現在のブランチに紐づく PR を確認
- `git status` でワーキングツリーがクリーンか確認

PR が見つからなければ停止してユーザーに通知する。

## 2. CI とレビューの確認

以下のコマンドを並列実行:
- `gh pr checks` で CI チェックステータスを取得
- `gh api repos/{owner}/{repo}/pulls/{number}/comments` でインラインレビューコメントを取得
- `gh pr view --json reviews,comments` で PR レベルのコメントを取得

結果を分類:
- CI ステータス: 全通過、一部 pending、一部失敗
- レビュー: コード変更を求める未対応コメントの有無

全チェック通過 & 未対応コメントなし → 成功を報告して終了。

CI チェックが pending 中 → "CI 実行中" と報告して終了。次の `/loop` で再チェックされる。

## 3. CI 失敗の修正 (`--reviews-only` の場合はスキップ)

失敗したチェックごとに:
1. `gh pr checks --json name,state,link` から run ID を取得
2. `gh run view <run-id> --log-failed` で失敗ログを取得
3. ログが長い場合は各失敗ステップの末尾100行に絞る
4. 原因を特定: テスト失敗、lint エラー、型エラー、ビルドエラーなど
5. 該当するソースファイルを読み取り、修正を適用

## 4. レビューコメントの修正 (`--ci-only` の場合はスキップ)

未対応のレビューコメントごとに:
1. コメント本文、ファイルパス、行範囲を読み取る
2. 該当ファイルと周辺コンテキストを確認
3. 要求された変更を適用

## 5. コミットとプッシュ

`/him0-git-ops:commit --push` を呼び出して修正をコミット＆プッシュする。

## 6. 報告

修正内容のサマリーを報告:
- 対応した CI 失敗
- 対応したレビューコメント
- 変更したファイル

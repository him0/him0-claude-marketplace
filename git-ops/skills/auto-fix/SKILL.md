---
name: "auto-fix"
description: "CI ステータスと PR レビューコメントを確認し、問題を自動修正してコミット＆プッシュする"
argument-hint: "[--watch | -w] [--ci-only] [--reviews-only]"
allowed-tools: TodoWrite Read Write Edit Glob Grep Bash(git *) Bash(gh *) Bash(*/scripts/*.sh *) Skill(him0-git-ops:commit) Monitor TaskStop
---

# Quick Reference

```bash
/auto-fix                    # CI 失敗とレビューコメントを1回修正
/auto-fix --ci-only          # CI 失敗のみ対象
/auto-fix --reviews-only     # レビューコメントのみ対象
/auto-fix --watch            # Monitor で継続監視し、問題検出時に自動修正
```

# Workflow

## 0. Watch モード

`--watch` または `-w` が指定された場合、まず現在の状況を確認してから Monitor による継続監視を開始する。

1. ステップ 1〜5 を通常どおり実行し、既存の CI 失敗やレビューコメントがあれば先に修正する
2. このスキルの `scripts/watch-pr.sh` を Monitor で起動する:
   - `command`: `bash <SKILL_DIR>/scripts/watch-pr.sh <owner/repo> <pr-number> 60`
   - `persistent: true` でセッション終了まで監視を継続
   - `description`: "PR #<number> の CI/レビュー監視"
3. Monitor からの通知に応じて行動する:
   - `ACTION_NEEDED` → ステップ 1 から修正フローを実行。修正完了後は次の通知を待つ
   - `NEW_COMMENTS` → 新しいコメント内容を確認し、コード変更の要求であればステップ 3 から修正フローを実行
   - `PENDING` → 何もせず次の通知を待つ
   - `ALL_CLEAR` → 何もせず次の通知を待つ
   - `MERGED` → PR がマージされたことを報告して終了 (Monitor は自動終了)
   - `CLOSED` → PR がクローズされたことを報告して終了 (Monitor は自動終了)
4. ユーザーが監視停止を求めたら TaskStop で Monitor を停止する

## 1. 状況の取得

`scripts/check-pr.sh` を実行して PR・CI・レビューの状況を一括取得する:

```bash
bash <SKILL_DIR>/scripts/check-pr.sh [--ci-only] [--reviews-only]
```

出力は JSON。`summary.status` に応じて分岐:
- `"error"` キーあり → PR が見つからない。停止してユーザーに通知
- `"ALL_CLEAR"` → 成功を報告して終了
- `"PENDING"` → "CI 実行中" と報告して終了。Watch モードの場合は次のポーリングで再チェック
- `"ACTION_NEEDED"` → ステップ 2, 3 へ進む

## 2. CI 失敗の修正

`ci.failed` 配列の各エントリに対して:
1. `scripts/get-ci-logs.sh <link>` で失敗ログを取得
2. 原因を特定: テスト失敗、lint エラー、型エラー、ビルドエラーなど
3. 該当するソースファイルを読み取り、修正を適用

## 3. レビューコメントの修正

`reviews.comments` と `reviews.changes_requested` の各エントリに対して:
1. コメントの `path`, `line`, `body` から変更要求を把握
2. 該当ファイルと周辺コンテキストを確認
3. 要求された変更を適用

## 4. コミットとプッシュ

`/him0-git-ops:commit --push` を呼び出して修正をコミット＆プッシュする。

## 5. 報告

修正内容のサマリーを報告:
- 対応した CI 失敗
- 対応したレビューコメント
- 変更したファイル

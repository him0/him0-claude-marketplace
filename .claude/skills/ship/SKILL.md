---
name: "ship"
description: "現在の diff を確認して PR を作成し、auto-fix --watch で CI / レビューに自動対応しながらマージまたはクローズまで見守る"
allowed-tools: TodoWrite Read Glob Grep Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git rev-parse *) Bash(git branch *) Bash(gh repo view *) Bash(gh pr view *) Skill(commit) Skill(pull-request) Skill(auto-fix)
---

# Quick Reference

```bash
/ship # 現在の diff を PR にして、マージ / クローズまで見守る
```

現在の作業内容 (未コミットの変更 + base から積んだコミット) を出荷するオーケストレーションスキル。実装は行わない。子スキル `commit` / `pull-request` / `auto-fix` を手順どおりに呼び出してまとめる。

# 不変条件

## 不変条件 1: ship はマージを実行しない

ship はマージを実行しない・誘発しない。具体的に禁止する操作:

- `gh pr merge` の呼び出し (`--auto` による auto-merge 有効化を含む)
- approve review の投稿

マージは人間が PR 画面から行う。この禁止経路を保つことで、`auto-fix --watch` が受信する `MERGED` イベントを「人間がマージした合図」と見なせる。

## 不変条件 2: ユーザー確認なしで最後まで自動進行する

途中の判断は合理的なデフォルトを取って先へ進める。停止してユーザーに委ねるのは次の安全停止条件のみ:

- 出荷対象の diff が存在しない (手順 1)
- `auto-fix --watch` の `CLOSED` 受信、または auto-fix が同一エラー 3 回ガードで Monitor を停止した場合 (手順 4)

子スキルが確認プロンプトを出した場合は、確認をユーザーに転送せず、「自動進行を継続する側」の回答 (追加作業の起動可否なら「いいえ」、続行確認なら「このまま進める」相当) を返して進行する。auto-fix の起動可否は聞かずに手順 4 で無条件起動する。

# Workflow

## 1. diff の確認

以下を並列実行して、出荷対象を把握する:

- `git status` で未コミットの変更を確認
- `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` でデフォルトブランチを取得
- `git log <default-branch>..HEAD --oneline` で base から積んだコミットを確認 (作業ブランチ上の場合)
- `git diff` / `git diff <default-branch>...HEAD` で変更内容を確認

未コミットの変更も先行コミットも存在しなければ「出荷対象がない」と報告して停止する (安全停止条件)。

出荷対象がある場合、何を ship するか (変更ファイル、変更の要旨) を 1 段落で要約提示してから次へ進む。要約はユーザーへの報告であり、確認待ちはしない (不変条件 2)。

## 2. コミット

未コミットの変更がある場合は `/commit --push` を呼び出す。デフォルトブランチ上にいる場合のブランチ作成は commit skill 側が担保する。

未コミットの変更がなく先行コミットだけの場合は、push 済みかを確認し、未 push なら push は手順 3 の pull-request に任せてそのまま進む。

## 3. PR 作成

`/pull-request` を呼び出す。

- PR が未作成なら新規作成される
- 既に PR があるブランチなら、最新コミットの push と PR title / description の更新が行われる

作成された (または更新された) PR の URL を報告する。

## 4. 監視 (auto-fix --watch)

`/auto-fix --watch` を無条件で 1 回起動する (不変条件 2。起動可否をユーザーに聞かない)。起動後の ship は終了イベントを待つだけでよい。監視・修正の実働はすべて auto-fix 側にある:

- CI 失敗・レビューコメント・merge conflict への自動対応は auto-fix の責務 (詳細は `auto-fix/SKILL.md`)
- 無限ループ防止も auto-fix 側のガードで担保される (同一エラー 3 回で Monitor 停止)

受信イベントごとの ship の対応:

- `ALL_PASSED` → 何もしない (非終了イベント。watch は監視を継続する)
- `MERGED` → 手順 5 へ (不変条件 1 により人間がマージした合図)
- `CLOSED` (未マージ) → 理由を確認してユーザーに報告し停止する
- auto-fix が同一エラー 3 回ガードで Monitor を停止 → ユーザーに報告して停止する

## 5. 完了レポート

`MERGED` 受信後、最終レポートを提示する:

- PR URL / merge commit SHA / マージ実行者 (`gh pr view --json mergedBy -q '.mergedBy.login'`)
- 監視中に対応した CI 失敗 / レビューコメント数

# 安全ルール

- 不変条件 1 (マージ禁止) を常に守る
- コミット・プッシュは `/commit` 経由で行い、force-push / `--no-verify` / デフォルトブランチへの直接プッシュは行わない
- 実装やリファクタリングは行わない。ship の対象は「今ある diff」だけであり、コード変更が必要なら先に通常の作業として行ってから ship を呼ぶ

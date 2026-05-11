---
name: "auto-fix"
description: "CI ステータスと PR レビューコメントを確認し、問題を自動修正してコミット＆プッシュする"
argument-hint: "[--watch | -w] [--ci-only] [--reviews-only]"
allowed-tools: TodoWrite Read Write Edit Glob Grep Bash(git *) Bash(gh *) Bash(*/scripts/*.sh *) Skill(him0-git-ops:commit) Skill(him0-git-ops:pull-request) Monitor TaskStop
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

`--watch` または `-w` が指定された場合:

1. `gh pr view --json number --jq .number` で現在の PR 番号を取得
2. ステップ 1〜5 を通常どおり実行し、現時点の CI 失敗・レビューコメントに対応する
3. 未対応コメント 0 件の確定 (Monitor 起動前のバリア。watcher の `seed_state` が起動時点の既存コメント ID を全て seen 化するため、ここで未対応 0 を確定させて取りこぼしを防ぐ):
   - ステップ 1 と同じコメント取得 (`scripts/check-pr.sh`) を再実行し、ステップ 3 と同じスキップ条件で「未対応」を分類する
   - 残っていればステップ 3〜4 を再実行 → 再フェッチを最大 3 周まで繰り返す
   - 3 周経っても残る場合は Monitor を起動せず終了する。修正は push 済みの状態で、残コメント (id / author / 抜粋) を一覧表示する
   - 0 件になったら次のステップへ進む
4. Monitor ツールを以下の設定で起動:
   - command: `bash <SKILL_DIR>/scripts/watch-pr.sh <PR番号>`
   - description: `PR #<N> CI & Review watcher`
   - persistent: true

Monitor からイベント通知を受けた場合:
- `[CI_FAILED]` or `[GHA_FAILED]` → ステップ 1〜5 を実行して CI 失敗を修正
- `[REVIEW_NEW]` → ステップ 1, 3〜5 を実行してレビューコメントを修正
- `[ALL_PASSED]` → 対応不要、確認のみ
- `[PENDING]` → 対応不要、待機継続
- `[MERGED]` → 「PR がマージされました」と報告して監視終了
- `[CLOSED]` → 「PR がクローズされました」と報告して監視終了

ユーザーが監視停止を求めたら TaskStop で Monitor を停止する。

## 1. 状況の取得

以下を並列実行:
- `bash <SKILL_DIR>/scripts/check-pr.sh [--ci-only] [--reviews-only]` で PR・CI・レビュー状況を一括取得
- `git status` でワーキングツリーがクリーンか確認

PR が見つからない (`summary.status` に `error`):
- main ブランチにいる → 「PR 番号または URL を教えてください」とユーザーに確認する
- それ以外 → 停止してユーザーに通知

ワーキングツリーが dirty な場合:
- 未コミットの変更があるならまず `/him0-git-ops:commit --push` で変更をコミットしてから続行

`summary.status` で分岐:
- `"ALL_CLEAR"` → 成功を報告して終了
- `"PENDING"` → "CI 実行中" と報告して終了。Watch モードの場合は次のポーリングで再チェックされる
- `"ACTION_NEEDED"` → ステップ 2, 3 へ進む

### Auto-merge の一時解除

修正が必要な場合 (CI 失敗または未対応コメントあり) かつ auto-merge が設定されている場合:
- `gh pr merge --disable-auto` で auto-merge を一時解除する
- 理由: 修正中に CI が通過すると意図せずマージされてしまうため
- 修正完了後にステップ 4b (`/him0-git-ops:pull-request` が有効化を内包) またはステップ 4c (フォールバック) で再有効化する

## 2. CI 失敗の修正 (`--reviews-only` の場合はスキップ)

### 修正対象の判断

以下の失敗はコード修正では解決できないため、ユーザーに報告して修正をスキップする:
- インフラ・ネットワーク起因のエラー (タイムアウト、接続エラー等)
- シークレットや環境変数の未設定エラー
- Docker イメージのプル失敗
- flaky test の可能性が高い場合 (同じテストが他のブランチでも失敗している等)

### GitHub Actions の失敗

`ci.failed` 配列のうち `provider == "github-actions"` のエントリに対して:
1. `bash <SKILL_DIR>/scripts/get-ci-logs.sh <link>` で失敗ログを取得
2. ログが長い場合は各失敗ステップの末尾 100 行に絞る
3. 失敗の原因を分析し、該当ソースファイルを読み取って修正を適用

### CircleCI の失敗

CircleCI の失敗詳細はこのスキルでは取得しない。ステータスは検知するが、内容を追う場合は CircleCI の Web UI を案内するか、ユーザーに対応を委ねる。

### 共通の注意事項

- テストケース自体は修正してはいけない (テストが正しく、プロダクションコードにバグがある前提で修正する)
- 必要に応じてローカルで再度テストを実行して修正を検証する
- プロジェクトに lint/format コマンドがある場合は変更後に実行する (例: `make fmt`, `pnpm fix`, `cargo fmt` 等)。`package.json` の `scripts` や Makefile を確認して該当コマンドを選ぶ

## 3. レビューコメントの修正 (`--ci-only` の場合はスキップ)

### Claude 自身の返信は除外する

コメントを評価する前に、以下に該当するものは「Claude (auto-fix) 自身が投稿したもの」として対応対象から除外する:

- コメント本文の末尾が `<!-- claude-code:auto-fix -->` で終わる → Claude 自身の返信 (人間が引用や PR 本文中で同じ文字列に言及するケースで誤検出しないよう、末尾完全一致で判定する)
- 同じスレッド (`in_reply_to_id` で連鎖) の最新の返信が上記末尾条件を満たす → そのスレッドは Claude が既に応答済みとみなす

判定方法 (auto-fix 本体実行時に Claude が行う):
1. `scripts/check-pr.sh` のレスポンスに各コメントの `id` / `in_reply_to_id` / `body` が含まれる
2. `in_reply_to_id` でスレッドをグルーピング (root id ごとに、作成時刻順の返信列を作る)
3. 各スレッドについて末尾のコメントの body を `body.trimEnd().endsWith('<!-- claude-code:auto-fix -->')` で判定し、true ならスキップ
4. マーカーが付かない過去コメント (運用開始前のもの) は人間扱いとして通常通り評価する

watcher (`watch-pr.sh`) との役割分担:

- watcher は新規コメント単体を `body.trimEnd().endsWith('<!-- claude-code:auto-fix -->')` で判定し、true なら `[REVIEW_NEW]` を発火させない (Claude 自身の直前返信で監視ループが回るのを防ぐ目的のみ)
- スレッド単位の「対応済み判定」 (上記 1〜4) は watcher では行わない。auto-fix 本体実行時に Claude が判断する責務
- そのため、Claude のマーカー付き返信に人間が再 reply してきた場合、watcher は新規 reply (人間側) に対して `[REVIEW_NEW]` を発火させ、auto-fix 本体が起動する

### 対応するコメントの判断

上記スキップ後に残ったコメントについて、内容から対応要否を判断する:
- コード変更を求めているもの (バグ指摘、修正依頼、リファクタ提案等) → 対応する
- 軽微な指摘 (タイポ、命名、フォーマット等) → 対応する
- 提案・意見で判断に迷うもの (設計方針の変更、大きなリファクタ等) → レビュアーに質問を返信して確認する
- 意図や要件が不明確なコメント → レビュアーに質問を返信して明確化を求める
- 質問・確認のみのコメント → コード修正せず、返信で回答する
- 参考情報や備忘録 → 対応不要

### 修正手順

未対応のレビューコメントごとに:
1. コメント本文、ファイルパス、行範囲、コメント ID を読み取る
2. 該当ファイルと周辺コンテキストを確認
3. `gh api` でコメントに返信する
   - コマンド: `gh api repos/:owner/:repo/pulls/<PR番号>/comments/<コメントID>/replies -f body='<返信本文>'`
   - 返信本文は必ず以下のテンプレートで投稿する (マーカー識別のため固定):

     ```text
     <返信内容>

     <sub>— auto-fix by Claude Code</sub>
     <!-- claude-code:auto-fix -->
     ```

   - `<返信内容>` の書き方:
     - 「ご指摘ありがとうございます」「ご指摘の通り」「お疲れ様です」などの枕詞・謝意表明・前置きは書かない。事実と対応内容だけを簡潔に書く
     - 修正する場合: 何をどう変えたかを 1〜2 文で書く (例: 「○○を△△に変更しました」「□□のチェックを追加しました」)
     - 対応しない場合: 対応しない理由を 1〜2 文で書く (例: 「○○の理由で現状維持とします」)
     - 質問する場合: 不明点を具体的に書く (例: 「○○と△△のどちらの方針が望ましいでしょうか？」)
   - 末尾の `<!-- claude-code:auto-fix -->` は固定マーカー。Claude 自身の返信を後続実行や `--watch` 監視で識別するために使う。改変・省略してはいけない
   - 視認フッター `<sub>— auto-fix by Claude Code</sub>` も固定。GitHub 上でレビュアーに「Claude が返信した」と分かるように残す
4. 修正する場合は要求された変更を適用 (質問のみの場合はスキップ)
5. プロジェクトに lint/format コマンドがある場合は変更後に実行する

## 4. コミット・プッシュ・PR description 更新

### 4a. コミットとプッシュ

`/him0-git-ops:commit --push` を呼び出して修正をコミット＆プッシュする。

コミット時に以下の情報を渡す:
- CI 失敗を修正した場合: どのジョブのどんなエラーを修正したか
- レビューコメントを修正した場合: どのコメントに対応したか

### 4b. PR description の更新

このイテレーションで コードファイル (= skill ドキュメント以外) を変更するコミットが発生した場合のみ `/him0-git-ops:pull-request` を呼び、最新コミット群に合わせて PR description を書き換える。

判定基準:
- 4a の `/him0-git-ops:commit --push` 実行前の HEAD を `prev` として保持し、push 後に `git diff prev..HEAD --name-only` を取得
- 出力が空、または PR description に影響しないファイル (例: コメント返信ログのみ) しか含まれていない場合は 4b をスキップする (PR description が無意味に書き換わるのを避ける)
- それ以外は 4b を実行する

`/him0-git-ops:pull-request` skill は既存 PR で auto-merge が未設定なら自動で再有効化する。4b 実行後に `gh pr view --json autoMergeRequest` で確認し、未有効なら 4c のコマンドを追加で実行する。

### 4c. Auto-merge の再有効化 (フォールバック)

4b をスキップした (= コード変更ゼロだった) かつステップ 1 で auto-merge を解除した場合のみ実行:
- `gh pr merge --auto --squash` で auto-merge を再有効化する
- squash 以外のマージ方法が必要な場合は `--merge` または `--rebase` を使用

## 5. 報告

修正内容のサマリーを報告:
- 対応した CI 失敗 (ジョブ名、エラー種別、修正内容)
- 対応したレビューコメント (コメント内容の要約、修正内容)
- 修正できなかった問題 (理由とともに報告)
- 変更したファイル

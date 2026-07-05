---
name: "auto-fix"
description: "CI ステータスと PR レビューコメントを確認し、問題を自動修正してコミット＆プッシュする。CI 確認、テスト落ち修正、レビュー対応が必要な時に使用"
argument-hint: "[--watch | -w]"
allowed-tools: TodoWrite Read Write Edit Glob Grep Bash(git *) Bash(gh *) Bash(bash .claude/skills/auto-fix/scripts/*) Skill(commit) Skill(merge-base) Monitor TaskStop
---

# Quick Reference

```bash
/auto-fix         # CI 失敗とレビューコメントを1回修正
/auto-fix --watch # Monitor で継続監視し、マージ / クローズまで自動対応
```

# 共通ルール

## auto-fix が付けるコメントの識別

auto-fix が PR に付ける返信・コメントには、必ず本文末尾に次の 2 つのマーカーを付与する。

```markdown
<sub>— ClaudeCode:auto-fix</sub>

<!-- ClaudeCode:auto-fix -->
```

役割の使い分け:

- `<sub>— ClaudeCode:auto-fix</sub>` は人間向けの可視マーカー。GitHub UI 上で「これは auto-fix が書いた」と分かる
- `<!-- ClaudeCode:auto-fix -->` は Claude Code (スクリプト) 向けの不可視マーカー。GitHub UI には表示されないが API レスポンスの body には含まれる

ポーリングスクリプト・本スキルの両方が HTML コメント側を検索して「auto-fix 自身の返信」を識別し、未対応コメント検出から除外する。可視 sub タグは識別には使わず (人間が手動で sub タグを真似た場合の誤検知を避けるため)、表示のためだけに付ける。

マーカー文言は `scripts/markers.sh` の `auto_fix_marker` で一元管理しており、`watch-pr.sh` / `check-pr.sh` の両方がこれを読み込む。変更する場合は `markers.sh` と本ファイルの記載を同時に更新すること。

## 例外: bot / CI が自動投稿する持続的メタコメントは別カテゴリで除外

「指摘内容を含むコメント」ではなく、bot や CI が PR ライフサイクルに紐づけて自動投稿する持続的メタコメント (人手レビューではなく対応するアクションも存在しない) は、別カテゴリのマーカー集合として除外する。`scripts/markers.sh` の `persistent_meta_markers_json` 変数 (JSON 配列) で管理する。

デフォルトは CodeRabbit のサマリーコメント (`<!-- This is an auto-generated comment: summarize by coderabbit.ai -->`) のみ。CodeRabbit の指摘はインラインコメントとして別途届くため、サマリー本体は対応アクションのないメタコメントとして扱う。プロジェクトに issue トラッカーのリンクバックや CI の進捗通知など他の bot コメントがある場合、その本文に含まれる HTML コメントマーカーをこの配列に追加する。

「指摘内容を含むがアクション不要」というケース (例: 既に対応済みの古いレビュー) はこのカテゴリには含めない。それらは通常レビューとして拾い、「修正しない」返信で resolve する。

## 返信の 3 区分

レビュー / コメントごとに、必ず次のいずれかの返信を行う。

- 修正: 指摘内容が妥当でコード修正が可能な場合。何をどう変更したか、対象ファイル / コミットを明記する。返信後、対応するレビュースレッドを resolve する
- 追加質問: 指摘の意図・期待動作が曖昧で確認が必要な場合。不明点を具体的に質問し、仮の解釈を述べて確認を求める。人間の応答待ちなので resolve しない
- 修正しない: 仕様上正しい・既に対応済み・out of scope 等の場合。修正しない理由と根拠 (既存仕様、別 PR 対応予定 等) を提示する。返信後、対応するレビュースレッドを resolve する

返信末尾には必ず sub タグ + HTML コメントの 2 行を付ける (上記参照)。

## 返信のトーン

返信本文には次のものだけを書く。

- 採用 / 不採用の判断と理由
- 修正した場合の変更概要と対応コミット SHA
- 追加質問の場合は具体的な不明点

「レビューありがとうございます」「お疲れさまです」「ご指摘の通りです」「ご提案の通り」などの社交辞令・感謝表現・前置きは入れない。事実と対応のみを簡潔に書く。

良い例:

```markdown
SKILL.md:107 の閾値を「3 回連続」に修正 (コミット 35d11f16d)。LLM の解釈ブレを防ぐ意図に同意。
```

悪い例:

```markdown
レビューありがとうございます。
ご提案の通り「3 回連続」と明示するよう修正しました (コミット 35d11f16d)。
```

## レビュースレッドの resolve

「修正」「修正しない」で対応が完了したインラインレビュースレッドは、必ず resolve する。GitHub REST API では resolve できないので GraphQL を使う。

`check-pr.sh` の出力 `reviews.unresolved_threads[].thread_id` にスレッド ID が含まれる。無い場合はコメントの databaseId から逆引きする。

```bash
# コメント databaseId からスレッド ID を取得
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 5) { nodes { databaseId } }
          }
        }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F number=<pr_number>

# 取得したスレッド ID で resolve
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { id isResolved }
    }
  }' -F threadId=<thread_id>
```

PR トップレベルコメントとレビュー本体には resolve の概念がないため、「修正/修正しない」の返信を付けるだけで完了とする。

## auto-merge の取り扱い

コード修正に着手する前に、PR に auto-merge が設定されているかを確認する (`check-pr.sh` の `pr.auto_merge_enabled`)。

有効なら、修正を push すると意図せずマージされる恐れがあるため、修正に着手する前に必ず外す。

```bash
gh pr merge --disable-auto
```

外したことは報告に含め、必要に応じて修正後にユーザーが再有効化できるよう案内する。auto-fix 側からの再有効化は行わない (マージに至る操作は人間に委ねる)。

「修正しない」「追加質問」のみで終わる場合は auto-merge を外さない。

## 1 サイクル 1 push

1 回の対応サイクルで CI 失敗とレビュー指摘の両方を直す場合は、変更をまとめて 1 回の push にする。修正のたびに push すると CI が同じコードに対して何度も走って無駄になるため、push は対応サイクルあたり 1 回に束ねる。conflict 解消と併発した場合の push 経路は Step 2a を参照。

# Workflow

## 0. Watch モード

`--watch` または `-w` が指定された場合、`Monitor` ツールで PR の状態変化を監視する永続プロセスを起動する。

Monitor 起動:

- command: `bash .claude/skills/auto-fix/scripts/watch-pr.sh`
- persistent: true でセッション寿命まで継続
- description: `auto-fix PR 監視` 等、分かりやすいラベルを付ける

Monitor 起動が成功したら、ユーザーに監視を開始した旨と「PR 上にコメントで指摘してもらえれば auto-fix が対応する」旨を 1 度案内する。

ポーリングスクリプト `watch-pr.sh` は CI と各種コメントを 60 秒間隔でポーリングし、状態変化が起きた時のみ次のイベントを stdout に 1 行ずつ出力する。初回ポーリングで現時点の問題 (既存の CI 失敗・未対応コメント) もイベントとして出力されるため、watch 起動前に単発実行を挟む必要はない。

- `CI_FAILED:<check_name>,<run_id>`: 失敗しているチェックを検出 (Monitor 継続)
- `NEW_REVIEW:count=<n>`: 未対応の PR トップレベルコメント / レビュー本体あり (Monitor 継続)
- `NEW_REVIEW_COMMENT:count=<n>`: 未対応のインラインレビューコメントあり (Monitor 継続)
- `MERGE_CONFLICT:<mergeable>,<state>`: base ブランチとの conflict を検出 (Monitor 継続)
- `ALL_PASSED`: CI 全通過かつ未対応コメントなし (Monitor 継続。クリーン化のたびに通知し、終了しない)
- `MERGED`: PR がマージされた (Monitor 終了)
- `CLOSED`: PR が未マージでクローズされた (Monitor 終了)
- `ERROR:<message>`: ポーリング自体の障害 (連続 3 回で Monitor 終了)

スクリプトの未対応コメント検出ルール:

- インラインレビュースレッド: `isResolved == false` かつ「最後のコメントが auto-fix の HTML コメントマーカー / 持続的メタコメントマーカーを含まない」スレッドのみカウント。「修正/修正しない」で resolve 済 / 「追加質問」で人間応答待ち、いずれも未対応カウントから除外される
- PR トップレベルコメント / レビュー本体: resolve の概念がないため、「本文にマーカーを含むもの」に加えて「auto-fix の最後の返信 (マーカー付きコメント) より古いもの」を対応済みとみなして除外する。auto-fix は対応サイクルの最後に必ずマーカー付きで返信するため、返信時点までのコメントは対応済みと判定できる。空本文でも `CHANGES_REQUESTED` のレビューは未対応として数える
- 新規イベントの検知は件数ではなく ID 集合の差集合 (新規に増えた分) で行う。同一ポーリング間隔内で「1 件解消 + 1 件新規」が起きても相殺されず、解消のみ (resolve だけ) では発火しない。CI_FAILED も同様に、新規に失敗し始めたチェックだけを通知する

スクリプトの終了条件:

- 終了するのは PR が `MERGED` / `CLOSED` になった時、またはポーリング障害が連続 3 回続いた時のみ。クリーン状態に達しても終了しない (`ALL_PASSED` は非終了の通知)
- これにより approve 後・マージ前に新規コメントや merge conflict が発生しても拾い続けられる

イベント受信時の挙動:

- `CI_FAILED:*` → Step 2 (CI 失敗修正) → Step 4 (コミット & プッシュ)
- `NEW_REVIEW:*` / `NEW_REVIEW_COMMENT:*` → Step 3 (レビュー対応) → 必要なら Step 4
- `MERGE_CONFLICT:*` → Step 2a (base ブランチ取り込み & conflict 解消。push は Step 2a 内で完結し Step 4 は通らない)
- `ALL_PASSED` → 「現在クリーン。マージ / クローズまで監視継続」と報告するのみ。TaskStop しない
- `MERGED` → マージ完了を報告し、TaskStop で Monitor を停止
- `CLOSED` → クローズ検知を報告し、TaskStop で Monitor を停止
- `ERROR:*` → ユーザーに報告。連続 3 回ならスクリプトが exit

ユーザーが監視停止を求めたら TaskStop で Monitor を停止する。

## 1. 状況の取得

以下を並列実行:

- `bash .claude/skills/auto-fix/scripts/check-pr.sh` で PR・CI・レビュー状況を一括取得
- `git status` でワーキングツリーがクリーンか確認

PR が見つからない (`summary.status` が `error`):

- main ブランチにいる → 「PR 番号または URL を教えてください」とユーザーに確認する
- それ以外 → 停止してユーザーに通知

ワーキングツリーが dirty な場合は、まず `/commit --push` で変更をコミットしてから続行する。

`summary.status` で分岐 (上から順に評価し、最初にマッチした分岐を採用する):

- conflict あり (`pr.mergeable == "CONFLICTING"` または `pr.merge_state_status == "DIRTY"`) → Step 2a へ。CI 失敗・未対応コメントと併発時は Step 2/3 でコード修正をコミットまで行い (push しない)、Step 2a で merge コミットと束ねて 1 回 push する
- `"ALL_CLEAR"` → 成功を報告して終了 (Watch モードでは `ALL_PASSED` を受けても TaskStop しない)
- `"PENDING"` → "CI 実行中" と報告して終了。Watch モードでは次のポーリングで再チェックされる
- `"ACTION_NEEDED"` → Step 2 (CI) / Step 3 (レビュー) へ

`pr.mergeable == "UNKNOWN"` は GitHub 側が非同期計算中。Watch モードは次のポーリングで自然に確定する。単発モードでは 2 秒待って `gh pr view --json mergeable` を再取得するリトライを最大 2 回行い、それでも `UNKNOWN` なら誤検知回避のため conflict なし扱いで先へ進む。

## 2a. base ブランチとの merge conflict 解消

Watch モードで `MERGE_CONFLICT:*` を受信した時、または Step 1 が conflict ありと分類した時に実行する。push は本 Step 内で完結させ、Step 4 は通らない。

1. `pr.auto_merge_enabled` が true なら `gh pr merge --disable-auto` を実行する (共通ルール「auto-merge の取り扱い」参照)
2. `/merge-base` を呼び出して base ブランチを取り込み、conflict を解消する (skill 内部で PR base を自動検出するので引数不要)
   - 自動解消不能な conflict で skill が停止した場合は、残コンフリクトのファイル一覧と要約をユーザーに報告して停止する (force push は行わない)
3. `git push origin "$(git branch --show-current)"` で push する (`/commit --push` は使わない。merge コミットを含むため)。Step 2/3 のコード修正コミットがローカルに先行している場合も、先行コミット + merge コミットを 1 回の push で送信する
4. push 後、Step 1 を再実行し、新しい `summary.status` で再分岐する (CI が再走するため通常 `PENDING` になる)

## 2. CI 失敗の修正

CI 修正に着手する前に、`pr.auto_merge_enabled` が true なら `gh pr merge --disable-auto` を実行する。

### 修正対象の判断

以下の失敗はコード修正では解決できないため、ユーザーに報告して修正をスキップする:

- インフラ・ネットワーク起因のエラー (タイムアウト、接続エラー等)
- シークレットや環境変数の未設定エラー
- Docker イメージのプル失敗
- flaky test の可能性が高い場合 (コード変更なしで失敗、同じテストが他ブランチでも失敗している等) → `gh run rerun <RUN_ID> --failed` を提案

### 修正手順

`ci.failed` の各エントリに対して:

1. `provider == "github-actions"` なら `bash .claude/skills/auto-fix/scripts/get-ci-logs.sh <link>` で失敗ログを取得。ログが長い場合は各失敗ステップの末尾 100 行に絞る
2. それ以外の provider (CircleCI 等) は詳細ログを取得しない。ステータスのみ報告し、Web UI を案内するかユーザーに対応を委ねる
3. 原因を特定 (テスト失敗、lint エラー、型エラー、ビルドエラー等) し、該当ソースファイルを読み取って修正を適用

修正の優先順位はビルドエラー、次に lint、最後にテスト失敗の順。

注意事項:

- 失敗に直接関連するファイルのみ最小限に修正する。無関係なリファクタリングは行わない
- テストケース自体は修正してはいけない (テストが正しく、プロダクションコードにバグがある前提で修正する)
- 必要に応じてローカルでテストを再実行して修正を検証する
- プロジェクトに lint/format コマンドがある場合は変更後に実行する

修正完了後の push 経路は Step 1 の分岐に従う。conflict 併発時は Step 4 ではなく Step 2a で push する。

## 3. レビュー / コメントへの対応

対応対象は `check-pr.sh` の出力のうち:

- `reviews.unresolved_threads`: 未解決のインラインレビュースレッド (auto-fix 応答済み・メタコメントは除外済み)
- `reviews.pr_reviews` / `reviews.issue_comments` のうち `claude_marker` / `meta_marker` / `handled` がすべて false のもの (summary の集計と同一条件。`handled == true` は auto-fix の最後の返信より古い対応済みコメントなので、再度対応すると重複返信になる)

`<!-- ClaudeCode:auto-fix -->` を含むコメントは auto-fix 自身の返信なので必ずスキップする。

### 3-1. 内容の確認

1. コメント本文・ファイルパス・行範囲を読み取る
2. 該当ファイルと周辺コンテキストを確認
3. 共通ルール「返信の 3 区分」のうちどれに該当するかを判断する

### 3-2. 区分ごとの対応

修正する場合:

1. `pr.auto_merge_enabled` が true なら、コード変更前に `gh pr merge --disable-auto` を実行する
2. 要求された変更を最小限の差分で適用する
3. コミット・push したのち、3-3 でコメントへ返信する (返信本文に対応コミット SHA を含める)。push 経路は Step 1 の分岐に従う: 通常は Step 4、conflict 併発時は Step 2a で束ねて push
4. インラインレビュースレッドの場合は、返信後に該当スレッドを resolve する (共通ルール「レビュースレッドの resolve」参照)

追加質問する場合:

- コード変更は行わない
- 不明点を具体的に列挙し、仮の解釈案を提示して確認を求める
- 3-3 で返信する。人間の応答待ちなので resolve しない

修正しない場合:

- コード変更は行わない
- 修正しない理由 (仕様上正しい / 別 PR で対応 / out of scope など) を根拠とともに記述する
- 3-3 で返信し、インラインレビュースレッドの場合は resolve する

### 3-3. 返信

返信本文末尾には必ずマーカー 2 行を付与する (共通ルール「auto-fix が付けるコメントの識別」が定義元)。

返信先による使い分け:

- インラインレビューコメントには、スレッド返信を使う

  ```bash
  gh api -X POST "repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies" \
    -f body="$(cat <<'EOF'
  修正しました (コミット <sha>)。XX を YY に変更しています。

  <sub>— ClaudeCode:auto-fix</sub>

  <!-- ClaudeCode:auto-fix -->
  EOF
  )"
  ```

- PR トップレベルコメント / レビュー本体には、`gh pr comment` で新しいコメントを付ける

  ```bash
  gh pr comment <pr_number> --body "$(cat <<'EOF'
  本文…

  <sub>— ClaudeCode:auto-fix</sub>

  <!-- ClaudeCode:auto-fix -->
  EOF
  )"
  ```

返信は対象コメント 1 件につき 1 回。複数指摘を同一スレッドにまとめない。

## 4. コミットとプッシュ

コード修正を行った場合のみ実行する。conflict 併発時は本 Step に来ず Step 2a 内で push をまとめる。

`/commit --push` を呼び出して修正をコミット＆プッシュする。コミット時に以下の情報を渡す:

- CI 失敗を修正した場合: どのジョブのどんなエラーを修正したか
- レビューコメントを修正した場合: どのコメントに対応したか

push 後、3-3 の「修正」区分の返信に含めるコミット SHA を確定する。Watch モードでは push 後、Monitor が次の状態変化 (新しい CI 実行結果やレビュー) を検知するまで待機する。

## 5. 報告

修正内容のサマリーを報告:

- 対応した CI 失敗 (ジョブ名、エラー種別、修正内容)
- 対応したレビュー / コメント (区分: 修正 / 追加質問 / 修正しない の内訳)
- resolve したインラインレビュースレッド数
- 解消した merge conflict (base ブランチ取り込みの有無、merge コミット SHA)
- 変更したファイル
- 修正できなかった問題 (理由とともに報告)
- auto-merge を外した場合はその旨と、再有効化はユーザー側で行う必要があることを案内

# 安全ルール

- force-push 禁止、`--no-verify` 禁止
- `.github/workflows/` は原則変更しない
- flaky test (コード変更なしで失敗) → `gh run rerun <RUN_ID> --failed` を提案
- インフラ起因の失敗 → 報告のみ
- 同じエラーが 3 回以上続く (同一指摘の修正に繰り返し失敗して収束しない) → 手動介入を案内し、TaskStop で Monitor を停止。この計数はスクリプトではなくスキル実行側の判断に依存する設計上の制約があり、セッションを跨ぐとリセットされる。収束しない兆候を感じたら早めに手動介入を案内する側に倒す
- auto-fix からは auto-merge を外すだけで、有効化はしない
- 返信に必ず sub タグ + HTML コメントマーカーの 2 行を付け、auto-fix 自身の返信を再対応対象にしない

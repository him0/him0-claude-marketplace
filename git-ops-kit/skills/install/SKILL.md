---
name: "install"
description: "git-ops スキルテンプレートをプロジェクトの .claude/skills/ にインストールし、プロジェクトに合わせて最適化する。導入済みのものはテンプレートと比較して改善を提案する"
argument-hint: "[<name>...] [--all] [--user] [--no-adapt]"
allowed-tools: TodoWrite Read Write Edit Glob Grep AskUserQuestion Bash(ls *) Bash(cp *) Bash(mkdir *) Bash(diff *) Bash(git log *) Bash(git remote *) Bash(gh repo view *) Bash(gh pr list *)
---

# Quick Reference

```bash
/him0-git-ops-kit:install                  # 状況を提示して対話的に選択
/him0-git-ops-kit:install commit ship     # 指定テンプレートのみ対象
/him0-git-ops-kit:install --all           # 未導入をすべて導入、導入済みは更新提案
/him0-git-ops-kit:install --user          # ~/.claude/skills/ に導入 (個人用、adapt なし)
/him0-git-ops-kit:install --no-adapt      # プロジェクト最適化をスキップしてそのままコピー
```

# コンセプト

このスキルはテンプレートの「配布」だけを行う。インストール後の `.claude/skills/<name>/` はプロジェクトが所有するマスターであり、この kit が所有権を主張することはない。メタデータや lock ファイルは一切作らない。プロジェクトにはただの手書きスキルと区別がつかない状態で残る。

# Workflow

## 1. 状態の把握

`${CLAUDE_SKILL_DIR}/templates/` 配下の各テンプレートについて、展開先 (`--user` なら `~/.claude/skills/`、それ以外は `.claude/skills/`) の同名ディレクトリの有無を確認し、分類する:

- 未導入: 展開先に同名ディレクトリがない
- 導入済み: 展開先に同名ディレクトリがある (kit 由来か手書きかは区別しない。同名ならプロジェクト側がマスター)

## 2. 対象の決定

- 引数でテンプレート名が指定されていればそれを対象にする (存在しない名前はエラーとして一覧を提示)
- `--all` なら全テンプレートを対象にする
- 引数なしなら分類結果を一覧表示し、AskUserQuestion (multiSelect) で対象を選択してもらう。導入済みのものは「更新確認」として選択肢に含める

依存関係: 対象テンプレートの SKILL.md が `Skill(xxx)` で他のテンプレートを参照している場合、その依存先が展開先に存在しなければ対象に自動追加する (追加したことを報告する)。

## 3. 未導入テンプレートのインストール

対象ごとに:

1. `${CLAUDE_SKILL_DIR}/templates/<name>/` 一式を展開先 `<skills-dir>/<name>/` に再帰コピーする (scripts/ などの付属ファイルを含む)
2. adapt フェーズを実行する (`--no-adapt` または `--user` の場合はスキップ)

### adapt フェーズ (プロジェクト最適化)

プロジェクトを調査し、テンプレートをプロジェクトの実態に合わせて書き換える。

調査対象:
- プロジェクトの CLAUDE.md / AGENTS.md / CONTRIBUTING.md にある運用ルール
- デフォルトブランチ、ブランチ命名規則 (`git log` や `gh pr list` から推定)
- コミットメッセージの言語・形式の慣習 (`git log --oneline -30` から推定)
- CI 構成 (.github/workflows/ など) と test / lint コマンド
- PR テンプレート (.github/PULL_REQUEST_TEMPLATE.md)
- モノレポ構成、パッケージマネージャ

書き換えの原則:
- 変えるのは値と手順 (コマンド名、ブランチ名、言語、スキップ条件など)。スキルの構造や見出し立ては保つ
- プロジェクトの明文化されたルールと矛盾する箇所は必ずプロジェクト側に合わせる
- 判断がつかない点は推測で埋めず、テンプレートのまま残す

適用前に、テンプレート原本からの変更点を要約して提示し、確認を得てから書き込む。

## 4. 導入済みテンプレートの更新提案

対象ごとに、テンプレートの現在版とプロジェクト版の SKILL.md (と付属ファイル) を読み比べる。バージョン追跡はしないので、その場の意味的な比較だけで判断する:

1. テンプレート側にだけある機能を抽出する: 新しいオプション、ワークフローの追加ステップ、新しいスクリプト、明確な改善
2. 抽出した項目を一覧で提示し、AskUserQuestion で取り込むものを選択してもらう
3. 取り込みはプロジェクト版を土台にした追記・部分修正で行う。プロジェクト版の構成やカスタマイズを尊重し、丸ごと置き換えは絶対にしない

保守的に判断する原則:
- プロジェクト版とテンプレートで記述が異なる箇所は、プロジェクトの意図的なカスタマイズである可能性を優先し、取り込み候補にしない
- 明らかにテンプレート側で新規追加された機能だけを提案する
- 迷うものは「差分として存在する」と提示するだけにとどめ、判断をユーザーに委ねる

差分に取り込むべきものがなければ「差分なし」または「プロジェクト固有のカスタマイズのみ」と報告して終わる。

## 5. 報告

最後に結果をまとめる:

- 導入したスキル (adapt での主な変更点つき)
- 更新提案して取り込んだ項目 / 見送った項目
- スキップしたもの
- 展開先がプロジェクトの場合、`.claude/skills/` の変更をコミットしてチームに共有するよう促す

# Templates

- commit: Conventional Commits 形式でのコミット (ブランチ自動作成、--push, --main)
- pull-request: PR 作成・更新 (--draft, --base によるスタック PR, チケット URL 連携)
- merge-base: PR base ブランチの取り込みとコンフリクト自動解消 (--rebase)
- auto-fix: CI 失敗・レビューコメントの自動修正 (--watch でマージ / クローズまで継続監視)
- ship: 現在の diff を PR にして auto-fix --watch でマージ / クローズまで見守る

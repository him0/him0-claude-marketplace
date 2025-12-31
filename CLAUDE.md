# Claude Code Plugin 開発ガイド

このリポジトリは Claude Code 用のプラグインマーケットプレイスです。

## plugin.json の構成

### 必須フィールド
- `name`: プラグインの一意識別子 (kebab-case)

### author フィールド
`author` はオブジェクト形式：

```json
"author": {
  "name": "作者名",
  "email": "email@example.com",
  "url": "https://github.com/author"
}
```

`name` のみ必須、`email` と `url` は任意

### skills フィールド
スキルベースのプラグインでは、`skills` はパス文字列：

```json
"skills": "./skills/"
```

### commands フィールド
`commands/` ディレクトリは自動検出されるため、通常は指定不要。
カスタムパスを使用する場合のみパス文字列で指定：

```json
"commands": "./custom/commands/"
```

## ディレクトリ構造

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json      # マニフェストはここに配置
├── skills/              # スキルベースの場合
│   └── skill-name/
│       └── SKILL.md
└── commands/            # コマンドベースの場合
    └── command-name.md
```

## プラグイン名の命名規則

- marketplace.json の `plugins[].name` と plugin.json の `name` は一致させる
- kebab-case を使用 (例: `him0-git-ops-plugin`)

## プラグイン更新時の注意

プラグインを更新した際は、必ず `plugin.json` の `version` を上げること。

```json
"version": "1.0.1"  // 更新時にインクリメント
```

バージョンを上げないと `claude plugin update` でキャッシュが更新されない。

## スタイルガイド

- Markdown で `**` による強調は使わない

## 参照

- [Plugins Guide](https://docs.anthropic.com/en/docs/claude-code/plugins) - プラグイン開発の概要
- [Plugins Reference](https://docs.anthropic.com/en/docs/claude-code/plugins-reference) - plugin.json スキーマの詳細仕様

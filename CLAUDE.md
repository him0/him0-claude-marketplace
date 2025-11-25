# Claude Code Plugin 開発ガイド

このリポジトリは Claude Code 用のプラグインマーケットプレイスです。

## plugin.json の正しい構成

### 必須フィールド
- `name`: プラグインの一意識別子 (kebab-case)

### author フィールド (重要)
`author` は**オブジェクト**である必要があります：

```json
"author": {
  "name": "作者名",
  "email": "email@example.com",
  "url": "https://github.com/author"
}
```

- `name` のみ必須、`email` と `url` は任意

**誤った例:**
```json
"author": "him0"
```

**正しい例:**
```json
"author": { "name": "him0" }
```

### skills フィールド
スキルベースのプラグインでは、`skills` は**パス文字列**です：

```json
"skills": "./skills/"
```

**誤った例:**
```json
"skills": [{ "name": "...", "path": "..." }]
```

**正しい例:**
```json
"skills": "./skills/"
```

### commands フィールド
コマンドベースのプラグインでは、`commands` はオブジェクトの配列：

```json
"commands": [
  {
    "name": "commit",
    "description": "commit changes",
    "file": "commands/commit.md"
  }
]
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

**重要**: `plugin.json` は必ず `.claude-plugin/` ディレクトリ内に配置してください。

## プラグイン名の命名規則

- marketplace.json の `plugins[].name` と plugin.json の `name` は一致させる
- kebab-case を使用 (例: `him0-git-ops-plugin`)

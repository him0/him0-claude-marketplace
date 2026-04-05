---
name: "setup"
description: "Configure the user's Claude Code status line setting. Use this skill to configure the user's Claude Code status line setting."
---

# Setup Status Line

claude-code-statusline パッケージをグローバルインストールし、settings.json に statusLine 設定を追加します。

## 手順

1. `npm install -g claude-code-statusline` を実行
2. `~/.claude/settings.json` に以下の設定を追加:

```json
"statusLine": {
  "type": "command",
  "command": "claude-code-statusline"
}
```

## 実行

上記の手順を実行してください。完了したら結果を報告してください。

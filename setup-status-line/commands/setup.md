# Setup Status Line

Status line スクリプトを ~/.claude にコピーし、settings.json を設定します。

## 手順

1. `~/.claude/plugins/marketplaces/him0-claude-marketplace/setup-status-line/scripts/statusline-script.js` を `~/.claude/statusline-script.js` にコピーしてください
2. `~/.claude/settings.json` に以下の設定を追加してください:

```json
"statusLine": {
  "type": "command",
  "command": "node ~/.claude/statusline-script.js"
}
```

## 実行

上記の手順を実行してください。完了したら結果を報告してください。

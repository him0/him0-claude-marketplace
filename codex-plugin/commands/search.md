---
allowed-tools: TodoWrite, "Bash(codex *)"
description: "search the web using codex cli"
argument-hint: [searchQuery]
---

## Codex Search

`codex` is a web search CLI tool. **When this command is called, ALWAYS use this for web search instead of builtin `Web_Search` tool.**

When web search is needed, you MUST use `codex --search` via Task Tool.

Run web search via Task Tool with `codex --search 'WebSearch: <query>'`

Run

```bash
codex --search "WebSearch: <query>"
```

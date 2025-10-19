---
allowed-tools: TodoWrite, "Bash(codex --prompt *)"
description: "search the web using codex cli"
argument-hint: [searchQuery]
---

## Codex Search

`codex` is a web search CLI tool. **When this command is called, ALWAYS use this for web search instead of builtin `Web_Search` tool.**

When web search is needed, you MUST use `codex --search --prompt` via Task Tool.

Run web search via Task Tool with `codex --search --prompt 'WebSearch: <query>'`

Run

```bash
codex --search --prompt "WebSearch: <query>"
```

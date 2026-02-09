---
name: codex
description: "Delegate tasks to OpenAI Codex CLI in read-only sandbox mode. Use when the user explicitly asks to use codex, or when you need a second opinion from another AI agent for coding, search, or general tasks."
allowed-tools: "Bash(codex *)"
context: fork
agent: general-purpose
---

# Codex CLI

`codex` is the OpenAI Codex CLI agent.

## Usage

Always run codex in read-only sandbox (`-s read-only`) to prevent unintended file writes.

```bash
codex exec --color never -s read-only "<prompt>"
```

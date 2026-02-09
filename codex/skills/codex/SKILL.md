---
name: codex
description: "Delegate tasks to OpenAI Codex CLI. Use when the user explicitly asks to use codex, or when you need a second opinion from another AI agent for coding, search, or general tasks."
allowed-tools: "Bash(codex *)"
context: fork
agent: general-purpose
---

# Codex CLI

`codex` is the OpenAI Codex CLI agent.

## Usage

Run codex with the user's request:

```bash
codex exec --json --color never "<prompt>"
```

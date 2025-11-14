---
allowed-tools: Task, Glob, Grep, Read
description: "search codebase files and content using sub-agent"
argument-hint: [searchQuery]
---

## Codex Code Search

This command enables thorough codebase exploration and content search using a specialized sub-agent.

### When to Use

Use this command when you need to:
- Find files matching specific patterns (e.g., "**/*.ts", "src/components/**/*.tsx")
- Search for keywords or code patterns across the codebase
- Understand how specific features or APIs are implemented
- Explore the structure and organization of the codebase
- Locate definitions of classes, functions, or variables

### How It Works

When this command is called, you MUST use the Task tool with `subagent_type=Explore` to perform the search.

The Explore agent has access to:
- **Glob**: Find files by pattern matching
- **Grep**: Search file contents with regex support
- **Read**: Read and analyze file contents
- All other necessary tools for codebase exploration

### Usage Pattern

For the search query provided by the user, invoke the Task tool like this:

```
Use Task tool with:
- subagent_type: "Explore"
- description: Short description of the search task (3-5 words)
- prompt: Detailed search instructions including:
  - What to search for (files, keywords, patterns)
  - Desired thoroughness level: "quick", "medium", or "very thorough"
  - What information to return
```

### Examples

**Example 1: Finding files by pattern**
```
Task with subagent_type="Explore":
Find all TypeScript React components in the src directory.
Search for files matching "src/**/*.tsx" pattern.
Thoroughness: quick
```

**Example 2: Searching for code keywords**
```
Task with subagent_type="Explore":
Search for all files that contain "API endpoints" or "apiEndpoint".
Look for how API endpoints are defined and used.
Thoroughness: medium
```

**Example 3: Understanding architecture**
```
Task with subagent_type="Explore":
Explore how authentication is implemented in this codebase.
Search for auth-related files, middleware, and configurations.
Thoroughness: very thorough
```

### Important Notes

- Always specify the thoroughness level based on the scope of the search
- Return detailed findings including file paths and line numbers when relevant
- If the search query is ambiguous, try multiple search strategies
- Provide code snippets or examples from the findings when helpful

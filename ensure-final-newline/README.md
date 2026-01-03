# Ensure Final Newline

Claude Code plugin that automatically ensures files end with a newline character after Write, Edit, or MultiEdit operations.

## Features

- Automatically adds a final newline to files modified by Claude
- Works with Write, Edit, and MultiEdit tools
- POSIX-compliant file format
- macOS/BSD sed compatible

## Installation

```bash
claude plugin install him0-claude-marketplace
claude plugin enable him0-ensure-final-newline
```

## How It Works

This plugin uses a PostToolUse hook that:
1. Detects when Write, Edit, or MultiEdit tools are used
2. Extracts the file path from the tool input
3. Automatically appends a newline if the file doesn't end with one

## Why Final Newlines Matter

Many tools and standards expect text files to end with a newline:
- POSIX definition of a text file requires it
- Git shows "No newline at end of file" warnings without it
- Some compilers and linters require it
- Prevents issues when concatenating files

## Technical Details

The hook uses:
- `jq` to parse tool input JSON
- `sed` for in-place file modification
- File existence check to prevent errors

## Version

1.0.0

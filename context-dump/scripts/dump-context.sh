#!/bin/bash
# Dump /context command output to JSON files

input=$(cat)

# Only process /context command
command_name=$(echo "$input" | jq -r '.tool_input.command // empty')
if [ "$command_name" != "context" ]; then
  exit 0
fi

# Create output directory
OUTPUT_DIR="$HOME/.claude/context-dumps"
mkdir -p "$OUTPUT_DIR"

# Generate filename with timestamp
timestamp=$(date +"%Y%m%d_%H%M%S")
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
filename="${timestamp}_${session_id}.json"

# Save data
echo "$input" | jq '{
  timestamp: (now | todate),
  session_id: .session_id,
  cwd: .cwd,
  tool_response: .tool_response,
  transcript_path: .transcript_path
}' > "$OUTPUT_DIR/$filename"

exit 0

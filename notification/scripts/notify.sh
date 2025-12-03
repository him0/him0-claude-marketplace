#!/bin/bash
# Desktop notification script with tmux passthrough support for iTerm2
# Uses OSC 9 escape sequence for iTerm2 notifications

# Read JSON input from stdin
input=$(cat)

# Extract message from JSON
msg=$(echo "$input" | jq -r '.message // "Claude Code notification"')

# Send notification using OSC 9 escape sequence
if [ -n "$TMUX" ]; then
  # Inside tmux: wrap OSC sequence for iTerm2 passthrough
  printf '\ePtmux;\e\e]9;%s\a\e\\' "$msg"
else
  # Outside tmux: send OSC 9 directly
  printf '\e]9;%s\a' "$msg"
fi

exit 0

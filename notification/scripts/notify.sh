#!/bin/bash
# Desktop notification script with tmux passthrough support for iTerm2
# Uses OSC 9 escape sequence for iTerm2 notifications

# Read JSON input from stdin
input=$(cat)

# dump for debugging
# echo "$input" > "$HOME/.claude/notify.json"

# Extract message from JSON
msg=$(echo "$input" | jq -r '.message // "Claude Code notification"')

# Send notification using OSC 9 escape sequence
# Output directly to /dev/tty to bypass Claude Code's stdout capture
if [ -n "$TMUX" ]; then
  # Inside tmux: wrap OSC sequence for iTerm2 passthrough
  printf '\ePtmux;\e\e]9;%s\a\e\\' "$msg" > /dev/tty
else
  # Outside tmux: send OSC 9 directly
  printf '\e]9;%s\a' "$msg" > /dev/tty
fi

exit 0

#!/bin/bash
# Test script for notify.sh
# Simulates the JSON input that Claude Code sends to the Notification hook

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Test with default message
echo "Testing with default message..."
echo '{}' | "$SCRIPT_DIR/notify.sh"

# Test with custom message
echo "Testing with custom message..."
echo '{"message": "Test notification from Claude Code"}' | "$SCRIPT_DIR/notify.sh"

# Test with permission_prompt type
echo "Testing permission_prompt notification..."
echo '{"message": "Claude needs your permission to use Bash", "notification_type": "permission_prompt"}' | "$SCRIPT_DIR/notify.sh"

# Test with idle_prompt type
echo "Testing idle_prompt notification..."
echo '{"message": "Claude is waiting for your input", "notification_type": "idle_prompt"}' | "$SCRIPT_DIR/notify.sh"

echo ""
echo "All tests completed!"
echo "TMUX detected: $([ -n "$TMUX" ] && echo "Yes" || echo "No")"

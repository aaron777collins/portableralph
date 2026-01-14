#!/bin/bash
# slack-notify.sh - Optional Slack notifications for Ralph
# Posts messages to Slack via webhook URL
#
# Configuration (via environment variables):
#   RALPH_SLACK_WEBHOOK_URL - Slack incoming webhook URL (required for notifications)
#   RALPH_SLACK_CHANNEL     - Override default channel (optional)
#   RALPH_SLACK_USERNAME    - Bot username (default: "Ralph")
#   RALPH_SLACK_ICON_EMOJI  - Bot icon (default: ":robot_face:")
#
# Usage:
#   ./slack-notify.sh "Your message here"
#   ./slack-notify.sh "Message" "emoji"  # Override icon for this message
#
# If RALPH_SLACK_WEBHOOK_URL is not set, this script silently exits (notifications disabled)

set -euo pipefail

MESSAGE="${1:-}"
EMOJI_OVERRIDE="${2:-}"

# Exit silently if webhook URL not configured (notifications are optional)
if [ -z "${RALPH_SLACK_WEBHOOK_URL:-}" ]; then
    exit 0
fi

# Exit if no message provided
if [ -z "$MESSAGE" ]; then
    exit 0
fi

# Configuration with defaults
CHANNEL="${RALPH_SLACK_CHANNEL:-}"
USERNAME="${RALPH_SLACK_USERNAME:-Ralph}"
ICON_EMOJI="${EMOJI_OVERRIDE:-${RALPH_SLACK_ICON_EMOJI:-:robot_face:}}"

# Build JSON payload
# Using jq if available, otherwise basic escaping
if command -v jq &> /dev/null; then
    # Use jq for proper JSON escaping
    PAYLOAD=$(jq -n \
        --arg text "$MESSAGE" \
        --arg username "$USERNAME" \
        --arg icon_emoji "$ICON_EMOJI" \
        --arg channel "$CHANNEL" \
        '{
            text: $text,
            username: $username,
            icon_emoji: $icon_emoji
        } + (if $channel != "" then {channel: $channel} else {} end)')
else
    # Basic JSON escaping (handles common cases)
    ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')

    if [ -n "$CHANNEL" ]; then
        PAYLOAD="{\"text\":\"$ESCAPED_MESSAGE\",\"username\":\"$USERNAME\",\"icon_emoji\":\"$ICON_EMOJI\",\"channel\":\"$CHANNEL\"}"
    else
        PAYLOAD="{\"text\":\"$ESCAPED_MESSAGE\",\"username\":\"$USERNAME\",\"icon_emoji\":\"$ICON_EMOJI\"}"
    fi
fi

# Send to Slack
curl -s -X POST \
    -H 'Content-type: application/json' \
    --data "$PAYLOAD" \
    "$RALPH_SLACK_WEBHOOK_URL" > /dev/null 2>&1 || true

# Don't fail the main script if Slack notification fails
exit 0

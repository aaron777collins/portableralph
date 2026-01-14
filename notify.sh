#!/bin/bash
# notify.sh - Multi-platform notifications for Ralph
# Supports: Slack, Discord, Telegram, and Custom scripts
#
# Configuration (via environment variables):
#
#   SLACK:
#     RALPH_SLACK_WEBHOOK_URL  - Slack incoming webhook URL
#     RALPH_SLACK_CHANNEL      - Override default channel (optional)
#     RALPH_SLACK_USERNAME     - Bot username (default: "Ralph")
#     RALPH_SLACK_ICON_EMOJI   - Bot icon (default: ":robot_face:")
#
#   DISCORD:
#     RALPH_DISCORD_WEBHOOK_URL - Discord webhook URL
#     RALPH_DISCORD_USERNAME    - Bot username (default: "Ralph")
#     RALPH_DISCORD_AVATAR_URL  - Bot avatar URL (optional)
#
#   TELEGRAM:
#     RALPH_TELEGRAM_BOT_TOKEN - Telegram bot token (from @BotFather)
#     RALPH_TELEGRAM_CHAT_ID   - Chat/group/channel ID to send to
#
#   CUSTOM:
#     RALPH_CUSTOM_NOTIFY_SCRIPT - Path to custom notification script
#                                  Script receives message as $1
#                                  Use this for proprietary integrations
#                                  (database bridges, internal APIs, etc.)
#
#   BEHAVIOR:
#     RALPH_NOTIFY_FREQUENCY     - How often to send progress notifications
#                                  1 = every iteration (default)
#                                  5 = every 5th iteration (reduces noise)
#
# Usage:
#   ./notify.sh "Your message here"
#   ./notify.sh --test              # Send test notification to all configured platforms
#
# Messages are sent to ALL configured platforms. If none are configured, exits silently.

set -euo pipefail

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check for test mode
if [ "${1:-}" = "--test" ]; then
    TEST_MODE=true
    MESSAGE="Test notification from Ralph"
else
    TEST_MODE=false
    MESSAGE="${1:-}"
fi

# Exit if no message provided
if [ -z "$MESSAGE" ]; then
    exit 0
fi

# Convert literal \n to actual newlines
MESSAGE=$(printf '%b' "$MESSAGE")

# Track if any notification was sent
SENT_ANY=false

# ============================================
# SLACK
# ============================================
send_slack() {
    local msg="$1"

    if [ -z "${RALPH_SLACK_WEBHOOK_URL:-}" ]; then
        return 0
    fi

    local username="${RALPH_SLACK_USERNAME:-Ralph}"
    local icon_emoji="${RALPH_SLACK_ICON_EMOJI:-:robot_face:}"
    local channel="${RALPH_SLACK_CHANNEL:-}"

    local payload
    if command -v jq &> /dev/null; then
        payload=$(jq -n \
            --arg text "$msg" \
            --arg username "$username" \
            --arg icon_emoji "$icon_emoji" \
            --arg channel "$channel" \
            '{
                text: $text,
                username: $username,
                icon_emoji: $icon_emoji
            } + (if $channel != "" then {channel: $channel} else {} end)')
    else
        local escaped_msg
        escaped_msg=$(echo "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
        if [ -n "$channel" ]; then
            payload="{\"text\":\"$escaped_msg\",\"username\":\"$username\",\"icon_emoji\":\"$icon_emoji\",\"channel\":\"$channel\"}"
        else
            payload="{\"text\":\"$escaped_msg\",\"username\":\"$username\",\"icon_emoji\":\"$icon_emoji\"}"
        fi
    fi

    if curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$RALPH_SLACK_WEBHOOK_URL" > /dev/null 2>&1; then
        SENT_ANY=true
        $TEST_MODE && echo "  Slack: sent"
        return 0
    else
        $TEST_MODE && echo "  Slack: FAILED"
        return 1
    fi
}

# ============================================
# DISCORD
# ============================================
send_discord() {
    local msg="$1"

    if [ -z "${RALPH_DISCORD_WEBHOOK_URL:-}" ]; then
        return 0
    fi

    local username="${RALPH_DISCORD_USERNAME:-Ralph}"
    local avatar_url="${RALPH_DISCORD_AVATAR_URL:-}"

    # Convert Slack-style formatting to Discord markdown
    # :emoji: stays the same, *bold* -> **bold**, \n -> actual newlines
    local discord_msg
    discord_msg=$(echo "$msg" | sed 's/\*\([^*]*\)\*/**\1**/g')

    local payload
    if command -v jq &> /dev/null; then
        payload=$(jq -n \
            --arg content "$discord_msg" \
            --arg username "$username" \
            --arg avatar_url "$avatar_url" \
            '{
                content: $content,
                username: $username
            } + (if $avatar_url != "" then {avatar_url: $avatar_url} else {} end)')
    else
        local escaped_msg
        escaped_msg=$(echo "$discord_msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
        if [ -n "$avatar_url" ]; then
            payload="{\"content\":\"$escaped_msg\",\"username\":\"$username\",\"avatar_url\":\"$avatar_url\"}"
        else
            payload="{\"content\":\"$escaped_msg\",\"username\":\"$username\"}"
        fi
    fi

    if curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$RALPH_DISCORD_WEBHOOK_URL" > /dev/null 2>&1; then
        SENT_ANY=true
        $TEST_MODE && echo "  Discord: sent"
        return 0
    else
        $TEST_MODE && echo "  Discord: FAILED"
        return 1
    fi
}

# ============================================
# TELEGRAM
# ============================================
send_telegram() {
    local msg="$1"

    if [ -z "${RALPH_TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${RALPH_TELEGRAM_CHAT_ID:-}" ]; then
        return 0
    fi

    # Convert Slack-style formatting to Telegram markdown
    # *bold* stays the same in Telegram MarkdownV2
    # :emoji: -> just remove the colons for common ones or keep as-is
    local telegram_msg
    telegram_msg=$(echo "$msg" | sed 's/:rocket:/🚀/g; s/:white_check_mark:/✅/g; s/:warning:/⚠️/g; s/:gear:/⚙️/g; s/:robot_face:/🤖/g; s/:x:/❌/g')

    # Escape special characters for Telegram MarkdownV2
    # Characters that need escaping: _ * [ ] ( ) ~ ` > # + - = | { } . !
    # But we want to keep * for bold, so be selective
    telegram_msg=$(echo "$telegram_msg" | sed 's/\./\\./g; s/!/\\!/g; s/-/\\-/g; s/=/\\=/g; s/|/\\|/g; s/{/\\{/g; s/}/\\}/g; s/(/\\(/g; s/)/\\)/g; s/\[/\\[/g; s/\]/\\]/g')

    local api_url="https://api.telegram.org/bot${RALPH_TELEGRAM_BOT_TOKEN}/sendMessage"

    local payload
    if command -v jq &> /dev/null; then
        payload=$(jq -n \
            --arg chat_id "$RALPH_TELEGRAM_CHAT_ID" \
            --arg text "$telegram_msg" \
            '{
                chat_id: $chat_id,
                text: $text,
                parse_mode: "MarkdownV2"
            }')
    else
        local escaped_msg
        escaped_msg=$(echo "$telegram_msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
        payload="{\"chat_id\":\"$RALPH_TELEGRAM_CHAT_ID\",\"text\":\"$escaped_msg\",\"parse_mode\":\"MarkdownV2\"}"
    fi

    if curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$api_url" > /dev/null 2>&1; then
        SENT_ANY=true
        $TEST_MODE && echo "  Telegram: sent"
        return 0
    else
        $TEST_MODE && echo "  Telegram: FAILED"
        return 1
    fi
}

# ============================================
# CUSTOM SCRIPT
# ============================================
# For proprietary integrations (database bridges, internal APIs, etc.)
# Your script receives the message as $1 and handles delivery however you need.
#
# Example use cases:
#   - Database-to-Slack bridge (insert into DB, separate service posts to Slack)
#   - Internal company notification API
#   - SMS gateway
#   - Email relay
#
# Example script (my-notify.sh):
#   #!/bin/bash
#   MESSAGE="$1"
#   curl -X POST -d "message=$MESSAGE" https://internal.api/notify
#
send_custom() {
    local msg="$1"

    if [ -z "${RALPH_CUSTOM_NOTIFY_SCRIPT:-}" ]; then
        return 0
    fi

    # Verify script exists and is executable
    if [ ! -x "$RALPH_CUSTOM_NOTIFY_SCRIPT" ]; then
        $TEST_MODE && echo "  Custom: FAILED (script not found or not executable)"
        return 1
    fi

    # Strip Slack-style emoji codes for cleaner output
    local clean_msg
    clean_msg=$(echo "$msg" | sed 's/:rocket:/🚀/g; s/:white_check_mark:/✅/g; s/:warning:/⚠️/g; s/:gear:/⚙️/g; s/:robot_face:/🤖/g; s/:x:/❌/g')

    if "$RALPH_CUSTOM_NOTIFY_SCRIPT" "$clean_msg" > /dev/null 2>&1; then
        SENT_ANY=true
        $TEST_MODE && echo "  Custom: sent"
        return 0
    else
        $TEST_MODE && echo "  Custom: FAILED"
        return 1
    fi
}

# ============================================
# MAIN
# ============================================

if $TEST_MODE; then
    echo "Testing Ralph notifications..."
    echo ""
    echo "Configured platforms:"
    [ -n "${RALPH_SLACK_WEBHOOK_URL:-}" ] && echo "  - Slack: configured" || echo "  - Slack: not configured"
    [ -n "${RALPH_DISCORD_WEBHOOK_URL:-}" ] && echo "  - Discord: configured" || echo "  - Discord: not configured"
    [ -n "${RALPH_TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${RALPH_TELEGRAM_CHAT_ID:-}" ] && echo "  - Telegram: configured" || echo "  - Telegram: not configured"
    [ -n "${RALPH_CUSTOM_NOTIFY_SCRIPT:-}" ] && echo "  - Custom: configured ($RALPH_CUSTOM_NOTIFY_SCRIPT)" || echo "  - Custom: not configured"
    echo ""
    echo "Sending test message..."
fi

# Send to all configured platforms
send_slack "$MESSAGE" || true
send_discord "$MESSAGE" || true
send_telegram "$MESSAGE" || true
send_custom "$MESSAGE" || true

if $TEST_MODE; then
    echo ""
    if $SENT_ANY; then
        echo "Test complete! Check your notification channels."
    else
        echo "No notifications sent. Configure at least one platform."
        echo "Run: ~/ralph/setup-notifications.sh"
    fi
fi

exit 0

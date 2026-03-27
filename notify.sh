#!/bin/bash
# notify.sh - Multi-platform notifications for Ralph
# Supports: Slack, Discord, Telegram, Email, and Custom scripts
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
#   EMAIL:
#     RALPH_EMAIL_TO           - Recipient email address(es) (comma-separated)
#     RALPH_EMAIL_FROM         - Sender email address
#     RALPH_EMAIL_SUBJECT      - Email subject prefix (default: "Ralph Notification")
#
#     SMTP Configuration (Traditional):
#     RALPH_SMTP_HOST          - SMTP server hostname
#     RALPH_SMTP_PORT          - SMTP server port (default: 587)
#     RALPH_SMTP_USER          - SMTP username
#     RALPH_SMTP_PASSWORD      - SMTP password
#     RALPH_SMTP_TLS           - Use TLS (true/false, default: true)
#
#     SendGrid API (Alternative to SMTP):
#     RALPH_SENDGRID_API_KEY   - SendGrid API key
#
#     AWS SES (Alternative to SMTP):
#     RALPH_AWS_SES_REGION     - AWS region (e.g., us-east-1)
#     RALPH_AWS_ACCESS_KEY_ID  - AWS access key
#     RALPH_AWS_SECRET_KEY     - AWS secret key
#
#     Email Options:
#     RALPH_EMAIL_HTML         - Send HTML emails (true/false, default: true)
#     RALPH_EMAIL_BATCH_DELAY  - Seconds to wait before sending batched emails (default: 300)
#     RALPH_EMAIL_BATCH_MAX    - Maximum notifications per batch (default: 10)
#
#   CUSTOM:
#     RALPH_CUSTOM_NOTIFY_SCRIPT - Path to custom notification script
#                                  Script receives message as $1
#                                  Use this for proprietary integrations
#                                  (database bridges, internal APIs, etc.)
#
#   BEHAVIOR:
#     RALPH_NOTIFY_FREQUENCY     - How often to send progress notifications
#                                  5 = every 5th iteration (default)
#                                  1 = every iteration
#
# Usage:
#   ./notify.sh "Your message here"
#   ./notify.sh --test              # Send test notification to all configured platforms
#
# Messages are sent to ALL configured platforms. If none are configured, exits silently.

set -euo pipefail

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load constants
if [ -f "$RALPH_DIR/lib/constants.sh" ]; then
    source "$RALPH_DIR/lib/constants.sh"
fi

# Load platform utilities for cross-platform support
if [ -f "$RALPH_DIR/lib/platform-utils.sh" ]; then
    source "$RALPH_DIR/lib/platform-utils.sh"
fi

# Load enhanced error handling
if [ -f "$RALPH_DIR/lib/error-handling.sh" ]; then
    source "$RALPH_DIR/lib/error-handling.sh"
    setup_error_handling "notify.sh"
fi

# Load and decrypt environment variables
if [ -f "$RALPH_DIR/decrypt-env.sh" ]; then
    source "$RALPH_DIR/decrypt-env.sh"
    if ! decrypt_ralph_env 2>&1 | grep -q "^Error:"; then
        : # Decryption succeeded or no encrypted values
    else
        # Only show warning in test mode, otherwise notifications might spam
        if [ "${1:-}" = "--test" ]; then
            echo "Warning: Failed to decrypt some environment variables" >&2
            echo "Some notification platforms may not work" >&2
        fi
    fi
fi

# ============================================
# SECURITY FUNCTIONS
# ============================================

# Source shared validation library
source "${RALPH_DIR}/lib/validation.sh"

# All validation functions are now loaded from lib/validation.sh:
# - json_escape()
# - mask_token()
# - validate_webhook_url() / validate_url()
# - validate_email()
# - validate_numeric()
# - validate_path()

# Rate limiting: track notification timestamps (use platform-appropriate temp dir)
if command -v get_temp_dir &>/dev/null; then
    TEMP_DIR=$(get_temp_dir)
else
    TEMP_DIR="${TMPDIR:-/tmp}"
fi
RATE_LIMIT_FILE="${TEMP_DIR}/ralph_notify_rate_limit_$$"
# Use RATE_LIMIT_MAX from constants.sh if available, otherwise default to 60
# Note: Don't reassign if already readonly from constants.sh
if [ -z "${RATE_LIMIT_MAX:-}" ]; then
    RATE_LIMIT_MAX=60  # Max notifications per minute
fi

check_rate_limit() {
    local now
    now=$(date +%s)
    local rate_window="${RATE_LIMIT_WINDOW:-60}"

    # Clean up old entries (older than rate limit window)
    if [ -f "$RATE_LIMIT_FILE" ]; then
        if awk -v cutoff="$((now - rate_window))" '$1 > cutoff' "$RATE_LIMIT_FILE" > "${RATE_LIMIT_FILE}.tmp" 2>/dev/null; then
            if ! mv "${RATE_LIMIT_FILE}.tmp" "$RATE_LIMIT_FILE" 2>/dev/null; then
                # If mv fails, cleanup temp file
                rm -f "${RATE_LIMIT_FILE}.tmp" 2>/dev/null
            fi
        else
            # If awk fails, remove temp file if it exists
            rm -f "${RATE_LIMIT_FILE}.tmp" 2>/dev/null
        fi
    fi

    # Count recent notifications
    local count=0
    if [ -f "$RATE_LIMIT_FILE" ]; then
        count=$(wc -l < "$RATE_LIMIT_FILE" 2>/dev/null || echo 0)
    fi

    if [ "$count" -ge "$RATE_LIMIT_MAX" ]; then
        return 1  # Rate limit exceeded
    fi

    # Record this notification (if we can't write, rate limiting is disabled)
    if ! echo "$now" >> "$RATE_LIMIT_FILE" 2>/dev/null; then
        # If we can't write to rate limit file, continue anyway
        # This prevents notification failures due to file system issues
        return 0
    fi
    return 0
}

# Check for help flag
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat << 'EOF'
notify.sh - Multi-platform notifications for Ralph

USAGE:
    ./notify.sh [OPTIONS] [MESSAGE]

OPTIONS:
    --test                  Send a test notification to all configured platforms
    --help, -h              Show this help message

EXAMPLES:
    ./notify.sh "Build complete!"
    ./notify.sh --test
    ./notify.sh "🚀 Deployment finished successfully"

CONFIGURATION:
    Configure notification platforms using environment variables:

    Slack:
        RALPH_SLACK_WEBHOOK_URL      - Slack webhook URL
        RALPH_SLACK_CHANNEL          - Channel override (optional)
        RALPH_SLACK_USERNAME         - Bot username (default: "Ralph")

    Discord:
        RALPH_DISCORD_WEBHOOK_URL    - Discord webhook URL
        RALPH_DISCORD_USERNAME       - Bot username (default: "Ralph")

    Telegram:
        RALPH_TELEGRAM_BOT_TOKEN     - Bot token from @BotFather
        RALPH_TELEGRAM_CHAT_ID       - Chat/channel ID

    Email:
        RALPH_EMAIL_TO               - Recipient email(s)
        RALPH_EMAIL_FROM             - Sender email
        RALPH_SMTP_HOST              - SMTP server
        RALPH_SMTP_USER              - SMTP username
        RALPH_SMTP_PASSWORD          - SMTP password

    Custom Script:
        RALPH_CUSTOM_NOTIFY_SCRIPT   - Path to custom script

    For detailed configuration, see the script header comments.

SETUP:
    Run 'ralph notify setup' to configure notification platforms interactively.
EOF
    exit 0
fi

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

    # Validate webhook URL
    if ! validate_webhook_url "$RALPH_SLACK_WEBHOOK_URL"; then
        $TEST_MODE && echo "  Slack: FAILED (invalid webhook URL)"
        return 1
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
        # Use safe JSON escaping function (no sed)
        local escaped_msg
        local escaped_username
        local escaped_icon
        local escaped_channel
        escaped_msg=$(json_escape "$msg")
        escaped_username=$(json_escape "$username")
        escaped_icon=$(json_escape "$icon_emoji")
        escaped_channel=$(json_escape "$channel")

        if [ -n "$channel" ]; then
            payload="{\"text\":\"$escaped_msg\",\"username\":\"$escaped_username\",\"icon_emoji\":\"$escaped_icon\",\"channel\":\"$escaped_channel\"}"
        else
            payload="{\"text\":\"$escaped_msg\",\"username\":\"$escaped_username\",\"icon_emoji\":\"$escaped_icon\"}"
        fi
    fi

    # Send with timeout and error handling
    local http_code
    local max_time="${HTTP_MAX_TIME:-10}"
    local connect_timeout="${HTTP_CONNECT_TIMEOUT:-5}"
    http_code=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST \
        -H 'Content-type: application/json' \
        --max-time "$max_time" \
        --connect-timeout "$connect_timeout" \
        --data "$payload" \
        "$RALPH_SLACK_WEBHOOK_URL" 2>&1)
    local curl_exit=$?

    local success_min="${HTTP_STATUS_SUCCESS_MIN:-200}"
    local success_max="${HTTP_STATUS_SUCCESS_MAX:-300}"
    if [ $curl_exit -eq 0 ] && [ "$http_code" -ge "$success_min" ] && [ "$http_code" -lt "$success_max" ]; then
        SENT_ANY=true
        $TEST_MODE && echo "  Slack: sent"
        return 0
    else
        $TEST_MODE && echo "  Slack: FAILED (HTTP $http_code, exit $curl_exit)"
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

    # Validate webhook URL
    if ! validate_webhook_url "$RALPH_DISCORD_WEBHOOK_URL"; then
        $TEST_MODE && echo "  Discord: FAILED (invalid webhook URL)"
        return 1
    fi

    local username="${RALPH_DISCORD_USERNAME:-Ralph}"
    local avatar_url="${RALPH_DISCORD_AVATAR_URL:-}"

    # Convert Slack-style formatting to Discord markdown safely
    # Avoid sed for user input - use bash substitution
    local discord_msg="$msg"
    # Replace *text* with **text** for Discord bold
    while [[ "$discord_msg" =~ \*([^*]+)\* ]]; do
        discord_msg="${discord_msg/\*${BASH_REMATCH[1]}\*/**${BASH_REMATCH[1]}**}"
    done

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
        # Use safe JSON escaping function
        local escaped_msg
        local escaped_username
        local escaped_avatar
        escaped_msg=$(json_escape "$discord_msg")
        escaped_username=$(json_escape "$username")
        escaped_avatar=$(json_escape "$avatar_url")

        if [ -n "$avatar_url" ]; then
            payload="{\"content\":\"$escaped_msg\",\"username\":\"$escaped_username\",\"avatar_url\":\"$escaped_avatar\"}"
        else
            payload="{\"content\":\"$escaped_msg\",\"username\":\"$escaped_username\"}"
        fi
    fi

    # Send with timeout and error handling
    local http_code
    local max_time="${HTTP_MAX_TIME:-10}"
    local connect_timeout="${HTTP_CONNECT_TIMEOUT:-5}"
    http_code=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST \
        -H 'Content-type: application/json' \
        --max-time "$max_time" \
        --connect-timeout "$connect_timeout" \
        --data "$payload" \
        "$RALPH_DISCORD_WEBHOOK_URL" 2>&1)
    local curl_exit=$?

    local success_min="${HTTP_STATUS_SUCCESS_MIN:-200}"
    local success_max="${HTTP_STATUS_SUCCESS_MAX:-300}"
    if [ $curl_exit -eq 0 ] && [ "$http_code" -ge "$success_min" ] && [ "$http_code" -lt "$success_max" ]; then
        SENT_ANY=true
        $TEST_MODE && echo "  Discord: sent"
        return 0
    else
        $TEST_MODE && echo "  Discord: FAILED (HTTP $http_code, exit $curl_exit)"
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

    # Convert Slack-style emoji codes to Unicode (avoid sed on user input)
    local telegram_msg="$msg"
    telegram_msg="${telegram_msg//:rocket:/🚀}"
    telegram_msg="${telegram_msg//:white_check_mark:/✅}"
    telegram_msg="${telegram_msg//:warning:/⚠️}"
    telegram_msg="${telegram_msg//:gear:/⚙️}"
    telegram_msg="${telegram_msg//:robot_face:/🤖}"
    telegram_msg="${telegram_msg//:x:/❌}"
    telegram_msg="${telegram_msg//:clipboard:/📋}"

    # Escape special characters for Telegram MarkdownV2 using bash
    # Characters that need escaping: _ * [ ] ( ) ~ ` > # + - = | { } . !
    # Keep * for bold, escape others
    local escaped_msg="$telegram_msg"
    escaped_msg="${escaped_msg//\\/\\\\}"
    escaped_msg="${escaped_msg//./\\.}"
    escaped_msg="${escaped_msg//!/\\!}"
    escaped_msg="${escaped_msg//-/\\-}"
    escaped_msg="${escaped_msg//=/\\=}"
    escaped_msg="${escaped_msg//|/\\|}"
    escaped_msg="${escaped_msg//\{/\\{}"
    escaped_msg="${escaped_msg//\}/\\}}"
    escaped_msg="${escaped_msg//(/\\(}"
    escaped_msg="${escaped_msg//)/\\)}"
    escaped_msg="${escaped_msg//\[/\\[}"
    escaped_msg="${escaped_msg//\]/\\]}"

    # Construct API URL with masked token for logs
    local api_url="https://api.telegram.org/bot${RALPH_TELEGRAM_BOT_TOKEN}/sendMessage"
    local masked_url="https://api.telegram.org/bot$(mask_token "$RALPH_TELEGRAM_BOT_TOKEN")/sendMessage"

    local payload
    if command -v jq &> /dev/null; then
        payload=$(jq -n \
            --arg chat_id "$RALPH_TELEGRAM_CHAT_ID" \
            --arg text "$escaped_msg" \
            '{
                chat_id: $chat_id,
                text: $text,
                parse_mode: "MarkdownV2"
            }')
    else
        # Use safe JSON escaping function
        local json_escaped_msg
        local json_escaped_chat
        json_escaped_msg=$(json_escape "$escaped_msg")
        json_escaped_chat=$(json_escape "$RALPH_TELEGRAM_CHAT_ID")
        payload="{\"chat_id\":\"$json_escaped_chat\",\"text\":\"$json_escaped_msg\",\"parse_mode\":\"MarkdownV2\"}"
    fi

    # Send with timeout and error handling (never log actual token)
    local http_code
    local error_output
    local max_time="${HTTP_MAX_TIME:-10}"
    local connect_timeout="${HTTP_CONNECT_TIMEOUT:-5}"
    error_output=$(mktemp) || {
        $TEST_MODE && echo "  Telegram: FAILED (temp file creation failed)"
        return 1
    }
    trap 'rm -f "$error_output" 2>/dev/null' RETURN

    http_code=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST \
        -H 'Content-type: application/json' \
        --max-time "$max_time" \
        --connect-timeout "$connect_timeout" \
        --data "$payload" \
        "$api_url" 2>"$error_output")
    local curl_exit=$?

    # Clean up temp file
    rm -f "$error_output"

    local success_min="${HTTP_STATUS_SUCCESS_MIN:-200}"
    local success_max="${HTTP_STATUS_SUCCESS_MAX:-300}"
    if [ $curl_exit -eq 0 ] && [ "$http_code" -ge "$success_min" ] && [ "$http_code" -lt "$success_max" ]; then
        SENT_ANY=true
        $TEST_MODE && echo "  Telegram: sent"
        return 0
    else
        # Never expose the actual token in error messages
        $TEST_MODE && echo "  Telegram: FAILED (HTTP $http_code, exit $curl_exit, URL: $masked_url)"
        return 1
    fi
}

# ============================================
# EMAIL
# ============================================
# Supports three delivery methods:
#   1. SMTP (traditional mail servers)
#   2. SendGrid API (cloud service)
#   3. AWS SES (Amazon Simple Email Service)
#
# Features:
#   - HTML and plain text emails
#   - Event batching to reduce spam
#   - Multiple recipients
#   - Template-based formatting

# Email batching state (use platform-appropriate temp dir)
EMAIL_BATCH_DIR="${TEMP_DIR}/ralph_email_batch"
EMAIL_BATCH_FILE="$EMAIL_BATCH_DIR/pending.txt"
EMAIL_BATCH_LOCK="$EMAIL_BATCH_DIR/batch.lock"

# Initialize email batch directory
init_email_batch() {
    mkdir -p "$EMAIL_BATCH_DIR"
    chmod 700 "$EMAIL_BATCH_DIR"
}

# Check if we should batch this notification
should_batch_email() {
    local batch_delay="${RALPH_EMAIL_BATCH_DELAY:-${EMAIL_BATCH_DELAY_DEFAULT:-300}}"

    # Batching disabled if delay is 0
    if [ "$batch_delay" -eq 0 ]; then
        return 1  # Don't batch
    fi

    # Check if this is a high-priority message (errors, warnings)
    if echo "$1" | grep -qiE "(error|failed|critical|warning)"; then
        return 1  # Don't batch critical messages
    fi

    return 0  # Batch this message
}

# Add message to batch queue
add_to_batch() {
    local msg="$1"
    local timestamp
    timestamp=$(date +%s)

    init_email_batch

    # Acquire lock
    local lock_acquired=false
    local lock_retries="${EMAIL_BATCH_LOCK_RETRIES:-10}"
    local lock_delay="${EMAIL_BATCH_LOCK_DELAY:-0.1}"
    for i in $(seq 1 "$lock_retries"); do
        if mkdir "$EMAIL_BATCH_LOCK" 2>/dev/null; then
            lock_acquired=true
            break
        fi
        sleep "$lock_delay"
    done

    if [ "$lock_acquired" = false ]; then
        return 1
    fi

    # Add to batch file
    if ! echo "${timestamp}|${msg}" >> "$EMAIL_BATCH_FILE" 2>/dev/null; then
        # Release lock before returning
        rmdir "$EMAIL_BATCH_LOCK" 2>/dev/null
        return 1
    fi

    # Release lock
    if ! rmdir "$EMAIL_BATCH_LOCK" 2>/dev/null; then
        # Lock directory removal failed, but message was added
        # This is not critical, the lock will be handled on next attempt
        :
    fi

    # Check if we should send now
    check_and_send_batch
}

# Check if batch should be sent
check_and_send_batch() {
    local batch_delay="${RALPH_EMAIL_BATCH_DELAY:-${EMAIL_BATCH_DELAY_DEFAULT:-300}}"
    local batch_max="${RALPH_EMAIL_BATCH_MAX:-${EMAIL_BATCH_MAX_DEFAULT:-10}}"
    local now
    now=$(date +%s)

    if [ ! -f "$EMAIL_BATCH_FILE" ]; then
        return 0
    fi

    local count
    count=$(wc -l < "$EMAIL_BATCH_FILE" 2>/dev/null || echo 0)

    if [ "$count" -eq 0 ]; then
        return 0
    fi

    # Get oldest message timestamp
    local oldest
    oldest=$(head -n1 "$EMAIL_BATCH_FILE" | cut -d'|' -f1)

    local age=$((now - oldest))

    # Send if batch is old enough OR full enough
    if [ "$age" -ge "$batch_delay" ] || [ "$count" -ge "$batch_max" ]; then
        send_batched_email
    fi
}

# Send batched emails
send_batched_email() {
    if [ ! -f "$EMAIL_BATCH_FILE" ]; then
        return 0
    fi

    # Acquire lock
    if ! mkdir "$EMAIL_BATCH_LOCK" 2>/dev/null; then
        return 1
    fi

    # Read and clear batch file
    local batch_content
    if ! batch_content=$(cat "$EMAIL_BATCH_FILE" 2>/dev/null); then
        # Failed to read batch file
        rmdir "$EMAIL_BATCH_LOCK" 2>/dev/null
        return 1
    fi

    if ! : > "$EMAIL_BATCH_FILE" 2>/dev/null; then
        # Failed to clear batch file, but we have the content
        # Continue processing, file will be cleared next time
        :
    fi

    # Release lock
    if ! rmdir "$EMAIL_BATCH_LOCK" 2>/dev/null; then
        # Lock removal failed, but we have the batch content
        # This is not critical, continue processing
        :
    fi

    if [ -z "$batch_content" ]; then
        return 0
    fi

    # Format batched messages
    local batch_count
    batch_count=$(echo "$batch_content" | wc -l)

    # Get the first message as the main message
    local first_line
    first_line=$(echo "$batch_content" | head -n1)
    local first_timestamp="${first_line%%|*}"
    local first_msg="${first_line#*|}"

    # Get remaining messages for the batched items section (skip first line)
    local remaining_content
    remaining_content=$(echo "$batch_content" | tail -n +2)

    # Send as a single email with batched content
    # First message goes in MESSAGE, rest go in BATCHED_ITEMS
    local remaining_count=$((batch_count - 1))
    send_email_direct "$first_msg" "info" "$remaining_count" "$remaining_content"
}

# Escape HTML special characters to prevent XSS
html_escape() {
    local str="$1"
    str="${str//&/&amp;}"
    str="${str//</&lt;}"
    str="${str//>/&gt;}"
    str="${str//\"/&quot;}"
    str="${str//\'/&#x27;}"
    printf '%s' "$str"
}

# Remove template sections without using sed
remove_template_section() {
    local content="$1"
    local start_tag="$2"
    local end_tag="$3"

    # Use bash pattern matching to remove sections
    while [[ "$content" =~ (.*)"$start_tag"[^}]*"$end_tag"(.*) ]]; do
        content="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    done

    printf '%s' "$content"
}

# Render email template
render_email_template() {
    local template_file="$1"
    local message="$2"
    local type="${3:-info}"
    local batch_count="${4:-0}"
    local batched_items_data="${5:-}"  # Format: "timestamp1|msg1\ntimestamp2|msg2\n..."

    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S %Z")

    local hostname
    hostname=$(hostname)

    local project="${RALPH_PROJECT_NAME:-}"

    # Determine type label
    local type_label="Information"
    case "$type" in
        success) type_label="Success" ;;
        warning) type_label="Warning" ;;
        error) type_label="Error" ;;
        progress) type_label="Progress Update" ;;
    esac

    # Read template
    local content
    content=$(cat "$template_file")

    # Escape message for HTML if template is HTML
    local escaped_message="$message"
    if [[ "$template_file" == *.html ]]; then
        escaped_message=$(html_escape "$message")
    fi

    # Replace variables using bash substitution (no sed)
    content="${content//\{\{MESSAGE\}\}/$escaped_message}"
    content="${content//\{\{TYPE\}\}/$type}"
    content="${content//\{\{TYPE_LABEL\}\}/$type_label}"
    content="${content//\{\{TIMESTAMP\}\}/$timestamp}"
    content="${content//\{\{HOSTNAME\}\}/$hostname}"
    content="${content//\{\{PROJECT\}\}/$project}"
    content="${content//\{\{BATCH_COUNT\}\}/$batch_count}"

    # Handle conditional sections without sed
    if [ -n "$project" ]; then
        content="${content//\{\{#HAS_PROJECT\}\}/}"
        content="${content//\{\{\/HAS_PROJECT\}\}/}"
    else
        # Remove project sections using bash pattern matching
        content=$(remove_template_section "$content" "{{#HAS_PROJECT}}" "{{/HAS_PROJECT}}")
    fi

    if [ "$batch_count" -gt 0 ]; then
        content="${content//\{\{#HAS_BATCHED\}\}/}"
        content="${content//\{\{\/HAS_BATCHED\}\}/}"

        # Expand {{#BATCHED_ITEMS}}...{{/BATCHED_ITEMS}} loop
        if [ -n "$batched_items_data" ]; then
            content=$(expand_batched_items "$content" "$batched_items_data" "$template_file")
        else
            # No batched items data provided, remove the section
            content=$(remove_template_section "$content" "{{#BATCHED_ITEMS}}" "{{/BATCHED_ITEMS}}")
        fi
    else
        # Remove batched sections using bash pattern matching
        content=$(remove_template_section "$content" "{{#HAS_BATCHED}}" "{{/HAS_BATCHED}}")
    fi

    echo "$content"
}

# Expand batched items loop in template
expand_batched_items() {
    local content="$1"
    local batched_items_data="$2"
    local template_file="$3"

    # Extract the template block between {{#BATCHED_ITEMS}} and {{/BATCHED_ITEMS}}
    local start_tag="{{#BATCHED_ITEMS}}"
    local end_tag="{{/BATCHED_ITEMS}}"

    # Find the item template
    if [[ "$content" =~ $start_tag(.*?)$end_tag ]]; then
        # Bash regex doesn't support non-greedy, use a different approach
        :
    fi

    # Extract item template using parameter expansion
    local before_items="${content%%${start_tag}*}"
    local after_start="${content#*${start_tag}}"
    local item_template="${after_start%%${end_tag}*}"
    local after_items="${content#*${end_tag}}"

    # Generate expanded items
    local expanded_items=""
    while IFS='|' read -r item_timestamp item_msg; do
        [ -z "$item_timestamp" ] && continue

        # Format the timestamp
        local item_time
        item_time=$(date -d "@$item_timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || \
                   date -r "$item_timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || \
                   echo "$item_timestamp")

        # Escape for HTML if needed
        local escaped_item_msg="$item_msg"
        local escaped_item_time="$item_time"
        if [[ "$template_file" == *.html ]]; then
            escaped_item_msg=$(html_escape "$item_msg")
            escaped_item_time=$(html_escape "$item_time")
        fi

        # Replace placeholders in item template
        local item_content="$item_template"
        item_content="${item_content//\{\{ITEM_TIME\}\}/$escaped_item_time}"
        item_content="${item_content//\{\{ITEM_MESSAGE\}\}/$escaped_item_msg}"

        expanded_items="${expanded_items}${item_content}"
    done <<< "$batched_items_data"

    # Reassemble the content
    printf '%s%s%s' "$before_items" "$expanded_items" "$after_items"
}

# Send email via SMTP
send_email_smtp() {
    local to="$1"
    local subject="$2"
    local body="$3"
    local is_html="${4:-false}"

    local smtp_host="${RALPH_SMTP_HOST}"
    local smtp_port="${RALPH_SMTP_PORT:-587}"
    local smtp_user="${RALPH_SMTP_USER}"
    local smtp_pass="${RALPH_SMTP_PASSWORD}"
    local smtp_tls="${RALPH_SMTP_TLS:-true}"
    local from="${RALPH_EMAIL_FROM}"

    # Check if we have required SMTP credentials
    if [ -z "$smtp_host" ] || [ -z "$smtp_user" ] || [ -z "$smtp_pass" ]; then
        return 1
    fi

    # Create email message
    local content_type="text/plain; charset=UTF-8"
    if [ "$is_html" = true ]; then
        content_type="text/html; charset=UTF-8"
    fi

    local email_file
    email_file=$(mktemp) || {
        return 1
    }
    chmod 600 "$email_file"

    cat > "$email_file" << EOF
From: $from
To: $to
Subject: $subject
MIME-Version: 1.0
Content-Type: $content_type

$body
EOF

    # Send using curl with SMTP
    local smtp_url="smtp://${smtp_host}:${smtp_port}"
    local smtp_opts=""

    if [ "$smtp_tls" = true ]; then
        smtp_opts="--ssl-reqd"
    fi

    local result=0
    local smtp_timeout="${HTTP_SMTP_TIMEOUT:-30}"
    curl -s --url "$smtp_url" \
        $smtp_opts \
        --mail-from "$from" \
        --mail-rcpt "$to" \
        --user "${smtp_user}:${smtp_pass}" \
        --upload-file "$email_file" \
        --max-time "$smtp_timeout" 2>&1 > /dev/null || result=$?

    rm -f "$email_file"
    return $result
}

# Send email via SendGrid API
send_email_sendgrid() {
    local to="$1"
    local subject="$2"
    local body="$3"
    local is_html="${4:-false}"

    local api_key="${RALPH_SENDGRID_API_KEY}"
    local from="${RALPH_EMAIL_FROM}"

    if [ -z "$api_key" ]; then
        return 1
    fi

    # Build JSON payload
    local content_type="text/plain"
    if [ "$is_html" = true ]; then
        content_type="text/html"
    fi

    local payload
    if command -v jq &> /dev/null; then
        payload=$(jq -n \
            --arg from "$from" \
            --arg to "$to" \
            --arg subject "$subject" \
            --arg body "$body" \
            --arg content_type "$content_type" \
            '{
                personalizations: [{to: [{email: $to}]}],
                from: {email: $from},
                subject: $subject,
                content: [{type: $content_type, value: $body}]
            }')
    else
        local escaped_body
        escaped_body=$(json_escape "$body")
        local escaped_subject
        escaped_subject=$(json_escape "$subject")
        payload="{\"personalizations\":[{\"to\":[{\"email\":\"$to\"}]}],\"from\":{\"email\":\"$from\"},\"subject\":\"$escaped_subject\",\"content\":[{\"type\":\"$content_type\",\"value\":\"$escaped_body\"}]}"
    fi

    # Send via SendGrid API
    local http_code
    local smtp_timeout="${HTTP_SMTP_TIMEOUT:-30}"
    http_code=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST \
        "https://api.sendgrid.com/v3/mail/send" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        --data "$payload" \
        --max-time "$smtp_timeout" 2>&1)

    local success_min="${HTTP_STATUS_SUCCESS_MIN:-200}"
    local success_max="${HTTP_STATUS_SUCCESS_MAX:-300}"
    if [ "$http_code" -ge "$success_min" ] && [ "$http_code" -lt "$success_max" ]; then
        return 0
    else
        return 1
    fi
}

# Send email via AWS SES
send_email_ses() {
    local to="$1"
    local subject="$2"
    local body="$3"
    local is_html="${4:-false}"

    local region="${RALPH_AWS_SES_REGION}"
    local access_key="${RALPH_AWS_ACCESS_KEY_ID}"
    local secret_key="${RALPH_AWS_SECRET_KEY}"
    local from="${RALPH_EMAIL_FROM}"

    if [ -z "$region" ] || [ -z "$access_key" ] || [ -z "$secret_key" ]; then
        return 1
    fi

    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        return 1
    fi

    # Escape quotes in body and subject
    local escaped_body
    local escaped_subject
    escaped_body="${body//\"/\\\"}"
    escaped_subject="${subject//\"/\\\"}"

    # Determine message format
    local message_arg
    if [ "$is_html" = true ]; then
        message_arg="Body={Html={Data=\"$escaped_body\",Charset=utf-8}}"
    else
        message_arg="Body={Text={Data=\"$escaped_body\",Charset=utf-8}}"
    fi

    # Send via AWS CLI
    AWS_ACCESS_KEY_ID="$access_key" \
    AWS_SECRET_ACCESS_KEY="$secret_key" \
    AWS_DEFAULT_REGION="$region" \
    aws ses send-email \
        --from "$from" \
        --destination "ToAddresses=$to" \
        --message "Subject={Data=\"$escaped_subject\",Charset=utf-8},$message_arg" \
        --region "$region" \
        --output json > /dev/null 2>&1

    return $?
}

# Main email sending function
send_email_direct() {
    local msg="$1"
    local type="${2:-info}"
    local batch_count="${3:-0}"
    local batched_items_data="${4:-}"  # Format: "timestamp1|msg1\ntimestamp2|msg2\n..."

    local to="${RALPH_EMAIL_TO}"
    local from="${RALPH_EMAIL_FROM}"
    local subject_prefix="${RALPH_EMAIL_SUBJECT:-Ralph Notification}"
    local use_html="${RALPH_EMAIL_HTML:-true}"

    # Check required config
    if [ -z "$to" ] || [ -z "$from" ]; then
        return 0  # Not configured, skip silently
    fi

    # Validate email addresses
    if ! validate_email "$to"; then
        $TEST_MODE && echo "  Email: FAILED (invalid recipient email address)"
        return 1
    fi

    if ! validate_email "$from"; then
        $TEST_MODE && echo "  Email: FAILED (invalid sender email address)"
        return 1
    fi

    # Determine subject based on message type
    local subject="$subject_prefix"
    case "$type" in
        success) subject="$subject_prefix - Success" ;;
        warning) subject="$subject_prefix - Warning" ;;
        error) subject="$subject_prefix - Error" ;;
        progress) subject="$subject_prefix - Progress Update" ;;
    esac

    if [ "$batch_count" -gt 0 ]; then
        subject="$subject_prefix - Batch Update ($batch_count notifications)"
    fi

    # Prepare email body
    local html_body=""
    local text_body=""

    if [ "$use_html" = true ] && [ -f "$RALPH_DIR/templates/email-notification.html" ]; then
        html_body=$(render_email_template "$RALPH_DIR/templates/email-notification.html" "$msg" "$type" "$batch_count" "$batched_items_data")
    fi

    if [ -f "$RALPH_DIR/templates/email-notification.txt" ]; then
        text_body=$(render_email_template "$RALPH_DIR/templates/email-notification.txt" "$msg" "$type" "$batch_count" "$batched_items_data")
    else
        # Fallback to plain message
        text_body="$msg"
    fi

    # Try sending methods in order of preference
    local sent=false

    # 1. Try SendGrid (fastest, most reliable cloud option)
    if [ -n "${RALPH_SENDGRID_API_KEY:-}" ]; then
        if [ "$use_html" = true ] && [ -n "$html_body" ]; then
            if send_email_sendgrid "$to" "$subject" "$html_body" true; then
                sent=true
            fi
        else
            if send_email_sendgrid "$to" "$subject" "$text_body" false; then
                sent=true
            fi
        fi
    fi

    # 2. Try AWS SES
    if [ "$sent" = false ] && [ -n "${RALPH_AWS_SES_REGION:-}" ]; then
        if [ "$use_html" = true ] && [ -n "$html_body" ]; then
            if send_email_ses "$to" "$subject" "$html_body" true; then
                sent=true
            fi
        else
            if send_email_ses "$to" "$subject" "$text_body" false; then
                sent=true
            fi
        fi
    fi

    # 3. Try SMTP
    if [ "$sent" = false ] && [ -n "${RALPH_SMTP_HOST:-}" ]; then
        if [ "$use_html" = true ] && [ -n "$html_body" ]; then
            if send_email_smtp "$to" "$subject" "$html_body" true; then
                sent=true
            fi
        else
            if send_email_smtp "$to" "$subject" "$text_body" false; then
                sent=true
            fi
        fi
    fi

    if [ "$sent" = true ]; then
        return 0
    else
        return 1
    fi
}

# Public send_email function (with batching logic)
send_email() {
    local msg="$1"

    if [ -z "${RALPH_EMAIL_TO:-}" ]; then
        return 0
    fi

    # Determine message type from content
    local msg_type="info"
    if echo "$msg" | grep -qiE "(error|failed|critical)"; then
        msg_type="error"
    elif echo "$msg" | grep -qiE "warning"; then
        msg_type="warning"
    elif echo "$msg" | grep -qiE "(success|completed|done)"; then
        msg_type="success"
    elif echo "$msg" | grep -qiE "(progress|running|processing)"; then
        msg_type="progress"
    fi

    # Check if we should batch this message
    if should_batch_email "$msg"; then
        add_to_batch "$msg"
        $TEST_MODE && echo "  Email: queued for batch"
        SENT_ANY=true
        return 0
    fi

    # Send immediately
    if send_email_direct "$msg" "$msg_type"; then
        SENT_ANY=true
        $TEST_MODE && echo "  Email: sent"
        return 0
    else
        $TEST_MODE && echo "  Email: FAILED"
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

    # Security: Validate script path
    # Must be absolute path, no traversal, and owned by user/root
    if [[ ! "$RALPH_CUSTOM_NOTIFY_SCRIPT" =~ ^/ ]]; then
        $TEST_MODE && echo "  Custom: FAILED (script must be absolute path)"
        return 1
    fi

    if [[ "$RALPH_CUSTOM_NOTIFY_SCRIPT" =~ \.\. ]]; then
        $TEST_MODE && echo "  Custom: FAILED (path traversal detected)"
        return 1
    fi

    # Verify script exists and is executable
    if [ ! -f "$RALPH_CUSTOM_NOTIFY_SCRIPT" ]; then
        $TEST_MODE && echo "  Custom: FAILED (script not found)"
        return 1
    fi

    if [ ! -x "$RALPH_CUSTOM_NOTIFY_SCRIPT" ]; then
        $TEST_MODE && echo "  Custom: FAILED (script not executable)"
        return 1
    fi

    # Check script ownership (must be owned by current user or root)
    local script_owner
    script_owner=$(stat -f '%Su' "$RALPH_CUSTOM_NOTIFY_SCRIPT" 2>/dev/null || stat -c '%U' "$RALPH_CUSTOM_NOTIFY_SCRIPT" 2>/dev/null || echo "unknown")
    if [ "$script_owner" != "$USER" ] && [ "$script_owner" != "root" ]; then
        $TEST_MODE && echo "  Custom: FAILED (script not owned by user or root)"
        return 1
    fi

    # Security: Check file permissions - should not be world-writable
    local perms
    perms=$(stat -f '%Lp' "$RALPH_CUSTOM_NOTIFY_SCRIPT" 2>/dev/null || stat -c '%a' "$RALPH_CUSTOM_NOTIFY_SCRIPT" 2>/dev/null)
    if [[ "${perms: -1}" =~ [2367] ]]; then
        $TEST_MODE && echo "  Custom: FAILED (script is world-writable)"
        return 1
    fi

    # Security: Scan script for suspicious content
    local suspicious_patterns=(
        'rm -rf /'
        'dd if='
        'mkfs\.'
        '>/dev/sd'
        'curl.*\|.*sh'
        'wget.*\|.*sh'
        'eval.*\$'
        'base64 -d.*\|.*sh'
        'nc -e'
        '/dev/tcp/'
    )

    for pattern in "${suspicious_patterns[@]}"; do
        if grep -qE "$pattern" "$RALPH_CUSTOM_NOTIFY_SCRIPT" 2>/dev/null; then
            $TEST_MODE && echo "  Custom: FAILED (suspicious content detected: $pattern)"
            return 1
        fi
    done

    # Security: For root-owned scripts, require user confirmation
    if [ "$script_owner" = "root" ]; then
        # Check if we've already confirmed this script (cache confirmation)
        local script_hash
        script_hash=$(shasum -a 256 "$RALPH_CUSTOM_NOTIFY_SCRIPT" 2>/dev/null || sha256sum "$RALPH_CUSTOM_NOTIFY_SCRIPT" 2>/dev/null | awk '{print $1}')
        # Use platform-appropriate home directory
        if command -v get_home_dir &>/dev/null; then
            local user_home=$(get_home_dir)
        else
            local user_home="${HOME}"
        fi
        local confirm_file="${user_home}/.ralph_custom_script_confirmed"

        if [ ! -f "$confirm_file" ] || ! grep -q "^${script_hash}$" "$confirm_file" 2>/dev/null; then
            # Interactive confirmation required
            if [ -t 0 ]; then
                echo ""
                echo "WARNING: Custom notification script is owned by root:"
                echo "  Path: $RALPH_CUSTOM_NOTIFY_SCRIPT"
                echo "  Owner: $script_owner"
                echo ""
                read -p "Do you want to execute this script? (yes/no): " -r confirm
                echo ""

                if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                    $TEST_MODE && echo "  Custom: SKIPPED (user declined root-owned script)"
                    return 1
                fi

                # Cache confirmation for this script version
                mkdir -p "$(dirname "$confirm_file")"
                echo "$script_hash" >> "$confirm_file"
            else
                # Non-interactive mode: refuse to run root-owned scripts without prior confirmation
                $TEST_MODE && echo "  Custom: FAILED (root-owned script requires interactive confirmation)"
                return 1
            fi
        fi
    fi

    # Strip Slack-style emoji codes for cleaner output (avoid sed on user input)
    local clean_msg="$msg"
    clean_msg="${clean_msg//:rocket:/🚀}"
    clean_msg="${clean_msg//:white_check_mark:/✅}"
    clean_msg="${clean_msg//:warning:/⚠️}"
    clean_msg="${clean_msg//:gear:/⚙️}"
    clean_msg="${clean_msg//:robot_face:/🤖}"
    clean_msg="${clean_msg//:x:/❌}"
    clean_msg="${clean_msg//:clipboard:/📋}"

    # Execute script with timeout and capture exit code
    local exit_code=0
    local script_timeout="${CUSTOM_SCRIPT_TIMEOUT:-30}"
    timeout "$script_timeout" "$RALPH_CUSTOM_NOTIFY_SCRIPT" "$clean_msg" > /dev/null 2>&1 || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        SENT_ANY=true
        $TEST_MODE && echo "  Custom: sent"
        return 0
    elif [ $exit_code -eq 124 ]; then
        $TEST_MODE && echo "  Custom: FAILED (timeout after ${script_timeout}s)"
        return 1
    else
        $TEST_MODE && echo "  Custom: FAILED (exit code $exit_code)"
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
    if [ -n "${RALPH_SLACK_WEBHOOK_URL:-}" ]; then
        if validate_webhook_url "$RALPH_SLACK_WEBHOOK_URL"; then
            echo "  - Slack: configured (valid)"
        else
            echo "  - Slack: configured (INVALID URL - must use HTTP or HTTPS)"
        fi
    else
        echo "  - Slack: not configured"
    fi

    if [ -n "${RALPH_DISCORD_WEBHOOK_URL:-}" ]; then
        if validate_webhook_url "$RALPH_DISCORD_WEBHOOK_URL"; then
            echo "  - Discord: configured (valid)"
        else
            echo "  - Discord: configured (INVALID URL - must use HTTP or HTTPS)"
        fi
    else
        echo "  - Discord: not configured"
    fi

    if [ -n "${RALPH_TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${RALPH_TELEGRAM_CHAT_ID:-}" ]; then
        echo "  - Telegram: configured (token: $(mask_token "${RALPH_TELEGRAM_BOT_TOKEN}"))"
    else
        echo "  - Telegram: not configured"
    fi

    # Email configuration check
    if [ -n "${RALPH_EMAIL_TO:-}" ] && [ -n "${RALPH_EMAIL_FROM:-}" ]; then
        email_method="unknown"
        if [ -n "${RALPH_SENDGRID_API_KEY:-}" ]; then
            email_method="SendGrid API"
        elif [ -n "${RALPH_AWS_SES_REGION:-}" ]; then
            email_method="AWS SES"
        elif [ -n "${RALPH_SMTP_HOST:-}" ]; then
            email_method="SMTP ($RALPH_SMTP_HOST)"
        fi
        echo "  - Email: configured (to: $RALPH_EMAIL_TO, method: $email_method)"
    else
        echo "  - Email: not configured"
    fi

    if [ -n "${RALPH_CUSTOM_NOTIFY_SCRIPT:-}" ]; then
        echo "  - Custom: configured ($RALPH_CUSTOM_NOTIFY_SCRIPT)"
    else
        echo "  - Custom: not configured"
    fi
    echo ""
    echo "Sending test message..."
fi

# Check rate limit (skip in test mode)
if ! $TEST_MODE; then
    if ! check_rate_limit; then
        echo "Rate limit exceeded (max $RATE_LIMIT_MAX notifications per minute)" >&2
        exit 1
    fi
fi

# Track errors for better reporting (using simple string instead of associative array for bash 3 compat)
SEND_ERRORS=""

# Send to all configured platforms with individual error tracking
if ! send_slack "$MESSAGE"; then
    SEND_ERRORS="${SEND_ERRORS}slack "
fi

if ! send_discord "$MESSAGE"; then
    SEND_ERRORS="${SEND_ERRORS}discord "
fi

if ! send_telegram "$MESSAGE"; then
    SEND_ERRORS="${SEND_ERRORS}telegram "
fi

if ! send_email "$MESSAGE"; then
    SEND_ERRORS="${SEND_ERRORS}email "
fi

if ! send_custom "$MESSAGE"; then
    SEND_ERRORS="${SEND_ERRORS}custom "
fi

# Cleanup rate limit file on exit
trap "rm -f '$RATE_LIMIT_FILE' 2>/dev/null || true" EXIT

if $TEST_MODE; then
    echo ""
    if $SENT_ANY; then
        echo "Test complete! Check your notification channels."
        if [ -n "$SEND_ERRORS" ]; then
            echo ""
            echo "Note: Some platforms failed to send. Check configuration."
        fi
    else
        echo "No notifications sent. Configure at least one platform."
        echo "Run: ralph notify setup"
    fi
fi

# Note: We exit 0 even if notifications fail to avoid blocking the main script.
# The main ralph.sh script should continue even if notifications are down.
# Errors are logged but don't cause a fatal exit.

exit 0

#!/bin/bash
# Ralph Progress Monitor - Posts updates to Slack
# Bash version for Linux/macOS support
# Usage: ./monitor-progress.sh [interval_seconds] [repo_dir]

set -euo pipefail

INTERVAL=${1:-300}  # Default: 5 minutes (300 seconds)
REPO_DIR=${2:-$(pwd)}

# Load Ralph config for Slack webhook
CONFIG_FILE="$HOME/.ralph.env"

if [ -f "$CONFIG_FILE" ]; then
    # Parse the .env file safely
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')  # trim
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            if [[ "$line" =~ ^(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=\"?([^\"]*)\"?$ ]]; then
                var_name="${BASH_REMATCH[2]}"
                var_value="${BASH_REMATCH[3]}"
                export "$var_name"="$var_value"
            fi
        fi
    done < "$CONFIG_FILE"
fi

SLACK_WEBHOOK="${RALPH_SLACK_WEBHOOK_URL:-}"

if [ -z "$SLACK_WEBHOOK" ]; then
    echo "❌ Error: RALPH_SLACK_WEBHOOK_URL not set in $CONFIG_FILE" >&2
    echo "Set it by adding to the file: export RALPH_SLACK_WEBHOOK_URL=\"https://hooks.slack.com/services/YOUR/WEBHOOK/URL\"" >&2
    exit 1
fi

echo "Ralph Progress Monitor Started"
echo "Interval: ${INTERVAL}s"
echo "Repo: $REPO_DIR"
echo "Slack: Enabled"
echo ""

# Parse a progress file and return: "total completed status"
parse_progress() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        echo "0 0 NOT_FOUND"
        return
    fi

    local content
    content=$(cat "$file_path")

    # Extract status
    local status="UNKNOWN"
    local in_status_section=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^##[[:space:]]*Status ]]; then
            in_status_section=true
            continue
        fi
        if [ "$in_status_section" = true ] && [ -n "$(echo "$line" | tr -d '[:space:]')" ]; then
            status=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            break
        fi
    done <<< "$content"

    # Count tasks (checkbox format: - [ ] or - [x])
    local total completed
    total=$(echo "$content" | grep -cE '^- \[[x ]\]' || true)
    completed=$(echo "$content" | grep -c '^- \[x\]' || true)

    # If no checkboxes found, try task list format
    if [ "$total" -eq 0 ]; then
        total=$(echo "$content" | grep -cE '^(Task|Phase) [0-9]' || true)
        completed=$(echo "$content" | grep -cE '^(Task|Phase) [0-9].*✅' || true)
    fi

    echo "$total $completed $status"
}

# Calculate percentage
calc_percent() {
    local completed="$1"
    local total="$2"

    if [ "$total" -eq 0 ]; then
        echo "0"
        return
    fi

    echo $((completed * 100 / total))
}

# Get last update time
get_last_update() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        echo "N/A"
        return
    fi

    local mtime now diff
    mtime=$(stat -c %Y "$file_path" 2>/dev/null || stat -f %m "$file_path" 2>/dev/null)
    now=$(date +%s)
    diff=$((now - mtime))

    if [ "$diff" -lt 60 ]; then
        echo "${diff}s ago"
    elif [ "$diff" -lt 3600 ]; then
        echo "$((diff / 60))m ago"
    else
        echo "$((diff / 3600))h ago"
    fi
}

# Escape strings for JSON
json_escape() {
    local text="$1"
    
    # Escape backslashes first (order matters!)
    text="${text//\\/\\\\}"
    # Escape double quotes
    text="${text//\"/\\\"}"
    # Escape tab, newline, carriage return
    text="${text//$'\t'/\\t}"
    text="${text//$'\n'/\\n}"
    text="${text//$'\r'/\\r}"
    # Remove other control characters (simplified)
    text=$(echo "$text" | tr -d '\000-\010\013\014\016-\037')
    
    echo "$text"
}

# Track consecutive notification failures
SLACK_FAILURE_COUNT=0
SLACK_MAX_FAILURES=3

# Send to Slack with error handling
send_slack() {
    local message="$1"
    local escaped_message
    escaped_message=$(json_escape "$message")
    
    # Build JSON payload safely
    local payload="{\"text\": \"$escaped_message\"}"
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 10 \
        "$SLACK_WEBHOOK" | grep -q "^200$"; then
        SLACK_FAILURE_COUNT=0
        return 0
    else
        SLACK_FAILURE_COUNT=$((SLACK_FAILURE_COUNT + 1))
        
        echo "[$timestamp] Slack notification failed (failure #$SLACK_FAILURE_COUNT)" >&2
        
        if [ "$SLACK_FAILURE_COUNT" -ge "$SLACK_MAX_FAILURES" ]; then
            echo "[$timestamp] WARNING: $SLACK_FAILURE_COUNT consecutive Slack notification failures" >&2
            echo "[$timestamp] Check webhook URL: $SLACK_WEBHOOK" >&2
            echo "[$timestamp] Monitoring will continue, but notifications are not being delivered" >&2
        fi
        
        return 1
    fi
}

# Track previous state to avoid spam
declare -A PREV_PERCENT
declare -A PREV_STATUS

# Main monitoring loop
iteration=0
while true; do
    iteration=$((iteration + 1))
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] Iteration $iteration"
    
    updates=""
    
    # Find all progress files
    while IFS= read -r -d '' progress_file; do
        plan_name=$(basename "$progress_file" _PROGRESS.md)
        
        # Parse progress info
        read -r total completed status < <(parse_progress "$progress_file")
        percent=$(calc_percent "$completed" "$total")
        last_update=$(get_last_update "$progress_file")
        
        # Determine status emoji
        status_emoji="🔄"
        case "$status" in
            COMPLETED|DONE) status_emoji="✅" ;;
            IN_PROGRESS) status_emoji="🚧" ;;
            FAILED|ERROR) status_emoji="❌" ;;
            STALLED) status_emoji="⚠️" ;;
        esac
        
        # Check if there's a significant change
        prev_percent=${PREV_PERCENT[$plan_name]:-0}
        prev_status=${PREV_STATUS[$plan_name]:-""}
        
        significant_change=false
        if [ "$((percent - prev_percent))" -ge 5 ] || [ "$status" != "$prev_status" ]; then
            significant_change=true
        fi
        
        # Build update message
        update_line="$status_emoji *$plan_name*: $completed/$total tasks ($percent%) - _${status}_ - Last: $last_update"
        
        echo "  $plan_name: $completed/$total ($percent%) - $status - $last_update"
        
        # Add to updates if significant or first iteration
        if [ "$iteration" -eq 1 ] || [ "$significant_change" = true ]; then
            updates="${updates}${update_line}\n"
            PREV_PERCENT[$plan_name]=$percent
            PREV_STATUS[$plan_name]=$status
        fi
        
    done < <(find "$REPO_DIR" -name "*_PROGRESS.md" -type f -print0)
    
    # Send Slack update if there are changes
    if [ -n "$updates" ]; then
        slack_message=$(printf "📊 *Ralph Progress Update* - %s\n\n%s" "$timestamp" "$updates")
        if send_slack "$slack_message"; then
            echo "  ✓ Posted to Slack"
        else
            echo "  ⚠ Failed to post to Slack (monitoring continues)"
        fi
    else
        echo "  No significant changes"
    fi
    
    echo ""
    
    # Sleep until next check
    sleep "$INTERVAL"
done
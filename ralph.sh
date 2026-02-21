#!/bin/bash
# Ralph - Autonomous AI Development Loop
# Usage: ralph <plan-file> [plan|build] [max-iterations]
#
# Examples:
#   ralph ./my-feature-plan.md           # Build mode (default), runs until RALPH_DONE
#   ralph ./my-feature-plan.md plan      # Plan mode, generates implementation tasks
#   ralph ./my-feature-plan.md build 20  # Build mode, max 20 iterations
#
# Exit conditions:
#   - Plan mode: Exits after 1 iteration (planning complete)
#   - Build mode: "RALPH_DONE" appears in progress file
#   - Max iterations reached (if specified)
#   - Ctrl+C
#
# Progress is tracked in: <plan-name>_PROGRESS.md (in current directory)

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

# Colors (defined early for use in validation messages)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log directory for errors (use platform-appropriate paths)
if command -v get_home_dir &>/dev/null && command -v get_temp_dir &>/dev/null; then
    USER_HOME=$(get_home_dir)
    TEMP_DIR=$(get_temp_dir)
else
    USER_HOME="${HOME}"
    TEMP_DIR="${TMPDIR:-/tmp}"
fi

LOG_DIR="${USER_HOME}/.portableralph/logs"
if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
    echo "Warning: Could not create log directory: $LOG_DIR" >&2
    LOG_DIR="${TEMP_DIR}/ralph_logs"
    mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR=""
fi

# Error logging function
log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$1"
    local logfile="${LOG_DIR}/ralph_$(date '+%Y%m%d').log"

    # Log to file if LOG_DIR is available
    if [ -n "$LOG_DIR" ] && [ -d "$LOG_DIR" ]; then
        if ! echo "[$timestamp] ERROR: $message" >> "$logfile" 2>/dev/null; then
            # If logging to file fails, at least note it on stderr
            echo "[$timestamp] WARNING: Failed to write to log file: $logfile" >&2
        fi
    fi

    # Always log to stderr
    echo -e "${RED}Error: $message${NC}" >&2
}

# Source shared libraries
source "${RALPH_DIR}/lib/validation.sh"
source "${RALPH_DIR}/lib/error-handling.sh"

# Initialize enhanced error handling
setup_error_handling "ralph.sh" "$LOG_DIR"

# The following functions are now loaded from lib/validation.sh:
# - validate_webhook_url() / validate_url()
# - validate_numeric()
# - validate_email()
#
# Enhanced error handling functions from lib/error-handling.sh:
# - retry_command() - retry with exponential backoff
# - validate_api_key() - validate Claude API key format
# - validate_network_connectivity() - check network access
# - validate_file_path() / validate_path()
# - json_escape()
# - mask_token()

# Just use the library's validate_path function
# Users should be able to use whatever plan files they want
validate_file_path() {
    validate_path "$@"
}

# Validate config file syntax before sourcing - enhanced with corruption handling
validate_config() {
    local config_file="$1"

    # Check if file exists
    if [ ! -f "$config_file" ]; then
        return 0  # File doesn't exist, nothing to validate
    fi

    # Check for binary corruption or severely invalid content
    if ! file "$config_file" 2>/dev/null | grep -q "text"; then
        log_warning "Configuration file appears to be corrupted or contains binary data: $config_file"
        suggest_recovery "Remove corrupted config file: rm '$config_file' and reconfigure with 'ralph config'"
        return 2  # Corrupted file, handled gracefully
    fi

    # Check for null bytes or other corruption indicators
    if grep -l $'\0' "$config_file" >/dev/null 2>&1; then
        log_warning "Configuration file contains null bytes (corrupted): $config_file"
        suggest_recovery "Remove corrupted config file: rm '$config_file' and reconfigure with 'ralph config'"
        return 2  # Corrupted file, handled gracefully
    fi

    # Just check basic bash syntax
    if ! bash -n "$config_file" 2>/dev/null; then
        log_warning "Configuration file has syntax errors: $config_file"
        suggest_recovery "Fix syntax errors or remove file: rm '$config_file' and reconfigure with 'ralph config'"
        return 2  # Syntax error, handled gracefully
    fi

    return 0
}

# Load configuration (use platform-appropriate config location) with corruption recovery
RALPH_CONFIG_FILE="${USER_HOME}/.ralph.env"
if [ -f "$RALPH_CONFIG_FILE" ]; then
    # Temporarily disable exit on error for config validation
    set +e
    validate_config "$RALPH_CONFIG_FILE"
    config_status=$?
    set -e
    
    if [ $config_status -eq 0 ]; then
        # Config is valid, source it
        source "$RALPH_CONFIG_FILE"

        # Validate loaded configuration values
        if [ -n "${RALPH_SLACK_WEBHOOK_URL:-}" ]; then
            if ! validate_webhook_url "$RALPH_SLACK_WEBHOOK_URL" "RALPH_SLACK_WEBHOOK_URL"; then
                echo -e "${YELLOW}Warning: Invalid RALPH_SLACK_WEBHOOK_URL, disabling Slack notifications${NC}" >&2
                unset RALPH_SLACK_WEBHOOK_URL
            fi
        fi
    elif [ $config_status -eq 2 ]; then
        # Config is corrupted but handled gracefully - continue with defaults
        log_info "Continuing with default configuration due to corrupted config file"
        echo -e "${BLUE}Info: Using default configuration due to corrupted config file${NC}" >&2
    else
        # Other validation failure - continue with defaults
        log_warning "Configuration validation failed, using defaults"
    fi

    if [ -n "${RALPH_DISCORD_WEBHOOK_URL:-}" ]; then
        if ! validate_webhook_url "$RALPH_DISCORD_WEBHOOK_URL" "RALPH_DISCORD_WEBHOOK_URL"; then
            echo -e "${YELLOW}Warning: Invalid RALPH_DISCORD_WEBHOOK_URL, disabling Discord notifications${NC}" >&2
            unset RALPH_DISCORD_WEBHOOK_URL
        fi
    fi

    if [ -n "${RALPH_EMAIL_TO:-}" ]; then
        if ! validate_email "$RALPH_EMAIL_TO" "RALPH_EMAIL_TO"; then
            echo -e "${YELLOW}Warning: Invalid RALPH_EMAIL_TO, disabling email notifications${NC}" >&2
            unset RALPH_EMAIL_TO
        fi
    fi

    if [ -n "${RALPH_EMAIL_FROM:-}" ]; then
        if ! validate_email "$RALPH_EMAIL_FROM" "RALPH_EMAIL_FROM"; then
            echo -e "${YELLOW}Warning: Invalid RALPH_EMAIL_FROM, disabling email notifications${NC}" >&2
            unset RALPH_EMAIL_FROM
        fi
    fi

    if [ -n "${RALPH_NOTIFY_FREQUENCY:-}" ]; then
        # Note: Not using 'local' here since we're at top level, not in a function
        _notify_min="${NOTIFY_FREQUENCY_MIN:-1}"
        _notify_max="${NOTIFY_FREQUENCY_MAX:-100}"
        _notify_default="${NOTIFY_FREQUENCY_DEFAULT:-5}"
        if ! validate_numeric "$RALPH_NOTIFY_FREQUENCY" "RALPH_NOTIFY_FREQUENCY" "$_notify_min" "$_notify_max"; then
            echo -e "${YELLOW}Warning: Invalid RALPH_NOTIFY_FREQUENCY, using default: ${_notify_default}${NC}" >&2
            export RALPH_NOTIFY_FREQUENCY="$_notify_default"
        fi
        unset _notify_min _notify_max _notify_default
    fi
fi

# Decrypt encrypted environment variables
if [ -f "$RALPH_DIR/decrypt-env.sh" ]; then
    source "$RALPH_DIR/decrypt-env.sh"
    if ! decrypt_ralph_env 2>&1 | grep -q "^Error:"; then
        : # Decryption succeeded or no encrypted values
    else
        echo -e "${YELLOW}Warning: Failed to decrypt some environment variables${NC}" >&2
        echo "Run 'ralph notify setup' if you have notification issues" >&2
    fi
fi

VERSION="1.7.0"

# Auto-commit setting (default: true)
# Can be disabled via: ralph config commit off
# Or by adding DO_NOT_COMMIT on its own line in the plan file
RALPH_AUTO_COMMIT="${RALPH_AUTO_COMMIT:-true}"

# Check if plan file contains DO_NOT_COMMIT directive
# Skips content inside ``` code blocks to avoid false positives
should_skip_commit_from_plan() {
    local plan_file="$1"
    [ ! -f "$plan_file" ] && return 1

    # Use awk to skip code blocks and find DO_NOT_COMMIT on its own line
    # Handles whitespace before/after the directive
    awk '
        /^```/ { in_code = !in_code; next }
        !in_code && /^[[:space:]]*DO_NOT_COMMIT[[:space:]]*$/ { found=1; exit }
        END { exit !found }
    ' "$plan_file"
}

# Notification helper with retry logic and error logging
notify() {
    local message="$1"
    local emoji="${2:-}"
    local max_retries="${NOTIFY_MAX_RETRIES:-3}"
    local retry_delay="${NOTIFY_RETRY_DELAY:-2}"
    local attempt=1
    local notification_log="${LOG_DIR}/ralph_notifications_$(date '+%Y%m%d').log"

    # Skip if LOG_DIR is not available (use platform-appropriate null device)
    if [ -z "$LOG_DIR" ] || [ ! -d "$LOG_DIR" ]; then
        if command -v get_null_device &>/dev/null; then
            notification_log="$(get_null_device)"
        else
            notification_log="/dev/null"
        fi
    fi

    while [ $attempt -le $max_retries ]; do
        local notify_output
        local notify_exit=0

        # Capture output and exit code
        notify_output=$("$RALPH_DIR/notify.sh" "$message" "$emoji" 2>&1) || notify_exit=$?

        # Log the output with proper error handling (check for null device)
        local null_dev="/dev/null"
        if command -v get_null_device &>/dev/null; then
            null_dev="$(get_null_device)"
        fi
        if [ "$notification_log" != "$null_dev" ] && [ "$notification_log" != "NUL" ]; then
            if ! echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $attempt: $notify_output" >> "$notification_log" 2>/dev/null; then
                # If logging fails, report to stderr but don't fail the notification
                echo "Warning: Failed to write to notification log: $notification_log" >&2
            fi
        fi

        if [ $notify_exit -eq 0 ]; then
            return 0
        fi

        if [ $attempt -lt $max_retries ]; then
            log_error "Notification attempt $attempt/$max_retries failed (exit $notify_exit), retrying in ${retry_delay}s..."
            sleep $retry_delay
            # Exponential backoff
            retry_delay=$((retry_delay * 2))
        else
            local msg_truncate="${MESSAGE_TRUNCATE_LENGTH:-100}"
            log_error "Notification failed after $max_retries attempts (exit $notify_exit): ${message:0:$msg_truncate}..."
        fi

        attempt=$((attempt + 1))
    done

    return 1  # Failed after all retries
}

# Check if any notification platform is configured
notifications_enabled() {
    [ -n "${RALPH_SLACK_WEBHOOK_URL:-}" ] || \
    [ -n "${RALPH_DISCORD_WEBHOOK_URL:-}" ] || \
    ([ -n "${RALPH_TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${RALPH_TELEGRAM_CHAT_ID:-}" ]) || \
    [ -n "${RALPH_CUSTOM_NOTIFY_SCRIPT:-}" ] || \
    ([ -n "${RALPH_EMAIL_TO:-}" ] && [ -n "${RALPH_EMAIL_FROM:-}" ])
}

usage() {
    echo -e "${GREEN}PortableRalph${NC} v${VERSION} - Autonomous AI Development Loop"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ralph <plan-file> [mode] [max-iterations]"
    echo "  ralph update [--check|--list|<version>]"
    echo "  ralph rollback"
    echo "  ralph config <setting>"
    echo "  ralph notify <setup|test>"
    echo "  ralph --help | -h"
    echo "  ralph --version | -v"
    echo ""
    echo -e "${YELLOW}Full path:${NC} ~/ralph/ralph.sh (alias: ralph)"
    echo ""
    echo -e "${YELLOW}Arguments:${NC}"
    echo "  plan-file       Path to your plan/spec file (required)"
    echo "  mode            'plan' or 'build' (default: build)"
    echo "  max-iterations  Maximum loop iterations (default: unlimited)"
    echo ""
    echo -e "${YELLOW}Modes:${NC}"
    echo "  plan   Analyze codebase, create task list (runs once, then exits)"
    echo "  build  Implement tasks one at a time until RALPH_DONE"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ralph ./feature.md              # Build until done"
    echo "  ralph ./feature.md plan         # Plan only (creates task list, exits)"
    echo "  ralph ./feature.md build 20     # Build, max 20 iterations"
    echo ""
    echo -e "${YELLOW}Exit Conditions:${NC}"
    echo "  - Plan mode: Exits after 1 iteration when task list is created"
    echo "  - Build mode: RALPH_DONE appears in <plan-name>_PROGRESS.md"
    echo "  - Max iterations reached (if specified)"
    echo "  - Ctrl+C"
    echo ""
    echo -e "${YELLOW}Progress File:${NC}"
    echo "  Created as <plan-name>_PROGRESS.md in current directory"
    echo "  This is the only artifact left in your repo"
    echo ""
    echo -e "${YELLOW}Updates:${NC}"
    echo "  ralph update              Update to latest version"
    echo "  ralph update --check      Check for updates without installing"
    echo "  ralph update --list       List all available versions"
    echo "  ralph update <version>    Install specific version (e.g., 1.4.0)"
    echo "  ralph rollback            Rollback to previous version"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  ralph config commit on      Enable auto-commit (default)"
    echo "  ralph config commit off     Disable auto-commit"
    echo "  ralph config commit status  Show current setting"
    echo ""
    echo -e "${YELLOW}Plan File Directives:${NC}"
    echo "  Add DO_NOT_COMMIT on its own line to disable commits for that plan"
    echo ""
    echo -e "${YELLOW}Notifications (optional):${NC}"
    echo "  Supports Slack, Discord, Telegram, and custom scripts"
    echo "  ralph notify setup    Configure notification platforms"
    echo "  ralph notify test     Send a test notification"
    echo ""
    echo "More info: https://github.com/aaron777collins/portableralph"
    exit 0
}

version() {
    echo "PortableRalph v${VERSION}"
    exit 0
}

# Parse arguments
if [ $# -lt 1 ]; then
    usage
fi

# Handle help and version flags
if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ]; then
    usage
fi

if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    version
fi

if [ "$1" = "--test-notify" ] || [ "$1" = "--test-notifications" ]; then
    "$RALPH_DIR/notify.sh" --test
    exit 0
fi

# Handle update subcommand
if [ "$1" = "update" ]; then
    exec "$RALPH_DIR/update.sh" "${@:2}"
fi

# Handle rollback subcommand
if [ "$1" = "rollback" ]; then
    exec "$RALPH_DIR/update.sh" --rollback
fi

# Handle notify subcommand
if [ "$1" = "notify" ]; then
    case "${2:-}" in
        setup)
            exec "$RALPH_DIR/setup-notifications.sh"
            ;;
        test)
            exec "$RALPH_DIR/notify.sh" --test
            ;;
        "")
            echo -e "${YELLOW}Usage:${NC} ralph notify <command>"
            echo ""
            echo -e "${YELLOW}Commands:${NC}"
            echo "  setup    Configure Slack, Discord, Telegram, or custom notifications"
            echo "  test     Send a test notification to all configured platforms"
            exit 1
            ;;
        *)
            echo -e "${RED}Unknown notify command: $2${NC}"
            echo "Run 'ralph notify' for available commands."
            exit 1
            ;;
    esac
fi

# Handle config subcommand
if [ "$1" = "config" ]; then
    CONFIG_FILE="$RALPH_CONFIG_FILE"

    # Helper to set a config value (handles both export and non-export patterns)
    set_config_value() {
        local key="$1"
        local value="$2"

        # Security: Escape special characters in value for safe sed usage
        # This prevents sed injection by escaping: / \ & newlines and special chars
        local escaped_value
        escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g' -e 's/$/\\/' | tr -d '\n' | sed 's/\\$//')

        if [ -f "$CONFIG_FILE" ]; then
            # Check if key exists (with or without export)
            if grep -qE "^(export )?${key}=" "$CONFIG_FILE" 2>/dev/null; then
                # Update existing (handle both patterns)
                # Use a temporary file for atomic operation
                local temp_file
                temp_file=$(mktemp) || {
                    log_error "Failed to create temp file for config update"
                    return 1
                }
                chmod 600 "$temp_file"
                trap 'rm -f "$temp_file" 2>/dev/null' RETURN

                # Process the file line by line to avoid sed injection
                while IFS= read -r line || [ -n "$line" ]; do
                    if [[ "$line" =~ ^export\ ${key}= ]] || [[ "$line" =~ ^${key}= ]]; then
                        echo "export ${key}=\"${escaped_value}\""
                    else
                        echo "$line"
                    fi
                done < "$CONFIG_FILE" > "$temp_file"

                mv "$temp_file" "$CONFIG_FILE"
            else
                # Append to existing file (preserve content)
                echo "" >> "$CONFIG_FILE"
                echo "# Auto-commit setting" >> "$CONFIG_FILE"
                echo "export ${key}=\"${escaped_value}\"" >> "$CONFIG_FILE"
            fi
        else
            # Create new file
            echo '# PortableRalph Configuration' > "$CONFIG_FILE"
            echo "# Generated on $(date)" >> "$CONFIG_FILE"
            echo "" >> "$CONFIG_FILE"
            echo "export ${key}=\"${escaped_value}\"" >> "$CONFIG_FILE"
            chmod 600 "$CONFIG_FILE"
        fi
    }

    case "${2:-}" in
        commit)
            case "${3:-}" in
                on|true|yes|1)
                    set_config_value "RALPH_AUTO_COMMIT" "true"
                    echo -e "${GREEN}Auto-commit enabled${NC}"
                    echo "Ralph will commit after each iteration."
                    ;;
                off|false|no|0)
                    set_config_value "RALPH_AUTO_COMMIT" "false"
                    echo -e "${YELLOW}Auto-commit disabled${NC}"
                    echo "Ralph will NOT commit after each iteration."
                    echo "You can also add DO_NOT_COMMIT on its own line in your plan file."
                    ;;
                status|"")
                    echo -e "${YELLOW}Auto-commit setting:${NC}"
                    if [ "$RALPH_AUTO_COMMIT" = "true" ]; then
                        echo -e "  Current: ${GREEN}enabled${NC} (commits after each iteration)"
                    else
                        echo -e "  Current: ${YELLOW}disabled${NC} (no automatic commits)"
                    fi
                    echo ""
                    echo -e "${YELLOW}Usage:${NC}"
                    echo "  ralph config commit on     Enable auto-commit (default)"
                    echo "  ralph config commit off    Disable auto-commit"
                    echo ""
                    echo -e "${YELLOW}Plan file override:${NC}"
                    echo "  Add DO_NOT_COMMIT on its own line to disable commits for that plan"
                    ;;
                *)
                    echo -e "${RED}Unknown option: $3${NC}"
                    echo "Usage: ralph config commit <on|off|status>"
                    exit 1
                    ;;
            esac
            exit 0
            ;;
        "")
            echo -e "${YELLOW}Usage:${NC} ralph config <setting>"
            echo ""
            echo -e "${YELLOW}Settings:${NC}"
            echo "  commit <on|off|status>    Configure auto-commit behavior"
            exit 1
            ;;
        *)
            echo -e "${RED}Unknown config setting: $2${NC}"
            echo "Run 'ralph config' for available settings."
            exit 1
            ;;
    esac
fi

PLAN_FILE="$1"
MODE="${2:-build}"
MAX_ITERATIONS="${3:-${MAX_ITERATIONS_DEFAULT:-0}}"

# Enhanced validation of input parameters
if ! validate_file_enhanced "$PLAN_FILE" "Plan file"; then
    exit 1
fi

# Validate mode
if [ "$MODE" != "plan" ] && [ "$MODE" != "build" ]; then
    # Disable the exit trap temporarily to show our specific error
    trap - EXIT
    printf "Error: Invalid mode '%s'. Valid modes are: plan, build\n" "$MODE" >&2
    printf "Run 'ralph --help' for usage information.\n" >&2
    exit 1
fi

# Validate max iterations with enhanced error handling
if [ "$MAX_ITERATIONS" != "0" ]; then
    max_iter_min="${MAX_ITERATIONS_MIN:-1}"
    max_iter_max="${MAX_ITERATIONS_MAX:-10000}"
    if ! validate_numeric "$MAX_ITERATIONS" "Max iterations" "$max_iter_min" "$max_iter_max"; then
        suggest_recovery "Use a number between $max_iter_min and $max_iter_max, or use 0 for unlimited iterations"
        exit 1
    fi
fi

# Derive progress file name from plan file
PLAN_BASENAME=$(basename "$PLAN_FILE" .md)
PROGRESS_FILE="${PLAN_BASENAME}_PROGRESS.md"
PLAN_FILE_ABS=$(realpath "$PLAN_FILE")

# Select prompt template
if [ "$MODE" = "plan" ]; then
    PROMPT_TEMPLATE="$RALPH_DIR/PROMPT_plan.md"
else
    PROMPT_TEMPLATE="$RALPH_DIR/PROMPT_build.md"
fi

# Verify prompt template exists
if [ ! -f "$PROMPT_TEMPLATE" ]; then
    echo -e "${RED}Error: Prompt template not found: $PROMPT_TEMPLATE${NC}"
    echo "Run the setup script or create the template manually."
    exit 1
fi

# Compute commit setting (check env var and plan file)
# DO_NOT_COMMIT in plan file takes precedence for that specific plan
SHOULD_COMMIT="true"
COMMIT_DISABLED_REASON=""
if [ "$RALPH_AUTO_COMMIT" != "true" ]; then
    SHOULD_COMMIT="false"
    COMMIT_DISABLED_REASON="(disabled via config)"
elif should_skip_commit_from_plan "$PLAN_FILE"; then
    SHOULD_COMMIT="false"
    COMMIT_DISABLED_REASON="(DO_NOT_COMMIT in plan)"
fi

# Print banner
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  RALPH - Autonomous AI Development Loop${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Plan:      ${YELLOW}$PLAN_FILE${NC}"
echo -e "  Mode:      ${YELLOW}$MODE${NC}"
echo -e "  Progress:  ${YELLOW}$PROGRESS_FILE${NC}"
[ "$MAX_ITERATIONS" -gt 0 ] && echo -e "  Max Iter:  ${YELLOW}$MAX_ITERATIONS${NC}"
if [ "$SHOULD_COMMIT" = "true" ]; then
    echo -e "  Commit:    ${GREEN}enabled${NC}"
else
    echo -e "  Commit:    ${YELLOW}disabled${NC} ${COMMIT_DISABLED_REASON}"
fi
if notifications_enabled; then
    PLATFORMS=""
    [ -n "${RALPH_SLACK_WEBHOOK_URL:-}" ] && PLATFORMS="${PLATFORMS}Slack "
    [ -n "${RALPH_DISCORD_WEBHOOK_URL:-}" ] && PLATFORMS="${PLATFORMS}Discord "
    [ -n "${RALPH_TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${RALPH_TELEGRAM_CHAT_ID:-}" ] && PLATFORMS="${PLATFORMS}Telegram "
    [ -n "${RALPH_CUSTOM_NOTIFY_SCRIPT:-}" ] && PLATFORMS="${PLATFORMS}Custom "
    [ -n "${RALPH_EMAIL_TO:-}" ] && [ -n "${RALPH_EMAIL_FROM:-}" ] && PLATFORMS="${PLATFORMS}Email "
    echo -e "  Notify:    ${GREEN}${PLATFORMS}${NC}"
else
    echo -e "  Notify:    ${YELLOW}disabled${NC} (run 'ralph notify setup')"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Exit conditions:${NC}"
if [ "$MODE" = "plan" ]; then
    echo "  - Planning completes when task list is created (Status: IN_PROGRESS)"
    echo "  - Plan mode runs once then exits automatically"
else
    echo "  - RALPH_DONE in $PROGRESS_FILE signals all tasks complete (set by AI)"
fi
echo "  - Press Ctrl+C to stop manually"
echo ""

# Send start notification to Slack
REPO_NAME=$(basename "$(pwd)")
notify ":rocket: *Ralph Started*\n\`\`\`Plan: $PLAN_BASENAME\nMode: $MODE\nRepo: $REPO_NAME\`\`\`" ":rocket:"

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
    echo "# Progress: $PLAN_BASENAME" > "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
    echo "## Status" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
    echo "IN_PROGRESS" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
    echo "## Tasks Completed" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
fi

ITERATION=0

# Check for completion
# Uses -x to match whole lines only, preventing false positives from
# instructional text like "DO NOT set RALPH_DONE" in the progress file
is_done() {
    if [ -f "$PROGRESS_FILE" ]; then
        grep -qx "RALPH_DONE" "$PROGRESS_FILE" 2>/dev/null && return 0
    fi
    return 1
}

# ============================================================================
# CONCURRENCY PROTECTION (Fix for GitHub Issue #1)
# ============================================================================
# Prevent multiple Ralph instances from running on the same plan file
# This fixes API Error 400 due to tool use race conditions

# Generate lock file path based on plan file (unique per plan)
PLAN_HASH=$(echo "$PLAN_FILE_ABS" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$PLAN_BASENAME")
LOCK_FILE="${TEMP_DIR:-/tmp}/ralph_${PLAN_HASH}.lock"

# Cleanup function for graceful exit - integrates with error handling library
cleanup_lock() {
    if [ -n "${LOCK_FILE:-}" ]; then
        release_lock "$LOCK_FILE" 2>/dev/null || true
    fi
}

# Script-specific cleanup function called by error handling library
cleanup_script_specific() {
    local exit_code="${1:-1}"
    cleanup_lock
}

# Set up trap to use error handling library (which calls cleanup_script_specific)
# This ensures proper signal handling with exit code 130 for SIGINT
# The error handling library's trap will call cleanup_script_specific which calls cleanup_lock

# Acquire lock before starting the main loop
if ! acquire_lock "$LOCK_FILE"; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ERROR: Another Ralph instance is already running this plan${NC}"
    echo -e "${RED}  Plan: $PLAN_FILE${NC}"
    echo -e "${RED}  Lock: $LOCK_FILE${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}To force a new instance, remove the lock file:${NC}"
    echo -e "  rm -f $LOCK_FILE"
    exit 1
fi

echo -e "${GREEN}Lock acquired: $LOCK_FILE${NC}"

# Main loop
while true; do
    # Check exit conditions
    if is_done; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  RALPH_DONE - Work complete!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        notify ":white_check_mark: *Ralph Complete!*\n\`\`\`Plan: $PLAN_BASENAME\nIterations: $ITERATION\nRepo: $REPO_NAME\`\`\`" ":white_check_mark:"
        break
    fi

    if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$ITERATION" -ge "$MAX_ITERATIONS" ]; then
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  Max iterations reached: $MAX_ITERATIONS${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        notify ":warning: *Ralph Stopped*\n\`\`\`Plan: $PLAN_BASENAME\nReason: Max iterations reached ($MAX_ITERATIONS)\nRepo: $REPO_NAME\`\`\`" ":warning:"
        break
    fi

    ITERATION=$((ITERATION + 1))
    echo ""
    echo -e "${BLUE}══════════════════ ITERATION $ITERATION ══════════════════${NC}"
    echo ""

    # Build the prompt with substitutions (safely escape for sed to prevent injection)
    # Escape special sed characters: & \ / newlines
    escape_sed() {
        local str="$1"
        # Escape backslashes first, then forward slashes, then ampersands
        str="${str//\\/\\\\}"
        str="${str//\//\\/}"
        str="${str//&/\\&}"
        printf '%s' "$str"
    }

    # Variables for sed escaping (not using local since we're in main loop, not a function)
    safe_plan_file=$(escape_sed "$PLAN_FILE_ABS")
    safe_progress_file=$(escape_sed "$PROGRESS_FILE")
    safe_plan_name=$(escape_sed "$PLAN_BASENAME")
    safe_should_commit=$(escape_sed "$SHOULD_COMMIT")

    PROMPT=$(cat "$PROMPT_TEMPLATE" | \
        sed "s|\${PLAN_FILE}|$safe_plan_file|g" | \
        sed "s|\${PROGRESS_FILE}|$safe_progress_file|g" | \
        sed "s|\${PLAN_NAME}|$safe_plan_name|g" | \
        sed "s|\${AUTO_COMMIT}|$safe_should_commit|g")

    # Validate prerequisites before calling Claude
    if [ -n "${CLAUDE_API_KEY:-}" ]; then
        if ! validate_api_key "$CLAUDE_API_KEY"; then
            log_error "Invalid Claude API key format"
            exit 1
        fi
    fi
    
    # Check network connectivity
    if ! validate_network_connectivity "api.anthropic.com" 10; then
        log_error "Cannot reach Anthropic API servers"
        suggest_recovery "Check your internet connection and firewall settings"
        exit 1
    fi
    
    # Check available disk space (require 50MB minimum)
    if ! validate_disk_space 50 "."; then
        exit 1
    fi

    # Run Claude with retry logic (configurable attempts with exponential backoff)
    max_claude_retries="${CLAUDE_MAX_RETRIES:-3}"
    claude_retry_delay="${CLAUDE_RETRY_DELAY:-5}"
    claude_attempt=1
    claude_success=false
    claude_exit_code=0
    claude_errors=""
    error_detected=false
    error_type="unknown"

    while [ $claude_attempt -le $max_claude_retries ]; do
        if [ $claude_attempt -gt 1 ]; then
            echo -e "${YELLOW}Retrying Claude CLI (attempt $claude_attempt/$max_claude_retries) in ${claude_retry_delay}s...${NC}"
            sleep $claude_retry_delay
        fi

        # Reset for this attempt
        claude_exit_code=0
        error_detected=false
        error_type="unknown"
        claude_output_file=$(mktemp) || {
            log_error "Failed to create temp file for Claude output"
            exit 1
        }
        claude_error_file=$(mktemp) || {
            rm -f "$claude_output_file"
            log_error "Failed to create temp file for Claude errors"
            exit 1
        }
        chmod 600 "$claude_output_file" "$claude_error_file"

            #            --model sonnet \
        # Run Claude
        echo "$PROMPT" | claude -p \
            --dangerously-skip-permissions \
                        --model claude-opus-4-5 \
            --verbose > "$claude_output_file" 2>"$claude_error_file" || claude_exit_code=$?

        # Display output on first attempt or final retry
        if [ $claude_attempt -eq 1 ] || [ $claude_attempt -eq $max_claude_retries ]; then
            if [ -f "$claude_output_file" ]; then
                cat "$claude_output_file"
            fi
        fi

        # Capture any error output
        claude_errors=""
        if [ -f "$claude_error_file" ]; then
            claude_errors=$(cat "$claude_error_file" 2>/dev/null || echo "")
        fi

        # Check for known error patterns even if exit code is 0
        if [ $claude_exit_code -ne 0 ]; then
            error_detected=true
            case $claude_exit_code in
                1)   error_type="general error" ;;
                2)   error_type="CLI usage error" ;;
                130) error_type="interrupted by user (Ctrl+C)" ;;
                *)   error_type="exit code $claude_exit_code" ;;
            esac
        fi

        # Check error output for known patterns
        if [ -n "$claude_errors" ]; then
            if echo "$claude_errors" | grep -qi "authentication\|unauthorized\|api.*key"; then
                error_detected=true
                error_type="authentication failure"
            elif echo "$claude_errors" | grep -qi "rate.*limit\|too.*many.*requests"; then
                error_detected=true
                error_type="rate limit exceeded"
            elif echo "$claude_errors" | grep -qi "network\|connection\|timeout"; then
                error_detected=true
                error_type="network error"
            elif echo "$claude_errors" | grep -qi "not.*found\|command.*not.*found"; then
                error_detected=true
                error_type="Claude CLI not found or not in PATH"
            # GitHub Issue #1: Detect API 400 errors from tool use concurrency
            elif echo "$claude_errors" | grep -qi "400\|bad.*request\|tool.*use\|concurrency"; then
                error_detected=true
                error_type="API 400 error (tool use concurrency)"
            fi
        fi

        # Clean up temp files
        rm -f "$claude_output_file" "$claude_error_file"

        # Check if we succeeded
        if [ "$error_detected" = false ]; then
            claude_success=true
            break
        fi

        # Log the attempt error
        log_error "Claude CLI error at iteration $ITERATION (attempt $claude_attempt/$max_claude_retries): $error_type"
        if [ -n "$claude_errors" ]; then
            err_truncate="${ERROR_DETAILS_TRUNCATE_LENGTH:-500}"
            log_error "Error details: ${claude_errors:0:$err_truncate}"
        fi

        # For non-retryable errors, don't retry
        if [[ "$error_type" =~ "authentication"|"CLI usage error"|"interrupted by user"|"not found" ]]; then
            echo -e "${RED}Non-retryable error detected: $error_type${NC}"
            break
        fi

        # Increment retry counter and increase backoff with jitter
        claude_attempt=$((claude_attempt + 1))
        if [ $claude_attempt -le $max_claude_retries ]; then
            # Exponential backoff: 5s, 10s, 20s with random jitter (0-2s)
            # Jitter prevents "thundering herd" when multiple instances retry simultaneously
            # This is a key fix for GitHub Issue #1 (concurrency issues)
            jitter=$((RANDOM % 3))
            claude_retry_delay=$(( (claude_retry_delay * 2) + jitter ))
        fi
    done

    # If all retries failed, stop iterations
    if [ "$claude_success" = false ]; then
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}  Claude CLI Error (after $claude_attempt attempts): $error_type${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Check if this is a transient error that might benefit from manual retry
        # API 400 (tool use concurrency) is now retryable with proper locking
        if [[ "$error_type" =~ "rate limit"|"network"|"timeout"|"API 400" ]]; then
            echo -e "${YELLOW}This appears to be a transient error.${NC}"
            echo -e "${YELLOW}You may want to retry in a few minutes.${NC}"
        fi

        # Send error notification and log
        log_error "Stopping Ralph due to Claude CLI failure at iteration $ITERATION after $claude_attempt attempts"
        notify ":x: *Ralph Error*\n\`\`\`Plan: $PLAN_BASENAME\nIteration: $ITERATION\nError: $error_type (after $claude_attempt retries)\nRepo: $REPO_NAME\`\`\`" ":x:"
        exit $claude_exit_code
    fi

    echo ""
    echo -e "${GREEN}Iteration $ITERATION complete${NC}"

    # Plan mode: exit after one iteration
    if [ "$MODE" = "plan" ]; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  Planning complete! Task list created in $PROGRESS_FILE${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "Next step: Run ${YELLOW}ralph $PLAN_FILE build${NC} to implement tasks"
        notify ":clipboard: *Ralph Planning Complete!*\n\`\`\`Plan: $PLAN_BASENAME\nTask list created in: $PROGRESS_FILE\nRepo: $REPO_NAME\`\`\`" ":clipboard:"
        break
    fi

    # Send iteration notification (configurable frequency via RALPH_NOTIFY_FREQUENCY)
    notify_default="${NOTIFY_FREQUENCY_DEFAULT:-5}"
    NOTIFY_FREQ="${RALPH_NOTIFY_FREQUENCY:-$notify_default}"
    # Validate notification frequency
    notify_min="${NOTIFY_FREQUENCY_MIN:-1}"
    notify_max="${NOTIFY_FREQUENCY_MAX:-100}"
    if ! validate_numeric "$NOTIFY_FREQ" "RALPH_NOTIFY_FREQUENCY" "$notify_min" "$notify_max"; then
        NOTIFY_FREQ="$notify_default"
        log_error "Invalid RALPH_NOTIFY_FREQUENCY, using default: $notify_default"
    fi
    if [ "$ITERATION" -eq 1 ] || [ $((ITERATION % NOTIFY_FREQ)) -eq 0 ]; then
        notify ":gear: *Ralph Progress*: Iteration $ITERATION completed\n\`Plan: $PLAN_BASENAME\`" ":gear:"
    fi

    # Small delay between iterations
    iter_delay="${ITERATION_DELAY:-2}"
    sleep "$iter_delay"
done

echo ""
echo "Total iterations: $ITERATION"
echo "Progress file: $PROGRESS_FILE"

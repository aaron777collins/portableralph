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

# Validate config file syntax before sourcing
validate_config() {
    local config_file="$1"
    if [ -f "$config_file" ] && ! bash -n "$config_file" 2>/dev/null; then
        echo -e "${YELLOW}Warning: Syntax error in $config_file${NC}" >&2
        echo -e "${YELLOW}Run: bash -n $config_file to see details${NC}" >&2
        return 1
    fi
    return 0
}

# Load configuration
if [ -f "$HOME/.ralph.env" ] && validate_config "$HOME/.ralph.env"; then
    source "$HOME/.ralph.env"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VERSION="1.5.0"

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

# Notification helper (sends to all configured platforms: Slack, Discord, Telegram)
notify() {
    local message="$1"
    "$RALPH_DIR/notify.sh" "$message" 2>/dev/null || true
}

# Check if any notification platform is configured
notifications_enabled() {
    [ -n "${RALPH_SLACK_WEBHOOK_URL:-}" ] || \
    [ -n "${RALPH_DISCORD_WEBHOOK_URL:-}" ] || \
    ([ -n "${RALPH_TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${RALPH_TELEGRAM_CHAT_ID:-}" ]) || \
    [ -n "${RALPH_CUSTOM_NOTIFY_SCRIPT:-}" ]
}

usage() {
    echo -e "${GREEN}PortableRalph${NC} v${VERSION} - Autonomous AI Development Loop"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ralph <plan-file> [mode] [max-iterations]"
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
    CONFIG_FILE="$HOME/.ralph.env"

    # Helper to set a config value (handles both export and non-export patterns)
    set_config_value() {
        local key="$1"
        local value="$2"
        if [ -f "$CONFIG_FILE" ]; then
            # Check if key exists (with or without export)
            if grep -qE "^(export )?${key}=" "$CONFIG_FILE" 2>/dev/null; then
                # Update existing (handle both patterns)
                sed -i "s/^export ${key}=.*/export ${key}=\"${value}\"/" "$CONFIG_FILE"
                sed -i "s/^${key}=.*/export ${key}=\"${value}\"/" "$CONFIG_FILE"
            else
                # Append to existing file (preserve content)
                echo "" >> "$CONFIG_FILE"
                echo "# Auto-commit setting" >> "$CONFIG_FILE"
                echo "export ${key}=\"${value}\"" >> "$CONFIG_FILE"
            fi
        else
            # Create new file
            echo '# PortableRalph Configuration' > "$CONFIG_FILE"
            echo "# Generated on $(date)" >> "$CONFIG_FILE"
            echo "" >> "$CONFIG_FILE"
            echo "export ${key}=\"${value}\"" >> "$CONFIG_FILE"
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
MAX_ITERATIONS="${3:-0}"

# Validate plan file exists
if [ ! -f "$PLAN_FILE" ]; then
    echo -e "${RED}Error: Plan file not found: $PLAN_FILE${NC}"
    exit 1
fi

# Validate mode
if [ "$MODE" != "plan" ] && [ "$MODE" != "build" ]; then
    echo -e "${RED}Error: Mode must be 'plan' or 'build', got: $MODE${NC}"
    usage
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

    # Build the prompt with substitutions
    PROMPT=$(cat "$PROMPT_TEMPLATE" | \
        sed "s|\${PLAN_FILE}|$PLAN_FILE_ABS|g" | \
        sed "s|\${PROGRESS_FILE}|$PROGRESS_FILE|g" | \
        sed "s|\${PLAN_NAME}|$PLAN_BASENAME|g" | \
        sed "s|\${AUTO_COMMIT}|$SHOULD_COMMIT|g")

    # Run Claude
    echo "$PROMPT" | claude -p \
        --dangerously-skip-permissions \
        --model sonnet \
        --verbose 2>&1 || {
            echo -e "${RED}Claude exited with error, continuing...${NC}"
        }

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

    # Send iteration notification (configurable frequency via RALPH_NOTIFY_FREQUENCY, default: every 5 iterations)
    NOTIFY_FREQ="${RALPH_NOTIFY_FREQUENCY:-5}"
    if [ "$ITERATION" -eq 1 ] || [ $((ITERATION % NOTIFY_FREQ)) -eq 0 ]; then
        notify ":gear: *Ralph Progress*: Iteration $ITERATION completed\n\`Plan: $PLAN_BASENAME\`" ":gear:"
    fi

    # Small delay between iterations
    sleep 2
done

echo ""
echo "Total iterations: $ITERATION"
echo "Progress file: $PROGRESS_FILE"

#!/bin/bash
# Ralph - Autonomous AI Development Loop
# Usage: ~/ralph/ralph.sh <plan-file> [plan|build] [max-iterations]
#
# Examples:
#   ~/ralph/ralph.sh ./my-feature-plan.md           # Build mode (default), runs until RALPH_DONE
#   ~/ralph/ralph.sh ./my-feature-plan.md plan      # Plan mode, generates implementation tasks
#   ~/ralph/ralph.sh ./my-feature-plan.md build 20  # Build mode, max 20 iterations
#
# Exit conditions:
#   - "RALPH_DONE" appears in progress file
#   - Max iterations reached (if specified)
#   - Ctrl+C
#
# Progress is tracked in: <plan-name>_PROGRESS.md (in current directory)

set -euo pipefail

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load notification configuration
if [ -f "$HOME/.ralph.env" ]; then
    source "$HOME/.ralph.env"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VERSION="1.4.0"

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
    echo "  ~/ralph/ralph.sh <plan-file> [mode] [max-iterations]"
    echo "  ~/ralph/ralph.sh --help | -h"
    echo "  ~/ralph/ralph.sh --version | -v"
    echo ""
    echo -e "${YELLOW}Arguments:${NC}"
    echo "  plan-file       Path to your plan/spec file (required)"
    echo "  mode            'plan' or 'build' (default: build)"
    echo "  max-iterations  Maximum loop iterations (default: unlimited)"
    echo ""
    echo -e "${YELLOW}Modes:${NC}"
    echo "  plan   Analyze codebase, create task list in progress file"
    echo "  build  Implement tasks one at a time until RALPH_DONE"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ~/ralph/ralph.sh ./feature.md              # Build until done"
    echo "  ~/ralph/ralph.sh ./feature.md plan         # Plan only"
    echo "  ~/ralph/ralph.sh ./feature.md build 20     # Build, max 20 iterations"
    echo "  ~/ralph/ralph.sh ./feature.md plan 5       # Plan, max 5 iterations"
    echo ""
    echo -e "${YELLOW}Exit Conditions:${NC}"
    echo "  - RALPH_DONE appears in <plan-name>_PROGRESS.md"
    echo "  - Max iterations reached (if specified)"
    echo "  - Ctrl+C"
    echo ""
    echo -e "${YELLOW}Progress File:${NC}"
    echo "  Created as <plan-name>_PROGRESS.md in current directory"
    echo "  This is the only artifact left in your repo"
    echo ""
    echo -e "${YELLOW}Notifications (optional):${NC}"
    echo "  Supports Slack, Discord, and Telegram"
    echo "  Run: ~/ralph/setup-notifications.sh to configure"
    echo "  Or set environment variables (see .env.example)"
    echo ""
    echo -e "${YELLOW}Test Notifications:${NC}"
    echo "  ~/ralph/ralph.sh --test-notify"
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

# Print banner
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  RALPH - Autonomous AI Development Loop${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Plan:      ${YELLOW}$PLAN_FILE${NC}"
echo -e "  Mode:      ${YELLOW}$MODE${NC}"
echo -e "  Progress:  ${YELLOW}$PROGRESS_FILE${NC}"
[ "$MAX_ITERATIONS" -gt 0 ] && echo -e "  Max Iter:  ${YELLOW}$MAX_ITERATIONS${NC}"
if notifications_enabled; then
    PLATFORMS=""
    [ -n "${RALPH_SLACK_WEBHOOK_URL:-}" ] && PLATFORMS="${PLATFORMS}Slack "
    [ -n "${RALPH_DISCORD_WEBHOOK_URL:-}" ] && PLATFORMS="${PLATFORMS}Discord "
    [ -n "${RALPH_TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${RALPH_TELEGRAM_CHAT_ID:-}" ] && PLATFORMS="${PLATFORMS}Telegram "
    [ -n "${RALPH_CUSTOM_NOTIFY_SCRIPT:-}" ] && PLATFORMS="${PLATFORMS}Custom "
    echo -e "  Notify:    ${GREEN}${PLATFORMS}${NC}"
else
    echo -e "  Notify:    ${YELLOW}disabled${NC} (run ~/ralph/setup-notifications.sh)"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Exit conditions:${NC}"
echo "  - Add 'RALPH_DONE' to $PROGRESS_FILE when complete"
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
is_done() {
    if [ -f "$PROGRESS_FILE" ]; then
        grep -q "RALPH_DONE" "$PROGRESS_FILE" 2>/dev/null && return 0
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
        sed "s|\${PLAN_NAME}|$PLAN_BASENAME|g")

    # Run Claude
    echo "$PROMPT" | claude -p \
        --dangerously-skip-permissions \
        --model sonnet \
        --verbose 2>&1 || {
            echo -e "${RED}Claude exited with error, continuing...${NC}"
        }

    echo ""
    echo -e "${GREEN}Iteration $ITERATION complete${NC}"

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

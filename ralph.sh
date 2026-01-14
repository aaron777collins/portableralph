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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <plan-file> [plan|build] [max-iterations]"
    echo ""
    echo "Arguments:"
    echo "  plan-file       Path to your plan/spec file (required)"
    echo "  mode            'plan' or 'build' (default: build)"
    echo "  max-iterations  Maximum loop iterations (default: unlimited)"
    echo ""
    echo "Examples:"
    echo "  $0 ./feature-spec.md              # Build until done"
    echo "  $0 ./feature-spec.md plan         # Plan only"
    echo "  $0 ./feature-spec.md build 50     # Build, max 50 iterations"
    exit 1
}

# Parse arguments
if [ $# -lt 1 ]; then
    usage
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
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Exit conditions:${NC}"
echo "  - Add 'RALPH_DONE' to $PROGRESS_FILE when complete"
echo "  - Press Ctrl+C to stop manually"
echo ""

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
        break
    fi

    if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$ITERATION" -ge "$MAX_ITERATIONS" ]; then
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  Max iterations reached: $MAX_ITERATIONS${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

    # Small delay between iterations
    sleep 2
done

echo ""
echo "Total iterations: $ITERATION"
echo "Progress file: $PROGRESS_FILE"

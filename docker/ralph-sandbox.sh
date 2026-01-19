#!/bin/bash
# ralph-sandbox.sh - Run Ralph in a Docker sandbox
#
# Usage:
#   ./docker/ralph-sandbox.sh /path/to/repo [feature-file] [mode|max-iter] [max-iter]
#
# Examples:
#   ./docker/ralph-sandbox.sh /path/to/my-repo
#   ./docker/ralph-sandbox.sh /path/to/my-repo my-feature.md
#   ./docker/ralph-sandbox.sh /path/to/my-repo feature.md 20
#   ./docker/ralph-sandbox.sh /path/to/my-repo feature.md plan
#   ANTHROPIC_API_KEY="sk-ant-..." ./docker/ralph-sandbox.sh /path/to/repo

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="ralph-sandbox"

usage() {
    echo -e "${GREEN}Ralph Docker Sandbox${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 <repo-path> [feature-file] [mode|max-iter] [max-iter]"
    echo ""
    echo -e "${YELLOW}Arguments:${NC}"
    echo "  repo-path      Path to the repository to work on (required)"
    echo "  feature-file   Feature/plan markdown file (default: feature.md or auto-detect)"
    echo "  mode           'plan' or 'build' (default: build)"
    echo "  max-iter       Maximum iterations (default: unlimited)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 /path/to/my-repo"
    echo "  $0 /path/to/my-repo my-feature.md"
    echo "  $0 /path/to/my-repo feature.md plan"
    echo "  $0 /path/to/my-repo feature.md build 20"
    echo ""
    echo -e "${YELLOW}Authentication:${NC}"
    echo "  API key (recommended): ANTHROPIC_API_KEY=\"sk-ant-...\" $0 /path/to/repo"
    echo "  Or run 'claude setup-token' first to create a file-based token."
    echo "  Note: Standard OAuth login uses system keychain, not accessible from Docker."
    echo ""
    echo -e "${YELLOW}Environment Variables:${NC}"
    echo "  ANTHROPIC_API_KEY    Use API key instead of OAuth"
    echo "  GIT_USER_NAME        Git user name for commits (default: Ralph Bot)"
    echo "  GIT_USER_EMAIL       Git user email for commits (default: ralph@localhost)"
    echo "  RALPH_AUTO_COMMIT    Enable/disable auto-commit (default: true)"
    echo ""
    exit 1
}

# Parse arguments
if [ $# -lt 1 ]; then
    usage
fi

REPO_PATH="$1"
FEATURE_FILE="${2:-}"
MODE_OR_ITER="${3:-}"
MAX_ITER="${4:-}"

# Handle the case where mode is provided as third arg
MODE="build"
if [ -n "$MODE_OR_ITER" ]; then
    if [ "$MODE_OR_ITER" = "plan" ] || [ "$MODE_OR_ITER" = "build" ]; then
        MODE="$MODE_OR_ITER"
    else
        # It's a number (max iterations)
        MAX_ITER="$MODE_OR_ITER"
    fi
fi

# Default max iterations if not set
MAX_ITER="${MAX_ITER:-0}"

# Validate repo path
if [ ! -d "$REPO_PATH" ]; then
    echo -e "${RED}Error: Repository path not found: $REPO_PATH${NC}"
    exit 1
fi

# Convert to absolute path
REPO_PATH="$(cd "$REPO_PATH" && pwd)"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Ralph Docker Sandbox Launcher${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Repository: ${YELLOW}$REPO_PATH${NC}"
[ -n "$FEATURE_FILE" ] && echo -e "  Feature:    ${YELLOW}$FEATURE_FILE${NC}"
echo -e "  Mode:       ${YELLOW}$MODE${NC}"
[ "$MAX_ITER" != "0" ] && echo -e "  Max iter:   ${YELLOW}$MAX_ITER${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Build image if it doesn't exist or if requested
if [ "${RALPH_REBUILD_IMAGE:-}" = "true" ] || ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo -e "${YELLOW}Building Ralph sandbox image...${NC}"
    docker build -t "$IMAGE_NAME" -f "$RALPH_ROOT/docker/Dockerfile" "$RALPH_ROOT"
    echo ""
fi

# Prepare docker run arguments
DOCKER_ARGS=(
    --rm
    -it
    --name "ralph-sandbox-$$"
    -v "$REPO_PATH:/workspace"
)

# Add git config as environment variables
DOCKER_ARGS+=(-e "GIT_USER_NAME=${GIT_USER_NAME:-Ralph Bot}")
DOCKER_ARGS+=(-e "GIT_USER_EMAIL=${GIT_USER_EMAIL:-ralph@localhost}")

# Pass through ralph config
[ -n "${RALPH_AUTO_COMMIT:-}" ] && DOCKER_ARGS+=(-e "RALPH_AUTO_COMMIT=$RALPH_AUTO_COMMIT")

# Pass through notification config if set
[ -n "${RALPH_SLACK_WEBHOOK_URL:-}" ] && DOCKER_ARGS+=(-e "RALPH_SLACK_WEBHOOK_URL=$RALPH_SLACK_WEBHOOK_URL")
[ -n "${RALPH_DISCORD_WEBHOOK_URL:-}" ] && DOCKER_ARGS+=(-e "RALPH_DISCORD_WEBHOOK_URL=$RALPH_DISCORD_WEBHOOK_URL")
[ -n "${RALPH_TELEGRAM_BOT_TOKEN:-}" ] && DOCKER_ARGS+=(-e "RALPH_TELEGRAM_BOT_TOKEN=$RALPH_TELEGRAM_BOT_TOKEN")
[ -n "${RALPH_TELEGRAM_CHAT_ID:-}" ] && DOCKER_ARGS+=(-e "RALPH_TELEGRAM_CHAT_ID=$RALPH_TELEGRAM_CHAT_ID")

# Handle authentication
# Priority: ANTHROPIC_API_KEY (pay-per-use) or CLAUDE_CODE_OAUTH_TOKEN (Max subscription)
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo -e "${GREEN}Using API key authentication (pay-per-use)${NC}"
    DOCKER_ARGS+=(-e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
elif [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo -e "${GREEN}Using OAuth token (Max subscription)${NC}"
    DOCKER_ARGS+=(-e "CLAUDE_CODE_OAUTH_TOKEN=$CLAUDE_CODE_OAUTH_TOKEN")
else
    echo -e "${RED}Error: Authentication required${NC}"
    echo ""
    echo "Provide one of these environment variables:"
    echo ""
    echo "  ${YELLOW}For Max subscription (recommended):${NC}"
    echo "    1. Run: claude setup-token"
    echo "    2. Copy the token it outputs"
    echo "    3. CLAUDE_CODE_OAUTH_TOKEN=\"sk-ant-oat01-...\" $0 $REPO_PATH"
    echo ""
    echo "  ${YELLOW}For API pay-per-use:${NC}"
    echo "    ANTHROPIC_API_KEY=\"sk-ant-api03-...\" $0 $REPO_PATH"
    echo ""
    exit 1
fi

echo ""

# Build container arguments (feature file, mode, max-iter)
# Always pass all 3 args - use empty string for auto-detect feature file
CONTAINER_ARGS=("${FEATURE_FILE:-}" "$MODE" "$MAX_ITER")

# Run the container
echo -e "${GREEN}Starting Ralph sandbox...${NC}"
echo ""

exec docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" "${CONTAINER_ARGS[@]}"

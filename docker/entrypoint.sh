#!/bin/bash
# Ralph Docker entrypoint script
# Configures environment and runs ralph

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Ralph Docker Sandbox${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Configure git user for commits (use env vars or defaults)
GIT_USER_NAME="${GIT_USER_NAME:-Ralph Bot}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-ralph@localhost}"

git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global --add safe.directory /workspace

echo -e "  Git user:  ${YELLOW}$GIT_USER_NAME <$GIT_USER_EMAIL>${NC}"

# Check authentication
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo -e "  Auth:      ${GREEN}API Key (pay-per-use)${NC}"
elif [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo -e "  Auth:      ${GREEN}OAuth Token (Max subscription)${NC}"
else
    echo -e "  Auth:      ${RED}NOT CONFIGURED${NC}"
    echo ""
    echo -e "${RED}Error: Authentication required!${NC}"
    echo ""
    echo "Use CLAUDE_CODE_OAUTH_TOKEN for Max subscription:"
    echo "  1. Run: claude setup-token"
    echo "  2. CLAUDE_CODE_OAUTH_TOKEN=\"sk-ant-oat01-...\" ./docker/ralph-sandbox.sh /path/to/repo"
    echo ""
    echo "Or ANTHROPIC_API_KEY for pay-per-use API access."
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if workspace has content
if [ ! "$(ls -A /workspace 2>/dev/null)" ]; then
    echo -e "${RED}Error: /workspace is empty!${NC}"
    echo "Did you mount a repository? Use:"
    echo "  ./docker/ralph-sandbox.sh /path/to/your/repo"
    exit 1
fi

# Determine feature file, mode, and max iterations
FEATURE_FILE="${1:-}"
MODE="${2:-build}"
MAX_ITER="${3:-0}"

# Validate mode
if [ "$MODE" != "plan" ] && [ "$MODE" != "build" ]; then
    echo -e "${RED}Error: Mode must be 'plan' or 'build', got: $MODE${NC}"
    exit 1
fi

# If no feature file specified, try to find one
if [ -z "$FEATURE_FILE" ]; then
    if [ -f "/workspace/feature.md" ]; then
        FEATURE_FILE="feature.md"
    else
        # Look for any .md file in workspace root (excluding common non-feature files)
        FEATURE_FILE=$(find /workspace -maxdepth 1 -name "*.md" \
            ! -name "README.md" \
            ! -name "CHANGELOG.md" \
            ! -name "CONTRIBUTING.md" \
            ! -name "LICENSE.md" \
            ! -name "*_PROGRESS.md" \
            -type f -print -quit 2>/dev/null | xargs -r basename)
    fi
fi

if [ -z "$FEATURE_FILE" ]; then
    echo -e "${RED}Error: No feature file found!${NC}"
    echo ""
    echo "Please specify a feature file:"
    echo "  ./docker/ralph-sandbox.sh /path/to/repo my-feature.md"
    echo ""
    echo "Or create a feature.md in your repo root."
    exit 1
fi

echo -e "Feature file: ${YELLOW}$FEATURE_FILE${NC}"
echo -e "Mode:         ${YELLOW}$MODE${NC}"
[ "$MAX_ITER" != "0" ] && echo -e "Max iterations: ${YELLOW}$MAX_ITER${NC}"
echo ""

# Run ralph
cd /workspace
exec /opt/ralph/ralph.sh "$FEATURE_FILE" "$MODE" "$MAX_ITER"

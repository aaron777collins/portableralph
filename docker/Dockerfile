# Ralph Docker Sandbox
# Runs Ralph in an isolated container to protect your host system
#
# Build: docker build -t ralph-sandbox -f docker/Dockerfile .
# Run via: ./docker/ralph-sandbox.sh /path/to/repo

FROM node:20-slim

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    bash \
    curl \
    ca-certificates \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create ralph directory and copy scripts
RUN mkdir -p /opt/ralph
COPY ralph.sh notify.sh update.sh setup-notifications.sh /opt/ralph/
COPY PROMPT_build.md PROMPT_plan.md /opt/ralph/
COPY docker/entrypoint.sh /opt/ralph/entrypoint.sh

# Make scripts executable
RUN chmod +x /opt/ralph/*.sh

# Use existing 'node' user (UID 1000) for security
# Create directories for Claude config (will be mounted read-only)
RUN mkdir -p /home/node/.claude /home/node/.config/claude \
    && chown -R node:node /home/node

# Switch to non-root user
USER node

# Set working directory (will be mounted with target repo)
WORKDIR /workspace

# Set ralph scripts in PATH
ENV PATH="/opt/ralph:${PATH}"
ENV RALPH_DIR="/opt/ralph"

# Default entrypoint
ENTRYPOINT ["/opt/ralph/entrypoint.sh"]

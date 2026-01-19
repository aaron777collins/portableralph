# Ralph Docker Sandbox

Run Ralph in an isolated Docker container to protect your host system from destructive commands.

## Quick Start

```bash
# Run ralph on a repository (uses your existing Claude login)
./docker/ralph-sandbox.sh /path/to/my-repo

# Specify a feature file
./docker/ralph-sandbox.sh /path/to/my-repo my-feature.md

# Plan mode only (creates task list, doesn't implement)
./docker/ralph-sandbox.sh /path/to/my-repo feature.md plan

# Limit iterations
./docker/ralph-sandbox.sh /path/to/my-repo feature.md build 20
```

## Authentication

Docker containers cannot access the system keychain. Use one of these methods:

### Option 1: Max Subscription (Recommended)

Use your existing Claude Max subscription with an OAuth token:

```bash
# First, generate a token (one-time setup)
claude setup-token

# Copy the token it outputs, then run:
CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..." ./docker/ralph-sandbox.sh /path/to/repo
```

### Option 2: API Key (Pay-per-use)

Use an API key from the Anthropic Console (billed separately):

```bash
ANTHROPIC_API_KEY="sk-ant-api03-..." ./docker/ralph-sandbox.sh /path/to/repo
```

Get an API key from: https://console.anthropic.com/

## Security Model

| Aspect | Configuration |
|--------|---------------|
| User | Non-root `node` user (UID 1000) |
| Network | Full access (required for Claude API) |
| Filesystem | Only mounted repo is writable |
| Credentials | Read-only mount |
| Cleanup | Container removed after exit (`--rm`) |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ANTHROPIC_API_KEY` | Use API key instead of OAuth | (uses OAuth) |
| `GIT_USER_NAME` | Git user name for commits | Ralph Bot |
| `GIT_USER_EMAIL` | Git email for commits | ralph@localhost |
| `RALPH_AUTO_COMMIT` | Enable/disable auto-commit | true |
| `RALPH_REBUILD_IMAGE` | Force rebuild Docker image | false |
| `RALPH_SLACK_WEBHOOK_URL` | Slack notifications | - |
| `RALPH_DISCORD_WEBHOOK_URL` | Discord notifications | - |
| `RALPH_TELEGRAM_BOT_TOKEN` | Telegram bot token | - |
| `RALPH_TELEGRAM_CHAT_ID` | Telegram chat ID | - |

## Using Docker Compose

For users who prefer docker-compose:

```bash
# Set the repo path and run
REPO_PATH=/path/to/my-repo docker-compose -f docker/docker-compose.yml up

# With custom arguments
REPO_PATH=/path/to/my-repo FEATURE_FILE=my-plan.md MODE=plan \
  docker-compose -f docker/docker-compose.yml up

# Run specific command
docker-compose -f docker/docker-compose.yml run ralph feature.md build 10
```

## Building the Image Manually

```bash
# From the portableralph root directory
docker build -t ralph-sandbox -f docker/Dockerfile .

# Force rebuild
RALPH_REBUILD_IMAGE=true ./docker/ralph-sandbox.sh /path/to/repo
```

## How It Works

1. **ralph-sandbox.sh** (host-side script):
   - Validates arguments and paths
   - Builds the Docker image if needed
   - Detects your OS and mounts appropriate credential paths
   - Runs the container with your repo mounted at `/workspace`

2. **entrypoint.sh** (inside container):
   - Configures git for commits
   - Validates authentication
   - Finds or validates the feature file
   - Executes ralph.sh with provided arguments

3. **ralph.sh** (inside container):
   - Normal ralph execution loop
   - All changes are made to `/workspace` (your mounted repo)
   - Any destructive commands only affect the container filesystem

## Troubleshooting

### "No authentication found"

Make sure you're logged into Claude Code on your host:
```bash
claude login
```

Or provide an API key:
```bash
ANTHROPIC_API_KEY="sk-ant-..." ./docker/ralph-sandbox.sh /path/to/repo
```

### "Permission denied" on repo files

The container runs as UID 1000. If your files have different ownership:
```bash
# Check your UID
id -u

# If not 1000, you may need to adjust file permissions
chmod -R a+rw /path/to/repo
```

### Container keeps rebuilding

The image is cached after first build. To force rebuild:
```bash
RALPH_REBUILD_IMAGE=true ./docker/ralph-sandbox.sh /path/to/repo
```

### Feature file not found

Ensure your feature file:
1. Exists in the repo root
2. Has a `.md` extension
3. Is not named README.md, CHANGELOG.md, etc.

Or specify it explicitly:
```bash
./docker/ralph-sandbox.sh /path/to/repo my-feature.md
```

# Notifications

Get notified when Ralph starts, progresses, and completes work.

## Overview

Ralph supports four notification channels:

| Platform | Setup Time | Best For |
|:---------|:-----------|:---------|
| **Slack** | ~2 min | Team channels |
| **Discord** | ~1 min | Personal/community servers |
| **Telegram** | ~3 min | Mobile notifications |
| **Custom** | Varies | Proprietary systems |

Notifications fire when:

- Run **starts**
- Every **5 iterations** (progress)
- Work **completes** (RALPH_DONE)
- **Max iterations** reached

## Quick Setup

Run the interactive wizard:

```bash
~/ralph/setup-notifications.sh
```

Test your configuration:

```bash
~/ralph/ralph.sh --test-notify
```

## Platform Setup

### Slack

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. **Create New App** → **From scratch**
3. Name it "Ralph", select your workspace
4. Navigate to **Incoming Webhooks**
5. Toggle **Activate Incoming Webhooks** ON
6. Click **Add New Webhook to Workspace**
7. Select your channel → **Allow**
8. Copy the webhook URL

```bash
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00/B00/xxxx"
```

**Optional:**

```bash
export RALPH_SLACK_CHANNEL="#dev-alerts"
export RALPH_SLACK_USERNAME="Ralph Bot"
export RALPH_SLACK_ICON_EMOJI=":robot_face:"
```

### Discord

1. Open your Discord server
2. Right-click channel → **Edit Channel**
3. **Integrations** → **Webhooks**
4. **New Webhook** → Name it "Ralph"
5. **Copy Webhook URL**

```bash
export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxx/yyy"
```

**Optional:**

```bash
export RALPH_DISCORD_USERNAME="Ralph"
export RALPH_DISCORD_AVATAR_URL="https://example.com/avatar.png"
```

### Telegram

**Step 1: Create a bot**

1. Open Telegram, find [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Follow prompts to name your bot
4. Copy the token (format: `123456789:ABCdefGHI...`)

**Step 2: Get chat ID**

1. Start a chat with your new bot
2. Send any message
3. Visit: `https://api.telegram.org/bot<TOKEN>/getUpdates`
4. Find `"chat":{"id":YOUR_ID}` in the response

!!! note
    Group chat IDs are negative numbers (e.g., `-123456789`)

```bash
export RALPH_TELEGRAM_BOT_TOKEN="123456789:ABCdefGHI..."
export RALPH_TELEGRAM_CHAT_ID="987654321"
```

### Custom Script

For proprietary integrations—database bridges, internal APIs, SMS gateways.

Your script receives the message as `$1`:

```bash
#!/bin/bash
# my-notify.sh
MESSAGE="$1"

# Post to internal API
curl -X POST -d "text=$MESSAGE" https://internal.company.com/notify

# Or insert into database
docker exec db psql -c "INSERT INTO alerts (msg) VALUES ('$MESSAGE');"
```

```bash
export RALPH_CUSTOM_NOTIFY_SCRIPT="/path/to/my-notify.sh"
```

!!! warning "Important"
    Script must be executable (`chmod +x`). Exit code is ignored.

## Configuration Reference

| Variable | Platform | Description |
|:---------|:---------|:------------|
| `RALPH_SLACK_WEBHOOK_URL` | Slack | Webhook URL |
| `RALPH_SLACK_CHANNEL` | Slack | Override channel |
| `RALPH_SLACK_USERNAME` | Slack | Bot name |
| `RALPH_SLACK_ICON_EMOJI` | Slack | Bot icon |
| `RALPH_DISCORD_WEBHOOK_URL` | Discord | Webhook URL |
| `RALPH_DISCORD_USERNAME` | Discord | Bot name |
| `RALPH_DISCORD_AVATAR_URL` | Discord | Avatar image URL |
| `RALPH_TELEGRAM_BOT_TOKEN` | Telegram | Bot token |
| `RALPH_TELEGRAM_CHAT_ID` | Telegram | Target chat ID |
| `RALPH_CUSTOM_NOTIFY_SCRIPT` | Custom | Path to script |

## Persisting Configuration

The wizard saves to `~/.ralph.env`. Load automatically:

```bash
echo 'source ~/.ralph.env' >> ~/.bashrc
source ~/.bashrc
```

## Multiple Platforms

Configure as many as you want—Ralph sends to **all** configured channels:

```bash
export RALPH_SLACK_WEBHOOK_URL="https://..."
export RALPH_DISCORD_WEBHOOK_URL="https://..."
export RALPH_TELEGRAM_BOT_TOKEN="..."
export RALPH_TELEGRAM_CHAT_ID="..."
```

## Message Format

```
🚀 Ralph Started
Plan: auth-feature
Mode: build
Repo: my-project

⚙️ Ralph Progress: Iteration 5 completed
Plan: auth-feature

✅ Ralph Complete!
Plan: auth-feature
Iterations: 12
Repo: my-project
```

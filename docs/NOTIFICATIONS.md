# Notifications

Get notified when Ralph starts, progresses, and completes work.

## Overview

Ralph supports four notification channels:

| Platform | Setup Difficulty | Best For |
|----------|-----------------|----------|
| **Slack** | Easy | Team channels |
| **Discord** | Easy | Personal/community servers |
| **Telegram** | Medium | Mobile notifications |
| **Custom** | Varies | Proprietary systems |

Notifications are sent:
- When a run **starts**
- Every **5 iterations** (progress update)
- When work **completes** (RALPH_DONE)
- When **max iterations** reached

## Quick Setup

Run the interactive wizard:

```bash
~/ralph/setup-notifications.sh
```

The wizard walks you through configuring any or all platforms.

## Testing

Verify your setup:

```bash
~/ralph/ralph.sh --test-notify
```

---

## Platform Setup

### Slack

**Time:** ~2 minutes

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App** → **From scratch**
3. Name it "Ralph", select your workspace
4. Navigate to **Incoming Webhooks** in sidebar
5. Toggle **Activate Incoming Webhooks** to ON
6. Click **Add New Webhook to Workspace**
7. Select your channel, click **Allow**
8. Copy the webhook URL

```bash
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00/B00/xxxx"
```

**Optional settings:**

```bash
export RALPH_SLACK_CHANNEL="#dev-alerts"      # Override channel
export RALPH_SLACK_USERNAME="Ralph Bot"       # Custom bot name
export RALPH_SLACK_ICON_EMOJI=":robot_face:"  # Custom icon
```

---

### Discord

**Time:** ~1 minute

1. Open your Discord server
2. Right-click target channel → **Edit Channel**
3. Go to **Integrations** → **Webhooks**
4. Click **New Webhook**
5. Name it "Ralph", click **Copy Webhook URL**

```bash
export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxx/yyy"
```

**Optional settings:**

```bash
export RALPH_DISCORD_USERNAME="Ralph"         # Bot display name
export RALPH_DISCORD_AVATAR_URL="https://..."  # Custom avatar
```

---

### Telegram

**Time:** ~3 minutes

**Step 1: Create a bot**

1. Open Telegram, search for [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Follow prompts to name your bot
4. Copy the bot token (format: `123456789:ABCdefGHI...`)

**Step 2: Get your chat ID**

1. Start a chat with your new bot
2. Send any message to it
3. Open in browser: `https://api.telegram.org/bot<TOKEN>/getUpdates`
4. Find `"chat":{"id":YOUR_CHAT_ID}` in the response

> **Tip:** Group chat IDs are negative numbers (e.g., `-123456789`)

```bash
export RALPH_TELEGRAM_BOT_TOKEN="123456789:ABCdefGHI..."
export RALPH_TELEGRAM_CHAT_ID="987654321"
```

---

### Custom Script

For proprietary integrations—database bridges, internal APIs, SMS gateways, etc.

Your script receives the notification message as `$1`:

```bash
#!/bin/bash
# my-notify.sh
MESSAGE="$1"

# Example: Post to internal API
curl -X POST -d "text=$MESSAGE" https://internal.company.com/notify

# Example: Insert into database
docker exec db psql -c "INSERT INTO alerts (msg) VALUES ('$MESSAGE');"

# Example: Send SMS via Twilio
curl -X POST "https://api.twilio.com/..." -d "Body=$MESSAGE"
```

Configure:

```bash
export RALPH_CUSTOM_NOTIFY_SCRIPT="/path/to/my-notify.sh"
```

**Requirements:**
- Script must be executable (`chmod +x`)
- Script receives message as first argument (`$1`)
- Exit code is ignored (notifications don't block Ralph)

---

## Configuration Reference

| Variable | Platform | Required | Description |
|----------|----------|----------|-------------|
| `RALPH_SLACK_WEBHOOK_URL` | Slack | Yes | Webhook URL |
| `RALPH_SLACK_CHANNEL` | Slack | No | Override channel |
| `RALPH_SLACK_USERNAME` | Slack | No | Bot name (default: Ralph) |
| `RALPH_SLACK_ICON_EMOJI` | Slack | No | Bot icon (default: :robot_face:) |
| `RALPH_DISCORD_WEBHOOK_URL` | Discord | Yes | Webhook URL |
| `RALPH_DISCORD_USERNAME` | Discord | No | Bot name (default: Ralph) |
| `RALPH_DISCORD_AVATAR_URL` | Discord | No | Avatar image URL |
| `RALPH_TELEGRAM_BOT_TOKEN` | Telegram | Yes | Bot token from @BotFather |
| `RALPH_TELEGRAM_CHAT_ID` | Telegram | Yes | Target chat ID |
| `RALPH_CUSTOM_NOTIFY_SCRIPT` | Custom | Yes | Path to script |

## Persisting Configuration

The setup wizard saves to `~/.ralph.env`. To load automatically:

```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'source ~/.ralph.env' >> ~/.bashrc
source ~/.bashrc
```

## Multiple Platforms

Configure as many platforms as you want—Ralph sends to **all** configured channels simultaneously.

```bash
# All three will receive notifications
export RALPH_SLACK_WEBHOOK_URL="https://..."
export RALPH_DISCORD_WEBHOOK_URL="https://..."
export RALPH_TELEGRAM_BOT_TOKEN="..."
export RALPH_TELEGRAM_CHAT_ID="..."
```

## Notification Format

Messages include context about the run:

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

---

Next: [How It Works](./HOW-IT-WORKS.md) | [Writing Plans](./WRITING-PLANS.md)

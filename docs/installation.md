# Installation

Get PortableRalph up and running in under a minute.

## One-Liner Install

The fastest way to get started:

```bash
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
```

This will:

1. Clone PortableRalph to `~/ralph`
2. Set up the `ralph` alias in your shell
3. Optionally configure notifications

## Manual Installation

If you prefer manual setup:

```bash
# Clone the repository
git clone https://github.com/aaron777collins/portableralph.git ~/ralph

# Make scripts executable
chmod +x ~/ralph/*.sh

# Add alias to your shell
echo 'alias ralph="~/ralph/ralph.sh"' >> ~/.bashrc
source ~/.bashrc
```

## Headless Installation

For CI/CD or automated setups, use command-line flags:

```bash
# Install with Slack notifications
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | \
  bash -s -- --headless --slack-webhook "https://hooks.slack.com/services/xxx"

# Install with Discord
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | \
  bash -s -- --headless --discord-webhook "https://discord.com/api/webhooks/xxx"

# Install with custom script
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | \
  bash -s -- --headless --custom-script "/path/to/notify.sh"
```

### Headless Flags

| Flag | Description |
|:-----|:------------|
| `--headless` | Non-interactive mode |
| `--slack-webhook URL` | Configure Slack webhook |
| `--discord-webhook URL` | Configure Discord webhook |
| `--telegram-token TOKEN` | Configure Telegram bot token |
| `--telegram-chat ID` | Configure Telegram chat ID |
| `--custom-script PATH` | Configure custom notification script |

## Requirements

Before installing, make sure you have:

| Requirement | Description |
|:------------|:------------|
| **Claude Code CLI** | [Install from Anthropic](https://platform.claude.com/docs/en/get-started) |
| **Bash** | Most Unix systems have this |
| **Git** | For auto-commits (optional) |
| **curl** | For notifications (optional) |

### Verify Claude CLI

```bash
claude --version
```

If this doesn't work, install Claude Code first.

## Post-Installation

### Verify Installation

```bash
ralph --version
```

### Set Up Notifications (Optional)

```bash
~/ralph/setup-notifications.sh
```

### Test Notifications

```bash
ralph --test-notify
```

## Upgrading

To upgrade to the latest version:

```bash
cd ~/ralph && git pull
```

## Uninstalling

To remove PortableRalph:

```bash
# Remove the directory
rm -rf ~/ralph

# Remove the alias from your shell config
# Edit ~/.bashrc or ~/.zshrc and remove the ralph alias line

# Remove config file (optional)
rm ~/.ralph.env
```

# setup-notifications.ps1 - Interactive setup wizard for Ralph notifications
# PowerShell version for Windows support
# Supports: Slack, Discord, Telegram, and Custom scripts
#
# Usage: .\setup-notifications.ps1
#
# This wizard will:
# 1. Ask which platforms you want to configure
# 2. Guide you through getting the credentials for each
# 3. Save configuration to ~/.ralph.env
# 4. Test the notifications

param()

$ErrorActionPreference = "Stop"

$RALPH_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load validation library
$ValidationLib = Join-Path $RALPH_DIR "lib\validation.ps1"
if (Test-Path $ValidationLib) {
    . $ValidationLib
}

$CONFIG_FILE = Join-Path $env:USERPROFILE ".ralph.env"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "  Ralph Notifications Setup Wizard" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host ""
Write-Host "This wizard will help you configure notifications for Ralph."
Write-Host "Your settings will be saved to: " -NoNewline
Write-Host $CONFIG_FILE -ForegroundColor Cyan
Write-Host ""

# Load existing config if present
if (Test-Path $CONFIG_FILE) {
    Write-Host "Existing configuration found." -ForegroundColor Yellow
    $reconfigure = Read-Host "Do you want to reconfigure? (y/N)"
    if ($reconfigure -notmatch '^[Yy]') {
        Write-Host "Keeping existing configuration."
        Write-Host ""
        Write-Host "To test notifications, run:"
        Write-Host "  .\ralph.ps1 notify test" -ForegroundColor Cyan
        exit 0
    }
    Write-Host ""
}

# Initialize config variables
$SLACK_URL = ""
$DISCORD_URL = ""
$TELEGRAM_TOKEN = ""
$TELEGRAM_CHAT = ""
$EMAIL_TO = ""
$EMAIL_FROM = ""
$SMTP_SERVER = ""
$SMTP_PORT = ""
$SMTP_USER = ""
$SMTP_PASS = ""
$CUSTOM_SCRIPT = ""

# ============================================
# PLATFORM SELECTION
# ============================================
Write-Host "Which platforms do you want to configure?" -ForegroundColor White
Write-Host ""
Write-Host "  1) Slack"
Write-Host "  2) Discord"
Write-Host "  3) Telegram"
Write-Host "  4) Email (SMTP)"
Write-Host "  5) Custom script (for proprietary integrations)"
Write-Host "  6) All standard platforms (1-4)"
Write-Host "  7) Cancel"
Write-Host ""
$PLATFORM_CHOICE = Read-Host "Enter your choice (1-7)"

$SETUP_SLACK = $false
$SETUP_DISCORD = $false
$SETUP_TELEGRAM = $false
$SETUP_EMAIL = $false
$SETUP_CUSTOM = $false

switch ($PLATFORM_CHOICE) {
    "1" { $SETUP_SLACK = $true }
    "2" { $SETUP_DISCORD = $true }
    "3" { $SETUP_TELEGRAM = $true }
    "4" { $SETUP_EMAIL = $true }
    "5" { $SETUP_CUSTOM = $true }
    "6" { $SETUP_SLACK = $true; $SETUP_DISCORD = $true; $SETUP_TELEGRAM = $true; $SETUP_EMAIL = $true }
    "7" { Write-Host "Setup cancelled."; exit 0 }
    default { Write-Host "Invalid choice. Exiting." -ForegroundColor Red; exit 1 }
}

# ============================================
# SLACK SETUP
# ============================================
if ($SETUP_SLACK) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "Slack Setup" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    Write-Host "To get a Slack webhook URL:"
    Write-Host ""
    Write-Host "  1. Go to: " -NoNewline
    Write-Host "https://api.slack.com/apps" -ForegroundColor Cyan
    Write-Host "  2. Click 'Create New App' > 'From scratch'"
    Write-Host "  3. Name it 'Ralph' and select your workspace"
    Write-Host "  4. Go to 'Incoming Webhooks' in the sidebar"
    Write-Host "  5. Toggle 'Activate Incoming Webhooks' ON"
    Write-Host "  6. Click 'Add New Webhook to Workspace'"
    Write-Host "  7. Select the channel and click 'Allow'"
    Write-Host "  8. Copy the webhook URL"
    Write-Host ""
    $SLACK_URL = Read-Host "Paste your Slack webhook URL (or press Enter to skip)"

    if ($SLACK_URL) {
        Write-Host "Slack webhook configured." -ForegroundColor Green
    } else {
        Write-Host "Slack skipped." -ForegroundColor Yellow
    }
}

# ============================================
# DISCORD SETUP
# ============================================
if ($SETUP_DISCORD) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "Discord Setup" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    Write-Host "To get a Discord webhook URL:"
    Write-Host ""
    Write-Host "  1. Open your Discord server"
    Write-Host "  2. Right-click the channel > 'Edit Channel'"
    Write-Host "  3. Go to 'Integrations' > 'Webhooks'"
    Write-Host "  4. Click 'New Webhook'"
    Write-Host "  5. Name it 'Ralph' and click 'Copy Webhook URL'"
    Write-Host ""
    $DISCORD_URL = Read-Host "Paste your Discord webhook URL (or press Enter to skip)"

    if ($DISCORD_URL) {
        Write-Host "Discord webhook configured." -ForegroundColor Green
    } else {
        Write-Host "Discord skipped." -ForegroundColor Yellow
    }
}

# ============================================
# TELEGRAM SETUP
# ============================================
if ($SETUP_TELEGRAM) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "Telegram Setup" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    Write-Host "To set up Telegram notifications:"
    Write-Host ""
    Write-Host "  Step 1: Create a bot" -ForegroundColor White
    Write-Host "  1. Open Telegram and search for @BotFather"
    Write-Host "  2. Send /newbot and follow the prompts"
    Write-Host "  3. Copy the bot token (looks like: 123456789:ABCdefGHI...)"
    Write-Host ""
    $TELEGRAM_TOKEN = Read-Host "Paste your bot token (or press Enter to skip)"

    if ($TELEGRAM_TOKEN) {
        Write-Host ""
        Write-Host "  Step 2: Get your chat ID" -ForegroundColor White
        Write-Host "  1. Start a chat with your new bot (search for it and click Start)"
        Write-Host "  2. Send any message to the bot"
        Write-Host "  3. Visit this URL in your browser:"
        Write-Host "     https://api.telegram.org/bot$TELEGRAM_TOKEN/getUpdates" -ForegroundColor Cyan
        Write-Host "  4. Look for `"chat`":{`"id`":YOUR_CHAT_ID}"
        Write-Host ""
        Write-Host "  For group chats: Add the bot to the group, send a message,"
        Write-Host "  then check getUpdates. Group IDs are negative numbers."
        Write-Host ""
        $TELEGRAM_CHAT = Read-Host "Paste your chat ID"

        if ($TELEGRAM_CHAT) {
            Write-Host "Telegram configured." -ForegroundColor Green
        } else {
            Write-Host "Telegram skipped (no chat ID)." -ForegroundColor Yellow
            $TELEGRAM_TOKEN = ""
        }
    } else {
        Write-Host "Telegram skipped." -ForegroundColor Yellow
    }
}

# ============================================
# EMAIL SETUP
# ============================================
if ($SETUP_EMAIL) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "Email Setup" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Configure email notifications via SMTP."
    Write-Host ""

    # Get basic email info
    $EMAIL_TO = Read-Host "Recipient email address (To)"

    if ($EMAIL_TO) {
        $EMAIL_FROM = Read-Host "Sender email address (From)"

        if ($EMAIL_FROM) {
            Write-Host ""
            Write-Host "SMTP Configuration" -ForegroundColor White
            Write-Host ""
            Write-Host "Common SMTP servers:"
            Write-Host "  Gmail: smtp.gmail.com (port 587)"
            Write-Host "  Outlook: smtp-mail.outlook.com (port 587)"
            Write-Host "  Yahoo: smtp.mail.yahoo.com (port 587)"
            Write-Host ""
            $SMTP_SERVER = Read-Host "SMTP server hostname"
            $SMTP_PORT = Read-Host "SMTP port (default 587)"
            if (-not $SMTP_PORT) { $SMTP_PORT = "587" }
            $SMTP_USER = Read-Host "SMTP username"
            $SMTP_PASS = Read-Host "SMTP password" -AsSecureString
            $SMTP_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SMTP_PASS))

            if ($SMTP_SERVER -and $SMTP_USER -and $SMTP_PASS) {
                Write-Host ""
                Write-Host "Email configured." -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host "Email skipped (incomplete SMTP configuration)." -ForegroundColor Yellow
                $EMAIL_TO = ""
                $EMAIL_FROM = ""
            }
        } else {
            Write-Host "Email skipped (no sender address)." -ForegroundColor Yellow
            $EMAIL_TO = ""
        }
    } else {
        Write-Host "Email skipped (no recipient address)." -ForegroundColor Yellow
    }
}

# ============================================
# CUSTOM SCRIPT SETUP
# ============================================
if ($SETUP_CUSTOM) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "Custom Script Setup" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Custom scripts let you integrate with proprietary systems."
    Write-Host "Your script receives the notification message as `$1 (or `$args[0] in PowerShell)."
    Write-Host ""
    Write-Host "How it works:" -ForegroundColor White
    Write-Host "  1. Create a script that accepts a message argument"
    Write-Host "  2. Your script handles delivery (API call, database insert, etc.)"
    Write-Host "  3. Ralph calls your script for each notification"
    Write-Host ""
    Write-Host "Example script (my-notify.ps1):" -ForegroundColor White
    Write-Host "  param([string]`$Message)" -ForegroundColor Cyan
    Write-Host "  Invoke-RestMethod -Uri 'https://your.api/notify' -Method Post -Body @{text=`$Message}" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Use cases:" -ForegroundColor White
    Write-Host "  - Database-to-Slack bridge"
    Write-Host "  - Internal company notification API"
    Write-Host "  - SMS or email gateway"
    Write-Host "  - Custom webhook format"
    Write-Host ""
    $CUSTOM_SCRIPT = Read-Host "Path to your notification script (or press Enter to skip)"

    if ($CUSTOM_SCRIPT) {
        # Expand ~ to home directory (PowerShell style)
        $CUSTOM_SCRIPT = $CUSTOM_SCRIPT -replace '^~', $env:USERPROFILE

        if (Test-Path $CUSTOM_SCRIPT) {
            Write-Host "Custom script configured: $CUSTOM_SCRIPT" -ForegroundColor Green
        } else {
            Write-Host "Warning: Script not found at $CUSTOM_SCRIPT" -ForegroundColor Yellow
            Write-Host "Make sure the script exists before running Ralph."
        }
    } else {
        Write-Host "Custom script skipped." -ForegroundColor Yellow
    }
}

# ============================================
# SAVE CONFIGURATION
# ============================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "Saving Configuration" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host ""

# Check if anything was configured
if (-not $SLACK_URL -and -not $DISCORD_URL -and -not $TELEGRAM_TOKEN -and -not $EMAIL_TO -and -not $CUSTOM_SCRIPT) {
    Write-Host "No platforms were configured." -ForegroundColor Yellow
    Write-Host "Run this wizard again when you're ready."
    exit 0
}

# Write config file
$configContent = @"
# Ralph Notification Configuration
# Generated by setup-notifications.ps1 on $(Get-Date)
# Load this file: . `"$CONFIG_FILE`"

"@

if ($SLACK_URL) {
    $configContent += @"
# Slack
export RALPH_SLACK_WEBHOOK_URL="$SLACK_URL"

"@
}

if ($DISCORD_URL) {
    $configContent += @"
# Discord
export RALPH_DISCORD_WEBHOOK_URL="$DISCORD_URL"

"@
}

if ($TELEGRAM_TOKEN) {
    $configContent += @"
# Telegram
export RALPH_TELEGRAM_BOT_TOKEN="$TELEGRAM_TOKEN"
export RALPH_TELEGRAM_CHAT_ID="$TELEGRAM_CHAT"

"@
}

if ($EMAIL_TO) {
    $configContent += @"
# Email
export RALPH_EMAIL_TO="$EMAIL_TO"
export RALPH_EMAIL_FROM="$EMAIL_FROM"
export RALPH_EMAIL_SMTP_SERVER="$SMTP_SERVER"
export RALPH_EMAIL_PORT="$SMTP_PORT"
export RALPH_EMAIL_USER="$SMTP_USER"
export RALPH_EMAIL_PASS="$SMTP_PASS"
export RALPH_EMAIL_USE_SSL="true"

"@
}

if ($CUSTOM_SCRIPT) {
    $configContent += @"
# Custom Script
export RALPH_CUSTOM_NOTIFY_SCRIPT="$CUSTOM_SCRIPT"

"@
}

Set-Content -Path $CONFIG_FILE -Value $configContent
Write-Host "Configuration saved to: $CONFIG_FILE" -ForegroundColor Green

# ============================================
# SOURCE AND TEST
# ============================================
Write-Host ""
Write-Host "Loading configuration..." -ForegroundColor White

# Load the config into current session
Get-Content $CONFIG_FILE | ForEach-Object {
    $line = $_.Trim()
    if ($line -and !$line.StartsWith('#')) {
        if ($line -match '^(?:export\s+)?(\w+)="?([^"]*)"?$') {
            $varName = $matches[1]
            $varValue = $matches[2]
            Set-Item -Path "env:$varName" -Value $varValue -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ""
$testNow = Read-Host "Do you want to send a test notification? (Y/n)"
if ($testNow -notmatch '^[Nn]') {
    Write-Host ""
    & (Join-Path $RALPH_DIR "notify.ps1") --test
}

# ============================================
# FINAL INSTRUCTIONS
# ============================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host ""
Write-Host "To enable notifications in new PowerShell sessions, add this to your"
Write-Host "`$PROFILE (PowerShell profile):"
Write-Host ""
Write-Host "  # Load Ralph configuration" -ForegroundColor Cyan
Write-Host "  if (Test-Path '$CONFIG_FILE') {" -ForegroundColor Cyan
Write-Host "      Get-Content '$CONFIG_FILE' | ForEach-Object {" -ForegroundColor Cyan
Write-Host '          if ($_ -match "^(?:export\s+)?(\w+)=\"?([^\"]*)\"?$") {' -ForegroundColor Cyan
Write-Host "              Set-Item -Path `"env:`$(`$matches[1])`" -Value `$matches[2]" -ForegroundColor Cyan
Write-Host "          }" -ForegroundColor Cyan
Write-Host "      }" -ForegroundColor Cyan
Write-Host "  }" -ForegroundColor Cyan
Write-Host ""
Write-Host "Or edit your profile with:"
Write-Host ""
Write-Host "  notepad `$PROFILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test notifications anytime with:"
Write-Host ""
Write-Host "  .\ralph.ps1 notify test" -ForegroundColor Cyan
Write-Host ""
